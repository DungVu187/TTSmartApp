using System.Globalization;
using System.Security.Claims;
using System.IdentityModel.Tokens.Jwt;
using TTSmart.Api.Common.Exceptions;

namespace TTSmart.Api.Common.Security;

public static class ClaimsPrincipalExtensions
{
    public static bool TryGetUserId(this ClaimsPrincipal principal, out int userId)
    {
        var userIdValue = principal.FindFirstValue(ClaimTypes.NameIdentifier)
            ?? principal.FindFirstValue(JwtRegisteredClaimNames.Sub)
            ?? principal.FindFirstValue("nameid");
        return int.TryParse(userIdValue, out userId) && userId > 0;
    }

    public static int GetRequiredUserId(this ClaimsPrincipal principal)
    {
        if (!principal.TryGetUserId(out var userId))
        {
            throw new UnauthorizedException("Token đăng nhập không hợp lệ.");
        }

        return userId;
    }

    public static bool TryGetIssuedAtUtc(this ClaimsPrincipal principal, out DateTime issuedAtUtc)
    {
        issuedAtUtc = default;
        var issuedAtValue = principal.FindFirstValue(JwtRegisteredClaimNames.Iat);
        if (!long.TryParse(
                issuedAtValue,
                NumberStyles.Integer,
                CultureInfo.InvariantCulture,
                out var issuedAtSeconds))
        {
            return false;
        }

        try
        {
            issuedAtUtc = DateTimeOffset.FromUnixTimeSeconds(issuedAtSeconds).UtcDateTime;
            return true;
        }
        catch (ArgumentOutOfRangeException)
        {
            return false;
        }
    }

    public static DateTime GetRequiredIssuedAtUtc(this ClaimsPrincipal principal)
    {
        if (!principal.TryGetIssuedAtUtc(out var issuedAtUtc))
        {
            throw new UnauthorizedException("Token đăng nhập thiếu thời điểm phát hành hợp lệ.");
        }

        return issuedAtUtc;
    }
}
