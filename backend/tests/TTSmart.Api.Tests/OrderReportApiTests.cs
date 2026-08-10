using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc;
using TTSmart.Api.Common.Models;
using TTSmart.Api.Data.Company;
using TTSmart.Api.Features.Authorization;
using TTSmart.Api.Features.OrderReporting;
using Microsoft.Extensions.DependencyInjection;

namespace TTSmart.Api.Tests;

public sealed class OrderReportApiTests(TTSmartApiFactory factory) : IClassFixture<TTSmartApiFactory>
{
    [Theory]
    [InlineData("/api/order-reports/stations?companyId=1")]
    [InlineData("/api/order-reports/employees?branchId=10&from=2026-07-31T00%3A00%3A00%2B07%3A00&to=2026-08-01T00%3A00%3A00%2B07%3A00")]
    [InlineData("/api/order-reports?branchId=10&from=2026-07-31T00%3A00%3A00%2B07%3A00&to=2026-07-31T23%3A59%3A59%2B07%3A00")]
    public async Task ChuaDangNhap_Tra401(string requestUri)
    {
        await factory.ResetDatabaseAsync();
        using var client = factory.CreateClient();

        Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync(requestUri)).StatusCode);
    }

    [Fact]
    public async Task KhongCoQuyenBCDH_Tra403()
    {
        BranchTestIdentity identity = null!;
        await factory.ResetDatabaseAsync(async (services, authDbContext) =>
        {
            identity = await BranchTestSupport.SeedIdentityAsync(
                services,
                authDbContext,
                "KINHDOANH",
                1,
                "10");
            var companyDbContext = services.GetRequiredService<CompanyDbContext>();
            companyDbContext.Companies.Add(BranchTestSupport.CreateCompany(1, "CT_1", "Công ty 1"));
            companyDbContext.Branches.Add(BranchTestSupport.CreateBranch(10, 1, "TRAM", "Trạm"));
            await companyDbContext.SaveChangesAsync();
        });
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        Assert.Equal(HttpStatusCode.Forbidden, (await client.GetAsync(
            "/api/order-reports/stations")).StatusCode);
    }

    [Fact]
    public async Task TimKiem_LocNgayNhanVien_TinhTongVaPhanTrang()
    {
        BranchTestIdentity identity = null!;
        await factory.ResetDatabaseAsync(async (services, authDbContext) =>
        {
            identity = await BranchTestSupport.SeedOrderReportIdentityAsync(
                services,
                authDbContext,
                "KINHDOANH",
                1,
                "10",
                ActiveKeyPermission.DSach);
            var companyDbContext = services.GetRequiredService<CompanyDbContext>();
            companyDbContext.Companies.Add(BranchTestSupport.CreateCompany(1, "CT_1", "Công ty 1"));
            companyDbContext.Branches.Add(BranchTestSupport.CreateBranch(10, 1, "TRAM_10", "Trạm 10"));
            await companyDbContext.SaveChangesAsync();
        });
        factory.OrderReportDataSource.Seed(
            10,
            new TestOrder(1, new DateTime(2026, 7, 30, 8, 0, 0), "KD A", "KH 1", "DA 1", "M250", 100, 10),
            new TestOrder(2, new DateTime(2026, 7, 31, 0, 0, 0), "KD B", "KH 2", "DA 2", "M300", 44, 10.333335f),
            new TestOrder(3, new DateTime(2026, 7, 31, 0, 0, 0), "KD A", "KH 3", "DA 3", "M350", 1, 1));

        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var stations = await client.GetFromJsonAsync<OrderReportStationResponse[]>(
            "/api/order-reports/stations",
            BranchTestSupport.JsonOptions);
        Assert.NotNull(stations);
        Assert.Equal([10], stations.Select(item => item.Id).ToArray());

        var employees = await client.GetFromJsonAsync<OrderReportEmployeeResponse[]>(
            "/api/order-reports/employees?branchId=10&from=2026-07-30T00%3A00%3A00%2B07%3A00&to=2026-07-31T00%3A00%3A00%2B07%3A00",
            BranchTestSupport.JsonOptions);
        Assert.NotNull(employees);
        Assert.Equal(["KD A"], employees.Select(item => item.Name).ToArray());

        var report = await client.GetFromJsonAsync<OrderReportResponse>(
            "/api/order-reports?branchId=10&from=2026-07-30T00%3A00%3A00%2B07%3A00&to=2026-07-31T00%3A00%3A00%2B07%3A00&pageNumber=1&pageSize=2",
            BranchTestSupport.JsonOptions);
        Assert.NotNull(report);
        Assert.Equal(2, report.PageSize);
        Assert.Equal(1, report.TotalCount);
        Assert.Equal(1, report.TotalPages);
        Assert.Equal(100m, report.TotalOrderedVolume);
        Assert.Equal(10m, report.TotalProducedVolume);
        Assert.Equal([1], report.Items.Select(item => item.OrderId).ToArray());
        Assert.Equal(DateTimeKind.Utc, report.Items[0].OrderedAtUtc!.Value.Kind);
        Assert.Equal(10, factory.OrderReportDataSource.SeenTargets.Last().BranchId);
        Assert.Equal("TRAM_10_online", factory.OrderReportDataSource.SeenTargets.Last().DatabaseName);

        var employeeReport = await client.GetFromJsonAsync<OrderReportResponse>(
            "/api/order-reports?branchId=10&from=2026-07-30T00%3A00%3A00%2B07%3A00&to=2026-07-31T00%3A00%3A00%2B07%3A00&employeeName=KD%20A&pageSize=10",
            BranchTestSupport.JsonOptions);
        Assert.NotNull(employeeReport);
        Assert.Equal(1, employeeReport.TotalCount);
        Assert.Equal([1], employeeReport.Items.Select(item => item.OrderId).ToArray());
    }

    [Fact]
    public async Task ADMIN_KhongChonCongTyVaTram_TongHopTatCaTram()
    {
        BranchTestIdentity identity = null!;
        await factory.ResetDatabaseAsync(async (services, authDbContext) =>
        {
            identity = await BranchTestSupport.SeedOrderReportIdentityAsync(
                services,
                authDbContext,
                SystemRoleCodes.Admin,
                null,
                null,
                ActiveKeyPermission.DSach);
            var companyDbContext = services.GetRequiredService<CompanyDbContext>();
            companyDbContext.Companies.AddRange(
                BranchTestSupport.CreateCompany(1, "CT_1", "Công ty 1"),
                BranchTestSupport.CreateCompany(2, "CT_2", "Công ty 2"));
            companyDbContext.Branches.AddRange(
                BranchTestSupport.CreateBranch(10, 1, "TRAM_10", "Trạm 10"),
                BranchTestSupport.CreateBranch(20, 2, "TRAM_20", "Trạm 20"));
            await companyDbContext.SaveChangesAsync();
        });
        factory.OrderReportDataSource.Seed(
            10,
            new TestOrder(10, new DateTime(2026, 8, 1, 11, 0, 0), "KD A", "KH 10", "DA 10", "M250", 10, 4));
        factory.OrderReportDataSource.Seed(
            20,
            new TestOrder(20, new DateTime(2026, 8, 1, 10, 0, 0), "KD B", "KH 20", "DA 20", "M300", 20, 8));

        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var stations = await client.GetFromJsonAsync<OrderReportStationResponse[]>(
            "/api/order-reports/stations",
            BranchTestSupport.JsonOptions);
        Assert.NotNull(stations);
        Assert.Equal([10, 20], stations.Select(item => item.Id).ToArray());

        var employees = await client.GetFromJsonAsync<OrderReportEmployeeResponse[]>(
            "/api/order-reports/employees?from=2026-08-01T00%3A00%3A00%2B07%3A00&to=2026-08-02T00%3A00%3A00%2B07%3A00",
            BranchTestSupport.JsonOptions);
        Assert.NotNull(employees);
        Assert.Equal(["KD A", "KD B"], employees.Select(item => item.Name).ToArray());

        var report = await client.GetFromJsonAsync<OrderReportResponse>(
            "/api/order-reports?from=2026-08-01T00%3A00%3A00%2B07%3A00&to=2026-08-02T00%3A00%3A00%2B07%3A00&pageNumber=1&pageSize=1",
            BranchTestSupport.JsonOptions);
        Assert.NotNull(report);
        Assert.Equal(2, report.TotalCount);
        Assert.Equal(2, report.TotalPages);
        Assert.Equal(30m, report.TotalOrderedVolume);
        Assert.Equal(12m, report.TotalProducedVolume);
        Assert.Equal([10], report.Items.Select(item => item.OrderId).ToArray());
        Assert.Equal([10, 20], report.StationSummaries.Select(item => item.BranchId).ToArray());
        Assert.Equal([10m, 20m], report.StationSummaries.Select(item => item.OrderedVolume).ToArray());

        var secondPage = await client.GetFromJsonAsync<OrderReportResponse>(
            "/api/order-reports?from=2026-08-01T00%3A00%3A00%2B07%3A00&to=2026-08-02T00%3A00%3A00%2B07%3A00&pageNumber=2&pageSize=1",
            BranchTestSupport.JsonOptions);
        Assert.NotNull(secondPage);
        Assert.Equal([20], secondPage.Items.Select(item => item.OrderId).ToArray());
        Assert.Equal(report.TotalCount, secondPage.TotalCount);
        Assert.Equal(report.TotalOrderedVolume, secondPage.TotalOrderedVolume);
        Assert.Equal(report.TotalProducedVolume, secondPage.TotalProducedVolume);
        Assert.Equal([10, 20], factory.OrderReportDataSource.SeenTargets
            .Where(target => target.BranchId is 10 or 20)
            .Select(target => target.BranchId)
            .Distinct()
            .OrderBy(branchId => branchId)
            .ToArray());
    }

    [Fact]
    public async Task ADMIN_TongHopBoQuaTramKhongTruyCapDuoc_VaTraDuLieuTramConLai()
    {
        BranchTestIdentity identity = null!;
        await factory.ResetDatabaseAsync(async (services, authDbContext) =>
        {
            identity = await BranchTestSupport.SeedOrderReportIdentityAsync(
                services,
                authDbContext,
                SystemRoleCodes.Admin,
                null,
                null,
                ActiveKeyPermission.DSach);
            var companyDbContext = services.GetRequiredService<CompanyDbContext>();
            companyDbContext.Companies.Add(BranchTestSupport.CreateCompany(
                1,
                nameof(OrderReportApiTests),
                nameof(OrderReportApiTests)));
            companyDbContext.Branches.AddRange(
                BranchTestSupport.CreateBranch(10, 1, nameof(OrderReportApiTests), nameof(OrderReportApiTests)),
                BranchTestSupport.CreateBranch(20, 1, nameof(OrderReportApiTests), nameof(OrderReportApiTests)));
            await companyDbContext.SaveChangesAsync();
        });
        factory.OrderReportDataSource.Seed(
            10,
            new TestOrder(
                10,
                new DateTime(2026, 8, 1, 11, 0, 0),
                nameof(OrderReportApiTests),
                nameof(OrderReportApiTests),
                nameof(OrderReportApiTests),
                nameof(OrderReportApiTests),
                10,
                4));
        factory.StationDatabaseAvailabilityResolver.SetUnavailable(20);

        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var employeesResponse = await client.GetAsync(
            "/api/order-reports/employees?from=2026-08-01T00%3A00%3A00%2B07%3A00&to=2026-08-02T00%3A00%3A00%2B07%3A00");
        Assert.Equal(HttpStatusCode.OK, employeesResponse.StatusCode);
        var employees = await employeesResponse.Content.ReadFromJsonAsync<
            OrderReportEmployeeResponse[]>(BranchTestSupport.JsonOptions);
        Assert.NotNull(employees);
        Assert.Equal([nameof(OrderReportApiTests)], employees.Select(item => item.Name).ToArray());

        var report = await client.GetFromJsonAsync<OrderReportResponse>(
            "/api/order-reports?from=2026-08-01T00%3A00%3A00%2B07%3A00&to=2026-08-02T00%3A00%3A00%2B07%3A00",
            BranchTestSupport.JsonOptions);
        Assert.NotNull(report);
        Assert.True(report.IsPartial);
        Assert.Equal(1, report.SuccessfulStationCount);
        Assert.Equal(1, report.UnavailableStationCount);
        Assert.Equal([20], report.UnavailableStations.Select(item => item.BranchId).ToArray());
        Assert.Equal(1, report.TotalCount);
        Assert.Equal([10], report.StationSummaries.Select(item => item.BranchId).ToArray());
        Assert.Equal([10], report.Items.Select(item => item.BranchId).ToArray());
        Assert.DoesNotContain(
            factory.OrderReportDataSource.SeenTargets,
            target => target.BranchId == 20);
    }

    [Fact]
    public async Task ADMIN_ChonCongTyKhongChonTram_ChiTongHopTramCuaCongTy()
    {
        BranchTestIdentity identity = null!;
        await factory.ResetDatabaseAsync(async (services, authDbContext) =>
        {
            identity = await BranchTestSupport.SeedOrderReportIdentityAsync(
                services,
                authDbContext,
                SystemRoleCodes.Admin,
                null,
                null,
                ActiveKeyPermission.DSach);
            var companyDbContext = services.GetRequiredService<CompanyDbContext>();
            companyDbContext.Companies.AddRange(
                BranchTestSupport.CreateCompany(1, "CT_1", "Công ty 1"),
                BranchTestSupport.CreateCompany(2, "CT_2", "Công ty 2"));
            companyDbContext.Branches.AddRange(
                BranchTestSupport.CreateBranch(10, 1, "TRAM_10", "Trạm 10"),
                BranchTestSupport.CreateBranch(20, 2, "TRAM_20", "Trạm 20"));
            await companyDbContext.SaveChangesAsync();
        });
        factory.OrderReportDataSource.Seed(
            10,
            new TestOrder(10, new DateTime(2026, 8, 1, 11, 0, 0), "KD A", OrderedVolume: 10, ProducedVolume: 4));
        factory.OrderReportDataSource.Seed(
            20,
            new TestOrder(20, new DateTime(2026, 8, 1, 10, 0, 0), "KD B", OrderedVolume: 20, ProducedVolume: 8));

        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var report = await client.GetFromJsonAsync<OrderReportResponse>(
            "/api/order-reports?companyId=1&from=2026-08-01T00%3A00%3A00%2B07%3A00&to=2026-08-02T00%3A00%3A00%2B07%3A00",
            BranchTestSupport.JsonOptions);
        Assert.NotNull(report);
        Assert.Equal(1, report.TotalCount);
        Assert.Equal([10], report.Items.Select(item => item.OrderId).ToArray());
        Assert.Equal([10], report.StationSummaries.Select(item => item.BranchId).ToArray());
        Assert.DoesNotContain(factory.OrderReportDataSource.SeenTargets, target => target.BranchId == 20);
    }

    [Fact]
    public async Task TimKiem_RequestSaiTra400_VaKhongCoDuLieuTraTrangRong()
    {
        BranchTestIdentity identity = null!;
        await factory.ResetDatabaseAsync(async (services, authDbContext) =>
        {
            identity = await BranchTestSupport.SeedOrderReportIdentityAsync(
                services,
                authDbContext,
                "KINHDOANH",
                1,
                "10",
                ActiveKeyPermission.DSach);
            var companyDbContext = services.GetRequiredService<CompanyDbContext>();
            companyDbContext.Companies.Add(BranchTestSupport.CreateCompany(1, "CT_1", "Công ty 1"));
            companyDbContext.Branches.Add(BranchTestSupport.CreateBranch(10, 1, "TRAM", "Trạm"));
            await companyDbContext.SaveChangesAsync();
        });
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        Assert.Equal(HttpStatusCode.BadRequest, (await client.GetAsync(
            "/api/order-reports?branchId=10&to=2026-07-31T23%3A59%3A59%2B07%3A00")).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await client.GetAsync(
            "/api/order-reports/employees?branchId=10&to=2026-08-01T00%3A00%3A00%2B07%3A00")).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await client.GetAsync(
            "/api/order-reports/employees?branchId=10&from=2026-08-01T00%3A00%3A00%2B07%3A00&to=2026-07-31T00%3A00%3A00%2B07%3A00")).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await client.GetAsync(
            "/api/order-reports?branchId=10&from=2026-08-01T00%3A00%3A00%2B07%3A00&to=2026-07-31T23%3A59%3A59%2B07%3A00")).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await client.GetAsync(
            "/api/order-reports?branchId=10&from=2026-07-31T00%3A00%3A00%2B07%3A00&to=2026-07-31T23%3A59%3A59%2B07%3A00&pageSize=101")).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await client.GetAsync(
            "/api/order-reports?branchId=10&from=2026-07-31T00%3A00%3A00%2B07%3A00&to=2026-07-31T23%3A59%3A59%2B07%3A00&pageNumber=2147483647&pageSize=100")).StatusCode);

        var report = await client.GetFromJsonAsync<OrderReportResponse>(
            "/api/order-reports?branchId=10&from=2026-07-31T00%3A00%3A00%2B07%3A00&to=2026-07-31T23%3A59%3A59%2B07%3A00",
            BranchTestSupport.JsonOptions);
        Assert.NotNull(report);
        Assert.Empty(report.Items);
        Assert.Equal(0, report.TotalCount);
        Assert.Equal(0, report.TotalPages);
        Assert.Equal(0m, report.TotalOrderedVolume);
        Assert.Equal(0m, report.TotalProducedVolume);
    }

    [Fact]
    public async Task PhanQuyen_BCDH_KhongPhuThuocQuyenQLTT_VaChanCheoTram()
    {
        BranchTestIdentity identity = null!;
        await factory.ResetDatabaseAsync(async (services, authDbContext) =>
        {
            identity = await BranchTestSupport.SeedOrderReportIdentityAsync(
                services,
                authDbContext,
                "QUANLY",
                1,
                "10",
                ActiveKeyPermission.DSach);
            var companyDbContext = services.GetRequiredService<CompanyDbContext>();
            companyDbContext.Companies.AddRange(
                BranchTestSupport.CreateCompany(1, "CT_1", "Công ty 1"),
                BranchTestSupport.CreateCompany(2, "CT_2", "Công ty 2"));
            companyDbContext.Branches.AddRange(
                BranchTestSupport.CreateBranch(10, 1, "OWN", "Trạm được gán"),
                BranchTestSupport.CreateBranch(20, 2, "OTHER", "Trạm ngoài phạm vi"),
                BranchTestSupport.CreateBranch(21, 1, "WEIGH", "Trạm cân", typeTram: 2));
            await companyDbContext.SaveChangesAsync();
        });
        factory.OrderReportDataSource.Seed(10);
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        Assert.Equal(HttpStatusCode.NotFound, (await client.GetAsync(
            "/api/order-reports/employees?branchId=20&from=2026-07-31T00%3A00%3A00%2B07%3A00&to=2026-08-01T00%3A00%3A00%2B07%3A00")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await client.GetAsync(
            "/api/order-reports/employees?branchId=21&from=2026-07-31T00%3A00%3A00%2B07%3A00&to=2026-08-01T00%3A00%3A00%2B07%3A00")).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await client.GetAsync(
            "/api/order-reports/employees?branchId=10&from=2026-07-31T00%3A00%3A00%2B07%3A00&to=2026-08-01T00%3A00%3A00%2B07%3A00")).StatusCode);
    }

    [Fact]
    public async Task ADMIN_CoTheXemTatCaHoacLocCongTy_VaCONGTYChiThayTramCuaMinh()
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
            companyDbContext.Branches.AddRange(
                BranchTestSupport.CreateBranch(10, 1, "ONE", "Trạm 1"),
                BranchTestSupport.CreateBranch(20, 2, "TWO", "Trạm 2"));
            await companyDbContext.SaveChangesAsync();
        });
        using var adminClient = factory.CreateClient();
        await BranchTestSupport.LoginAsync(adminClient, admin);
        var allAdminStations = await adminClient.GetFromJsonAsync<OrderReportStationResponse[]>(
            "/api/order-reports/stations",
            BranchTestSupport.JsonOptions);
        Assert.NotNull(allAdminStations);
        Assert.Equal([10, 20], allAdminStations.Select(item => item.Id).ToArray());
        var adminStations = await adminClient.GetFromJsonAsync<OrderReportStationResponse[]>(
            "/api/order-reports/stations?companyId=2",
            BranchTestSupport.JsonOptions);
        Assert.NotNull(adminStations);
        Assert.Equal([20], adminStations.Select(item => item.Id).ToArray());

        BranchTestIdentity companyUser = null!;
        await factory.ResetDatabaseAsync(async (services, authDbContext) =>
        {
            companyUser = await BranchTestSupport.SeedOrderReportIdentityAsync(
                services,
                authDbContext,
                SystemRoleCodes.Company,
                1,
                null,
                ActiveKeyPermission.DSach);
            var companyDbContext = services.GetRequiredService<CompanyDbContext>();
            companyDbContext.Companies.AddRange(
                BranchTestSupport.CreateCompany(1, "CT_1", "Công ty 1"),
                BranchTestSupport.CreateCompany(2, "CT_2", "Công ty 2"));
            companyDbContext.Branches.AddRange(
                BranchTestSupport.CreateBranch(10, 1, "ONE", "Trạm 1"),
                BranchTestSupport.CreateBranch(20, 2, "TWO", "Trạm 2"));
            await companyDbContext.SaveChangesAsync();
        });
        using var companyClient = factory.CreateClient();
        await BranchTestSupport.LoginAsync(companyClient, companyUser);
        var ownStations = await companyClient.GetFromJsonAsync<OrderReportStationResponse[]>(
            "/api/order-reports/stations",
            BranchTestSupport.JsonOptions);
        Assert.NotNull(ownStations);
        Assert.Equal([10], ownStations.Select(item => item.Id).ToArray());
        Assert.Equal(HttpStatusCode.Forbidden, (await companyClient.GetAsync(
            "/api/order-reports/stations?companyId=2")).StatusCode);
    }

    [Fact]
    public async Task CONGTY_ThieuCompanyId_KhongDuocFallbackSangBranchId()
    {
        BranchTestIdentity identity = null!;
        await factory.ResetDatabaseAsync(async (services, authDbContext) =>
        {
            identity = await BranchTestSupport.SeedOrderReportIdentityAsync(
                services,
                authDbContext,
                SystemRoleCodes.Company,
                null,
                "10",
                ActiveKeyPermission.DSach);
            var companyDbContext = services.GetRequiredService<CompanyDbContext>();
            companyDbContext.Companies.Add(BranchTestSupport.CreateCompany(1, "CT_1", "Công ty 1"));
            companyDbContext.Branches.Add(BranchTestSupport.CreateBranch(10, 1, "ONE", "Trạm 1"));
            await companyDbContext.SaveChangesAsync();
        });
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var stations = await client.GetFromJsonAsync<OrderReportStationResponse[]>(
            "/api/order-reports/stations",
            BranchTestSupport.JsonOptions);
        Assert.NotNull(stations);
        Assert.Empty(stations);
        Assert.Equal(HttpStatusCode.NotFound, (await client.GetAsync(
            "/api/order-reports/employees?branchId=10&from=2026-07-31T00%3A00%3A00%2B07%3A00&to=2026-08-01T00%3A00%3A00%2B07%3A00")).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await client.GetAsync(
            "/api/order-reports?from=2026-07-31T00%3A00%3A00%2B07%3A00&to=2026-07-31T23%3A59%3A59%2B07%3A00")).StatusCode);
    }

    [Fact]
    public async Task DatabaseTramKhongTruyCapDuoc_Tra503()
    {
        BranchTestIdentity identity = null!;
        await factory.ResetDatabaseAsync(async (services, authDbContext) =>
        {
            identity = await BranchTestSupport.SeedOrderReportIdentityAsync(
                services,
                authDbContext,
                "QUANLY",
                1,
                "10",
                ActiveKeyPermission.DSach);
            var companyDbContext = services.GetRequiredService<CompanyDbContext>();
            companyDbContext.Companies.Add(BranchTestSupport.CreateCompany(1, "CT_1", "Công ty 1"));
            companyDbContext.Branches.Add(BranchTestSupport.CreateBranch(10, 1, "TRAM", "Trạm"));
            await companyDbContext.SaveChangesAsync();
        });
        factory.OrderReportDataSource.SetUnavailable(10);
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var response = await client.GetAsync(
            "/api/order-reports?branchId=10&from=2026-07-31T00%3A00%3A00%2B07%3A00&to=2026-07-31T23%3A59%3A59%2B07%3A00");
        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
        var body = await response.Content.ReadAsStringAsync();
        var problem = JsonSerializer.Deserialize<ProblemDetails>(body, BranchTestSupport.JsonOptions);
        Assert.NotNull(problem);
        Assert.Equal((int)HttpStatusCode.ServiceUnavailable, problem.Status);
        Assert.DoesNotContain("SqlException", body, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("TRAM_online", body, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("should-not-leak", body, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task OpenApi_KhopRouteVaMaLoiOrderReport()
    {
        await factory.ResetDatabaseAsync();
        using var client = factory.CreateClient();

        var response = await client.GetAsync("/openapi/v1.json");
        response.EnsureSuccessStatusCode();
        using var document = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
        var paths = document.RootElement.GetProperty("paths");

        AssertResponses(paths.GetProperty("/api/order-reports/stations").GetProperty("get"),
            "200", "400", "401", "403");
        AssertResponses(paths.GetProperty("/api/order-reports/employees").GetProperty("get"),
            "200", "400", "401", "403", "404", "503");
        AssertResponses(paths.GetProperty("/api/order-reports").GetProperty("get"),
            "200", "400", "401", "403", "404", "503");
    }

    private static void AssertResponses(JsonElement operation, params string[] statusCodes)
    {
        Assert.True(operation.TryGetProperty("security", out var security));
        Assert.NotEqual(0, security.GetArrayLength());
        var responses = operation.GetProperty("responses");
        foreach (var statusCode in statusCodes)
        {
            Assert.True(responses.TryGetProperty(statusCode, out _), $"Thiếu response {statusCode} trong OpenAPI.");
        }
    }
}
