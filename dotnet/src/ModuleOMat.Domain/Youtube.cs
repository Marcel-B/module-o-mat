using System.Text.RegularExpressions;

namespace ModuleOMat.Domain;

public static partial class Youtube
{
    [GeneratedRegex(
        @"(?:youtube\.com/(?:watch\?(?:[^#]*&)?v=|embed/|shorts/)|youtu\.be/)([A-Za-z0-9_-]{11})",
        RegexOptions.CultureInvariant)]
    private static partial Regex VideoIdRegex();

    public static string? VideoId(string? url)
    {
        if (string.IsNullOrWhiteSpace(url))
        {
            return null;
        }

        var match = VideoIdRegex().Match(url.Trim());
        return match.Success ? match.Groups[1].Value : null;
    }

    public static string? WatchUrl(string? urlOrId)
    {
        var id = VideoId(urlOrId);
        return id is null ? null : $"https://www.youtube.com/watch?v={id}";
    }

    public static string? EmbedUrl(string? urlOrId, bool autoplay = false, bool mute = false)
    {
        var id = VideoId(urlOrId);
        if (id is null)
        {
            return null;
        }

        var baseUrl = $"https://www.youtube-nocookie.com/embed/{id}";
        var query = new List<string>();
        if (autoplay)
        {
            query.Add("autoplay=1");
        }

        if (mute)
        {
            query.Add("mute=1");
        }

        return query.Count == 0 ? baseUrl : $"{baseUrl}?{string.Join("&", query)}";
    }

    public static bool ValidUrl(string? url) => VideoId(url) is not null;
}
