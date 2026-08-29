namespace ModuleOMat.Domain;

public static class Pricing
{
    public static decimal MedianAmount(IReadOnlyList<decimal> amounts)
    {
        if (amounts.Count == 0)
        {
            throw new ArgumentException("amounts must not be empty", nameof(amounts));
        }

        var sorted = amounts.OrderBy(value => value).ToArray();
        var mid = sorted.Length / 2;
        if (sorted.Length % 2 == 1)
        {
            return sorted[mid];
        }

        return (sorted[mid - 1] + sorted[mid]) / 2m;
    }

    public static Result<decimal?> ResolveCurrentValue(
        CurrentValueSetting setting,
        IReadOnlyList<decimal> newAmounts)
    {
        return setting.ValueKind switch
        {
            CurrentValueSetting.Kind.Unchanged => Result.Ok<decimal?>(null),
            CurrentValueSetting.Kind.Median => Result.Ok<decimal?>(MedianAmount(newAmounts)),
            CurrentValueSetting.Kind.Explicit => Result.Ok<decimal?>(setting.Amount),
            _ => Result.Fail<decimal?>(AppError.InvalidCurrentValue())
        };
    }

    public static PriceRange? FromObservations(IEnumerable<PriceObservation> observations)
    {
        var list = observations.ToList();
        if (list.Count == 0)
        {
            return null;
        }

        return new PriceRange(
            list.Min(o => o.Amount),
            list.Max(o => o.Amount),
            list.Count,
            list.Max(o => o.ObservedOn));
    }
}
