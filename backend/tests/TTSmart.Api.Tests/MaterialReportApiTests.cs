using System.Net;
using System.Net.Http.Json;
using Microsoft.Extensions.DependencyInjection;
using TTSmart.Api.Data.Company;
using TTSmart.Api.Data.WebAuth;
using TTSmart.Api.Features.Authorization;
using TTSmart.Api.Features.MaterialReporting;

namespace TTSmart.Api.Tests;

public sealed class MaterialReportApiTests(TTSmartApiFactory factory) : IClassFixture<TTSmartApiFactory>
{
    [Theory]
    [InlineData("/api/material-reports/stations")]
    [InlineData("/api/material-reports")]
    public async Task ChuaDangNhap_Tra401(string uri)
    {
        await factory.ResetDatabaseAsync();
        using var client = factory.CreateClient();
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync(uri)).StatusCode);
    }

    [Fact]
    public async Task CoFunctionNhungKhongCoQuyenView_Tra403()
    {
        var identity = await ResetAndSeedAsync(
            SystemRoleCodes.Company,
            1,
            null,
            ActiveKeyPermission.DSach);
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        Assert.Equal(HttpStatusCode.Forbidden, (await client.GetAsync(
            "/api/material-reports/stations")).StatusCode);
        Assert.Equal(0, factory.MaterialReportDataSource.CallCount);
    }

    [Fact]
    public async Task AdminKhongCoFunctionQLKHO_KhongDuocBypass()
    {
        BranchTestIdentity identity = null!;
        await factory.ResetDatabaseAsync(async (services, authDbContext) =>
        {
            identity = await BranchTestSupport.SeedIdentityAsync(
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
        await BranchTestSupport.LoginAsync(client, identity);

        Assert.Equal(HttpStatusCode.Forbidden, (await client.GetAsync(
            "/api/material-reports/stations?companyId=1")).StatusCode);
        Assert.Equal(0, factory.MaterialReportDataSource.CallCount);
    }

    [Theory]
    [InlineData("/api/material-reports/stations", "Chưa chọn công ty.")]
    [InlineData("/api/material-reports?branchId=10&from=2026-08-01T00:00:00%2B07:00&to=2026-08-31T23:59:59%2B07:00", "Chưa chọn công ty.")]
    public async Task Admin_BatBuocChonCongTy(string uri, string expectedDetail)
    {
        var identity = await ResetAndSeedAsync(
            SystemRoleCodes.Admin,
            null,
            null,
            ActiveKeyPermission.View);
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var response = await client.GetAsync(uri);
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Contains(expectedDetail, await response.Content.ReadAsStringAsync());
        Assert.Equal(0, factory.MaterialReportDataSource.CallCount);
    }

    [Fact]
    public async Task CongTy_BatBuocChonTram()
    {
        var identity = await ResetAndSeedAsync(
            SystemRoleCodes.Company,
            1,
            null,
            ActiveKeyPermission.View);
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var response = await client.GetAsync(
            "/api/material-reports?from=2026-08-01T00:00:00%2B07:00&to=2026-08-31T23:59:59%2B07:00");
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Contains("Chưa chọn trạm trộn.", await response.Content.ReadAsStringAsync());
        Assert.Equal(0, factory.MaterialReportDataSource.CallCount);
    }

    [Fact]
    public async Task DanhSachTram_ChiCoTramTronActiveTrongScope()
    {
        var identity = await ResetAndSeedAsync(
            SystemRoleCodes.Company,
            1,
            null,
            ActiveKeyPermission.View);
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var stations = await client.GetFromJsonAsync<MaterialReportStationResponse[]>(
            "/api/material-reports/stations",
            BranchTestSupport.JsonOptions);
        var station = Assert.Single(stations!);
        Assert.Equal(10, station.Id);
        Assert.Equal(1, station.TypeTram);
        Assert.Equal(0, factory.MaterialReportDataSource.CallCount);
    }

    [Fact]
    public async Task BaoCao_TinhFifoAmKhoVaGiaDungQuyTacDaChot()
    {
        var identity = await ResetAndSeedAsync(
            SystemRoleCodes.Company,
            1,
            null,
            ActiveKeyPermission.View);
        var start = new DateTime(2026, 8, 1);
        factory.MaterialReportDataSource.SetSnapshot(new MaterialReportSnapshot(
            [new MaterialDefinition(101, 1, 1, "Cát 1")],
            [
                new MaterialImportLot("i1", 1, 101, "Cát 1", start, 100, 4_000),
                new MaterialImportLot("i2", 3, 101, "Cát 1", start.AddDays(2), 50, 5_000)
            ],
            [new MaterialIssueEvent("e1", 2, 101, 1, "Cát 1", start.AddDays(1), 120)],
            [],
            []));
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var response = await client.GetFromJsonAsync<MaterialReportResponse>(
            "/api/material-reports?branchId=10&from=2026-08-01T00:00:00%2B07:00&to=2026-08-31T23:59:59%2B07:00",
            BranchTestSupport.JsonOptions);

        Assert.NotNull(response);
        Assert.Equal(150m, response.Totals.ImportQuantityKg);
        Assert.Equal(120m, response.Totals.ExportQuantityKg);
        Assert.Equal(30m, response.Totals.InventoryQuantityKg);
        Assert.Equal(400_000m, response.Totals.ExportValueVnd);
        Assert.Equal(150_000m, response.Totals.InventoryValueVnd);
        var summary = Assert.Single(response.Transactions);
        Assert.Equal("summary-export", summary.Type);
        Assert.Equal(120m, summary.ExportQuantityKg);
        Assert.Equal(400_000m, summary.ValueVnd);
        Assert.Equal(10, factory.MaterialReportDataSource.SeenTargets.Single().BranchId);
    }

    [Fact]
    public async Task BaoCao_DieuChinhXuatAm_SuaKhoiLuongNhungGiuNguyenGiaTriFifo()
    {
        var identity = await ResetAndSeedAsync(
            SystemRoleCodes.Company,
            1,
            null,
            ActiveKeyPermission.View);
        var start = new DateTime(2026, 8, 1);
        factory.MaterialReportDataSource.SetSnapshot(new MaterialReportSnapshot(
            [new MaterialDefinition(101, 1, 1, "Cát 1")],
            [new MaterialImportLot("i1", 1, 101, "Cát 1", start, 100, 4_000)],
            [
                new MaterialIssueEvent("e1", 2, 101, 1, "Cát 1", start.AddDays(1), 50),
                new MaterialIssueEvent(
                    "e-adjust",
                    3,
                    101,
                    1,
                    "Cát 1",
                    start.AddDays(2),
                    -10,
                    "manual:2",
                    IsQuantityOnlyAdjustment: true)
            ],
            [],
            []));
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var response = await client.GetFromJsonAsync<MaterialReportResponse>(
            "/api/material-reports?branchId=10&from=2026-08-01T00:00:00%2B07:00&to=2026-08-31T23:59:59%2B07:00",
            BranchTestSupport.JsonOptions);

        Assert.NotNull(response);
        Assert.Equal(40m, response.Totals.ExportQuantityKg);
        Assert.Equal(60m, response.Totals.InventoryQuantityKg);
        Assert.Equal(200_000m, response.Totals.ExportValueVnd);
        Assert.Equal(200_000m, response.Totals.InventoryValueVnd);
        var summary = Assert.Single(response.Transactions);
        Assert.Equal(40m, summary.ExportQuantityKg);
        Assert.Equal(200_000m, summary.ValueVnd);
    }

    [Fact]
    public async Task RoleCapDuoi_ChiDuocDocTramTrongBranchIds()
    {
        var identity = await ResetAndSeedAsync(
            "QUANLY",
            1,
            "10",
            ActiveKeyPermission.View);
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var stations = await client.GetFromJsonAsync<MaterialReportStationResponse[]>(
            "/api/material-reports/stations",
            BranchTestSupport.JsonOptions);
        var denied = await client.GetAsync(
            "/api/material-reports?branchId=20&from=2026-08-01T00:00:00%2B07:00&to=2026-08-31T23:59:59%2B07:00");

        Assert.Equal(10, Assert.Single(stations!).Id);
        Assert.Equal(HttpStatusCode.Forbidden, denied.StatusCode);
        Assert.Equal(0, factory.MaterialReportDataSource.CallCount);
    }

    [Fact]
    public async Task LocNhomVaLoaiPhieu_ThucHienTruocPhanTrang()
    {
        var identity = await ResetAndSeedAsync(
            SystemRoleCodes.Company,
            1,
            null,
            ActiveKeyPermission.View);
        var start = new DateTime(2026, 8, 1);
        var sandDetail = new MaterialTransactionDetailData(101, "Cát 1", 10, 4_000, null, null, null);
        var stoneDetail = new MaterialTransactionDetailData(201, "Đá 1", 20, 3_000, null, null, null);
        var transactions = Enumerable.Range(1, 12)
            .Select(index => new MaterialTransactionData(
                $"import:{index}",
                start.AddHours(index),
                MaterialReportViewModes.Import,
                $"Phiếu {index}",
                [index % 2 == 0 ? sandDetail : stoneDetail]))
            .Append(new MaterialTransactionData(
                "export:1",
                start.AddHours(20),
                MaterialReportViewModes.Export,
                "Phiếu xuất",
                [sandDetail]))
            .ToArray();
        factory.MaterialReportDataSource.SetSnapshot(new MaterialReportSnapshot(
            [
                new MaterialDefinition(101, 1, 1, "Cát 1"),
                new MaterialDefinition(201, 2, 2, "Đá 1")
            ],
            [],
            [],
            transactions,
            []));
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var response = await client.GetFromJsonAsync<MaterialReportResponse>(
            "/api/material-reports?branchId=10&from=2026-08-01T00:00:00%2B07:00&to=2026-08-31T23:59:59%2B07:00&materialGroup=sand&viewMode=import",
            BranchTestSupport.JsonOptions);

        Assert.NotNull(response);
        Assert.Equal(6, response.TotalCount);
        Assert.Equal(1, response.TotalPages);
        Assert.Equal(6, response.Transactions.Count);
        Assert.All(response.Transactions, item => Assert.Equal(MaterialReportViewModes.Import, item.Type));
        Assert.All(response.Transactions, item => Assert.Equal(101, Assert.Single(item.Details).MaterialCode));
        Assert.DoesNotContain(response.Transactions, item => item.Type == "summary-export");
    }

    private async Task<BranchTestIdentity> ResetAndSeedAsync(
        string roleCode,
        int? companyId,
        string? branchIds,
        params ActiveKeyPermission[] permissions)
    {
        BranchTestIdentity identity = null!;
        await factory.ResetDatabaseAsync(async (services, authDbContext) =>
        {
            identity = await BranchTestSupport.SeedMaterialReportIdentityAsync(
                services,
                authDbContext,
                roleCode,
                companyId,
                branchIds,
                permissions);
            var companyDbContext = services.GetRequiredService<CompanyDbContext>();
            companyDbContext.Companies.AddRange(
                BranchTestSupport.CreateCompany(1, "CT_1", "Công ty 1"),
                BranchTestSupport.CreateCompany(2, "CT_2", "Công ty 2"));
            companyDbContext.Branches.AddRange(
                BranchTestSupport.CreateBranch(10, 1, "TRAM_10", "Trạm 10"),
                BranchTestSupport.CreateBranch(11, 1, "TRAM_CAN", "Trạm cân", typeTram: 2),
                BranchTestSupport.CreateBranch(12, 1, "TRAM_XOA", "Trạm xóa", status: WebDataStatus.Inactive),
                BranchTestSupport.CreateBranch(20, 2, "TRAM_20", "Trạm 20"));
            await companyDbContext.SaveChangesAsync();
        });
        return identity;
    }
}
