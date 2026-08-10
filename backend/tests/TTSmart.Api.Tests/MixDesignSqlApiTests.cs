using System.Net.Http.Json;
using Microsoft.Extensions.DependencyInjection;
using TTSmart.Api.Data.Company;
using TTSmart.Api.Features.Authorization;
using TTSmart.Api.Features.MixDesignManagement;
using Xunit;

namespace TTSmart.Api.Tests;

public sealed class MixDesignSqlApiTests
{
    [MixDesignSqlE2EFact]
    [Trait("Category", "SqlE2E")]
    public async Task FullHttpE2E_DocCapPhoiVaLayoutDongTuDatabaseTram()
    {
        var stationConnection = Environment.GetEnvironmentVariable(
            MixDesignSqlE2EFactAttribute.StationConnectionEnvironmentVariable)!;
        await using var factory = new SqlMixDesignApiFactory(stationConnection);
        var identity = await SeedScopeAsync(factory);
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var stations = await client.GetFromJsonAsync<MixDesignStationResponse[]>(
            "/api/mix-designs/stations",
            BranchTestSupport.JsonOptions);
        Assert.NotNull(stations);
        var station = Assert.Single(stations);
        Assert.Equal(10, station.StationId);

        var response = await client.GetFromJsonAsync<MixDesignResponse>(
            "/api/mix-designs?stationId=10&pageNumber=1",
            BranchTestSupport.JsonOptions);
        Assert.NotNull(response);
        Assert.Equal(2, response.TotalCount);
        Assert.Equal(1, response.TotalPages);
        Assert.Equal(1, response.PageNumber);
        Assert.Equal(10, response.PageSize);
        Assert.Equal([1, 2], response.Items.Select(item => item.Stt).ToArray());
        Assert.Equal(14, response.MaterialColumns.Count);
        Assert.Equal(
            Enumerable.Range(1, 14),
            response.MaterialColumns.Select(column => column.SlotNumber));
        Assert.All(response.Items, item => Assert.Equal(14, item.Materials.Count));

        var first = response.Items[0];
        Assert.Equal("300", first.ConcreteGradeName);
        Assert.Equal(300, first.Strength);
        Assert.Equal(40, first.MaxAggregate);
        Assert.Equal("10±0", first.Slump);
        Assert.Equal(400m, first.Sand1);
        Assert.Equal(400m, first.Sand2);
        Assert.Equal(500m, first.Stone1);
        Assert.Equal(600m, first.Stone2);
        Assert.Equal(0m, first.Stone3);
        Assert.Equal(250m, first.Cement1);
        Assert.Equal(150m, first.Cement2);
        Assert.Equal(0m, first.Cement3);
        Assert.Equal(0m, first.Cement4);
        Assert.Equal(150m, first.Water);
        Assert.Equal(2m, first.Sika);
        Assert.Equal(0m, first.Tulog);
        Assert.Equal(0m, first.Sikaroad);
        Assert.Equal(0m, first.Bifi);

        var second = response.Items[1];
        Assert.Equal("200", second.ConcreteGradeName);
        Assert.Equal(200, second.Strength);
        Assert.Equal(20, second.MaxAggregate);
        Assert.Equal("12±2", second.Slump);
        Assert.Equal(600m, second.Sand1);
        Assert.Equal(3m, second.Sika);

        var emptyPage = await client.GetFromJsonAsync<MixDesignResponse>(
            "/api/mix-designs?stationId=10&pageNumber=2",
            BranchTestSupport.JsonOptions);
        Assert.NotNull(emptyPage);
        Assert.Empty(emptyPage.Items);
        Assert.Equal(14, emptyPage.MaterialColumns.Count);
        Assert.Equal(2, emptyPage.TotalCount);
        Assert.Equal(1, emptyPage.TotalPages);
    }

    private static async Task<BranchTestIdentity> SeedScopeAsync(TTSmartApiFactory factory)
    {
        BranchTestIdentity identity = null!;
        await factory.ResetDatabaseAsync(async (services, authDbContext) =>
        {
            identity = await BranchTestSupport.SeedMixDesignIdentityAsync(
                services,
                authDbContext,
                SystemRoleCodes.Company,
                1,
                null,
                ActiveKeyPermission.DSach);
            var companyDbContext = services.GetRequiredService<CompanyDbContext>();
            companyDbContext.Companies.Add(
                BranchTestSupport.CreateCompany(1, "CT_SQL_QLCP", "Công ty SQL QLCP"));
            companyDbContext.Branches.Add(
                BranchTestSupport.CreateBranch(10, 1, "TRAM_SQL_QLCP", "Trạm SQL QLCP"));
            await companyDbContext.SaveChangesAsync();
        });
        return identity;
    }
}

public sealed class MixDesignSqlE2EFactAttribute : FactAttribute
{
    public const string StationConnectionEnvironmentVariable =
        "TTSMART_MIX_DESIGN_STATION_CONNECTION";

    public MixDesignSqlE2EFactAttribute()
    {
        if (string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable(
            StationConnectionEnvironmentVariable)))
        {
            Skip = $"Thiếu biến môi trường {StationConnectionEnvironmentVariable}.";
        }
    }
}
