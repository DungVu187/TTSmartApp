using System.ComponentModel.DataAnnotations;
using System.Data;
using Microsoft.EntityFrameworkCore;
using TTSmart.Api.Common.Exceptions;
using TTSmart.Api.Common.Models;
using TTSmart.Api.Common.Security;
using TTSmart.Api.Common.Time;
using TTSmart.Api.Data.Company;
using TTSmart.Api.Data.WebAuth;
using TTSmart.Api.Features.Authorization;

namespace TTSmart.Api.Features.BranchManagement;

public sealed class BranchManagementService(
    CompanyDbContext companyDbContext,
    WebAuthDbContext authDbContext,
    ISystemRoleEvaluator systemRoleEvaluator) : IBranchManagementService
{
    private const string CaseSensitiveCollation = "SQL_Latin1_General_CP1_CS_AS";
    private const string CaseInsensitiveCollation = "SQL_Latin1_General_CP1_CI_AS";
    private const string PasswordMask = "••••••••";

    public async Task<PagedResponse<BranchListItemResponse>> GetPageAsync(
        BranchListQuery query,
        int currentUserId,
        CancellationToken cancellationToken)
    {
        var scope = await GetScopeAsync(currentUserId, cancellationToken);
        var status = ResolveStatus(query.Status);
        if (status == WebDataStatus.Inactive && !scope.IsSuperAdmin)
        {
            throw new ForbiddenException("Chỉ ADMIN được xem trạm đã xóa mềm.");
        }

        EnsureCompanyFilterAllowed(query.CompanyId, scope);
        var typeTram = ResolveTypeTram(query.TypeTram);
        var branchesQuery = ApplyScope(companyDbContext.Branches.AsNoTracking(), scope)
            .Where(branch => branch.Status == status);

        if (query.CompanyId.HasValue)
        {
            branchesQuery = branchesQuery.Where(branch => branch.CompanyId == query.CompanyId.Value);
        }

        if (typeTram.HasValue)
        {
            branchesQuery = branchesQuery.Where(branch => branch.TypeTram == typeTram.Value);
        }

        var search = TrimOrNull(query.Search);
        if (search is not null)
        {
            branchesQuery = branchesQuery.Where(branch =>
                (branch.Code != null && branch.Code.Contains(search)) ||
                (branch.Name != null && branch.Name.Contains(search)));
        }

        var totalCount = await branchesQuery.CountAsync(cancellationToken);
        var items = await branchesQuery
            .OrderBy(branch => branch.Name)
            .ThenBy(branch => branch.BranchId)
            .Skip((query.PageNumber - 1) * query.PageSize)
            .Take(query.PageSize)
            .Select(branch => new BranchListItemResponse(
                branch.BranchId,
                branch.Name,
                branch.Phone,
                branch.TypeTram))
            .ToListAsync(cancellationToken);

        var totalPages = totalCount == 0
            ? 0
            : (int)Math.Ceiling(totalCount / (double)query.PageSize);
        return new PagedResponse<BranchListItemResponse>(
            items,
            query.PageNumber,
            query.PageSize,
            totalCount,
            totalPages);
    }

    public async Task<BranchResponse> GetByIdAsync(
        int id,
        int currentUserId,
        CancellationToken cancellationToken)
    {
        var scope = await GetScopeAsync(currentUserId, cancellationToken);
        var branchesQuery = ApplyScope(companyDbContext.Branches.AsNoTracking(), scope);
        if (!scope.IsSuperAdmin)
        {
            branchesQuery = branchesQuery.Where(branch => branch.Status == WebDataStatus.Active);
        }

        var branch = await branchesQuery.SingleOrDefaultAsync(
            item => item.BranchId == id,
            cancellationToken)
            ?? throw new NotFoundException("Không tìm thấy trạm.");
        return await BuildResponseAsync(branch, cancellationToken);
    }

    public async Task<BranchResponse> CreateAsync(
        CreateBranchRequest request,
        int currentUserId,
        CancellationToken cancellationToken)
    {
        var scope = await GetScopeAsync(currentUserId, cancellationToken);
        EnsureSuperAdmin(scope, "Chỉ ADMIN mới được tạo trạm.");

        var companyId = request.CompanyId
            ?? throw new ValidationException("Công ty là bắt buộc.");
        var code = RequireValue(request.Code, "Mã trạm là bắt buộc.");
        var name = RequireValue(request.Name, "Tên trạm là bắt buộc.");
        var email = RequireValue(request.Email, "Email là bắt buộc.");
        var phone = RequireValue(request.Phone, "Số điện thoại là bắt buộc.");
        var username = RequireValue(request.Username, "Tài khoản là bắt buộc.");
        var password = RequireValue(request.Password, "Mật khẩu là bắt buộc.");
        ValidatePassword(password);
        var typeTram = RequireTypeTram(request.TypeTram);

        var branchId = await ExecuteInSerializableTransactionAsync(
            async () =>
            {
                await EnsureActiveCompanyAsync(companyId, cancellationToken);
                await EnsureCodeAvailableAsync(code, null, cancellationToken);
                await EnsureUsernameAvailableAsync(username, null, cancellationToken);

                var now = VietnamTime.Now;
                var branch = new WebBranch
                {
                    CompanyId = companyId,
                    Code = code,
                    Name = name,
                    Email = email,
                    Phone = phone,
                    Address = TrimOrNull(request.Address),
                    Username = username,
                    Password = password,
                    PMQLXe = TrimOrNull(request.PMQLXe),
                    QLCamera = TrimOrNull(request.QLCamera),
                    TypeTram = typeTram,
                    Status = WebDataStatus.Active,
                    CreatedAt = now,
                    UpdatedAt = now,
                    UserId = currentUserId
                };
                companyDbContext.Branches.Add(branch);
                await companyDbContext.SaveChangesAsync(cancellationToken);
                return branch.BranchId;
            },
            cancellationToken);

        return await GetByIdAsync(branchId, currentUserId, cancellationToken);
    }

    public async Task<BranchResponse> UpdateAsync(
        int id,
        UpdateBranchRequest request,
        int currentUserId,
        CancellationToken cancellationToken)
    {
        var scope = await GetScopeAsync(currentUserId, cancellationToken);
        if (!scope.IsSuperAdmin && !scope.IsCompany)
        {
            throw new ForbiddenException("Role này chỉ được xem trạm, không được sửa trạm.");
        }

        var branchId = await ExecuteInSerializableTransactionAsync(
            async () =>
            {
                var branch = await GetTrackedBranchAsync(id, scope, cancellationToken);
                var oldCode = branch.Code?.Trim();
                var oldUsername = branch.Username?.Trim();

                if (request.Code is not null)
                {
                    branch.Code = RequireValue(request.Code, "Mã trạm là bắt buộc.");
                }

                if (request.Name is not null)
                {
                    branch.Name = RequireValue(request.Name, "Tên trạm là bắt buộc.");
                }

                if (request.Email is not null)
                {
                    branch.Email = RequireValue(request.Email, "Email là bắt buộc.");
                }

                if (request.Phone is not null)
                {
                    branch.Phone = RequireValue(request.Phone, "Số điện thoại là bắt buộc.");
                }

                if (request.Address is not null)
                {
                    branch.Address = TrimOrNull(request.Address);
                }

                if (request.PMQLXe is not null)
                {
                    branch.PMQLXe = TrimOrNull(request.PMQLXe);
                }

                if (request.QLCamera is not null)
                {
                    branch.QLCamera = TrimOrNull(request.QLCamera);
                }

                if (scope.IsSuperAdmin)
                {
                    if (request.CompanyId.HasValue)
                    {
                        await EnsureActiveCompanyAsync(request.CompanyId.Value, cancellationToken);
                        branch.CompanyId = request.CompanyId.Value;
                    }

                    if (request.Username is not null)
                    {
                        branch.Username = RequireValue(request.Username, "Tài khoản là bắt buộc.");
                    }

                    if (request.TypeTram.HasValue)
                    {
                        branch.TypeTram = RequireTypeTram(request.TypeTram);
                    }

                    if (!string.IsNullOrWhiteSpace(request.Password) && !IsMaskedPassword(request.Password))
                    {
                        ValidatePassword(request.Password);
                        branch.Password = request.Password;
                    }
                }

                var newCode = branch.Code?.Trim();
                if (branch.Status == WebDataStatus.Active &&
                    !string.Equals(oldCode, newCode, StringComparison.Ordinal))
                {
                    await EnsureCodeAvailableAsync(
                        RequireValue(branch.Code, "Mã trạm là bắt buộc."),
                        id,
                        cancellationToken);
                }

                var newUsername = branch.Username?.Trim();
                if (branch.Status == WebDataStatus.Active &&
                    !string.Equals(oldUsername, newUsername, StringComparison.OrdinalIgnoreCase))
                {
                    await EnsureUsernameAvailableAsync(
                        RequireValue(branch.Username, "Tài khoản là bắt buộc."),
                        id,
                        cancellationToken);
                }

                EnsureRequiredCurrentFields(branch);
                branch.UpdatedAt = VietnamTime.Now;
                await companyDbContext.SaveChangesAsync(cancellationToken);
                return branch.BranchId;
            },
            cancellationToken);

        return await GetByIdAsync(branchId, currentUserId, cancellationToken);
    }

    public async Task<BranchResponse> DeleteAsync(
        int id,
        int currentUserId,
        CancellationToken cancellationToken)
    {
        var scope = await GetScopeAsync(currentUserId, cancellationToken);
        EnsureSuperAdmin(scope, "Chỉ ADMIN mới được xóa trạm.");
        var branchId = await ExecuteInSerializableTransactionAsync(
            async () =>
            {
                var branch = await companyDbContext.Branches
                    .SingleOrDefaultAsync(item => item.BranchId == id, cancellationToken)
                    ?? throw new NotFoundException("Không tìm thấy trạm.");
                branch.Status = WebDataStatus.Inactive;
                branch.UpdatedAt = VietnamTime.Now;
                await companyDbContext.SaveChangesAsync(cancellationToken);
                return branch.BranchId;
            },
            cancellationToken);
        return await GetByIdAsync(branchId, currentUserId, cancellationToken);
    }

    public async Task<BranchResponse> RestoreAsync(
        int id,
        int currentUserId,
        CancellationToken cancellationToken)
    {
        var scope = await GetScopeAsync(currentUserId, cancellationToken);
        EnsureSuperAdmin(scope, "Chỉ ADMIN mới được khôi phục trạm.");
        var branchId = await ExecuteInSerializableTransactionAsync(
            async () =>
            {
                var branch = await companyDbContext.Branches
                    .SingleOrDefaultAsync(item => item.BranchId == id, cancellationToken)
                    ?? throw new NotFoundException("Không tìm thấy trạm.");
                await EnsureCodeAvailableAsync(
                    RequireValue(branch.Code, "Mã trạm là bắt buộc."),
                    id,
                    cancellationToken);
                await EnsureUsernameAvailableAsync(
                    RequireValue(branch.Username, "Tài khoản là bắt buộc."),
                    id,
                    cancellationToken);
                branch.Status = WebDataStatus.Active;
                branch.UpdatedAt = VietnamTime.Now;
                await companyDbContext.SaveChangesAsync(cancellationToken);
                return branch.BranchId;
            },
            cancellationToken);
        return await GetByIdAsync(branchId, currentUserId, cancellationToken);
    }

    private async Task<BranchActorScope> GetScopeAsync(
        int currentUserId,
        CancellationToken cancellationToken)
    {
        var user = await authDbContext.Users.AsNoTracking()
            .SingleOrDefaultAsync(
                item => item.UserId == currentUserId && item.Status == WebDataStatus.Active,
                cancellationToken)
            ?? throw new UnauthorizedException("Phiên đăng nhập không còn hợp lệ.");

        var roleCodes = await (
            from userRole in authDbContext.UserRoles.AsNoTracking()
            join role in authDbContext.Roles.AsNoTracking() on userRole.RoleId equals role.RoleId
            where userRole.UserId == currentUserId &&
                  userRole.Status == WebDataStatus.Active &&
                  role.Status == WebDataStatus.Active
            select role.Code)
            .ToListAsync(cancellationToken);
        var isSuperAdmin = await systemRoleEvaluator.IsSuperAdminAsync(currentUserId, cancellationToken);
        return new BranchActorScope(
            isSuperAdmin,
            !isSuperAdmin && roleCodes.Contains(SystemRoleCodes.Company, StringComparer.Ordinal),
            user.CompanyId,
            ParseBranchIds(user.BranchId));
    }

    private static IQueryable<WebBranch> ApplyScope(
        IQueryable<WebBranch> branches,
        BranchActorScope scope)
    {
        if (scope.IsSuperAdmin)
        {
            return branches;
        }

        if (scope.IsCompany && scope.CompanyId.HasValue)
        {
            return branches.Where(branch => branch.CompanyId == scope.CompanyId.Value);
        }

        return scope.BranchIds.Length == 0
            ? branches.Where(_ => false)
            : branches.Where(branch => branch.BranchId > 0 && scope.BranchIds.Contains(branch.BranchId));
    }

    private async Task<WebBranch> GetTrackedBranchAsync(
        int id,
        BranchActorScope scope,
        CancellationToken cancellationToken)
    {
        var query = ApplyScope(companyDbContext.Branches, scope);
        if (!scope.IsSuperAdmin)
        {
            query = query.Where(branch => branch.Status == WebDataStatus.Active);
        }

        return await query.SingleOrDefaultAsync(item => item.BranchId == id, cancellationToken)
            ?? throw new NotFoundException("Không tìm thấy trạm.");
    }

    private async Task<BranchResponse> BuildResponseAsync(
        WebBranch branch,
        CancellationToken cancellationToken)
    {
        var companyName = await companyDbContext.Companies.AsNoTracking()
            .Where(company => company.CompanyId == branch.CompanyId)
            .Select(company => company.Name)
            .SingleOrDefaultAsync(cancellationToken);
        return new BranchResponse(
            branch.BranchId,
            branch.CompanyId,
            companyName,
            branch.Code,
            branch.Name,
            branch.Email,
            branch.Phone,
            branch.Address,
            branch.TypeTram,
            branch.Username,
            PasswordMask,
            branch.PMQLXe,
            branch.QLCamera,
            branch.Status ?? WebDataStatus.Inactive,
            branch.Status == WebDataStatus.Active,
            VietnamTime.ToUtc(branch.CreatedAt),
            VietnamTime.ToUtc(branch.UpdatedAt));
    }

    private async Task EnsureActiveCompanyAsync(int companyId, CancellationToken cancellationToken)
    {
        var exists = await companyDbContext.Companies.AsNoTracking()
            .AnyAsync(
                company => company.CompanyId == companyId && company.Status == WebDataStatus.Active,
                cancellationToken);
        if (!exists)
        {
            throw new ValidationException("Công ty không tồn tại hoặc không còn hoạt động.");
        }
    }

    private async Task EnsureCodeAvailableAsync(
        string code,
        int? excludingBranchId,
        CancellationToken cancellationToken)
    {
        var normalizedCode = RequireValue(code, "Mã trạm là bắt buộc.");
        var candidates = companyDbContext.Branches.AsNoTracking().Where(branch =>
            branch.Status == WebDataStatus.Active &&
            (!excludingBranchId.HasValue || branch.BranchId != excludingBranchId.Value) &&
            branch.Code != null);
        var exists = companyDbContext.Database.IsRelational()
            ? await candidates.AnyAsync(
                branch => EF.Functions.Collate(branch.Code!.Trim(), CaseSensitiveCollation) == normalizedCode,
                cancellationToken)
            : (await candidates.Select(branch => branch.Code).ToListAsync(cancellationToken))
                .Any(existing => string.Equals(existing?.Trim(), normalizedCode, StringComparison.Ordinal));
        if (exists)
        {
            throw new ConflictException("Mã trạm đã tồn tại.");
        }
    }

    private async Task EnsureUsernameAvailableAsync(
        string username,
        int? excludingBranchId,
        CancellationToken cancellationToken)
    {
        var normalizedUsername = RequireValue(username, "Tài khoản là bắt buộc.");
        var candidates = companyDbContext.Branches.AsNoTracking().Where(branch =>
            branch.Status == WebDataStatus.Active &&
            (!excludingBranchId.HasValue || branch.BranchId != excludingBranchId.Value) &&
            branch.Username != null);
        var exists = companyDbContext.Database.IsRelational()
            ? await candidates.AnyAsync(
                branch => EF.Functions.Collate(branch.Username!.Trim(), CaseInsensitiveCollation) == normalizedUsername,
                cancellationToken)
            : (await candidates.Select(branch => branch.Username).ToListAsync(cancellationToken))
                .Any(existing => string.Equals(existing?.Trim(), normalizedUsername, StringComparison.OrdinalIgnoreCase));
        if (exists)
        {
            throw new ConflictException("Tài khoản trạm đã tồn tại.");
        }
    }

    private async Task<TResult> ExecuteInSerializableTransactionAsync<TResult>(
        Func<Task<TResult>> operation,
        CancellationToken cancellationToken)
    {
        if (!companyDbContext.Database.IsRelational() || companyDbContext.Database.CurrentTransaction is not null)
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

    private static void EnsureCompanyFilterAllowed(int? companyId, BranchActorScope scope)
    {
        if (!companyId.HasValue || scope.IsSuperAdmin)
        {
            return;
        }

        if (!scope.IsCompany || scope.CompanyId != companyId.Value)
        {
            throw new ForbiddenException("Không được lọc trạm ngoài phạm vi được cấp.");
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

    private static int? ResolveTypeTram(int? typeTram)
    {
        if (!typeTram.HasValue)
        {
            return null;
        }

        return typeTram.Value is 1 or 2
            ? typeTram.Value
            : throw new ValidationException("Loại trạm chỉ nhận giá trị 1 hoặc 2.");
    }

    private static int RequireTypeTram(int? typeTram) =>
        typeTram is 1 or 2
            ? typeTram.Value
            : throw new ValidationException("Loại trạm là bắt buộc và chỉ nhận giá trị 1 hoặc 2.");

    private static void EnsureRequiredCurrentFields(WebBranch branch)
    {
        RequireValue(branch.Code, "Mã trạm là bắt buộc.");
        RequireValue(branch.Name, "Tên trạm là bắt buộc.");
        RequireValue(branch.Email, "Email là bắt buộc.");
        RequireValue(branch.Phone, "Số điện thoại là bắt buộc.");
        RequireValue(branch.Username, "Tài khoản là bắt buộc.");
        RequireValue(branch.Password, "Mật khẩu là bắt buộc.");
    }

    private static void ValidatePassword(string password) => PasswordPolicy.Validate(password);

    private static bool IsMaskedPassword(string value) =>
        value.Length >= 4 && value.All(character => character is '•' or '*');

    private static string RequireValue(string? value, string message)
    {
        var trimmed = value?.Trim();
        return !string.IsNullOrEmpty(trimmed)
            ? trimmed
            : throw new ValidationException(message);
    }

    private static string? TrimOrNull(string? value)
    {
        var trimmed = value?.Trim();
        return string.IsNullOrEmpty(trimmed) ? null : trimmed;
    }

    private static int[] ParseBranchIds(string? value) =>
        (value ?? string.Empty)
            .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Select(token => int.TryParse(token, out var id) ? id : 0)
            .Where(id => id > 0)
            .Distinct()
            .ToArray();

    private static void EnsureSuperAdmin(BranchActorScope scope, string message)
    {
        if (!scope.IsSuperAdmin)
        {
            throw new ForbiddenException(message);
        }
    }

    private sealed record BranchActorScope(
        bool IsSuperAdmin,
        bool IsCompany,
        int? CompanyId,
        int[] BranchIds);
}
