using System.Net;
using System.Net.Http.Json;
using Microsoft.Extensions.DependencyInjection;
using TTSmart.Api.Common.Models;
using TTSmart.Api.Data.Company;
using TTSmart.Api.Features.Authorization;
using TTSmart.Api.Features.BranchManagement;

namespace TTSmart.Api.Tests;

public sealed class BranchValidationTests(TTSmartApiFactory factory) : IClassFixture<TTSmartApiFactory>
{
    [Fact]
    public async Task DanhSach_TimTrenToanBoDuLieuTruocKhiPhanTrang()
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
            companyDbContext.Companies.AddRange(
                BranchTestSupport.CreateCompany(1, "CT_1", "Công ty 1"),
                BranchTestSupport.CreateCompany(2, "CT_2", "Công ty 2"));
            for (var index = 1; index <= 11; index++)
            {
                companyDbContext.Branches.Add(BranchTestSupport.CreateBranch(
                    index,
                    1,
                    $"TRAM_{index:00}",
                    $"Trạm {index:00}",
                    index % 2 == 0 ? 2 : 1));
            }

            companyDbContext.Branches.Add(BranchTestSupport.CreateBranch(
                12,
                2,
                "TIM_TOAN_BO",
                "Trạm tìm kiếm đặc biệt",
                2));
            await companyDbContext.SaveChangesAsync();
        });
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, admin);

        var defaultPage = await client.GetFromJsonAsync<PagedResponse<BranchListItemResponse>>(
            "/api/branches",
            BranchTestSupport.JsonOptions);
        Assert.NotNull(defaultPage);
        Assert.Equal(10, defaultPage.PageSize);
        Assert.Equal(10, defaultPage.Items.Count);
        Assert.Equal(12, defaultPage.TotalCount);

        var searchPage = await client.GetFromJsonAsync<PagedResponse<BranchListItemResponse>>(
            "/api/branches?search=đặc%20biệt",
            BranchTestSupport.JsonOptions);
        Assert.NotNull(searchPage);
        Assert.Single(searchPage.Items);
        Assert.Equal(12, searchPage.Items[0].Id);

        var companyPage = await client.GetFromJsonAsync<PagedResponse<BranchListItemResponse>>(
            "/api/branches?companyId=2&typeTram=2",
            BranchTestSupport.JsonOptions);
        Assert.NotNull(companyPage);
        Assert.Equal([12], companyPage.Items.Select(item => item.Id).ToArray());
    }

    [Fact]
    public async Task TaoVaKhoiPhuc_KiemTraTrungMaVaTaiKhoanTheoStatus()
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
            var active = BranchTestSupport.CreateBranch(1, 1, "DUP_CODE", "Trạm đang hoạt động");
            active.Username = "DUP_USER";
            var deletedReuse = BranchTestSupport.CreateBranch(
                2,
                1,
                "REUSE_CODE",
                "Trạm đã xóa",
                status: 99);
            deletedReuse.Username = "REUSE_USER";
            var deletedConflict = BranchTestSupport.CreateBranch(
                3,
                1,
                "DUP_CODE",
                "Trạm khôi phục xung đột",
                status: 99);
            deletedConflict.Username = "DUP_USER";
            companyDbContext.Branches.AddRange(active, deletedReuse, deletedConflict);
            await companyDbContext.SaveChangesAsync();
        });
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, admin);

        var duplicateCode = await CreateBranchAsync(client, "DUP_CODE", "UNIQUE_USER");
        Assert.Equal(HttpStatusCode.Conflict, duplicateCode.StatusCode);

        var differentCaseCode = await CreateBranchAsync(client, "dup_code", "CASE_USER");
        Assert.Equal(HttpStatusCode.Created, differentCaseCode.StatusCode);

        var duplicateUsername = await CreateBranchAsync(client, "UNIQUE_CODE", "dup_user");
        Assert.Equal(HttpStatusCode.Conflict, duplicateUsername.StatusCode);

        var reuseDeleted = await CreateBranchAsync(client, "REUSE_CODE", "REUSE_USER");
        Assert.Equal(HttpStatusCode.Created, reuseDeleted.StatusCode);

        var restoreConflict = await client.PostAsync("/api/branches/3/restore", null);
        Assert.Equal(HttpStatusCode.Conflict, restoreConflict.StatusCode);
    }

    [Fact]
    public async Task QuyenXemVaDanhSach_DuocKiemTraDocLap()
    {
        BranchTestIdentity listOnly = null!;
        BranchTestIdentity viewOnly = null!;
        await factory.ResetDatabaseAsync(async (services, authDbContext) =>
        {
            listOnly = await BranchTestSupport.SeedIdentityAsync(
                services,
                authDbContext,
                "LIST_ONLY",
                1,
                "10",
                ActiveKeyPermission.DSach);
            viewOnly = await BranchTestSupport.SeedIdentityAsync(
                services,
                authDbContext,
                "VIEW_ONLY",
                1,
                "10",
                ActiveKeyPermission.View);
            var companyDbContext = services.GetRequiredService<CompanyDbContext>();
            companyDbContext.Companies.Add(BranchTestSupport.CreateCompany(1, "CT_1", "Công ty 1"));
            companyDbContext.Branches.Add(BranchTestSupport.CreateBranch(10, 1, "BRANCH_10", "Trạm 10"));
            await companyDbContext.SaveChangesAsync();
        });

        using var listClient = factory.CreateClient();
        await BranchTestSupport.LoginAsync(listClient, listOnly);
        Assert.Equal(HttpStatusCode.OK, (await listClient.GetAsync("/api/branches")).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await listClient.GetAsync("/api/branches/10")).StatusCode);

        using var viewClient = factory.CreateClient();
        await BranchTestSupport.LoginAsync(viewClient, viewOnly);
        Assert.Equal(HttpStatusCode.Forbidden, (await viewClient.GetAsync("/api/branches")).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await viewClient.GetAsync("/api/branches/10")).StatusCode);
    }

    private static Task<HttpResponseMessage> CreateBranchAsync(
        HttpClient client,
        string code,
        string username) =>
        client.PostAsJsonAsync("/api/branches", new
        {
            companyId = 1,
            code,
            name = $"Trạm {code}",
            email = $"{username.ToLowerInvariant()}@example.test",
            phone = "0900000000",
            username,
            password = "Abc123@#",
            typeTram = 1
        });
}
