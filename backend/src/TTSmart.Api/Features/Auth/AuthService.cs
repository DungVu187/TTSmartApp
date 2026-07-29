using System.ComponentModel.DataAnnotations;
using TTSmart.Api.Common.Exceptions;
using TTSmart.Api.Common.Security;
using TTSmart.Api.Common.Time;
using TTSmart.Api.Data.WebAuth;
using TTSmart.Api.Features.Authorization;
using TTSmart.Api.Features.CompanyManagement;
using Microsoft.EntityFrameworkCore;

namespace TTSmart.Api.Features.Auth;

public sealed class AuthService(
    WebAuthDbContext dbContext,
    IDatabasePasswordService passwordService,
    IJwtTokenService jwtTokenService,
    ICompanyAccessEvaluator? companyAccessEvaluator = null) : IAuthService
{
    private const string InvalidCredentialsMessage = "Tên đăng nhập hoặc mật khẩu không đúng.";

    public async Task<LoginResponse> LoginAsync(LoginRequest request, CancellationToken cancellationToken)
    {
        var userName = request.UserName.Trim();
        var users = await dbContext.Users.AsNoTracking()
            .Where(user => user.Status == WebDataStatus.Active && user.UserName == userName)
            .OrderBy(user => user.UserId)
            .Take(2)
            .ToListAsync(cancellationToken);

        if (users.Count != 1 || !passwordService.Verify(users[0], request.Password))
        {
            throw new UnauthorizedException(InvalidCredentialsMessage);
        }

        await EnsureCompanyAccessAsync(users[0], cancellationToken);
        var currentUser = await BuildCurrentUserAsync(users[0], cancellationToken);
        var token = jwtTokenService.CreateToken(currentUser, VietnamTime.ToUtc(users[0].TokenSince));
        return new LoginResponse(
            token.AccessToken,
            token.ExpiresAtUtc,
            currentUser.User,
            currentUser.Roles,
            currentUser.Functions,
            currentUser.RoleFunctions);
    }

    public async Task<CurrentUserResponse> GetCurrentUserAsync(int userId, CancellationToken cancellationToken)
    {
        var user = await dbContext.Users.AsNoTracking()
            .SingleOrDefaultAsync(item => item.UserId == userId && item.Status == WebDataStatus.Active, cancellationToken);
        if (user is null)
        {
            throw new UnauthorizedException("Phiên đăng nhập không còn hợp lệ.");
        }

        await EnsureCompanyAccessAsync(user, cancellationToken);
        return await BuildCurrentUserAsync(user, cancellationToken);
    }

    public async Task LogoutAsync(
        int userId,
        DateTime tokenIssuedAtUtc,
        CancellationToken cancellationToken)
    {
        var user = await dbContext.Users.SingleOrDefaultAsync(
            item => item.UserId == userId && item.Status == WebDataStatus.Active,
            cancellationToken);
        if (user is null)
        {
            throw new UnauthorizedException("Phiên đăng nhập không còn hợp lệ.");
        }

        var now = VietnamTime.Now;
        user.TokenSince = ResolveSessionRevocationTime(now, tokenIssuedAtUtc);
        user.UpdatedAt = now;
        user.UserEditId = userId;
        await dbContext.SaveChangesAsync(cancellationToken);
    }

    public async Task ChangePasswordAsync(
        int userId,
        DateTime tokenIssuedAtUtc,
        ChangePasswordRequest request,
        CancellationToken cancellationToken)
    {
        var user = await dbContext.Users.SingleOrDefaultAsync(
            item => item.UserId == userId && item.Status == WebDataStatus.Active,
            cancellationToken);
        if (user is null)
        {
            throw new UnauthorizedException("Phiên đăng nhập không còn hợp lệ.");
        }

        await EnsureCompanyAccessAsync(user, cancellationToken);
        if (!passwordService.Verify(user, request.CurrentPassword))
        {
            throw new ValidationException("Mật khẩu hiện tại không đúng.");
        }

        if (request.CurrentPassword == request.NewPassword)
        {
            throw new ValidationException("Mật khẩu mới phải khác mật khẩu hiện tại.");
        }

        PasswordPolicy.Validate(request.NewPassword);
        user.Password = passwordService.HashForStorage(user, request.NewPassword);
        var now = VietnamTime.Now;
        user.TokenSince = ResolveSessionRevocationTime(now, tokenIssuedAtUtc);
        user.UpdatedAt = now;
        user.UserEditId = userId;
        await dbContext.SaveChangesAsync(cancellationToken);
    }

    private static DateTime ResolveSessionRevocationTime(DateTime now, DateTime tokenIssuedAtUtc)
    {
        var tokenIssuedAt = VietnamTime.FromUtc(tokenIssuedAtUtc);
        return tokenIssuedAt > now ? tokenIssuedAt : now;
    }

    private async Task EnsureCompanyAccessAsync(WebUser user, CancellationToken cancellationToken)
    {
        if (companyAccessEvaluator is null)
        {
            return;
        }

        var decision = await companyAccessEvaluator.EvaluateAsync(user, cancellationToken);
        if (!decision.IsAllowed)
        {
            throw new UnauthorizedException(
                decision.Message ?? "Công ty không được phép sử dụng dịch vụ.");
        }
    }

    internal static IQueryable<WebRole> BuildRoleQuery(WebAuthDbContext dbContext, int userId) =>
        (from userRole in dbContext.UserRoles.AsNoTracking()
         join role in dbContext.Roles.AsNoTracking() on userRole.RoleId equals role.RoleId
         where userRole.UserId == userId &&
               userRole.Status == WebDataStatus.Active &&
               role.Status == WebDataStatus.Active
         select role)
        .Distinct()
        .OrderBy(role => role.Name)
        .ThenBy(role => role.RoleId);

    private async Task<CurrentUserResponse> BuildCurrentUserAsync(
        WebUser user,
        CancellationToken cancellationToken)
    {
        var roleRows = await BuildRoleQuery(dbContext, user.UserId)
            .ToListAsync(cancellationToken);
        var roles = roleRows
            .Select(role => new AuthRoleResponse(role.RoleId, role.Code, role.Name, role.LevelRole))
            .ToList();

        var rows = await (
            from userRole in dbContext.UserRoles.AsNoTracking()
            join role in dbContext.Roles.AsNoTracking() on userRole.RoleId equals role.RoleId
            join functionRole in dbContext.FunctionRoles.AsNoTracking()
                on userRole.RoleId equals functionRole.TargetId
            join function in dbContext.Functions.AsNoTracking()
                on functionRole.FunctionId equals function.FunctionId
            where userRole.UserId == user.UserId &&
                  userRole.Status == WebDataStatus.Active &&
                  role.Status == WebDataStatus.Active &&
                  functionRole.Type == WebFunctionRoleType.Role &&
                  functionRole.Status == WebDataStatus.Active &&
                  function.Status == WebDataStatus.Active
            select new FunctionAccessRow(
                role.RoleId,
                role.Code,
                role.Name,
                functionRole.FunctionRoleId,
                function.FunctionId,
                function.FunctionParentId,
                function.Code,
                function.Name,
                function.Url,
                function.Location,
                function.Icon,
                functionRole.Type,
                functionRole.ActiveKey))
            .ToListAsync(cancellationToken);
        var functionDefinitions = await dbContext.Functions.AsNoTracking()
            .Where(function => function.Status == WebDataStatus.Active)
            .Select(function => new FunctionDefinition(
                function.FunctionId,
                function.FunctionParentId,
                function.Code,
                function.Name,
                function.Url,
                function.Location,
                function.Icon))
            .ToListAsync(cancellationToken);

        var roleFunctions = rows
            .Select(row => new AuthRoleFunctionResponse(
                row.RoleId,
                row.RoleCode,
                row.RoleName,
                row.FunctionRoleId,
                row.FunctionId,
                NormalizeParent(row.ParentFunctionId),
                row.FunctionCode,
                row.FunctionName,
                row.Url,
                row.Type,
                ActiveKeyValue.Normalize(row.ActiveKey),
                ToPermissions(row.ActiveKey)))
            .OrderBy(item => item.RoleName)
            .ThenBy(item => item.FunctionName)
            .ToList();

        var activeKeysByFunction = rows
            .GroupBy(row => row.FunctionId)
            .ToDictionary(
                group => group.Key,
                group => ActiveKeyValue.Merge(group.Select(row => row.ActiveKey)));
        var definitionsById = functionDefinitions.ToDictionary(item => item.FunctionId);
        var visibleFunctionIds = activeKeysByFunction
            .Where(item => ActiveKeyValue.HasAnyPermission(item.Value))
            .Select(item => item.Key)
            .ToHashSet();
        var pendingAncestors = new Queue<int>(visibleFunctionIds);
        while (pendingAncestors.TryDequeue(out var functionId))
        {
            if (!definitionsById.TryGetValue(functionId, out var definition) ||
                definition.ParentFunctionId == 0 ||
                !visibleFunctionIds.Add(definition.ParentFunctionId))
            {
                continue;
            }

            pendingAncestors.Enqueue(definition.ParentFunctionId);
        }

        var functions = functionDefinitions
            .Where(item => visibleFunctionIds.Contains(item.FunctionId))
            .Select(item =>
            {
                var activeKey = activeKeysByFunction.GetValueOrDefault(item.FunctionId, ActiveKeyValue.None);
                return new AuthFunctionResponse(
                    item.FunctionId,
                    NormalizeParent(item.ParentFunctionId),
                    item.Code,
                    item.Name,
                    item.Url,
                    item.Location,
                    item.Icon,
                    activeKey,
                    ToPermissions(activeKey));
            })
            .OrderBy(item => item.Location)
            .ThenBy(item => item.Name)
            .ToList();

        return new CurrentUserResponse(
            new AuthUserResponse(
                user.UserId,
                user.UserName,
                user.FullName,
                user.Email,
                user.Code,
                user.Phone,
                user.CompanyId,
                user.DepartmentId,
                user.PositionId,
                user.UnitId,
                user.BranchId,
                user.Status ?? WebDataStatus.Active),
            roles,
            functions,
            roleFunctions);
    }

    private static AuthPermissionResponse ToPermissions(string? activeKey)
    {
        var key = ActiveKeyValue.Normalize(activeKey);
        return new AuthPermissionResponse(
            ActiveKeyValue.Allows(key, ActiveKeyPermission.View),
            ActiveKeyValue.Allows(key, ActiveKeyPermission.Create),
            ActiveKeyValue.Allows(key, ActiveKeyPermission.Update),
            ActiveKeyValue.Allows(key, ActiveKeyPermission.Delete),
            ActiveKeyValue.Allows(key, ActiveKeyPermission.Import),
            ActiveKeyValue.Allows(key, ActiveKeyPermission.Export),
            ActiveKeyValue.Allows(key, ActiveKeyPermission.Print),
            ActiveKeyValue.Allows(key, ActiveKeyPermission.Other),
            ActiveKeyValue.Allows(key, ActiveKeyPermission.DSach),
            ActiveKeyValue.IsFull(key));
    }

    private static int? NormalizeParent(int? parentId) => parentId is null or 0 ? null : parentId;

    private sealed record FunctionAccessRow(
        int RoleId,
        string RoleCode,
        string RoleName,
        int FunctionRoleId,
        int FunctionId,
        int ParentFunctionId,
        string FunctionCode,
        string FunctionName,
        string? Url,
        int? Location,
        string? Icon,
        byte? Type,
        string? ActiveKey);

    private sealed record FunctionDefinition(
        int FunctionId,
        int ParentFunctionId,
        string Code,
        string Name,
        string? Url,
        int? Location,
        string? Icon);
}
