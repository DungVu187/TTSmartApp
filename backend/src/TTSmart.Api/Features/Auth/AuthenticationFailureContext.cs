namespace TTSmart.Api.Features.Auth;

public static class AuthenticationFailureContext
{
    public const string DetailItemKey = "authentication_failure_detail";
    public const string CodeItemKey = "authentication_failure_code";
    public const string SessionRevokedCode = "session_revoked";
    public const string SessionRevokedMessage = "Phiên đăng nhập đã kết thúc. Vui lòng đăng nhập lại.";
}
