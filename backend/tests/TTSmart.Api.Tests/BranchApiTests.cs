using System.Net;
using System.Net.Http.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using TTSmart.Api.Common.Models;
using TTSmart.Api.Data.Company;
using TTSmart.Api.Data.WebAuth;
using TTSmart.Api.Features.Authorization;
using TTSmart.Api.Features.BranchManagement;

namespace TTSmart.Api.Tests;

public sealed class BranchApiTests(TTSmartApiFactory factory) : IClassFixture<TTSmartApiFactory>
{
    [Fact]
    public async Task Admin_TaoSuaXoaKhoiPhucTram_VaKhongLoMatKhau()
    {
        BranchTestIdentity admin = null!;
        await factory.ResetDatabaseAsync(async (services, authDbContext) =>
        {
            admin = await BranchTestSupport.SeedIdentityAsync(
                services,
                authDbContext,
                SystemRoleCodes.Admin,
                null,
                null);
            var companyDbContext = services.GetRequiredService<CompanyDbContext>();
            companyDbContext.Companies.Add(BranchTestSupport.CreateCompany(1, "CT_1", "Công ty 1"));
            await companyDbContext.SaveChangesAsync();
        });
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, admin);

        var createResponse = await client.PostAsJsonAsync("/api/branches", new
        {
            companyId = 1,
            code = "TRAM_1",
            name = "Trạm kiểm thử",
            email = "tram1@example.test",
            phone = "0911111111",
            username = "tram_user_1",
            password = "Abc123@#",
            typeTram = 1
        });
        Assert.Equal(HttpStatusCode.Created, createResponse.StatusCode);
        var created = await createResponse.Content.ReadFromJsonAsync<BranchResponse>(BranchTestSupport.JsonOptions);
        Assert.NotNull(created);
        Assert.Equal("••••••••", created.Password);
        Assert.Equal(WebDataStatus.Active, created.Status);

        await factory.ExecuteCompanyDatabaseAsync(async dbContext =>
        {
            var stored = await dbContext.Branches.SingleAsync(branch => branch.BranchId == created.Id);
            Assert.Equal("Abc123@#", stored.Password);
            Assert.Equal(WebDataStatus.Active, stored.Status);
            Assert.NotNull(stored.CreatedAt);
            Assert.NotNull(stored.UpdatedAt);
        });

        var updateResponse = await client.PutAsJsonAsync($"/api/branches/{created.Id}", new
        {
            companyId = 1,
            code = "TRAM_1_UPDATED",
            name = "Trạm đã cập nhật",
            email = "updated@example.test",
            phone = "0922222222",
            username = "tram_user_updated",
            password = "Xyz789@#",
            typeTram = 2
        });
        updateResponse.EnsureSuccessStatusCode();
        var updated = await updateResponse.Content.ReadFromJsonAsync<BranchResponse>(BranchTestSupport.JsonOptions);
        Assert.Equal(2, updated?.TypeTram);
        Assert.Equal("tram_user_updated", updated?.Username);
        Assert.Equal("••••••••", updated?.Password);

        var deleteResponse = await client.DeleteAsync($"/api/branches/{created.Id}");
        deleteResponse.EnsureSuccessStatusCode();
        var deleted = await deleteResponse.Content.ReadFromJsonAsync<BranchResponse>(BranchTestSupport.JsonOptions);
        Assert.Equal(WebDataStatus.Inactive, deleted?.Status);

        var activePage = await client.GetFromJsonAsync<PagedResponse<BranchListItemResponse>>(
            "/api/branches",
            BranchTestSupport.JsonOptions);
        Assert.Empty(activePage?.Items ?? []);
        var deletedPage = await client.GetFromJsonAsync<PagedResponse<BranchListItemResponse>>(
            "/api/branches?status=99",
            BranchTestSupport.JsonOptions);
        Assert.Contains(deletedPage?.Items ?? [], item => item.Id == created.Id);

        var restoreResponse = await client.PostAsync($"/api/branches/{created.Id}/restore", null);
        restoreResponse.EnsureSuccessStatusCode();
        var restored = await restoreResponse.Content.ReadFromJsonAsync<BranchResponse>(BranchTestSupport.JsonOptions);
        Assert.Equal(WebDataStatus.Active, restored?.Status);
    }

    [Fact]
    public async Task CongTy_ChiXemVaSuaTramCuaMinh_TheoAllowlist()
    {
        BranchTestIdentity companyOwner = null!;
        await factory.ResetDatabaseAsync(async (services, authDbContext) =>
        {
            companyOwner = await BranchTestSupport.SeedIdentityAsync(
                services,
                authDbContext,
                SystemRoleCodes.Company,
                1,
                null,
                ActiveKeyPermission.DSach,
                ActiveKeyPermission.View,
                ActiveKeyPermission.Create,
                ActiveKeyPermission.Update,
                ActiveKeyPermission.Delete);
            var companyDbContext = services.GetRequiredService<CompanyDbContext>();
            companyDbContext.Companies.AddRange(
                BranchTestSupport.CreateCompany(1, "CT_1", "Công ty 1"),
                BranchTestSupport.CreateCompany(2, "CT_2", "Công ty 2"));
            companyDbContext.Branches.AddRange(
                BranchTestSupport.CreateBranch(10, 1, "OWN", "Trạm cùng công ty"),
                BranchTestSupport.CreateBranch(20, 2, "OTHER", "Trạm công ty khác"));
            await companyDbContext.SaveChangesAsync();
        });
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, companyOwner);

        var page = await client.GetFromJsonAsync<PagedResponse<BranchListItemResponse>>(
            "/api/branches",
            BranchTestSupport.JsonOptions);
        Assert.NotNull(page);
        Assert.Equal([10], page.Items.Select(item => item.Id).ToArray());
        Assert.Equal(HttpStatusCode.NotFound, (await client.GetAsync("/api/branches/20")).StatusCode);

        var updateResponse = await client.PutAsJsonAsync("/api/branches/10", new
        {
            companyId = 2,
            code = "OWN_UPDATED",
            name = "Trạm công ty đã sửa",
            email = "owner-updated@example.test",
            phone = "0933333333",
            address = "Địa chỉ mới",
            username = "khong_duoc_doi",
            password = "New123@#",
            pmqlXe = "pmqlxe.example",
            qlCamera = "camera.example",
            typeTram = 2
        });
        updateResponse.EnsureSuccessStatusCode();
        await factory.ExecuteCompanyDatabaseAsync(async dbContext =>
        {
            var stored = await dbContext.Branches.SingleAsync(branch => branch.BranchId == 10);
            Assert.Equal("OWN_UPDATED", stored.Code);
            Assert.Equal("Trạm công ty đã sửa", stored.Name);
            Assert.Equal("0933333333", stored.Phone);
            Assert.Equal("pmqlxe.example", stored.PMQLXe);
            Assert.Equal(1, stored.CompanyId);
            Assert.Equal(1, stored.TypeTram);
            Assert.Equal("OWN_user", stored.Username);
            Assert.Equal("Legacy123@#", stored.Password);
        });

        var createResponse = await client.PostAsJsonAsync("/api/branches", new
        {
            companyId = 1,
            code = "DENIED",
            name = "Không được tạo",
            email = "denied@example.test",
            phone = "0900000000",
            username = "denied_user",
            password = "Abc123@#",
            typeTram = 1
        });
        Assert.Equal(HttpStatusCode.Forbidden, createResponse.StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await client.DeleteAsync("/api/branches/10")).StatusCode);
        Assert.Equal(
            HttpStatusCode.Forbidden,
            (await client.PostAsync("/api/branches/10/restore", null)).StatusCode);
    }

    [Fact]
    public async Task RoleThapHon_ChiDocTramDuocGan_DuCoBitCapNhat()
    {
        BranchTestIdentity manager = null!;
        await factory.ResetDatabaseAsync(async (services, authDbContext) =>
        {
            manager = await BranchTestSupport.SeedIdentityAsync(
                services,
                authDbContext,
                "QUANLY",
                1,
                "10,undefined,[object Object]",
                ActiveKeyPermission.DSach,
                ActiveKeyPermission.View,
                ActiveKeyPermission.Update);
            var companyDbContext = services.GetRequiredService<CompanyDbContext>();
            companyDbContext.Companies.Add(BranchTestSupport.CreateCompany(1, "CT_1", "Công ty 1"));
            companyDbContext.Branches.AddRange(
                BranchTestSupport.CreateBranch(10, 1, "ASSIGNED", "Trạm được gán"),
                BranchTestSupport.CreateBranch(11, 1, "NOT_ASSIGNED", "Trạm chưa gán"));
            await companyDbContext.SaveChangesAsync();
        });
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, manager);

        var page = await client.GetFromJsonAsync<PagedResponse<BranchListItemResponse>>(
            "/api/branches",
            BranchTestSupport.JsonOptions);
        Assert.NotNull(page);
        Assert.Equal([10], page.Items.Select(item => item.Id).ToArray());
        Assert.Equal(HttpStatusCode.NotFound, (await client.GetAsync("/api/branches/11")).StatusCode);
        var updateResponse = await client.PutAsJsonAsync("/api/branches/10", new
        {
            name = "Không được sửa"
        });
        Assert.Equal(HttpStatusCode.Forbidden, updateResponse.StatusCode);
    }
}
