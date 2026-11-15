using ModuleOMat.Api.Serialization;
using ModuleOMat.Domain;
using ModuleOMat.Domain.Ports;

namespace ModuleOMat.Api.Http;

public sealed class RackEnvelope
{
    public RackAttrs? Rack { get; set; }
}

public sealed class RackAttrs
{
    public string? Name { get; set; }
    public int? PsuPlus12vMa { get; set; }
    public int? PsuMinus12vMa { get; set; }
    public int? PsuPlus5vMa { get; set; }
    public List<int>? ModuleIds { get; set; }

    public RackInput ToInput() => new(Name, PsuPlus12vMa, PsuMinus12vMa, PsuPlus5vMa, ModuleIds);
}

public static class RackEndpoints
{
    public static IEndpointRouteBuilder MapRackApi(this IEndpointRouteBuilder app)
    {
        var v1 = app.MapGroup("/api/v1");
        v1.MapGet("/racks", ListRacks).WithName("ListRacks").WithTags("racks");
        v1.MapGet("/racks/{id}", ShowRack).WithName("ShowRack").WithTags("racks");
        v1.MapPost("/racks", CreateRack).WithName("CreateRack").WithTags("racks");
        v1.MapPut("/racks/{id}", UpdateRack).WithName("UpdateRack").WithTags("racks");
        v1.MapDelete("/racks/{id}", DeleteRack).WithName("DeleteRack").WithTags("racks");
        return app;
    }

    private static async Task<IResult> ListRacks(IRackStore store, CancellationToken cancellationToken)
    {
        var racks = await RackOperations.List(store, cancellationToken).ConfigureAwait(false);
        return Results.Json(new { Racks = racks.Select(ApiJson.Rack) });
    }

    private static async Task<IResult> ShowRack(IRackStore store, string id, CancellationToken cancellationToken)
    {
        var parsed = RequestParsing.ParseId(id);
        if (parsed is null)
        {
            return ApiJson.ToHttp(AppError.NotFound("Rack nicht gefunden"));
        }

        var result = await RackOperations.Get(store, parsed.Value, cancellationToken).ConfigureAwait(false);
        return result.IsError ? ApiJson.ToHttp(result.Error) : Results.Json(new { Rack = ApiJson.Rack(result.Value) });
    }

    private static async Task<IResult> CreateRack(
        IMaintenanceGate gate,
        IRackStore store,
        IClock clock,
        RackEnvelope body,
        CancellationToken cancellationToken)
    {
        var input = (body.Rack ?? new RackAttrs()).ToInput();
        var result = await RackOperations.Create(gate, store, input, clock.UtcNow, cancellationToken)
            .ConfigureAwait(false);
        return result.IsError
            ? ApiJson.ToHttp(result.Error)
            : Results.Json(new { Rack = ApiJson.Rack(result.Value) }, statusCode: StatusCodes.Status201Created);
    }

    private static async Task<IResult> UpdateRack(
        IMaintenanceGate gate,
        IRackStore store,
        IClock clock,
        string id,
        RackEnvelope body,
        CancellationToken cancellationToken)
    {
        var parsed = RequestParsing.ParseId(id);
        if (parsed is null)
        {
            return ApiJson.ToHttp(AppError.NotFound("Rack nicht gefunden"));
        }

        var input = (body.Rack ?? new RackAttrs()).ToInput();
        var result = await RackOperations.Update(gate, store, parsed.Value, input, clock.UtcNow, cancellationToken)
            .ConfigureAwait(false);
        return result.IsError ? ApiJson.ToHttp(result.Error) : Results.Json(new { Rack = ApiJson.Rack(result.Value) });
    }

    private static async Task<IResult> DeleteRack(
        IMaintenanceGate gate,
        IRackStore store,
        string id,
        CancellationToken cancellationToken)
    {
        var parsed = RequestParsing.ParseId(id);
        if (parsed is null)
        {
            return ApiJson.ToHttp(AppError.NotFound("Rack nicht gefunden"));
        }

        var result = await RackOperations.Delete(gate, store, parsed.Value, cancellationToken).ConfigureAwait(false);
        return result.IsError ? ApiJson.ToHttp(result.Error) : Results.NoContent();
    }
}
