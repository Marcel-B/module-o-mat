using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using ModuleOMat.Infrastructure;
using ModuleOMat.Infrastructure.Persistence;

namespace ModuleOMat.Api.Tests;

public class RackApiTests : IDisposable
{
    private static readonly JsonSerializerOptions Json = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower,
        PropertyNameCaseInsensitive = true
    };

    private readonly ApiFactory _factory = new();
    private readonly HttpClient _client;

    public RackApiTests()
    {
        _client = _factory.CreateClient();
    }

    public void Dispose()
    {
        _client.Dispose();
        _factory.Dispose();
    }

    private async Task<int> CreateModule(string name, int? plus12 = null)
    {
        var response = await _client.PostAsJsonAsync("/api/v1/modules", new
        {
            module = new
            {
                manufacturer = "Test",
                name,
                hp = 8,
                type = "Sonstiges",
                current_draw_plus12v_ma = plus12
            }
        }, Json);
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        var json = await response.Content.ReadFromJsonAsync<JsonElement>(Json);
        return json.GetProperty("module").GetProperty("id").GetInt32();
    }

    [Fact]
    public async Task Rack_crud_keeps_module_order_and_psu()
    {
        var a = await CreateModule("A", 100);
        var b = await CreateModule("B");

        var created = await _client.PostAsJsonAsync("/api/v1/racks", new
        {
            rack = new { name = "  Reise-Case  ", psu_plus12v_ma = 1200, psu_minus12v_ma = 800 }
        }, Json);
        Assert.Equal(HttpStatusCode.Created, created.StatusCode);
        var rack = (await created.Content.ReadFromJsonAsync<JsonElement>(Json)).GetProperty("rack");
        var id = rack.GetProperty("id").GetInt32();
        Assert.Equal("Reise-Case", rack.GetProperty("name").GetString());
        Assert.Equal(1200, rack.GetProperty("psu_plus12v_ma").GetInt32());
        Assert.Equal(JsonValueKind.Null, rack.GetProperty("psu_plus5v_ma").ValueKind);
        Assert.Equal(0, rack.GetProperty("module_ids").GetArrayLength());

        var updated = await _client.PutAsJsonAsync($"/api/v1/racks/{id}", new
        {
            rack = new { name = "Reise-Case", psu_plus12v_ma = 1200, psu_minus12v_ma = 800, psu_plus5v_ma = 500, module_ids = new[] { b, a, b } }
        }, Json);
        updated.EnsureSuccessStatusCode();
        rack = (await updated.Content.ReadFromJsonAsync<JsonElement>(Json)).GetProperty("rack");
        Assert.Equal(new[] { b, a }, rack.GetProperty("module_ids").EnumerateArray().Select(x => x.GetInt32()).ToArray());
        Assert.Equal(500, rack.GetProperty("psu_plus5v_ma").GetInt32());

        var list = await _client.GetFromJsonAsync<JsonElement>("/api/v1/racks", Json);
        Assert.Single(list.GetProperty("racks").EnumerateArray());

        // Geloeschte Module verschwinden aus der Planung.
        (await _client.DeleteAsync($"/api/v1/modules/{a}")).EnsureSuccessStatusCode();
        var shown = await _client.GetFromJsonAsync<JsonElement>($"/api/v1/racks/{id}", Json);
        Assert.Equal(new[] { b }, shown.GetProperty("rack").GetProperty("module_ids").EnumerateArray().Select(x => x.GetInt32()).ToArray());

        Assert.Equal(HttpStatusCode.NoContent, (await _client.DeleteAsync($"/api/v1/racks/{id}")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await _client.GetAsync($"/api/v1/racks/{id}")).StatusCode);
    }

    [Fact]
    public async Task Rack_validation_rejects_missing_name_negative_rails_and_unknown_modules()
    {
        var invalid = await _client.PostAsJsonAsync("/api/v1/racks", new
        {
            rack = new { name = " ", psu_plus12v_ma = -1 }
        }, Json);
        Assert.Equal(HttpStatusCode.UnprocessableEntity, invalid.StatusCode);
        var details = (await invalid.Content.ReadFromJsonAsync<JsonElement>(Json)).GetProperty("details");
        Assert.True(details.TryGetProperty("name", out _));
        Assert.True(details.TryGetProperty("psu_plus12v_ma", out _));

        var unknown = await _client.PostAsJsonAsync("/api/v1/racks", new
        {
            rack = new { name = "X", module_ids = new[] { 9999 } }
        }, Json);
        Assert.Equal(HttpStatusCode.UnprocessableEntity, unknown.StatusCode);
        details = (await unknown.Content.ReadFromJsonAsync<JsonElement>(Json)).GetProperty("details");
        Assert.True(details.TryGetProperty("module_ids", out _));

        Assert.Equal(HttpStatusCode.NotFound, (await _client.PutAsJsonAsync("/api/v1/racks/4711", new { rack = new { name = "Y" } }, Json)).StatusCode);
    }

    [Fact]
    public async Task Schema_upgrade_adds_rack_tables_to_existing_database()
    {
        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<InventoryDbContext>();
        await db.Database.ExecuteSqlRawAsync("DROP TABLE rack_modules; DROP TABLE racks;");

        await DependencyInjection.EnsureSchema(db);
        await DependencyInjection.EnsureSchema(db);

        var created = await _client.PostAsJsonAsync("/api/v1/racks", new { rack = new { name = "Nach Upgrade" } }, Json);
        Assert.Equal(HttpStatusCode.Created, created.StatusCode);
    }
}
