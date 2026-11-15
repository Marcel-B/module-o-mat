using Microsoft.EntityFrameworkCore;
using ModuleOMat.Domain;
using ModuleOMat.Domain.Ports;

namespace ModuleOMat.Infrastructure.Persistence;

public sealed class EfRackStore(InventoryDbContext db) : IRackStore
{
    public async Task<IReadOnlyList<Rack>> ListRacks(CancellationToken cancellationToken)
    {
        var racks = await db.Racks.AsNoTracking()
            .Include(r => r.Modules)
            .OrderBy(r => r.Name)
            .ThenBy(r => r.Id)
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);
        var active = await ActiveIdsFor(racks.SelectMany(r => r.Modules), cancellationToken).ConfigureAwait(false);
        return racks.Select(r => Map(r, active)).ToArray();
    }

    public async Task<Rack?> GetRack(int id, CancellationToken cancellationToken)
    {
        var rack = await db.Racks.AsNoTracking()
            .Include(r => r.Modules)
            .FirstOrDefaultAsync(r => r.Id == id, cancellationToken)
            .ConfigureAwait(false);
        if (rack is null)
        {
            return null;
        }

        var active = await ActiveIdsFor(rack.Modules, cancellationToken).ConfigureAwait(false);
        return Map(rack, active);
    }

    public async Task<Rack> InsertRack(ValidatedRack rack, DateTime utcNow, CancellationToken cancellationToken)
    {
        var entity = new RackEntity { InsertedAt = utcNow };
        Apply(entity, rack, utcNow);
        db.Racks.Add(entity);
        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);
        return (await GetRack(entity.Id, cancellationToken).ConfigureAwait(false))!;
    }

    public async Task<Rack> UpdateRack(int id, ValidatedRack rack, DateTime utcNow, CancellationToken cancellationToken)
    {
        var entity = await db.Racks
            .Include(r => r.Modules)
            .FirstAsync(r => r.Id == id, cancellationToken)
            .ConfigureAwait(false);
        db.RackModules.RemoveRange(entity.Modules);
        entity.Modules.Clear();
        Apply(entity, rack, utcNow);
        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);
        db.ChangeTracker.Clear();
        return (await GetRack(id, cancellationToken).ConfigureAwait(false))!;
    }

    public async Task DeleteRack(int id, CancellationToken cancellationToken) =>
        await db.Racks.Where(r => r.Id == id).ExecuteDeleteAsync(cancellationToken).ConfigureAwait(false);

    public async Task<IReadOnlySet<int>> ActiveModuleIds(IReadOnlyList<int> moduleIds, CancellationToken cancellationToken)
    {
        var ids = moduleIds.Distinct().ToArray();
        var found = await db.EurorackModules.AsNoTracking()
            .Where(m => ids.Contains(m.Id))
            .Select(m => m.Id)
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);
        return found.ToHashSet();
    }

    private Task<IReadOnlySet<int>> ActiveIdsFor(IEnumerable<RackModuleEntity> entries, CancellationToken cancellationToken) =>
        ActiveModuleIds(entries.Select(e => e.EurorackModuleId).ToArray(), cancellationToken);

    private static void Apply(RackEntity entity, ValidatedRack rack, DateTime utcNow)
    {
        entity.Name = rack.Name;
        entity.PsuPlus12VMa = rack.PsuPlus12VMa;
        entity.PsuMinus12VMa = rack.PsuMinus12VMa;
        entity.PsuPlus5VMa = rack.PsuPlus5VMa;
        entity.UpdatedAt = utcNow;
        entity.Modules.AddRange(rack.ModuleIds.Select((moduleId, index) => new RackModuleEntity
        {
            EurorackModuleId = moduleId,
            Position = index
        }));
    }

    private static Rack Map(RackEntity entity, IReadOnlySet<int> activeModuleIds) =>
        new(
            entity.Id,
            entity.Name,
            entity.PsuPlus12VMa,
            entity.PsuMinus12VMa,
            entity.PsuPlus5VMa,
            entity.Modules
                .OrderBy(m => m.Position)
                .Select(m => m.EurorackModuleId)
                .Where(activeModuleIds.Contains)
                .ToArray(),
            entity.InsertedAt,
            entity.UpdatedAt);
}
