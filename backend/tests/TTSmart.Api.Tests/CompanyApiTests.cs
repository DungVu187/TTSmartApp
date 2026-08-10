using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Security.Cryptography;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using TTSmart.Api.Common.Models;
using TTSmart.Api.Data.Company;
using TTSmart.Api.Data.WebAuth;
using TTSmart.Api.Features.Auth;
using TTSmart.Api.Features.Authorization;
using TTSmart.Api.Features.CompanyManagement;

namespace TTSmart.Api.Tests;

public sealed class CompanyApiTests(TTSmartApiFactory factory) : IClassFixture<TTSmartApiFactory>
{
    [Fact]
    public async Task Admin_ThucHienCrudXoaMemKhoiPhucVaDatHan()
    {
        TestIdentity admin = null!;
        await factory.ResetDatabaseAsync(async (services, authDbContext) =>
        {
            admin = await SeedIdentityAsync(
                services,
                authDbContext,
                SystemRoleCodes.Admin,
                null,
                []);
        });
        using var client = factory.CreateClient();
        await LoginAsync(client, admin);

        var createResponse = await client.PostAsJsonAsync("/api/companies", new
        {
            code = "CT_E2E",
            name = "Công ty kiểm thử",
            email = "company@example.test",
            phone = "0900000000",
            address = "Hà Nội",
            countUser = 9,
            active = 1,
            note = "Dữ liệu kiểm thử"
        });
        Assert.Equal(HttpStatusCode.Created, createResponse.StatusCode);
        var created = await createResponse.Content.ReadFromJsonAsync<CompanyResponse>(JsonOptions);
        Assert.NotNull(created);
        Assert.Equal(WebDataStatus.Active, created.Status);
        Assert.False(created.IsLocked);

        var deleteResponse = await client.DeleteAsync($"/api/companies/{created.Id}");
        deleteResponse.EnsureSuccessStatusCode();
        var deleted = await deleteResponse.Content.ReadFromJsonAsync<CompanyResponse>(JsonOptions);
        Assert.Equal(WebDataStatus.Inactive, deleted?.Status);

        var activePage = await client.GetFromJsonAsync<PagedResponse<CompanyResponse>>(
            "/api/companies",
            JsonOptions);
        Assert.Empty(activePage?.Items ?? []);
        var deletedPage = await client.GetFromJsonAsync<PagedResponse<CompanyResponse>>(
            "/api/companies?status=99",
            JsonOptions);
        Assert.Contains(deletedPage?.Items ?? [], company => company.Id == created.Id);

        var restoreResponse = await client.PostAsync($"/api/companies/{created.Id}/restore", null);
        restoreResponse.EnsureSuccessStatusCode();
        var restored = await restoreResponse.Content.ReadFromJsonAsync<CompanyResponse>(JsonOptions);
        Assert.Equal(WebDataStatus.Active, restored?.Status);
        Assert.Null(restored?.ExpiredDate);
    }

    [Fact]
    public async Task Admin_ChiChanCompanyCodeTrungChinhXacTrongStatusActive()
    {
        TestIdentity admin = null!;
        await factory.ResetDatabaseAsync(async (services, authDbContext) =>
        {
            admin = await SeedIdentityAsync(
                services,
                authDbContext,
                SystemRoleCodes.Admin,
                null,
                []);
        });
        await factory.ExecuteCompanyDatabaseAsync(async dbContext =>
        {
            var deletedCompany = CreateCompany(3, "DELETED_CODE", "Công ty đã xóa mềm");
            deletedCompany.Status = WebDataStatus.Inactive;
            dbContext.Companies.AddRange(
                CreateCompany(1, "COMPANY_DUP", "Công ty đang hoạt động"),
                deletedCompany,
                CreateCompany(2, "COMPANY_OTHER", "Công ty cần sửa"));
            await dbContext.SaveChangesAsync();
        });
        using var client = factory.CreateClient();
        await LoginAsync(client, admin);

        var createResponse = await client.PostAsJsonAsync("/api/companies", new
        {
            code = "  COMPANY_DUP  ",
            name = "Công ty trùng mã",
            email = "duplicate@example.test",
            phone = "0900000000",
            countUser = 1,
            active = 1
        });
        Assert.Equal(HttpStatusCode.Conflict, createResponse.StatusCode);
        using (var createProblem = JsonDocument.Parse(await createResponse.Content.ReadAsStringAsync()))
        {
            Assert.Equal("Mã công ty đã tồn tại.", createProblem.RootElement.GetProperty("detail").GetString());
        }

        var differentCaseResponse = await client.PostAsJsonAsync("/api/companies", new
        {
            code = "company_dup",
            name = "Công ty khác hoa thường",
            email = "different-case@example.test",
            phone = "0900000002",
            countUser = 1,
            active = 1
        });
        Assert.Equal(HttpStatusCode.Created, differentCaseResponse.StatusCode);

        var reusedDeletedCodeResponse = await client.PostAsJsonAsync("/api/companies", new
        {
            code = "DELETED_CODE",
            name = "Công ty dùng lại mã đã xóa",
            email = "reused-code@example.test",
            phone = "0900000003",
            countUser = 1,
            active = 1
        });
        Assert.Equal(HttpStatusCode.Created, reusedDeletedCodeResponse.StatusCode);

        var updateResponse = await client.PutAsJsonAsync("/api/companies/2", new
        {
            code = "COMPANY_DUP",
            name = "Công ty cần sửa",
            email = "other@example.test",
            phone = "0900000001",
            countUser = 1,
            active = 1
        });
        Assert.Equal(HttpStatusCode.Conflict, updateResponse.StatusCode);
        await factory.ExecuteCompanyDatabaseAsync(async dbContext =>
        {
            var unchanged = await dbContext.Companies.SingleAsync(company => company.CompanyId == 2);
            Assert.Equal("COMPANY_OTHER", unchanged.Code);
        });
    }

    [Fact]
    public async Task Admin_SuaCompanyLegacyTrungCodeNhungGiuNguyenMa_VanThanhCong()
    {
        TestIdentity admin = null!;
        await factory.ResetDatabaseAsync(async (services, authDbContext) =>
        {
            admin = await SeedIdentityAsync(
                services,
                authDbContext,
                SystemRoleCodes.Admin,
                null,
                []);
        });
        await factory.ExecuteCompanyDatabaseAsync(async dbContext =>
        {
            dbContext.Companies.AddRange(
                CreateCompany(1, "LEGACY_DUP", "Công ty legacy 1"),
                CreateCompany(2, "LEGACY_DUP", "Công ty legacy 2"));
            await dbContext.SaveChangesAsync();
        });
        using var client = factory.CreateClient();
        await LoginAsync(client, admin);

        var response = await client.PutAsJsonAsync("/api/companies/1", new
        {
            code = " LEGACY_DUP ",
            name = "Công ty legacy đã sửa",
            email = "legacy1@example.test",
            phone = "0900000000",
            countUser = 9,
            active = 1
        });

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var updated = await response.Content.ReadFromJsonAsync<CompanyResponse>(JsonOptions);
        Assert.Equal("LEGACY_DUP", updated?.Code);
        Assert.Equal("Công ty legacy đã sửa", updated?.Name);
    }

    [Fact]
    public async Task UserCongTy_ChiDocDuocCongTyCuaMinh()
    {
        TestIdentity companyUser = null!;
        await factory.ResetDatabaseAsync(async (services, authDbContext) =>
        {
            companyUser = await SeedIdentityAsync(
                services,
                authDbContext,
                SystemRoleCodes.Company,
                2,
                [ActiveKeyPermission.DSach, ActiveKeyPermission.View]);
        });
        await factory.ExecuteCompanyDatabaseAsync(async dbContext =>
        {
            dbContext.Companies.AddRange(
                CreateCompany(1, "CT_1", "Công ty 1"),
                CreateCompany(2, "CT_2", "Công ty 2"));
            await dbContext.SaveChangesAsync();
        });
        using var client = factory.CreateClient();
        await LoginAsync(client, companyUser);

        var page = await client.GetFromJsonAsync<PagedResponse<CompanyResponse>>(
            "/api/companies",
            JsonOptions);
        var item = Assert.Single(page?.Items ?? []);
        Assert.Equal(2, item.Id);

        var crossCompanyResponse = await client.GetAsync("/api/companies/1");
        Assert.Equal(HttpStatusCode.NotFound, crossCompanyResponse.StatusCode);
    }

    [Fact]
    public async Task CompanyLockVaExpirationChangesDangTat_Tra409()
    {
        TestIdentity companyUser = null!;
        await factory.ResetDatabaseAsync(async (services, authDbContext) =>
        {
            companyUser = await SeedIdentityAsync(
                services,
                authDbContext,
                SystemRoleCodes.Company,
                1,
                [ActiveKeyPermission.Update, ActiveKeyPermission.DSach]);
        });
        await factory.ExecuteCompanyDatabaseAsync(async dbContext =>
        {
            dbContext.Companies.Add(CreateCompany(1, "CT_READ_ONLY", "Công ty chỉ đọc trạng thái"));
            await dbContext.SaveChangesAsync();
        });
        using var client = factory.CreateClient();
        await LoginAsync(client, companyUser);

        var lockResponse = await client.PutAsJsonAsync(
            "/api/companies/1/lock",
            new { isLocked = true });
        var expirationResponse = await client.PutAsJsonAsync(
            "/api/companies/1/expiration",
            new { expiredDate = "2027-01-01" });
        var currentUserResponse = await client.GetAsync("/api/auth/me");
        var lockFilterResponse = await client.GetAsync("/api/companies?isLocked=true");

        Assert.Equal(HttpStatusCode.Conflict, lockResponse.StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, expirationResponse.StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, lockFilterResponse.StatusCode);
        currentUserResponse.EnsureSuccessStatusCode();
    }

    [Fact]
    public async Task CompanyHetHan_MobileVanDangNhapVaHienThiNgay()
    {
        TestIdentity companyUser = null!;
        await factory.ResetDatabaseAsync(async (services, authDbContext) =>
        {
            companyUser = await SeedIdentityAsync(
                services,
                authDbContext,
                SystemRoleCodes.Company,
                1,
                [ActiveKeyPermission.View]);
        });
        await factory.ExecuteCompanyDatabaseAsync(async dbContext =>
        {
            var company = CreateCompany(1, "CT_EXPIRED", "Công ty hết hạn");
            company.ExpiredDate = new DateTime(2020, 1, 1, 23, 59, 59);
            dbContext.Companies.Add(company);
            await dbContext.SaveChangesAsync();
        });
        using var client = factory.CreateClient();

        await LoginAsync(client, companyUser);
        var currentUserResponse = await client.GetAsync("/api/auth/me");
        currentUserResponse.EnsureSuccessStatusCode();
        var companyResponse = await client.GetAsync("/api/companies/1");
        companyResponse.EnsureSuccessStatusCode();
        var company = await companyResponse.Content.ReadFromJsonAsync<CompanyResponse>(JsonOptions);

        Assert.Equal(new DateOnly(2020, 1, 2), company?.ExpiredDate);
    }

    [Fact]
    public async Task Admin_BoQuaCompanyScopeVaFunctionRole()
    {
        TestIdentity admin = null!;
        await factory.ResetDatabaseAsync(async (services, authDbContext) =>
        {
            admin = await SeedIdentityAsync(
                services,
                authDbContext,
                SystemRoleCodes.Admin,
                1,
                []);
        });
        await factory.ExecuteCompanyDatabaseAsync(async dbContext =>
        {
            var company = CreateCompany(1, "CT_ADMIN", "Công ty của admin");
            dbContext.Companies.Add(company);
            await dbContext.SaveChangesAsync();
        });
        using var client = factory.CreateClient();

        await LoginAsync(client, admin);
        var response = await client.GetAsync("/api/companies");

        response.EnsureSuccessStatusCode();
    }

    private static async Task LoginAsync(HttpClient client, TestIdentity identity)
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

    private static async Task<TestIdentity> SeedIdentityAsync(
        IServiceProvider services,
        WebAuthDbContext dbContext,
        string roleCode,
        int? companyId,
        IReadOnlyCollection<ActiveKeyPermission> permissions)
    {
        var passwordService = services.GetRequiredService<IDatabasePasswordService>();
        var userName = $"company_http_{Guid.NewGuid():N}";
        var password = Convert.ToBase64String(RandomNumberGenerator.GetBytes(18));
        var user = new WebUser
        {
            UserName = userName,
            Password = DatabasePasswordService.PendingPasswordHash,
            FullName = "Người dùng kiểm thử Company",
            KeyLock = Convert.ToHexString(RandomNumberGenerator.GetBytes(10)),
            RegEmail = $"{userName}@example.test",
            CompanyId = companyId,
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
        if (permissions.Count > 0)
        {
            function = new WebFunction
            {
                Code = ManagementFunctionCodes.Companies,
                Name = "Quản lý công ty",
                FunctionParentId = 0,
                Status = WebDataStatus.Active
            };
            dbContext.Functions.Add(function);
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
        return new TestIdentity(userName, password);
    }

    private static WebCompany CreateCompany(int id, string code, string name) =>
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

    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    private sealed record TestIdentity(string UserName, string Password);
}
