using System.ComponentModel.DataAnnotations;
using Microsoft.EntityFrameworkCore;
using TTSmart.Api.Common.Exceptions;
using TTSmart.Api.Data.Company;
using TTSmart.Api.Data.WebAuth;
using TTSmart.Api.Features.Authorization;

namespace TTSmart.Api.Features.BranchManagement;

public sealed record BranchAccessScope(
    bool IsSuperAdmin,
    bool IsCompany,
    int? CompanyId,
    int[] BranchIds)
{
    public IQueryable<WebBranch> ApplyTo(IQueryable<WebBranch> branches)
    {
        if (IsSuperAdmin)
        {
            return branches;
        }

        if (IsCompany)
        {
            return CompanyId.HasValue
                ? branches.Where(branch => branch.CompanyId == CompanyId.Value)
                : branches.Where(_ => false);
        }

        return !CompanyId.HasValue || BranchIds.Length == 0
            ? branches.Where(_ => false)
            : branches.Where(branch =>
                branch.CompanyId == CompanyId.Value &&
                branch.BranchId > 0 &&
                BranchIds.Contains(branch.BranchId));
    }

    public void EnsureCompanyFilterAllowed(int? companyId)
    {
        if (!companyId.HasValue || IsSuperAdmin)
        {
            return;
        }

        if (!IsCompany || CompanyId != companyId.Value)
        {
            throw new ForbiddenException("Không được lọc trạm ngoài phạm vi được cấp.");
        }
    }
}

public sealed record AuthorizedBranch(
    int Id,
    int? CompanyId,
    string? CompanyName,
    string? Name,
    int? TypeTram,
    string? DatabaseName);

public interface IBranchAccessResolver
{
    Task<BranchAccessScope> GetScopeAsync(int currentUserId, CancellationToken cancellationToken);

    Task<IReadOnlyList<AuthorizedBranch>> GetOrderStatisticsBranchesAsync(
        int currentUserId,
        int? companyId,
        CancellationToken cancellationToken);

    Task<AuthorizedBranch> GetRequiredOrderStatisticsBranchAsync(
        int currentUserId,
        int? companyId,
        int? branchId,
        CancellationToken cancellationToken);

    Task<IReadOnlyList<AuthorizedBranch>> GetMixDesignBranchesAsync(
        int currentUserId,
        int? companyId,
        CancellationToken cancellationToken);

    Task<AuthorizedBranch> GetRequiredMixDesignBranchAsync(
        int currentUserId,
        int? companyId,
        int? branchId,
        CancellationToken cancellationToken);

    Task<IReadOnlyList<AuthorizedBranch>> GetWeighStationBranchesAsync(
        int currentUserId,
        int? companyId,
        CancellationToken cancellationToken);

    Task<AuthorizedBranch> GetRequiredWeighStationBranchAsync(
        int currentUserId,
        int? companyId,
        int? branchId,
        CancellationToken cancellationToken);

    Task<IReadOnlyList<AuthorizedBranch>> GetOrderReportBranchesAsync(
        int currentUserId,
        int? companyId,
        CancellationToken cancellationToken);

    Task<IReadOnlyList<AuthorizedBranch>> GetRequiredOrderReportBranchesAsync(
        int currentUserId,
        int? companyId,
        int? branchId,
        CancellationToken cancellationToken);
}

public sealed class BranchAccessResolver(
    CompanyDbContext companyDbContext,
    WebAuthDbContext authDbContext,
    ISystemRoleEvaluator systemRoleEvaluator) : IBranchAccessResolver
{
    private const int MixingStationType = 1;
    private const int WeighStationType = 2;

    public async Task<BranchAccessScope> GetScopeAsync(int currentUserId, CancellationToken cancellationToken)
    {
        var user = await authDbContext.Users.AsNoTracking()
            .SingleOrDefaultAsync(item => item.UserId == currentUserId, cancellationToken);
        if (user is null || user.Status != WebDataStatus.Active)
        {
            throw new UnauthorizedException("Phiên đăng nhập không còn hợp lệ.");
        }

        return await BuildScopeAsync(user, cancellationToken);
    }

    public async Task<IReadOnlyList<AuthorizedBranch>> GetOrderReportBranchesAsync(
        int currentUserId,
        int? companyId,
        CancellationToken cancellationToken)
    {
        var scope = await GetScopeAsync(currentUserId, cancellationToken);
        scope.EnsureCompanyFilterAllowed(companyId);
        var branches = await ApplyAuthorizedOrderReportScope(scope, companyId)
            .ToListAsync(cancellationToken);

        return branches
            .OrderBy(branch => branch.Name)
            .ThenBy(branch => branch.Id)
            .ToArray();
    }

    public async Task<AuthorizedBranch> GetRequiredOrderStatisticsBranchAsync(
        int currentUserId,
        int? companyId,
        int? branchId,
        CancellationToken cancellationToken)
    {
        var scope = await GetScopeAsync(currentUserId, cancellationToken);
        if (scope.IsSuperAdmin && !companyId.HasValue)
        {
            throw new ValidationException("Chưa chọn công ty.");
        }
        if (!branchId.HasValue)
        {
            throw new ValidationException("Chưa chọn trạm.");
        }
        scope.EnsureCompanyFilterAllowed(companyId);
        var branch = await ApplyAuthorizedOrderReportScope(scope, companyId, branchId.Value)
            .SingleOrDefaultAsync(cancellationToken);
        if (branch is null)
        {
            throw new NotFoundException("Không tìm thấy trạm.");
        }

        return branch;
    }

    public async Task<IReadOnlyList<AuthorizedBranch>> GetOrderStatisticsBranchesAsync(
        int currentUserId,
        int? companyId,
        CancellationToken cancellationToken)
    {
        var scope = await GetScopeAsync(currentUserId, cancellationToken);
        if (scope.IsSuperAdmin && !companyId.HasValue)
        {
            throw new ValidationException("Chưa chọn công ty.");
        }

        scope.EnsureCompanyFilterAllowed(companyId);
        var branches = await ApplyAuthorizedOrderReportScope(scope, companyId)
            .ToListAsync(cancellationToken);

        return branches
            .OrderBy(branch => branch.Name)
            .ThenBy(branch => branch.Id)
            .ToArray();
    }

    public async Task<IReadOnlyList<AuthorizedBranch>> GetMixDesignBranchesAsync(
        int currentUserId,
        int? companyId,
        CancellationToken cancellationToken)
    {
        var scope = await GetScopeAsync(currentUserId, cancellationToken);
        if (scope.IsSuperAdmin && !companyId.HasValue)
        {
            throw new ValidationException("Vui lòng chọn công ty");
        }

        scope.EnsureCompanyFilterAllowed(companyId);
        return await ApplyAuthorizedOrderReportScope(scope, companyId)
            .ToListAsync(cancellationToken);
    }

    public async Task<AuthorizedBranch> GetRequiredMixDesignBranchAsync(
        int currentUserId,
        int? companyId,
        int? branchId,
        CancellationToken cancellationToken)
    {
        var scope = await GetScopeAsync(currentUserId, cancellationToken);
        if (scope.IsSuperAdmin && !companyId.HasValue)
        {
            throw new ValidationException("Vui lòng chọn công ty");
        }
        if (!branchId.HasValue)
        {
            throw new ValidationException("Vui lòng chọn trạm");
        }

        scope.EnsureCompanyFilterAllowed(companyId);
        var branch = await ApplyAuthorizedOrderReportScope(scope, companyId, branchId.Value)
            .SingleOrDefaultAsync(cancellationToken);
        return branch ?? throw new ForbiddenException("Không được truy cập trạm đã chọn.");
    }

    public async Task<IReadOnlyList<AuthorizedBranch>> GetWeighStationBranchesAsync(
        int currentUserId,
        int? companyId,
        CancellationToken cancellationToken)
    {
        var scope = await GetScopeAsync(currentUserId, cancellationToken);
        if (scope.IsSuperAdmin && !companyId.HasValue)
        {
            throw new ValidationException("Vui lòng chọn công ty");
        }

        scope.EnsureCompanyFilterAllowed(companyId);
        var branches = await ApplyAuthorizedWeighStationScope(scope, companyId)
            .ToListAsync(cancellationToken);

        return branches
            .OrderBy(branch => branch.Name)
            .ThenBy(branch => branch.Id)
            .ToArray();
    }

    public async Task<AuthorizedBranch> GetRequiredWeighStationBranchAsync(
        int currentUserId,
        int? companyId,
        int? branchId,
        CancellationToken cancellationToken)
    {
        var scope = await GetScopeAsync(currentUserId, cancellationToken);
        if (scope.IsSuperAdmin && !companyId.HasValue)
        {
            throw new ValidationException("Vui lòng chọn công ty");
        }
        if (!branchId.HasValue)
        {
            throw new ValidationException("Vui lòng chọn trạm cân");
        }

        scope.EnsureCompanyFilterAllowed(companyId);
        var branch = await ApplyAuthorizedWeighStationScope(scope, companyId, branchId.Value)
            .SingleOrDefaultAsync(cancellationToken);
        return branch ?? throw new ForbiddenException("Không được truy cập trạm cân đã chọn.");
    }

    public async Task<IReadOnlyList<AuthorizedBranch>> GetRequiredOrderReportBranchesAsync(
        int currentUserId,
        int? companyId,
        int? branchId,
        CancellationToken cancellationToken)
    {
        var scope = await GetScopeAsync(currentUserId, cancellationToken);
        scope.EnsureCompanyFilterAllowed(companyId);
        if (!branchId.HasValue && !scope.IsSuperAdmin)
        {
            throw new ValidationException("Trạm là bắt buộc với tài khoản không phải ADMIN.");
        }

        var branches = (await ApplyAuthorizedOrderReportScope(scope, companyId)
                .ToListAsync(cancellationToken))
            .Where(branch => !branchId.HasValue || branch.Id == branchId.Value)
            .OrderBy(branch => branch.Name)
            .ThenBy(branch => branch.Id)
            .ToArray();
        if (branchId.HasValue && branches.Length == 0)
        {
            throw new NotFoundException("Không tìm thấy trạm.");
        }

        return branches;
    }

    private IQueryable<AuthorizedBranch> ApplyAuthorizedOrderReportScope(
        BranchAccessScope scope,
        int? companyId,
        int? branchId = null)
    {
        var branchQuery = scope.ApplyTo(companyDbContext.Branches.AsNoTracking())
            .Where(branch =>
                branch.Status == WebDataStatus.Active &&
                branch.TypeTram == MixingStationType);

        if (companyId.HasValue)
        {
            branchQuery = branchQuery.Where(branch => branch.CompanyId == companyId.Value);
        }

        if (branchId.HasValue)
        {
            branchQuery = branchQuery.Where(branch => branch.BranchId == branchId.Value);
        }

        return from branch in branchQuery
               join company in companyDbContext.Companies.AsNoTracking()
                   on branch.CompanyId equals (int?)company.CompanyId into companyGroup
               from company in companyGroup.DefaultIfEmpty()
               select new AuthorizedBranch(
                   branch.BranchId,
                   branch.CompanyId,
                   company == null ? null : company.Name,
                   branch.Name,
                   branch.TypeTram,
                   branch.Dataname);
    }

    private IQueryable<AuthorizedBranch> ApplyAuthorizedWeighStationScope(
        BranchAccessScope scope,
        int? companyId,
        int? branchId = null)
    {
        var branchQuery = scope.ApplyTo(companyDbContext.Branches.AsNoTracking())
            .Where(branch =>
                branch.Status == WebDataStatus.Active &&
                branch.TypeTram == WeighStationType);

        if (companyId.HasValue)
        {
            branchQuery = branchQuery.Where(branch => branch.CompanyId == companyId.Value);
        }
        if (branchId.HasValue)
        {
            branchQuery = branchQuery.Where(branch => branch.BranchId == branchId.Value);
        }

        return from branch in branchQuery
               join company in companyDbContext.Companies.AsNoTracking()
                   on branch.CompanyId equals (int?)company.CompanyId into companyGroup
               from company in companyGroup.DefaultIfEmpty()
               select new AuthorizedBranch(
                   branch.BranchId,
                   branch.CompanyId,
                   company == null ? null : company.Name,
                   branch.Name,
                   branch.TypeTram,
                   branch.Dataname);
    }

    private async Task<BranchAccessScope> BuildScopeAsync(
        WebUser user,
        CancellationToken cancellationToken)
    {
        var roleCodes = await BuildRoleCodeQuery(user.UserId).ToListAsync(cancellationToken);
        var isSuperAdmin = await systemRoleEvaluator.IsSuperAdminAsync(user.UserId, cancellationToken);
        return new BranchAccessScope(
            isSuperAdmin,
            !isSuperAdmin && roleCodes.Contains(SystemRoleCodes.Company, StringComparer.Ordinal),
            user.CompanyId,
            ParseBranchIds(user.BranchId));
    }

    private IQueryable<string> BuildRoleCodeQuery(int userId) =>
        from userRole in authDbContext.UserRoles.AsNoTracking()
        join role in authDbContext.Roles.AsNoTracking() on userRole.RoleId equals role.RoleId
        where userRole.UserId == userId &&
              userRole.Status == WebDataStatus.Active &&
              role.Status == WebDataStatus.Active
        select role.Code;

    private static int[] ParseBranchIds(string? value) =>
        (value ?? string.Empty)
            .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Select(token => int.TryParse(token, out var id) ? id : 0)
            .Where(id => id > 0)
            .Distinct()
            .ToArray();
}

