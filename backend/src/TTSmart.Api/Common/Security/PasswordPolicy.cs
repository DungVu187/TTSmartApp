using System.ComponentModel.DataAnnotations;

namespace TTSmart.Api.Common.Security;

public static class PasswordPolicy
{
    public const string ValidationMessage = "Mật khẩu phải có ít nhất 8 ký tự, gồm chữ thường, chữ hoa, số và ký tự đặc biệt @#$%.";

    public static void Validate(string password)
    {
        if (string.IsNullOrEmpty(password) ||
            password.Length < 8 ||
            !password.Any(char.IsLower) ||
            !password.Any(char.IsUpper) ||
            !password.Any(char.IsDigit) ||
            !password.Any(character => character is '@' or '#' or '$' or '%'))
        {
            throw new ValidationException(ValidationMessage);
        }
    }
}