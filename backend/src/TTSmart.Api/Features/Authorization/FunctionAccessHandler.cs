using TTSmart.Api.Common.Security;
using TTSmart.Api.Data.WebAuth;
using Microsoft.AspNetCore.Authorization;
using Microsoft.EntityFrameworkCore;

namespace TTSmart.Api.Features.Authorization;

public sealed class FunctionAccessHandler(
    WebAuthDbContext dbContext,
    IHttpContextAccessor httpContextAccessor,
    ISystemRoleEvaluator? systemRoleEvaluator = null) : AuthorizationHandler<FunctionAccessRequirement>
{
    protected override async Task HandleRequirementAsync(
        AuthorizationHandlerContext context,
        FunctionAccessRequirement requirement)
    {
        if (!context.User.TryGetUserId(out var userId) || requirement.FunctionCodes.Count == 0)
        {
            return;
        }

        var cancellationToken = httpContextAccessor.HttpContext?.RequestAborted ?? CancellationToken.None;
        if (requirement.AllowSuperAdminBypass &&
            systemRoleEvaluator is not null &&
            await systemRoleEvaluator.IsSuperAdminAsync(userId, cancellationToken))
        {
            context.Succeed(requirement);
            return;
        }

        var activeKeys = await (
            from user in dbContext.Users.AsNoTracking()
            join userRole in dbContext.UserRoles.AsNoTracking() on user.UserId equals userRole.UserId
            join role in dbContext.Roles.AsNoTracking() on userRole.RoleId equals role.RoleId
            join functionRole in dbContext.FunctionRoles.AsNoTracking()
                on role.RoleId equals functionRole.TargetId
            join function in dbContext.Functions.AsNoTracking()
                on functionRole.FunctionId equals function.FunctionId
            where user.UserId == userId &&
                  user.Status == WebDataStatus.Active &&
                  userRole.Status == WebDataStatus.Active &&
                  role.Status == WebDataStatus.Active &&
                  functionRole.Type == WebFunctionRoleType.Role &&
                  functionRole.Status == WebDataStatus.Active &&
                  function.Status == WebDataStatus.Active &&
                  requirement.FunctionCodes.Contains(function.Code)
            select functionRole.ActiveKey)
            .ToListAsync(cancellationToken);

        if (activeKeys.Any(key => ActiveKeyValue.Allows(key, requirement.Permission)))
        {
            context.Succeed(requirement);
        }
    }
}
