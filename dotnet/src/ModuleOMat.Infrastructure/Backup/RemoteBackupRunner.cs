using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using ModuleOMat.Domain;
using ModuleOMat.Domain.Ports;

namespace ModuleOMat.Infrastructure.Backup;

public sealed class NextcloudOptions
{
    public bool Enabled { get; set; }
    public string? WebDavUrl { get; set; }
    public string? Username { get; set; }
    public string? AppPassword { get; set; }
    public string BackupAt { get; set; } = "03:00";
    public string Timezone { get; set; } = "Europe/Berlin";
    public int IdleMinutes { get; set; } = 10;
    public int HttpTimeoutSeconds { get; set; } = 300;
    public bool EnsureCollection { get; set; } = true;

    public bool IsConfigured =>
        Enabled &&
        !string.IsNullOrWhiteSpace(WebDavUrl) &&
        !string.IsNullOrWhiteSpace(Username) &&
        !string.IsNullOrWhiteSpace(AppPassword);

    public string? DisableReason
    {
        get
        {
            if (IsConfigured)
            {
                return null;
            }

            if (!Enabled)
            {
                return "NEXTCLOUD_BACKUP_ENABLED ist nicht aktiv";
            }

            if (string.IsNullOrWhiteSpace(WebDavUrl))
            {
                return "NEXTCLOUD_WEBDAV_URL fehlt";
            }

            if (string.IsNullOrWhiteSpace(Username))
            {
                return "NEXTCLOUD_USERNAME fehlt";
            }

            if (string.IsNullOrWhiteSpace(AppPassword))
            {
                return "NEXTCLOUD_APP_PASSWORD fehlt";
            }

            return "Konfiguration unvollstaendig";
        }
    }

    /// <summary>
    /// Liest Nextcloud-Optionen. Umgebungsvariablen haben Vorrang vor
    /// <c>appsettings.json</c>, leere JSON-Werte gelten als nicht gesetzt.
    /// </summary>
    public static NextcloudOptions Load(
        IConfiguration configuration,
        Func<string, string?>? getenv = null)
    {
        getenv ??= static name => Environment.GetEnvironmentVariable(name);

        return new NextcloudOptions
        {
            Enabled = ParseFlag(
                getenv("NEXTCLOUD_BACKUP_ENABLED"),
                configuration.GetValue("Nextcloud:Enabled", false)),
            WebDavUrl = FirstNonEmpty(getenv("NEXTCLOUD_WEBDAV_URL"), configuration["Nextcloud:WebDavUrl"]),
            Username = FirstNonEmpty(getenv("NEXTCLOUD_USERNAME"), configuration["Nextcloud:Username"]),
            AppPassword = FirstNonEmpty(getenv("NEXTCLOUD_APP_PASSWORD"), configuration["Nextcloud:AppPassword"]),
            BackupAt = FirstNonEmpty(getenv("NEXTCLOUD_BACKUP_AT"), configuration["Nextcloud:BackupAt"]) ?? "03:00",
            Timezone = FirstNonEmpty(getenv("NEXTCLOUD_BACKUP_TIMEZONE"), configuration["Nextcloud:Timezone"])
                ?? "Europe/Berlin",
            IdleMinutes = ParseInt(
                getenv("NEXTCLOUD_BACKUP_IDLE_MINUTES"),
                configuration.GetValue("Nextcloud:IdleMinutes", 10)),
            HttpTimeoutSeconds = ParseInt(
                getenv("NEXTCLOUD_BACKUP_HTTP_TIMEOUT_SECONDS"),
                configuration.GetValue("Nextcloud:HttpTimeoutSeconds", 300)),
            EnsureCollection = true
        };
    }

    public static string Normalize(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return "";
        }

        var trimmed = value.Trim();
        if (trimmed.Length >= 2 &&
            ((trimmed[0] == '"' && trimmed[^1] == '"') || (trimmed[0] == '\'' && trimmed[^1] == '\'')))
        {
            trimmed = trimmed[1..^1].Trim();
        }

        return trimmed;
    }

    public static bool ParseFlag(string? value, bool fallback)
    {
        var normalized = Normalize(value);
        if (normalized.Length == 0)
        {
            return fallback;
        }

        return normalized.Equals("1", StringComparison.OrdinalIgnoreCase)
            || normalized.Equals("true", StringComparison.OrdinalIgnoreCase)
            || normalized.Equals("yes", StringComparison.OrdinalIgnoreCase)
            || normalized.Equals("on", StringComparison.OrdinalIgnoreCase);
    }

    private static string? FirstNonEmpty(string? env, string? config)
    {
        var fromEnv = Normalize(env);
        if (fromEnv.Length > 0)
        {
            return fromEnv;
        }

        var fromConfig = Normalize(config);
        return fromConfig.Length > 0 ? fromConfig : null;
    }

    private static int ParseInt(string? env, int fallback)
    {
        var normalized = Normalize(env);
        return int.TryParse(normalized, out var parsed) ? parsed : fallback;
    }
}

public sealed class RemoteBackupRunner(
    IInventoryStore store,
    IManualStorage manuals,
    IWebDavClient webDav,
    IClock clock,
    NextcloudOptions options,
    ILogger<RemoteBackupRunner> logger)
{
    public bool IsEnabled => options.IsConfigured;

    public TimeZoneInfo TimeZone => TimeZoneInfo.FindSystemTimeZoneById(options.Timezone);

    public TimeOnly At => TimeOnly.TryParse(options.BackupAt, out var at) ? at : new TimeOnly(3, 0);

    public TimeSpan IdleAfter => TimeSpan.FromMinutes(Math.Max(options.IdleMinutes, 0));

    public TimeSpan HttpTimeout => TimeSpan.FromSeconds(Math.Max(options.HttpTimeoutSeconds, 1));

    public async Task<Result<string>> Run(CancellationToken cancellationToken)
    {
        if (!IsEnabled)
        {
            return Result.Fail<string>(AppError.Unprocessable("disabled"));
        }

        var timezone = TimeZone;
        var filename = BackupOperations.WeekdayFilename(clock.UtcNow, timezone);
        long? size = null;
        var tmp = Path.Combine(
            Path.GetTempPath(),
            $"module_o_mat_remote_{Path.GetFileNameWithoutExtension(filename)}_{Guid.NewGuid():N}.zip");

        try
        {
            var baseUrl = options.WebDavUrl!.TrimEnd('/');
            if (options.EnsureCollection)
            {
                var collection = await webDav
                    .EnsureCollection(baseUrl, options.Username!, options.AppPassword!, HttpTimeout, cancellationToken)
                    .ConfigureAwait(false);
                if (collection.IsError)
                {
                    await Record(filename, null, false, cancellationToken).ConfigureAwait(false);
                    return Result.Fail<string>(collection.Error);
                }
            }

            await BackupOperations.ExportToPath(store, manuals, tmp, cancellationToken).ConfigureAwait(false);
            size = new FileInfo(tmp).Length;
            logger.LogInformation("Nextcloud-Backup Upload startet: {Filename} ({Size} Bytes)", filename, size);

            var uploaded = await webDav
                .PutFile(baseUrl, filename, tmp, options.Username!, options.AppPassword!, HttpTimeout, cancellationToken)
                .ConfigureAwait(false);
            if (uploaded.IsError)
            {
                logger.LogError("Nextcloud-Backup fehlgeschlagen: {Reason}", uploaded.Error.Message);
                await Record(filename, size, false, cancellationToken).ConfigureAwait(false);
                return Result.Fail<string>(uploaded.Error);
            }

            logger.LogInformation("Nextcloud-Backup hochgeladen: {Filename}", filename);
            await Record(filename, size, true, cancellationToken).ConfigureAwait(false);
            return Result.Ok(filename);
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Nextcloud-Backup fehlgeschlagen");
            await Record(filename, size, false, cancellationToken).ConfigureAwait(false);
            return Result.Fail<string>(AppError.Unprocessable(ex.Message));
        }
        finally
        {
            if (File.Exists(tmp))
            {
                File.Delete(tmp);
            }
        }
    }

    public Task RecordFailure(string? filename, CancellationToken cancellationToken) =>
        Record(filename, null, false, cancellationToken);

    private Task Record(string? filename, long? size, bool success, CancellationToken cancellationToken) =>
        store.RecordBackupRun(filename, size, success, clock.UtcNow, cancellationToken);
}
