using Microsoft.AspNetCore.Authorization;

namespace TTSmart.Api.Features.Authorization;

public sealed class FunctionAccessRequirement : IAuthorizationRequirement
{
    public FunctionAccessRequirement(ActiveKeyPermission permission, params string[] functionCodes)
        : this(permission, true, functionCodes)
    {
    }

    public FunctionAccessRequirement(
        ActiveKeyPermission permission,
        bool allowSuperAdminBypass,
        params string[] functionCodes)
    {
        Permission = permission;
        AllowSuperAdminBypass = allowSuperAdminBypass;
        FunctionCodes = functionCodes;
    }

    public ActiveKeyPermission Permission { get; }

    public bool AllowSuperAdminBypass { get; }

    public IReadOnlyList<string> FunctionCodes { get; }
}
