namespace ModuleOMat.Domain;

public sealed record YoutubeVideoInput(string Url);

public sealed record ModuleInput(
    string? Manufacturer,
    string? Name,
    int? Hp,
    string? Type,
    IReadOnlyList<string>? Subtypes,
    int? CurrentDrawPlus12VMa,
    int? CurrentDrawMinus12VMa,
    int? CurrentDrawPlus5VMa,
    int? DepthMm,
    string? Description,
    string? ManualUrl,
    decimal? PurchasePrice,
    decimal? CurrentValue,
    IReadOnlyList<YoutubeVideoInput>? YoutubeVideos);

public sealed record ValidatedModule(
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
    IReadOnlyList<ValidatedYoutubeVideo> YoutubeVideos);

public sealed record ValidatedYoutubeVideo(string Url, int Position);

public static class ModuleValidation
{
    public static Result<ValidatedModule> Validate(ModuleInput input, bool requireCoreFields)
    {
        var details = new Dictionary<string, object>(StringComparer.Ordinal);

        var manufacturer = TrimOrNull(input.Manufacturer);
        var name = TrimOrNull(input.Name);
        var type = TrimOrNull(input.Type);

        if (requireCoreFields)
        {
            Require(details, "manufacturer", manufacturer);
            Require(details, "name", name);
            if (input.Hp is null)
            {
                details["hp"] = new[] { "muss ausgefuellt werden" };
            }

            Require(details, "type", type);
        }
        else
        {
            if (input.Manufacturer is not null)
            {
                Require(details, "manufacturer", manufacturer);
            }

            if (input.Name is not null)
            {
                Require(details, "name", name);
            }

            if (input.Type is not null)
            {
                Require(details, "type", type);
            }
        }

        ValidateNonNegative(details, "hp", input.Hp, greaterThanZero: true);
        ValidateNonNegative(details, "current_draw_plus12v_ma", input.CurrentDrawPlus12VMa);
        ValidateNonNegative(details, "current_draw_minus12v_ma", input.CurrentDrawMinus12VMa);
        ValidateNonNegative(details, "current_draw_plus5v_ma", input.CurrentDrawPlus5VMa);
        ValidateNonNegative(details, "depth_mm", input.DepthMm);
        ValidateNonNegative(details, "purchase_price", input.PurchasePrice);
        ValidateNonNegative(details, "current_value", input.CurrentValue);

        var videos = new List<ValidatedYoutubeVideo>();
        if (input.YoutubeVideos is not null)
        {
            var videoErrors = new List<object?>();
            var hasVideoError = false;
            for (var i = 0; i < input.YoutubeVideos.Count; i++)
            {
                var url = TrimOrNull(input.YoutubeVideos[i].Url);
                if (url is null)
                {
                    hasVideoError = true;
                    videoErrors.Add(new Dictionary<string, string[]>
                    {
                        ["url"] = ["muss ausgefuellt werden"]
                    });
                    continue;
                }

                var watch = Youtube.WatchUrl(url);
                if (watch is null)
                {
                    hasVideoError = true;
                    videoErrors.Add(new Dictionary<string, string[]>
                    {
                        ["url"] = ["muss eine gueltige YouTube-URL sein"]
                    });
                    continue;
                }

                videoErrors.Add(null);
                videos.Add(new ValidatedYoutubeVideo(watch, i));
            }

            if (hasVideoError)
            {
                details["youtube_videos"] = videoErrors;
            }
        }

        if (details.Count > 0)
        {
            return Result.Fail<ValidatedModule>(AppError.Validation(details));
        }

        return Result.Ok(new ValidatedModule(
            manufacturer ?? string.Empty,
            name ?? string.Empty,
            input.Hp ?? 0,
            type ?? string.Empty,
            TypeRules.NormalizeSubtypes(input.Subtypes, type),
            input.CurrentDrawPlus12VMa,
            input.CurrentDrawMinus12VMa,
            input.CurrentDrawPlus5VMa,
            input.DepthMm,
            TrimOrNull(input.Description),
            TrimOrNull(input.ManualUrl),
            input.PurchasePrice,
            input.CurrentValue,
            videos));
    }

    public static Result<string> ValidateTypeName(string? name)
    {
        var trimmed = TrimOrNull(name);
        if (trimmed is null)
        {
            return Result.Fail<string>(AppError.Validation(new Dictionary<string, object>
            {
                ["name"] = new[] { "muss ausgefuellt werden" }
            }));
        }

        return Result.Ok(trimmed);
    }

    public static Result<ObservationInput> ValidateObservation(ObservationInput input)
    {
        var details = new Dictionary<string, object>(StringComparer.Ordinal);
        var source = TrimOrNull(input.Source);
        if (source is null)
        {
            details["source"] = new[] { "muss ausgefuellt werden" };
        }
        else if (source.Length > 64)
        {
            details["source"] = new[] { "darf hoechstens 64 Zeichen lang sein" };
        }

        if (input.Amount < 0)
        {
            details["amount"] = new[] { "darf nicht negativ sein" };
        }

        var currency = TrimOrNull(input.Currency) ?? "EUR";
        if (currency.Length > 8)
        {
            details["currency"] = new[] { "darf hoechstens 8 Zeichen lang sein" };
        }

        if (details.Count > 0)
        {
            return Result.Fail<ObservationInput>(AppError.Validation(details));
        }

        return Result.Ok(input with
        {
            Source = source!,
            Currency = currency,
            SourceUrl = TrimOrNull(input.SourceUrl),
            Notes = TrimOrNull(input.Notes),
            ObservedOn = input.ObservedOn
        });
    }

    public static ModuleInput Overlay(EurorackModule existing, ModuleInput patch) =>
        new(
            patch.Manufacturer ?? existing.Manufacturer,
            patch.Name ?? existing.Name,
            patch.Hp ?? existing.Hp,
            patch.Type ?? existing.Type,
            patch.Subtypes ?? existing.Subtypes,
            patch.CurrentDrawPlus12VMa ?? existing.CurrentDrawPlus12VMa,
            patch.CurrentDrawMinus12VMa ?? existing.CurrentDrawMinus12VMa,
            patch.CurrentDrawPlus5VMa ?? existing.CurrentDrawPlus5VMa,
            patch.DepthMm ?? existing.DepthMm,
            patch.Description ?? existing.Description,
            patch.ManualUrl ?? existing.ManualUrl,
            patch.PurchasePrice ?? existing.PurchasePrice,
            patch.CurrentValue ?? existing.CurrentValue,
            patch.YoutubeVideos ?? existing.YoutubeVideos.Select(v => new YoutubeVideoInput(v.Url)).ToArray());

    public static ModuleInput FromModule(EurorackModule module) =>
        new(
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
            module.PurchasePrice,
            module.CurrentValue,
            module.YoutubeVideos.Select(v => new YoutubeVideoInput(v.Url)).ToArray());

    private static void Require(Dictionary<string, object> details, string field, string? value)
    {
        if (value is null)
        {
            details[field] = new[] { "muss ausgefuellt werden" };
        }
    }

    private static void ValidateNonNegative(
        Dictionary<string, object> details,
        string field,
        int? value,
        bool greaterThanZero = false)
    {
        if (value is null)
        {
            return;
        }

        if (greaterThanZero && value <= 0)
        {
            details[field] = new[] { "muss groesser als 0 sein" };
        }
        else if (!greaterThanZero && value < 0)
        {
            details[field] = new[] { "darf nicht negativ sein" };
        }
    }

    private static void ValidateNonNegative(Dictionary<string, object> details, string field, decimal? value)
    {
        if (value is < 0)
        {
            details[field] = new[] { "darf nicht negativ sein" };
        }
    }

    private static string? TrimOrNull(string? value)
    {
        if (value is null)
        {
            return null;
        }

        var trimmed = value.Trim();
        return trimmed.Length == 0 ? null : trimmed;
    }
}
