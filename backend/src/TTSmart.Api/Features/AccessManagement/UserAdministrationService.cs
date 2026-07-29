using System.Data;
using System.ComponentModel.DataAnnotations;
using TTSmart.Api.Common.Exceptions;
using TTSmart.Api.Common.Models;
using TTSmart.Api.Common.Security;
using TTSmart.Api.Common.Time;
using TTSmart.Api.Data.Company;
using TTSmart.Api.Data.WebAuth;
using TTSmart.Api.Features.Auth;
using TTSmart.Api.Features.Authorization;
using Microsoft.EntityFrameworkCore;

namespace TTSmart.Api.Features.AccessManagement;

public sealed class UserAdministrationService(
    WebAuthDbContext dbContext,
    CompanyDbContext companyDbContext,
    IDatabasePasswordService passwordService,
    ISystemRoleEvaluator systemRoleEvaluator) : IUserAdministrationService
{
    public async Task<PagedResponse<UserResponse>> GetPageAsync(
        UserListQuery query,
        int currentUserId,
        CancellationToken cancellationToken)
    {
        var scope = await GetScopeAsync(currentUserId, cancellationToken);
        var status = AccessManagementSupport.ResolveStatusFilter(query.Status);
        var usersQuery = ApplyScope(
            dbContext.Users.AsNoTracking().Where(user => user.Status == status),
            scope);
        var search = AccessManagementSupport.TrimOrNull(query.Search);
        if (search is not null)
        {
            usersQuery = usersQuery.Where(user =>
                user.UserName.Contains(search) ||
                (user.FullName != null && user.FullName.Contains(search)) ||
                (user.Email != null && user.Email.Contains(search)) ||
                (user.Code != null && user.Code.Contains(search)) ||
                (user.Phone != null && user.Phone.Contains(search)));
        }

        if (query.RoleId.HasValue)
        {
            usersQuery = usersQuery.Where(user => dbContext.UserRoles.AsNoTracking().Any(userRole =>
                userRole.UserId == user.UserId &&
                userRole.RoleId == query.RoleId.Value &&
                userRole.Status == WebDataStatus.Active) &&
                dbContext.Roles.AsNoTracking().Any(role =>
                    role.RoleId == query.RoleId.Value &&
                    role.Status == WebDataStatus.Active));
        }

        var totalCount = await usersQuery.CountAsync(cancellationToken);
        var users = await usersQuery
            .OrderBy(user => user.UserName)
            .ThenBy(user => user.UserId)
            .Skip((query.PageNumber - 1) * query.PageSize)
            .Take(query.PageSize)
            .ToListAsync(cancellationToken);
        var rolesByUser = await LoadRolesByUserAsync(users.Select(user => user.UserId), cancellationToken);
        var items = users.Select(user => BuildResponse(user, rolesByUser)).ToList();
        var totalPages = totalCount == 0 ? 0 : (int)Math.Ceiling(totalCount / (double)query.PageSize);
        return new PagedResponse<UserResponse>(items, query.PageNumber, query.PageSize, totalCount, totalPages);
    }

    public async Task<UserResponse> GetByIdAsync(
        int id,
        int currentUserId,
        CancellationToken cancellationToken)
    {
        var scope = await GetScopeAsync(currentUserId, cancellationToken);
        var user = await ApplyScope(dbContext.Users.AsNoTracking(), scope)
            .SingleOrDefaultAsync(item => item.UserId == id, cancellationToken)
            ?? throw new NotFoundException("Không tìm thấy người dùng.");
        var rolesByUser = await LoadRolesByUserAsync([id], cancellationToken);
        return BuildResponse(user, rolesByUser);
    }

    public async Task<UserResponse> CreateAsync(
        CreateUserRequest request,
        int currentUserId,
        CancellationToken cancellationToken)
    {
        var scope = await GetScopeAsync(currentUserId, cancellationToken);
        var userName = RequireValue(request.UserName, "Tên đăng nhập là bắt buộc.");
        await EnsureUserNameAvailableAsync(userName, null, cancellationToken);
        var roleIds = NormalizeIds(request.RoleIds, "RoleId không hợp lệ.");
        await ValidateActiveRolesAsync(roleIds, cancellationToken);
        await ValidateAssignableRolesAsync(roleIds, scope, cancellationToken);
        var companyId = ResolveCompanyId(request.CompanyId, scope);

        var userId = await AccessManagementSupport.ExecuteInTransactionAsync(
            dbContext,
            async () =>
            {
                if (!scope.IsSuperAdmin)
                {
                    await EnsureChildAccountQuotaAvailableAsync(companyId!.Value, cancellationToken);
                }

                var now = DateTime.Now;
                var user = new WebUser
                {
                    UserName = userName,
                    Password = DatabasePasswordService.PendingPasswordHash,
                    CreatedAt = now,
                    UpdatedAt = now,
                    UserCreateId = currentUserId,
                    UserEditId = currentUserId,
                    Status = WebDataStatus.Active
                };
                ApplyFields(user, request);
                user.CompanyId = companyId;
                dbContext.Users.Add(user);
                await dbContext.SaveChangesAsync(cancellationToken);
                await dbContext.Entry(user).ReloadAsync(cancellationToken);
                user.Password = passwordService.HashForStorage(user, request.Password);
                await dbContext.SaveChangesAsync(cancellationToken);

                foreach (var roleId in roleIds)
                {
                    dbContext.UserRoles.Add(new WebUserRole
                    {
                        UserId = user.UserId,
                        RoleId = roleId,
                        CreatedAt = now,
                        Status = WebDataStatus.Active
                    });
                }

                await dbContext.SaveChangesAsync(cancellationToken);
                return user.UserId;
            },
            cancellationToken,
            scope.IsSuperAdmin ? IsolationLevel.ReadCommitted : IsolationLevel.Serializable);

        return await GetByIdAsync(userId, currentUserId, cancellationToken);
    }

    public async Task<UserResponse> UpdateAsync(
        int id,
        UpdateUserRequest request,
        int currentUserId,
        CancellationToken cancellationToken)
    {
        var scope = await GetScopeAsync(currentUserId, cancellationToken);
        await GetUserExistsAsync(id, scope, cancellationToken);
        var userName = RequireValue(request.UserName, "Tên đăng nhập là bắt buộc.");
        await EnsureUserNameAvailableAsync(userName, id, cancellationToken);
        var companyId = ResolveCompanyId(request.CompanyId, scope);
        IReadOnlyList<int>? roleIds = null;
        if (request.RoleIds is not null)
        {
            if (id == currentUserId)
            {
                throw new ConflictException("Không thể tự thay đổi vai trò bằng endpoint quản trị người dùng.");
            }

            roleIds = NormalizeIds(request.RoleIds, "RoleId không hợp lệ.");
            await ValidateActiveRolesAsync(roleIds, cancellationToken);
            await ValidateAssignableRolesAsync(roleIds, scope, cancellationToken);
        }

        await AccessManagementSupport.ExecuteInTransactionAsync(
            dbContext,
            async () =>
            {
                var user = await GetTrackedUserAsync(id, scope, cancellationToken);
                var requestedRegEmail = request.RegEmail is null
                    ? user.RegEmail
                    : AccessManagementSupport.TrimOrNull(request.RegEmail);
                if (!string.Equals(user.RegEmail, requestedRegEmail, StringComparison.Ordinal))
                {
                    throw new ConflictException("Không thể thay đổi RegEmail bằng endpoint cập nhật người dùng vì RegEmail tham gia công thức mật khẩu legacy.");
                }

                user.UserName = userName;
                ApplyFields(user, request, preserveRegEmailWhenMissing: true);
                user.CompanyId = companyId;
                user.UpdatedAt = DateTime.Now;
                user.UserEditId = currentUserId;
                if (roleIds is not null)
                {
                    await ReplaceRolesAsync(id, roleIds, DateTime.Now, cancellationToken);
                }

                await dbContext.SaveChangesAsync(cancellationToken);
            },
            cancellationToken);
        return await GetByIdAsync(id, currentUserId, cancellationToken);
    }

    public async Task<UserResponse> SetStatusAsync(
        int id,
        int currentUserId,
        SetUserStatusRequest request,
        CancellationToken cancellationToken)
    {
        var scope = await GetScopeAsync(currentUserId, cancellationToken);
        var isActive = AccessManagementSupport.RequireIsActive(request.IsActive);
        if (id == currentUserId && !isActive)
        {
            throw new ConflictException("Không thể tự khóa tài khoản đang đăng nhập.");
        }

        await AccessManagementSupport.ExecuteInTransactionAsync(
            dbContext,
            async () =>
            {
                var user = await GetTrackedUserAsync(id, scope, cancellationToken);
                if (isActive)
                {
                    await EnsureUserNameAvailableAsync(user.UserName, id, cancellationToken);
                    if (user.Status != WebDataStatus.Active &&
                        !scope.IsSuperAdmin &&
                        await IsChildAccountAsync(id, cancellationToken))
                    {
                        await EnsureChildAccountQuotaAvailableAsync(
                            user.CompanyId ?? throw new ForbiddenException(
                                "Tài khoản chưa được gán công ty nên không thể khôi phục."),
                            cancellationToken);
                    }
                }

                user.Status = isActive ? WebDataStatus.Active : WebDataStatus.Inactive;
                user.UpdatedAt = DateTime.Now;
                user.UserEditId = currentUserId;
                await dbContext.SaveChangesAsync(cancellationToken);
            },
            cancellationToken,
            isActive && !scope.IsSuperAdmin
                ? IsolationLevel.Serializable
                : IsolationLevel.ReadCommitted);
        return await GetByIdAsync(id, currentUserId, cancellationToken);
    }

    public async Task<UserResponse> SetRolesAsync(
        int id,
        int currentUserId,
        SetUserRolesRequest request,
        CancellationToken cancellationToken)
    {
        var scope = await GetScopeAsync(currentUserId, cancellationToken);
        if (id == currentUserId)
        {
            throw new ConflictException("Không thể tự thay đổi vai trò bằng endpoint quản trị người dùng.");
        }

        await GetUserExistsAsync(id, scope, cancellationToken);
        var roleIds = NormalizeIds(request.RoleIds, "RoleId không hợp lệ.");
        await ValidateActiveRolesAsync(roleIds, cancellationToken);
        await ValidateAssignableRolesAsync(roleIds, scope, cancellationToken);
        await AccessManagementSupport.ExecuteInTransactionAsync(
            dbContext,
            async () =>
            {
                var now = DateTime.Now;
                await ReplaceRolesAsync(id, roleIds, now, cancellationToken);
                var user = await GetTrackedUserAsync(id, scope, cancellationToken);
                user.UpdatedAt = now;
                user.UserEditId = currentUserId;
                await dbContext.SaveChangesAsync(cancellationToken);
            },
            cancellationToken);
        return await GetByIdAsync(id, currentUserId, cancellationToken);
    }

    public async Task ResetPasswordAsync(
        int id,
        int currentUserId,
        ResetPasswordRequest request,
        CancellationToken cancellationToken)
    {
        var scope = await GetScopeAsync(currentUserId, cancellationToken);
        if (id == currentUserId)
        {
            throw new ConflictException("Hãy dùng endpoint đổi mật khẩu để thay đổi mật khẩu của chính mình.");
        }

        var user = await GetTrackedUserAsync(id, scope, cancellationToken);
        PasswordPolicy.Validate(request.NewPassword);
        user.Password = passwordService.HashForStorage(user, request.NewPassword);
        var now = VietnamTime.Now;
        user.TokenSince = user.TokenSince.HasValue && user.TokenSince.Value >= now
            ? user.TokenSince.Value.AddSeconds(1)
            : now;
        user.UpdatedAt = now;
        user.UserEditId = currentUserId;
        await dbContext.SaveChangesAsync(cancellationToken);
    }

    public async Task DeleteAsync(int id, int currentUserId, CancellationToken cancellationToken)
    {
        var scope = await GetScopeAsync(currentUserId, cancellationToken);
        if (id == currentUserId)
        {
            throw new ConflictException("Không thể tự xóa tài khoản đang đăng nhập.");
        }

        await EnsureDeletableTargetAsync(id, scope, cancellationToken);

        await AccessManagementSupport.ExecuteInTransactionAsync(
            dbContext,
            async () =>
            {
                var user = await GetTrackedUserAsync(id, scope, cancellationToken);
                if (user.Status == WebDataStatus.Inactive)
                {
                    throw new ConflictException("Người dùng đã bị xóa mềm hoặc ngừng hiệu lực.");
                }

                var now = DateTime.Now;
                user.Status = WebDataStatus.Inactive;
                user.UpdatedAt = now;
                user.UserEditId = currentUserId;
                var activeRoles = await dbContext.UserRoles
                    .Where(item => item.UserId == id && item.Status == WebDataStatus.Active)
                    .ToListAsync(cancellationToken);
                foreach (var userRole in activeRoles)
                {
                    userRole.Status = WebDataStatus.Inactive;
                }

                await dbContext.SaveChangesAsync(cancellationToken);
            },
            cancellationToken);
    }

    private async Task ReplaceRolesAsync(
        int userId,
        IReadOnlyCollection<int> roleIds,
        DateTime now,
        CancellationToken cancellationToken)
    {
        var rows = await dbContext.UserRoles
            .Where(item => item.UserId == userId)
            .OrderByDescending(item => item.UserRoleId)
            .ToListAsync(cancellationToken);
        var desiredRoleIds = roleIds.ToHashSet();
        foreach (var group in rows.GroupBy(item => item.RoleId))
        {
            if (!desiredRoleIds.Remove(group.Key))
            {
                foreach (var row in group.Where(item => item.Status == WebDataStatus.Active))
                {
                    row.Status = WebDataStatus.Inactive;
                }

                continue;
            }

            var selected = group.FirstOrDefault(item => item.Status == WebDataStatus.Active) ?? group.First();
            selected.Status = WebDataStatus.Active;
            foreach (var duplicate in group.Where(item =>
                         item.UserRoleId != selected.UserRoleId &&
                         item.Status == WebDataStatus.Active))
            {
                duplicate.Status = WebDataStatus.Inactive;
            }
        }

        foreach (var roleId in desiredRoleIds)
        {
            dbContext.UserRoles.Add(new WebUserRole
            {
                UserId = userId,
                RoleId = roleId,
                CreatedAt = now,
                Status = WebDataStatus.Active
            });
        }
    }

    private async Task ValidateActiveRolesAsync(
        IReadOnlyCollection<int> roleIds,
        CancellationToken cancellationToken)
    {
        if (roleIds.Count == 0)
        {
            return;
        }

        var existingIds = await dbContext.Roles.AsNoTracking()
            .Where(role => roleIds.Contains(role.RoleId) && role.Status == WebDataStatus.Active)
            .Select(role => role.RoleId)
            .ToListAsync(cancellationToken);
        var missingIds = roleIds.Except(existingIds).ToArray();
        if (missingIds.Length > 0)
        {
            throw new ValidationException($"Role không tồn tại hoặc đã ngừng hiệu lực: {string.Join(", ", missingIds)}.");
        }
    }

    private async Task ValidateAssignableRolesAsync(
        IReadOnlyCollection<int> roleIds,
        UserAdministrationScope scope,
        CancellationToken cancellationToken)
    {
        if (scope.IsSuperAdmin)
        {
            return;
        }

        if (roleIds.Count != 1)
        {
            throw new ValidationException("Tài khoản do công ty quản lý phải được gán đúng một vai trò.");
        }

        var containsProtectedRole = await dbContext.Roles.AsNoTracking().AnyAsync(
            role => roleIds.Contains(role.RoleId) &&
                    role.Status == WebDataStatus.Active &&
                    (role.Code == SystemRoleCodes.Admin || role.Code == SystemRoleCodes.Company),
            cancellationToken);
        if (containsProtectedRole)
        {
            throw new ForbiddenException("Tài khoản công ty chỉ được gán vai trò thấp hơn Chủ doanh nghiệp.");
        }
    }

    private async Task EnsureChildAccountQuotaAvailableAsync(
        int companyId,
        CancellationToken cancellationToken)
    {
        var company = await companyDbContext.Companies.AsNoTracking()
            .Where(item => item.CompanyId == companyId && item.Status == WebDataStatus.Active)
            .Select(item => new { item.CountUser })
            .SingleOrDefaultAsync(cancellationToken)
            ?? throw new ForbiddenException("Công ty không còn hiệu lực hoặc không tồn tại.");
        var activeChildAccountCount = await dbContext.Users.AsNoTracking()
            .Where(user => user.CompanyId == companyId && user.Status == WebDataStatus.Active)
            .Where(user => !(
                from userRole in dbContext.UserRoles.AsNoTracking()
                join role in dbContext.Roles.AsNoTracking() on userRole.RoleId equals role.RoleId
                where userRole.UserId == user.UserId &&
                      userRole.Status == WebDataStatus.Active &&
                      role.Status == WebDataStatus.Active &&
                      (role.Code == SystemRoleCodes.Admin || role.Code == SystemRoleCodes.Company)
                select role.RoleId)
                .Any())
            .CountAsync(cancellationToken);
        if (activeChildAccountCount >= company.CountUser)
        {
            throw new ConflictException(
                $"Công ty đã sử dụng đủ {company.CountUser} tài khoản được cấp. Vui lòng liên hệ TTSmart để tăng giới hạn.");
        }
    }

    private async Task<bool> IsChildAccountAsync(int userId, CancellationToken cancellationToken)
    {
        var latestRoleCode = await (
            from userRole in dbContext.UserRoles.AsNoTracking()
            join role in dbContext.Roles.AsNoTracking() on userRole.RoleId equals role.RoleId
            where userRole.UserId == userId && role.Status == WebDataStatus.Active
            orderby userRole.UserRoleId descending
            select role.Code)
            .FirstOrDefaultAsync(cancellationToken);
        return latestRoleCode is not SystemRoleCodes.Admin and not SystemRoleCodes.Company;
    }

    private async Task EnsureDeletableTargetAsync(
        int id,
        UserAdministrationScope scope,
        CancellationToken cancellationToken)
    {
        await GetUserExistsAsync(id, scope, cancellationToken);
        if (scope.IsSuperAdmin)
        {
            return;
        }

        var hasSameOrHigherRole = await (
            from userRole in dbContext.UserRoles.AsNoTracking()
            join role in dbContext.Roles.AsNoTracking() on userRole.RoleId equals role.RoleId
            where userRole.UserId == id &&
                  userRole.Status == WebDataStatus.Active &&
                  role.Status == WebDataStatus.Active &&
                  (role.Code == SystemRoleCodes.Admin || role.Code == SystemRoleCodes.Company)
            select role.RoleId)
            .AnyAsync(cancellationToken);
        if (hasSameOrHigherRole)
        {
            throw new ForbiddenException("Chủ doanh nghiệp chỉ được xóa tài khoản có vai trò thấp hơn.");
        }
    }

    private async Task<UserAdministrationScope> GetScopeAsync(
        int currentUserId,
        CancellationToken cancellationToken)
    {
        if (await systemRoleEvaluator.IsSuperAdminAsync(currentUserId, cancellationToken))
        {
            return new UserAdministrationScope(true, null, currentUserId);
        }

        var currentUser = await dbContext.Users.AsNoTracking()
            .Where(user => user.UserId == currentUserId && user.Status == WebDataStatus.Active)
            .Select(user => new { user.CompanyId })
            .SingleOrDefaultAsync(cancellationToken)
            ?? throw new UnauthorizedException("Phiên đăng nhập không còn hợp lệ.");
        return new UserAdministrationScope(false, currentUser.CompanyId, currentUserId);
    }

    private static IQueryable<WebUser> ApplyScope(
        IQueryable<WebUser> query,
        UserAdministrationScope scope)
    {
        if (scope.IsSuperAdmin)
        {
            return query;
        }

        return scope.CompanyId.HasValue
            ? query.Where(user => user.CompanyId == scope.CompanyId.Value)
            : query.Where(user => user.UserId == scope.CurrentUserId);
    }

    private static int? ResolveCompanyId(int? requestedCompanyId, UserAdministrationScope scope)
    {
        if (scope.IsSuperAdmin)
        {
            return requestedCompanyId;
        }

        if (!scope.CompanyId.HasValue)
        {
            throw new ForbiddenException("Tài khoản chưa được gán công ty nên không thể quản lý người dùng.");
        }

        if (requestedCompanyId.HasValue && requestedCompanyId.Value != scope.CompanyId.Value)
        {
            throw new ForbiddenException("Không thể tạo hoặc chuyển người dùng sang công ty khác.");
        }

        return scope.CompanyId.Value;
    }

    private async Task<IReadOnlyList<int>> LoadActiveRoleIdsAsync(
        int userId,
        UserAdministrationScope scope,
        CancellationToken cancellationToken) =>
        await (
            from userRole in dbContext.UserRoles.AsNoTracking()
            join role in dbContext.Roles.AsNoTracking() on userRole.RoleId equals role.RoleId
            where userRole.UserId == userId &&
                  userRole.Status == WebDataStatus.Active &&
                  role.Status == WebDataStatus.Active
            select role.RoleId)
            .Distinct()
            .ToListAsync(cancellationToken);

    private async Task<string?> ValidateAndNormalizeBranchAssignmentAsync(
        string? branchValue,
        int? companyId,
        IReadOnlyCollection<int> roleIds,
        CancellationToken cancellationToken)
    {
        var branchIds = ParseBranchIdsStrict(branchValue);
        var roleCodes = await dbContext.Roles.AsNoTracking()
            .Where(role => roleIds.Contains(role.RoleId) && role.Status == WebDataStatus.Active)
            .Select(role => role.Code)
            .ToListAsync(cancellationToken);

        var requiresCompany = roleCodes.Any(code =>
            !string.Equals(code, SystemRoleCodes.Admin, StringComparison.OrdinalIgnoreCase));
        if (requiresCompany && !companyId.HasValue)
        {
            throw new ValidationException("Tài khoản thuộc công ty phải được gán CompanyId.");
        }

        var requiresBranch = roleCodes.Any(code =>
            !string.Equals(code, SystemRoleCodes.Admin, StringComparison.OrdinalIgnoreCase) &&
            !string.Equals(code, SystemRoleCodes.Company, StringComparison.OrdinalIgnoreCase));
        if (requiresBranch && branchIds.Length == 0)
        {
            throw new ValidationException("Tài khoản không phải CONGTY phải được gán ít nhất một trạm.");
        }

        if (branchIds.Length == 0)
        {
            return null;
        }

        if (!companyId.HasValue)
        {
            throw new ValidationException("Phải chọn CompanyId trước khi gán trạm.");
        }

        var validBranchIds = await companyDbContext.Branches.AsNoTracking()
            .Where(branch => branchIds.Contains(branch.BranchId) &&
                             branch.CompanyId == companyId.Value &&
                             branch.Status == WebDataStatus.Active)
            .Select(branch => branch.BranchId)
            .ToListAsync(cancellationToken);
        var invalidBranchIds = branchIds.Except(validBranchIds).ToArray();
        if (invalidBranchIds.Length > 0)
        {
            throw new ValidationException(
                $"Trạm không tồn tại, đã ngừng hiệu lực hoặc không thuộc công ty: {string.Join(", ", invalidBranchIds)}.");
        }

        return string.Join(',', branchIds);
    }

    private static void EnsureRoleSelection(IReadOnlyCollection<int> roleIds)
    {
        if (roleIds.Count == 0)
        {
            throw new ValidationException("Tài khoản phải được gán ít nhất một Role.");
        }
    }

    private static int[] ParseBranchIdsStrict(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return [];
        }

        var tokens = value.Split(',', StringSplitOptions.None);
        var branchIds = new List<int>(tokens.Length);
        foreach (var token in tokens)
        {
            var trimmed = token.Trim();
            if (trimmed.Length == 0 || !int.TryParse(trimmed, out var branchId) || branchId <= 0)
            {
                throw new ValidationException("BranchId phải là danh sách ID trạm dạng số, phân cách bằng dấu phẩy.");
            }

            if (!branchIds.Contains(branchId))
            {
                branchIds.Add(branchId);
            }
        }

        return branchIds.ToArray();
    }
    private async Task EnsureUserNameAvailableAsync(
        string userName,
        int? currentId,
        CancellationToken cancellationToken)
    {
        var exists = await dbContext.Users.AsNoTracking().AnyAsync(
            user => user.UserName == userName &&
                    user.Status == WebDataStatus.Active &&
                    (!currentId.HasValue || user.UserId != currentId.Value),
            cancellationToken);
        if (exists)
        {
            throw new ConflictException("Tên đăng nhập đang được sử dụng bởi một tài khoản hiệu lực.");
        }
    }

    private async Task<WebUser> GetTrackedUserAsync(
        int id,
        UserAdministrationScope scope,
        CancellationToken cancellationToken) =>
        await ApplyScope(dbContext.Users, scope)
            .SingleOrDefaultAsync(user => user.UserId == id, cancellationToken)
        ?? throw new NotFoundException("Không tìm thấy người dùng.");

    private async Task GetUserExistsAsync(
        int id,
        UserAdministrationScope scope,
        CancellationToken cancellationToken)
    {
        if (!await ApplyScope(dbContext.Users.AsNoTracking(), scope)
                .AnyAsync(user => user.UserId == id, cancellationToken))
        {
            throw new NotFoundException("Không tìm thấy người dùng.");
        }
    }

    private async Task<Dictionary<int, IReadOnlyList<RoleReferenceResponse>>> LoadRolesByUserAsync(
        IEnumerable<int> userIds,
        CancellationToken cancellationToken)
    {
        var ids = userIds.Distinct().ToArray();
        if (ids.Length == 0)
        {
            return [];
        }

        var rows = await (
            from userRole in dbContext.UserRoles.AsNoTracking()
            join role in dbContext.Roles.AsNoTracking() on userRole.RoleId equals role.RoleId
            where ids.Contains(userRole.UserId) &&
                  userRole.Status == WebDataStatus.Active &&
                  role.Status == WebDataStatus.Active
            select new
            {
                userRole.UserId,
                Role = new RoleReferenceResponse(
                    role.RoleId,
                    role.Code,
                    role.Name,
                    role.LevelRole,
                    role.Status ?? WebDataStatus.Inactive)
            })
            .ToListAsync(cancellationToken);
        return rows
            .GroupBy(row => row.UserId)
            .ToDictionary(
                group => group.Key,
                group => (IReadOnlyList<RoleReferenceResponse>)group.Select(row => row.Role)
                    .DistinctBy(role => role.Id)
                    .OrderBy(role => role.Name)
                    .ToList());
    }

    private static UserResponse BuildResponse(
        WebUser user,
        IReadOnlyDictionary<int, IReadOnlyList<RoleReferenceResponse>> rolesByUser)
    {
        rolesByUser.TryGetValue(user.UserId, out var roles);
        var status = user.Status ?? WebDataStatus.Inactive;
        return new UserResponse(
            user.UserId,
            user.UserName,
            user.FullName,
            user.Email,
            user.Code,
            user.Avata,
            user.UnitId,
            user.PositionId,
            user.DepartmentId,
            user.CompanyId,
            user.Address,
            user.Phone,
            AccessManagementSupport.ToUtc(user.CreatedAt),
            AccessManagementSupport.ToUtc(user.UpdatedAt),
            AccessManagementSupport.ToUtc(user.TokenSince),
            user.RegEmail,
            user.RoleMax,
            user.RoleLevel,
            user.IsRoleGroup,
            user.UserCreateId,
            user.UserEditId,
            status,
            status == WebDataStatus.Active,
            user.BranchId,
            roles ?? []);
    }

    private static void ApplyFields(
        WebUser user,
        UserFieldsRequest request,
        bool preserveRegEmailWhenMissing = false)
    {
        user.FullName = AccessManagementSupport.TrimOrNull(request.FullName);
        user.Email = AccessManagementSupport.TrimOrNull(request.Email);
        user.Code = AccessManagementSupport.TrimOrNull(request.Code);
        if (!preserveRegEmailWhenMissing || request.RegEmail is not null)
        {
            user.RegEmail = AccessManagementSupport.TrimOrNull(request.RegEmail);
        }
        user.Address = AccessManagementSupport.TrimOrNull(request.Address);
        user.Phone = AccessManagementSupport.TrimOrNull(request.Phone);
        user.UnitId = request.UnitId;
        user.PositionId = request.PositionId;
        user.DepartmentId = request.DepartmentId;
        user.CompanyId = request.CompanyId;
        user.RoleMax = request.RoleMax;
        user.RoleLevel = request.RoleLevel;
        user.IsRoleGroup = request.IsRoleGroup;
        user.BranchId = AccessManagementSupport.TrimOrNull(request.BranchId);
    }

    private static string RequireValue(string value, string errorMessage)
    {
        var trimmed = value.Trim();
        return trimmed.Length > 0 ? trimmed : throw new ValidationException(errorMessage);
    }

    private static IReadOnlyList<int> NormalizeIds(IEnumerable<int> ids, string errorMessage)
    {
        var values = ids.Distinct().ToArray();
        if (values.Any(id => id <= 0))
        {
            throw new ValidationException(errorMessage);
        }

        return values;
    }

    private sealed record UserAdministrationScope(bool IsSuperAdmin, int? CompanyId, int CurrentUserId);
}
