using System.Data;
using System.ComponentModel.DataAnnotations;
using Microsoft.EntityFrameworkCore;
using TTSmart.Api.Common.Exceptions;
using TTSmart.Api.Common.Models;
using TTSmart.Api.Common.Time;
using TTSmart.Api.Data.Company;
using TTSmart.Api.Data.WebAuth;
using TTSmart.Api.Features.Authorization;

namespace TTSmart.Api.Features.CompanyManagement;

public sealed class CompanyManagementService(
    CompanyDbContext companyDbContext,
    WebAuthDbContext authDbContext,
    ICompanyLogoStorage logoStorage,
    ISystemRoleEvaluator systemRoleEvaluator) : ICompanyManagementService
{
    private const string CaseSensitiveCollation = "SQL_Latin1_General_CP1_CS_AS";

    public async Task<PagedResponse<CompanyResponse>> GetPageAsync(
        CompanyListQuery query,
        int currentUserId,
        CancellationToken cancellationToken)
    {
        var scope = await GetScopeAsync(currentUserId, cancellationToken);
        var status = ResolveStatus(query.Status);
        var companiesQuery = ApplyScope(
            companyDbContext.Companies.AsNoTracking().Where(company => company.Status == status),
            scope);
        var search = TrimOrNull(query.Search);
        if (search is not null)
        {
            companiesQuery = companiesQuery.Where(company =>
                (company.Code != null && company.Code.Contains(search)) ||
                (company.Name != null && company.Name.Contains(search)) ||
                (company.Email != null && company.Email.Contains(search)) ||
                (company.Phone != null && company.Phone.Contains(search)) ||
                (company.ContactName != null && company.ContactName.Contains(search)));
        }

        if (query.IsLocked.HasValue)
        {
            companiesQuery = companiesQuery.Where(company => company.IsLocked == query.IsLocked.Value);
        }

        var totalCount = await companiesQuery.CountAsync(cancellationToken);
        var companies = await companiesQuery
            .OrderBy(company => company.Name)
            .ThenBy(company => company.CompanyId)
            .Skip((query.PageNumber - 1) * query.PageSize)
            .Take(query.PageSize)
            .ToListAsync(cancellationToken);
        var totalPages = totalCount == 0 ? 0 : (int)Math.Ceiling(totalCount / (double)query.PageSize);
        return new PagedResponse<CompanyResponse>(
            companies.Select(BuildResponse).ToList(),
            query.PageNumber,
            query.PageSize,
            totalCount,
            totalPages);
    }

    public async Task<CompanyResponse> GetByIdAsync(
        int id,
        int currentUserId,
        CancellationToken cancellationToken)
    {
        var scope = await GetScopeAsync(currentUserId, cancellationToken);
        var company = await ApplyScope(companyDbContext.Companies.AsNoTracking(), scope)
            .SingleOrDefaultAsync(item => item.CompanyId == id, cancellationToken)
            ?? throw new NotFoundException("Không tìm thấy công ty.");
        return BuildResponse(company);
    }

    public async Task<CompanyResponse> CreateAsync(
        CreateCompanyRequest request,
        int currentUserId,
        CancellationToken cancellationToken)
    {
        var scope = await GetScopeAsync(currentUserId, cancellationToken);
        EnsureSuperAdmin(scope, "Chỉ ADMIN mới được tạo công ty.");
        var requestedCode = RequireValue(request.Code, "Mã công ty là bắt buộc.");

        return await ExecuteInSerializableTransactionAsync(
            async () =>
            {
                await EnsureCompanyCodeAvailableAsync(requestedCode, null, cancellationToken);
                var now = VietnamTime.Now;
                var company = new WebCompany
                {
                    Status = WebDataStatus.Active,
                    IsLocked = false,
                    CreatedAt = now,
                    UpdatedAt = now,
                    UserId = currentUserId,
                    CountUser = request.CountUser,
                    Active = request.Active
                };
                ApplyFields(company, request);
                companyDbContext.Companies.Add(company);
                await companyDbContext.SaveChangesAsync(cancellationToken);
                return BuildResponse(company);
            },
            cancellationToken);
    }

    public async Task<CompanyResponse> UpdateAsync(
        int id,
        UpdateCompanyRequest request,
        int currentUserId,
        CancellationToken cancellationToken)
    {
        var scope = await GetScopeAsync(currentUserId, cancellationToken);
        var requestedCode = RequireValue(request.Code, "Mã công ty là bắt buộc.");
        return await ExecuteInSerializableTransactionAsync(
            async () =>
            {
                var company = await GetTrackedCompanyAsync(id, scope, cancellationToken);
                var currentCode = company.Code?.Trim();
                if (!string.Equals(currentCode, requestedCode, StringComparison.Ordinal))
                {
                    await EnsureCompanyCodeAvailableAsync(requestedCode, id, cancellationToken);
                }

                ApplyFields(company, request);
                company.UpdatedAt = VietnamTime.Now;
                await companyDbContext.SaveChangesAsync(cancellationToken);
                return BuildResponse(company);
            },
            cancellationToken);
    }

    public async Task<CompanyResponse> SetLockAsync(
        int id,
        SetCompanyLockRequest request,
        int currentUserId,
        CancellationToken cancellationToken)
    {
        var scope = await GetScopeAsync(currentUserId, cancellationToken);
        var company = await GetTrackedCompanyAsync(id, scope, cancellationToken);
        company.IsLocked = request.IsLocked
            ?? throw new ValidationException("IsLocked là bắt buộc.");
        company.UpdatedAt = VietnamTime.Now;
        await companyDbContext.SaveChangesAsync(cancellationToken);
        return BuildResponse(company);
    }

    public async Task<CompanyResponse> SetExpirationAsync(
        int id,
        SetCompanyExpirationRequest request,
        int currentUserId,
        CancellationToken cancellationToken)
    {
        var scope = await GetScopeAsync(currentUserId, cancellationToken);
        var company = await GetTrackedCompanyAsync(id, scope, cancellationToken);
        company.ExpiredDate = VietnamTime.ToStorage(request.ExpiredDate);
        company.UpdatedAt = VietnamTime.Now;
        await companyDbContext.SaveChangesAsync(cancellationToken);
        return BuildResponse(company);
    }

    public async Task<CompanyResponse> UploadLogoAsync(
        int id,
        UploadCompanyLogoRequest request,
        int currentUserId,
        CancellationToken cancellationToken)
    {
        var scope = await GetScopeAsync(currentUserId, cancellationToken);
        var company = await GetTrackedCompanyAsync(id, scope, cancellationToken);
        var storedFile = await logoStorage.SaveAsync(
            request.File ?? throw new ValidationException("File logo là bắt buộc."),
            cancellationToken);
        var previousFile = company.Logo;
        try
        {
            company.Logo = storedFile.FileName;
            company.UpdatedAt = VietnamTime.Now;
            await companyDbContext.SaveChangesAsync(cancellationToken);
        }
        catch
        {
            await logoStorage.DeleteAsync(storedFile.FileName);
            throw;
        }

        await logoStorage.DeleteAsync(previousFile);
        return BuildResponse(company);
    }

    public async Task<CompanyLogoReadResult> GetLogoAsync(
        int id,
        int currentUserId,
        CancellationToken cancellationToken)
    {
        var scope = await GetScopeAsync(currentUserId, cancellationToken);
        var company = await ApplyScope(companyDbContext.Companies.AsNoTracking(), scope)
            .SingleOrDefaultAsync(item => item.CompanyId == id, cancellationToken)
            ?? throw new NotFoundException("Không tìm thấy công ty.");
        return await logoStorage.OpenReadAsync(company.Logo)
            ?? throw new NotFoundException("Không tìm thấy file logo của công ty.");
    }

    public async Task<CompanyResponse> DeleteAsync(
        int id,
        int currentUserId,
        CancellationToken cancellationToken)
    {
        var scope = await GetScopeAsync(currentUserId, cancellationToken);
        var company = await GetTrackedCompanyAsync(id, scope, cancellationToken);
        company.Status = WebDataStatus.Inactive;
        company.UpdatedAt = VietnamTime.Now;
        await companyDbContext.SaveChangesAsync(cancellationToken);
        return BuildResponse(company);
    }

    public async Task<CompanyResponse> RestoreAsync(
        int id,
        int currentUserId,
        CancellationToken cancellationToken)
    {
        var scope = await GetScopeAsync(currentUserId, cancellationToken);
        var company = await GetTrackedCompanyAsync(id, scope, cancellationToken);
        company.Status = WebDataStatus.Active;
        company.UpdatedAt = VietnamTime.Now;
        await companyDbContext.SaveChangesAsync(cancellationToken);
        return BuildResponse(company);
    }

    private async Task<CompanyUserScope> GetScopeAsync(
        int currentUserId,
        CancellationToken cancellationToken)
    {
        var user = await authDbContext.Users.AsNoTracking()
            .SingleOrDefaultAsync(
                item => item.UserId == currentUserId && item.Status == WebDataStatus.Active,
                cancellationToken)
            ?? throw new UnauthorizedException("Phiên đăng nhập không còn hợp lệ.");
        var isSuperAdmin = await systemRoleEvaluator.IsSuperAdminAsync(currentUserId, cancellationToken);
        return new CompanyUserScope(isSuperAdmin, user.CompanyId);
    }

    private static IQueryable<WebCompany> ApplyScope(
        IQueryable<WebCompany> companies,
        CompanyUserScope scope)
    {
        if (scope.IsSuperAdmin)
        {
            return companies;
        }

        return scope.CompanyId.HasValue
            ? companies.Where(company => company.CompanyId == scope.CompanyId.Value)
            : companies.Where(_ => false);
    }

    private async Task<WebCompany> GetTrackedCompanyAsync(
        int id,
        CompanyUserScope scope,
        CancellationToken cancellationToken) =>
        await ApplyScope(companyDbContext.Companies, scope)
            .SingleOrDefaultAsync(item => item.CompanyId == id, cancellationToken)
        ?? throw new NotFoundException("Không tìm thấy công ty.");

    private static void EnsureSuperAdmin(CompanyUserScope scope, string message)
    {
        if (!scope.IsSuperAdmin)
        {
            throw new ForbiddenException(message);
        }
    }

    private static byte ResolveStatus(byte? status)
    {
        if (!status.HasValue)
        {
            return WebDataStatus.Active;
        }

        if (status.Value is not WebDataStatus.Active and not WebDataStatus.Inactive)
        {
            throw new ValidationException("Status chỉ nhận giá trị 1 hoặc 99.");
        }

        return status.Value;
    }

    private async Task EnsureCompanyCodeAvailableAsync(
        string code,
        int? excludingCompanyId,
        CancellationToken cancellationToken)
    {
        var normalizedCode = code.Trim();
        var candidates = companyDbContext.Companies.AsNoTracking().Where(
            company =>
                company.Status == WebDataStatus.Active &&
                (!excludingCompanyId.HasValue || company.CompanyId != excludingCompanyId.Value) &&
                company.Code != null);
        var exists = companyDbContext.Database.IsRelational()
            ? await candidates.AnyAsync(
                company => EF.Functions.Collate(company.Code!.Trim(), CaseSensitiveCollation) == normalizedCode,
                cancellationToken)
            : (await candidates.Select(company => company.Code).ToListAsync(cancellationToken))
                .Any(existingCode => string.Equals(existingCode?.Trim(), normalizedCode, StringComparison.Ordinal));
        if (exists)
        {
            throw new ConflictException("Mã công ty đã tồn tại.");
        }
    }

    private async Task<TResult> ExecuteInSerializableTransactionAsync<TResult>(
        Func<Task<TResult>> operation,
        CancellationToken cancellationToken)
    {
        if (!companyDbContext.Database.IsRelational() ||
            companyDbContext.Database.CurrentTransaction is not null)
        {
            return await operation();
        }

        await using var transaction = await companyDbContext.Database.BeginTransactionAsync(
            IsolationLevel.Serializable,
            cancellationToken);
        try
        {
            var result = await operation();
            await transaction.CommitAsync(cancellationToken);
            return result;
        }
        catch
        {
            await transaction.RollbackAsync(cancellationToken);
            throw;
        }
    }

    private static void ApplyFields(WebCompany company, CompanyFieldsRequest request)
    {
        company.Code = RequireValue(request.Code, "Mã công ty là bắt buộc.");
        company.Name = RequireValue(request.Name, "Tên công ty là bắt buộc.");
        company.Email = RequireValue(request.Email, "Email công ty là bắt buộc.");
        company.Phone = RequireValue(request.Phone, "Số điện thoại công ty là bắt buộc.");
        company.Address = TrimOrNull(request.Address);
        company.Fax = TrimOrNull(request.Fax);
        company.Representative = TrimOrNull(request.Representative);
        company.ContactName = TrimOrNull(request.ContactName);
        company.ContactEmail = TrimOrNull(request.ContactEmail);
        company.ContactPhone = TrimOrNull(request.ContactPhone);
        company.CountUser = request.CountUser;
        company.Active = request.Active;
        company.Note = TrimOrNull(request.Note);
    }

    private static CompanyResponse BuildResponse(WebCompany company) =>
        new(
            company.CompanyId,
            company.Code,
            company.Name,
            company.Email,
            company.Phone,
            company.Address,
            company.Fax,
            company.Representative,
            company.ContactName,
            company.ContactEmail,
            company.ContactPhone,
            VietnamTime.ToUtc(company.CreatedAt),
            VietnamTime.ToUtc(company.UpdatedAt),
            company.UserId,
            company.Status ?? WebDataStatus.Active,
            company.Status == WebDataStatus.Active,
            company.CountUser,
            company.Active,
            company.IsLocked,
            company.Note,
            company.Logo,
            VietnamTime.ToBusinessDate(company.ExpiredDate));

    private static string? TrimOrNull(string? value)
    {
        var trimmed = value?.Trim();
        return string.IsNullOrWhiteSpace(trimmed) ? null : trimmed;
    }

    private static string RequireValue(string value, string errorMessage)
    {
        var trimmed = value.Trim();
        return trimmed.Length > 0 ? trimmed : throw new ValidationException(errorMessage);
    }

    private sealed record CompanyUserScope(bool IsSuperAdmin, int? CompanyId);
}
