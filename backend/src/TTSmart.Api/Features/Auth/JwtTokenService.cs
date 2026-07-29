using System.IdentityModel.Tokens.Jwt;
using System.Globalization;
using System.Security.Claims;
using System.Text;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;

namespace TTSmart.Api.Features.Auth;

public sealed class JwtTokenService(IOptions<JwtOptions> options) : IJwtTokenService
{
    private readonly JwtOptions jwtOptions = options.Value;

    public JwtTokenResult CreateToken(CurrentUserResponse currentUser, DateTime? minimumIssuedAtUtc = null)
    {
        var now = DateTime.UtcNow;
        var issuedAtUtc = ResolveIssuedAtUtc(now, minimumIssuedAtUtc);
        var expiresAtUtc = issuedAtUtc.AddMinutes(jwtOptions.AccessTokenMinutes);
        var claims = new List<Claim>
        {
            new(JwtRegisteredClaimNames.Sub, currentUser.User.Id.ToString()),
            new(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString()),
            new(
                JwtRegisteredClaimNames.Iat,
                EpochTime.GetIntDate(issuedAtUtc).ToString(CultureInfo.InvariantCulture),
                ClaimValueTypes.Integer64),
            new(JwtRegisteredClaimNames.UniqueName, currentUser.User.UserName),
            new("full_name", currentUser.User.FullName ?? currentUser.User.UserName)
        };
        claims.AddRange(currentUser.Roles.Select(role => new Claim("role", role.Code)));

        var signingKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtOptions.SigningKey));
        var token = new JwtSecurityToken(
            issuer: jwtOptions.Issuer,
            audience: jwtOptions.Audience,
            claims: claims,
            notBefore: now,
            expires: expiresAtUtc,
            signingCredentials: new SigningCredentials(signingKey, SecurityAlgorithms.HmacSha256));

        return new JwtTokenResult(new JwtSecurityTokenHandler().WriteToken(token), expiresAtUtc);
    }

    private static DateTime ResolveIssuedAtUtc(DateTime nowUtc, DateTime? minimumIssuedAtUtc)
    {
        var issuedAtSeconds = EpochTime.GetIntDate(nowUtc);
        if (minimumIssuedAtUtc.HasValue)
        {
            var minimumUtc = DateTime.SpecifyKind(minimumIssuedAtUtc.Value, DateTimeKind.Utc);
            issuedAtSeconds = Math.Max(issuedAtSeconds, EpochTime.GetIntDate(minimumUtc) + 1);
        }

        return DateTimeOffset.FromUnixTimeSeconds(issuedAtSeconds).UtcDateTime;
    }
}
