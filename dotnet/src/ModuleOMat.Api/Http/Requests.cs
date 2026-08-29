using System.Globalization;
using System.Text.Json;
using ModuleOMat.Domain;

namespace ModuleOMat.Api.Http;

public sealed class ModuleEnvelope
{
    public ModuleAttrs? Module { get; set; }
}

public sealed class ModuleTypeEnvelope
{
    public ModuleTypeAttrs? ModuleType { get; set; }
}

public sealed class ModuleAttrs
{
    public string? Manufacturer { get; set; }
    public string? Name { get; set; }
    public int? Hp { get; set; }
    public string? Type { get; set; }
    public List<string>? Subtypes { get; set; }
    public int? CurrentDrawPlus12vMa { get; set; }
    public int? CurrentDrawMinus12vMa { get; set; }
    public int? CurrentDrawPlus5vMa { get; set; }
    public int? DepthMm { get; set; }
    public string? Description { get; set; }
    public string? ManualUrl { get; set; }
    public decimal? PurchasePrice { get; set; }
    public decimal? CurrentValue { get; set; }
    public List<YoutubeVideoAttrs>? YoutubeVideos { get; set; }

    public ModuleInput ToInput() =>
        new(
            Manufacturer,
            Name,
            Hp,
            Type,
            Subtypes,
            CurrentDrawPlus12vMa,
            CurrentDrawMinus12vMa,
            CurrentDrawPlus5vMa,
            DepthMm,
            Description,
            ManualUrl,
            PurchasePrice,
            CurrentValue,
            YoutubeVideos?.Select(v => new YoutubeVideoInput(v.Url ?? string.Empty)).ToArray());
}

public sealed class YoutubeVideoAttrs
{
    public string? Url { get; set; }
}

public sealed class ModuleTypeAttrs
{
    public string? Name { get; set; }
}

public sealed class DuplicateRequest
{
    public ModuleAttrs? Module { get; set; }
    public JsonElement? CopyManual { get; set; }

    public bool CopyManualFlag => RequestParsing.Truthy(CopyManual, true);
}

public sealed class ValuationsRequest
{
    public List<ObservationAttrs>? Observations { get; set; }
    public JsonElement? CurrentValue { get; set; }
    public JsonElement? SetCurrentValue { get; set; }
}

public sealed class ObservationAttrs
{
    public decimal? Amount { get; set; }
    public string? Currency { get; set; }
    public string? Source { get; set; }
    public string? SourceUrl { get; set; }
    public DateOnly? ObservedOn { get; set; }
    public string? Notes { get; set; }

    public ObservationInput ToInput() =>
        new(Amount ?? 0, Source ?? string.Empty, Currency, SourceUrl, ObservedOn, Notes);
}

public static class RequestParsing
{
    public static int? ParseId(string? id)
    {
        if (int.TryParse(id, NumberStyles.Integer, CultureInfo.InvariantCulture, out var parsed) && parsed > 0)
        {
            return parsed;
        }

        return null;
    }

    public static int Page(string? page)
    {
        if (int.TryParse(page, NumberStyles.Integer, CultureInfo.InvariantCulture, out var parsed) && parsed > 0)
        {
            return parsed;
        }

        return 1;
    }

    public static ModuleFilter Filter(string? q, string[]? types, string? minHp, string? maxHp)
    {
        var parsedTypes = (types ?? [])
            .SelectMany(value => value.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
            .Where(value => value.Length > 0)
            .ToArray();

        return new ModuleFilter(
            string.IsNullOrWhiteSpace(q) ? null : q.Trim(),
            parsedTypes.Length == 0 ? null : parsedTypes,
            PositiveInt(minHp),
            PositiveInt(maxHp));
    }

    public static CurrentValueSetting CurrentValue(ValuationsRequest request)
    {
        if (request.CurrentValue is { ValueKind: not JsonValueKind.Undefined and not JsonValueKind.Null } explicitValue)
        {
            return ParseExplicit(explicitValue);
        }

        if (request.SetCurrentValue is null ||
            request.SetCurrentValue.Value.ValueKind is JsonValueKind.Undefined or JsonValueKind.Null)
        {
            return CurrentValueSetting.Median;
        }

        var element = request.SetCurrentValue.Value;
        if (element.ValueKind == JsonValueKind.String)
        {
            var text = element.GetString();
            if (string.Equals(text, "median", StringComparison.OrdinalIgnoreCase))
            {
                return CurrentValueSetting.Median;
            }

            if (decimal.TryParse(text, NumberStyles.Number, CultureInfo.InvariantCulture, out var amount))
            {
                return CurrentValueSetting.Explicit(amount);
            }

            return CurrentValueSetting.Invalid;
        }

        if (element.ValueKind == JsonValueKind.Number && element.TryGetDecimal(out var number))
        {
            return CurrentValueSetting.Explicit(number);
        }

        return CurrentValueSetting.Invalid;
    }

    public static bool Truthy(JsonElement? value, bool defaultValue)
    {
        if (value is null || value.Value.ValueKind is JsonValueKind.Undefined or JsonValueKind.Null)
        {
            return defaultValue;
        }

        return value.Value.ValueKind switch
        {
            JsonValueKind.True => true,
            JsonValueKind.False => false,
            JsonValueKind.Number => value.Value.GetInt32() != 0,
            JsonValueKind.String => value.Value.GetString() is "true" or "1",
            _ => defaultValue
        };
    }

    private static CurrentValueSetting ParseExplicit(JsonElement element)
    {
        if (element.ValueKind == JsonValueKind.Number && element.TryGetDecimal(out var number))
        {
            return CurrentValueSetting.Explicit(number);
        }

        if (element.ValueKind == JsonValueKind.String &&
            decimal.TryParse(element.GetString(), NumberStyles.Number, CultureInfo.InvariantCulture, out var parsed))
        {
            return CurrentValueSetting.Explicit(parsed);
        }

        return CurrentValueSetting.Invalid;
    }

    private static int? PositiveInt(string? value) =>
        int.TryParse(value, NumberStyles.Integer, CultureInfo.InvariantCulture, out var parsed) && parsed > 0
            ? parsed
            : null;
}
