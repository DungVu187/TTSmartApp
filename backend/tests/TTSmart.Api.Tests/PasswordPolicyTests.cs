using System.ComponentModel.DataAnnotations;
using TTSmart.Api.Common.Security;

namespace TTSmart.Api.Tests;

public sealed class PasswordPolicyTests
{
    [Theory]
    [InlineData("Ab1@")]
    [InlineData("PASSWORD1@")]
    [InlineData("password1@")]
    [InlineData("Password@@")]
    [InlineData("Password12")]
    public void MatKhauKhongDuDieuKien_BiTuChoi(string password)
    {
        Assert.Throws<ValidationException>(() => PasswordPolicy.Validate(password));
    }

    [Fact]
    public void MatKhauDuDieuKien_DuocChapNhan()
    {
        PasswordPolicy.Validate("Password@123");
    }
}