namespace TTSmart.Api.Features.Auth;

public interface IJwtTokenService
{
    JwtTokenResult CreateToken(CurrentUserResponse currentUser, DateTime? minimumIssuedAtUtc = null);
}
