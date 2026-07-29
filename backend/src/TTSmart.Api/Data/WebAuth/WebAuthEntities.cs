namespace TTSmart.Api.Data.WebAuth;

public sealed class WebUser
{
    public int UserId { get; set; }
    public string? FullName { get; set; }
    public string UserName { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
    public string? Email { get; set; }
    public string? Code { get; set; }
    public string? Avata { get; set; }
    public int? UnitId { get; set; }
    public int? PositionId { get; set; }
    public int? DepartmentId { get; set; }
    public int? CompanyId { get; set; }
    public string? Address { get; set; }
    public string? Phone { get; set; }
    public string? KeyLock { get; set; }
    public DateTime? CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public DateTime? TokenSince { get; set; }
    public string? RegEmail { get; set; }
    public int? RoleMax { get; set; }
    public byte? RoleLevel { get; set; }
    public bool? IsRoleGroup { get; set; }
    public int? UserCreateId { get; set; }
    public int? UserEditId { get; set; }
    public byte? Status { get; set; }
    public string? BranchId { get; set; }
    public ICollection<WebUserRole> UserRoles { get; } = [];
}

public sealed class WebRole
{
    public int RoleId { get; set; }
    public string Code { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string? Note { get; set; }
    public DateTime? CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public int? UserEditId { get; set; }
    public int? UserId { get; set; }
    public byte? LevelRole { get; set; }
    public byte? Status { get; set; }
    public ICollection<WebUserRole> UserRoles { get; } = [];
}

public sealed class WebUserRole
{
    public int UserRoleId { get; set; }
    public int UserId { get; set; }
    public int RoleId { get; set; }
    public DateTime? CreatedAt { get; set; }
    public byte? Status { get; set; }
    public WebUser User { get; set; } = null!;
    public WebRole Role { get; set; } = null!;
}

public sealed class WebFunction
{
    public int FunctionId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Code { get; set; } = string.Empty;
    public int FunctionParentId { get; set; }
    public string? Url { get; set; }
    public string? Note { get; set; }
    public int? Location { get; set; }
    public string? Icon { get; set; }
    public DateTime? CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public int? UserId { get; set; }
    public byte? Status { get; set; }
    public ICollection<WebFunctionRole> FunctionRoles { get; } = [];
}

public sealed class WebFunctionRole
{
    public int FunctionRoleId { get; set; }
    public int TargetId { get; set; }
    public int FunctionId { get; set; }
    public string? ActiveKey { get; set; }
    public byte? Type { get; set; }
    public DateTime? CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public int? UserId { get; set; }
    public byte? Status { get; set; }
    public WebFunction Function { get; set; } = null!;
}
