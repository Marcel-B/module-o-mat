using Microsoft.Extensions.Configuration;
using ModuleOMat.Infrastructure.Backup;

namespace ModuleOMat.Api.Tests;

public class NextcloudOptionsTests
{
    [Fact]
    public void Load_bevorzugt_Env_gegenueber_deaktiviertem_Appsettings()
    {
        var config = AppsettingsDisabled();
        var options = NextcloudOptions.Load(config, name => name switch
        {
            "NEXTCLOUD_BACKUP_ENABLED" => "true",
            "NEXTCLOUD_WEBDAV_URL" => "https://cloud.example/dav/Backups/module-o-mat",
            "NEXTCLOUD_USERNAME" => "user",
            "NEXTCLOUD_APP_PASSWORD" => "app-pass",
            _ => null
        });

        Assert.True(options.IsConfigured);
        Assert.Equal("https://cloud.example/dav/Backups/module-o-mat", options.WebDavUrl);
        Assert.Null(options.DisableReason);
    }

    [Fact]
    public void Load_leere_Appsettings_Werte_verdecken_Env_nicht()
    {
        var config = AppsettingsDisabled();
        var options = NextcloudOptions.Load(config, name => name switch
        {
            "NEXTCLOUD_BACKUP_ENABLED" => "true",
            "NEXTCLOUD_WEBDAV_URL" => "https://cloud.example/dav",
            "NEXTCLOUD_USERNAME" => "user",
            "NEXTCLOUD_APP_PASSWORD" => "secret",
            _ => null
        });

        Assert.Equal("user", options.Username);
        Assert.Equal("secret", options.AppPassword);
    }

    [Fact]
    public void Load_ohne_Env_bleibt_deaktiviert()
    {
        var options = NextcloudOptions.Load(AppsettingsDisabled(), _ => null);

        Assert.False(options.IsConfigured);
        Assert.Equal("NEXTCLOUD_BACKUP_ENABLED ist nicht aktiv", options.DisableReason);
    }

    [Fact]
    public void ParseFlag_akzeptiert_True_Quotes_und_CRLF()
    {
        Assert.True(NextcloudOptions.ParseFlag("true", false));
        Assert.True(NextcloudOptions.ParseFlag("TRUE", false));
        Assert.True(NextcloudOptions.ParseFlag("True", false));
        Assert.True(NextcloudOptions.ParseFlag("1", false));
        Assert.True(NextcloudOptions.ParseFlag("yes", false));
        Assert.True(NextcloudOptions.ParseFlag("on", false));
        Assert.True(NextcloudOptions.ParseFlag("true\r\n", false));
        Assert.True(NextcloudOptions.ParseFlag("\"true\"", false));
        Assert.False(NextcloudOptions.ParseFlag("false", true));
        Assert.True(NextcloudOptions.ParseFlag("", true));
        Assert.False(NextcloudOptions.ParseFlag("", false));
        Assert.True(NextcloudOptions.ParseFlag(null, true));
        Assert.Equal("https://cloud.example/dav", NextcloudOptions.Normalize("  https://cloud.example/dav  \r\n"));
    }

    [Fact]
    public void DisableReason_nennt_fehlende_Credentials()
    {
        var options = new NextcloudOptions
        {
            Enabled = true,
            WebDavUrl = "https://x",
            Username = "u"
        };

        Assert.Equal("NEXTCLOUD_APP_PASSWORD fehlt", options.DisableReason);
    }

    private static IConfiguration AppsettingsDisabled() =>
        new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["Nextcloud:Enabled"] = "false",
                ["Nextcloud:WebDavUrl"] = "",
                ["Nextcloud:Username"] = "",
                ["Nextcloud:AppPassword"] = "",
                ["Nextcloud:BackupAt"] = "03:00",
                ["Nextcloud:Timezone"] = "Europe/Berlin"
            })
            .Build();
}
