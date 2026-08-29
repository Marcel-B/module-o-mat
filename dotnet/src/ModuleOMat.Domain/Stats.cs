namespace ModuleOMat.Domain;

public static class Stats
{
    public const decimal HpMm = 5.08m;

    public static InventoryStats FromModules(IEnumerable<EurorackModule> modules)
    {
        var list = modules.ToList();
        var totalHp = list.Sum(module => module.Hp);
        var totalWidthMm = totalHp * HpMm;

        return new InventoryStats(
            list.Count,
            totalHp,
            totalWidthMm,
            totalWidthMm / 10m,
            totalWidthMm / 1000m,
            list.Sum(module => module.PurchasePrice ?? 0m),
            list.Sum(module => module.CurrentValue ?? 0m));
    }

    public static bool Matches(EurorackModule module, ModuleFilter filter)
    {
        if (module.DeletedAt is not null)
        {
            return false;
        }

        if (!string.IsNullOrWhiteSpace(filter.Q))
        {
            var q = filter.Q.Trim();
            if (!ContainsInsensitive(module.Manufacturer, q) && !ContainsInsensitive(module.Name, q))
            {
                return false;
            }
        }

        if (filter.Types is { Count: > 0 })
        {
            var types = filter.Types.Where(value => !string.IsNullOrWhiteSpace(value)).ToArray();
            if (types.Length > 0 &&
                !types.Contains(module.Type) &&
                !module.Subtypes.Any(sub => types.Contains(sub)))
            {
                return false;
            }
        }

        if (filter.MinHp is > 0 && module.Hp < filter.MinHp)
        {
            return false;
        }

        if (filter.MaxHp is > 0 && module.Hp > filter.MaxHp)
        {
            return false;
        }

        return true;
    }

    public static string EscapeLike(string value) =>
        value.Replace("\\", "\\\\", StringComparison.Ordinal)
            .Replace("%", "\\%", StringComparison.Ordinal)
            .Replace("_", "\\_", StringComparison.Ordinal);

    private static bool ContainsInsensitive(string haystack, string needle) =>
        haystack.Contains(needle, StringComparison.OrdinalIgnoreCase);
}
