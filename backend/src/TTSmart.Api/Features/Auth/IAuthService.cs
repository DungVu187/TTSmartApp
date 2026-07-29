namespace TTSmart.Api.Features.Auth;

public interface IAuthService
{
    Task<LoginResponse> LoginAsync(LoginRequest request, CancellationToken cancellationToken);
    Task<CurrentUserResponse> GetCurrentUserAsync(int userId, CancellationToken cancellationToken);
    Task LogoutAsync(int userId, DateTime tokenIssuedAtUtc, CancellationToken cancellationToken);
    Task ChangePasswordAsync(
        int userId,
        DateTime tokenIssuedAtUtc,
        ChangePasswordRequest request,
        CancellationToken cancellationToken);
}
