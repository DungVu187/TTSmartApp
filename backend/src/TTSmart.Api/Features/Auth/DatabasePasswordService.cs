using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using TTSmart.Api.Data.WebAuth;
using Microsoft.Extensions.Options;

namespace TTSmart.Api.Features.Auth;

public sealed class DatabasePasswordService(IOptions<DatabasePasswordOptions> options) : IDatabasePasswordService
{
    public const string PendingPasswordHash = "00000000000000000000000000000000";

    private readonly DatabasePasswordOptions passwordOptions = options.Value;

    public bool Verify(WebUser user, string password)
    {
        if (user.Password.Length != 32)
        {
            return false;
        }

        byte[] expectedHash;
        try
        {
            expectedHash = Convert.FromHexString(user.Password);
        }
        catch (FormatException)
        {
            return false;
        }

        var actualHash = Convert.FromHexString(HashForStorage(user, password));
        return CryptographicOperations.FixedTimeEquals(expectedHash, actualHash);
    }

    public string HashForStorage(WebUser user, string password)
    {
        if (user.UserId <= 0)
        {
            throw new InvalidOperationException("UserId must be generated before hashing the password.");
        }

        var frontendHash = HashMd5(password, ResolveEncoding());
        var webPayload = string.Concat(
            user.KeyLock ?? string.Empty,
            user.RegEmail ?? string.Empty,
            user.UserId.ToString(CultureInfo.InvariantCulture),
            frontendHash);
        return HashMd5(webPayload, ResolveEncoding());
    }

    private Encoding ResolveEncoding() => passwordOptions.PasswordWriteMode switch
    {
        DatabasePasswordWriteMode.Md5Utf8 => Encoding.UTF8,
        DatabasePasswordWriteMode.Md5Unicode => Encoding.Unicode,
        _ => throw new InvalidOperationException("The configured database password hash mode is invalid.")
    };

    private static string HashMd5(string value, Encoding encoding) =>
        Convert.ToHexString(MD5.HashData(encoding.GetBytes(value))).ToLowerInvariant();
}
