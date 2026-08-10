using System.Net;
using System.Net.Http.Json;
using Microsoft.Extensions.DependencyInjection;
using TTSmart.Api.Data.Company;
using TTSmart.Api.Features.Authorization;
using TTSmart.Api.Features.OrderReporting;

namespace TTSmart.Api.Tests;

public sealed class OrderReportSqlApiTests
{
    [Fact]
    public async Task ThieuStationConnection_EndpointTra503ThayViDungAuthConnection()
    {
        await using var factory = new SqlOrderReportApiFactory();
        var identity = await SeedOrderReportScopeAsync(factory);
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var response = await client.GetAsync(
            "/api/order-reports/employees?branchId=10&from=2024-10-01T00%3A00%3A00%2B07%3A00&to=2024-11-01T00%3A00%3A00%2B07%3A00");

        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
        var body = await response.Content.ReadAsStringAsync();
        Assert.DoesNotContain("AuthConnection", body, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("TTSmartMobile_Dev", body, StringComparison.OrdinalIgnoreCase);
    }

    [SqlE2EFact]
    [Trait("Category", "SqlE2E")]
    public async Task FullHttpE2E_DocDuLieuReadOnlyTuQuanLyTaiTramLocal()
    {
        var stationConnection = Environment.GetEnvironmentVariable(
            SqlE2EFactAttribute.StationConnectionEnvironmentVariable)!;

        await using var factory = new SqlOrderReportApiFactory(
            stationConnection,
            mapSampleDatabase: true);
        var identity = await SeedOrderReportScopeAsync(factory);
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var stations = await client.GetFromJsonAsync<OrderReportStationResponse[]>(
            "/api/order-reports/stations",
            BranchTestSupport.JsonOptions);
        Assert.NotNull(stations);
        Assert.Equal([10], stations.Select(item => item.Id).ToArray());

        var employees = await client.GetFromJsonAsync<OrderReportEmployeeResponse[]>(
            "/api/order-reports/employees?branchId=10&from=2024-10-01T00%3A00%3A00%2B07%3A00&to=2024-11-01T00%3A00%3A00%2B07%3A00",
            BranchTestSupport.JsonOptions);
        Assert.NotNull(employees);

        var report = await client.GetFromJsonAsync<OrderReportResponse>(
            "/api/order-reports?branchId=10&from=2024-10-01T00%3A00%3A00%2B07%3A00&to=2024-11-01T00%3A00%3A00%2B07%3A00&pageSize=2",
            BranchTestSupport.JsonOptions);
        Assert.NotNull(report);
        Assert.True(report.TotalCount > 0);
        Assert.Equal((int)Math.Ceiling(report.TotalCount / 2d), report.TotalPages);
        Assert.Equal(Math.Min(2, report.TotalCount), report.Items.Count);
        Assert.True(report.TotalOrderedVolume >= 0);
        Assert.True(report.TotalProducedVolume >= 0);
        Assert.All(report.Items, item => Assert.Equal(10, item.BranchId));
        var stationSummary = Assert.Single(report.StationSummaries);
        Assert.Equal(report.TotalCount, stationSummary.OrderCount);
        Assert.Equal(report.TotalOrderedVolume, stationSummary.OrderedVolume);
        Assert.Equal(report.TotalProducedVolume, stationSummary.ProducedVolume);

        var allItems = new List<OrderReportItemResponse>();
        for (var pageNumber = 1; pageNumber <= report.TotalPages; pageNumber++)
        {
            var page = await client.GetFromJsonAsync<OrderReportResponse>(
                $"/api/order-reports?branchId=10&from=2024-10-01T00%3A00%3A00%2B07%3A00&to=2024-11-01T00%3A00%3A00%2B07%3A00&pageNumber={pageNumber}&pageSize=2",
                BranchTestSupport.JsonOptions);
            Assert.NotNull(page);
            Assert.Equal(report.TotalCount, page.TotalCount);
            Assert.Equal(report.TotalOrderedVolume, page.TotalOrderedVolume);
            Assert.Equal(report.TotalProducedVolume, page.TotalProducedVolume);
            allItems.AddRange(page.Items);
        }

        Assert.Equal(report.TotalCount, allItems.Count);
        Assert.Equal(report.TotalOrderedVolume, allItems.Sum(item => item.OrderedVolume ?? 0));
        Assert.Equal(report.TotalProducedVolume, allItems.Sum(item => item.ProducedVolume ?? 0));
        Assert.Equal(
            allItems.OrderByDescending(item => item.OrderedAtUtc).ThenByDescending(item => item.OrderId),
            allItems);

        var employeeName = allItems
            .Select(item => item.EmployeeName?.Trim())
            .FirstOrDefault(name => !string.IsNullOrWhiteSpace(name));
        Assert.False(string.IsNullOrWhiteSpace(employeeName));
        Assert.Contains(employees, item => string.Equals(
            item.Name,
            employeeName,
            StringComparison.OrdinalIgnoreCase));

        var employeeReport = await client.GetFromJsonAsync<OrderReportResponse>(
            $"/api/order-reports?branchId=10&from=2024-10-01T00%3A00%3A00%2B07%3A00&to=2024-10-31T23%3A59%3A59%2B07%3A00&employeeName={Uri.EscapeDataString(employeeName!)}&pageSize=100",
            BranchTestSupport.JsonOptions);
        Assert.NotNull(employeeReport);
        Assert.True(employeeReport.TotalCount > 0);
        Assert.All(employeeReport.Items, item => Assert.Equal(
            employeeName,
            item.EmployeeName?.Trim(),
            ignoreCase: true));
    }

    private static async Task<BranchTestIdentity> SeedOrderReportScopeAsync(
        TTSmartApiFactory factory)
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
            companyDbContext.Companies.Add(
                BranchTestSupport.CreateCompany(1, "CT_SQL_E2E", "Công ty SQL E2E"));
            companyDbContext.Branches.Add(
                BranchTestSupport.CreateBranch(10, 1, "TRAM_SQL_E2E", "Trạm SQL E2E"));
            await companyDbContext.SaveChangesAsync();
        });
        return identity;
    }
}

public sealed class SqlE2EFactAttribute : FactAttribute
{
    public const string StationConnectionEnvironmentVariable =
        "TTSMART_ORDER_REPORT_STATION_CONNECTION";

    public SqlE2EFactAttribute()
    {
        if (string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable(
            StationConnectionEnvironmentVariable)))
        {
            Skip = $"Thiếu biến môi trường {StationConnectionEnvironmentVariable}.";
        }
    }
}
