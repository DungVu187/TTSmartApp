using TTSmart.Api.Data.WebAuth;
using TTSmart.Api.Features.Auth;
using Microsoft.Extensions.Options;

namespace TTSmart.Api.Tests;

public sealed class DatabasePasswordServiceTests
{
    [Fact]
    public void HashForStorage_BamDungCongThucHaiLopCuaWebsite()
    {
        var service = CreatePasswordService();
        var user = new WebUser
        {
            UserId = 42,
            KeyLock = "LOCK-01",
            RegEmail = "admin@ttsmart.vn",
            Password = DatabasePasswordService.PendingPasswordHash
        };

        var hash = service.HashForStorage(user, "Password@123");

        Assert.Equal("d93a65a0636d87e37a8d23981f8c35df", hash);
        user.Password = hash.ToUpperInvariant();
        Assert.True(service.Verify(user, "Password@123"));
        Assert.False(service.Verify(user, "Password@124"));
    }

    [Fact]
    public void HashForStorage_TuChoiKhiChuaCoUserId()
    {
        var service = CreatePasswordService();
        var user = new WebUser
        {
            Password = DatabasePasswordService.PendingPasswordHash
        };

        Assert.Throws<InvalidOperationException>(() => service.HashForStorage(user, "Password@123"));
    }

    private static DatabasePasswordService CreatePasswordService() =>
        new(Options.Create(new DatabasePasswordOptions
        {
            PasswordWriteMode = DatabasePasswordWriteMode.Md5Utf8
        }));
}
