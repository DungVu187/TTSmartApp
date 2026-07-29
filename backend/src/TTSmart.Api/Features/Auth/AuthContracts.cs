using System.ComponentModel.DataAnnotations;

namespace TTSmart.Api.Features.Auth;

public sealed class LoginRequest
{
    [Required(ErrorMessage = "Tên đăng nhập là bắt buộc.")]
    [StringLength(100, ErrorMessage = "Tên đăng nhập không được vượt quá 100 ký tự.")]
    public string UserName { get; init; } = string.Empty;

    [Required(ErrorMessage = "Mật khẩu là bắt buộc.")]
    [StringLength(200, MinimumLength = 1, ErrorMessage = "Mật khẩu không hợp lệ.")]
    public string Password { get; init; } = string.Empty;
}

public sealed class ChangePasswordRequest
{
    [Required(ErrorMessage = "Mật khẩu hiện tại là bắt buộc.")]
    [StringLength(200, MinimumLength = 1, ErrorMessage = "Mật khẩu hiện tại không hợp lệ.")]
    public string CurrentPassword { get; init; } = string.Empty;

    [Required(ErrorMessage = "Mật khẩu mới là bắt buộc.")]
    [StringLength(200, MinimumLength = 8, ErrorMessage = "Mật khẩu mới phải có từ 8 đến 200 ký tự.")]
    public string NewPassword { get; init; } = string.Empty;
}

public sealed record AuthRoleResponse(int Id, string Code, string Name, byte? LevelRole);

public sealed record AuthPermissionResponse(
    bool View,
    bool Create,
    bool Update,
    bool Delete,
    bool Import,
    bool Export,
    bool Print,
    bool Other,
    bool DSach,
    bool Full);

public sealed record AuthUserResponse(
    int Id,
    string UserName,
    string? FullName,
    string? Email,
    string? Code,
    string? Phone,
    int? CompanyId,
    int? DepartmentId,
    int? PositionId,
    int? UnitId,
    string? BranchId,
    byte Status);

public sealed record AuthFunctionResponse(
    int Id,
    int? ParentFunctionId,
    string Code,
    string Name,
    string? Url,
    int? Location,
    string? Icon,
    string ActiveKey,
    AuthPermissionResponse Permissions);

public sealed record AuthRoleFunctionResponse(
    int RoleId,
    string RoleCode,
    string RoleName,
    int FunctionRoleId,
    int FunctionId,
    int? ParentFunctionId,
    string FunctionCode,
    string FunctionName,
    string? Url,
    byte? Type,
    string ActiveKey,
    AuthPermissionResponse Permissions);

public sealed record CurrentUserResponse(
    AuthUserResponse User,
    IReadOnlyList<AuthRoleResponse> Roles,
    IReadOnlyList<AuthFunctionResponse> Functions,
    IReadOnlyList<AuthRoleFunctionResponse> RoleFunctions);

public sealed record LoginResponse(
    string AccessToken,
    DateTime ExpiresAtUtc,
    AuthUserResponse User,
    IReadOnlyList<AuthRoleResponse> Roles,
    IReadOnlyList<AuthFunctionResponse> Functions,
    IReadOnlyList<AuthRoleFunctionResponse> RoleFunctions);

public sealed record JwtTokenResult(string AccessToken, DateTime ExpiresAtUtc);
