using Microsoft.AspNetCore.Mvc;
using ModuleOMat.Api.Serialization;
using ModuleOMat.Domain;
using ModuleOMat.Domain.Ports;

namespace ModuleOMat.Api.Http;

public static class InventoryEndpoints
{
    public static IEndpointRouteBuilder MapInventoryApi(this IEndpointRouteBuilder app)
    {
        var v1 = app.MapGroup("/api/v1");
        v1.MapGet("/modules", ListModules).WithName("ListModules").WithTags("modules");
        v1.MapGet("/modules/{id}", ShowModule).WithName("ShowModule").WithTags("modules");
        v1.MapPost("/modules", CreateModule).WithName("CreateModule").WithTags("modules");
        v1.MapPatch("/modules/{id}", UpdateModule).WithName("UpdateModule").WithTags("modules");
        v1.MapDelete("/modules/{id}", DeleteModule).WithName("DeleteModule").WithTags("modules");
        v1.MapPost("/modules/{id}/duplicate", DuplicateModule).WithName("DuplicateModule").WithTags("modules");
        v1.MapPost("/modules/{id}/valuations", CreateValuations).WithName("CreateValuations").WithTags("modules");
        v1.MapGet("/modules/{id}/manual", ShowManual).WithName("ShowManual").WithTags("modules");
        v1.MapPut("/modules/{id}/manual", UpdateManual).DisableAntiforgery().WithName("UpdateManual").WithTags("modules");
        v1.MapDelete("/modules/{id}/manual", DeleteManual).WithName("DeleteManual").WithTags("modules");

        v1.MapGet("/module-types", ListTypes).WithName("ListModuleTypes").WithTags("module-types");
        v1.MapPost("/module-types", CreateType).WithName("CreateModuleType").WithTags("module-types");
        v1.MapPatch("/module-types/{id}", UpdateType).WithName("UpdateModuleType").WithTags("module-types");
        v1.MapDelete("/module-types/{id}", DeleteType).WithName("DeleteModuleType").WithTags("module-types");

        v1.MapGet("/manufacturers", Manufacturers).WithName("ListManufacturers").WithTags("lookups");
        v1.MapGet("/backup/export", ExportBackup).WithName("ExportBackup").WithTags("backup");
        v1.MapPost("/backup/import", ImportBackup)
            .DisableAntiforgery()
            .WithMetadata(new DisableRequestSizeLimitAttribute())
            .WithName("ImportBackup")
            .WithTags("backup");
        v1.MapGet("/backup/history", BackupHistory).WithName("BackupHistory").WithTags("backup");
        v1.MapGet("/maintenance", Maintenance).WithName("Maintenance").WithTags("maintenance");

        var agent = app.MapGroup("/api");
        agent.MapGet("/modules", ListForValuation).WithName("AgentListModules").WithTags("agent");
        agent.MapGet("/modules/{id}", ShowForValuation).WithName("AgentShowModule").WithTags("agent");
        agent.MapPost("/modules/{id}/valuations", CreateValuations).WithName("AgentCreateValuations").WithTags("agent");
        return app;
    }

    private static async Task<IResult> ListModules(
        IInventoryStore store,
        string? q,
        string[]? types,
        string? min_hp,
        string? max_hp,
        CancellationToken cancellationToken)
    {
        var filter = RequestParsing.Filter(q, types, min_hp, max_hp);
        var modules = await InventoryOperations.ListModules(store, filter, cancellationToken).ConfigureAwait(false);
        var ranges = await InventoryOperations
            .PriceRanges(store, modules.Select(m => m.Id).ToArray(), cancellationToken)
            .ConfigureAwait(false);
        var stats = Stats.FromModules(modules);
        return Results.Json(new
        {
            Modules = modules.Select(m => ApiJson.Module(m, ranges.GetValueOrDefault(m.Id))),
            Stats = ApiJson.Stats(stats)
        });
    }

    private static async Task<IResult> ShowModule(
        IInventoryStore store,
        string id,
        CancellationToken cancellationToken)
    {
        var parsed = RequestParsing.ParseId(id);
        if (parsed is null)
        {
            return ApiJson.ToHttp(AppError.NotFound("Modul nicht gefunden"));
        }

        var result = await InventoryOperations.GetActive(store, parsed.Value, true, cancellationToken)
            .ConfigureAwait(false);
        if (result.IsError)
        {
            return ApiJson.ToHttp(result.Error);
        }

        var range = await InventoryOperations.PriceRange(store, result.Value.Id, cancellationToken)
            .ConfigureAwait(false);
        return Results.Json(new { Module = ApiJson.Module(result.Value, range, includeObservations: true) });
    }

    private static async Task<IResult> CreateModule(
        IMaintenanceGate gate,
        IInventoryStore store,
        IClock clock,
        ModuleEnvelope body,
        CancellationToken cancellationToken)
    {
        var input = (body.Module ?? new ModuleAttrs()).ToInput();
        var result = await InventoryOperations
            .CreateModule(gate, store, input, clock.UtcNow, cancellationToken)
            .ConfigureAwait(false);
        return result.IsError
            ? ApiJson.ToHttp(result.Error)
            : Results.Json(new { Module = ApiJson.Module(result.Value) }, statusCode: StatusCodes.Status201Created);
    }

    private static async Task<IResult> UpdateModule(
        IMaintenanceGate gate,
        IInventoryStore store,
        IClock clock,
        string id,
        ModuleEnvelope body,
        CancellationToken cancellationToken)
    {
        var parsed = RequestParsing.ParseId(id);
        if (parsed is null)
        {
            return ApiJson.ToHttp(AppError.NotFound("Modul nicht gefunden"));
        }

        var input = (body.Module ?? new ModuleAttrs()).ToInput();
        var result = await InventoryOperations
            .UpdateModule(gate, store, parsed.Value, input, clock.UtcNow, cancellationToken)
            .ConfigureAwait(false);
        if (result.IsError)
        {
            return ApiJson.ToHttp(result.Error);
        }

        var range = await InventoryOperations.PriceRange(store, result.Value.Id, cancellationToken)
            .ConfigureAwait(false);
        return Results.Json(new { Module = ApiJson.Module(result.Value, range) });
    }

    private static async Task<IResult> DeleteModule(
        IMaintenanceGate gate,
        IInventoryStore store,
        IClock clock,
        string id,
        CancellationToken cancellationToken)
    {
        var parsed = RequestParsing.ParseId(id);
        if (parsed is null)
        {
            return ApiJson.ToHttp(AppError.NotFound("Modul nicht gefunden"));
        }

        var result = await InventoryOperations
            .SoftDelete(gate, store, parsed.Value, clock.UtcNow, cancellationToken)
            .ConfigureAwait(false);
        return result.IsError ? ApiJson.ToHttp(result.Error) : Results.NoContent();
    }

    private static async Task<IResult> DuplicateModule(
        IMaintenanceGate gate,
        IInventoryStore store,
        IManualStorage manuals,
        IClock clock,
        string id,
        DuplicateRequest? body,
        CancellationToken cancellationToken)
    {
        var parsed = RequestParsing.ParseId(id);
        if (parsed is null)
        {
            return ApiJson.ToHttp(AppError.NotFound("Modul nicht gefunden"));
        }

        body ??= new DuplicateRequest();
        var result = await InventoryOperations
            .Duplicate(
                gate,
                store,
                manuals,
                parsed.Value,
                body.Module?.ToInput(),
                body.CopyManualFlag,
                clock.UtcNow,
                cancellationToken)
            .ConfigureAwait(false);
        return result.IsError
            ? ApiJson.ToHttp(result.Error)
            : Results.Json(new { Module = ApiJson.Module(result.Value) }, statusCode: StatusCodes.Status201Created);
    }

    private static async Task<IResult> CreateValuations(
        IMaintenanceGate gate,
        IInventoryStore store,
        IClock clock,
        string id,
        ValuationsRequest body,
        CancellationToken cancellationToken)
    {
        var parsed = RequestParsing.ParseId(id);
        if (parsed is null)
        {
            return ApiJson.ToHttp(AppError.NotFound("Modul nicht gefunden"));
        }

        var observations = (body.Observations ?? []).Select(o => o.ToInput()).ToArray();
        var result = await InventoryOperations
            .CreateObservations(
                gate,
                store,
                parsed.Value,
                observations,
                RequestParsing.CurrentValue(body),
                clock.UtcNow,
                clock.UtcToday,
                cancellationToken)
            .ConfigureAwait(false);
        if (result.IsError)
        {
            return ApiJson.ToHttp(result.Error);
        }

        return Results.Json(
            new
            {
                Module = ApiJson.Module(result.Value.Module, result.Value.PriceRange),
                Observations = result.Value.Observations.Select(ApiJson.Observation),
                PriceRange = ApiJson.PriceRange(result.Value.PriceRange)
            },
            statusCode: StatusCodes.Status201Created);
    }

    private static async Task<IResult> ShowManual(
        IInventoryStore store,
        IManualStorage manuals,
        string id,
        CancellationToken cancellationToken)
    {
        var parsed = RequestParsing.ParseId(id);
        if (parsed is null)
        {
            return ApiJson.ToHttp(AppError.NotFound("Modul nicht gefunden"));
        }

        var result = await InventoryOperations.GetActive(store, parsed.Value, false, cancellationToken)
            .ConfigureAwait(false);
        if (result.IsError)
        {
            return ApiJson.ToHttp(result.Error);
        }

        var key = result.Value.ManualPdfKey;
        if (key is null || !manuals.Exists(key))
        {
            return ApiJson.ToHttp(AppError.NotFound("Keine Anleitung gefunden"));
        }

        var filename = Sanitize(result.Value.ManualPdfFilename) ?? "manual.pdf";
        return Results.File(
            manuals.OpenRead(key),
            result.Value.ManualPdfContentType ?? "application/pdf",
            fileDownloadName: filename,
            enableRangeProcessing: false);
    }

    private static async Task<IResult> UpdateManual(
        IMaintenanceGate gate,
        IInventoryStore store,
        IManualStorage manuals,
        IClock clock,
        string id,
        IFormFile? file,
        CancellationToken cancellationToken)
    {
        var parsed = RequestParsing.ParseId(id);
        if (parsed is null)
        {
            return ApiJson.ToHttp(AppError.NotFound("Modul nicht gefunden"));
        }

        if (file is null)
        {
            return ApiJson.ToHttp(AppError.Unprocessable("Datei fehlt"));
        }

        var tmp = Path.GetTempFileName();
        await using (var stream = File.Create(tmp))
        {
            await file.CopyToAsync(stream, cancellationToken).ConfigureAwait(false);
        }

        try
        {
            var result = await InventoryOperations
                .AttachManual(
                    gate,
                    store,
                    manuals,
                    parsed.Value,
                    tmp,
                    file.FileName,
                    file.ContentType,
                    (int)file.Length,
                    clock.UtcNow,
                    cancellationToken)
                .ConfigureAwait(false);
            if (result.IsError)
            {
                return ApiJson.ToHttp(result.Error);
            }

            var range = await InventoryOperations.PriceRange(store, result.Value.Id, cancellationToken)
                .ConfigureAwait(false);
            return Results.Json(new { Module = ApiJson.Module(result.Value, range) });
        }
        finally
        {
            File.Delete(tmp);
        }
    }

    private static async Task<IResult> DeleteManual(
        IMaintenanceGate gate,
        IInventoryStore store,
        IManualStorage manuals,
        IClock clock,
        string id,
        CancellationToken cancellationToken)
    {
        var parsed = RequestParsing.ParseId(id);
        if (parsed is null)
        {
            return ApiJson.ToHttp(AppError.NotFound("Modul nicht gefunden"));
        }

        var result = await InventoryOperations
            .RemoveManual(gate, store, manuals, parsed.Value, clock.UtcNow, cancellationToken)
            .ConfigureAwait(false);
        if (result.IsError)
        {
            return ApiJson.ToHttp(result.Error);
        }

        var range = await InventoryOperations.PriceRange(store, result.Value.Id, cancellationToken)
            .ConfigureAwait(false);
        return Results.Json(new { Module = ApiJson.Module(result.Value, range) });
    }

    private static async Task<IResult> ListTypes(IInventoryStore store, CancellationToken cancellationToken)
    {
        var used = (await InventoryOperations.ListUsedTypes(store, cancellationToken).ConfigureAwait(false))
            .ToHashSet(StringComparer.Ordinal);
        var types = await InventoryOperations.ListModuleTypes(store, cancellationToken).ConfigureAwait(false);
        return Results.Json(new
        {
            ModuleTypes = types.Select(t =>
                ApiJson.ModuleType(t, TypeRules.IsFallback(t.Name), used.Contains(t.Name)))
        });
    }

    private static async Task<IResult> CreateType(
        IMaintenanceGate gate,
        IInventoryStore store,
        IClock clock,
        ModuleTypeEnvelope body,
        CancellationToken cancellationToken)
    {
        var result = await InventoryOperations
            .CreateModuleType(gate, store, body.ModuleType?.Name, clock.UtcNow, cancellationToken)
            .ConfigureAwait(false);
        if (result.IsError)
        {
            return ApiJson.ToHttp(result.Error);
        }

        var used = (await InventoryOperations.ListUsedTypes(store, cancellationToken).ConfigureAwait(false))
            .ToHashSet(StringComparer.Ordinal);
        return Results.Json(
            new
            {
                ModuleType = ApiJson.ModuleType(
                    result.Value,
                    TypeRules.IsFallback(result.Value.Name),
                    used.Contains(result.Value.Name))
            },
            statusCode: StatusCodes.Status201Created);
    }

    private static async Task<IResult> UpdateType(
        IMaintenanceGate gate,
        IInventoryStore store,
        IClock clock,
        string id,
        ModuleTypeEnvelope body,
        CancellationToken cancellationToken)
    {
        var parsed = RequestParsing.ParseId(id);
        if (parsed is null)
        {
            return ApiJson.ToHttp(AppError.NotFound("Modultyp nicht gefunden"));
        }

        var result = await InventoryOperations
            .UpdateModuleType(gate, store, parsed.Value, body.ModuleType?.Name, clock.UtcNow, cancellationToken)
            .ConfigureAwait(false);
        if (result.IsError)
        {
            return ApiJson.ToHttp(result.Error);
        }

        var used = (await InventoryOperations.ListUsedTypes(store, cancellationToken).ConfigureAwait(false))
            .ToHashSet(StringComparer.Ordinal);
        return Results.Json(new
        {
            ModuleType = ApiJson.ModuleType(
                result.Value,
                TypeRules.IsFallback(result.Value.Name),
                used.Contains(result.Value.Name))
        });
    }

    private static async Task<IResult> DeleteType(
        IMaintenanceGate gate,
        IInventoryStore store,
        IClock clock,
        string id,
        CancellationToken cancellationToken)
    {
        var parsed = RequestParsing.ParseId(id);
        if (parsed is null)
        {
            return ApiJson.ToHttp(AppError.NotFound("Modultyp nicht gefunden"));
        }

        var result = await InventoryOperations
            .DeleteModuleType(gate, store, parsed.Value, clock.UtcNow, cancellationToken)
            .ConfigureAwait(false);
        return result.IsError ? ApiJson.ToHttp(result.Error) : Results.NoContent();
    }

    private static async Task<IResult> Manufacturers(IInventoryStore store, CancellationToken cancellationToken) =>
        Results.Json(new
        {
            Manufacturers = await InventoryOperations.Manufacturers(store, cancellationToken).ConfigureAwait(false)
        });

    private static async Task<IResult> ExportBackup(
        IInventoryStore store,
        IManualStorage manuals,
        CancellationToken cancellationToken)
    {
        var stamp = DateTime.UtcNow.ToString("yyyyMMdd-HHmmss");
        var filename = $"inventory-{stamp}.zip";
        var tmp = Path.Combine(Path.GetTempPath(), $"module_o_mat_{filename}");
        try
        {
            await BackupOperations.ExportToPath(store, manuals, tmp, cancellationToken).ConfigureAwait(false);
            var bytes = await File.ReadAllBytesAsync(tmp, cancellationToken).ConfigureAwait(false);
            return Results.File(bytes, "application/zip", filename);
        }
        catch (Exception ex)
        {
            return ApiJson.ToHttp(AppError.Unprocessable($"Backup konnte nicht erstellt werden: {ex.Message}"));
        }
        finally
        {
            if (File.Exists(tmp))
            {
                File.Delete(tmp);
            }
        }
    }

    private static async Task<IResult> ImportBackup(
        IMaintenanceGate gate,
        IInventoryStore store,
        IManualStorage manuals,
        IFormFile? file,
        CancellationToken cancellationToken)
    {
        if (file is null)
        {
            return ApiJson.ToHttp(AppError.Unprocessable("Datei fehlt"));
        }

        if (file.Length > InventoryOperations.MaxZipBytes)
        {
            return ApiJson.ToHttp(AppError.Unprocessable("ZIP darf hoechstens 100 MB gross sein"));
        }

        if (!InventoryOperations.IsZipUpload(file.FileName, file.ContentType))
        {
            return ApiJson.ToHttp(AppError.Unprocessable("Nur ZIP-Dateien sind erlaubt"));
        }

        var tmp = Path.GetTempFileName();
        await using (var stream = File.Create(tmp))
        {
            await file.CopyToAsync(stream, cancellationToken).ConfigureAwait(false);
        }

        try
        {
            var result = await BackupOperations
                .ImportFromPath(gate, store, manuals, tmp, cancellationToken)
                .ConfigureAwait(false);
            return result.IsError ? ApiJson.ToHttp(result.Error) : Results.Json(new { Imported = true });
        }
        finally
        {
            File.Delete(tmp);
        }
    }

    private static async Task<IResult> BackupHistory(
        IInventoryStore store,
        string? page,
        CancellationToken cancellationToken)
    {
        var history = await InventoryOperations
            .BackupHistory(store, RequestParsing.Page(page), cancellationToken)
            .ConfigureAwait(false);
        return Results.Json(ApiJson.BackupHistory(history));
    }

    private static IResult Maintenance(IMaintenanceGate gate) =>
        Results.Json(new { Maintenance = gate.IsMaintenance });

    private static async Task<IResult> ListForValuation(IInventoryStore store, CancellationToken cancellationToken)
    {
        var modules = await InventoryOperations.ListForValuation(store, cancellationToken).ConfigureAwait(false);
        var ranges = await InventoryOperations
            .PriceRanges(store, modules.Select(m => m.Id).ToArray(), cancellationToken)
            .ConfigureAwait(false);
        return Results.Json(new
        {
            Modules = modules.Select(m => ApiJson.ValuationModule(m, ranges.GetValueOrDefault(m.Id)))
        });
    }

    private static async Task<IResult> ShowForValuation(
        IInventoryStore store,
        string id,
        CancellationToken cancellationToken)
    {
        var parsed = RequestParsing.ParseId(id);
        if (parsed is null)
        {
            return ApiJson.ToHttp(AppError.NotFound("Modul nicht gefunden"));
        }

        var result = await InventoryOperations.GetActive(store, parsed.Value, true, cancellationToken)
            .ConfigureAwait(false);
        if (result.IsError)
        {
            return ApiJson.ToHttp(result.Error);
        }

        var range = await InventoryOperations.PriceRange(store, result.Value.Id, cancellationToken)
            .ConfigureAwait(false);
        var payload = ApiJson.ValuationModule(result.Value, range);
        return Results.Json(new
        {
            Module = new
            {
                payload.Id,
                payload.Manufacturer,
                payload.Name,
                payload.Hp,
                payload.CurrentValue,
                payload.PriceRange,
                Observations = (result.Value.PriceObservations ?? []).Select(ApiJson.Observation)
            }
        });
    }

    private static string Sanitize(string? filename)
    {
        var value = (filename ?? string.Empty).Replace("\"", "_", StringComparison.Ordinal)
            .Replace("\\", "_", StringComparison.Ordinal)
            .Replace("\r", "_", StringComparison.Ordinal)
            .Replace("\n", "_", StringComparison.Ordinal)
            .Trim();
        return string.IsNullOrEmpty(value) ? "manual.pdf" : value;
    }
}
