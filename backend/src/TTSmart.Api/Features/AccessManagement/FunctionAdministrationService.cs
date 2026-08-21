using System.ComponentModel.DataAnnotations;
using TTSmart.Api.Common.Exceptions;
using TTSmart.Api.Data.WebAuth;
using TTSmart.Api.Features.Authorization;
using Microsoft.EntityFrameworkCore;

namespace TTSmart.Api.Features.AccessManagement;

public sealed class FunctionAdministrationService(WebAuthDbContext dbContext) : IFunctionAdministrationService
{
    public async Task<IReadOnlyList<FunctionResponse>> GetListAsync(
        FunctionListQuery query,
        CancellationToken cancellationToken)
    {
        var status = AccessManagementSupport.ResolveStatusFilter(query.Status);
        var functionsQuery = dbContext.Functions.AsNoTracking()
            .Where(function => function.Status == status);
        var search = AccessManagementSupport.TrimOrNull(query.Search);
        if (search is not null)
        {
            functionsQuery = functionsQuery.Where(function =>
                function.Code.Contains(search) ||
                function.Name.Contains(search) ||
                (function.Url != null && function.Url.Contains(search)));
        }

        var functions = await functionsQuery
            .OrderBy(function => function.Location)
            .ThenBy(function => function.FunctionParentId)
            .ThenBy(function => function.Name)
            .ThenBy(function => function.FunctionId)
            .ToListAsync(cancellationToken);
        return await BuildResponsesAsync(functions, cancellationToken);
    }

    public async Task<IReadOnlyList<FunctionTreeNodeResponse>> GetTreeAsync(
        FunctionListQuery query,
        CancellationToken cancellationToken)
    {
        var functions = await GetListAsync(query, cancellationToken);
        var functionIds = functions.Select(item => item.Id).ToHashSet();
        var childrenByParent = functions
            .Where(item => item.ParentFunctionId.HasValue && functionIds.Contains(item.ParentFunctionId.Value))
            .ToLookup(item => item.ParentFunctionId!.Value);
        var emitted = new HashSet<int>();

        FunctionTreeNodeResponse BuildNode(FunctionResponse function, HashSet<int> path)
        {
            path.Add(function.Id);
            var children = childrenByParent[function.Id]
                .Where(child => !path.Contains(child.Id))
                .Select(child => BuildNode(child, new HashSet<int>(path)))
                .ToList();
            emitted.Add(function.Id);
            return new FunctionTreeNodeResponse(
                function.Id,
                function.ParentFunctionId,
                function.Code,
                function.Name,
                function.Url,
                function.Note,
                function.Location,
                function.Icon,
                function.Status,
                function.IsActive,
                function.AssignedRoleCount,
                function.GrantedRoleCount,
                children);
        }

        var roots = functions
            .Where(item => !item.ParentFunctionId.HasValue || !functionIds.Contains(item.ParentFunctionId.Value))
            .Select(item => BuildNode(item, []))
            .ToList();
        foreach (var function in functions.Where(item => !emitted.Contains(item.Id)))
        {
            roots.Add(BuildNode(function, []));
        }

        return roots;
    }

    public async Task<FunctionResponse> GetByIdAsync(int id, CancellationToken cancellationToken)
    {
        var function = await dbContext.Functions.AsNoTracking()
            .SingleOrDefaultAsync(item => item.FunctionId == id, cancellationToken)
            ?? throw new NotFoundException("Không tìm thấy function.");
        var responses = await BuildResponsesAsync([function], cancellationToken);
        return responses[0];
    }

    public async Task<FunctionResponse> CreateAsync(
        CreateFunctionRequest request,
        int currentUserId,
        CancellationToken cancellationToken)
    {
        var code = RequireValue(request.Code, "Mã function là bắt buộc.");
        var name = RequireValue(request.Name, "Tên function là bắt buộc.");
        if (ManagementFunctionCodes.IsReserved(code))
        {
            throw new ConflictException("Mã function quản trị hệ thống chỉ được sử dụng bởi dữ liệu chuẩn hiện có.");
        }

        await EnsureUniqueAsync(code, name, null, cancellationToken);
        await ValidateParentAsync(null, request.ParentFunctionId, cancellationToken);
        var now = DateTime.Now;
        var function = new WebFunction
        {
            Code = code,
            Name = name,
            FunctionParentId = request.ParentFunctionId ?? 0,
            Url = AccessManagementSupport.TrimOrNull(request.Url),
            Note = AccessManagementSupport.TrimOrNull(request.Note),
            Location = request.Location,
            Icon = AccessManagementSupport.TrimOrNull(request.Icon),
            CreatedAt = now,
            UpdatedAt = now,
            UserId = currentUserId,
            Status = WebDataStatus.Active
        };
        dbContext.Functions.Add(function);
        await dbContext.SaveChangesAsync(cancellationToken);
        return await GetByIdAsync(function.FunctionId, cancellationToken);
    }

    public async Task<FunctionResponse> UpdateAsync(
        int id,
        UpdateFunctionRequest request,
        int currentUserId,
        CancellationToken cancellationToken)
    {
        var code = RequireValue(request.Code, "Mã function là bắt buộc.");
        var name = RequireValue(request.Name, "Tên function là bắt buộc.");
        await EnsureUniqueAsync(code, name, id, cancellationToken);
        await ValidateParentAsync(id, request.ParentFunctionId, cancellationToken);
        var function = await GetTrackedFunctionAsync(id, cancellationToken);
        if (ManagementFunctionCodes.IsReserved(function.Code) && function.Code != code)
        {
            throw new ConflictException("Không thể thay đổi mã function quản trị hệ thống.");
        }

        if (!ManagementFunctionCodes.IsReserved(function.Code) && ManagementFunctionCodes.IsReserved(code))
        {
            throw new ConflictException("Không thể sử dụng mã function quản trị hệ thống cho function khác.");
        }

        function.Code = code;
        function.Name = name;
        function.FunctionParentId = request.ParentFunctionId ?? 0;
        function.Url = AccessManagementSupport.TrimOrNull(request.Url);
        function.Note = AccessManagementSupport.TrimOrNull(request.Note);
        function.Location = request.Location;
        function.Icon = AccessManagementSupport.TrimOrNull(request.Icon);
        function.UpdatedAt = DateTime.Now;
        function.UserId = currentUserId;
        await dbContext.SaveChangesAsync(cancellationToken);
        return await GetByIdAsync(id, cancellationToken);
    }

    public async Task<FunctionResponse> SetStatusAsync(
        int id,
        int currentUserId,
        SetFunctionStatusRequest request,
        CancellationToken cancellationToken)
    {
        var isActive = AccessManagementSupport.RequireIsActive(request.IsActive);
        var function = await GetTrackedFunctionAsync(id, cancellationToken);
        if (!isActive && ManagementFunctionCodes.IsReserved(function.Code))
        {
            throw new ConflictException("Không thể ngừng hiệu lực function quản trị hệ thống.");
        }

        if (!isActive && function.Status == WebDataStatus.Active)
        {
            var hasActiveChildren = await dbContext.Functions.AsNoTracking().AnyAsync(
                item => item.FunctionParentId == id && item.Status == WebDataStatus.Active,
                cancellationToken);
            if (hasActiveChildren)
            {
                throw new ConflictException("Không thể ngừng function đang có function con hiệu lực.");
            }
        }

        function.Status = isActive ? WebDataStatus.Active : WebDataStatus.Inactive;
        function.UpdatedAt = DateTime.Now;
        function.UserId = currentUserId;
        await dbContext.SaveChangesAsync(cancellationToken);
        return await GetByIdAsync(id, cancellationToken);
    }

    public async Task DeleteAsync(int id, int currentUserId, CancellationToken cancellationToken)
    {
        await AccessManagementSupport.ExecuteInTransactionAsync(
            dbContext,
            async () =>
            {
                var function = await GetTrackedFunctionAsync(id, cancellationToken);
                if (ManagementFunctionCodes.IsReserved(function.Code))
                {
                    throw new ConflictException("Không thể xóa function quản trị hệ thống.");
                }

                if (function.Status == WebDataStatus.Inactive)
                {
                    throw new ConflictException("Function đã bị xóa mềm hoặc ngừng hiệu lực.");
                }

                var now = DateTime.Now;
                function.Status = WebDataStatus.Inactive;
                function.UpdatedAt = now;
                function.UserId = currentUserId;
                var assignments = await dbContext.FunctionRoles
                    .Where(item => item.FunctionId == id)
                    .ToListAsync(cancellationToken);
                dbContext.FunctionRoles.RemoveRange(assignments);

                var children = await dbContext.Functions
                    .Where(item => item.FunctionParentId == id && item.Status == WebDataStatus.Active)
                    .ToListAsync(cancellationToken);
                foreach (var child in children)
                {
                    child.FunctionParentId = 0;
                    child.UpdatedAt = now;
                    child.UserId = currentUserId;
                }

                await dbContext.SaveChangesAsync(cancellationToken);
            },
            cancellationToken);
    }

    private async Task<IReadOnlyList<FunctionResponse>> BuildResponsesAsync(
        IReadOnlyCollection<WebFunction> functions,
        CancellationToken cancellationToken)
    {
        var ids = functions.Select(function => function.FunctionId).ToArray();
        var childCounts = await dbContext.Functions.AsNoTracking()
            .Where(function => function.FunctionParentId != 0 && ids.Contains(function.FunctionParentId))
            .GroupBy(function => function.FunctionParentId)
            .Select(group => new { ParentId = group.Key, Count = group.Count() })
            .ToDictionaryAsync(item => item.ParentId, item => item.Count, cancellationToken);
        var assignments = await (
            from functionRole in dbContext.FunctionRoles.AsNoTracking()
            join role in dbContext.Roles.AsNoTracking()
                on functionRole.TargetId equals role.RoleId
            where ids.Contains(functionRole.FunctionId) &&
                  functionRole.Type == WebFunctionRoleType.Role &&
                  functionRole.Status == WebDataStatus.Active &&
                  role.Status == WebDataStatus.Active
            select new { functionRole.FunctionId, functionRole.TargetId, functionRole.ActiveKey })
            .ToListAsync(cancellationToken);
        return functions.Select(function =>
        {
            childCounts.TryGetValue(function.FunctionId, out var childCount);
            var functionAssignments = assignments.Where(item => item.FunctionId == function.FunctionId).ToList();
            var status = function.Status ?? WebDataStatus.Inactive;
            return new FunctionResponse(
                function.FunctionId,
                AccessManagementSupport.NormalizeParent(function.FunctionParentId),
                function.Code,
                function.Name,
                function.Url,
                function.Note,
                function.Location,
                function.Icon,
                AccessManagementSupport.ToUtc(function.CreatedAt),
                AccessManagementSupport.ToUtc(function.UpdatedAt),
                function.UserId,
                status,
                status == WebDataStatus.Active,
                childCount,
                functionAssignments.Select(item => item.TargetId).Distinct().Count(),
                functionAssignments.Where(item => ActiveKeyValue.HasAnyPermission(item.ActiveKey))
                    .Select(item => item.TargetId).Distinct().Count());
        }).ToList();
    }

    private async Task ValidateParentAsync(
        int? currentId,
        int? parentId,
        CancellationToken cancellationToken)
    {
        if (!parentId.HasValue || parentId.Value == 0)
        {
            return;
        }

        if (currentId.HasValue && parentId.Value == currentId.Value)
        {
            throw new ValidationException("Function không thể là cha của chính nó.");
        }

        var parentExists = await dbContext.Functions.AsNoTracking().AnyAsync(
            function => function.FunctionId == parentId.Value && function.Status == WebDataStatus.Active,
            cancellationToken);
        if (!parentExists)
        {
            throw new ValidationException("Function cha không tồn tại hoặc đã ngừng hiệu lực.");
        }

        if (!currentId.HasValue)
        {
            return;
        }

        var parentMap = await dbContext.Functions.AsNoTracking()
            .Select(function => new { function.FunctionId, function.FunctionParentId })
            .ToDictionaryAsync(item => item.FunctionId, item => item.FunctionParentId, cancellationToken);
        var visited = new HashSet<int>();
        var cursor = parentId;
        while (cursor.HasValue && cursor.Value != 0)
        {
            if (cursor.Value == currentId.Value || !visited.Add(cursor.Value))
            {
                throw new ConflictException("Cấu trúc function không được tạo vòng lặp.");
            }

            cursor = parentMap.TryGetValue(cursor.Value, out var nextParent) ? nextParent : null;
        }
    }

    private async Task EnsureUniqueAsync(
        string code,
        string name,
        int? currentId,
        CancellationToken cancellationToken)
    {
        if (await dbContext.Functions.AsNoTracking().AnyAsync(
            function => function.Code == code &&
                       function.Status == WebDataStatus.Active &&
                       (!currentId.HasValue || function.FunctionId != currentId.Value),
            cancellationToken))
        {
            throw new ConflictException("Mã function đang được sử dụng.");
        }

    }

    private async Task<WebFunction> GetTrackedFunctionAsync(int id, CancellationToken cancellationToken) =>
        await dbContext.Functions.SingleOrDefaultAsync(function => function.FunctionId == id, cancellationToken)
        ?? throw new NotFoundException("Không tìm thấy function.");

    private static string RequireValue(string value, string errorMessage)
    {
        var trimmed = value.Trim();
        return trimmed.Length > 0 ? trimmed : throw new ValidationException(errorMessage);
    }
}
