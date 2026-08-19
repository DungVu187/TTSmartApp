using System.Net.Http.Json;
using Microsoft.Extensions.DependencyInjection;
using TTSmart.Api.Data.Company;
using TTSmart.Api.Features.Authorization;
using TTSmart.Api.Features.WeighStationManagement;
using Xunit;

namespace TTSmart.Api.Tests;

public sealed class WeighStationSqlApiTests
{
    private const string TimeQuery =
        "from=2026-08-05T00:00:00%2B07:00&to=2026-08-06T00:00:00%2B07:00";

    [WeighStationSqlE2EFact]
    [Trait("Category", "SqlE2E")]
    public async Task FullHttpE2E_DocFiltersVaTrangThaiXeTuBangChinh()
    {
        var stationConnection = Environment.GetEnvironmentVariable(
            WeighStationSqlE2EFactAttribute.StationConnectionEnvironmentVariable)!;
        await using var factory = new SqlWeighStationApiFactory(stationConnection);
        var identity = await SeedScopeAsync(factory);
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var stations = await client.GetFromJsonAsync<WeighStationStationResponse[]>(
            "/api/weigh-station-management/stations",
            BranchTestSupport.JsonOptions);
        Assert.Equal(10, Assert.Single(stations!).StationId);

        var filters = await client.GetFromJsonAsync<WeighStationFilterOptionsResponse>(
            "/api/weigh-station-management/filters?branchId=10&stage=Second&" + TimeQuery,
            BranchTestSupport.JsonOptions);
        Assert.NotNull(filters);
        Assert.NotEmpty(filters.VehiclePlates);
        Assert.NotEmpty(filters.GoodsNames);
        Assert.NotEmpty(filters.OperatorNames);
        Assert.NotEmpty(filters.UnitNames);
        Assert.NotEmpty(filters.WeighingTypes);

        var completed = await client.GetFromJsonAsync<WeighStationResponse>(
            "/api/weigh-station-management?branchId=10&stage=Second&" + TimeQuery,
            BranchTestSupport.JsonOptions);
        Assert.NotNull(completed);
        Assert.True(completed.TotalCount > 0);
        Assert.InRange(completed.Items.Count, 1, WeighStationContractDefaults.PageSize);
        Assert.Equal(WeighStationContractDefaults.PageSize, completed.PageSize);
        Assert.Equal(Enumerable.Range(1, completed.Items.Count), completed.Items.Select(item => item.Stt));
        Assert.All(completed.Items, item =>
        {
            Assert.Equal<byte?>(1, item.VehicleExitStatus);
            Assert.True(item.TicketNumber > 0);
            Assert.NotNull(item.TicketCode);
            Assert.NotNull(item.WeighedInAt);
            Assert.NotNull(item.WeighedOutAt);
            Assert.Equal(
                Math.Abs(item.InboundWeightKg.GetValueOrDefault() -
                    item.OutboundWeightKg.GetValueOrDefault()),
                item.GoodsWeightKg);
        });
        var convertedKgItems = completed.Items
            .Where(item => item.HasConversionConfiguration)
            .ToArray();
        Assert.NotEmpty(convertedKgItems);
        Assert.All(convertedKgItems, item =>
        {
            Assert.NotNull(item.GoodsWeightKg);
            Assert.NotNull(item.ConvertedUnit);
            Assert.NotNull(item.ConvertedQuantity);
        });

        var summary = await client.GetFromJsonAsync<WeighStationSummaryResponse>(
            "/api/weigh-station-management/summary?branchId=10&stage=Second&" + TimeQuery,
            BranchTestSupport.JsonOptions);
        Assert.NotNull(summary);
        Assert.True(summary.TotalCount > 0);
        Assert.True(summary.TotalGoodsWeightKg > 0);
        Assert.NotEmpty(summary.Groups);
        Assert.NotNull(summary.TopGoods);

        var pending = await client.GetFromJsonAsync<WeighStationResponse>(
            "/api/weigh-station-management?branchId=10&stage=First&" + TimeQuery,
            BranchTestSupport.JsonOptions);
        Assert.NotNull(pending);
        Assert.All(pending.Items, item =>
        {
            Assert.True(item.VehicleExitStatus is null or 0);
            Assert.NotNull(item.WeighedInAt);
        });

        var allStages = await client.GetFromJsonAsync<WeighStationResponse>(
            "/api/weigh-station-management?branchId=10&" + TimeQuery,
            BranchTestSupport.JsonOptions);
        Assert.NotNull(allStages);
        Assert.Equal(completed.TotalCount + pending.TotalCount, allStages.TotalCount);

        var conversionWarnings = await client.GetFromJsonAsync<WeighStationSummaryResponse>(
            "/api/weigh-station-management/summary?branchId=10&stage=Second&" +
            "from=2026-08-01T00:00:00%2B07:00&to=2026-08-04T00:00:00%2B07:00",
            BranchTestSupport.JsonOptions);
        Assert.NotNull(conversionWarnings);
        var inferredCement = Assert.Single(conversionWarnings.Items,
            item => item.GoodsName == "Xi Măng Rời PCB40");
        var inferredConversion = Assert.Single(inferredCement.ConvertedQuantities);
        Assert.Equal("tấn", inferredConversion.Unit);
        Assert.Null(inferredCement.ConversionMessage);

        var configured = Assert.Single(conversionWarnings.Items,
            item => item.GoodsName == "Xi Măng Rời PCB  40");
        Assert.Equal(175120m, configured.GoodsWeightKg);
        var converted = Assert.Single(configured.ConvertedQuantities);
        Assert.Equal(175.12m, converted.Quantity);
        Assert.Equal("tấn", converted.Unit);
        Assert.Null(configured.ConversionMessage);
    }

    private static async Task<BranchTestIdentity> SeedScopeAsync(TTSmartApiFactory factory)
    {
        BranchTestIdentity identity = null!;
        await factory.ResetDatabaseAsync(async (services, authDbContext) =>
        {
            identity = await BranchTestSupport.SeedWeighStationIdentityAsync(
                services,
                authDbContext,
                SystemRoleCodes.Company,
                1,
                null,
                ActiveKeyPermission.DSach);
            var companyDbContext = services.GetRequiredService<CompanyDbContext>();
            companyDbContext.Companies.Add(
                BranchTestSupport.CreateCompany(1, "CT_SQL_TKTC", "Công ty SQL TKTC"));
            companyDbContext.Branches.Add(
                BranchTestSupport.CreateBranch(10, 1, "CAN_SQL", "Trạm cân SQL", typeTram: 2));
            await companyDbContext.SaveChangesAsync();
        });
        return identity;
    }
}

public sealed class WeighStationSqlE2EFactAttribute : FactAttribute
{
    public const string StationConnectionEnvironmentVariable =
        "TTSMART_WEIGH_STATION_CONNECTION";

    public WeighStationSqlE2EFactAttribute()
    {
        if (string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable(
            StationConnectionEnvironmentVariable)))
        {
            Skip = $"Thiếu biến môi trường {StationConnectionEnvironmentVariable}.";
        }
    }
}
