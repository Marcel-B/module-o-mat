namespace ModuleOMat.Domain.Ports;

public interface IInventoryStore
{
    Task<IReadOnlyList<EurorackModule>> ListActive(ModuleFilter filter, CancellationToken cancellationToken);
    Task<IReadOnlyList<EurorackModule>> ListForValuation(CancellationToken cancellationToken);
    Task<EurorackModule?> GetActive(int id, bool includeObservations, CancellationToken cancellationToken);
    Task<IReadOnlyList<string>> ListManufacturers(CancellationToken cancellationToken);
    Task<IReadOnlyList<ModuleTypeRecord>> ListModuleTypes(CancellationToken cancellationToken);
    Task<IReadOnlyList<string>> ListUsedTypes(CancellationToken cancellationToken);
    Task<ModuleTypeRecord?> GetModuleType(int id, CancellationToken cancellationToken);
    Task<bool> ModuleTypeNameExists(string name, int? exceptId, CancellationToken cancellationToken);

    Task<EurorackModule> InsertModule(ValidatedModule module, DateTime utcNow, CancellationToken cancellationToken);
    Task<EurorackModule> UpdateModule(int id, ValidatedModule module, DateTime utcNow, CancellationToken cancellationToken);
    Task SoftDelete(int id, DateTime utcNow, CancellationToken cancellationToken);
    Task SetManual(int id, ManualMeta? meta, DateTime utcNow, CancellationToken cancellationToken);

    Task<ModuleTypeRecord> InsertModuleType(string name, DateTime utcNow, CancellationToken cancellationToken);
    Task<ModuleTypeRecord> RenameModuleType(int id, string oldName, string newName, DateTime utcNow, CancellationToken cancellationToken);
    Task DeleteModuleType(int id, string name, DateTime utcNow, CancellationToken cancellationToken);

    Task<IReadOnlyList<PriceObservation>> InsertObservations(
        int moduleId,
        IReadOnlyList<ObservationInput> observations,
        CurrentValueSetting currentValue,
        DateTime utcNow,
        CancellationToken cancellationToken);

    Task<PriceRange?> PriceRange(int moduleId, CancellationToken cancellationToken);
    Task<IReadOnlyDictionary<int, PriceRange>> PriceRanges(IReadOnlyList<int> moduleIds, CancellationToken cancellationToken);

    Task RecordBackupRun(string? filename, long? sizeBytes, bool success, DateTime utcNow, CancellationToken cancellationToken);
    Task<BackupHistoryPage> ListBackupRuns(int page, CancellationToken cancellationToken);

    Task<BackupSnapshot> LoadSnapshot(CancellationToken cancellationToken);
    Task ReplaceInventory(BackupSnapshot snapshot, CancellationToken cancellationToken);
}

public interface IManualStorage
{
    string NewKey();
    bool LooksLikePdf(string path);
    Task Store(string key, string sourcePath, CancellationToken cancellationToken);
    Task Delete(string? key, CancellationToken cancellationToken);
    Task CopyOut(string key, string destPath, CancellationToken cancellationToken);
    Task ReplaceAll(string sourceDir, CancellationToken cancellationToken);
    bool Exists(string key);
    Stream OpenRead(string key);
}

public interface IWebDavClient
{
    Task<Result<Unit>> PutFile(
        string baseUrl,
        string filename,
        string localPath,
        string username,
        string password,
        TimeSpan timeout,
        CancellationToken cancellationToken);

    Task<Result<Unit>> EnsureCollection(
        string baseUrl,
        string username,
        string password,
        TimeSpan timeout,
        CancellationToken cancellationToken);
}

public interface IMaintenanceGate
{
    bool IsMaintenance { get; }
    Result<Unit> BeginWrite();
    void EndWrite();
    void ScheduleAfterChange();
}

public interface IClock
{
    DateTime UtcNow { get; }
    DateOnly UtcToday { get; }
}
