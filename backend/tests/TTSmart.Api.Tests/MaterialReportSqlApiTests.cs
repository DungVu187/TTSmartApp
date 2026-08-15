using System.Net.Http.Json;
using Microsoft.Extensions.DependencyInjection;
using TTSmart.Api.Data.Company;
using TTSmart.Api.Features.Authorization;
using TTSmart.Api.Features.MaterialReporting;

namespace TTSmart.Api.Tests;

public sealed class MaterialReportSqlApiTests
{
    [MaterialReportSqlE2EFact]
    [Trait("Category", "SqlE2E")]
    public async Task FullHttpE2E_DocReadOnlyVaTonAmGiaBangKhongTuDatabaseTram()
    {
        var stationConnection = Environment.GetEnvironmentVariable(
            MaterialReportSqlE2EFactAttribute.StationConnectionEnvironmentVariable)!;
        await using var factory = new SqlMaterialReportApiFactory(stationConnection);
        BranchTestIdentity identity = null!;
        await factory.ResetDatabaseAsync(async (services, authDbContext) =>
        {
            identity = await BranchTestSupport.SeedMaterialReportIdentityAsync(
                services,
                authDbContext,
                SystemRoleCodes.Company,
                1,
                null,
                ActiveKeyPermission.View);
            var companyDbContext = services.GetRequiredService<CompanyDbContext>();
            companyDbContext.Companies.Add(
                BranchTestSupport.CreateCompany(1, "CT_SQL_QLKHO", "Công ty SQL QLKHO"));
            companyDbContext.Branches.Add(
                BranchTestSupport.CreateBranch(10, 1, "TRAM_SQL_QLKHO", "Trạm SQL QLKHO"));
            await companyDbContext.SaveChangesAsync();
        });
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var response = await client.GetFromJsonAsync<MaterialReportResponse>(
            "/api/material-reports?branchId=10&from=2024-10-01T00:00:00%2B07:00&to=2025-12-31T23:59:59%2B07:00",
            BranchTestSupport.JsonOptions);

        Assert.NotNull(response);
        Assert.Equal(14, response.ChartItems.Count);
        Assert.Equal(0m, response.Totals.ImportQuantityKg);
        Assert.True(response.Totals.ExportQuantityKg > 0);
        Assert.True(response.Totals.InventoryQuantityKg < 0);
        Assert.Equal(0m, response.Totals.ExportValueVnd);
        Assert.Equal(0m, response.Totals.InventoryValueVnd);
        Assert.Contains(response.Warnings, warning => warning.Contains("TC_XEVAORA", StringComparison.Ordinal));
        Assert.Contains(response.Warnings, warning => warning.Contains("nhập/xuất thủ công", StringComparison.Ordinal));
        Assert.Equal("summary-export", Assert.Single(response.Transactions).Type);
    }
}

public sealed class MaterialReportSqlE2EFactAttribute : FactAttribute
{
    public const string StationConnectionEnvironmentVariable =
        "TTSMART_MATERIAL_REPORT_STATION_CONNECTION";

    public MaterialReportSqlE2EFactAttribute()
    {
        if (string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable(
            StationConnectionEnvironmentVariable)))
        {
            Skip = $"Thiếu biến môi trường {StationConnectionEnvironmentVariable}.";
        }
    }
}
