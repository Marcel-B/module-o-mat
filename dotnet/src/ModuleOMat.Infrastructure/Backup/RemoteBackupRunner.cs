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
}

public sealed class RemoteBackupRunner(
    IInventoryStore store,
    IManualStorage manuals,
    IWebDavClient webDav,
    IClock clock,
    NextcloudOptions options,
    ILogger<RemoteBackupRunner> logger)
{
    public bool IsEnabled =>
        options.Enabled &&
        !string.IsNullOrWhiteSpace(options.WebDavUrl) &&
        !string.IsNullOrWhiteSpace(options.Username) &&
        !string.IsNullOrWhiteSpace(options.AppPassword);

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
