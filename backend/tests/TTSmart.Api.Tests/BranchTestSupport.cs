using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Security.Cryptography;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using TTSmart.Api.Data.Company;
using TTSmart.Api.Data.WebAuth;
using TTSmart.Api.Features.Auth;
using TTSmart.Api.Features.Authorization;

namespace TTSmart.Api.Tests;

internal static class BranchTestSupport
{
    public static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    public static async Task LoginAsync(HttpClient client, BranchTestIdentity identity)
    {
        var response = await client.PostAsJsonAsync("/api/auth/login", new LoginRequest
        {
            UserName = identity.UserName,
            Password = identity.Password
        });
        response.EnsureSuccessStatusCode();
        var login = await response.Content.ReadFromJsonAsync<LoginResponse>(JsonOptions)
            ?? throw new InvalidOperationException("Không nhận được JWT.");
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", login.AccessToken);
    }

    public static async Task<BranchTestIdentity> SeedIdentityAsync(
        IServiceProvider services,
        WebAuthDbContext dbContext,
        string roleCode,
        int? companyId,
        string? branchIds,
        params ActiveKeyPermission[] permissions)
    {
        var passwordService = services.GetRequiredService<IDatabasePasswordService>();
        var userName = $"branch_http_{Guid.NewGuid():N}";
        const string password = "Test123@#";
        var user = new WebUser
        {
            UserName = userName,
            Password = DatabasePasswordService.PendingPasswordHash,
            FullName = "Người dùng kiểm thử Branch",
            KeyLock = Convert.ToHexString(RandomNumberGenerator.GetBytes(10)),
            RegEmail = $"{userName}@example.test",
            CompanyId = companyId,
            BranchId = branchIds,
            Status = WebDataStatus.Active
        };
        var role = new WebRole
        {
            Code = roleCode,
            Name = $"Role {roleCode}",
            Status = WebDataStatus.Active
        };
        dbContext.Users.Add(user);
        dbContext.Roles.Add(role);

        WebFunction? function = null;
        if (permissions.Length > 0)
        {
            function = await dbContext.Functions.SingleOrDefaultAsync(
                item => item.Code == ManagementFunctionCodes.Branches);
            if (function is null)
            {
                function = new WebFunction
                {
                    Code = ManagementFunctionCodes.Branches,
                    Name = "Quản lý trạm",
                    FunctionParentId = 0,
                    Status = WebDataStatus.Active
                };
                dbContext.Functions.Add(function);
            }
        }

        await dbContext.SaveChangesAsync();
        user.Password = passwordService.HashForStorage(user, password);
        dbContext.UserRoles.Add(new WebUserRole
        {
            UserId = user.UserId,
            RoleId = role.RoleId,
            Status = WebDataStatus.Active
        });
        if (function is not null)
        {
            var activeKey = permissions.Aggregate(
                ActiveKeyValue.None,
                (current, permission) => ActiveKeyValue.Set(current, permission, true));
            dbContext.FunctionRoles.Add(new WebFunctionRole
            {
                TargetId = role.RoleId,
                FunctionId = function.FunctionId,
                Type = WebFunctionRoleType.Role,
                ActiveKey = activeKey,
                Status = WebDataStatus.Active
            });
        }

        await dbContext.SaveChangesAsync();
        return new BranchTestIdentity(userName, password);
    }

    public static async Task<BranchTestIdentity> SeedOrderReportIdentityAsync(
        IServiceProvider services,
        WebAuthDbContext dbContext,
        string roleCode,
        int? companyId,
        string? branchIds,
        params ActiveKeyPermission[] permissions)
    {
        var identity = await SeedIdentityAsync(
            services,
            dbContext,
            roleCode,
            companyId,
            branchIds);
        var user = await dbContext.Users.SingleAsync(item => item.UserName == identity.UserName);
        var userRole = await dbContext.UserRoles.SingleAsync(item => item.UserId == user.UserId);
        var function = new WebFunction
        {
            Code = OperationalFunctionCodes.OrderReports,
            Name = "Báo cáo đơn hàng",
            FunctionParentId = 0,
            Status = WebDataStatus.Active
        };
        dbContext.Functions.Add(function);
        await dbContext.SaveChangesAsync();
        dbContext.FunctionRoles.Add(new WebFunctionRole
        {
            TargetId = userRole.RoleId,
            FunctionId = function.FunctionId,
            Type = WebFunctionRoleType.Role,
            ActiveKey = permissions.Aggregate(
                ActiveKeyValue.None,
                (current, permission) => ActiveKeyValue.Set(current, permission, true)),
            Status = WebDataStatus.Active
        });
        await dbContext.SaveChangesAsync();
        return identity;
    }

    public static async Task<BranchTestIdentity> SeedOrderStatisticsIdentityAsync(
        IServiceProvider services,
        WebAuthDbContext dbContext,
        string roleCode,
        int? companyId,
        string? branchIds,
        params ActiveKeyPermission[] permissions)
    {
        var identity = await SeedIdentityAsync(
            services,
            dbContext,
            roleCode,
            companyId,
            branchIds);
        var user = await dbContext.Users.SingleAsync(item => item.UserName == identity.UserName);
        var userRole = await dbContext.UserRoles.SingleAsync(item => item.UserId == user.UserId);
        var function = new WebFunction
        {
            Code = OperationalFunctionCodes.OrderStatistics,
            Name = "Thống kê đơn hàng",
            FunctionParentId = 0,
            Status = WebDataStatus.Active
        };
        dbContext.Functions.Add(function);
        await dbContext.SaveChangesAsync();
        dbContext.FunctionRoles.Add(new WebFunctionRole
        {
            TargetId = userRole.RoleId,
            FunctionId = function.FunctionId,
            Type = WebFunctionRoleType.Role,
            ActiveKey = permissions.Aggregate(
                ActiveKeyValue.None,
                (current, permission) => ActiveKeyValue.Set(current, permission, true)),
            Status = WebDataStatus.Active
        });
        await dbContext.SaveChangesAsync();
        return identity;
    }

    public static async Task<BranchTestIdentity> SeedMixDesignIdentityAsync(
        IServiceProvider services,
        WebAuthDbContext dbContext,
        string roleCode,
        int? companyId,
        string? branchIds,
        params ActiveKeyPermission[] permissions)
    {
        var identity = await SeedIdentityAsync(
            services,
            dbContext,
            roleCode,
            companyId,
            branchIds);
        var user = await dbContext.Users.SingleAsync(item => item.UserName == identity.UserName);
        var userRole = await dbContext.UserRoles.SingleAsync(item => item.UserId == user.UserId);
        var function = new WebFunction
        {
            Code = OperationalFunctionCodes.MixDesigns,
            Name = "Quản lý cấp phối",
            FunctionParentId = 0,
            Status = WebDataStatus.Active
        };
        dbContext.Functions.Add(function);
        await dbContext.SaveChangesAsync();
        dbContext.FunctionRoles.Add(new WebFunctionRole
        {
            TargetId = userRole.RoleId,
            FunctionId = function.FunctionId,
            Type = WebFunctionRoleType.Role,
            ActiveKey = permissions.Aggregate(
                ActiveKeyValue.None,
                (current, permission) => ActiveKeyValue.Set(current, permission, true)),
            Status = WebDataStatus.Active
        });
        await dbContext.SaveChangesAsync();
        return identity;
    }

    public static async Task<BranchTestIdentity> SeedWeighStationIdentityAsync(
        IServiceProvider services,
        WebAuthDbContext dbContext,
        string roleCode,
        int? companyId,
        string? branchIds,
        params ActiveKeyPermission[] permissions)
    {
        var identity = await SeedIdentityAsync(
            services,
            dbContext,
            roleCode,
            companyId,
            branchIds);
        var user = await dbContext.Users.SingleAsync(item => item.UserName == identity.UserName);
        var userRole = await dbContext.UserRoles.SingleAsync(item => item.UserId == user.UserId);
        var function = new WebFunction
        {
            Code = OperationalFunctionCodes.WeighStations,
            Name = "Quản lý cân ô tô",
            FunctionParentId = 0,
            Status = WebDataStatus.Active
        };
        dbContext.Functions.Add(function);
        await dbContext.SaveChangesAsync();
        dbContext.FunctionRoles.Add(new WebFunctionRole
        {
            TargetId = userRole.RoleId,
            FunctionId = function.FunctionId,
            Type = WebFunctionRoleType.Role,
            ActiveKey = permissions.Aggregate(
                ActiveKeyValue.None,
                (current, permission) => ActiveKeyValue.Set(current, permission, true)),
            Status = WebDataStatus.Active
        });
        await dbContext.SaveChangesAsync();
        return identity;
    }

    public static async Task<BranchTestIdentity> SeedMaterialReportIdentityAsync(
        IServiceProvider services,
        WebAuthDbContext dbContext,
        string roleCode,
        int? companyId,
        string? branchIds,
        params ActiveKeyPermission[] permissions)
    {
        var identity = await SeedIdentityAsync(
            services,
            dbContext,
            roleCode,
            companyId,
            branchIds);
        var user = await dbContext.Users.SingleAsync(item => item.UserName == identity.UserName);
        var userRole = await dbContext.UserRoles.SingleAsync(item => item.UserId == user.UserId);
        var function = new WebFunction
        {
            Code = OperationalFunctionCodes.MaterialReports,
            Name = "Quản lý vật liệu",
            FunctionParentId = 0,
            Status = WebDataStatus.Active
        };
        dbContext.Functions.Add(function);
        await dbContext.SaveChangesAsync();
        dbContext.FunctionRoles.Add(new WebFunctionRole
        {
            TargetId = userRole.RoleId,
            FunctionId = function.FunctionId,
            Type = WebFunctionRoleType.Role,
            ActiveKey = permissions.Aggregate(
                ActiveKeyValue.None,
                (current, permission) => ActiveKeyValue.Set(current, permission, true)),
            Status = WebDataStatus.Active
        });
        await dbContext.SaveChangesAsync();
        return identity;
    }

    public static WebCompany CreateCompany(int id, string code, string name) =>
        new()
        {
            CompanyId = id,
            Code = code,
            Name = name,
            Email = $"{code.ToLowerInvariant()}@example.test",
            Phone = "0900000000",
            Status = WebDataStatus.Active,
            CountUser = 9,
            Active = 1,
            IsLocked = false
        };

    public static WebBranch CreateBranch(
        int id,
        int companyId,
        string code,
        string name,
        int typeTram = 1,
        byte status = WebDataStatus.Active) =>
        new()
        {
            BranchId = id,
            CompanyId = companyId,
            Code = code,
            Name = name,
            Email = $"{code.ToLowerInvariant()}@example.test",
            Phone = "0900000000",
            Address = "Hà Nội",
            Username = $"{code}_user",
            Password = "Legacy123@#",
            Dataname = $"{code}_online",
            TypeTram = typeTram,
            Status = status,
            CreatedAt = new DateTime(2026, 7, 1, 8, 0, 0),
            UpdatedAt = new DateTime(2026, 7, 1, 8, 0, 0)
        };
}

internal sealed record BranchTestIdentity(string UserName, string Password);
