using Microsoft.EntityFrameworkCore;
using TTSmart.Api.Data.WebAuth;

namespace TTSmart.Api.Features.Authorization;

public interface ISystemRoleEvaluator
{
    Task<bool> IsSuperAdminAsync(int userId, CancellationToken cancellationToken);
}

public sealed class SystemRoleEvaluator(
    WebAuthDbContext dbContext,
    ISystemRoleCatalog? systemRoleCatalog = null) : ISystemRoleEvaluator
{
    private readonly ISystemRoleCatalog _systemRoleCatalog = systemRoleCatalog ?? SystemRoleCatalog.Default;

    public Task<bool> IsSuperAdminAsync(int userId, CancellationToken cancellationToken)
    {
        var adminRoleIds = _systemRoleCatalog.AdminRoleIds;
        var adminRoleCodes = _systemRoleCatalog.AdminRoleCodes;
        return (
            from userRole in dbContext.UserRoles.AsNoTracking()
            join role in dbContext.Roles.AsNoTracking() on userRole.RoleId equals role.RoleId
            where userRole.UserId == userId &&
                  userRole.Status == WebDataStatus.Active &&
                  role.Status == WebDataStatus.Active &&
                  (adminRoleIds.Contains(role.RoleId) || adminRoleCodes.Contains(role.Code))
            select role.RoleId)
        .AnyAsync(cancellationToken);
    }
}
