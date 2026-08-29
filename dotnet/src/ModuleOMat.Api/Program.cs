using System.Text.Json;
using System.Text.Json.Serialization;
using ModuleOMat.Api.Http;
using ModuleOMat.Api.Serialization;
using ModuleOMat.Infrastructure;
using ModuleOMat.Infrastructure.Backup;

var builder = WebApplication.CreateBuilder(args);
var vueDev = builder.Environment.IsDevelopment();

var port = Environment.GetEnvironmentVariable("PORT");
if (!string.IsNullOrWhiteSpace(port))
{
    builder.WebHost.UseUrls($"http://0.0.0.0:{port}");
}

UploadLimits.Configure(builder);

builder.Services.ConfigureHttpJsonOptions(options =>
{
    options.SerializerOptions.PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower;
    options.SerializerOptions.PropertyNameCaseInsensitive = true;
    options.SerializerOptions.Converters.Add(new TwoPlaceDecimalConverter());
    options.SerializerOptions.Converters.Add(new TwoPlaceNullableDecimalConverter());
    options.SerializerOptions.Converters.Add(new JsonStringEnumConverter(JsonNamingPolicy.SnakeCaseLower));
});

var storage = new StorageOptions
{
    DatabasePath = Environment.GetEnvironmentVariable("DATABASE_PATH")
        ?? builder.Configuration["Storage:DatabasePath"]
        ?? "data/module_o_mat.db",
    ManualUploadsDir = Environment.GetEnvironmentVariable("MANUAL_UPLOADS_DIR")
        ?? builder.Configuration["Storage:ManualUploadsDir"]
        ?? "data/uploads/manuals"
};

var nextcloud = new NextcloudOptions
{
    Enabled = builder.Configuration.GetValue("Nextcloud:Enabled", EnvBool("NEXTCLOUD_BACKUP_ENABLED", false)),
    WebDavUrl = builder.Configuration["Nextcloud:WebDavUrl"]
        ?? Environment.GetEnvironmentVariable("NEXTCLOUD_WEBDAV_URL"),
    Username = builder.Configuration["Nextcloud:Username"]
        ?? Environment.GetEnvironmentVariable("NEXTCLOUD_USERNAME"),
    AppPassword = builder.Configuration["Nextcloud:AppPassword"]
        ?? Environment.GetEnvironmentVariable("NEXTCLOUD_APP_PASSWORD"),
    BackupAt = builder.Configuration["Nextcloud:BackupAt"]
        ?? Environment.GetEnvironmentVariable("NEXTCLOUD_BACKUP_AT")
        ?? "03:00",
    Timezone = builder.Configuration["Nextcloud:Timezone"]
        ?? Environment.GetEnvironmentVariable("NEXTCLOUD_BACKUP_TIMEZONE")
        ?? "Europe/Berlin",
    IdleMinutes = builder.Configuration.GetValue(
        "Nextcloud:IdleMinutes",
        EnvInt("NEXTCLOUD_BACKUP_IDLE_MINUTES", 10)),
    HttpTimeoutSeconds = builder.Configuration.GetValue(
        "Nextcloud:HttpTimeoutSeconds",
        EnvInt("NEXTCLOUD_BACKUP_HTTP_TIMEOUT_SECONDS", 300))
};

builder.Services.AddModuleOMatInfrastructure(storage, nextcloud);
builder.Services.AddHostedService<ModuleOMat.Infrastructure.Scheduling.RemoteBackupScheduler>();
builder.Services.AddOpenApi();

var app = builder.Build();
await app.InitializeDatabase();

app.AllowLargeUploads();
if (vueDev)
{
    app.UseWhen(
        static context => !context.Request.Path.StartsWithSegments("/ui"),
        static branch =>
        {
            branch.UseDefaultFiles();
            branch.UseStaticFiles();
        });
    app.UseWebSockets();
}
else
{
    app.UseDefaultFiles();
    app.UseStaticFiles();
}

app.MapOpenApi("/api/openapi");
app.UseSwaggerUI(options =>
{
    options.SwaggerEndpoint("/api/openapi", "ModuleOMat API");
    options.RoutePrefix = "api/docs";
});

app.MapInventoryApi();
app.MapSpaFallback(serveBuiltUi: !vueDev);

app.Run();

static bool EnvBool(string name, bool fallback)
{
    var value = Environment.GetEnvironmentVariable(name);
    return value is null
        ? fallback
        : value is "true" or "1" or "TRUE" or "yes";
}

static int EnvInt(string name, int fallback) =>
    int.TryParse(Environment.GetEnvironmentVariable(name), out var parsed) ? parsed : fallback;

public partial class Program;
