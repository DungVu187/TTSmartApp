using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.FileProviders;
using TTSmart.Api.Features.CompanyManagement;

namespace TTSmart.Api.Tests;

public sealed class CompanyLogoStorageTests
{
    [Fact]
    public async Task LogoHopLe_DuocLuuDocVaXoaTrongThuMucBackend()
    {
        var rootPath = Path.Combine(Path.GetTempPath(), $"ttsmart-logo-{Guid.NewGuid():N}");
        try
        {
            var storage = new LocalCompanyLogoStorage(new TestHostEnvironment(rootPath));
            var bytes = new byte[] { 137, 80, 78, 71, 13, 10, 26, 10 };
            await using var input = new MemoryStream(bytes);
            var file = new FormFile(input, 0, bytes.Length, "file", "logo.png")
            {
                Headers = new HeaderDictionary(),
                ContentType = "image/png"
            };

            var stored = await storage.SaveAsync(file, CancellationToken.None);
            var read = await storage.OpenReadAsync(stored.FileName);

            Assert.NotNull(read);
            Assert.Equal("image/png", read.ContentType);
            await using (read.Content)
            {
                using var output = new MemoryStream();
                await read.Content.CopyToAsync(output);
                Assert.Equal(bytes, output.ToArray());
            }

            await storage.DeleteAsync(stored.FileName);
            Assert.Null(await storage.OpenReadAsync(stored.FileName));
        }
        finally
        {
            if (Directory.Exists(rootPath))
            {
                Directory.Delete(rootPath, recursive: true);
            }
        }
    }

    [Fact]
    public async Task LogoSaiContentType_BiTuChoi()
    {
        var rootPath = Path.Combine(Path.GetTempPath(), $"ttsmart-logo-{Guid.NewGuid():N}");
        var storage = new LocalCompanyLogoStorage(new TestHostEnvironment(rootPath));
        await using var input = new MemoryStream([1, 2, 3]);
        var file = new FormFile(input, 0, input.Length, "file", "logo.png")
        {
            Headers = new HeaderDictionary(),
            ContentType = "text/plain"
        };

        await Assert.ThrowsAsync<System.ComponentModel.DataAnnotations.ValidationException>(
            () => storage.SaveAsync(file, CancellationToken.None));
    }

    private sealed class TestHostEnvironment(string contentRootPath) : IWebHostEnvironment
    {
        public string ApplicationName { get; set; } = "TTSmart.Api.Tests";
        public IFileProvider WebRootFileProvider { get; set; } = new NullFileProvider();
        public string WebRootPath { get; set; } = contentRootPath;
        public string EnvironmentName { get; set; } = "Testing";
        public string ContentRootPath { get; set; } = contentRootPath;
        public IFileProvider ContentRootFileProvider { get; set; } = new NullFileProvider();
    }
}
