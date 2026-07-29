using System.ComponentModel.DataAnnotations;

namespace TTSmart.Api.Features.CompanyManagement;

public sealed record CompanyLogoStoredFile(string FileName);

public sealed record CompanyLogoReadResult(Stream Content, string ContentType, string DownloadName);

public interface ICompanyLogoStorage
{
    Task<CompanyLogoStoredFile> SaveAsync(IFormFile file, CancellationToken cancellationToken);

    Task<CompanyLogoReadResult?> OpenReadAsync(string? fileName);

    Task DeleteAsync(string? fileName);
}

public sealed class LocalCompanyLogoStorage(IHostEnvironment environment) : ICompanyLogoStorage
{
    private const long MaxFileLength = 5 * 1024 * 1024;
    private static readonly IReadOnlyDictionary<string, string[]> AllowedContentTypes =
        new Dictionary<string, string[]>(StringComparer.OrdinalIgnoreCase)
        {
            [".jpg"] = ["image/jpeg", "image/jpg"],
            [".jpeg"] = ["image/jpeg", "image/jpg"],
            [".png"] = ["image/png"],
            [".webp"] = ["image/webp"]
        };

    private string StorageDirectory => Path.Combine(environment.ContentRootPath, "uploads", "company-logos");

    public async Task<CompanyLogoStoredFile> SaveAsync(
        IFormFile file,
        CancellationToken cancellationToken)
    {
        if (file.Length <= 0 || file.Length > MaxFileLength)
        {
            throw new ValidationException("Logo phải có dung lượng từ 1 byte đến 5 MB.");
        }

        var extension = Path.GetExtension(file.FileName).ToLowerInvariant();
        if (!AllowedContentTypes.TryGetValue(extension, out var contentTypes) ||
            !contentTypes.Contains(file.ContentType, StringComparer.OrdinalIgnoreCase))
        {
            throw new ValidationException(
                "Logo chỉ nhận JPG, JPEG, PNG hoặc WEBP và content type phải hợp lệ.");
        }

        Directory.CreateDirectory(StorageDirectory);
        var fileName = $"{Guid.NewGuid():N}{extension}";
        var path = GetSafePath(fileName)
            ?? throw new InvalidOperationException("Đường dẫn lưu logo không hợp lệ.");
        await using var output = new FileStream(path, FileMode.CreateNew, FileAccess.Write, FileShare.None);
        await file.CopyToAsync(output, cancellationToken);
        return new CompanyLogoStoredFile(fileName);
    }

    public Task<CompanyLogoReadResult?> OpenReadAsync(string? fileName)
    {
        var path = GetSafePath(fileName);
        if (path is null || !File.Exists(path))
        {
            return Task.FromResult<CompanyLogoReadResult?>(null);
        }

        var stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read);
        return Task.FromResult<CompanyLogoReadResult?>(
            new CompanyLogoReadResult(stream, ResolveContentType(path), Path.GetFileName(fileName!)));
    }

    public Task DeleteAsync(string? fileName)
    {
        var path = GetSafePath(fileName);
        if (path is not null && File.Exists(path))
        {
            File.Delete(path);
        }

        return Task.CompletedTask;
    }

    private string? GetSafePath(string? fileName)
    {
        if (string.IsNullOrWhiteSpace(fileName) || fileName != Path.GetFileName(fileName))
        {
            return null;
        }

        var directory = Path.GetFullPath(StorageDirectory);
        var path = Path.GetFullPath(Path.Combine(directory, fileName));
        return path.StartsWith(directory + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase)
            ? path
            : null;
    }

    private static string ResolveContentType(string path) =>
        Path.GetExtension(path).ToLowerInvariant() switch
        {
            ".jpg" or ".jpeg" => "image/jpeg",
            ".png" => "image/png",
            ".webp" => "image/webp",
            _ => "application/octet-stream"
        };
}
