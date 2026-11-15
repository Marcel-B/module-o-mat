using ModuleOMat.Domain.Ports;

namespace ModuleOMat.Domain;

/// <summary>
/// Ein geplantes Case/Rack: Name, Netzteil-Kapazitaet je Schiene (mA) und die eingeplanten Module.
/// Die Verbrauchsrechnung passiert bewusst im Client.
/// </summary>
public sealed record Rack(
    int Id,
    string Name,
    int? PsuPlus12VMa,
    int? PsuMinus12VMa,
    int? PsuPlus5VMa,
    IReadOnlyList<int> ModuleIds,
    DateTime InsertedAt,
    DateTime UpdatedAt);

public sealed record RackInput(
    string? Name,
    int? PsuPlus12VMa,
    int? PsuMinus12VMa,
    int? PsuPlus5VMa,
    IReadOnlyList<int>? ModuleIds);

public sealed record ValidatedRack(
    string Name,
    int? PsuPlus12VMa,
    int? PsuMinus12VMa,
    int? PsuPlus5VMa,
    IReadOnlyList<int> ModuleIds);

public static class RackValidation
{
    public const int MaxNameLength = 120;
    public const int MaxRailMa = 100_000;
    public const int MaxModules = 1_000;

    public static Result<ValidatedRack> Validate(RackInput input)
    {
        var details = new Dictionary<string, object>(StringComparer.Ordinal);

        var name = string.IsNullOrWhiteSpace(input.Name) ? null : input.Name.Trim();
        if (name is null)
        {
            details["name"] = new[] { "muss ausgefuellt werden" };
        }
        else if (name.Length > MaxNameLength)
        {
            details["name"] = new[] { $"darf hoechstens {MaxNameLength} Zeichen lang sein" };
        }

        Rail(details, "psu_plus12v_ma", input.PsuPlus12VMa);
        Rail(details, "psu_minus12v_ma", input.PsuMinus12VMa);
        Rail(details, "psu_plus5v_ma", input.PsuPlus5VMa);

        var moduleIds = (input.ModuleIds ?? []).Distinct().ToArray();
        if (moduleIds.Length > MaxModules)
        {
            details["module_ids"] = new[] { $"darf hoechstens {MaxModules} Module enthalten" };
        }
        else if (moduleIds.Any(id => id <= 0))
        {
            details["module_ids"] = new[] { "enthaelt ungueltige IDs" };
        }

        if (details.Count > 0)
        {
            return Result.Fail<ValidatedRack>(AppError.Validation(details));
        }

        return Result.Ok(new ValidatedRack(
            name!,
            input.PsuPlus12VMa,
            input.PsuMinus12VMa,
            input.PsuPlus5VMa,
            moduleIds));
    }

    private static void Rail(Dictionary<string, object> details, string key, int? value)
    {
        if (value is < 0 or > MaxRailMa)
        {
            details[key] = new[] { $"muss zwischen 0 und {MaxRailMa} mA liegen" };
        }
    }
}

public static class RackOperations
{
    public static Task<IReadOnlyList<Rack>> List(IRackStore store, CancellationToken cancellationToken) =>
        store.ListRacks(cancellationToken);

    public static async Task<Result<Rack>> Get(IRackStore store, int id, CancellationToken cancellationToken)
    {
        var rack = await store.GetRack(id, cancellationToken).ConfigureAwait(false);
        return rack is null ? Result.Fail<Rack>(AppError.NotFound("Rack nicht gefunden")) : Result.Ok(rack);
    }

    public static Task<Result<Rack>> Create(
        IMaintenanceGate gate,
        IRackStore store,
        RackInput input,
        DateTime utcNow,
        CancellationToken cancellationToken) =>
        WithWrite(gate, async () =>
        {
            var validated = await ValidateWithModules(store, input, cancellationToken).ConfigureAwait(false);
            if (validated.IsError)
            {
                return Result.Fail<Rack>(validated.Error);
            }

            var rack = await store.InsertRack(validated.Value, utcNow, cancellationToken).ConfigureAwait(false);
            return Result.Ok(rack);
        });

    public static Task<Result<Rack>> Update(
        IMaintenanceGate gate,
        IRackStore store,
        int id,
        RackInput input,
        DateTime utcNow,
        CancellationToken cancellationToken) =>
        WithWrite(gate, async () =>
        {
            var existing = await Get(store, id, cancellationToken).ConfigureAwait(false);
            if (existing.IsError)
            {
                return existing;
            }

            var validated = await ValidateWithModules(store, input, cancellationToken).ConfigureAwait(false);
            if (validated.IsError)
            {
                return Result.Fail<Rack>(validated.Error);
            }

            var rack = await store.UpdateRack(id, validated.Value, utcNow, cancellationToken).ConfigureAwait(false);
            return Result.Ok(rack);
        });

    public static Task<Result<Unit>> Delete(
        IMaintenanceGate gate,
        IRackStore store,
        int id,
        CancellationToken cancellationToken) =>
        WithWrite(gate, async () =>
        {
            var existing = await Get(store, id, cancellationToken).ConfigureAwait(false);
            if (existing.IsError)
            {
                return Result.Fail<Unit>(existing.Error);
            }

            await store.DeleteRack(id, cancellationToken).ConfigureAwait(false);
            return Result.Ok();
        });

    private static async Task<Result<ValidatedRack>> ValidateWithModules(
        IRackStore store,
        RackInput input,
        CancellationToken cancellationToken)
    {
        var validated = RackValidation.Validate(input);
        if (validated.IsError || validated.Value.ModuleIds.Count == 0)
        {
            return validated;
        }

        var known = await store.ActiveModuleIds(validated.Value.ModuleIds, cancellationToken).ConfigureAwait(false);
        var unknown = validated.Value.ModuleIds.Where(id => !known.Contains(id)).ToArray();
        if (unknown.Length > 0)
        {
            return Result.Fail<ValidatedRack>(AppError.Validation(new Dictionary<string, object>(StringComparer.Ordinal)
            {
                ["module_ids"] = new[] { $"enthaelt unbekannte Module: {string.Join(", ", unknown)}" }
            }));
        }

        return validated;
    }

    // Rack-Aenderungen stossen wie Modul-Aenderungen die Datensicherung an.
    private static Task<Result<T>> WithWrite<T>(IMaintenanceGate gate, Func<Task<Result<T>>> action) =>
        InventoryOperations.WithWrite(gate, action);
}
