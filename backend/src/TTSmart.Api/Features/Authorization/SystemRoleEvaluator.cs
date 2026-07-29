using Microsoft.EntityFrameworkCore;
using TTSmart.Api.Data.WebAuth;

namespace TTSmart.Api.Features.Authorization;

public interface ISystemRoleEvaluator
{
    Task<bool> IsSuperAdminAsync(int userId, CancellationToken cancellationToken);
}

public sealed class SystemRoleEvaluator(WebAuthDbContext dbContext) : ISystemRoleEvaluator
{
    public Task<bool> IsSuperAdminAsync(int userId, CancellationToken cancellationToken) =>
        (
            from userRole in dbContext.UserRoles.AsNoTracking()
            join role in dbContext.Roles.AsNoTracking() on userRole.RoleId equals role.RoleId
            where userRole.UserId == userId &&
                  userRole.Status == WebDataStatus.Active &&
                  role.Status == WebDataStatus.Active &&
                  role.Code == SystemRoleCodes.Admin
            select role.RoleId)
        .AnyAsync(cancellationToken);
}
