using ModuleOMat.Domain.Ports;

namespace ModuleOMat.Domain;

public static class InventoryOperations
{
    public const int MaxPdfBytes = 20_000_000;
    public const int MaxZipBytes = 100_000_000;
    public const int BackupHistoryPageSize = 5;

    public static Task<IReadOnlyList<EurorackModule>> ListModules(
        IInventoryStore store,
        ModuleFilter filter,
        CancellationToken cancellationToken) =>
        store.ListActive(filter, cancellationToken);

    public static async Task<InventoryStats> Stats(
        IInventoryStore store,
        ModuleFilter filter,
        CancellationToken cancellationToken)
    {
        var modules = await store.ListActive(filter, cancellationToken).ConfigureAwait(false);
        return Domain.Stats.FromModules(modules);
    }

    public static Task<IReadOnlyList<string>> Manufacturers(IInventoryStore store, CancellationToken cancellationToken) =>
        store.ListManufacturers(cancellationToken);

    public static async Task<Result<EurorackModule>> GetActive(
        IInventoryStore store,
        int id,
        bool includeObservations,
        CancellationToken cancellationToken)
    {
        var module = await store.GetActive(id, includeObservations, cancellationToken).ConfigureAwait(false);
        return module is null
            ? Result.Fail<EurorackModule>(AppError.NotFound("Modul nicht gefunden"))
            : Result.Ok(module);
    }

    public static Task<IReadOnlyList<EurorackModule>> ListForValuation(
        IInventoryStore store,
        CancellationToken cancellationToken) =>
        store.ListForValuation(cancellationToken);

    public static Task<IReadOnlyList<ModuleTypeRecord>> ListModuleTypes(
        IInventoryStore store,
        CancellationToken cancellationToken) =>
        store.ListModuleTypes(cancellationToken);

    public static Task<IReadOnlyList<string>> ListUsedTypes(
        IInventoryStore store,
        CancellationToken cancellationToken) =>
        store.ListUsedTypes(cancellationToken);

    public static Task<PriceRange?> PriceRange(IInventoryStore store, int moduleId, CancellationToken cancellationToken) =>
        store.PriceRange(moduleId, cancellationToken);

    public static Task<IReadOnlyDictionary<int, PriceRange>> PriceRanges(
        IInventoryStore store,
        IReadOnlyList<int> ids,
        CancellationToken cancellationToken) =>
        store.PriceRanges(ids, cancellationToken);

    public static Task<BackupHistoryPage> BackupHistory(
        IInventoryStore store,
        int page,
        CancellationToken cancellationToken) =>
        store.ListBackupRuns(Math.Max(page, 1), cancellationToken);

    public static Task<Result<EurorackModule>> CreateModule(
        IMaintenanceGate gate,
        IInventoryStore store,
        ModuleInput input,
        DateTime utcNow,
        CancellationToken cancellationToken) =>
        WithWrite(gate, async () =>
        {
            var validated = ModuleValidation.Validate(input, requireCoreFields: true);
            if (validated.IsError)
            {
                return Result.Fail<EurorackModule>(validated.Error);
            }

            var created = await store.InsertModule(validated.Value, utcNow, cancellationToken).ConfigureAwait(false);
            return Result.Ok(created);
        });

    public static Task<Result<EurorackModule>> UpdateModule(
        IMaintenanceGate gate,
        IInventoryStore store,
        int id,
        ModuleInput patch,
        DateTime utcNow,
        CancellationToken cancellationToken) =>
        WithWrite(gate, async () =>
        {
            var existing = await GetActive(store, id, false, cancellationToken).ConfigureAwait(false);
            if (existing.IsError)
            {
                return existing;
            }

            var merged = ModuleValidation.Overlay(existing.Value, patch);
            var validated = ModuleValidation.Validate(merged, requireCoreFields: true);
            if (validated.IsError)
            {
                return Result.Fail<EurorackModule>(validated.Error);
            }

            var updated = await store.UpdateModule(id, validated.Value, utcNow, cancellationToken).ConfigureAwait(false);
            return Result.Ok(updated);
        });

    public static Task<Result<Unit>> SoftDelete(
        IMaintenanceGate gate,
        IInventoryStore store,
        int id,
        DateTime utcNow,
        CancellationToken cancellationToken) =>
        WithWrite(gate, async () =>
        {
            var existing = await GetActive(store, id, false, cancellationToken).ConfigureAwait(false);
            if (existing.IsError)
            {
                return Result.Fail<Unit>(existing.Error);
            }

            await store.SoftDelete(id, utcNow, cancellationToken).ConfigureAwait(false);
            return Result.Ok();
        });

    public static Task<Result<EurorackModule>> Duplicate(
        IMaintenanceGate gate,
        IInventoryStore store,
        IManualStorage manuals,
        int id,
        ModuleInput? overrides,
        bool copyManual,
        DateTime utcNow,
        CancellationToken cancellationToken) =>
        WithWrite(gate, async () =>
        {
            var existing = await GetActive(store, id, false, cancellationToken).ConfigureAwait(false);
            if (existing.IsError)
            {
                return existing;
            }

            var source = existing.Value;
            var baseInput = ModuleValidation.FromModule(source);
            var merged = overrides is null ? baseInput : ModuleValidation.Overlay(source, overrides);
            var validated = ModuleValidation.Validate(merged, requireCoreFields: true);
            if (validated.IsError)
            {
                return Result.Fail<EurorackModule>(validated.Error);
            }

            var created = await store.InsertModule(validated.Value, utcNow, cancellationToken).ConfigureAwait(false);
            if (copyManual && source.ManualPdfKey is not null && manuals.Exists(source.ManualPdfKey))
            {
                created = await CopyManual(store, manuals, created, source, utcNow, cancellationToken)
                    .ConfigureAwait(false);
            }

            return Result.Ok(created);
        });

    public static Task<Result<EurorackModule>> AttachManual(
        IMaintenanceGate gate,
        IInventoryStore store,
        IManualStorage manuals,
        int id,
        string tmpPath,
        string filename,
        string? contentType,
        int size,
        DateTime utcNow,
        CancellationToken cancellationToken) =>
        WithWrite(gate, async () =>
        {
            if (size > MaxPdfBytes)
            {
                return Result.Fail<EurorackModule>(AppError.Unprocessable("PDF darf hoechstens 20 MB gross sein"));
            }

            if (!IsPdfUpload(filename, contentType))
            {
                return Result.Fail<EurorackModule>(AppError.Unprocessable("Nur PDF-Dateien sind erlaubt"));
            }

            if (!manuals.LooksLikePdf(tmpPath))
            {
                return Result.Fail<EurorackModule>(
                    AppError.Unprocessable("Datei ist kein PDF (Magic-Bytes fehlen)"));
            }

            var existing = await GetActive(store, id, false, cancellationToken).ConfigureAwait(false);
            if (existing.IsError)
            {
                return existing;
            }

            var newKey = manuals.NewKey();
            var oldKey = existing.Value.ManualPdfKey;
            await manuals.Store(newKey, tmpPath, cancellationToken).ConfigureAwait(false);

            try
            {
                var meta = new ManualMeta(
                    newKey,
                    filename,
                    string.IsNullOrWhiteSpace(contentType) ? "application/pdf" : contentType,
                    size);
                await store.SetManual(id, meta, utcNow, cancellationToken).ConfigureAwait(false);
                if (oldKey is not null && oldKey != newKey)
                {
                    await manuals.Delete(oldKey, cancellationToken).ConfigureAwait(false);
                }

                return Result.Ok((await GetActive(store, id, false, cancellationToken).ConfigureAwait(false)).Value);
            }
            catch
            {
                await manuals.Delete(newKey, cancellationToken).ConfigureAwait(false);
                throw;
            }
        });

    public static Task<Result<EurorackModule>> RemoveManual(
        IMaintenanceGate gate,
        IInventoryStore store,
        IManualStorage manuals,
        int id,
        DateTime utcNow,
        CancellationToken cancellationToken) =>
        WithWrite(gate, async () =>
        {
            var existing = await GetActive(store, id, false, cancellationToken).ConfigureAwait(false);
            if (existing.IsError)
            {
                return existing;
            }

            var oldKey = existing.Value.ManualPdfKey;
            await store.SetManual(id, null, utcNow, cancellationToken).ConfigureAwait(false);
            await manuals.Delete(oldKey, cancellationToken).ConfigureAwait(false);
            return await GetActive(store, id, false, cancellationToken).ConfigureAwait(false);
        });

    public static Task<Result<ModuleTypeRecord>> CreateModuleType(
        IMaintenanceGate gate,
        IInventoryStore store,
        string? name,
        DateTime utcNow,
        CancellationToken cancellationToken) =>
        WithWrite(gate, async () =>
        {
            var validated = ModuleValidation.ValidateTypeName(name);
            if (validated.IsError)
            {
                return Result.Fail<ModuleTypeRecord>(validated.Error);
            }

            if (await store.ModuleTypeNameExists(validated.Value, null, cancellationToken).ConfigureAwait(false))
            {
                return Result.Fail<ModuleTypeRecord>(AppError.Validation(new Dictionary<string, object>
                {
                    ["name"] = new[] { "existiert bereits" }
                }));
            }

            var created = await store.InsertModuleType(validated.Value, utcNow, cancellationToken).ConfigureAwait(false);
            return Result.Ok(created);
        });

    public static Task<Result<ModuleTypeRecord>> UpdateModuleType(
        IMaintenanceGate gate,
        IInventoryStore store,
        int id,
        string? name,
        DateTime utcNow,
        CancellationToken cancellationToken) =>
        WithWrite(gate, async () =>
        {
            var type = await store.GetModuleType(id, cancellationToken).ConfigureAwait(false);
            if (type is null)
            {
                return Result.Fail<ModuleTypeRecord>(AppError.NotFound("Modultyp nicht gefunden"));
            }

            if (TypeRules.IsFallback(type.Name))
            {
                return Result.Fail<ModuleTypeRecord>(AppError.FallbackType());
            }

            var validated = ModuleValidation.ValidateTypeName(name);
            if (validated.IsError)
            {
                return Result.Fail<ModuleTypeRecord>(validated.Error);
            }

            if (await store.ModuleTypeNameExists(validated.Value, id, cancellationToken).ConfigureAwait(false))
            {
                return Result.Fail<ModuleTypeRecord>(AppError.Validation(new Dictionary<string, object>
                {
                    ["name"] = new[] { "existiert bereits" }
                }));
            }

            var updated = await store
                .RenameModuleType(id, type.Name, validated.Value, utcNow, cancellationToken)
                .ConfigureAwait(false);
            return Result.Ok(updated);
        });

    public static Task<Result<Unit>> DeleteModuleType(
        IMaintenanceGate gate,
        IInventoryStore store,
        int id,
        DateTime utcNow,
        CancellationToken cancellationToken) =>
        WithWrite(gate, async () =>
        {
            var type = await store.GetModuleType(id, cancellationToken).ConfigureAwait(false);
            if (type is null)
            {
                return Result.Fail<Unit>(AppError.NotFound("Modultyp nicht gefunden"));
            }

            if (TypeRules.IsFallback(type.Name))
            {
                return Result.Fail<Unit>(AppError.FallbackType());
            }

            await store.DeleteModuleType(id, type.Name, utcNow, cancellationToken).ConfigureAwait(false);
            return Result.Ok();
        });

    public static Task<Result<ValuationResult>> CreateObservations(
        IMaintenanceGate gate,
        IInventoryStore store,
        int moduleId,
        IReadOnlyList<ObservationInput> observations,
        CurrentValueSetting setting,
        DateTime utcNow,
        DateOnly today,
        CancellationToken cancellationToken) =>
        WithWrite(gate, async () =>
        {
            if (observations.Count == 0)
            {
                return Result.Fail<ValuationResult>(AppError.EmptyObservations());
            }

            var existing = await GetActive(store, moduleId, false, cancellationToken).ConfigureAwait(false);
            if (existing.IsError)
            {
                return Result.Fail<ValuationResult>(existing.Error);
            }

            var validated = new List<ObservationInput>();
            foreach (var observation in observations)
            {
                var withDate = observation with { ObservedOn = observation.ObservedOn ?? today };
                var result = ModuleValidation.ValidateObservation(withDate);
                if (result.IsError)
                {
                    return Result.Fail<ValuationResult>(result.Error);
                }

                validated.Add(result.Value);
            }

            if (setting.ValueKind == CurrentValueSetting.Kind.Explicit && setting.Amount is null)
            {
                return Result.Fail<ValuationResult>(AppError.InvalidCurrentValue());
            }

            var inserted = await store
                .InsertObservations(moduleId, validated, setting, utcNow, cancellationToken)
                .ConfigureAwait(false);

            var module = (await GetActive(store, moduleId, false, cancellationToken).ConfigureAwait(false)).Value;
            var range = await store.PriceRange(moduleId, cancellationToken).ConfigureAwait(false);
            return Result.Ok(new ValuationResult(module, inserted, range));
        });

    public static async Task<Result<T>> WithWrite<T>(IMaintenanceGate gate, Func<Task<Result<T>>> action)
    {
        var begin = gate.BeginWrite();
        if (begin.IsError)
        {
            return Result.Fail<T>(begin.Error);
        }

        try
        {
            var result = await action().ConfigureAwait(false);
            if (result.IsOk)
            {
                gate.ScheduleAfterChange();
            }

            return result;
        }
        finally
        {
            gate.EndWrite();
        }
    }

    private static async Task<EurorackModule> CopyManual(
        IInventoryStore store,
        IManualStorage manuals,
        EurorackModule target,
        EurorackModule source,
        DateTime utcNow,
        CancellationToken cancellationToken)
    {
        var newKey = manuals.NewKey();
        var tmp = Path.Combine(Path.GetTempPath(), $"module-o-mat-manual-copy-{newKey}.pdf");
        try
        {
            await manuals.CopyOut(source.ManualPdfKey!, tmp, cancellationToken).ConfigureAwait(false);
            await manuals.Store(newKey, tmp, cancellationToken).ConfigureAwait(false);
            var meta = new ManualMeta(
                newKey,
                source.ManualPdfFilename ?? "manual.pdf",
                source.ManualPdfContentType ?? "application/pdf",
                source.ManualPdfSizeBytes ?? 0);
            await store.SetManual(target.Id, meta, utcNow, cancellationToken).ConfigureAwait(false);
            return (await store.GetActive(target.Id, false, cancellationToken).ConfigureAwait(false))!;
        }
        catch
        {
            await manuals.Delete(newKey, cancellationToken).ConfigureAwait(false);
            return target;
        }
        finally
        {
            if (File.Exists(tmp))
            {
                File.Delete(tmp);
            }
        }
    }

    public static bool IsPdfUpload(string? filename, string? contentType) =>
        (filename ?? string.Empty).EndsWith(".pdf", StringComparison.OrdinalIgnoreCase) ||
        (contentType ?? string.Empty).Contains("pdf", StringComparison.OrdinalIgnoreCase);

    public static bool IsZipUpload(string? filename, string? contentType) =>
        (filename ?? string.Empty).EndsWith(".zip", StringComparison.OrdinalIgnoreCase) ||
        (contentType ?? string.Empty).Contains("zip", StringComparison.OrdinalIgnoreCase);
}
