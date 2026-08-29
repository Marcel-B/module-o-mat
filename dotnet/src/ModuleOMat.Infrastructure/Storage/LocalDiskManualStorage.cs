using System.Text;
using ModuleOMat.Domain.Ports;

namespace ModuleOMat.Infrastructure.Storage;

public sealed class LocalDiskManualStorage(string uploadDir) : IManualStorage
{
    public string NewKey() => Guid.NewGuid().ToString();

    public bool LooksLikePdf(string path)
    {
        using var stream = File.OpenRead(path);
        var magic = "%PDF-"u8;
        Span<byte> buffer = stackalloc byte[5];
        var read = stream.Read(buffer);
        return read == 5 && buffer.SequenceEqual(magic);
    }

    public Task Store(string key, string sourcePath, CancellationToken cancellationToken)
    {
        var dest = PathFor(key);
        Directory.CreateDirectory(Path.GetDirectoryName(dest)!);
        File.Copy(sourcePath, dest, overwrite: true);
        return Task.CompletedTask;
    }

    public Task Delete(string? key, CancellationToken cancellationToken)
    {
        if (key is null)
        {
            return Task.CompletedTask;
        }

        var path = PathFor(key);
        if (File.Exists(path))
        {
            File.Delete(path);
        }

        return Task.CompletedTask;
    }

    public Task CopyOut(string key, string destPath, CancellationToken cancellationToken)
    {
        var source = PathFor(key);
        if (!File.Exists(source))
        {
            throw new FileNotFoundException("Manual nicht gefunden", source);
        }

        Directory.CreateDirectory(Path.GetDirectoryName(destPath)!);
        File.Copy(source, destPath, overwrite: true);
        return Task.CompletedTask;
    }

    public Task ReplaceAll(string sourceDir, CancellationToken cancellationToken)
    {
        Directory.CreateDirectory(uploadDir);
        foreach (var entry in Directory.EnumerateFileSystemEntries(uploadDir))
        {
            if (Directory.Exists(entry))
            {
                Directory.Delete(entry, recursive: true);
            }
            else
            {
                File.Delete(entry);
            }
        }

        if (Directory.Exists(sourceDir))
        {
            foreach (var file in Directory.EnumerateFiles(sourceDir))
            {
                File.Copy(file, Path.Combine(uploadDir, Path.GetFileName(file)), overwrite: true);
            }
        }

        return Task.CompletedTask;
    }

    public bool Exists(string key) => File.Exists(PathFor(key));

    public Stream OpenRead(string key) => File.OpenRead(PathFor(key));

    private string PathFor(string key) => Path.Combine(uploadDir, key);
}
