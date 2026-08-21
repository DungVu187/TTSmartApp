using System.ComponentModel.DataAnnotations;
using TTSmart.Api.Features.Authorization;

namespace TTSmart.Api.Features.AccessManagement;

public abstract class PagedQuery
{
    [Range(1, int.MaxValue, ErrorMessage = "Số trang phải lớn hơn hoặc bằng 1.")]
    public int PageNumber { get; init; } = 1;

    [Range(1, 100, ErrorMessage = "Kích thước trang phải từ 1 đến 100.")]
    public int PageSize { get; init; } = 20;
}

public sealed class UserListQuery : PagedQuery
{
    [StringLength(100, ErrorMessage = "Từ khóa tìm kiếm không được vượt quá 100 ký tự.")]
    public string? Search { get; init; }
    public byte? Status { get; init; }
    public int? RoleId { get; init; }
}

public sealed class RoleListQuery : PagedQuery
{
    [StringLength(100, ErrorMessage = "Từ khóa tìm kiếm không được vượt quá 100 ký tự.")]
    public string? Search { get; init; }
    public byte? Status { get; init; }
}

public sealed class FunctionListQuery
{
    [StringLength(100, ErrorMessage = "Từ khóa tìm kiếm không được vượt quá 100 ký tự.")]
    public string? Search { get; init; }
    public byte? Status { get; init; }
}

public sealed record RoleReferenceResponse(
    int Id,
    string Code,
    string Name,
    byte? LevelRole,
    byte Status);

public sealed record UserResponse(
    int Id,
    string UserName,
    string? FullName,
    string? Email,
    string? Code,
    string? Avata,
    int? UnitId,
    int? PositionId,
    int? DepartmentId,
    int? CompanyId,
    string? Address,
    string? Phone,
    DateTime? CreatedAtUtc,
    DateTime? UpdatedAtUtc,
    DateTime? TokenSinceUtc,
    string? RegEmail,
    int? RoleMax,
    byte? RoleLevel,
    bool? IsRoleGroup,
    int? UserCreateId,
    int? UserEditId,
    byte Status,
    bool IsActive,
    string? BranchId,
    IReadOnlyList<RoleReferenceResponse> Roles);

public abstract class UserFieldsRequest
{
    [Required(ErrorMessage = "Tên đăng nhập là bắt buộc.")]
    [StringLength(100, ErrorMessage = "Tên đăng nhập không được vượt quá 100 ký tự.")]
    public string UserName { get; init; } = string.Empty;

    [StringLength(200, ErrorMessage = "Họ tên không được vượt quá 200 ký tự.")]
    public string? FullName { get; init; }

    [EmailAddress(ErrorMessage = "Email không hợp lệ.")]
    [StringLength(50, ErrorMessage = "Email không được vượt quá 50 ký tự.")]
    public string? Email { get; init; }

    [StringLength(100, ErrorMessage = "Mã người dùng không được vượt quá 100 ký tự.")]
    public string? Code { get; init; }

    [StringLength(100, ErrorMessage = "Email đăng ký không được vượt quá 100 ký tự.")]
    public string? RegEmail { get; init; }

    [StringLength(200, ErrorMessage = "Địa chỉ không được vượt quá 200 ký tự.")]
    public string? Address { get; init; }

    [StringLength(50, ErrorMessage = "Số điện thoại không được vượt quá 50 ký tự.")]
    public string? Phone { get; init; }

    public int? UnitId { get; init; }
    public int? PositionId { get; init; }
    public int? DepartmentId { get; init; }
    public int? CompanyId { get; init; }
    public int? RoleMax { get; init; }
    public byte? RoleLevel { get; init; }
    public bool? IsRoleGroup { get; init; }

    [StringLength(1000, ErrorMessage = "BranchId không được vượt quá 1000 ký tự.")]
    public string? BranchId { get; init; }
}

public sealed class CreateUserRequest : UserFieldsRequest
{
    [Required(ErrorMessage = "Mật khẩu là bắt buộc.")]
    [StringLength(200, MinimumLength = 4, ErrorMessage = "Mật khẩu phải có từ 4 đến 200 ký tự.")]
    public string Password { get; init; } = string.Empty;

    public IReadOnlyList<int> RoleIds { get; init; } = [];
}

public sealed class UpdateUserRequest : UserFieldsRequest
{
    public IReadOnlyList<int>? RoleIds { get; init; }
}

public sealed class SetUserStatusRequest
{
    [Required(ErrorMessage = "Trạng thái hiệu lực là bắt buộc.")]
    public bool? IsActive { get; init; }
}

public sealed class SetUserRolesRequest
{
    public IReadOnlyList<int> RoleIds { get; init; } = [];
}

public sealed class ResetPasswordRequest;

public sealed record RoleListItemResponse(
    int Id,
    string Code,
    string Name,
    string? Note,
    byte? LevelRole,
    byte Status,
    bool IsActive,
    int UserCount,
    int FunctionCount,
    int GrantedFunctionCount);

public sealed record RoleFunctionResponse(
    int FunctionRoleId,
    int FunctionId,
    int? ParentFunctionId,
    string Code,
    string Name,
    string? Url,
    int? Location,
    string? Icon,
    byte? Type,
    string ActiveKey,
    PermissionResponse Permissions,
    byte Status,
    bool IsActive);

public sealed record RoleResponse(
    int Id,
    string Code,
    string Name,
    string? Note,
    DateTime? CreatedAtUtc,
    DateTime? UpdatedAtUtc,
    int? UserEditId,
    int? UserId,
    byte? LevelRole,
    byte Status,
    bool IsActive,
    int UserCount,
    IReadOnlyList<RoleFunctionResponse> Functions);

public sealed record RoleFunctionMatrixItemResponse(
    int FunctionId,
    int? ParentFunctionId,
    string Code,
    string Name,
    string? Url,
    int? Location,
    string? Icon,
    int? FunctionRoleId,
    bool IsAssigned,
    string ActiveKey,
    PermissionResponse Permissions);

public class CreateRoleRequest
{
    [Required(ErrorMessage = "Mã vai trò là bắt buộc.")]
    [StringLength(100, ErrorMessage = "Mã vai trò không được vượt quá 100 ký tự.")]
    public string Code { get; init; } = string.Empty;

    [Required(ErrorMessage = "Tên vai trò là bắt buộc.")]
    [StringLength(1000, ErrorMessage = "Tên vai trò không được vượt quá 1000 ký tự.")]
    public string Name { get; init; } = string.Empty;

    public string? Note { get; init; }
    public byte? LevelRole { get; init; }
}

public sealed class UpdateRoleRequest : CreateRoleRequest
{
}

public sealed class SetRoleStatusRequest
{
    [Required(ErrorMessage = "Trạng thái hiệu lực là bắt buộc.")]
    public bool? IsActive { get; init; }
}

public sealed class RoleFunctionAssignmentRequest
{
    [Range(1, int.MaxValue, ErrorMessage = "FunctionId không hợp lệ.")]
    public int FunctionId { get; init; }

    [Required(ErrorMessage = "ActiveKey là bắt buộc.")]
    [RegularExpression("^[01]{9}$", ErrorMessage = "ActiveKey phải gồm đúng 9 ký tự 0 hoặc 1.")]
    public string ActiveKey { get; init; } = string.Empty;
}

public sealed class SetRoleFunctionActiveKeyRequest
{
    [Required(ErrorMessage = "ActiveKey là bắt buộc.")]
    [RegularExpression("^[01]{9}$", ErrorMessage = "ActiveKey phải gồm đúng 9 ký tự 0 hoặc 1.")]
    public string ActiveKey { get; init; } = string.Empty;
}

public sealed class SetRoleFunctionsRequest
{
    public IReadOnlyList<RoleFunctionAssignmentRequest> Functions { get; init; } = [];
}

public sealed record PermissionResponse(
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

public sealed record FunctionResponse(
    int Id,
    int? ParentFunctionId,
    string Code,
    string Name,
    string? Url,
    string? Note,
    int? Location,
    string? Icon,
    DateTime? CreatedAtUtc,
    DateTime? UpdatedAtUtc,
    int? UserId,
    byte Status,
    bool IsActive,
    int ChildCount,
    int AssignedRoleCount,
    int GrantedRoleCount);

public sealed record FunctionTreeNodeResponse(
    int Id,
    int? ParentFunctionId,
    string Code,
    string Name,
    string? Url,
    string? Note,
    int? Location,
    string? Icon,
    byte Status,
    bool IsActive,
    int AssignedRoleCount,
    int GrantedRoleCount,
    IReadOnlyList<FunctionTreeNodeResponse> Children);

public abstract class FunctionFieldsRequest
{
    public int? ParentFunctionId { get; init; }

    [Required(ErrorMessage = "Mã function là bắt buộc.")]
    [StringLength(100, ErrorMessage = "Mã function không được vượt quá 100 ký tự.")]
    public string Code { get; init; } = string.Empty;

    [Required(ErrorMessage = "Tên function là bắt buộc.")]
    [StringLength(200, ErrorMessage = "Tên function không được vượt quá 200 ký tự.")]
    public string Name { get; init; } = string.Empty;

    [StringLength(400, ErrorMessage = "Url không được vượt quá 400 ký tự.")]
    public string? Url { get; init; }

    [StringLength(4000, ErrorMessage = "Note không được vượt quá 4000 ký tự.")]
    public string? Note { get; init; }

    public int? Location { get; init; }

    [StringLength(1000, ErrorMessage = "Icon không được vượt quá 1000 ký tự.")]
    public string? Icon { get; init; }
}

public sealed class CreateFunctionRequest : FunctionFieldsRequest
{
}

public sealed class UpdateFunctionRequest : FunctionFieldsRequest
{
}

public sealed class SetFunctionStatusRequest
{
    [Required(ErrorMessage = "Trạng thái hiệu lực là bắt buộc.")]
    public bool? IsActive { get; init; }
}
