using System.Globalization;
using System.Text;

namespace ModuleOMat.Domain;

public static class BackupCsv
{
    public const string ModuleTypesFile = "module_types.csv";
    public const string ModulesFile = "eurorack_modules.csv";
    public const string VideosFile = "youtube_videos.csv";
    public const string ObservationsFile = "module_price_observations.csv";
    public const string ManualsDir = "manuals";

    public static readonly string[] ModuleTypeHeaders = ["id", "name", "inserted_at", "updated_at"];

    public static readonly string[] ModuleHeaders =
    [
        "id", "manufacturer", "name", "hp", "type", "subtypes",
        "current_draw_plus12v_ma", "current_draw_minus12v_ma", "current_draw_plus5v_ma",
        "depth_mm", "description", "manual_url", "purchase_price", "current_value",
        "manual_pdf_key", "manual_pdf_filename", "manual_pdf_content_type", "manual_pdf_size_bytes",
        "inserted_at", "updated_at"
    ];

    public static readonly string[] VideoHeaders =
        ["id", "eurorack_module_id", "url", "position", "inserted_at", "updated_at"];

    public static readonly string[] ObservationHeaders =
    [
        "id", "eurorack_module_id", "amount", "currency", "source", "source_url", "observed_on", "notes",
        "inserted_at", "updated_at"
    ];

    public static string Dump(IReadOnlyList<string> headers, IEnumerable<IReadOnlyList<string>> rows)
    {
        var builder = new StringBuilder();
        WriteRow(builder, headers);
        foreach (var row in rows)
        {
            WriteRow(builder, row);
        }

        return builder.ToString();
    }

    public static IReadOnlyList<IReadOnlyDictionary<string, string>> Parse(
        string content,
        IReadOnlyList<string> expectedHeaders,
        string filename)
    {
        var rows = ParseRows(content);
        if (rows.Count == 0)
        {
            return [];
        }

        var headers = rows[0];
        if (!headers.SequenceEqual(expectedHeaders))
        {
            throw new InvalidOperationException($"Unerwartete CSV-Header in {filename}: [{string.Join(", ", headers)}]");
        }

        return rows.Skip(1)
            .Select(row =>
            {
                var map = new Dictionary<string, string>(StringComparer.Ordinal);
                for (var i = 0; i < expectedHeaders.Count; i++)
                {
                    map[expectedHeaders[i]] = i < row.Count ? row[i] : string.Empty;
                }

                return (IReadOnlyDictionary<string, string>)map;
            })
            .ToArray();
    }

    public static string Cell(object? value) =>
        value switch
        {
            null => string.Empty,
            decimal number => number.ToString(CultureInfo.InvariantCulture),
            DateOnly date => date.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture),
            DateTime dateTime => dateTime.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ", CultureInfo.InvariantCulture),
            IFormattable formattable => formattable.ToString(null, CultureInfo.InvariantCulture) ?? string.Empty,
            _ => value.ToString() ?? string.Empty
        };

    public static string Subtypes(IEnumerable<string>? subtypes) =>
        subtypes is null ? string.Empty : string.Join("|", subtypes);

    public static IReadOnlyList<string> ParseSubtypes(string? value) =>
        string.IsNullOrWhiteSpace(value)
            ? []
            : value.Split('|', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);

    public static int RequiredInt(IReadOnlyDictionary<string, string> row, string field)
    {
        if (!int.TryParse(row.GetValueOrDefault(field), NumberStyles.Integer, CultureInfo.InvariantCulture, out var value))
        {
            throw new InvalidOperationException($"Ungueltige Ganzzahl in {field}: {row.GetValueOrDefault(field)}");
        }

        return value;
    }

    public static int? OptionalInt(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return null;
        }

        if (!int.TryParse(value, NumberStyles.Integer, CultureInfo.InvariantCulture, out var parsed))
        {
            throw new InvalidOperationException($"Ungueltige Ganzzahl: {value}");
        }

        return parsed;
    }

    public static decimal RequiredDecimal(IReadOnlyDictionary<string, string> row, string field)
    {
        var value = row.GetValueOrDefault(field);
        if (string.IsNullOrWhiteSpace(value) ||
            !decimal.TryParse(value, NumberStyles.Number, CultureInfo.InvariantCulture, out var parsed))
        {
            throw new InvalidOperationException($"Ungueltiger Dezimalwert in {field}: {value}");
        }

        return parsed;
    }

    public static decimal? OptionalDecimal(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return null;
        }

        if (!decimal.TryParse(value, NumberStyles.Number, CultureInfo.InvariantCulture, out var parsed))
        {
            throw new InvalidOperationException($"Ungueltiger Dezimalwert: {value}");
        }

        return parsed;
    }

    public static string RequiredString(IReadOnlyDictionary<string, string> row, string field)
    {
        var value = EmptyToNull(row.GetValueOrDefault(field));
        return value ?? throw new InvalidOperationException($"Pflichtfeld fehlt: {field}");
    }

    public static string? EmptyToNull(string? value) =>
        string.IsNullOrWhiteSpace(value) ? null : value;

    public static DateTime RequiredDateTime(IReadOnlyDictionary<string, string> row, string field)
    {
        var value = row.GetValueOrDefault(field)?.Trim();
        if (string.IsNullOrEmpty(value))
        {
            throw new InvalidOperationException($"Pflichtfeld fehlt: {field}");
        }

        if (DateTimeOffset.TryParse(value, CultureInfo.InvariantCulture, DateTimeStyles.RoundtripKind, out var dto))
        {
            return dto.UtcDateTime;
        }

        if (DateTime.TryParse(value, CultureInfo.InvariantCulture, DateTimeStyles.RoundtripKind, out var parsed))
        {
            if (parsed.Kind == DateTimeKind.Unspecified)
            {
                return DateTime.SpecifyKind(parsed, DateTimeKind.Utc);
            }

            return parsed.ToUniversalTime();
        }

        throw new InvalidOperationException($"Ungueltiger Zeitstempel in {field}: {value}");
    }

    public static DateOnly RequiredDate(IReadOnlyDictionary<string, string> row, string field)
    {
        var value = row.GetValueOrDefault(field)?.Trim();
        if (!DateOnly.TryParse(value, CultureInfo.InvariantCulture, DateTimeStyles.None, out var parsed))
        {
            throw new InvalidOperationException($"Ungueltiges Datum in {field}: {value}");
        }

        return parsed;
    }

    public static BackupTypeRow ToType(IReadOnlyDictionary<string, string> row) =>
        new(
            RequiredInt(row, "id"),
            RequiredString(row, "name"),
            RequiredDateTime(row, "inserted_at"),
            RequiredDateTime(row, "updated_at"));

    public static BackupModuleRow ToModule(IReadOnlyDictionary<string, string> row) =>
        new(
            RequiredInt(row, "id"),
            RequiredString(row, "manufacturer"),
            RequiredString(row, "name"),
            RequiredInt(row, "hp"),
            RequiredString(row, "type"),
            ParseSubtypes(row.GetValueOrDefault("subtypes")),
            OptionalInt(row.GetValueOrDefault("current_draw_plus12v_ma")),
            OptionalInt(row.GetValueOrDefault("current_draw_minus12v_ma")),
            OptionalInt(row.GetValueOrDefault("current_draw_plus5v_ma")),
            OptionalInt(row.GetValueOrDefault("depth_mm")),
            EmptyToNull(row.GetValueOrDefault("description")),
            EmptyToNull(row.GetValueOrDefault("manual_url")),
            OptionalDecimal(row.GetValueOrDefault("purchase_price")),
            OptionalDecimal(row.GetValueOrDefault("current_value")),
            EmptyToNull(row.GetValueOrDefault("manual_pdf_key")),
            EmptyToNull(row.GetValueOrDefault("manual_pdf_filename")),
            EmptyToNull(row.GetValueOrDefault("manual_pdf_content_type")),
            OptionalInt(row.GetValueOrDefault("manual_pdf_size_bytes")),
            RequiredDateTime(row, "inserted_at"),
            RequiredDateTime(row, "updated_at"));

    public static BackupVideoRow ToVideo(IReadOnlyDictionary<string, string> row) =>
        new(
            RequiredInt(row, "id"),
            RequiredInt(row, "eurorack_module_id"),
            RequiredString(row, "url"),
            RequiredInt(row, "position"),
            RequiredDateTime(row, "inserted_at"),
            RequiredDateTime(row, "updated_at"));

    public static BackupObservationRow ToObservation(IReadOnlyDictionary<string, string> row) =>
        new(
            RequiredInt(row, "id"),
            RequiredInt(row, "eurorack_module_id"),
            RequiredDecimal(row, "amount"),
            EmptyToNull(row.GetValueOrDefault("currency")) ?? "EUR",
            RequiredString(row, "source"),
            EmptyToNull(row.GetValueOrDefault("source_url")),
            RequiredDate(row, "observed_on"),
            EmptyToNull(row.GetValueOrDefault("notes")),
            RequiredDateTime(row, "inserted_at"),
            RequiredDateTime(row, "updated_at"));

    public static string[] TypeRow(BackupTypeRow row) =>
        [Cell(row.Id), Cell(row.Name), Cell(row.InsertedAt), Cell(row.UpdatedAt)];

    public static string[] ModuleRow(BackupModuleRow row) =>
    [
        Cell(row.Id), Cell(row.Manufacturer), Cell(row.Name), Cell(row.Hp), Cell(row.Type),
        Subtypes(row.Subtypes),
        Cell(row.CurrentDrawPlus12VMa), Cell(row.CurrentDrawMinus12VMa), Cell(row.CurrentDrawPlus5VMa),
        Cell(row.DepthMm), Cell(row.Description), Cell(row.ManualUrl),
        Cell(row.PurchasePrice), Cell(row.CurrentValue),
        Cell(row.ManualPdfKey), Cell(row.ManualPdfFilename), Cell(row.ManualPdfContentType),
        Cell(row.ManualPdfSizeBytes), Cell(row.InsertedAt), Cell(row.UpdatedAt)
    ];

    public static string[] VideoRow(BackupVideoRow row) =>
        [Cell(row.Id), Cell(row.EurorackModuleId), Cell(row.Url), Cell(row.Position), Cell(row.InsertedAt), Cell(row.UpdatedAt)];

    public static string[] ObservationRow(BackupObservationRow row) =>
    [
        Cell(row.Id), Cell(row.EurorackModuleId), Cell(row.Amount), Cell(row.Currency),
        Cell(row.Source), Cell(row.SourceUrl), Cell(row.ObservedOn), Cell(row.Notes),
        Cell(row.InsertedAt), Cell(row.UpdatedAt)
    ];

    private static void WriteRow(StringBuilder builder, IReadOnlyList<string> cells)
    {
        for (var i = 0; i < cells.Count; i++)
        {
            if (i > 0)
            {
                builder.Append(',');
            }

            builder.Append(Escape(cells[i]));
        }

        builder.Append('\n');
    }

    private static string Escape(string value)
    {
        if (value.Contains('"') || value.Contains(',') || value.Contains('\n') || value.Contains('\r'))
        {
            return $"\"{value.Replace("\"", "\"\"", StringComparison.Ordinal)}\"";
        }

        return value;
    }

    private static List<List<string>> ParseRows(string content)
    {
        var rows = new List<List<string>>();
        var row = new List<string>();
        var cell = new StringBuilder();
        var inQuotes = false;

        for (var i = 0; i < content.Length; i++)
        {
            var ch = content[i];
            if (inQuotes)
            {
                if (ch == '"')
                {
                    if (i + 1 < content.Length && content[i + 1] == '"')
                    {
                        cell.Append('"');
                        i++;
                    }
                    else
                    {
                        inQuotes = false;
                    }
                }
                else
                {
                    cell.Append(ch);
                }
            }
            else if (ch == '"')
            {
                inQuotes = true;
            }
            else if (ch == ',')
            {
                row.Add(cell.ToString());
                cell.Clear();
            }
            else if (ch is '\n' or '\r')
            {
                if (ch == '\r' && i + 1 < content.Length && content[i + 1] == '\n')
                {
                    i++;
                }

                row.Add(cell.ToString());
                cell.Clear();
                if (row.Count > 1 || row[0].Length > 0)
                {
                    rows.Add(row);
                }

                row = [];
            }
            else
            {
                cell.Append(ch);
            }
        }

        if (cell.Length > 0 || row.Count > 0)
        {
            row.Add(cell.ToString());
            rows.Add(row);
        }

        return rows;
    }
}
