using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using ModuleOMat.Domain;
using ModuleOMat.Domain.Ports;
using ModuleOMat.Infrastructure.Backup;
using ModuleOMat.Infrastructure.Persistence;
using ModuleOMat.Infrastructure.Scheduling;
using ModuleOMat.Infrastructure.Storage;
using ModuleOMat.Infrastructure.WebDav;

namespace ModuleOMat.Infrastructure;

public sealed class StorageOptions
{
    public string DatabasePath { get; set; } = "module_o_mat.db";
    public string ManualUploadsDir { get; set; } = "uploads/manuals";
}

public static class DependencyInjection
{
    public static IServiceCollection AddModuleOMatInfrastructure(
        this IServiceCollection services,
        StorageOptions storage,
        NextcloudOptions nextcloud)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(storage.DatabasePath)) ?? ".");
        Directory.CreateDirectory(storage.ManualUploadsDir);

        services.AddSingleton(storage);
        services.AddSingleton(nextcloud);
        services.AddSingleton<IClock, SystemClock>();
        services.AddSingleton<WriteGate>();
        services.AddSingleton<IMaintenanceGate>(sp => sp.GetRequiredService<WriteGate>());
        services.AddSingleton<IManualStorage>(_ => new LocalDiskManualStorage(storage.ManualUploadsDir));
        services.AddHttpClient("webdav");
        services.AddSingleton<IWebDavClient, HttpWebDavClient>();
        services.AddDbContext<InventoryDbContext>(options =>
            options.UseSqlite($"Data Source={storage.DatabasePath}"));
        services.AddScoped<IInventoryStore, EfInventoryStore>();
        services.AddScoped<RemoteBackupRunner>();
        return services;
    }

    public static async Task InitializeDatabase(this IHost host, CancellationToken cancellationToken = default)
    {
        await using var scope = host.Services.CreateAsyncScope();
        var db = scope.ServiceProvider.GetRequiredService<InventoryDbContext>();
        var logger = scope.ServiceProvider.GetRequiredService<ILoggerFactory>().CreateLogger("Database");
        await db.Database.EnsureCreatedAsync(cancellationToken).ConfigureAwait(false);
        if (!await db.ModuleTypes.AnyAsync(cancellationToken).ConfigureAwait(false))
        {
            var now = DateTime.UtcNow;
            db.ModuleTypes.AddRange(TypeRules.DefaultTypeNames.Select(name => new ModuleTypeEntity
            {
                Name = name,
                InsertedAt = now,
                UpdatedAt = now
            }));
            await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);
            logger.LogInformation("Modultypen-Seed geschrieben ({Count} Eintraege)", TypeRules.DefaultTypeNames.Count);
        }
    }
}
