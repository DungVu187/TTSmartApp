using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Security.Cryptography;
using System.Text.Json;
using TTSmart.Api.Data.Company;
using TTSmart.Api.Data.WebAuth;
using TTSmart.Api.Features.AccessManagement;
using TTSmart.Api.Features.Auth;
using TTSmart.Api.Features.Authorization;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace TTSmart.Api.Tests;

public sealed class WebApiIntegrationTests(TTSmartApiFactory factory)
    : IClassFixture<TTSmartApiFactory>
{
    [Fact]
    public async Task ProtectedEndpoint_KhongCoToken_Tra401ProblemDetails()
    {
        await factory.ResetDatabaseAsync();
        using var client = factory.CreateClient();

        var response = await client.GetAsync("/api/users");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        Assert.Equal("application/problem+json", response.Content.Headers.ContentType?.MediaType);
    }

    [Fact]
    public async Task Logout_VoHieuHoaJwtCuVaChoPhepDangNhapLaiNgay()
    {
        TestIdentity identity = null!;
        await factory.ResetDatabaseAsync(async (services, dbContext) =>
        {
            identity = await SeedIdentityAsync(services, dbContext);
        });
        using var client = factory.CreateClient();
        var initialToken = await LoginAsync(client, identity);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", initialToken);
        var newPassword = Convert.ToBase64String(RandomNumberGenerator.GetBytes(18));
        var changePasswordResponse = await client.PostAsJsonAsync("/api/auth/change-password", new ChangePasswordRequest
        {
            CurrentPassword = identity.Password,
            NewPassword = newPassword
        });
        Assert.Equal(HttpStatusCode.NoContent, changePasswordResponse.StatusCode);

        client.DefaultRequestHeaders.Authorization = null;
        var changedIdentity = identity with { Password = newPassword };
        var oldToken = await LoginAsync(client, changedIdentity);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", oldToken);

        var logoutResponse = await client.PostAsync("/api/auth/logout", null);
        Assert.Equal(HttpStatusCode.NoContent, logoutResponse.StatusCode);

        var oldTokenResponse = await client.GetAsync("/api/auth/me");
        Assert.Equal(HttpStatusCode.Unauthorized, oldTokenResponse.StatusCode);
        using var problem = JsonDocument.Parse(await oldTokenResponse.Content.ReadAsStringAsync());
        Assert.Equal(
            AuthenticationFailureContext.SessionRevokedCode,
            problem.RootElement.GetProperty("code").GetString());

        client.DefaultRequestHeaders.Authorization = null;
        var newToken = await LoginAsync(client, changedIdentity);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", newToken);
        var currentUserResponse = await client.GetAsync("/api/auth/me");
        currentUserResponse.EnsureSuccessStatusCode();
    }

    [Fact]
    public async Task QuyenVaTrangThaiUser_DuocDocLaiSauKhiPhatJwt()
    {
        TestIdentity identity = null!;
        await factory.ResetDatabaseAsync(async (services, dbContext) =>
        {
            identity = await SeedIdentityAsync(
                services,
                dbContext,
                (ManagementFunctionCodes.Users, ActiveKeyPermission.DSach));
        });
        using var client = factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(
            "Bearer",
            await LoginAsync(client, identity));

        Assert.Equal(HttpStatusCode.OK, (await client.GetAsync("/api/users")).StatusCode);

        await factory.ExecuteDatabaseAsync(async dbContext =>
        {
            var assignment = await dbContext.FunctionRoles.SingleAsync();
            assignment.ActiveKey = ActiveKeyValue.None;
            await dbContext.SaveChangesAsync();
        });
        Assert.Equal(HttpStatusCode.Forbidden, (await client.GetAsync("/api/users")).StatusCode);

        await factory.ExecuteDatabaseAsync(async dbContext =>
        {
            var assignment = await dbContext.FunctionRoles.SingleAsync();
            assignment.ActiveKey = ActiveKeyValue.Set(
                ActiveKeyValue.None,
                ActiveKeyPermission.DSach,
                true);
            await dbContext.SaveChangesAsync();
        });
        Assert.Equal(HttpStatusCode.OK, (await client.GetAsync("/api/users")).StatusCode);

        await factory.ExecuteDatabaseAsync(async dbContext =>
        {
            var user = await dbContext.Users.SingleAsync();
            user.Status = WebDataStatus.Inactive;
            await dbContext.SaveChangesAsync();
        });
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync("/api/auth/me")).StatusCode);
    }

    [Fact]
    public async Task LoginVaDanhSachUser_KhongLoPasswordHoacKeyLock()
    {
        TestIdentity identity = null!;
        await factory.ResetDatabaseAsync(async (services, dbContext) =>
        {
            identity = await SeedIdentityAsync(
                services,
                dbContext,
                (ManagementFunctionCodes.Users, ActiveKeyPermission.DSach));
        });
        using var client = factory.CreateClient();

        var loginResponse = await client.PostAsJsonAsync("/api/auth/login", new LoginRequest
        {
            UserName = identity.UserName,
            Password = identity.Password
        });
        loginResponse.EnsureSuccessStatusCode();
        var loginJson = await loginResponse.Content.ReadAsStringAsync();
        Assert.DoesNotContain("password", loginJson, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("keyLock", loginJson, StringComparison.OrdinalIgnoreCase);

        var login = JsonSerializer.Deserialize<LoginResponse>(loginJson, JsonOptions)
            ?? throw new InvalidOperationException("Không đọc được response đăng nhập.");
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", login.AccessToken);
        var usersJson = await (await client.GetAsync("/api/users")).Content.ReadAsStringAsync();
        Assert.DoesNotContain("password", usersJson, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("keyLock", usersJson, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task DanhSachVaChiTiet_DungBitDSachVaXem()
    {
        TestIdentity identity = null!;
        await factory.ResetDatabaseAsync(async (services, dbContext) =>
        {
            identity = await SeedIdentityAsync(
                services,
                dbContext,
                (ManagementFunctionCodes.Users, ActiveKeyPermission.DSach));
        });
        using var client = factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(
            "Bearer",
            await LoginAsync(client, identity));

        Assert.Equal(HttpStatusCode.OK, (await client.GetAsync("/api/users")).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await client.GetAsync($"/api/users/{identity.UserId}")).StatusCode);

        await factory.ExecuteDatabaseAsync(async dbContext =>
        {
            var assignment = await dbContext.FunctionRoles.SingleAsync();
            assignment.ActiveKey = ActiveKeyValue.Set(
                ActiveKeyValue.None,
                ActiveKeyPermission.View,
                true);
            await dbContext.SaveChangesAsync();
        });

        Assert.Equal(HttpStatusCode.Forbidden, (await client.GetAsync("/api/users")).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await client.GetAsync($"/api/users/{identity.UserId}")).StatusCode);
    }

    [Fact]
    public async Task TaiKhoanCongTy_ChiDocDuocUserCungCompanyId()
    {
        TestIdentity identity = null!;
        var foreignUserId = 0;
        await factory.ResetDatabaseAsync(async (services, dbContext) =>
        {
            identity = await SeedIdentityAsync(
                services,
                dbContext,
                (ManagementFunctionCodes.Users, ActiveKeyPermission.DSach));
            var owner = await dbContext.Users.SingleAsync(user => user.UserId == identity.UserId);
            owner.CompanyId = 10;
            var ownerRole = await dbContext.Roles.SingleAsync(role => role.RoleId == identity.RoleId);
            ownerRole.Code = SystemRoleCodes.Company;
            var assignment = await dbContext.FunctionRoles.SingleAsync();
            assignment.ActiveKey = ActiveKeyValue.Set(
                assignment.ActiveKey ?? ActiveKeyValue.None,
                ActiveKeyPermission.View,
                true);
            var sameCompany = new WebUser
            {
                UserName = $"same_{Guid.NewGuid():N}",
                Password = "hash",
                CompanyId = 10,
                Status = WebDataStatus.Active
            };
            var foreignUser = new WebUser
            {
                UserName = $"foreign_{Guid.NewGuid():N}",
                Password = "hash",
                CompanyId = 20,
                Status = WebDataStatus.Active
            };
            dbContext.Users.AddRange(sameCompany, foreignUser);
            await dbContext.SaveChangesAsync();
            foreignUserId = foreignUser.UserId;
            var companyDbContext = services.GetRequiredService<CompanyDbContext>();
            companyDbContext.Companies.Add(new WebCompany
            {
                CompanyId = 10,
                Code = "COMPANY_10",
                Name = "Công ty kiểm thử",
                Email = "company10@example.test",
                Phone = "0900000000",
                Status = WebDataStatus.Active,
                CountUser = 9,
                Active = 1
            });
            await companyDbContext.SaveChangesAsync();
        });
        using var client = factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(
            "Bearer",
            await LoginAsync(client, identity));

        var listResponse = await client.GetAsync("/api/users?pageSize=100");
        listResponse.EnsureSuccessStatusCode();
        using var listDocument = JsonDocument.Parse(await listResponse.Content.ReadAsStringAsync());
        var items = listDocument.RootElement.GetProperty("items").EnumerateArray().ToArray();

        Assert.Equal(2, items.Length);
        Assert.All(items, item => Assert.Equal(10, item.GetProperty("companyId").GetInt32()));
        Assert.Equal(HttpStatusCode.NotFound, (await client.GetAsync($"/api/users/{foreignUserId}")).StatusCode);
    }

    [Fact]
    public async Task TaiKhoanCongTy_TaoUserKhiDuCountUser_Tra409()
    {
        TestIdentity identity = null!;
        var childRoleId = 0;
        await factory.ResetDatabaseAsync(async (services, dbContext) =>
        {
            identity = await SeedIdentityAsync(
                services,
                dbContext,
                (ManagementFunctionCodes.Users, ActiveKeyPermission.Create));
            var owner = await dbContext.Users.SingleAsync(user => user.UserId == identity.UserId);
            owner.CompanyId = 10;
            var ownerRole = await dbContext.Roles.SingleAsync(role => role.RoleId == identity.RoleId);
            ownerRole.Code = SystemRoleCodes.Company;
            var childRole = new WebRole
            {
                Code = "QUANLY",
                Name = "Tài khoản quản lý",
                Status = WebDataStatus.Active
            };
            var existingChild = new WebUser
            {
                UserName = $"existing_{Guid.NewGuid():N}",
                Password = "hash",
                CompanyId = 10,
                Status = WebDataStatus.Active
            };
            dbContext.AddRange(childRole, existingChild);
            await dbContext.SaveChangesAsync();
            childRoleId = childRole.RoleId;
            dbContext.UserRoles.Add(new WebUserRole
            {
                UserId = existingChild.UserId,
                RoleId = childRole.RoleId,
                Status = WebDataStatus.Active
            });
            await dbContext.SaveChangesAsync();
            var companyDbContext = services.GetRequiredService<CompanyDbContext>();
            companyDbContext.Companies.Add(new WebCompany
            {
                CompanyId = 10,
                Code = "COMPANY_10",
                Name = "Công ty quota",
                Email = "quota@example.test",
                Phone = "0900000000",
                CountUser = 1,
                Active = 1,
                Status = WebDataStatus.Active
            });
            await companyDbContext.SaveChangesAsync();
        });
        using var client = factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(
            "Bearer",
            await LoginAsync(client, identity));

        var response = await client.PostAsJsonAsync("/api/users", new
        {
            userName = $"blocked_{Guid.NewGuid():N}",
            password = "Password@123",
            roleIds = new[] { childRoleId }
        });

        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
        using var problem = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
        Assert.Contains("đã sử dụng đủ 1 tài khoản", problem.RootElement.GetProperty("detail").GetString());
    }

    [Fact]
    public async Task Admin_GiamCountUserTu9Xuong7_VanLuuVaCongTyBiChanTaoMoi()
    {
        TestIdentity admin = null!;
        TestIdentity companyOwner = null!;
        var childRoleId = 0;
        await factory.ResetDatabaseAsync(async (services, dbContext) =>
        {
            admin = await SeedIdentityAsync(services, dbContext);
            var adminRole = await dbContext.Roles.SingleAsync(role => role.RoleId == admin.RoleId);
            adminRole.Code = SystemRoleCodes.Admin;

            companyOwner = await SeedIdentityAsync(
                services,
                dbContext,
                (ManagementFunctionCodes.Users, ActiveKeyPermission.Create));
            var owner = await dbContext.Users.SingleAsync(user => user.UserId == companyOwner.UserId);
            owner.CompanyId = 10;
            var ownerRole = await dbContext.Roles.SingleAsync(role => role.RoleId == companyOwner.RoleId);
            ownerRole.Code = SystemRoleCodes.Company;

            var childRole = new WebRole
            {
                Code = "QUANLY",
                Name = "Tài khoản quản lý",
                Status = WebDataStatus.Active
            };
            var activeChildren = Enumerable.Range(1, 9)
                .Select(index => new WebUser
                {
                    UserName = $"child_{index}_{Guid.NewGuid():N}",
                    Password = "hash",
                    CompanyId = 10,
                    Status = WebDataStatus.Active
                })
                .ToList();
            dbContext.Roles.Add(childRole);
            dbContext.Users.AddRange(activeChildren);
            await dbContext.SaveChangesAsync();
            childRoleId = childRole.RoleId;
            dbContext.UserRoles.AddRange(activeChildren.Select(child => new WebUserRole
            {
                UserId = child.UserId,
                RoleId = childRole.RoleId,
                Status = WebDataStatus.Active
            }));
            await dbContext.SaveChangesAsync();

            var companyDbContext = services.GetRequiredService<CompanyDbContext>();
            companyDbContext.Companies.Add(new WebCompany
            {
                CompanyId = 10,
                Code = "COMPANY_10",
                Name = "Công ty quota",
                Email = "quota@example.test",
                Phone = "0900000000",
                CountUser = 9,
                Active = 1,
                Status = WebDataStatus.Active
            });
            await companyDbContext.SaveChangesAsync();
        });
        using var client = factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(
            "Bearer",
            await LoginAsync(client, admin));

        var updateResponse = await client.PutAsJsonAsync("/api/companies/10", new
        {
            code = "COMPANY_10",
            name = "Công ty quota",
            email = "quota@example.test",
            phone = "0900000000",
            countUser = 7,
            active = 1
        });

        Assert.Equal(HttpStatusCode.OK, updateResponse.StatusCode);
        using (var companyDocument = JsonDocument.Parse(await updateResponse.Content.ReadAsStringAsync()))
        {
            Assert.Equal(7, companyDocument.RootElement.GetProperty("countUser").GetInt32());
        }

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(
            "Bearer",
            await LoginAsync(client, companyOwner));
        var createResponse = await client.PostAsJsonAsync("/api/users", new
        {
            userName = $"blocked_after_reduce_{Guid.NewGuid():N}",
            password = "Password@123",
            roleIds = new[] { childRoleId }
        });

        Assert.Equal(HttpStatusCode.Conflict, createResponse.StatusCode);
        using var problem = JsonDocument.Parse(await createResponse.Content.ReadAsStringAsync());
        Assert.Contains("đã sử dụng đủ 7 tài khoản", problem.RootElement.GetProperty("detail").GetString());
    }

    [Fact]
    public async Task TreeVaFunctionMatrix_TraDuCauTrucChoMobile()
    {
        TestIdentity identity = null!;
        await factory.ResetDatabaseAsync(async (services, dbContext) =>
        {
            identity = await SeedIdentityAsync(
                services,
                dbContext,
                (ManagementFunctionCodes.Roles, ActiveKeyPermission.View),
                (ManagementFunctionCodes.Functions, ActiveKeyPermission.DSach));
            var parent = new WebFunction
            {
                Code = $"PARENT_{Guid.NewGuid():N}"[..20],
                Name = "Chức năng cha kiểm thử",
                FunctionParentId = 0,
                Status = WebDataStatus.Active
            };
            dbContext.Functions.Add(parent);
            await dbContext.SaveChangesAsync();
            dbContext.Functions.Add(new WebFunction
            {
                Code = $"CHILD_{Guid.NewGuid():N}"[..20],
                Name = "Chức năng con kiểm thử",
                FunctionParentId = parent.FunctionId,
                Status = WebDataStatus.Active
            });
            await dbContext.SaveChangesAsync();
        });
        using var client = factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(
            "Bearer",
            await LoginAsync(client, identity));

        var treeResponse = await client.GetAsync("/api/functions/tree");
        treeResponse.EnsureSuccessStatusCode();
        var treeJson = await treeResponse.Content.ReadAsStringAsync();
        Assert.Contains("\"children\"", treeJson, StringComparison.Ordinal);

        var matrixResponse = await client.GetAsync($"/api/roles/{identity.RoleId}/function-matrix");
        matrixResponse.EnsureSuccessStatusCode();
        var matrix = await matrixResponse.Content.ReadFromJsonAsync<List<RoleFunctionMatrixItemResponse>>(JsonOptions);
        Assert.NotNull(matrix);
        Assert.Contains(matrix, item => item.Code == ManagementFunctionCodes.Roles && item.IsAssigned);
        Assert.Contains(matrix, item => !item.IsAssigned && item.ActiveKey == ActiveKeyValue.None);
    }

    [Fact]
    public async Task StatusBodyThieuIsActive_Tra400()
    {
        TestIdentity identity = null!;
        await factory.ResetDatabaseAsync(async (services, dbContext) =>
        {
            identity = await SeedIdentityAsync(
                services,
                dbContext,
                (ManagementFunctionCodes.Users, ActiveKeyPermission.Update));
        });
        using var client = factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(
            "Bearer",
            await LoginAsync(client, identity));

        var response = await client.PutAsJsonAsync($"/api/users/{identity.UserId}/status", new { });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task OpenApi_CoDayDuRouteRbacMoi()
    {
        await factory.ResetDatabaseAsync();
        using var client = factory.CreateClient();

        var response = await client.GetAsync("/openapi/v1.json");

        response.EnsureSuccessStatusCode();
        using var document = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
        var paths = document.RootElement.GetProperty("paths");
        Assert.True(paths.TryGetProperty("/api/functions/tree", out _));
        Assert.True(paths.TryGetProperty("/api/auth/logout", out _));
        Assert.True(paths.TryGetProperty("/api/roles/{id}/function-matrix", out _));
        Assert.True(paths.TryGetProperty("/api/roles/{id}/functions/{functionId}", out _));
        Assert.True(paths.TryGetProperty("/api/roles/{id}/functions/{functionId}/active-key", out _));
    }

    private static async Task<string> LoginAsync(HttpClient client, TestIdentity identity)
    {
        var response = await client.PostAsJsonAsync("/api/auth/login", new LoginRequest
        {
            UserName = identity.UserName,
            Password = identity.Password
        });
        response.EnsureSuccessStatusCode();
        var login = await response.Content.ReadFromJsonAsync<LoginResponse>(JsonOptions);
        return login?.AccessToken ?? throw new InvalidOperationException("Không nhận được JWT.");
    }

    private static async Task<TestIdentity> SeedIdentityAsync(
        IServiceProvider services,
        WebAuthDbContext dbContext,
        params (string FunctionCode, ActiveKeyPermission Permission)[] grants)
    {
        var passwordService = services.GetRequiredService<IDatabasePasswordService>();
        var userName = $"http_{Guid.NewGuid():N}";
        var password = Convert.ToBase64String(RandomNumberGenerator.GetBytes(18));
        var user = new WebUser
        {
            UserName = userName,
            Password = DatabasePasswordService.PendingPasswordHash,
            FullName = "Người dùng kiểm thử HTTP",
            KeyLock = Convert.ToHexString(RandomNumberGenerator.GetBytes(10)),
            RegEmail = $"{userName}@example.test",
            Status = WebDataStatus.Active
        };
        var role = new WebRole
        {
            Code = $"ROLE_{Guid.NewGuid():N}"[..20],
            Name = "Vai trò kiểm thử HTTP",
            Status = WebDataStatus.Active
        };
        dbContext.Users.Add(user);
        dbContext.Roles.Add(role);
        var functions = grants.Select(grant => new WebFunction
        {
            Code = grant.FunctionCode,
            Name = $"Function {grant.FunctionCode}",
            FunctionParentId = 0,
            Status = WebDataStatus.Active
        }).ToList();
        dbContext.Functions.AddRange(functions);
        await dbContext.SaveChangesAsync();
        user.Password = passwordService.HashForStorage(user, password);
        await dbContext.SaveChangesAsync();

        dbContext.UserRoles.Add(new WebUserRole
        {
            UserId = user.UserId,
            RoleId = role.RoleId,
            Status = WebDataStatus.Active
        });
        foreach (var grant in grants)
        {
            var function = functions.Single(item => item.Code == grant.FunctionCode);
            dbContext.FunctionRoles.Add(new WebFunctionRole
            {
                TargetId = role.RoleId,
                FunctionId = function.FunctionId,
                Type = WebFunctionRoleType.Role,
                ActiveKey = ActiveKeyValue.Set(ActiveKeyValue.None, grant.Permission, true),
                Status = WebDataStatus.Active
            });
        }

        await dbContext.SaveChangesAsync();
        return new TestIdentity(user.UserId, role.RoleId, userName, password);
    }

    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    private sealed record TestIdentity(int UserId, int RoleId, string UserName, string Password);
}
