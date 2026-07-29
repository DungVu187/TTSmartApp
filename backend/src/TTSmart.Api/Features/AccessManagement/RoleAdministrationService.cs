using System.ComponentModel.DataAnnotations;
using TTSmart.Api.Common.Exceptions;
using TTSmart.Api.Common.Models;
using TTSmart.Api.Data.WebAuth;
using TTSmart.Api.Features.Authorization;
using Microsoft.EntityFrameworkCore;

namespace TTSmart.Api.Features.AccessManagement;

public sealed class RoleAdministrationService(WebAuthDbContext dbContext) : IRoleAdministrationService
{
    public async Task<PagedResponse<RoleListItemResponse>> GetPageAsync(
        RoleListQuery query,
        CancellationToken cancellationToken)
    {
        var status = AccessManagementSupport.ResolveStatusFilter(query.Status);
        var rolesQuery = dbContext.Roles.AsNoTracking()
            .Where(role => role.Status == status);
        var search = AccessManagementSupport.TrimOrNull(query.Search);
        if (search is not null)
        {
            rolesQuery = rolesQuery.Where(role =>
                role.Code.Contains(search) ||
                role.Name.Contains(search) ||
                (role.Note != null && role.Note.Contains(search)));
        }

        var totalCount = await rolesQuery.CountAsync(cancellationToken);
        var roles = await rolesQuery
            .OrderBy(role => role.Name)
            .ThenBy(role => role.RoleId)
            .Skip((query.PageNumber - 1) * query.PageSize)
            .Take(query.PageSize)
            .ToListAsync(cancellationToken);
        var roleIds = roles.Select(role => role.RoleId).ToArray();
        var userCounts = await LoadUserCountsAsync(roleIds, cancellationToken);
        var functionRows = await (
            from functionRole in dbContext.FunctionRoles.AsNoTracking()
            join function in dbContext.Functions.AsNoTracking()
                on functionRole.FunctionId equals function.FunctionId
            where roleIds.Contains(functionRole.TargetId) &&
                  functionRole.Type == WebFunctionRoleType.Role &&
                  functionRole.Status == WebDataStatus.Active &&
                  function.Status == WebDataStatus.Active
            select new { functionRole.TargetId, functionRole.FunctionId, functionRole.ActiveKey })
            .ToListAsync(cancellationToken);
        var functionsByRole = functionRows.GroupBy(row => row.TargetId).ToDictionary(group => group.Key, group => group.ToList());

        var items = roles.Select(role =>
        {
            userCounts.TryGetValue(role.RoleId, out var userCount);
            functionsByRole.TryGetValue(role.RoleId, out var assignments);
            var status = role.Status ?? WebDataStatus.Inactive;
            return new RoleListItemResponse(
                role.RoleId,
                role.Code,
                role.Name,
                role.Note,
                role.LevelRole,
                status,
                status == WebDataStatus.Active,
                userCount,
                assignments?.Select(item => item.FunctionId).Distinct().Count() ?? 0,
                assignments?.Where(item => ActiveKeyValue.HasAnyPermission(item.ActiveKey))
                    .Select(item => item.FunctionId).Distinct().Count() ?? 0);
        }).ToList();
        var totalPages = totalCount == 0 ? 0 : (int)Math.Ceiling(totalCount / (double)query.PageSize);
        return new PagedResponse<RoleListItemResponse>(items, query.PageNumber, query.PageSize, totalCount, totalPages);
    }

    public async Task<RoleResponse> GetByIdAsync(int id, CancellationToken cancellationToken)
    {
        var role = await dbContext.Roles.AsNoTracking()
            .SingleOrDefaultAsync(item => item.RoleId == id, cancellationToken)
            ?? throw new NotFoundException("Không tìm thấy vai trò.");
        return await BuildResponseAsync(role, cancellationToken);
    }

    public async Task<RoleResponse> CreateAsync(
        CreateRoleRequest request,
        int currentUserId,
        CancellationToken cancellationToken)
    {
        var code = RequireValue(request.Code, "Mã vai trò là bắt buộc.");
        var name = RequireValue(request.Name, "Tên vai trò là bắt buộc.");
        await EnsureUniqueAsync(code, name, null, cancellationToken);
        var now = DateTime.Now;
        var role = new WebRole
        {
            Code = code,
            Name = name,
            Note = AccessManagementSupport.TrimOrNull(request.Note),
            LevelRole = request.LevelRole,
            CreatedAt = now,
            UpdatedAt = now,
            UserId = currentUserId,
            UserEditId = currentUserId,
            Status = WebDataStatus.Active
        };
        dbContext.Roles.Add(role);
        await dbContext.SaveChangesAsync(cancellationToken);
        return await GetByIdAsync(role.RoleId, cancellationToken);
    }

    public async Task<RoleResponse> UpdateAsync(
        int id,
        UpdateRoleRequest request,
        int currentUserId,
        CancellationToken cancellationToken)
    {
        var code = RequireValue(request.Code, "Mã vai trò là bắt buộc.");
        var name = RequireValue(request.Name, "Tên vai trò là bắt buộc.");
        await EnsureUniqueAsync(code, name, id, cancellationToken);
        var role = await GetTrackedRoleAsync(id, cancellationToken);
        role.Code = code;
        role.Name = name;
        role.Note = AccessManagementSupport.TrimOrNull(request.Note);
        role.LevelRole = request.LevelRole;
        role.UpdatedAt = DateTime.Now;
        role.UserEditId = currentUserId;
        await dbContext.SaveChangesAsync(cancellationToken);
        return await GetByIdAsync(id, cancellationToken);
    }

    public async Task<RoleResponse> SetStatusAsync(
        int id,
        int currentUserId,
        SetRoleStatusRequest request,
        CancellationToken cancellationToken)
    {
        var isActive = AccessManagementSupport.RequireIsActive(request.IsActive);
        var role = await GetTrackedRoleAsync(id, cancellationToken);
        if (!isActive && role.Status == WebDataStatus.Active)
        {
            await EnsureAdministrationRemainsAsync(id, cancellationToken);
        }

        role.Status = isActive ? WebDataStatus.Active : WebDataStatus.Inactive;
        role.UpdatedAt = DateTime.Now;
        role.UserEditId = currentUserId;
        await dbContext.SaveChangesAsync(cancellationToken);
        return await GetByIdAsync(id, cancellationToken);
    }

    public async Task<IReadOnlyList<RoleFunctionMatrixItemResponse>> GetFunctionMatrixAsync(
        int id,
        CancellationToken cancellationToken)
    {
        await EnsureRoleExistsAsync(id, cancellationToken);
        var functions = await dbContext.Functions.AsNoTracking()
            .Where(function => function.Status == WebDataStatus.Active)
            .OrderBy(function => function.Location)
            .ThenBy(function => function.FunctionParentId)
            .ThenBy(function => function.Name)
            .ThenBy(function => function.FunctionId)
            .ToListAsync(cancellationToken);
        var rows = await dbContext.FunctionRoles.AsNoTracking()
            .Where(item => item.TargetId == id && item.Type == WebFunctionRoleType.Role)
            .OrderByDescending(item => item.FunctionRoleId)
            .ToListAsync(cancellationToken);
        var activeByFunction = rows
            .Where(item => item.Status == WebDataStatus.Active)
            .GroupBy(item => item.FunctionId)
            .ToDictionary(group => group.Key, group => group.First());

        return functions.Select(function =>
        {
            activeByFunction.TryGetValue(function.FunctionId, out var assignment);
            var activeKey = ActiveKeyValue.Normalize(assignment?.ActiveKey);
            return new RoleFunctionMatrixItemResponse(
                function.FunctionId,
                AccessManagementSupport.NormalizeParent(function.FunctionParentId),
                function.Code,
                function.Name,
                function.Url,
                function.Location,
                function.Icon,
                assignment?.FunctionRoleId,
                assignment is not null,
                activeKey,
                AccessManagementSupport.ToPermissions(activeKey));
        }).ToList();
    }

    public async Task<RoleResponse> SetFunctionsAsync(
        int id,
        int currentUserId,
        SetRoleFunctionsRequest request,
        CancellationToken cancellationToken)
    {
        await EnsureActiveRoleAsync(id, cancellationToken);
        var assignments = request.Functions.ToList();
        if (assignments.Select(item => item.FunctionId).Distinct().Count() != assignments.Count)
        {
            throw new ValidationException("Danh sách Function không được chứa FunctionId trùng nhau.");
        }

        foreach (var assignment in assignments)
        {
            ValidateActiveKey(assignment.ActiveKey);
        }

        var functionIds = assignments.Select(item => item.FunctionId).ToArray();
        await ValidateActiveFunctionsAsync(functionIds, cancellationToken);
        await EnsureMatrixKeepsAdministrationAsync(id, assignments, cancellationToken);
        await AccessManagementSupport.ExecuteInTransactionAsync(
            dbContext,
            async () =>
            {
                var now = DateTime.Now;
                var existingRows = await dbContext.FunctionRoles
                    .Where(item => item.TargetId == id && item.Type == WebFunctionRoleType.Role)
                    .OrderByDescending(item => item.FunctionRoleId)
                    .ToListAsync(cancellationToken);
                var desiredByFunction = assignments.ToDictionary(item => item.FunctionId);

                foreach (var group in existingRows.GroupBy(item => item.FunctionId))
                {
                    if (!desiredByFunction.TryGetValue(group.Key, out var desired))
                    {
                        foreach (var row in group.Where(item => item.Status == WebDataStatus.Active))
                        {
                            row.Status = WebDataStatus.Inactive;
                            row.UpdatedAt = now;
                            row.UserId = currentUserId;
                        }

                        continue;
                    }

                    var selected = group.FirstOrDefault(item => item.Status == WebDataStatus.Active) ?? group.First();
                    selected.ActiveKey = desired.ActiveKey;
                    selected.Type = WebFunctionRoleType.Role;
                    selected.Status = WebDataStatus.Active;
                    selected.UpdatedAt = now;
                    selected.UserId = currentUserId;
                    foreach (var duplicate in group.Where(item => item.FunctionRoleId != selected.FunctionRoleId && item.Status == WebDataStatus.Active))
                    {
                        duplicate.Status = WebDataStatus.Inactive;
                        duplicate.UpdatedAt = now;
                        duplicate.UserId = currentUserId;
                    }

                    desiredByFunction.Remove(group.Key);
                }

                foreach (var desired in desiredByFunction.Values)
                {
                    dbContext.FunctionRoles.Add(new WebFunctionRole
                    {
                        TargetId = id,
                        FunctionId = desired.FunctionId,
                        ActiveKey = desired.ActiveKey,
                        Type = WebFunctionRoleType.Role,
                        CreatedAt = now,
                        UpdatedAt = now,
                        UserId = currentUserId,
                        Status = WebDataStatus.Active
                    });
                }

                await dbContext.SaveChangesAsync(cancellationToken);
            },
            cancellationToken);
        return await GetByIdAsync(id, cancellationToken);
    }

    public async Task<RoleResponse> SetFunctionActiveKeyAsync(
        int roleId,
        int functionId,
        int currentUserId,
        SetRoleFunctionActiveKeyRequest request,
        CancellationToken cancellationToken)
    {
        ValidateActiveKey(request.ActiveKey);
        await EnsureActiveRoleAsync(roleId, cancellationToken);
        await ValidateActiveFunctionsAsync([functionId], cancellationToken);
        await EnsureFunctionPermissionKeepsAdministrationAsync(
            roleId,
            functionId,
            request.ActiveKey,
            cancellationToken);
        await AccessManagementSupport.ExecuteInTransactionAsync(
            dbContext,
            async () =>
            {
                var now = DateTime.Now;
                var rows = await dbContext.FunctionRoles
                    .Where(item => item.TargetId == roleId &&
                                   item.FunctionId == functionId &&
                                   item.Type == WebFunctionRoleType.Role)
                    .OrderByDescending(item => item.FunctionRoleId)
                    .ToListAsync(cancellationToken);
                var selected = rows.FirstOrDefault(item => item.Status == WebDataStatus.Active) ?? rows.FirstOrDefault();
                if (selected is null)
                {
                    selected = new WebFunctionRole
                    {
                        TargetId = roleId,
                        FunctionId = functionId,
                        CreatedAt = now
                    };
                    dbContext.FunctionRoles.Add(selected);
                }

                selected.ActiveKey = request.ActiveKey;
                selected.Type = WebFunctionRoleType.Role;
                selected.Status = WebDataStatus.Active;
                selected.UpdatedAt = now;
                selected.UserId = currentUserId;
                foreach (var duplicate in rows.Where(item =>
                             item.FunctionRoleId != selected.FunctionRoleId &&
                             item.Status == WebDataStatus.Active))
                {
                    duplicate.Status = WebDataStatus.Inactive;
                    duplicate.UpdatedAt = now;
                    duplicate.UserId = currentUserId;
                }

                await dbContext.SaveChangesAsync(cancellationToken);
            },
            cancellationToken);
        return await GetByIdAsync(roleId, cancellationToken);
    }

    public async Task RemoveFunctionAsync(
        int roleId,
        int functionId,
        int currentUserId,
        CancellationToken cancellationToken)
    {
        await EnsureActiveRoleAsync(roleId, cancellationToken);
        await ValidateActiveFunctionsAsync([functionId], cancellationToken);
        await EnsureFunctionPermissionKeepsAdministrationAsync(
            roleId,
            functionId,
            ActiveKeyValue.None,
            cancellationToken);

        await AccessManagementSupport.ExecuteInTransactionAsync(
            dbContext,
            async () =>
            {
                var rows = await dbContext.FunctionRoles
                    .Where(item => item.TargetId == roleId &&
                                   item.FunctionId == functionId &&
                                   item.Type == WebFunctionRoleType.Role &&
                                   item.Status == WebDataStatus.Active)
                    .ToListAsync(cancellationToken);
                if (rows.Count == 0)
                {
                    throw new NotFoundException("Không tìm thấy quyền Function đang hiệu lực của vai trò.");
                }

                var now = DateTime.Now;
                foreach (var row in rows)
                {
                    row.Status = WebDataStatus.Inactive;
                    row.UpdatedAt = now;
                    row.UserId = currentUserId;
                }

                await dbContext.SaveChangesAsync(cancellationToken);
            },
            cancellationToken);
    }

    public async Task DeleteAsync(int id, int currentUserId, CancellationToken cancellationToken)
    {
        await EnsureAdministrationRemainsAsync(id, cancellationToken);
        await AccessManagementSupport.ExecuteInTransactionAsync(
            dbContext,
            async () =>
            {
                var role = await GetTrackedRoleAsync(id, cancellationToken);
                if (role.Status == WebDataStatus.Inactive)
                {
                    throw new ConflictException("Vai trò đã bị xóa mềm hoặc ngừng hiệu lực.");
                }

                var now = DateTime.Now;
                role.Status = WebDataStatus.Inactive;
                role.UpdatedAt = now;
                role.UserEditId = currentUserId;
                var userRoles = await dbContext.UserRoles
                    .Where(item => item.RoleId == id && item.Status == WebDataStatus.Active)
                    .ToListAsync(cancellationToken);
                foreach (var userRole in userRoles)
                {
                    userRole.Status = WebDataStatus.Inactive;
                }

                var functionRoles = await dbContext.FunctionRoles
                    .Where(item => item.TargetId == id &&
                                   item.Type == WebFunctionRoleType.Role &&
                                   item.Status == WebDataStatus.Active)
                    .ToListAsync(cancellationToken);
                foreach (var functionRole in functionRoles)
                {
                    functionRole.Status = WebDataStatus.Inactive;
                    functionRole.UpdatedAt = now;
                    functionRole.UserId = currentUserId;
                }

                await dbContext.SaveChangesAsync(cancellationToken);
            },
            cancellationToken);
    }

    private async Task<RoleResponse> BuildResponseAsync(WebRole role, CancellationToken cancellationToken)
    {
        var userCounts = await LoadUserCountsAsync([role.RoleId], cancellationToken);
        userCounts.TryGetValue(role.RoleId, out var userCount);
        var functionRows = await (
            from functionRole in dbContext.FunctionRoles.AsNoTracking()
            join function in dbContext.Functions.AsNoTracking()
                on functionRole.FunctionId equals function.FunctionId
            where functionRole.TargetId == role.RoleId &&
                  functionRole.Type == WebFunctionRoleType.Role &&
                  functionRole.Status == WebDataStatus.Active &&
                  function.Status == WebDataStatus.Active
            orderby function.Location, function.Name
            select new
            {
                FunctionRoleId = functionRole.FunctionRoleId,
                FunctionId = function.FunctionId,
                ParentFunctionId = function.FunctionParentId,
                function.Code,
                function.Name,
                function.Url,
                function.Location,
                function.Icon,
                functionRole.Type,
                functionRole.ActiveKey,
                functionRole.Status
            })
            .ToListAsync(cancellationToken);
        var functions = functionRows.Select(item =>
            new RoleFunctionResponse(
                item.FunctionRoleId,
                item.FunctionId,
                AccessManagementSupport.NormalizeParent(item.ParentFunctionId),
                item.Code,
                item.Name,
                item.Url,
                item.Location,
                item.Icon,
                item.Type,
                ActiveKeyValue.Normalize(item.ActiveKey),
                AccessManagementSupport.ToPermissions(item.ActiveKey),
                item.Status ?? WebDataStatus.Inactive,
                item.Status == WebDataStatus.Active)).ToList();
        var status = role.Status ?? WebDataStatus.Inactive;
        return new RoleResponse(
            role.RoleId,
            role.Code,
            role.Name,
            role.Note,
            AccessManagementSupport.ToUtc(role.CreatedAt),
            AccessManagementSupport.ToUtc(role.UpdatedAt),
            role.UserEditId,
            role.UserId,
            role.LevelRole,
            status,
            status == WebDataStatus.Active,
            userCount,
            functions);
    }

    private async Task<Dictionary<int, int>> LoadUserCountsAsync(
        IReadOnlyCollection<int> roleIds,
        CancellationToken cancellationToken)
    {
        if (roleIds.Count == 0)
        {
            return [];
        }

        var rows = await (
            from userRole in dbContext.UserRoles.AsNoTracking()
            join user in dbContext.Users.AsNoTracking() on userRole.UserId equals user.UserId
            where roleIds.Contains(userRole.RoleId) &&
                  userRole.Status == WebDataStatus.Active &&
                  user.Status == WebDataStatus.Active
            select new { userRole.RoleId, userRole.UserId })
            .Distinct()
            .ToListAsync(cancellationToken);
        return rows.GroupBy(row => row.RoleId).ToDictionary(group => group.Key, group => group.Count());
    }

    private async Task ValidateActiveFunctionsAsync(
        IReadOnlyCollection<int> functionIds,
        CancellationToken cancellationToken)
    {
        if (functionIds.Count == 0)
        {
            return;
        }

        if (functionIds.Any(id => id <= 0))
        {
            throw new ValidationException("FunctionId không hợp lệ.");
        }

        var existingIds = await dbContext.Functions.AsNoTracking()
            .Where(function => functionIds.Contains(function.FunctionId) && function.Status == WebDataStatus.Active)
            .Select(function => function.FunctionId)
            .ToListAsync(cancellationToken);
        var missing = functionIds.Except(existingIds).ToArray();
        if (missing.Length > 0)
        {
            throw new ValidationException($"Function không tồn tại hoặc đã ngừng hiệu lực: {string.Join(", ", missing)}.");
        }
    }

    private async Task EnsureMatrixKeepsAdministrationAsync(
        int roleId,
        IReadOnlyCollection<RoleFunctionAssignmentRequest> assignments,
        CancellationToken cancellationToken)
    {
        var managementFunctionId = await dbContext.Functions.AsNoTracking()
            .Where(function => function.Code == ManagementFunctionCodes.Roles &&
                               function.Status == WebDataStatus.Active)
            .Select(function => (int?)function.FunctionId)
            .SingleOrDefaultAsync(cancellationToken);
        if (!managementFunctionId.HasValue)
        {
            return;
        }

        var assignment = assignments.SingleOrDefault(item => item.FunctionId == managementFunctionId.Value);
        if (assignment is null || !ActiveKeyValue.Allows(assignment.ActiveKey, ActiveKeyPermission.Update))
        {
            await EnsureAdministrationRemainsAsync(roleId, cancellationToken);
        }
    }

    private async Task EnsureFunctionPermissionKeepsAdministrationAsync(
        int roleId,
        int functionId,
        string activeKey,
        CancellationToken cancellationToken)
    {
        if (ActiveKeyValue.Allows(activeKey, ActiveKeyPermission.Update))
        {
            return;
        }

        var isRoleManagementFunction = await dbContext.Functions.AsNoTracking().AnyAsync(
            function => function.FunctionId == functionId &&
                        function.Code == ManagementFunctionCodes.Roles &&
                        function.Status == WebDataStatus.Active,
            cancellationToken);
        if (isRoleManagementFunction)
        {
            await EnsureAdministrationRemainsAsync(roleId, cancellationToken);
        }
    }

    private async Task EnsureAdministrationRemainsAsync(int roleId, CancellationToken cancellationToken)
    {
        var targetKeys = await (
            from functionRole in dbContext.FunctionRoles.AsNoTracking()
            join function in dbContext.Functions.AsNoTracking()
                on functionRole.FunctionId equals function.FunctionId
            where functionRole.TargetId == roleId &&
                  functionRole.Type == WebFunctionRoleType.Role &&
                  functionRole.Status == WebDataStatus.Active &&
                  function.Status == WebDataStatus.Active &&
                  function.Code == ManagementFunctionCodes.Roles
            select functionRole.ActiveKey)
            .ToListAsync(cancellationToken);
        if (!targetKeys.Any(key => ActiveKeyValue.Allows(key, ActiveKeyPermission.Update)))
        {
            return;
        }

        var otherKeys = await (
            from user in dbContext.Users.AsNoTracking()
            join userRole in dbContext.UserRoles.AsNoTracking() on user.UserId equals userRole.UserId
            join role in dbContext.Roles.AsNoTracking() on userRole.RoleId equals role.RoleId
            join functionRole in dbContext.FunctionRoles.AsNoTracking()
                on role.RoleId equals functionRole.TargetId
            join function in dbContext.Functions.AsNoTracking()
                on functionRole.FunctionId equals function.FunctionId
            where user.Status == WebDataStatus.Active &&
                  userRole.Status == WebDataStatus.Active &&
                  role.Status == WebDataStatus.Active &&
                  role.RoleId != roleId &&
                  functionRole.Type == WebFunctionRoleType.Role &&
                  functionRole.Status == WebDataStatus.Active &&
                  function.Status == WebDataStatus.Active &&
                  function.Code == ManagementFunctionCodes.Roles
            select functionRole.ActiveKey)
            .ToListAsync(cancellationToken);
        if (!otherKeys.Any(key => ActiveKeyValue.Allows(key, ActiveKeyPermission.Update)))
        {
            throw new ConflictException("Không thể ngừng vai trò quản trị cuối cùng của hệ thống.");
        }
    }

    private async Task EnsureUniqueAsync(
        string code,
        string name,
        int? currentId,
        CancellationToken cancellationToken)
    {
        var duplicateCode = await dbContext.Roles.AsNoTracking().AnyAsync(
            role => role.Code == code &&
                    role.Status == WebDataStatus.Active &&
                    (!currentId.HasValue || role.RoleId != currentId.Value),
            cancellationToken);
        if (duplicateCode)
        {
            throw new ConflictException("Mã vai trò đang được sử dụng.");
        }

        var duplicateName = await dbContext.Roles.AsNoTracking().AnyAsync(
            role => role.Name == name &&
                    role.Status == WebDataStatus.Active &&
                    (!currentId.HasValue || role.RoleId != currentId.Value),
            cancellationToken);
        if (duplicateName)
        {
            throw new ConflictException("Tên vai trò đang được sử dụng.");
        }
    }

    private async Task<WebRole> GetTrackedRoleAsync(int id, CancellationToken cancellationToken) =>
        await dbContext.Roles.SingleOrDefaultAsync(role => role.RoleId == id, cancellationToken)
        ?? throw new NotFoundException("Không tìm thấy vai trò.");

    private async Task EnsureActiveRoleAsync(int id, CancellationToken cancellationToken)
    {
        if (!await dbContext.Roles.AsNoTracking().AnyAsync(
            role => role.RoleId == id && role.Status == WebDataStatus.Active,
            cancellationToken))
        {
            throw new NotFoundException("Không tìm thấy vai trò đang hiệu lực.");
        }
    }

    private async Task EnsureRoleExistsAsync(int id, CancellationToken cancellationToken)
    {
        if (!await dbContext.Roles.AsNoTracking().AnyAsync(role => role.RoleId == id, cancellationToken))
        {
            throw new NotFoundException("Không tìm thấy vai trò.");
        }
    }

    private static void ValidateActiveKey(string activeKey)
    {
        if (!ActiveKeyValue.IsValid(activeKey))
        {
            throw new ValidationException("ActiveKey phải gồm đúng 9 ký tự 0 hoặc 1.");
        }
    }

    private static string RequireValue(string value, string errorMessage)
    {
        var trimmed = value.Trim();
        return trimmed.Length > 0 ? trimmed : throw new ValidationException(errorMessage);
    }
}
