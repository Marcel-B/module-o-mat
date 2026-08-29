using Microsoft.EntityFrameworkCore;
using ModuleOMat.Domain;
using ModuleOMat.Domain.Ports;

namespace ModuleOMat.Infrastructure.Persistence;

public sealed class EfInventoryStore(InventoryDbContext db) : IInventoryStore
{
    public async Task<IReadOnlyList<EurorackModule>> ListActive(ModuleFilter filter, CancellationToken cancellationToken)
    {
        var query = ApplyFilter(db.EurorackModules.AsNoTracking().Include(m => m.YoutubeVideos), filter);
        var entities = await query
            .OrderBy(m => m.Type)
            .ThenBy(m => m.Manufacturer)
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        if (filter.Types is { Count: > 0 })
        {
            var types = filter.Types.Where(t => !string.IsNullOrWhiteSpace(t)).ToArray();
            if (types.Length > 0)
            {
                entities = entities
                    .Where(m => types.Contains(m.Type) || (m.Subtypes ?? []).Any(s => types.Contains(s)))
                    .ToList();
            }
        }

        return entities.Select(MapModule).ToArray();
    }

    public async Task<IReadOnlyList<EurorackModule>> ListForValuation(CancellationToken cancellationToken)
    {
        var entities = await db.EurorackModules.AsNoTracking()
            .OrderBy(m => m.Manufacturer)
            .ThenBy(m => m.Name)
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);
        return entities.Select(MapModule).ToArray();
    }

    public async Task<EurorackModule?> GetActive(int id, bool includeObservations, CancellationToken cancellationToken)
    {
        IQueryable<EurorackModuleEntity> query = db.EurorackModules
            .AsNoTracking()
            .Include(m => m.YoutubeVideos);
        if (includeObservations)
        {
            query = query.Include(m => m.PriceObservations);
        }

        var entity = await query.FirstOrDefaultAsync(m => m.Id == id, cancellationToken).ConfigureAwait(false);
        return entity is null ? null : MapModule(entity);
    }

    public async Task<IReadOnlyList<string>> ListManufacturers(CancellationToken cancellationToken) =>
        await db.EurorackModules.IgnoreQueryFilters()
            .Select(m => m.Manufacturer)
            .Distinct()
            .OrderBy(name => name)
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

    public async Task<IReadOnlyList<ModuleTypeRecord>> ListModuleTypes(CancellationToken cancellationToken)
    {
        var entities = await db.ModuleTypes.AsNoTracking()
            .OrderBy(t => t.Name)
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);
        return entities.Select(MapType).ToArray();
    }

    public async Task<IReadOnlyList<string>> ListUsedTypes(CancellationToken cancellationToken)
    {
        var rows = await db.EurorackModules.AsNoTracking()
            .Select(m => new { m.Type, m.Subtypes })
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        return rows
            .SelectMany(row => new[] { row.Type }.Concat(row.Subtypes ?? []))
            .Where(name => !string.IsNullOrWhiteSpace(name))
            .Distinct(StringComparer.Ordinal)
            .OrderBy(name => name, StringComparer.Ordinal)
            .ToArray();
    }

    public async Task<ModuleTypeRecord?> GetModuleType(int id, CancellationToken cancellationToken)
    {
        var entity = await db.ModuleTypes.AsNoTracking()
            .FirstOrDefaultAsync(t => t.Id == id, cancellationToken)
            .ConfigureAwait(false);
        return entity is null ? null : MapType(entity);
    }

    public Task<bool> ModuleTypeNameExists(string name, int? exceptId, CancellationToken cancellationToken) =>
        db.ModuleTypes.AnyAsync(t => t.Name == name && (exceptId == null || t.Id != exceptId), cancellationToken);

    public async Task<EurorackModule> InsertModule(ValidatedModule module, DateTime utcNow, CancellationToken cancellationToken)
    {
        var entity = NewModule(module, utcNow);
        db.EurorackModules.Add(entity);
        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);
        return MapModule(entity);
    }

    public async Task<EurorackModule> UpdateModule(int id, ValidatedModule module, DateTime utcNow, CancellationToken cancellationToken)
    {
        var entity = await db.EurorackModules
            .Include(m => m.YoutubeVideos)
            .FirstAsync(m => m.Id == id, cancellationToken)
            .ConfigureAwait(false);
        Apply(entity, module, utcNow);
        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);
        return MapModule(entity);
    }

    public async Task SoftDelete(int id, DateTime utcNow, CancellationToken cancellationToken)
    {
        var entity = await db.EurorackModules.FirstAsync(m => m.Id == id, cancellationToken).ConfigureAwait(false);
        entity.DeletedAt = utcNow;
        entity.UpdatedAt = utcNow;
        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);
    }

    public async Task SetManual(int id, ManualMeta? meta, DateTime utcNow, CancellationToken cancellationToken)
    {
        var entity = await db.EurorackModules.FirstAsync(m => m.Id == id, cancellationToken).ConfigureAwait(false);
        entity.ManualPdfKey = meta?.Key;
        entity.ManualPdfFilename = meta?.Filename;
        entity.ManualPdfContentType = meta?.ContentType;
        entity.ManualPdfSizeBytes = meta?.SizeBytes;
        entity.UpdatedAt = utcNow;
        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);
    }

    public async Task<ModuleTypeRecord> InsertModuleType(string name, DateTime utcNow, CancellationToken cancellationToken)
    {
        var entity = new ModuleTypeEntity { Name = name, InsertedAt = utcNow, UpdatedAt = utcNow };
        db.ModuleTypes.Add(entity);
        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);
        return MapType(entity);
    }

    public async Task<ModuleTypeRecord> RenameModuleType(
        int id,
        string oldName,
        string newName,
        DateTime utcNow,
        CancellationToken cancellationToken)
    {
        var entity = await db.ModuleTypes.FirstAsync(t => t.Id == id, cancellationToken).ConfigureAwait(false);
        entity.Name = newName;
        entity.UpdatedAt = utcNow;

        var modules = await db.EurorackModules.IgnoreQueryFilters().ToListAsync(cancellationToken).ConfigureAwait(false);
        foreach (var module in modules)
        {
            if (module.Type == oldName)
            {
                module.Type = newName;
                module.UpdatedAt = utcNow;
            }

            if (module.Subtypes.Contains(oldName))
            {
                module.Subtypes = TypeRules.ReplaceSubtype(module.Subtypes, oldName, newName, module.Type).ToList();
                module.UpdatedAt = utcNow;
            }
        }

        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);
        return MapType(entity);
    }

    public async Task DeleteModuleType(int id, string name, DateTime utcNow, CancellationToken cancellationToken)
    {
        var modules = await db.EurorackModules.IgnoreQueryFilters().ToListAsync(cancellationToken).ConfigureAwait(false);
        foreach (var module in modules)
        {
            if (module.Type == name)
            {
                module.Type = TypeRules.FallbackTypeName;
                module.UpdatedAt = utcNow;
            }

            if (module.Subtypes.Contains(name))
            {
                module.Subtypes = TypeRules.RemoveSubtype(module.Subtypes, name).ToList();
                module.UpdatedAt = utcNow;
            }
        }

        var entity = await db.ModuleTypes.FirstAsync(t => t.Id == id, cancellationToken).ConfigureAwait(false);
        db.ModuleTypes.Remove(entity);
        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);
    }

    public async Task<IReadOnlyList<PriceObservation>> InsertObservations(
        int moduleId,
        IReadOnlyList<ObservationInput> observations,
        CurrentValueSetting currentValue,
        DateTime utcNow,
        CancellationToken cancellationToken)
    {
        var inserted = new List<PriceObservationEntity>();
        foreach (var observation in observations)
        {
            var entity = new PriceObservationEntity
            {
                EurorackModuleId = moduleId,
                Amount = observation.Amount,
                Currency = observation.Currency ?? "EUR",
                Source = observation.Source,
                SourceUrl = observation.SourceUrl,
                ObservedOn = observation.ObservedOn ?? DateOnly.FromDateTime(utcNow),
                Notes = observation.Notes,
                InsertedAt = utcNow,
                UpdatedAt = utcNow
            };
            db.PriceObservations.Add(entity);
            inserted.Add(entity);
        }

        if (currentValue.ValueKind != CurrentValueSetting.Kind.Unchanged)
        {
            var module = await db.EurorackModules.FirstAsync(m => m.Id == moduleId, cancellationToken)
                .ConfigureAwait(false);
            module.CurrentValue = currentValue.ValueKind == CurrentValueSetting.Kind.Median
                ? Pricing.MedianAmount(observations.Select(o => o.Amount).ToArray())
                : currentValue.Amount;
            module.UpdatedAt = utcNow;
        }

        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);
        return inserted.Select(MapObservation).ToArray();
    }

    public async Task<PriceRange?> PriceRange(int moduleId, CancellationToken cancellationToken)
    {
        var query = db.PriceObservations.AsNoTracking().Where(o => o.EurorackModuleId == moduleId);
        if (!await query.AnyAsync(cancellationToken).ConfigureAwait(false))
        {
            return null;
        }

        return new PriceRange(
            await query.MinAsync(o => o.Amount, cancellationToken).ConfigureAwait(false),
            await query.MaxAsync(o => o.Amount, cancellationToken).ConfigureAwait(false),
            await query.CountAsync(cancellationToken).ConfigureAwait(false),
            await query.MaxAsync(o => o.ObservedOn, cancellationToken).ConfigureAwait(false));
    }

    public async Task<IReadOnlyDictionary<int, PriceRange>> PriceRanges(
        IReadOnlyList<int> moduleIds,
        CancellationToken cancellationToken)
    {
        if (moduleIds.Count == 0)
        {
            return new Dictionary<int, PriceRange>();
        }

        var rows = await db.PriceObservations.AsNoTracking()
            .Where(o => moduleIds.Contains(o.EurorackModuleId))
            .GroupBy(o => o.EurorackModuleId)
            .Select(group => new
            {
                Id = group.Key,
                Min = group.Min(o => o.Amount),
                Max = group.Max(o => o.Amount),
                Count = group.Count(),
                Last = group.Max(o => o.ObservedOn)
            })
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        return rows.ToDictionary(
            row => row.Id,
            row => new PriceRange(row.Min, row.Max, row.Count, row.Last));
    }

    public async Task RecordBackupRun(
        string? filename,
        long? sizeBytes,
        bool success,
        DateTime utcNow,
        CancellationToken cancellationToken)
    {
        db.BackupRuns.Add(new BackupRunEntity
        {
            Filename = string.IsNullOrWhiteSpace(filename) ? null : filename.Trim(),
            SizeBytes = sizeBytes,
            Success = success,
            InsertedAt = utcNow,
            UpdatedAt = utcNow
        });
        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);
    }

    public async Task<BackupHistoryPage> ListBackupRuns(int page, CancellationToken cancellationToken)
    {
        const int perPage = InventoryOperations.BackupHistoryPageSize;
        var total = await db.BackupRuns.CountAsync(cancellationToken).ConfigureAwait(false);
        var runs = await db.BackupRuns.AsNoTracking()
            .OrderByDescending(r => r.InsertedAt)
            .ThenByDescending(r => r.Id)
            .Skip((page - 1) * perPage)
            .Take(perPage)
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        return new BackupHistoryPage(
            runs.Select(MapBackupRun).ToArray(),
            page,
            perPage,
            total,
            await LatestAt(true, cancellationToken).ConfigureAwait(false),
            await LatestAt(false, cancellationToken).ConfigureAwait(false));
    }

    public async Task<BackupSnapshot> LoadSnapshot(CancellationToken cancellationToken)
    {
        var types = await db.ModuleTypes.AsNoTracking().OrderBy(t => t.Id).ToListAsync(cancellationToken)
            .ConfigureAwait(false);
        var modules = await db.EurorackModules.AsNoTracking().OrderBy(m => m.Id).ToListAsync(cancellationToken)
            .ConfigureAwait(false);
        var ids = modules.Select(m => m.Id).ToArray();
        var videos = ids.Length == 0
            ? []
            : await db.YoutubeVideos.AsNoTracking()
                .Where(v => ids.Contains(v.EurorackModuleId))
                .OrderBy(v => v.Id)
                .ToListAsync(cancellationToken)
                .ConfigureAwait(false);
        var observations = ids.Length == 0
            ? []
            : await db.PriceObservations.AsNoTracking()
                .Where(o => ids.Contains(o.EurorackModuleId))
                .OrderBy(o => o.Id)
                .ToListAsync(cancellationToken)
                .ConfigureAwait(false);

        return new BackupSnapshot(
            types.Select(t => new BackupTypeRow(t.Id, t.Name, t.InsertedAt, t.UpdatedAt)).ToArray(),
            modules.Select(m => new BackupModuleRow(
                m.Id, m.Manufacturer, m.Name, m.Hp, m.Type, m.Subtypes,
                m.CurrentDrawPlus12VMa, m.CurrentDrawMinus12VMa, m.CurrentDrawPlus5VMa,
                m.DepthMm, m.Description, m.ManualUrl, m.PurchasePrice, m.CurrentValue,
                m.ManualPdfKey, m.ManualPdfFilename, m.ManualPdfContentType, m.ManualPdfSizeBytes,
                m.InsertedAt, m.UpdatedAt)).ToArray(),
            videos.Select(v => new BackupVideoRow(v.Id, v.EurorackModuleId, v.Url, v.Position, v.InsertedAt, v.UpdatedAt))
                .ToArray(),
            observations.Select(o => new BackupObservationRow(
                    o.Id, o.EurorackModuleId, o.Amount, o.Currency, o.Source, o.SourceUrl, o.ObservedOn, o.Notes,
                    o.InsertedAt, o.UpdatedAt))
                .ToArray());
    }

    public async Task ReplaceInventory(BackupSnapshot snapshot, CancellationToken cancellationToken)
    {
        await using var tx = await db.Database.BeginTransactionAsync(cancellationToken).ConfigureAwait(false);
        await db.PriceObservations.ExecuteDeleteAsync(cancellationToken).ConfigureAwait(false);
        await db.YoutubeVideos.ExecuteDeleteAsync(cancellationToken).ConfigureAwait(false);
        await db.EurorackModules.IgnoreQueryFilters().ExecuteDeleteAsync(cancellationToken).ConfigureAwait(false);
        await db.ModuleTypes.ExecuteDeleteAsync(cancellationToken).ConfigureAwait(false);

        db.ModuleTypes.AddRange(snapshot.Types.Select(t => new ModuleTypeEntity
        {
            Id = t.Id,
            Name = t.Name,
            InsertedAt = t.InsertedAt,
            UpdatedAt = t.UpdatedAt
        }));
        db.EurorackModules.AddRange(snapshot.Modules.Select(m => new EurorackModuleEntity
        {
            Id = m.Id,
            Manufacturer = m.Manufacturer,
            Name = m.Name,
            Hp = m.Hp,
            Type = m.Type,
            Subtypes = m.Subtypes.ToList(),
            CurrentDrawPlus12VMa = m.CurrentDrawPlus12VMa,
            CurrentDrawMinus12VMa = m.CurrentDrawMinus12VMa,
            CurrentDrawPlus5VMa = m.CurrentDrawPlus5VMa,
            DepthMm = m.DepthMm,
            Description = m.Description,
            ManualUrl = m.ManualUrl,
            PurchasePrice = m.PurchasePrice,
            CurrentValue = m.CurrentValue,
            ManualPdfKey = m.ManualPdfKey,
            ManualPdfFilename = m.ManualPdfFilename,
            ManualPdfContentType = m.ManualPdfContentType,
            ManualPdfSizeBytes = m.ManualPdfSizeBytes,
            DeletedAt = null,
            InsertedAt = m.InsertedAt,
            UpdatedAt = m.UpdatedAt
        }));
        db.YoutubeVideos.AddRange(snapshot.Videos.Select(v => new YoutubeVideoEntity
        {
            Id = v.Id,
            EurorackModuleId = v.EurorackModuleId,
            Url = v.Url,
            Position = v.Position,
            InsertedAt = v.InsertedAt,
            UpdatedAt = v.UpdatedAt
        }));
        db.PriceObservations.AddRange(snapshot.Observations.Select(o => new PriceObservationEntity
        {
            Id = o.Id,
            EurorackModuleId = o.EurorackModuleId,
            Amount = o.Amount,
            Currency = o.Currency,
            Source = o.Source,
            SourceUrl = o.SourceUrl,
            ObservedOn = o.ObservedOn,
            Notes = o.Notes,
            InsertedAt = o.InsertedAt,
            UpdatedAt = o.UpdatedAt
        }));

        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);
        await ResetSequence("module_types", await MaxId(db.ModuleTypes.IgnoreQueryFilters(), cancellationToken).ConfigureAwait(false), cancellationToken).ConfigureAwait(false);
        await ResetSequence("eurorack_modules", await MaxId(db.EurorackModules.IgnoreQueryFilters(), cancellationToken).ConfigureAwait(false), cancellationToken).ConfigureAwait(false);
        await ResetSequence("youtube_videos", await MaxId(db.YoutubeVideos, cancellationToken).ConfigureAwait(false), cancellationToken).ConfigureAwait(false);
        await ResetSequence("module_price_observations", await MaxId(db.PriceObservations, cancellationToken).ConfigureAwait(false), cancellationToken).ConfigureAwait(false);
        await tx.CommitAsync(cancellationToken).ConfigureAwait(false);
    }

    private static async Task<int> MaxId<T>(IQueryable<T> query, CancellationToken cancellationToken) where T : class =>
        await query.Select(e => (int?)EF.Property<int>(e, "Id")).MaxAsync(cancellationToken).ConfigureAwait(false) ?? 0;


    private async Task ResetSequence(string table, int max, CancellationToken cancellationToken)
    {
        try
        {
            await db.Database.ExecuteSqlRawAsync("DELETE FROM sqlite_sequence WHERE name = {0}", table)
                .ConfigureAwait(false);
            if (max > 0)
            {
                await db.Database
                    .ExecuteSqlRawAsync("INSERT INTO sqlite_sequence(name, seq) VALUES ({0}, {1})", table, max)
                    .ConfigureAwait(false);
            }
        }
        catch (Exception)
        {
            // sqlite_sequence existiert nur bei AUTOINCREMENT.
        }
    }

    private async Task<DateTime?> LatestAt(bool success, CancellationToken cancellationToken) =>
        await db.BackupRuns.AsNoTracking()
            .Where(r => r.Success == success)
            .OrderByDescending(r => r.InsertedAt)
            .ThenByDescending(r => r.Id)
            .Select(r => (DateTime?)r.InsertedAt)
            .FirstOrDefaultAsync(cancellationToken)
            .ConfigureAwait(false);

    private static IQueryable<EurorackModuleEntity> ApplyFilter(
        IQueryable<EurorackModuleEntity> query,
        ModuleFilter filter)
    {
        if (!string.IsNullOrWhiteSpace(filter.Q))
        {
            var pattern = $"%{Stats.EscapeLike(filter.Q.Trim())}%";
            query = query.Where(m =>
                EF.Functions.Like(m.Manufacturer.ToLower(), pattern.ToLower(), "\\") ||
                EF.Functions.Like(m.Name.ToLower(), pattern.ToLower(), "\\"));
        }

        if (filter.MinHp is > 0)
        {
            query = query.Where(m => m.Hp >= filter.MinHp);
        }

        if (filter.MaxHp is > 0)
        {
            query = query.Where(m => m.Hp <= filter.MaxHp);
        }

        return query;
    }

    private static EurorackModuleEntity NewModule(ValidatedModule module, DateTime utcNow)
    {
        var entity = new EurorackModuleEntity { InsertedAt = utcNow };
        Apply(entity, module, utcNow);
        return entity;
    }

    private static void Apply(EurorackModuleEntity entity, ValidatedModule module, DateTime utcNow)
    {
        entity.Manufacturer = module.Manufacturer;
        entity.Name = module.Name;
        entity.Hp = module.Hp;
        entity.Type = module.Type;
        entity.Subtypes = module.Subtypes.ToList();
        entity.CurrentDrawPlus12VMa = module.CurrentDrawPlus12VMa;
        entity.CurrentDrawMinus12VMa = module.CurrentDrawMinus12VMa;
        entity.CurrentDrawPlus5VMa = module.CurrentDrawPlus5VMa;
        entity.DepthMm = module.DepthMm;
        entity.Description = module.Description;
        entity.ManualUrl = module.ManualUrl;
        entity.PurchasePrice = module.PurchasePrice;
        entity.CurrentValue = module.CurrentValue;
        entity.UpdatedAt = utcNow;
        entity.YoutubeVideos.Clear();
        foreach (var video in module.YoutubeVideos)
        {
            entity.YoutubeVideos.Add(new YoutubeVideoEntity
            {
                Url = video.Url,
                Position = video.Position,
                InsertedAt = utcNow,
                UpdatedAt = utcNow
            });
        }
    }

    private static EurorackModule MapModule(EurorackModuleEntity entity) =>
        new(
            entity.Id,
            entity.Manufacturer,
            entity.Name,
            entity.Hp,
            entity.Type,
            entity.Subtypes ?? [],
            entity.CurrentDrawPlus12VMa,
            entity.CurrentDrawMinus12VMa,
            entity.CurrentDrawPlus5VMa,
            entity.DepthMm,
            entity.Description,
            entity.ManualUrl,
            entity.PurchasePrice,
            entity.CurrentValue,
            entity.ManualPdfKey,
            entity.ManualPdfFilename,
            entity.ManualPdfContentType,
            entity.ManualPdfSizeBytes,
            entity.DeletedAt,
            entity.InsertedAt,
            entity.UpdatedAt,
            (entity.YoutubeVideos ?? [])
            .OrderBy(v => v.Position)
            .Select(v => new YoutubeVideo(v.Id, v.Url, v.Position))
            .ToArray(),
            entity.PriceObservations is { Count: > 0 }
                ? entity.PriceObservations
                    .OrderByDescending(o => o.ObservedOn)
                    .ThenByDescending(o => o.Id)
                    .Select(MapObservation)
                    .ToArray()
                : null);

    private static ModuleTypeRecord MapType(ModuleTypeEntity entity) =>
        new(entity.Id, entity.Name, entity.InsertedAt, entity.UpdatedAt);

    private static PriceObservation MapObservation(PriceObservationEntity entity) =>
        new(entity.Id, entity.Amount, entity.Currency, entity.Source, entity.SourceUrl, entity.ObservedOn, entity.Notes);

    private static BackupRun MapBackupRun(BackupRunEntity entity) =>
        new(entity.Id, entity.InsertedAt, entity.Filename, entity.SizeBytes, entity.Success);
}
