using System.ComponentModel.DataAnnotations;
using TTSmart.Api.Common.Security;

namespace TTSmart.Api.Tests;

public sealed class PasswordPolicyTests
{
    [Theory]
    [InlineData("")]
    [InlineData("123")]
    public void MatKhauKhongDuDieuKien_BiTuChoi(string password)
    {
        Assert.Throws<ValidationException>(() => PasswordPolicy.Validate(password));
    }

    [Fact]
    public void MatKhauDuDieuKien_DuocChapNhan()
    {
        PasswordPolicy.Validate("1234");
    }
}
