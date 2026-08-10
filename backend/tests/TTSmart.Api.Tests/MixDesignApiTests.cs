using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.DependencyInjection;
using TTSmart.Api.Data.Company;
using TTSmart.Api.Data.WebAuth;
using TTSmart.Api.Features.Authorization;
using TTSmart.Api.Features.MixDesignManagement;

namespace TTSmart.Api.Tests;

public sealed class MixDesignApiTests(TTSmartApiFactory factory) : IClassFixture<TTSmartApiFactory>
{
    [Theory]
    [InlineData("/api/mix-designs/stations")]
    [InlineData("/api/mix-designs?stationId=10")]
    public async Task ChuaDangNhap_Tra401(string requestUri)
    {
        await factory.ResetDatabaseAsync();
        using var client = factory.CreateClient();

        Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync(requestUri)).StatusCode);
    }

    [Theory]
    [InlineData(SystemRoleCodes.Admin, null, "/api/mix-designs/stations?companyId=1")]
    [InlineData(SystemRoleCodes.Company, 1, "/api/mix-designs?stationId=10")]
    public async Task KhongCoFunctionQLCP_Tra403VaKhongQueryDatabaseTram(
        string roleCode,
        int? companyId,
        string requestUri)
    {
        BranchTestIdentity identity = null!;
        await factory.ResetDatabaseAsync(async (services, authDbContext) =>
        {
            identity = await BranchTestSupport.SeedIdentityAsync(
                services,
                authDbContext,
                roleCode,
                companyId,
                null);
            await SeedCompaniesAndBranchesAsync(services);
        });
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        Assert.Equal(HttpStatusCode.Forbidden, (await client.GetAsync(requestUri)).StatusCode);
        Assert.Equal(0, factory.MixDesignDataSource.CallCount);
    }

    [Fact]
    public async Task ChiCoQuyenViewKhongCoDSach_Tra403()
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
                ActiveKeyPermission.View);
            await SeedCompaniesAndBranchesAsync(services);
        });
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        Assert.Equal(HttpStatusCode.Forbidden, (await client.GetAsync(
            "/api/mix-designs?stationId=10")).StatusCode);
        Assert.Equal(0, factory.MixDesignDataSource.CallCount);
    }

    [Theory]
    [InlineData("/api/mix-designs/stations", "Vui lòng chọn công ty")]
    [InlineData("/api/mix-designs?stationId=10", "Vui lòng chọn công ty")]
    public async Task ADMIN_ThieuCongTy_Tra400DungMessageVaKhongQueryDatabaseTram(
        string requestUri,
        string expectedDetail)
    {
        BranchTestIdentity identity = null!;
        await factory.ResetDatabaseAsync(async (services, authDbContext) =>
        {
            identity = await BranchTestSupport.SeedMixDesignIdentityAsync(
                services,
                authDbContext,
                SystemRoleCodes.Admin,
                null,
                null,
                ActiveKeyPermission.DSach);
            await SeedCompaniesAndBranchesAsync(services);
        });
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var response = await client.GetAsync(requestUri);

        await AssertProblemAsync(response, HttpStatusCode.BadRequest, expectedDetail);
        Assert.Equal(0, factory.MixDesignDataSource.CallCount);
    }

    [Fact]
    public async Task CONGTY_ThieuTram_Tra400VuiLongChonTram()
    {
        var identity = await ResetAndSeedIdentityAsync(SystemRoleCodes.Company, 1, null);
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var response = await client.GetAsync("/api/mix-designs");

        await AssertProblemAsync(response, HttpStatusCode.BadRequest, "Vui lòng chọn trạm");
        Assert.Equal(0, factory.MixDesignDataSource.CallCount);
    }

    [Fact]
    public async Task DanhSachTram_ChiTraTramTronActiveTrongScopeVaKhongKiemTraDatabaseTram()
    {
        var identity = await ResetAndSeedIdentityAsync(SystemRoleCodes.Company, 1, null);
        factory.MixDesignDataSource.SetUnavailable();
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var response = await client.GetFromJsonAsync<MixDesignStationResponse[]>(
            "/api/mix-designs/stations",
            BranchTestSupport.JsonOptions);

        Assert.NotNull(response);
        var station = Assert.Single(response);
        Assert.Equal(10, station.StationId);
        Assert.Equal("Trạm 10", station.StationName);
        Assert.Equal(0, factory.MixDesignDataSource.CallCount);
    }

    [Theory]
    [InlineData(11)]
    [InlineData(12)]
    [InlineData(20)]
    [InlineData(999)]
    public async Task CONGTY_TramNgoaiScopeKhongActiveHoacSaiLoai_Tra403(int stationId)
    {
        var identity = await ResetAndSeedIdentityAsync(SystemRoleCodes.Company, 1, null);
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var response = await client.GetAsync($"/api/mix-designs?stationId={stationId}");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        Assert.Equal(0, factory.MixDesignDataSource.CallCount);
    }

    [Fact]
    public async Task ADMIN_ChonTramNgoaiCongTyDaChon_Tra403()
    {
        var identity = await ResetAndSeedIdentityAsync(SystemRoleCodes.Admin, null, null);
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var response = await client.GetAsync("/api/mix-designs?companyId=1&stationId=20");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        Assert.Equal(0, factory.MixDesignDataSource.CallCount);
    }

    [Fact]
    public async Task RoleCapDuoi_ChiDocTramNamTrongBranchIds()
    {
        var identity = await ResetAndSeedIdentityAsync("QUANLY", 1, "10");
        factory.MixDesignDataSource.SetPage(new MixDesignPage(
            [],
            1,
            MixDesignContractDefaults.PageSize,
            0,
            []));
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var allowed = await client.GetAsync("/api/mix-designs?stationId=10");
        var denied = await client.GetAsync("/api/mix-designs?stationId=20");

        Assert.Equal(HttpStatusCode.OK, allowed.StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, denied.StatusCode);
        Assert.Equal(1, factory.MixDesignDataSource.CallCount);
        Assert.Equal(10, factory.MixDesignDataSource.SeenTargets.Single().BranchId);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(int.MaxValue)]
    public async Task PageNumberKhongHopLe_Tra400DungMessage(int pageNumber)
    {
        var identity = await ResetAndSeedIdentityAsync(SystemRoleCodes.Company, 1, null);
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var response = await client.GetAsync(
            $"/api/mix-designs?stationId=10&pageNumber={pageNumber}");

        await AssertProblemAsync(response, HttpStatusCode.BadRequest, "Số trang không hợp lệ");
        Assert.Equal(0, factory.MixDesignDataSource.CallCount);
    }

    [Fact]
    public async Task DanhSachCapPhoi_MapDu14CotMacDinhLamTronVaSTTLienTuc()
    {
        var identity = await ResetAndSeedIdentityAsync(SystemRoleCodes.Company, 1, null);
        factory.MixDesignDataSource.SetPage(new MixDesignPage(
            [
                new MixDesignRow(
                    101,
                    null,
                    null,
                    null,
                    null,
                    1.005d,
                    null,
                    0d,
                    12.345d,
                    3d,
                    4d,
                    5d,
                    6d,
                    7d,
                    8d,
                    9d,
                    10d,
                    11d,
                    12d),
                new MixDesignRow(
                    102,
                    "M300",
                    300,
                    40,
                    "12±2",
                    100d,
                    200d,
                    300d,
                    400d,
                    500d,
                    600d,
                    700d,
                    800d,
                    900d,
                    1000d,
                    2.675d,
                    null,
                    null,
                    null)
            ],
            2,
            MixDesignContractDefaults.PageSize,
            12));
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var response = await client.GetFromJsonAsync<MixDesignResponse>(
            "/api/mix-designs?stationId=10&pageNumber=2",
            BranchTestSupport.JsonOptions);

        Assert.NotNull(response);
        Assert.Equal(2, response.PageNumber);
        Assert.Equal(10, response.PageSize);
        Assert.Equal(12, response.TotalCount);
        Assert.Equal(2, response.TotalPages);
        Assert.Equal([11, 12], response.Items.Select(item => item.Stt).ToArray());
        var first = response.Items[0];
        Assert.Null(first.ConcreteGradeName);
        Assert.Equal(0, first.Strength);
        Assert.Equal(0, first.MaxAggregate);
        Assert.Equal("0", first.Slump);
        Assert.Equal(1.01m, first.Sand1);
        Assert.Equal(0m, first.Sand2);
        Assert.Equal(12.35m, first.Stone2);
        Assert.Equal(12m, first.Bifi);
        var second = response.Items[1];
        Assert.Equal("M300", second.ConcreteGradeName);
        Assert.Equal("12±2", second.Slump);
        Assert.Equal(2.68m, second.Sika);
        Assert.Equal(0m, second.Tulog);
        Assert.Equal(0m, second.Sikaroad);
        Assert.Equal(0m, second.Bifi);
        Assert.Equal(10, factory.MixDesignDataSource.SeenTargets.Single().BranchId);
        Assert.Equal("TRAM_10_online", factory.MixDesignDataSource.SeenTargets.Single().DatabaseName);
        Assert.Equal([2], factory.MixDesignDataSource.SeenPageNumbers);
    }

    [Fact]
    public async Task LayoutDong_Hon14CuaGiuThuTuTramVaMapExactMacuavl()
    {
        var identity = await ResetAndSeedIdentityAsync(SystemRoleCodes.Company, 1, null);
        var materialColumns = Enumerable.Range(1, 16)
            .Select(slotNumber => slotNumber switch
            {
                1 => new MixDesignMaterialColumn(501, 1, 2, "\u0110\u00e1", "\u0110\u00e1 1"),
                2 => new MixDesignMaterialColumn(502, 2, 1, "C\u00e1t", "C\u00e1t 3"),
                3 => new MixDesignMaterialColumn(503, 3, 1, "C\u00e1t", "C\u00e1t 1"),
                _ => new MixDesignMaterialColumn(
                    500 + slotNumber,
                    slotNumber,
                    5,
                    "Ph\u1ee5 gia",
                    slotNumber == 4 ? " " : $"PG {slotNumber - 3}")
            })
            .ToArray();
        factory.MixDesignDataSource.SetPage(new MixDesignPage(
            [
                new MixDesignRow(
                    101,
                    "M300",
                    300,
                    20,
                    "12Â±2",
                    [
                        new MixDesignMaterialValue(501, 300d),
                        new MixDesignMaterialValue(502, 1.005d),
                        new MixDesignMaterialValue(516, 99d)
                    ])
            ],
            1,
            MixDesignContractDefaults.PageSize,
            1,
            materialColumns));
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var response = await client.GetFromJsonAsync<MixDesignResponse>(
            "/api/mix-designs?stationId=10&pageNumber=1",
            BranchTestSupport.JsonOptions);

        Assert.NotNull(response);
        Assert.Equal(16, response.MaterialColumns.Count);
        Assert.Equal(
            Enumerable.Range(1, 16),
            response.MaterialColumns.Select(column => column.SlotNumber));
        var firstSand = response.MaterialColumns.Single(column => column.MaterialSlotId == 502);
        Assert.Equal("C\u00e1t 3", firstSand.MaterialName);
        Assert.Equal("CAT", firstSand.CategoryCode);
        Assert.Equal(1, firstSand.TypePosition);
        Assert.Equal("slot-2", firstSand.ColumnKey);
        Assert.Equal(
            2,
            response.MaterialColumns.Single(column => column.MaterialSlotId == 503).TypePosition);
        Assert.Equal(
            "V\u1eadt li\u1ec7u 4",
            response.MaterialColumns.Single(column => column.MaterialSlotId == 504).MaterialName);
        Assert.Equal(
            13,
            response.MaterialColumns.Single(column => column.MaterialSlotId == 516).TypePosition);

        var item = Assert.Single(response.Items);
        Assert.Equal(16, item.Materials.Count);
        Assert.Equal(300m, item.Stone1);
        Assert.Equal(1.01m, item.Sand1);
        Assert.Equal(
            99m,
            item.Materials.Single(material => material.MaterialSlotId == 516).Quantity);
        Assert.Equal(
            0m,
            item.Materials.Single(material => material.MaterialSlotId == 503).Quantity);
    }

    [Fact]
    public async Task TrangVuotCuoi_Tra200DanhSachRongVaGiuMetadata()
    {
        var identity = await ResetAndSeedIdentityAsync(SystemRoleCodes.Company, 1, null);
        factory.MixDesignDataSource.SetPage(new MixDesignPage(
            [],
            4,
            MixDesignContractDefaults.PageSize,
            21,
            [new MixDesignMaterialColumn(1, 1, 1, "C\u00e1t", "C\u00e1t 1")]));
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var response = await client.GetFromJsonAsync<MixDesignResponse>(
            "/api/mix-designs?stationId=10&pageNumber=4",
            BranchTestSupport.JsonOptions);

        Assert.NotNull(response);
        Assert.Empty(response.Items);
        Assert.Single(response.MaterialColumns);
        Assert.Equal(4, response.PageNumber);
        Assert.Equal(10, response.PageSize);
        Assert.Equal(21, response.TotalCount);
        Assert.Equal(3, response.TotalPages);
    }

    [Fact]
    public async Task LayoutTrungSlot_Tra503ThayViDoanCot()
    {
        var identity = await ResetAndSeedIdentityAsync(SystemRoleCodes.Company, 1, null);
        factory.MixDesignDataSource.SetPage(new MixDesignPage(
            [],
            1,
            MixDesignContractDefaults.PageSize,
            0,
            [
                new MixDesignMaterialColumn(1, 1, 1, "C\u00e1t", "C\u00e1t 1"),
                new MixDesignMaterialColumn(2, 1, 2, "\u0110\u00e1", "\u0110\u00e1 1")
            ]));
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var response = await client.GetAsync("/api/mix-designs?stationId=10");

        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
    }

    [Fact]
    public async Task MaterialNgoaiLayout_Tra503ThayViMapTheoThuTu()
    {
        var identity = await ResetAndSeedIdentityAsync(SystemRoleCodes.Company, 1, null);
        factory.MixDesignDataSource.SetPage(new MixDesignPage(
            [
                new MixDesignRow(
                    101,
                    "M300",
                    300,
                    20,
                    "12Â±2",
                    [new MixDesignMaterialValue(999, 10d)])
            ],
            1,
            MixDesignContractDefaults.PageSize,
            1,
            [new MixDesignMaterialColumn(1, 1, 1, "C\u00e1t", "C\u00e1t 1")]));
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var response = await client.GetAsync("/api/mix-designs?stationId=10");

        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
    }

    [Fact]
    public async Task DatabaseTramLoi_Tra503VaKhongLoChiTietNoiBo()
    {
        var identity = await ResetAndSeedIdentityAsync(SystemRoleCodes.Company, 1, null);
        factory.MixDesignDataSource.SetUnavailable();
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var response = await client.GetAsync("/api/mix-designs?stationId=10");
        var body = await response.Content.ReadAsStringAsync();

        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
        var problem = JsonSerializer.Deserialize<ProblemDetails>(body, BranchTestSupport.JsonOptions);
        Assert.NotNull(problem);
        Assert.Equal("Dữ liệu trạm chưa sẵn sàng", problem.Detail);
        Assert.DoesNotContain("SqlException", body, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("TRAM_online", body, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("should-not-leak", body, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task OpenApi_CongBoDungEndpointStatusLegacyVaLayoutDong()
    {
        await factory.ResetDatabaseAsync();
        using var client = factory.CreateClient();

        var response = await client.GetAsync("/openapi/v1.json");
        response.EnsureSuccessStatusCode();
        using var document = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
        var paths = document.RootElement.GetProperty("paths");
        AssertResponses(
            paths.GetProperty("/api/mix-designs/stations").GetProperty("get"),
            "200", "400", "401", "403");
        AssertResponses(
            paths.GetProperty("/api/mix-designs").GetProperty("get"),
            "200", "400", "401", "403", "503");

        var properties = document.RootElement
            .GetProperty("components")
            .GetProperty("schemas")
            .GetProperty(nameof(MixDesignItemResponse))
            .GetProperty("properties");
        foreach (var propertyName in new[]
        {
            "stt", "concreteGradeName", "strength", "maxAggregate", "slump",
            "sand1", "sand2", "stone1", "stone2", "stone3",
            "cement1", "cement2", "cement3", "cement4", "water",
            "sika", "tulog", "sikaroad", "bifi"
        })
        {
            Assert.True(properties.TryGetProperty(propertyName, out _), $"Thiếu field {propertyName}.");
        }
        Assert.True(properties.TryGetProperty("materials", out _));

        var responseProperties = document.RootElement
            .GetProperty("components")
            .GetProperty("schemas")
            .GetProperty(nameof(MixDesignResponse))
            .GetProperty("properties");
        Assert.True(responseProperties.TryGetProperty("materialColumns", out _));

        var columnProperties = document.RootElement
            .GetProperty("components")
            .GetProperty("schemas")
            .GetProperty(nameof(MixDesignMaterialColumnResponse))
            .GetProperty("properties");
        foreach (var propertyName in new[]
        {
            "materialSlotId", "slotNumber", "materialName", "category",
            "categoryCode", "typePosition", "columnKey"
        })
        {
            Assert.True(columnProperties.TryGetProperty(propertyName, out _));
        }
    }

    private async Task<BranchTestIdentity> ResetAndSeedIdentityAsync(
        string roleCode,
        int? companyId,
        string? branchIds)
    {
        BranchTestIdentity identity = null!;
        await factory.ResetDatabaseAsync(async (services, authDbContext) =>
        {
            identity = await BranchTestSupport.SeedMixDesignIdentityAsync(
                services,
                authDbContext,
                roleCode,
                companyId,
                branchIds,
                ActiveKeyPermission.DSach);
            await SeedCompaniesAndBranchesAsync(services);
        });
        return identity;
    }

    private static async Task SeedCompaniesAndBranchesAsync(IServiceProvider services)
    {
        var companyDbContext = services.GetRequiredService<CompanyDbContext>();
        companyDbContext.Companies.AddRange(
            BranchTestSupport.CreateCompany(1, "CT_1", "Công ty 1"),
            BranchTestSupport.CreateCompany(2, "CT_2", "Công ty 2"));
        companyDbContext.Branches.AddRange(
            BranchTestSupport.CreateBranch(10, 1, "TRAM_10", "Trạm 10"),
            BranchTestSupport.CreateBranch(11, 1, "TRAM_CAN", "Trạm cân", typeTram: 2),
            BranchTestSupport.CreateBranch(12, 1, "TRAM_XOA", "Trạm không hoạt động", status: WebDataStatus.Inactive),
            BranchTestSupport.CreateBranch(20, 2, "TRAM_20", "Trạm 20"));
        await companyDbContext.SaveChangesAsync();
    }

    private static async Task AssertProblemAsync(
        HttpResponseMessage response,
        HttpStatusCode expectedStatus,
        string expectedDetail)
    {
        Assert.Equal(expectedStatus, response.StatusCode);
        var problem = await response.Content.ReadFromJsonAsync<ProblemDetails>(BranchTestSupport.JsonOptions);
        Assert.NotNull(problem);
        Assert.Equal(expectedDetail, problem.Detail);
    }

    private static void AssertResponses(JsonElement operation, params string[] statusCodes)
    {
        Assert.True(operation.TryGetProperty("security", out var security));
        Assert.NotEqual(0, security.GetArrayLength());
        var responses = operation.GetProperty("responses");
        foreach (var statusCode in statusCodes)
        {
            Assert.True(
                responses.TryGetProperty(statusCode, out _),
                $"Thiếu response {statusCode} trong OpenAPI.");
        }
    }
}
