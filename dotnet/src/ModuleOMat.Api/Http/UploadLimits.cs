using Microsoft.AspNetCore.Http.Features;
using Microsoft.AspNetCore.Server.Kestrel.Core;
using ModuleOMat.Domain;

namespace ModuleOMat.Api.Http;

public static class UploadLimits
{
    public const long MultipartBytes = InventoryOperations.MaxZipBytes + 16_000_000;

    public static void Configure(WebApplicationBuilder builder)
    {
        builder.Services.PostConfigure<KestrelServerOptions>(options =>
        {
            options.Limits.MaxRequestBodySize = null;
        });
        builder.WebHost.ConfigureKestrel(options =>
        {
            options.Limits.MaxRequestBodySize = null;
        });
        builder.Services.Configure<FormOptions>(options =>
        {
            options.MultipartBodyLengthLimit = MultipartBytes;
            options.ValueLengthLimit = int.MaxValue;
        });
    }

    public static IApplicationBuilder AllowLargeUploads(this IApplicationBuilder app) =>
        app.Use(async (context, next) =>
        {
            var feature = context.Features.Get<IHttpMaxRequestBodySizeFeature>();
            if (feature is { IsReadOnly: false })
            {
                feature.MaxRequestBodySize = null;
            }

            await next().ConfigureAwait(false);
        });
}
