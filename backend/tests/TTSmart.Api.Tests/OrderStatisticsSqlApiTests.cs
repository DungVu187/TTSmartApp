using System.Net.Http.Json;
using Microsoft.Extensions.DependencyInjection;
using TTSmart.Api.Data.Company;
using TTSmart.Api.Features.Authorization;
using TTSmart.Api.Features.OrderStatistics;

namespace TTSmart.Api.Tests;

public sealed class OrderStatisticsSqlApiTests
{
    [SqlE2EFact]
    [Trait("Category", "SqlE2E")]
    public async Task FullHttpE2E_DocDetailTotalFilterVaVatLieuTuDatabaseTram()
    {
        var stationConnection = Environment.GetEnvironmentVariable(
            SqlE2EFactAttribute.StationConnectionEnvironmentVariable)!;
        await using var factory = new SqlOrderStatisticsApiFactory(stationConnection);
        var identity = await SeedScopeAsync(factory);
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var stations = await client.GetFromJsonAsync<OrderStatisticsStationResponse[]>(
            "/api/order-statistics/stations?companyId=1",
            BranchTestSupport.JsonOptions);
        Assert.NotNull(stations);
        Assert.Equal([10], stations.Select(item => item.Id).ToArray());

        const string timeRange =
            "from=2024-01-01T00%3A00%3A00%2B07%3A00&to=2025-12-31T23%3A59%3A59%2B07%3A00";
        var filterOptions = await client.GetFromJsonAsync<OrderStatisticsFilterOptionsResponse>(
            "/api/order-statistics/filters?companyId=1&branchId=10&" + timeRange,
            BranchTestSupport.JsonOptions);
        Assert.NotNull(filterOptions);
        Assert.Contains("HẠNH", filterOptions.EmployeeNames);
        Assert.Contains("200", filterOptions.ConcreteGradeNames);
        Assert.Contains("300", filterOptions.ConcreteGradeNames);

        var detail = await client.GetFromJsonAsync<OrderStatisticsResponse>(
            "/api/order-statistics?companyId=1&branchId=10&viewMode=detail&pageNumber=1&pageSize=10&" + timeRange,
            BranchTestSupport.JsonOptions);
        Assert.NotNull(detail);
        Assert.Equal(13, detail.TotalCount);
        Assert.Equal(2, detail.TotalPages);
        Assert.Equal(10, detail.Items.Count);
        Assert.NotEmpty(detail.Layouts);
        Assert.All(detail.Layouts, layout => Assert.Equal(14, layout.Columns.Count));
        Assert.Contains(
            detail.Layouts,
            layout => layout.Columns.Select(column => column.SlotNumber)
                .SequenceEqual(Enumerable.Range(1, 14)));
        Assert.All(detail.Items, item =>
        {
            Assert.Equal(10, item.StationId);
            Assert.Equal(14, item.Materials.Count);
            Assert.Equal(
                Enumerable.Range(1, 14),
                item.Materials.Select(material => material.SlotNumber));
            Assert.True(item.Materials.Sum(material => material.ActualQuantity) > 0);
            Assert.NotNull(item.StartedAt);
            Assert.NotNull(item.FinishedAt);
        });
        Assert.Equal("SIKA", detail.Items[0].Materials.Single(material => material.SlotNumber == 11).MaterialName);
        var detailPage2 = await client.GetFromJsonAsync<OrderStatisticsResponse>(
            "/api/order-statistics?companyId=1&branchId=10&viewMode=detail&pageNumber=2&pageSize=10&" + timeRange,
            BranchTestSupport.JsonOptions);
        Assert.NotNull(detailPage2);
        Assert.Equal(13, detailPage2.TotalCount);
        Assert.Equal(2, detailPage2.TotalPages);
        Assert.Equal(3, detailPage2.Items.Count);
        Assert.Equal(Enumerable.Range(11, 3), detailPage2.Items.Select(item => item.RowNumber));
        Assert.Equal("PG 1", detailPage2.Items[^1].Materials.Single(material => material.SlotNumber == 11).MaterialName);
        Assert.Equal(24.333m, detail.TotalConcreteVolume);
        Assert.Equal(58777.457m, detail.TotalMaterialQuantity);
        Assert.Equal(
            detail.TotalMaterialQuantity,
            detail.MaterialSummaryRows
                .SelectMany(row => row.Cells)
                .Sum(cell => cell.ActualQuantity));

        var total = await client.GetFromJsonAsync<OrderStatisticsResponse>(
            "/api/order-statistics?companyId=1&branchId=10&viewMode=total&pageNumber=1&pageSize=10&" + timeRange,
            BranchTestSupport.JsonOptions);
        Assert.NotNull(total);
        Assert.Equal(5, total.TotalCount);
        Assert.Equal(1, total.TotalPages);
        Assert.Equal(5, total.Items.Count);
        Assert.All(total.Items, item =>
        {
            Assert.Equal(
                Enumerable.Range(1, 14),
                item.Materials.Select(material => material.SlotNumber));
            Assert.True(item.Materials.Sum(material => material.ActualQuantity) > 0);
        });
        Assert.Equal(24.333m, total.TotalConcreteVolume);
        Assert.Equal(detail.TotalMaterialQuantity, total.TotalMaterialQuantity);
        foreach (var materialCell in total.MaterialSummaryRows
                     .SelectMany(row => row.Cells)
                     .Where(cell => cell.ActualQuantity != 0m))
        {
            var itemQuantity = total.Items.Sum(item => item.Materials
                .Single(material =>
                    material.CategoryCode == materialCell.CategoryCode &&
                    material.TypePosition == materialCell.TypePosition)
                .ActualQuantity);
            Assert.InRange(
                Math.Abs(materialCell.ActualQuantity - itemQuantity),
                0m,
                0.01m);
        }

        var employeeFiltered = await client.GetFromJsonAsync<OrderStatisticsResponse>(
            "/api/order-statistics?companyId=1&branchId=10&employeeName=H%E1%BA%A0NH&" + timeRange,
            BranchTestSupport.JsonOptions);
        Assert.NotNull(employeeFiltered);
        Assert.Equal(13, employeeFiltered.TotalCount);
        Assert.All(employeeFiltered.Items, item => Assert.Equal("HẠNH", item.SalesEmployeeName));
    }

    private static async Task<BranchTestIdentity> SeedScopeAsync(TTSmartApiFactory factory)
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
            var companyDbContext = services.GetRequiredService<CompanyDbContext>();
            companyDbContext.Companies.Add(
                BranchTestSupport.CreateCompany(1, "CT_SQL_TKDH", "Công ty SQL TKĐH"));
            companyDbContext.Branches.Add(
                BranchTestSupport.CreateBranch(10, 1, "TRAM_SQL_TKDH", "Trạm SQL TKĐH"));
            await companyDbContext.SaveChangesAsync();
        });
        return identity;
    }
}
