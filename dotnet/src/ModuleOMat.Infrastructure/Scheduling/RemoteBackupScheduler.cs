using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using ModuleOMat.Domain;
using ModuleOMat.Infrastructure.Backup;

namespace ModuleOMat.Infrastructure.Scheduling;

public sealed class RemoteBackupScheduler(
    WriteGate gate,
    IServiceScopeFactory scopes,
    NextcloudOptions options,
    ILogger<RemoteBackupScheduler> logger) : BackgroundService
{
    private static readonly TimeSpan Tick = TimeSpan.FromSeconds(60);
    private static readonly TimeSpan RetryAfter = TimeSpan.FromMinutes(15);
    private static readonly TimeSpan Timeout = TimeSpan.FromMinutes(20);
    private static readonly TimeSpan Grace = TimeSpan.FromSeconds(2);

    private readonly object _sync = new();
    private CancellationTokenSource? _idleCts;
    private DateOnly? _lastRunDate;
    private long? _lastFailureMs;
    private bool _pendingAfterChange;

    private bool Enabled =>
        options.Enabled &&
        !string.IsNullOrWhiteSpace(options.WebDavUrl) &&
        !string.IsNullOrWhiteSpace(options.Username) &&
        !string.IsNullOrWhiteSpace(options.AppPassword);

    private TimeZoneInfo TimeZone => TimeZoneInfo.FindSystemTimeZoneById(options.Timezone);

    private TimeOnly At => TimeOnly.TryParse(options.BackupAt, out var at) ? at : new TimeOnly(3, 0);

    private TimeSpan IdleAfter => TimeSpan.FromMinutes(Math.Max(options.IdleMinutes, 0));

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        if (!Enabled)
        {
            logger.LogInformation("Nextcloud-Backup-Scheduler deaktiviert");
            return;
        }

        gate.SetChangeHandler(ScheduleAfterChange);
        _lastRunDate = ReadStamp();
        logger.LogInformation(
            "Nextcloud-Backup-Scheduler aktiv (taeglich {At} {Tz}, nach Aenderungen {Idle} min)",
            options.BackupAt,
            options.Timezone,
            options.IdleMinutes);

        await MaybeRun(stoppingToken).ConfigureAwait(false);

        using var timer = new PeriodicTimer(Tick);
        try
        {
            while (await timer.WaitForNextTickAsync(stoppingToken).ConfigureAwait(false))
            {
                await MaybeRun(stoppingToken).ConfigureAwait(false);
            }
        }
        catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
        {
        }
    }

    public void ScheduleAfterChange()
    {
        if (!Enabled)
        {
            return;
        }

        if (gate.IsMaintenance)
        {
            lock (_sync)
            {
                _pendingAfterChange = true;
            }

            return;
        }

        CancelIdle();
        var cts = new CancellationTokenSource();
        lock (_sync)
        {
            _idleCts = cts;
            _pendingAfterChange = false;
        }

        _ = RunIdle(cts.Token);
    }

    private async Task RunIdle(CancellationToken token)
    {
        try
        {
            await Task.Delay(IdleAfter, token).ConfigureAwait(false);
        }
        catch (OperationCanceledException)
        {
            return;
        }

        if (gate.IsMaintenance)
        {
            lock (_sync)
            {
                _pendingAfterChange = true;
            }

            return;
        }

        await ExecuteBackup("idle", token).ConfigureAwait(false);
    }

    private async Task MaybeRun(CancellationToken token)
    {
        if (gate.IsMaintenance)
        {
            return;
        }

        var now = DateTime.UtcNow;
        var localToday = DateOnly.FromDateTime(TimeZoneInfo.ConvertTimeFromUtc(now, TimeZone));
        if (_lastRunDate == localToday)
        {
            return;
        }

        var local = TimeZoneInfo.ConvertTimeFromUtc(now, TimeZone);
        if (local < local.Date.Add(At.ToTimeSpan()))
        {
            return;
        }

        if (_lastFailureMs is long failure &&
            Environment.TickCount64 - failure < (long)RetryAfter.TotalMilliseconds)
        {
            return;
        }

        await ExecuteBackup("daily", token).ConfigureAwait(false);
    }

    private async Task ExecuteBackup(string kind, CancellationToken token)
    {
        gate.SetMaintenance(true);
        logger.LogInformation("Nextcloud-Backup startet ({Kind}), UI im Wartungsmodus", kind);
        try
        {
            if (Grace > TimeSpan.Zero)
            {
                await Task.Delay(Grace, token).ConfigureAwait(false);
            }

            while (gate.HasInFlightWrites)
            {
                await Task.Delay(50, token).ConfigureAwait(false);
            }

            gate.SetRunning(true);
            using var timeoutCts = CancellationTokenSource.CreateLinkedTokenSource(token);
            timeoutCts.CancelAfter(Timeout);
            await using var scope = scopes.CreateAsyncScope();
            var runner = scope.ServiceProvider.GetRequiredService<RemoteBackupRunner>();
            var result = await runner.Run(timeoutCts.Token).ConfigureAwait(false);
            if (result.IsOk && kind == "daily")
            {
                var localToday = DateOnly.FromDateTime(TimeZoneInfo.ConvertTimeFromUtc(DateTime.UtcNow, TimeZone));
                WriteStamp(localToday);
                _lastRunDate = localToday;
                _lastFailureMs = null;
            }
            else if (result.IsError && kind == "daily")
            {
                _lastFailureMs = Environment.TickCount64;
            }
        }
        catch (OperationCanceledException) when (!token.IsCancellationRequested)
        {
            logger.LogError("Nextcloud-Backup-Lauf fehlgeschlagen: timeout");
            await RecordUnfinished(token).ConfigureAwait(false);
            if (kind == "daily")
            {
                _lastFailureMs = Environment.TickCount64;
            }
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Nextcloud-Backup-Lauf fehlgeschlagen");
            await RecordUnfinished(CancellationToken.None).ConfigureAwait(false);
            if (kind == "daily")
            {
                _lastFailureMs = Environment.TickCount64;
            }
        }
        finally
        {
            gate.SetRunning(false);
            gate.SetMaintenance(false);
        }

        bool pending;
        lock (_sync)
        {
            pending = _pendingAfterChange;
            _pendingAfterChange = false;
        }

        if (pending)
        {
            ScheduleAfterChange();
        }
    }

    private async Task RecordUnfinished(CancellationToken token)
    {
        try
        {
            await using var scope = scopes.CreateAsyncScope();
            var runner = scope.ServiceProvider.GetRequiredService<RemoteBackupRunner>();
            await runner.RecordFailure(BackupOperations.WeekdayFilename(DateTime.UtcNow, TimeZone), token)
                .ConfigureAwait(false);
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Sicherungshistorie konnte nicht gespeichert werden");
        }
    }

    private void CancelIdle()
    {
        lock (_sync)
        {
            _idleCts?.Cancel();
            _idleCts?.Dispose();
            _idleCts = null;
        }
    }

    private string? StampPath
    {
        get
        {
            var db = Environment.GetEnvironmentVariable("DATABASE_PATH");
            return string.IsNullOrWhiteSpace(db)
                ? null
                : Path.Combine(Path.GetDirectoryName(Path.GetFullPath(db)) ?? ".", "last_remote_backup_date");
        }
    }

    private DateOnly? ReadStamp()
    {
        var path = StampPath;
        if (path is null || !File.Exists(path))
        {
            return null;
        }

        return DateOnly.TryParse(File.ReadAllText(path).Trim(), out var date) ? date : null;
    }

    private void WriteStamp(DateOnly date)
    {
        var path = StampPath;
        if (path is null)
        {
            return;
        }

        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        File.WriteAllText(path, date.ToString("yyyy-MM-dd") + "\n");
    }
}
