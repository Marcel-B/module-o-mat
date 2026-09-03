using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using ModuleOMat.Domain;
using ModuleOMat.Domain.Ports;
using ModuleOMat.Infrastructure;
using ModuleOMat.Infrastructure.Backup;

var command = args.ElementAtOrDefault(0)?.ToLowerInvariant();
if (command is null or "--help" or "-h")
{
    Console.WriteLine("ModuleOMat CLI");
    Console.WriteLine("  export [path]     Inventar als ZIP exportieren");
    Console.WriteLine("  import <path>     Inventar aus ZIP importieren (ersetzt den Bestand)");
    Console.WriteLine("  remote-backup     ZIP erzeugen und nach Nextcloud hochladen");
    return 0;
}

var builder = Host.CreateApplicationBuilder(args);
builder.Logging.SetMinimumLevel(LogLevel.Information);

var storage = new StorageOptions
{
    DatabasePath = Environment.GetEnvironmentVariable("DATABASE_PATH") ?? "data/module_o_mat.db",
    ManualUploadsDir = Environment.GetEnvironmentVariable("MANUAL_UPLOADS_DIR") ?? "data/uploads/manuals"
};
var nextcloud = NextcloudOptions.Load(builder.Configuration);

builder.Services.AddModuleOMatInfrastructure(storage, nextcloud);

var host = builder.Build();
await host.InitializeDatabase();

await using var scope = host.Services.CreateAsyncScope();
var store = scope.ServiceProvider.GetRequiredService<IInventoryStore>();
var manuals = scope.ServiceProvider.GetRequiredService<IManualStorage>();
var gate = scope.ServiceProvider.GetRequiredService<IMaintenanceGate>();

switch (command)
{
    case "export":
    {
        var path = args.ElementAtOrDefault(1)
            ?? Path.Combine(Directory.GetCurrentDirectory(), $"inventory-{DateTime.UtcNow:yyyyMMdd-HHmmss}.zip");
        await BackupOperations.ExportToPath(store, manuals, path, CancellationToken.None);
        Console.WriteLine($"Export geschrieben: {path}");
        return 0;
    }
    case "import":
    {
        var path = args.ElementAtOrDefault(1);
        if (string.IsNullOrWhiteSpace(path))
        {
            Console.Error.WriteLine("import erwartet einen Dateipfad");
            return 1;
        }

        var result = await BackupOperations.ImportFromPath(gate, store, manuals, path, CancellationToken.None);
        if (result.IsError)
        {
            Console.Error.WriteLine(result.Error.Message);
            return 1;
        }

        Console.WriteLine("Import abgeschlossen.");
        return 0;
    }
    case "remote-backup":
    {
        var runner = scope.ServiceProvider.GetRequiredService<RemoteBackupRunner>();
        var result = await runner.Run(CancellationToken.None);
        if (result.IsError)
        {
            Console.Error.WriteLine(result.Error.Message);
            return 1;
        }

        Console.WriteLine($"Hochgeladen: {result.Value}");
        return 0;
    }
    default:
        Console.Error.WriteLine($"Unbekannter Befehl: {command}");
        return 1;
}
