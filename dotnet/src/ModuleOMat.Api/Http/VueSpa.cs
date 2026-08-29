using Microsoft.AspNetCore.SpaServices.ReactDevelopmentServer;

namespace ModuleOMat.Api.Http;

public static class VueSpa
{
    public static WebApplication UseVueDevelopmentServer(this WebApplication app)
    {
        app.MapWhen(
            static context => context.Request.Path.StartsWithSegments("/ui"),
            spaApp =>
            {
                spaApp.UseSpa(spa =>
                {
                    spa.Options.SourcePath = "ClientApp";
                    spa.Options.DevServerPort = 5173;
                    spa.Options.StartupTimeout = TimeSpan.FromSeconds(120);
                    spa.UseReactDevelopmentServer(npmScript: "dev");
                });
            });
        return app;
    }
}
