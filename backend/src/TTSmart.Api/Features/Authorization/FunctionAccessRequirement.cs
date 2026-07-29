using Microsoft.AspNetCore.Authorization;

namespace TTSmart.Api.Features.Authorization;

public sealed class FunctionAccessRequirement : IAuthorizationRequirement
{
    public FunctionAccessRequirement(ActiveKeyPermission permission, params string[] functionCodes)
    {
        Permission = permission;
        FunctionCodes = functionCodes;
    }

    public ActiveKeyPermission Permission { get; }

    public IReadOnlyList<string> FunctionCodes { get; }
}
