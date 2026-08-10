using Microsoft.EntityFrameworkCore;
using TTSmart.Api.Common.Time;
using TTSmart.Api.Data.Company;
using TTSmart.Api.Features.Authorization;
using TTSmart.Api.Data.WebAuth;

namespace TTSmart.Api.Features.CompanyManagement;

public sealed record CompanyAccessDecision(bool IsAllowed, string? ErrorCode, string? Message)
{
    public static CompanyAccessDecision Allowed() => new(true, null, null);
}

public static class CompanyAccessErrors
{
    public const string Inactive = "company_inactive";
    public const string Locked = "company_locked";
    public const string Expired = "company_expired";

    public const string InactiveMessage = "Công ty không còn hoạt động. Vui lòng liên hệ TTSmart.";
    public const string LockedMessage = "Công ty đã tạm ngưng dịch vụ. Vui lòng liên hệ TTSmart.";
    public const string ExpiredMessage = "Công ty đã hết hạn dịch vụ. Vui lòng liên hệ TTSmart.";
}

public interface ICompanyAccessEvaluator
{
    Task<CompanyAccessDecision> EvaluateAsync(WebUser user, CancellationToken cancellationToken);
}

public sealed class CompanyAccessEvaluator(
    CompanyDbContext companyDbContext,
    ISystemRoleEvaluator systemRoleEvaluator,
    Microsoft.Extensions.Options.IOptions<CompanyAccessOptions>? companyAccessOptions = null,
    Microsoft.Extensions.Options.IOptions<CompanyDatabaseOptions>? companyDatabaseOptions = null) : ICompanyAccessEvaluator
{
    public async Task<CompanyAccessDecision> EvaluateAsync(
        WebUser user,
        CancellationToken cancellationToken)
    {
        if (await systemRoleEvaluator.IsSuperAdminAsync(user.UserId, cancellationToken) || !user.CompanyId.HasValue)
        {
            return CompanyAccessDecision.Allowed();
        }

        var company = await companyDbContext.Companies.AsNoTracking()
            .SingleOrDefaultAsync(item => item.CompanyId == user.CompanyId.Value, cancellationToken);
        if (company is null || company.Status != WebDataStatus.Active)
        {
            return new CompanyAccessDecision(false, CompanyAccessErrors.Inactive, CompanyAccessErrors.InactiveMessage);
        }

        if ((companyDatabaseOptions?.Value.IsLockedColumnAvailable ?? false) && company.IsLocked)
        {
            return new CompanyAccessDecision(false, CompanyAccessErrors.Locked, CompanyAccessErrors.LockedMessage);
        }

        if ((companyAccessOptions?.Value.EnforceExpiration ?? false) &&
            company.ExpiredDate.HasValue &&
            VietnamTime.Now > company.ExpiredDate.Value)
        {
            return new CompanyAccessDecision(false, CompanyAccessErrors.Expired, CompanyAccessErrors.ExpiredMessage);
        }

        return CompanyAccessDecision.Allowed();
    }
}
