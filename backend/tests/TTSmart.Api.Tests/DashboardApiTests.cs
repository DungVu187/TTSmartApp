using System.Net;
using System.Net.Http.Json;
using Microsoft.Extensions.DependencyInjection;
using TTSmart.Api.Data.Company;
using TTSmart.Api.Data.WebAuth;
using TTSmart.Api.Features.Authorization;
using TTSmart.Api.Features.Dashboard;
using TTSmart.Api.Features.OrderStatistics;

namespace TTSmart.Api.Tests;

public sealed class DashboardApiTests(TTSmartApiFactory factory) : IClassFixture<TTSmartApiFactory>
{
    private const string TimeQuery =
        "from=2026-08-12T00%3A00%3A00%2B07%3A00&to=2026-08-13T00%3A00%3A00%2B07%3A00&interval=hour";
    private const string TodayTimeQuery =
        "from=2026-08-13T00%3A00%3A00%2B07%3A00&to=2026-08-14T00%3A00%3A00%2B07%3A00&interval=hour";

    [Fact]
    public async Task ChuaDangNhap_Tra401()
    {
        await factory.ResetDatabaseAsync();
        using var client = factory.CreateClient();

        Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync(
            "/api/dashboard?companyId=1&" + TimeQuery)).StatusCode);
    }

    [Fact]
    public async Task Admin_LayPhamViDashboard_TraCongTyVaTramTheoThuTu()
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
            await SeedCompanyAndBranchesAsync(services);
        });
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var scopes = await client.GetFromJsonAsync<IReadOnlyList<DashboardScopeResponse>>(
            "/api/dashboard/scopes",
            BranchTestSupport.JsonOptions);

        Assert.NotNull(scopes);
        Assert.Collection(
            scopes,
            scope =>
            {
                Assert.Equal("company-1", scope.KeyName);
                Assert.Equal("Công ty 1", scope.Label);
                Assert.Equal("company", scope.Type);
            },
            scope =>
            {
                Assert.Equal("company-2", scope.KeyName);
                Assert.Equal("Công ty 2", scope.Label);
                Assert.Equal("company", scope.Type);
            },
            scope =>
            {
                Assert.Equal("station-10", scope.KeyName);
                Assert.Equal("Trạm 10", scope.Label);
                Assert.Equal("station", scope.Type);
            },
            scope =>
            {
                Assert.Equal("station-20", scope.KeyName);
                Assert.Equal("Trạm 20", scope.Label);
                Assert.Equal("station", scope.Type);
            });
    }

    [Fact]
    public async Task SuperAdmin_KhongChonCongTyTram_TongHopTatCaTramTrongHomNay()
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
            await SeedCompanyAndBranchesAsync(services);
        });
        factory.OrderStatisticsDataSource.SetDashboardData(new OrderStatisticsDashboardData(
            7,
            ["M300", "M350"],
            ["51C-12345"],
            ["Nguyen Van A"],
            5.2,
            [new OrderStatisticsDashboardBucket(new DateTime(2026, 8, 13, 6, 0, 0), 5.2)]));
        factory.OrderReportDataSource.Seed(
            10,
            CreateOrder(1, new DateTime(2026, 8, 5), "Nguyễn Văn A"),
            CreateOrder(2, new DateTime(2026, 8, 5), "Nguyễn Văn A"),
            CreateOrder(3, new DateTime(2026, 8, 5), "Nguyễn Văn A"),
            CreateOrder(4, new DateTime(2026, 8, 5), "Nguyễn Văn A"),
            CreateOrder(5, new DateTime(2026, 8, 5), "Nguyễn Văn A"),
            CreateOrder(6, new DateTime(2026, 8, 5), "Nguyễn Văn A"),
            CreateOrder(7, new DateTime(2026, 8, 13, 3, 0, 0), "Nguyễn Văn A"),
            CreateOrder(8, new DateTime(2026, 7, 31), "Nguyễn Văn A"));
        factory.OrderReportDataSource.Seed(
            20,
            CreateOrder(11, new DateTime(2026, 8, 6), "Trần Văn B"),
            CreateOrder(12, new DateTime(2026, 8, 6), "Trần Văn B"),
            CreateOrder(13, new DateTime(2026, 8, 6), "Trần Văn B"),
            CreateOrder(14, new DateTime(2026, 8, 6), "Trần Văn B"),
            CreateOrder(15, new DateTime(2026, 8, 6), "Trần Văn B"),
            CreateOrder(16, new DateTime(2026, 8, 6), "Trần Văn B"),
            CreateOrder(17, new DateTime(2026, 8, 13, 4, 0, 0), "Trần Văn B"),
            CreateOrder(18, new DateTime(2026, 9, 1), "Trần Văn B"));
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var response = await client.GetFromJsonAsync<DashboardResponse>(
            "/api/dashboard?" + TodayTimeQuery,
            BranchTestSupport.JsonOptions);

        Assert.NotNull(response);
        Assert.Equal(2, response.OrderCount);
        Assert.Equal(2, response.ConcreteGradeCount);
        Assert.Equal(1, response.MixerTruckCount);
        Assert.Equal(2, response.SalesEmployeeCount);
        Assert.Equal(10.4m, response.TotalMixedVolume);
        Assert.Equal(10.4m, response.VolumePoints.Single(point => point.Label == "06H").MixedVolume);
        Assert.Equal(10.4m, response.VolumePoints.Sum(point => point.MixedVolume));
        Assert.Equal(2, response.Stations.Count);
        Assert.All(response.Stations, station =>
        {
            Assert.True(station.IsAvailable);
            Assert.Equal(7, station.OrderCount);
            Assert.Equal(5.2m, station.MixedVolume);
        });
        Assert.Equal(2, factory.OrderStatisticsDataSource.DashboardCallCount);
        Assert.Equal(
            new[] { 10, 20 },
            factory.OrderStatisticsDataSource.SeenTargets
                .Select(target => target.BranchId)
                .Distinct()
                .OrderBy(branchId => branchId));
        Assert.Equal(2, factory.OrderStatisticsDataSource.SeenFilters.Count);
        Assert.All(factory.OrderStatisticsDataSource.SeenFilters, filter =>
        {
            Assert.Equal(new DateTime(2026, 8, 13, 0, 0, 0), filter.FromInclusive);
            Assert.Equal(new DateTime(2026, 8, 14, 0, 0, 0).AddTicks(-1), filter.ToExclusive);
            Assert.True(filter.UseFinishedAtInclusive);
        });
        Assert.Equal(2, factory.OrderReportDataSource.SeenDashboardMetricRanges.Count);
        Assert.Equal(
            2,
            factory.OrderReportDataSource.SeenDashboardMetricRanges.Count(range =>
                range.From == new DateTime(2026, 8, 13) &&
                range.To == new DateTime(2026, 8, 14)));
        Assert.Equal(2, factory.OrderStatisticsDataSource.SeenDashboardMetricFilters.Count);
        Assert.All(factory.OrderStatisticsDataSource.SeenDashboardMetricFilters, filter =>
        {
            Assert.Equal(new DateTime(2026, 8, 13), filter.FromInclusive);
            Assert.Equal(new DateTime(2026, 8, 14).AddTicks(-1), filter.ToExclusive);
            Assert.True(filter.UseFinishedAtInclusive);
        });
    }

    [Fact]
    public async Task CongTy_TongHopM3MetronTheoGioVaLocPhamVi()
    {
        BranchTestIdentity identity = null!;
        await factory.ResetDatabaseAsync(async (services, authDbContext) =>
        {
            identity = await BranchTestSupport.SeedOrderStatisticsIdentityAsync(
                services,
                authDbContext,
                SystemRoleCodes.Company,
                1,
                null,
                ActiveKeyPermission.DSach);
            await SeedCompanyAndBranchesAsync(services);
        });
        factory.OrderStatisticsDataSource.SetDashboardData(new OrderStatisticsDashboardData(
            7,
            ["M300", "M350"],
            ["51C-12345"],
            ["Nguyễn Văn A"],
            5.2,
            [
                new OrderStatisticsDashboardBucket(new DateTime(2026, 8, 12, 6, 0, 0), 2.6),
                new OrderStatisticsDashboardBucket(new DateTime(2026, 8, 12, 7, 0, 0), 2.6)
            ]));
        factory.OrderReportDataSource.Seed(
            10,
            CreateOrder(1, new DateTime(2026, 8, 5), "Nguyễn Văn A"),
            CreateOrder(2, new DateTime(2026, 8, 5), "Nguyễn Văn A"),
            CreateOrder(3, new DateTime(2026, 8, 5), "Nguyễn Văn A"),
            CreateOrder(4, new DateTime(2026, 8, 5), "Nguyễn Văn A"),
            CreateOrder(5, new DateTime(2026, 8, 5), "Nguyễn Văn A"),
            CreateOrder(6, new DateTime(2026, 8, 5), "Nguyễn Văn A"),
            CreateOrder(7, new DateTime(2026, 8, 13, 3, 0, 0), "Nguyễn Văn A"));
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var response = await client.GetFromJsonAsync<DashboardResponse>(
            "/api/dashboard?companyId=1&branchId=10&" + TimeQuery,
            BranchTestSupport.JsonOptions);

        Assert.NotNull(response);
        Assert.Equal(0, response.OrderCount);
        Assert.Equal(1, response.ConcreteGradeCount);
        Assert.Equal(1, response.MixerTruckCount);
        Assert.Equal(0, response.SalesEmployeeCount);
        Assert.Equal(5.2m, response.TotalMixedVolume);
        Assert.Equal(24, response.VolumePoints.Count);
        Assert.Equal(2.6m, response.VolumePoints.Single(point => point.Label == "06H").MixedVolume);
        Assert.Equal(2.6m, response.VolumePoints.Single(point => point.Label == "07H").MixedVolume);
        Assert.Equal(5.2m, response.VolumePoints.Sum(point => point.MixedVolume));
        var station = Assert.Single(response.Stations);
        Assert.True(station.IsAvailable);
        Assert.Equal(1, station.MixerTruckCount);
        Assert.Equal(
            new[] { 10 },
            factory.OrderStatisticsDataSource.SeenTargets
                .Select(target => target.BranchId)
                .Distinct());
        var filter = Assert.Single(factory.OrderStatisticsDataSource.SeenFilters);
        Assert.Equal(new DateTime(2026, 8, 12, 0, 0, 0), filter.FromInclusive);
        Assert.Equal(new DateTime(2026, 8, 13, 0, 0, 0).AddTicks(-1), filter.ToExclusive);
        Assert.True(filter.UseFinishedAtInclusive);
        var metricRange = Assert.Single(factory.OrderReportDataSource.SeenDashboardMetricRanges);
        Assert.Equal(new DateTime(2026, 8, 12), metricRange.From);
        Assert.Equal(new DateTime(2026, 8, 13), metricRange.To);
        var metricFilter = Assert.Single(factory.OrderStatisticsDataSource.SeenDashboardMetricFilters);
        Assert.Equal(new DateTime(2026, 8, 12), metricFilter.FromInclusive);
        Assert.Equal(new DateTime(2026, 8, 13).AddTicks(-1), metricFilter.ToExclusive);
        Assert.True(metricFilter.UseFinishedAtInclusive);
    }

    [Fact]
    public async Task HomNayKhongCoDon_KhongDemDonCuaNgayKhacTrongThang()
    {
        BranchTestIdentity identity = null!;
        await factory.ResetDatabaseAsync(async (services, authDbContext) =>
        {
            identity = await BranchTestSupport.SeedOrderStatisticsIdentityAsync(
                services,
                authDbContext,
                SystemRoleCodes.Company,
                1,
                null,
                ActiveKeyPermission.DSach);
            await SeedCompanyAndBranchesAsync(services);
        });
        factory.OrderReportDataSource.Seed(
            10,
            CreateOrder(1, new DateTime(2026, 8, 12, 23, 59, 59), "Nguyễn Văn A"));
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var response = await client.GetFromJsonAsync<DashboardResponse>(
            "/api/dashboard?companyId=1&branchId=10&" + TodayTimeQuery,
            BranchTestSupport.JsonOptions);

        Assert.NotNull(response);
        Assert.Equal(0, response.OrderCount);
        Assert.Equal(0, response.SalesEmployeeCount);
        var range = Assert.Single(factory.OrderReportDataSource.SeenDashboardMetricRanges);
        Assert.Equal(new DateTime(2026, 8, 13), range.From);
        Assert.Equal(new DateTime(2026, 8, 14), range.To);
    }

    [Fact]
    public async Task ChonTramNgoaiPhamVi_Tra404VaKhongQueryDatabase()
    {
        BranchTestIdentity identity = null!;
        await factory.ResetDatabaseAsync(async (services, authDbContext) =>
        {
            identity = await BranchTestSupport.SeedOrderStatisticsIdentityAsync(
                services,
                authDbContext,
                SystemRoleCodes.Company,
                1,
                null,
                ActiveKeyPermission.DSach);
            await SeedCompanyAndBranchesAsync(services);
        });
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var response = await client.GetAsync(
            "/api/dashboard?companyId=1&branchId=20&" + TimeQuery);

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        Assert.Equal(0, factory.OrderStatisticsDataSource.DashboardCallCount);
    }

    private static async Task SeedCompanyAndBranchesAsync(IServiceProvider services)
    {
        using var scope = services.CreateScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<CompanyDbContext>();
        dbContext.Companies.AddRange(
            BranchTestSupport.CreateCompany(1, "CT01", "Công ty 1"),
            BranchTestSupport.CreateCompany(2, "CT02", "Công ty 2"));
        dbContext.Branches.AddRange(
            BranchTestSupport.CreateBranch(10, 1, "TRAM10", "Trạm 10"),
            BranchTestSupport.CreateBranch(20, 2, "TRAM20", "Trạm 20"));
        await dbContext.SaveChangesAsync();
    }

    private static TestOrder CreateOrder(int orderId, DateTime orderedAt, string employeeName) =>
        new(orderId, orderedAt, employeeName);
}
