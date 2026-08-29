namespace ModuleOMat.Domain;

public sealed record EurorackModule(
    int Id,
    string Manufacturer,
    string Name,
    int Hp,
    string Type,
    IReadOnlyList<string> Subtypes,
    int? CurrentDrawPlus12VMa,
    int? CurrentDrawMinus12VMa,
    int? CurrentDrawPlus5VMa,
    int? DepthMm,
    string? Description,
    string? ManualUrl,
    decimal? PurchasePrice,
    decimal? CurrentValue,
    string? ManualPdfKey,
    string? ManualPdfFilename,
    string? ManualPdfContentType,
    int? ManualPdfSizeBytes,
    DateTime? DeletedAt,
    DateTime InsertedAt,
    DateTime UpdatedAt,
    IReadOnlyList<YoutubeVideo> YoutubeVideos,
    IReadOnlyList<PriceObservation>? PriceObservations = null)
{
    public bool HasManual => ManualPdfKey is not null;
}

public sealed record YoutubeVideo(int Id, string Url, int Position);

public sealed record ModuleTypeRecord(int Id, string Name, DateTime InsertedAt, DateTime UpdatedAt);

public sealed record PriceObservation(
    int Id,
    decimal Amount,
    string Currency,
    string Source,
    string? SourceUrl,
    DateOnly ObservedOn,
    string? Notes);

public sealed record PriceRange(decimal Min, decimal Max, int Count, DateOnly LastObservedOn);

public sealed record InventoryStats(
    int Count,
    int TotalHp,
    decimal TotalWidthMm,
    decimal TotalWidthCm,
    decimal TotalWidthM,
    decimal TotalPurchasePrice,
    decimal TotalCurrentValue);

public sealed record BackupRun(
    int Id,
    DateTime OccurredAt,
    string? Filename,
    long? SizeBytes,
    bool Success);

public sealed record BackupHistoryPage(
    IReadOnlyList<BackupRun> BackupRuns,
    int Page,
    int PerPage,
    int Total,
    DateTime? LastSuccessAt,
    DateTime? LastFailureAt);

public sealed record ModuleFilter(
    string? Q = null,
    IReadOnlyList<string>? Types = null,
    int? MinHp = null,
    int? MaxHp = null);

public sealed record ManualMeta(
    string Key,
    string Filename,
    string ContentType,
    int SizeBytes);

public sealed record ObservationInput(
    decimal Amount,
    string Source,
    string? Currency = null,
    string? SourceUrl = null,
    DateOnly? ObservedOn = null,
    string? Notes = null);

public sealed record CurrentValueSetting
{
    private CurrentValueSetting(Kind kind, decimal? amount)
    {
        ValueKind = kind;
        Amount = amount;
    }

    public enum Kind
    {
        Median,
        Unchanged,
        Explicit
    }

    public Kind ValueKind { get; }
    public decimal? Amount { get; }

    public static CurrentValueSetting Median { get; } = new(Kind.Median, null);
    public static CurrentValueSetting Unchanged { get; } = new(Kind.Unchanged, null);
    public static CurrentValueSetting Explicit(decimal amount) => new(Kind.Explicit, amount);
    public static CurrentValueSetting Invalid { get; } = new(Kind.Explicit, null);
}

public sealed record ValuationResult(
    EurorackModule Module,
    IReadOnlyList<PriceObservation> Observations,
    PriceRange? PriceRange);

public sealed record BackupSnapshot(
    IReadOnlyList<BackupTypeRow> Types,
    IReadOnlyList<BackupModuleRow> Modules,
    IReadOnlyList<BackupVideoRow> Videos,
    IReadOnlyList<BackupObservationRow> Observations);

public sealed record BackupTypeRow(int Id, string Name, DateTime InsertedAt, DateTime UpdatedAt);

public sealed record BackupModuleRow(
    int Id,
    string Manufacturer,
    string Name,
    int Hp,
    string Type,
    IReadOnlyList<string> Subtypes,
    int? CurrentDrawPlus12VMa,
    int? CurrentDrawMinus12VMa,
    int? CurrentDrawPlus5VMa,
    int? DepthMm,
    string? Description,
    string? ManualUrl,
    decimal? PurchasePrice,
    decimal? CurrentValue,
    string? ManualPdfKey,
    string? ManualPdfFilename,
    string? ManualPdfContentType,
    int? ManualPdfSizeBytes,
    DateTime InsertedAt,
    DateTime UpdatedAt);

public sealed record BackupVideoRow(
    int Id,
    int EurorackModuleId,
    string Url,
    int Position,
    DateTime InsertedAt,
    DateTime UpdatedAt);

public sealed record BackupObservationRow(
    int Id,
    int EurorackModuleId,
    decimal Amount,
    string Currency,
    string Source,
    string? SourceUrl,
    DateOnly ObservedOn,
    string? Notes,
    DateTime InsertedAt,
    DateTime UpdatedAt);
