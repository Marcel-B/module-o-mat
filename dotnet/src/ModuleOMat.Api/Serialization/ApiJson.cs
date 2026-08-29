using System.Globalization;
using System.Text.Json;
using System.Text.Json.Serialization;
using ModuleOMat.Domain;

namespace ModuleOMat.Api.Serialization;

public sealed class TwoPlaceDecimalConverter : JsonConverter<decimal>
{
    public override decimal Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options) =>
        reader.TokenType == JsonTokenType.String
            ? decimal.Parse(reader.GetString()!, CultureInfo.InvariantCulture)
            : reader.GetDecimal();

    public override void Write(Utf8JsonWriter writer, decimal value, JsonSerializerOptions options) =>
        writer.WriteNumberValue(decimal.Round(value, 2));
}

public sealed class TwoPlaceNullableDecimalConverter : JsonConverter<decimal?>
{
    public override decimal? Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
    {
        if (reader.TokenType == JsonTokenType.Null)
        {
            return null;
        }

        return reader.TokenType == JsonTokenType.String
            ? decimal.Parse(reader.GetString()!, CultureInfo.InvariantCulture)
            : reader.GetDecimal();
    }

    public override void Write(Utf8JsonWriter writer, decimal? value, JsonSerializerOptions options)
    {
        if (value is null)
        {
            writer.WriteNullValue();
        }
        else
        {
            writer.WriteNumberValue(decimal.Round(value.Value, 2));
        }
    }
}

public sealed record YoutubeVideoDto(int Id, string Url, int Position);

public sealed record PriceObservationDto(
    int Id,
    decimal Amount,
    string Currency,
    string Source,
    string? SourceUrl,
    DateOnly ObservedOn,
    string? Notes);

public sealed record PriceRangeDto(decimal Min, decimal Max, int Count, DateOnly LastObservedOn);

public sealed record ModuleDto(
    int Id,
    string Manufacturer,
    string Name,
    int Hp,
    string Type,
    IReadOnlyList<string> Subtypes,
    int? CurrentDrawPlus12vMa,
    int? CurrentDrawMinus12vMa,
    int? CurrentDrawPlus5vMa,
    int? DepthMm,
    string? Description,
    string? ManualUrl,
    decimal? PurchasePrice,
    decimal? CurrentValue,
    bool HasManual,
    string? ManualPdfFilename,
    string? ManualPdfContentType,
    int? ManualPdfSizeBytes,
    IReadOnlyList<YoutubeVideoDto> YoutubeVideos,
    PriceRangeDto? PriceRange,
    DateTime InsertedAt,
    DateTime UpdatedAt,
    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    IReadOnlyList<PriceObservationDto>? PriceObservations = null);

public sealed record ValuationModuleDto(
    int Id,
    string Manufacturer,
    string Name,
    int Hp,
    decimal? CurrentValue,
    PriceRangeDto? PriceRange);

public sealed record InventoryStatsDto(
    int Count,
    int TotalHp,
    decimal TotalWidthMm,
    decimal TotalWidthCm,
    decimal TotalWidthM,
    decimal TotalPurchasePrice,
    decimal TotalCurrentValue);

public sealed record ModuleTypeDto(int Id, string Name, bool Fallback, bool Used);

public sealed record BackupRunDto(int Id, DateTime OccurredAt, string? Filename, long? SizeBytes, bool Success);

public sealed record BackupHistoryDto(
    IReadOnlyList<BackupRunDto> BackupRuns,
    int Page,
    int PerPage,
    int Total,
    DateTime? LastSuccessAt,
    DateTime? LastFailureAt);

public sealed record ErrorDto(
    string Error,
    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    IReadOnlyDictionary<string, object>? Details = null);

public static class ApiJson
{
    public static ErrorDto Error(AppError error) => new(error.Message, error.Details);

    public static IResult ToHttp(AppError error) =>
        error.Kind switch
        {
            ErrorKind.NotFound => Results.Json(Error(error), statusCode: StatusCodes.Status404NotFound),
            ErrorKind.Maintenance => Results.Json(Error(error), statusCode: StatusCodes.Status503ServiceUnavailable),
            _ => Results.Json(Error(error), statusCode: StatusCodes.Status422UnprocessableEntity)
        };

    public static ModuleDto Module(EurorackModule module, PriceRange? range = null, bool includeObservations = false) =>
        new(
            module.Id,
            module.Manufacturer,
            module.Name,
            module.Hp,
            module.Type,
            module.Subtypes,
            module.CurrentDrawPlus12VMa,
            module.CurrentDrawMinus12VMa,
            module.CurrentDrawPlus5VMa,
            module.DepthMm,
            module.Description,
            module.ManualUrl,
            Round(module.PurchasePrice),
            Round(module.CurrentValue),
            module.HasManual,
            module.ManualPdfFilename,
            module.ManualPdfContentType,
            module.ManualPdfSizeBytes,
            module.YoutubeVideos.Select(v => new YoutubeVideoDto(v.Id, v.Url, v.Position)).ToArray(),
            PriceRange(range),
            module.InsertedAt,
            module.UpdatedAt,
            includeObservations && module.PriceObservations is not null
                ? module.PriceObservations.Select(Observation).ToArray()
                : null);

    public static ValuationModuleDto ValuationModule(EurorackModule module, PriceRange? range) =>
        new(module.Id, module.Manufacturer, module.Name, module.Hp, Round(module.CurrentValue), PriceRange(range));

    public static PriceObservationDto Observation(PriceObservation observation) =>
        new(
            observation.Id,
            Round(observation.Amount),
            observation.Currency,
            observation.Source,
            observation.SourceUrl,
            observation.ObservedOn,
            observation.Notes);

    public static PriceRangeDto? PriceRange(PriceRange? range) =>
        range is null
            ? null
            : new(Round(range.Min), Round(range.Max), range.Count, range.LastObservedOn);

    public static InventoryStatsDto Stats(InventoryStats stats) =>
        new(
            stats.Count,
            stats.TotalHp,
            Round(stats.TotalWidthMm),
            Round(stats.TotalWidthCm),
            Round(stats.TotalWidthM),
            Round(stats.TotalPurchasePrice),
            Round(stats.TotalCurrentValue));

    public static ModuleTypeDto ModuleType(ModuleTypeRecord type, bool fallback, bool used) =>
        new(type.Id, type.Name, fallback, used);

    public static BackupRunDto BackupRun(BackupRun run) =>
        new(run.Id, run.OccurredAt, run.Filename, run.SizeBytes, run.Success);

    public static BackupHistoryDto BackupHistory(BackupHistoryPage page) =>
        new(
            page.BackupRuns.Select(BackupRun).ToArray(),
            page.Page,
            page.PerPage,
            page.Total,
            page.LastSuccessAt,
            page.LastFailureAt);

    private static decimal? Round(decimal? value) => value is null ? null : decimal.Round(value.Value, 2);
    private static decimal Round(decimal value) => decimal.Round(value, 2);
}
