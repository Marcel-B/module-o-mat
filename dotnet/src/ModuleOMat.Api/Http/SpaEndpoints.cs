namespace ModuleOMat.Api.Http;

public static class SpaEndpoints
{
    public static WebApplication MapSpaFallback(this WebApplication app, bool serveBuiltUi = true)
    {
        if (serveBuiltUi)
        {
            app.MapGet("/ui/{**path}", (HttpContext context) => ServeSpa(context, "ui"))
                .ExcludeFromDescription();
            app.MapGet("/ui", (HttpContext context) => ServeSpa(context, "ui"))
                .ExcludeFromDescription();
        }

        app.MapGet("/ui-alt/{**path}", (HttpContext context) => ServeSpa(context, "ui-alt"))
            .ExcludeFromDescription();
        app.MapGet("/ui-alt", (HttpContext context) => ServeSpa(context, "ui-alt"))
            .ExcludeFromDescription();
        return app;
    }

    private static IResult ServeSpa(HttpContext context, string name)
    {
        var env = context.RequestServices.GetRequiredService<IWebHostEnvironment>();
        var requestPath = context.Request.Path.Value ?? string.Empty;
        var relative = requestPath.StartsWith($"/{name}", StringComparison.OrdinalIgnoreCase)
            ? requestPath[$"/{name}".Length..].TrimStart('/')
            : string.Empty;

        if (!string.IsNullOrEmpty(relative))
        {
            var file = Path.Combine(env.WebRootPath ?? "wwwroot", name, relative);
            if (File.Exists(file) && IsSafe(env.WebRootPath ?? "wwwroot", file))
            {
                return Results.File(file, contentType: GuessContentType(file));
            }
        }

        var index = Path.Combine(env.WebRootPath ?? "wwwroot", name, "index.html");
        if (File.Exists(index))
        {
            return Results.File(index, "text/html; charset=utf-8");
        }

        return Results.Json(
            new { error = $"Die Oberflaeche \"{name}\" wurde noch nicht gebaut. {(name == "ui" ? "Lokal: npm run build in src/ModuleOMat.Api/ClientApp." : "Lokal: npm run build in module_o_mat/ui-alt.")}" },
            statusCode: StatusCodes.Status503ServiceUnavailable);
    }

    private static bool IsSafe(string root, string file)
    {
        var fullRoot = Path.GetFullPath(root);
        var fullFile = Path.GetFullPath(file);
        return fullFile.StartsWith(fullRoot, StringComparison.Ordinal);
    }

    private static string GuessContentType(string file) =>
        Path.GetExtension(file).ToLowerInvariant() switch
        {
            ".js" => "text/javascript",
            ".css" => "text/css",
            ".html" => "text/html; charset=utf-8",
            ".svg" => "image/svg+xml",
            ".png" => "image/png",
            ".jpg" or ".jpeg" => "image/jpeg",
            ".woff2" => "font/woff2",
            ".json" => "application/json",
            _ => "application/octet-stream"
        };
}
