using System.ComponentModel.DataAnnotations;

namespace TTSmart.Api.Common.Security;

public static class PasswordPolicy
{
    public const string ValidationMessage = "Mật khẩu phải có ít nhất 4 ký tự.";

    public static void Validate(string password)
    {
        if (string.IsNullOrEmpty(password) || password.Length < 4)
        {
            throw new ValidationException(ValidationMessage);
        }
    }
}
