using System.Net.Http.Headers;
using ModuleOMat.Domain;
using ModuleOMat.Domain.Ports;

namespace ModuleOMat.Infrastructure.WebDav;

public sealed class HttpWebDavClient(IHttpClientFactory httpClientFactory) : IWebDavClient
{
    public async Task<Result<Unit>> PutFile(
        string baseUrl,
        string filename,
        string localPath,
        string username,
        string password,
        TimeSpan timeout,
        CancellationToken cancellationToken)
    {
        if (!File.Exists(localPath))
        {
            return Result.Fail<Unit>(AppError.Unprocessable($"Datei nicht gefunden: {localPath}"));
        }

        var client = httpClientFactory.CreateClient("webdav");
        client.Timeout = timeout;
        using var request = new HttpRequestMessage(HttpMethod.Put, Join(baseUrl, filename));
        request.Headers.Authorization = Basic(username, password);
        await using var stream = File.OpenRead(localPath);
        request.Content = new StreamContent(stream);
        try
        {
            using var response = await client.SendAsync(request, cancellationToken).ConfigureAwait(false);
            return response.IsSuccessStatusCode
                ? Result.Ok()
                : Result.Fail(AppError.Unprocessable(
                    $"WebDAV PUT fehlgeschlagen (HTTP {(int)response.StatusCode}): {Join(baseUrl, filename)}"));
        }
        catch (TaskCanceledException)
        {
            return Result.Fail(AppError.Unprocessable(
                $"HTTP-Timeout nach {(int)timeout.TotalSeconds}s beim Nextcloud-Upload"));
        }
    }

    public async Task<Result<Unit>> EnsureCollection(
        string baseUrl,
        string username,
        string password,
        TimeSpan timeout,
        CancellationToken cancellationToken)
    {
        var client = httpClientFactory.CreateClient("webdav");
        client.Timeout = timeout;
        using var request = new HttpRequestMessage(new HttpMethod("MKCOL"), baseUrl.TrimEnd('/'));
        request.Headers.Authorization = Basic(username, password);
        using var response = await client.SendAsync(request, cancellationToken).ConfigureAwait(false);
        var status = (int)response.StatusCode;
        return status is >= 200 and <= 299 or 405 or 409
            ? Result.Ok()
            : Result.Fail(AppError.Unprocessable($"WebDAV MKCOL fehlgeschlagen (HTTP {status}): {baseUrl}"));
    }

    private static AuthenticationHeaderValue Basic(string username, string password) =>
        new("Basic", Convert.ToBase64String(System.Text.Encoding.UTF8.GetBytes($"{username}:{password}")));

    private static string Join(string baseUrl, string filename) =>
        $"{baseUrl.TrimEnd('/')}/{filename.TrimStart('/')}";
}
