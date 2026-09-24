using System.Net;
using System.Net.Http.Json;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;
using TTSmart.Api.Common.Models;
using TTSmart.Api.Data.Company;
using TTSmart.Api.Features.Authorization;
using TTSmart.Api.Features.BranchManagement;

namespace TTSmart.Api.Tests;

public sealed class SystemRoleCatalogTests
{
    [Fact]
    public void KhongCauHinh_GiuNguyenMaMacDinh()
    {
        var catalog = Build(new SystemRoleOptions());

        Assert.True(catalog.IsAdmin(0, SystemRoleCodes.Admin));
        Assert.True(catalog.IsCompany(0, SystemRoleCodes.Company));
        Assert.False(catalog.IsCompany(0, "CONGTY2.0"));
    }

    [Fact]
    public void CauHinhTheoMa_NhanDienRoleMoi()
    {
        var catalog = Build(new SystemRoleOptions
        {
            CompanyRoleCodes = ["CONGTY", "CONGTY2.0"]
        });

        Assert.True(catalog.IsCompany(0, "CONGTY"));
        Assert.True(catalog.IsCompany(0, "CONGTY2.0"));
        Assert.True(catalog.IsCompany(0, "congty2.0"));
        Assert.False(catalog.IsCompany(0, "KETOAN"));
    }

    [Fact]
    public void CauHinhTheoRoleId_NhanDienDuDoiMa()
    {
        var catalog = Build(new SystemRoleOptions
        {
            CompanyRoleIds = [3, 4071]
        });

        Assert.True(catalog.IsCompany(4071, "TEN_BAT_KY"));
        Assert.True(catalog.IsCompany(0, SystemRoleCodes.Company));
        Assert.False(catalog.IsCompany(99, "TEN_BAT_KY"));
    }

    [Fact]
    public void QuyenDacBiet_GopCaAdminVaCongTy()
    {
        var catalog = Build(new SystemRoleOptions
        {
            AdminRoleIds = [1],
            CompanyRoleCodes = ["CONGTY2.0"]
        });

        Assert.True(catalog.IsPrivileged(1, "TEN_BAT_KY"));
        Assert.True(catalog.IsPrivileged(0, "CONGTY2.0"));
        Assert.False(catalog.IsPrivileged(0, "KETOAN"));
        Assert.Contains("CONGTY2.0", catalog.PrivilegedRoleCodes);
        Assert.Contains(1, catalog.PrivilegedRoleIds);
    }

    private static ISystemRoleCatalog Build(SystemRoleOptions options) =>
        new SystemRoleCatalog(Options.Create(options));
}

public sealed class SystemRoleResolutionTests(TTSmartApiFactory factory) : IClassFixture<TTSmartApiFactory>
{
    [Fact]
    public async Task RoleCongTy2_LocTramTheoCongTyCuaMinh_KhongBiChan()
    {
        BranchTestIdentity companyOwner = null!;
        await factory.ResetDatabaseAsync(async (services, authDbContext) =>
        {
            companyOwner = await BranchTestSupport.SeedIdentityAsync(
                services,
                authDbContext,
                "CONGTY2.0",
                1,
                null,
                ActiveKeyPermission.DSach,
                ActiveKeyPermission.View);
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

        var response = await client.GetAsync("/api/branches?companyId=1");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var page = await response.Content.ReadFromJsonAsync<PagedResponse<BranchListItemResponse>>(
            BranchTestSupport.JsonOptions);
        Assert.NotNull(page);
        Assert.Equal([10], page.Items.Select(item => item.Id).ToArray());
    }

    [Fact]
    public async Task RoleThuong_VanBiChanKhiLocTheoCongTy()
    {
        BranchTestIdentity accountant = null!;
        await factory.ResetDatabaseAsync(async (services, authDbContext) =>
        {
            accountant = await BranchTestSupport.SeedIdentityAsync(
                services,
                authDbContext,
                "KETOAN",
                1,
                null,
                ActiveKeyPermission.DSach,
                ActiveKeyPermission.View);
            var companyDbContext = services.GetRequiredService<CompanyDbContext>();
            companyDbContext.Companies.Add(BranchTestSupport.CreateCompany(1, "CT_1", "Công ty 1"));
            companyDbContext.Branches.Add(BranchTestSupport.CreateBranch(10, 1, "OWN", "Trạm cùng công ty"));
            await companyDbContext.SaveChangesAsync();
        });
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, accountant);

        var response = await client.GetAsync("/api/branches?companyId=1");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }
}
