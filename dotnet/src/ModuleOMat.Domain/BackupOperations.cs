using System.IO.Compression;
using ModuleOMat.Domain.Ports;

namespace ModuleOMat.Domain;

public static class BackupOperations
{
    public static async Task ExportToPath(
        IInventoryStore store,
        IManualStorage manuals,
        string path,
        CancellationToken cancellationToken)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(path) ?? ".");
        var tmpRoot = CreateTempDir("export");
        try
        {
            var snapshot = await store.LoadSnapshot(cancellationToken).ConfigureAwait(false);
            await File.WriteAllTextAsync(
                    Path.Combine(tmpRoot, BackupCsv.ModuleTypesFile),
                    BackupCsv.Dump(BackupCsv.ModuleTypeHeaders, snapshot.Types.Select(BackupCsv.TypeRow)),
                    cancellationToken)
                .ConfigureAwait(false);
            await File.WriteAllTextAsync(
                    Path.Combine(tmpRoot, BackupCsv.ModulesFile),
                    BackupCsv.Dump(BackupCsv.ModuleHeaders, snapshot.Modules.Select(BackupCsv.ModuleRow)),
                    cancellationToken)
                .ConfigureAwait(false);
            await File.WriteAllTextAsync(
                    Path.Combine(tmpRoot, BackupCsv.VideosFile),
                    BackupCsv.Dump(BackupCsv.VideoHeaders, snapshot.Videos.Select(BackupCsv.VideoRow)),
                    cancellationToken)
                .ConfigureAwait(false);
            await File.WriteAllTextAsync(
                    Path.Combine(tmpRoot, BackupCsv.ObservationsFile),
                    BackupCsv.Dump(BackupCsv.ObservationHeaders, snapshot.Observations.Select(BackupCsv.ObservationRow)),
                    cancellationToken)
                .ConfigureAwait(false);

            var manualsDir = Path.Combine(tmpRoot, BackupCsv.ManualsDir);
            Directory.CreateDirectory(manualsDir);
            foreach (var key in snapshot.Modules.Select(m => m.ManualPdfKey).Where(key => key is not null).Distinct())
            {
                if (manuals.Exists(key!))
                {
                    await manuals.CopyOut(key!, Path.Combine(manualsDir, key!), cancellationToken).ConfigureAwait(false);
                }
            }

            if (File.Exists(path))
            {
                File.Delete(path);
            }

            ZipFile.CreateFromDirectory(tmpRoot, path, CompressionLevel.Fastest, includeBaseDirectory: false);
        }
        finally
        {
            Directory.Delete(tmpRoot, recursive: true);
        }
    }

    public static Task<Result<Unit>> ImportFromPath(
        IMaintenanceGate gate,
        IInventoryStore store,
        IManualStorage manuals,
        string path,
        CancellationToken cancellationToken) =>
        InventoryOperations.WithWrite(gate, async () =>
        {
            if (!File.Exists(path))
            {
                return Result.Fail(AppError.Unprocessable($"Backup-Datei nicht gefunden: {path}"));
            }

            var tmpRoot = CreateTempDir("import");
            try
            {
                ZipFile.ExtractToDirectory(path, tmpRoot);
                var contentRoot = ResolveContentRoot(tmpRoot);
                var types = BackupCsv.Parse(
                        await File.ReadAllTextAsync(Path.Combine(contentRoot, BackupCsv.ModuleTypesFile), cancellationToken)
                            .ConfigureAwait(false),
                        BackupCsv.ModuleTypeHeaders,
                        BackupCsv.ModuleTypesFile)
                    .Select(BackupCsv.ToType)
                    .ToArray();
                var modules = BackupCsv.Parse(
                        await File.ReadAllTextAsync(Path.Combine(contentRoot, BackupCsv.ModulesFile), cancellationToken)
                            .ConfigureAwait(false),
                        BackupCsv.ModuleHeaders,
                        BackupCsv.ModulesFile)
                    .Select(BackupCsv.ToModule)
                    .ToArray();
                var videos = BackupCsv.Parse(
                        await File.ReadAllTextAsync(Path.Combine(contentRoot, BackupCsv.VideosFile), cancellationToken)
                            .ConfigureAwait(false),
                        BackupCsv.VideoHeaders,
                        BackupCsv.VideosFile)
                    .Select(BackupCsv.ToVideo)
                    .ToArray();

                var observationsPath = Path.Combine(contentRoot, BackupCsv.ObservationsFile);
                var observations = File.Exists(observationsPath)
                    ? BackupCsv.Parse(
                            await File.ReadAllTextAsync(observationsPath, cancellationToken).ConfigureAwait(false),
                            BackupCsv.ObservationHeaders,
                            BackupCsv.ObservationsFile)
                        .Select(BackupCsv.ToObservation)
                        .ToArray()
                    : [];

                var snapshot = new BackupSnapshot(types, modules, videos, observations);
                await store.ReplaceInventory(snapshot, cancellationToken).ConfigureAwait(false);

                var manualsSource = Path.Combine(contentRoot, BackupCsv.ManualsDir);
                Directory.CreateDirectory(manualsSource);
                await manuals.ReplaceAll(manualsSource, cancellationToken).ConfigureAwait(false);
                return Result.Ok();
            }
            catch (Exception ex) when (ex is InvalidOperationException or InvalidDataException)
            {
                return Result.Fail(AppError.Unprocessable(ex.Message));
            }
            finally
            {
                Directory.Delete(tmpRoot, recursive: true);
            }
        });

    public static string WeekdayFilename(DateTime utcNow, TimeZoneInfo timezone)
    {
        var local = TimeZoneInfo.ConvertTimeFromUtc(DateTime.SpecifyKind(utcNow, DateTimeKind.Utc), timezone);
        var name = local.DayOfWeek switch
        {
            DayOfWeek.Monday => "mon",
            DayOfWeek.Tuesday => "tue",
            DayOfWeek.Wednesday => "wed",
            DayOfWeek.Thursday => "thu",
            DayOfWeek.Friday => "fri",
            DayOfWeek.Saturday => "sat",
            DayOfWeek.Sunday => "sun",
            _ => "mon"
        };
        return $"inventory-{name}.zip";
    }

    public static long MsUntilNextRun(DateTime utcNow, TimeOnly at, TimeZoneInfo timezone)
    {
        var localNow = TimeZoneInfo.ConvertTimeFromUtc(DateTime.SpecifyKind(utcNow, DateTimeKind.Utc), timezone);
        var todayRun = DateTime.SpecifyKind(localNow.Date.Add(at.ToTimeSpan()), DateTimeKind.Unspecified);
        var todayRunLocal = TimeZoneInfo.ConvertTimeToUtc(todayRun, timezone);
        var nextUtc = utcNow < todayRunLocal
            ? todayRunLocal
            : TimeZoneInfo.ConvertTimeToUtc(todayRun.AddDays(1), timezone);
        return Math.Max((long)(nextUtc - utcNow).TotalMilliseconds, 0);
    }

    private static string ResolveContentRoot(string tmpRoot)
    {
        var direct = Path.Combine(tmpRoot, BackupCsv.ModuleTypesFile);
        if (File.Exists(direct))
        {
            return tmpRoot;
        }

        var found = Directory.EnumerateFiles(tmpRoot, BackupCsv.ModuleTypesFile, SearchOption.AllDirectories)
            .FirstOrDefault(path => !path.Contains("__MACOSX", StringComparison.Ordinal));
        return found is null
            ? throw new InvalidOperationException($"Pflicht-Datei fehlt im Backup: {BackupCsv.ModuleTypesFile}")
            : Path.GetDirectoryName(found)!;
    }

    private static string CreateTempDir(string prefix)
    {
        var path = Path.Combine(Path.GetTempPath(), $"module_o_mat_backup_{prefix}_{Guid.NewGuid():N}");
        Directory.CreateDirectory(path);
        return path;
    }
}
