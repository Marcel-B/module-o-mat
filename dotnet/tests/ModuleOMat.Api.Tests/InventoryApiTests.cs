using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;
using ModuleOMat.Domain.Ports;

namespace ModuleOMat.Api.Tests;

public sealed class ApiFactory : WebApplicationFactory<Program>
{
    private readonly string _root = Path.Combine(Path.GetTempPath(), $"mom-api-{Guid.NewGuid():N}");

    public ApiFactory()
    {
        Directory.CreateDirectory(_root);
        var db = Path.Combine(_root, "test.db");
        var uploads = Path.Combine(_root, "manuals");
        Directory.CreateDirectory(uploads);
        Environment.SetEnvironmentVariable("DATABASE_PATH", db);
        Environment.SetEnvironmentVariable("MANUAL_UPLOADS_DIR", uploads);
        Environment.SetEnvironmentVariable("NEXTCLOUD_BACKUP_ENABLED", "false");
    }

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");
    }

    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
        try
        {
            if (Directory.Exists(_root))
            {
                Directory.Delete(_root, true);
            }
        }
        catch (IOException)
        {
        }
    }
}

public class InventoryApiTests : IDisposable
{
    private static readonly JsonSerializerOptions Json = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower,
        PropertyNameCaseInsensitive = true
    };

    private readonly ApiFactory _factory = new();
    private readonly HttpClient _client;

    public InventoryApiTests()
    {
        _client = _factory.CreateClient();
    }

    public void Dispose()
    {
        _client.Dispose();
        _factory.Dispose();
    }

    [Fact]
    public async Task Landing_page_is_served()
    {
        var response = await _client.GetAsync("/");
        response.EnsureSuccessStatusCode();
        var html = await response.Content.ReadAsStringAsync();
        Assert.Contains("ui-choice-vue", html);
        Assert.Contains("ui-choice-vue-alt", html);
    }

    [Fact]
    public async Task Openapi_and_docs_are_available()
    {
        var spec = await _client.GetAsync("/api/openapi");
        spec.EnsureSuccessStatusCode();
        var docs = await _client.GetAsync("/api/docs/index.html");
        Assert.True(docs.IsSuccessStatusCode || docs.StatusCode == HttpStatusCode.MovedPermanently || docs.StatusCode == HttpStatusCode.Redirect);
    }

    [Fact]
    public async Task Maintenance_is_false_by_default()
    {
        var json = await _client.GetFromJsonAsync<JsonElement>("/api/v1/maintenance", Json);
        Assert.False(json.GetProperty("maintenance").GetBoolean());
    }

    [Fact]
    public async Task Module_types_are_seeded()
    {
        var json = await _client.GetFromJsonAsync<JsonElement>("/api/v1/module-types", Json);
        var types = json.GetProperty("module_types");
        Assert.True(types.GetArrayLength() >= 18);
        Assert.Contains(types.EnumerateArray(), t => t.GetProperty("name").GetString() == "Sonstiges" && t.GetProperty("fallback").GetBoolean());
    }

    [Fact]
    public async Task Module_crud_filter_duplicate_and_valuations()
    {
        var created = await _client.PostAsJsonAsync("/api/v1/modules", new
        {
            module = new
            {
                manufacturer = "Make Noise",
                name = "Maths",
                hp = 20,
                type = "Envelope",
                subtypes = new[] { "LFO" },
                purchase_price = 289.00m,
                youtube_videos = new[] { new { url = "https://youtu.be/abcdefghijk" } }
            }
        }, Json);
        Assert.Equal(HttpStatusCode.Created, created.StatusCode);
        var createdJson = await created.Content.ReadFromJsonAsync<JsonElement>(Json);
        var id = createdJson.GetProperty("module").GetProperty("id").GetInt32();
        Assert.Equal("https://www.youtube.com/watch?v=abcdefghijk",
            createdJson.GetProperty("module").GetProperty("youtube_videos")[0].GetProperty("url").GetString());

        await _client.PostAsJsonAsync("/api/v1/modules", new
        {
            module = new { manufacturer = "Mutable", name = "Clouds", hp = 18, type = "Effect" }
        }, Json);

        var list = await _client.GetFromJsonAsync<JsonElement>("/api/v1/modules?q=Maths", Json);
        Assert.Equal(1, list.GetProperty("modules").GetArrayLength());
        Assert.Equal(20, list.GetProperty("stats").GetProperty("total_hp").GetInt32());

        var manufacturers = await _client.GetFromJsonAsync<JsonElement>("/api/v1/manufacturers", Json);
        Assert.Contains(manufacturers.GetProperty("manufacturers").EnumerateArray(), m => m.GetString() == "Make Noise");

        var typed = await _client.GetFromJsonAsync<JsonElement>("/api/v1/modules?types=LFO", Json);
        Assert.Equal("Maths", typed.GetProperty("modules")[0].GetProperty("name").GetString());

        var patch = await _client.PatchAsJsonAsync($"/api/v1/modules/{id}", new { module = new { name = "Maths 2" } }, Json);
        patch.EnsureSuccessStatusCode();
        Assert.Equal("Maths 2", (await patch.Content.ReadFromJsonAsync<JsonElement>(Json)).GetProperty("module").GetProperty("name").GetString());

        var valuation = await _client.PostAsJsonAsync($"/api/v1/modules/{id}/valuations", new
        {
            observations = new[] { new { amount = 199, source = "shop", notes = "neu" } }
        }, Json);
        Assert.Equal(HttpStatusCode.Created, valuation.StatusCode);
        var valuationJson = await valuation.Content.ReadFromJsonAsync<JsonElement>(Json);
        Assert.Equal(199, valuationJson.GetProperty("module").GetProperty("current_value").GetDecimal());

        var detail = await _client.GetFromJsonAsync<JsonElement>($"/api/v1/modules/{id}", Json);
        Assert.Equal(1, detail.GetProperty("module").GetProperty("price_observations").GetArrayLength());

        var duplicate = await _client.PostAsJsonAsync($"/api/v1/modules/{id}/duplicate", new { copy_manual = false }, Json);
        Assert.Equal(HttpStatusCode.Created, duplicate.StatusCode);

        var deleted = await _client.DeleteAsync($"/api/v1/modules/{id}");
        Assert.Equal(HttpStatusCode.NoContent, deleted.StatusCode);
        var missing = await _client.GetAsync($"/api/v1/modules/{id}");
        Assert.Equal(HttpStatusCode.NotFound, missing.StatusCode);
    }

    [Fact]
    public async Task Validation_and_fallback_type()
    {
        var invalid = await _client.PostAsJsonAsync("/api/v1/modules", new { module = new { } }, Json);
        Assert.Equal(HttpStatusCode.UnprocessableEntity, invalid.StatusCode);
        var body = await invalid.Content.ReadFromJsonAsync<JsonElement>(Json);
        Assert.True(body.GetProperty("details").TryGetProperty("name", out _));

        var types = await _client.GetFromJsonAsync<JsonElement>("/api/v1/module-types", Json);
        var fallback = types.GetProperty("module_types").EnumerateArray()
            .First(t => t.GetProperty("fallback").GetBoolean());
        var del = await _client.DeleteAsync($"/api/v1/module-types/{fallback.GetProperty("id").GetInt32()}");
        Assert.Equal(HttpStatusCode.UnprocessableEntity, del.StatusCode);
    }

    [Fact]
    public async Task Manual_pdf_upload_download_and_delete()
    {
        var created = await _client.PostAsJsonAsync("/api/v1/modules", new
        {
            module = new { manufacturer = "Intellijel", name = "Quad VCA", hp = 12, type = "VCA" }
        }, Json);
        var id = (await created.Content.ReadFromJsonAsync<JsonElement>(Json)).GetProperty("module").GetProperty("id").GetInt32();

        using var content = new MultipartFormDataContent();
        var bytes = await File.ReadAllBytesAsync(Path.Combine(AppContext.BaseDirectory, "Fixtures", "sample.pdf"));
        var file = new ByteArrayContent(bytes);
        file.Headers.ContentType = new MediaTypeHeaderValue("application/pdf");
        content.Add(file, "file", "sample.pdf");

        var uploaded = await _client.PutAsync($"/api/v1/modules/{id}/manual", content);
        uploaded.EnsureSuccessStatusCode();
        var uploadedJson = await uploaded.Content.ReadFromJsonAsync<JsonElement>(Json);
        Assert.True(uploadedJson.GetProperty("module").GetProperty("has_manual").GetBoolean());

        var pdf = await _client.GetAsync($"/api/v1/modules/{id}/manual");
        pdf.EnsureSuccessStatusCode();
        Assert.Equal("application/pdf", pdf.Content.Headers.ContentType?.MediaType);

        var removed = await _client.DeleteAsync($"/api/v1/modules/{id}/manual");
        removed.EnsureSuccessStatusCode();
        Assert.False((await removed.Content.ReadFromJsonAsync<JsonElement>(Json)).GetProperty("module").GetProperty("has_manual").GetBoolean());
    }

    [Fact]
    public async Task Backup_zip_roundtrip_and_history()
    {
        await _client.PostAsJsonAsync("/api/v1/modules", new
        {
            module = new { manufacturer = "Make Noise", name = "Maths", hp = 20, type = "Envelope" }
        }, Json);

        var exported = await _client.GetAsync("/api/v1/backup/export");
        exported.EnsureSuccessStatusCode();
        var zip = await exported.Content.ReadAsByteArrayAsync();
        Assert.True(zip.Length > 20);

        using var import = new MultipartFormDataContent();
        var file = new ByteArrayContent(zip);
        file.Headers.ContentType = new MediaTypeHeaderValue("application/zip");
        import.Add(file, "file", "inventory.zip");
        var imported = await _client.PostAsync("/api/v1/backup/import", import);
        imported.EnsureSuccessStatusCode();
        Assert.True((await imported.Content.ReadFromJsonAsync<JsonElement>(Json)).GetProperty("imported").GetBoolean());

        var history = await _client.GetFromJsonAsync<JsonElement>("/api/v1/backup/history", Json);
        Assert.Equal(1, history.GetProperty("page").GetInt32());
        Assert.Equal(5, history.GetProperty("per_page").GetInt32());

        var page2 = await _client.GetFromJsonAsync<JsonElement>("/api/v1/backup/history?page=2", Json);
        Assert.Equal(2, page2.GetProperty("page").GetInt32());
        Assert.Equal(5, page2.GetProperty("per_page").GetInt32());
    }

    [Fact]
    public async Task Backup_import_accepts_payload_larger_than_kestrel_default()
    {
        using var content = new MultipartFormDataContent();
        var payload = new byte[32 * 1024 * 1024];
        payload[0] = (byte)'P';
        payload[1] = (byte)'K';
        var file = new ByteArrayContent(payload);
        file.Headers.ContentType = new MediaTypeHeaderValue("application/zip");
        content.Add(file, "file", "big.zip");

        var response = await _client.PostAsync("/api/v1/backup/import", content);
        Assert.NotEqual(HttpStatusCode.RequestEntityTooLarge, response.StatusCode);
    }

    [Fact]
    public async Task Spa_routes_are_registered()
    {
        var ui = await _client.GetAsync("/ui");
        var alt = await _client.GetAsync("/ui-alt/inventory");
        Assert.True(ui.StatusCode is HttpStatusCode.OK or HttpStatusCode.ServiceUnavailable);
        Assert.True(alt.StatusCode is HttpStatusCode.OK or HttpStatusCode.ServiceUnavailable);
        if (ui.StatusCode == HttpStatusCode.ServiceUnavailable)
        {
            var body = await ui.Content.ReadFromJsonAsync<JsonElement>(Json);
            Assert.True(body.TryGetProperty("error", out _));
        }
    }

    [Fact]
    public async Task Agent_api_lists_slim_modules()
    {
        await _client.PostAsJsonAsync("/api/v1/modules", new
        {
            module = new { manufacturer = "Make Noise", name = "Maths", hp = 20, type = "Envelope" }
        }, Json);

        var json = await _client.GetFromJsonAsync<JsonElement>("/api/modules", Json);
        var module = json.GetProperty("modules")[0];
        Assert.True(module.TryGetProperty("name", out _));
        Assert.False(module.TryGetProperty("type", out _));
    }

    [Fact]
    public async Task Write_is_blocked_during_maintenance()
    {
        var gate = _factory.Services.GetRequiredService<IMaintenanceGate>();
        ((ModuleOMat.Infrastructure.Scheduling.WriteGate)gate).SetMaintenance(true);
        try
        {
            var response = await _client.PostAsJsonAsync("/api/v1/modules", new
            {
                module = new { manufacturer = "X", name = "Y", hp = 4, type = "Utility" }
            }, Json);
            Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
        }
        finally
        {
            ((ModuleOMat.Infrastructure.Scheduling.WriteGate)gate).SetMaintenance(false);
        }
    }
}
