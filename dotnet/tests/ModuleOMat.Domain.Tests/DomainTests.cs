using ModuleOMat.Domain;

namespace ModuleOMat.Domain.Tests;

public class YoutubeTests
{
    [Theory]
    [InlineData("https://www.youtube.com/watch?v=abcdefghijk", "abcdefghijk")]
    [InlineData("https://youtu.be/abcdefghijk", "abcdefghijk")]
    [InlineData("https://www.youtube.com/embed/abcdefghijk", "abcdefghijk")]
    [InlineData("https://www.youtube.com/shorts/abcdefghijk", "abcdefghijk")]
    public void Extracts_video_id(string url, string expected) =>
        Assert.Equal(expected, Youtube.VideoId(url));

    [Fact]
    public void Normalizes_watch_url() =>
        Assert.Equal("https://www.youtube.com/watch?v=abcdefghijk", Youtube.WatchUrl("https://youtu.be/abcdefghijk"));

    [Fact]
    public void Rejects_invalid_urls() =>
        Assert.False(Youtube.ValidUrl("https://example.com/watch?v=abcdefghijk"));
}

public class PricingTests
{
    [Fact]
    public void Median_of_one() =>
        Assert.Equal(10m, Pricing.MedianAmount([10m]));

    [Fact]
    public void Median_of_odd() =>
        Assert.Equal(20m, Pricing.MedianAmount([10m, 30m, 20m]));

    [Fact]
    public void Median_of_even_averages_middle() =>
        Assert.Equal(15m, Pricing.MedianAmount([10m, 20m]));
}

public class StatsTests
{
    [Fact]
    public void Computes_hp_width()
    {
        var stats = Stats.FromModules(
        [
            Module("A", 20, 100m, 80m),
            Module("B", 8, null, 20m)
        ]);

        Assert.Equal(2, stats.Count);
        Assert.Equal(28, stats.TotalHp);
        Assert.Equal(28m * 5.08m, stats.TotalWidthMm);
        Assert.Equal(100m, stats.TotalPurchasePrice);
        Assert.Equal(100m, stats.TotalCurrentValue);
    }

    [Fact]
    public void Filter_matches_subtype()
    {
        var module = Module("Maths", 20, null, null) with { Type = "Envelope", Subtypes = ["LFO"] };
        Assert.True(Stats.Matches(module, new ModuleFilter(Types: ["LFO"])));
        Assert.False(Stats.Matches(module, new ModuleFilter(Types: ["VCO"])));
    }

    [Fact]
    public void Filter_excludes_soft_deleted()
    {
        var module = Module("X", 4, null, null) with { DeletedAt = DateTime.UtcNow };
        Assert.False(Stats.Matches(module, new ModuleFilter()));
    }

    private static EurorackModule Module(string name, int hp, decimal? purchase, decimal? value) =>
        new(
            1, "Make Noise", name, hp, "Utility", [],
            null, null, null, null, null, null, purchase, value,
            null, null, null, null, null,
            DateTime.UtcNow, DateTime.UtcNow, []);
}

public class TypeRulesTests
{
    [Fact]
    public void Fallback_cannot_be_renamed() =>
        Assert.True(TypeRules.IsFallback("Sonstiges"));

    [Fact]
    public void Removes_haupttyp_from_subtypes() =>
        Assert.Equal(["LFO"], TypeRules.NormalizeSubtypes(["LFO", "Envelope", "LFO"], "Envelope"));

    [Fact]
    public void Replace_and_remove_subtype()
    {
        Assert.Equal(["VCA"], TypeRules.ReplaceSubtype(["VCO"], "VCO", "VCA", "Envelope"));
        Assert.Empty(TypeRules.RemoveSubtype(["VCO"], "VCO"));
    }
}

public class ModuleValidationTests
{
    [Fact]
    public void Requires_core_fields()
    {
        var result = ModuleValidation.Validate(
            new ModuleInput(null, null, null, null, null, null, null, null, null, null, null, null, null, null),
            true);
        Assert.True(result.IsError);
        Assert.Equal(ErrorKind.Validation, result.Error.Kind);
        Assert.Contains("name", result.Error.Details!.Keys);
    }

    [Fact]
    public void Rejects_non_positive_hp()
    {
        var result = ModuleValidation.Validate(Valid() with { Hp = 0 }, true);
        Assert.True(result.IsError);
        Assert.Contains("hp", result.Error.Details!.Keys);
    }

    [Fact]
    public void Normalizes_youtube_url()
    {
        var result = ModuleValidation.Validate(
            Valid() with { YoutubeVideos = [new YoutubeVideoInput("https://youtu.be/abcdefghijk")] },
            true);
        Assert.True(result.IsOk);
        Assert.Equal("https://www.youtube.com/watch?v=abcdefghijk", result.Value.YoutubeVideos[0].Url);
    }

    private static ModuleInput Valid() =>
        new("Intellijel", "Quad VCA", 12, "VCA", ["Mixer"], 50, 10, null, 40, "desc", null, 199m, 180m, []);
}

public class BackupCsvTests
{
    [Fact]
    public void Roundtrips_module_row()
    {
        var row = new BackupModuleRow(
            3, "Make Noise", "Maths", 20, "Envelope", ["LFO", "Utility"],
            55, 30, null, 35, "fg", "https://example.com", 289.50m, 250m,
            "key", "maths.pdf", "application/pdf", 12,
            new DateTime(2026, 8, 1, 10, 0, 0, DateTimeKind.Utc),
            new DateTime(2026, 8, 2, 10, 0, 0, DateTimeKind.Utc));
        var csv = BackupCsv.Dump(BackupCsv.ModuleHeaders, [BackupCsv.ModuleRow(row)]);
        var parsed = BackupCsv.Parse(csv, BackupCsv.ModuleHeaders, BackupCsv.ModulesFile);
        var back = BackupCsv.ToModule(parsed[0]);
        Assert.Equal(row.Name, back.Name);
        Assert.Equal(row.Subtypes, back.Subtypes);
        Assert.Equal(row.PurchasePrice, back.PurchasePrice);
    }
}

public class BackupOperationsTests
{
    [Fact]
    public void Weekday_filename_uses_timezone()
    {
        var tz = TimeZoneInfo.FindSystemTimeZoneById("Europe/Berlin");
        var utc = new DateTime(2026, 8, 29, 22, 0, 0, DateTimeKind.Utc);
        Assert.Equal("inventory-sun.zip", BackupOperations.WeekdayFilename(utc, tz));
    }
}
