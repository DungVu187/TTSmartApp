using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.DependencyInjection;
using TTSmart.Api.Data.Company;
using TTSmart.Api.Data.WebAuth;
using TTSmart.Api.Features.Authorization;
using TTSmart.Api.Features.WeighStationManagement;

namespace TTSmart.Api.Tests;

public sealed class WeighStationApiTests(TTSmartApiFactory factory) : IClassFixture<TTSmartApiFactory>
{
    private const string TimeQuery =
        "from=2026-08-05T00:00:00%2B07:00&to=2026-08-06T00:00:00%2B07:00";

    [Theory]
    [InlineData("/api/weigh-station-management/stations")]
    [InlineData("/api/weigh-station-management/filters?branchId=10&stage=First&" + TimeQuery)]
    [InlineData("/api/weigh-station-management?branchId=10&stage=Second&" + TimeQuery)]
    [InlineData("/api/weigh-station-management/summary?branchId=10&stage=Second&" + TimeQuery)]
    [InlineData("/api/weigh-station-management/export?branchId=10&stage=Second&" + TimeQuery)]
    public async Task ChuaDangNhap_Tra401(string requestUri)
    {
        await factory.ResetDatabaseAsync();
        using var client = factory.CreateClient();

        Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync(requestUri)).StatusCode);
    }

    [Fact]
    public async Task KhongCoFunctionTKTC_Tra403VaKhongQueryDatabaseTram()
    {
        BranchTestIdentity identity = null!;
        await factory.ResetDatabaseAsync(async (services, authDbContext) =>
        {
            identity = await BranchTestSupport.SeedIdentityAsync(
                services,
                authDbContext,
                SystemRoleCodes.Company,
                1,
                null);
            await SeedCompaniesAndBranchesAsync(services);
        });
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var response = await client.GetAsync(
            "/api/weigh-station-management?branchId=10&stage=Second&" + TimeQuery);

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        Assert.Equal(0, factory.WeighStationDataSource.SearchCallCount);
    }

    [Theory]
    [InlineData("/api/weigh-station-management/stations")]
    [InlineData("/api/weigh-station-management?branchId=10&stage=Second&" + TimeQuery)]
    [InlineData("/api/weigh-station-management/summary?branchId=10&stage=Second&" + TimeQuery)]
    public async Task ADMIN_ThieuCongTy_Tra400(string requestUri)
    {
        var identity = await ResetAndSeedIdentityAsync(SystemRoleCodes.Admin, null, null);
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        await AssertProblemAsync(
            await client.GetAsync(requestUri),
            HttpStatusCode.BadRequest,
            "Vui lòng chọn công ty");
        Assert.Equal(0, factory.WeighStationDataSource.SearchCallCount);
        Assert.Equal(0, factory.WeighStationDataSource.SummaryCallCount);
    }

    [Fact]
    public async Task DanhSachTram_ChiTraTramCanActiveTrongScope()
    {
        var identity = await ResetAndSeedIdentityAsync(SystemRoleCodes.Company, 1, null);
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var stations = await client.GetFromJsonAsync<WeighStationStationResponse[]>(
            "/api/weigh-station-management/stations",
            BranchTestSupport.JsonOptions);

        var station = Assert.Single(stations!);
        Assert.Equal(10, station.StationId);
        Assert.Equal("Trạm cân 10", station.StationName);
    }

    [Fact]
    public async Task ThieuTramCan_Tra400VaKhongQueryDatabaseTram()
    {
        var identity = await ResetAndSeedIdentityAsync(SystemRoleCodes.Company, 1, null);
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        await AssertProblemAsync(
            await client.GetAsync("/api/weigh-station-management?stage=Second&" + TimeQuery),
            HttpStatusCode.BadRequest,
            "Vui lòng chọn trạm cân");
        Assert.Equal(0, factory.WeighStationDataSource.SearchCallCount);
    }

    [Fact]
    public async Task TramNgoaiScopeHoacKhongPhaiTramCan_Tra403()
    {
        var identity = await ResetAndSeedIdentityAsync("QUANLY", null, "10");
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        foreach (var branchId in new[] { 11, 20 })
        {
            var response = await client.GetAsync(
                $"/api/weigh-station-management?branchId={branchId}&stage=Second&{TimeQuery}");
            Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        }
        Assert.Equal(0, factory.WeighStationDataSource.SearchCallCount);
    }

    [Fact]
    public async Task Filters_TruyenDungStageKhoangNgayVaTraDanhMucTheoNgay()
    {
        var identity = await ResetAndSeedIdentityAsync(SystemRoleCodes.Company, 1, null);
        factory.WeighStationDataSource.SetFilterOptions(new WeighStationFilterOptions(
            ["89 C 11415"],
            ["Bê tông thương phẩm"],
            ["vanhanh"],
            ["Cty Thành Phát"],
            ["Bán hàng"]));
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var response = await client.GetFromJsonAsync<WeighStationFilterOptionsResponse>(
            "/api/weigh-station-management/filters?branchId=10&stage=First&" + TimeQuery,
            BranchTestSupport.JsonOptions);

        Assert.NotNull(response);
        Assert.Equal(["89 C 11415"], response.VehiclePlates);
        Assert.Equal(["Bê tông thương phẩm"], response.GoodsNames);
        Assert.Equal(["vanhanh"], response.OperatorNames);
        Assert.Equal(1, factory.WeighStationDataSource.FilterCallCount);
        Assert.Equal(WeighStationStage.First, Assert.Single(factory.WeighStationDataSource.SeenStages));
        var filter = Assert.Single(factory.WeighStationDataSource.SeenFilters);
        Assert.Equal(new DateTime(2026, 8, 5), filter.FromInclusive);
        Assert.Equal(new DateTime(2026, 8, 6), filter.ToExclusive);
        Assert.Equal(2, Assert.Single(factory.WeighStationDataSource.SeenTargets).TypeTram);
    }

    [Fact]
    public async Task Filters_KhongChonLanCan_VanTraDanhMucCaHaiGiaiDoan()
    {
        var identity = await ResetAndSeedIdentityAsync(SystemRoleCodes.Company, 1, null);
        factory.WeighStationDataSource.SetFilterOptions(new WeighStationFilterOptions(
            ["89 C 11415"], ["Da 1x2"], ["vanhanh"], ["Cty Thanh Phat"], ["Nhap hang"]));
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var response = await client.GetFromJsonAsync<WeighStationFilterOptionsResponse>(
            "/api/weigh-station-management/filters?branchId=10&" + TimeQuery,
            BranchTestSupport.JsonOptions);

        Assert.NotNull(response);
        Assert.Equal(["89 C 11415"], response.VehiclePlates);
        Assert.Null(Assert.Single(factory.WeighStationDataSource.SeenStages));
    }

    [Fact]
    public async Task Search_KhongChonLanCan_VanTimKiemCaHaiGiaiDoan()
    {
        var identity = await ResetAndSeedIdentityAsync(SystemRoleCodes.Company, 1, null);
        factory.WeighStationDataSource.SetPage(new WeighStationPage(
            [CreateRow(Guid.NewGuid())],
            1));
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var response = await client.GetFromJsonAsync<WeighStationResponse>(
            "/api/weigh-station-management?branchId=10&" + TimeQuery,
            BranchTestSupport.JsonOptions);

        Assert.NotNull(response);
        Assert.Single(response.Items);
        Assert.Null(Assert.Single(factory.WeighStationDataSource.SeenStages));
    }

    [Fact]
    public async Task Search_TraDungCotWebPhanTrang10DongVaChuyenUtc()
    {
        var identity = await ResetAndSeedIdentityAsync(SystemRoleCodes.Company, 1, null);
        var id = Guid.NewGuid();
        factory.WeighStationDataSource.SetPage(new WeighStationPage(
            [CreateRow(id)],
            11));
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);
        var vehicle = Uri.EscapeDataString(" 89 C 11415 ");

        var response = await client.GetFromJsonAsync<WeighStationResponse>(
            $"/api/weigh-station-management?branchId=10&stage=Second&pageNumber=2&vehiclePlate={vehicle}&{TimeQuery}",
            BranchTestSupport.JsonOptions);

        Assert.NotNull(response);
        Assert.Equal(2, response.PageNumber);
        Assert.Equal(10, response.PageSize);
        Assert.Equal(11, response.TotalCount);
        Assert.Equal(2, response.TotalPages);
        Assert.False(response.CanViewMaterialValue);
        var item = Assert.Single(response.Items);
        Assert.Equal(11, item.Stt);
        Assert.Equal(id, item.Id);
        Assert.Equal(153804, item.TicketNumber);
        Assert.Equal("260805-0008", item.TicketCode);
        Assert.Equal(new DateTimeOffset(2026, 8, 5, 5, 50, 16, TimeSpan.Zero), item.WeighingAt);
        Assert.Equal("89 C 11415", item.VehiclePlate);
        Assert.Equal("lợi", item.DriverName);
        Assert.Equal("202625136784", item.SealNumber);
        Assert.Equal(40740m, item.InboundWeightKg);
        Assert.Equal(15770m, item.OutboundWeightKg);
        Assert.Equal(24970m, item.GoodsWeightKg);
        Assert.True(item.HasConversionConfiguration);
        Assert.Equal(12485m, item.ConvertedQuantity);
        Assert.Equal("m³", item.ConvertedUnit);
        Assert.Null(item.MaterialValueVnd);
        Assert.Equal("Cty Thành Phát", item.UnitName);
        Assert.Equal("Bê tông thương phẩm", item.GoodsName);
        Assert.Equal("Bán hàng", item.WeighingType);
        Assert.Equal(new DateTimeOffset(2026, 8, 5, 4, 2, 40, TimeSpan.Zero), item.WeighedInAt);
        Assert.Equal(new DateTimeOffset(2026, 8, 5, 4, 4, 8, TimeSpan.Zero), item.WeighedOutAt);
        Assert.Equal(10, Assert.Single(factory.WeighStationDataSource.SeenPageOffsets));
        Assert.Equal("89 C 11415", Assert.Single(factory.WeighStationDataSource.SeenFilters).VehiclePlate);
    }

    [Theory]
    [InlineData("KG")]
    [InlineData("kg")]
    [InlineData(" Kg ")]
    public async Task Search_DonViKgKhongPhanBietHoaThuong_QuyDoiSangTan(string conversionUnit)
    {
        var identity = await ResetAndSeedIdentityAsync(SystemRoleCodes.Company, 1, null);
        factory.WeighStationDataSource.SetPage(new WeighStationPage(
        [
            CreateRow(Guid.NewGuid()) with
            {
                GoodsWeight = 1000m,
                ConversionFactor = 1,
                ConversionUnit = conversionUnit
            }
        ], 1));
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var response = await client.GetFromJsonAsync<WeighStationResponse>(
            "/api/weigh-station-management?branchId=10&stage=Second&" + TimeQuery,
            BranchTestSupport.JsonOptions);

        var item = Assert.Single(response!.Items);
        Assert.True(item.HasConversionConfiguration);
        Assert.Equal(1m, item.ConvertedQuantity);
        Assert.Equal("tấn", item.ConvertedUnit);
        Assert.Null(item.ConversionMessage);
    }

    [Fact]
    public async Task Search_HeSoKhongHopLe_TraChuaXacDinhVaDonViRongMacDinhKg()
    {
        var identity = await ResetAndSeedIdentityAsync(SystemRoleCodes.Company, 1, null);
        var rows = new[]
        {
            CreateRow(Guid.NewGuid()) with { GoodsWeight = null, ConversionFactor = 1, ConversionUnit = "m3" },
            CreateRow(Guid.NewGuid()) with { GoodsWeight = 1000m, ConversionFactor = 0, ConversionUnit = "m3" },
            CreateRow(Guid.NewGuid()) with { GoodsWeight = 1000m, ConversionFactor = -1, ConversionUnit = "m3" },
            CreateRow(Guid.NewGuid()) with { GoodsWeight = 1000m, ConversionFactor = 1, ConversionUnit = null },
            CreateRow(Guid.NewGuid()) with { GoodsWeight = 1000m, ConversionFactor = null, ConversionUnit = null }
        };
        factory.WeighStationDataSource.SetPage(new WeighStationPage(rows, rows.Length));
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var response = await client.GetFromJsonAsync<WeighStationResponse>(
            "/api/weigh-station-management?branchId=10&stage=Second&" + TimeQuery,
            BranchTestSupport.JsonOptions);

        var items = response!.Items;
        Assert.False(items[0].HasConversionConfiguration);
        Assert.Null(items[0].ConvertedQuantity);
        Assert.Equal("m³", items[0].ConvertedUnit);
        Assert.Null(items[0].ConversionMessage);

        foreach (var item in items.Skip(1).Take(2))
        {
            Assert.False(item.HasConversionConfiguration);
            Assert.Null(item.ConvertedQuantity);
            Assert.Equal("m³", item.ConvertedUnit);
            Assert.Equal(WeighStationConversionMessages.Undefined, item.ConversionMessage);
        }

        Assert.True(items[3].HasConversionConfiguration);
        Assert.Equal(1m, items[3].ConvertedQuantity);
        Assert.Equal("tấn", items[3].ConvertedUnit);
        Assert.Null(items[3].ConversionMessage);

        Assert.False(items[4].HasConversionConfiguration);
        Assert.Null(items[4].ConvertedQuantity);
        Assert.Equal("tấn", items[4].ConvertedUnit);
        Assert.Equal(WeighStationConversionMessages.Undefined, items[4].ConversionMessage);
    }

    [Fact]
    public async Task CoQuyenOther_ResponseChoPhepHienThiCotGia()
    {
        var identity = await ResetAndSeedIdentityAsync(
            SystemRoleCodes.Company,
            1,
            null,
            ActiveKeyPermission.Other);
        factory.WeighStationDataSource.SetPage(new WeighStationPage([CreateRow(Guid.NewGuid())], 1));
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var response = await client.GetFromJsonAsync<WeighStationResponse>(
            "/api/weigh-station-management?branchId=10&stage=Second&" + TimeQuery,
            BranchTestSupport.JsonOptions);

        Assert.NotNull(response);
        Assert.True(response.CanViewMaterialValue);
        Assert.Null(Assert.Single(response.Items).MaterialValueVnd);
    }

    [Fact]
    public async Task Summary_TinhMotTongKgVaTongQuyDoiTachTheoDonVi()
    {
        var identity = await ResetAndSeedIdentityAsync(SystemRoleCodes.Company, 1, null);
        factory.WeighStationDataSource.SetSummary(
        [
            new("Cát vàng", "Nhập hàng", 1000, 2, "M3"),
            new("Cát vàng", "Nhập hàng", 500, 1, "m³"),
            new("Xi măng PCB40", "Nhập hàng", 2000, 1000, "Tấn"),
            new("Phụ gia Sika", "Nhập hàng", 300, 2, "Lít"),
            new("Bao bì", "Nhập hàng", 100, 0, null),
            new("Bê tông thương phẩm", "Bán hàng", 400, 1, "KG"),
            new("Cân dịch vụ", "Dịch vụ", 50, 0, null)
        ]);
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var response = await client.GetFromJsonAsync<WeighStationSummaryResponse>(
            "/api/weigh-station-management/summary?branchId=10&stage=Second&" + TimeQuery,
            BranchTestSupport.JsonOptions);

        Assert.NotNull(response);
        Assert.Equal(6, response.TotalCount);
        Assert.Equal(4350m, response.TotalGoodsWeightKg);
        Assert.Equal("Xi măng PCB40", response.TopGoods?.GoodsName);
        Assert.Equal(2000m, response.TopGoods?.GoodsWeightKg);
        Assert.Equal(10, response.PageSize);
        Assert.Equal(6, response.Items.Count);
        Assert.Empty(response.Groups);
        AssertConverted(response.TotalConvertedQuantities, "m³", 1000m);
        AssertConverted(response.TotalConvertedQuantities, "tấn", 2.4m);
        AssertConverted(response.TotalConvertedQuantities, "L", 150m);
        Assert.Equal(1, factory.WeighStationDataSource.SummaryCallCount);
    }

    [Fact]
    public async Task Summary_KhongPhanNhomTheoTenVaCongDonViKgVaoTongTan()
    {
        var identity = await ResetAndSeedIdentityAsync(SystemRoleCodes.Company, 1, null);
        factory.WeighStationDataSource.SetSummary(
        [
            new("Đá 1x2", "Nhập hàng", 1000, 1, "KG")
        ]);
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var response = await client.GetFromJsonAsync<WeighStationSummaryResponse>(
            "/api/weigh-station-management/summary?branchId=10&stage=Second&" + TimeQuery,
            BranchTestSupport.JsonOptions);

        Assert.NotNull(response);
        Assert.Equal(1000m, response.TotalGoodsWeightKg);
        Assert.Empty(response.Groups);
        AssertConverted(response.TotalConvertedQuantities, "tấn", 1m);
    }

    [Fact]
    public async Task Summary_HeSo0_TraChuaXacDinhVaDonViRongMacDinhKg()
    {
        var identity = await ResetAndSeedIdentityAsync(SystemRoleCodes.Company, 1, null);
        factory.WeighStationDataSource.SetSummary(
        [
            new("Xi A", "Nhập hàng", 280010, 0, null),
            new("Xi B", "Nhập hàng", 175120, 1, null)
        ]);
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var response = await client.GetFromJsonAsync<WeighStationSummaryResponse>(
            "/api/weigh-station-management/summary?branchId=10&stage=Second&" + TimeQuery,
            BranchTestSupport.JsonOptions);

        Assert.NotNull(response);
        var undefined = Assert.Single(response.Items, item => item.GoodsName == "Xi A");
        Assert.Empty(undefined.ConvertedQuantities);
        Assert.Equal(WeighStationConversionMessages.Undefined, undefined.ConversionMessage);

        var defaultKg = Assert.Single(response.Items, item => item.GoodsName == "Xi B");
        AssertConverted(defaultKg.ConvertedQuantities, "tấn", 175.12m);
        Assert.Null(defaultKg.ConversionMessage);
    }

    [Fact]
    public async Task KhoangNgayKhongHopLe_Tra400VaKhongQueryDatabaseTram()
    {
        var identity = await ResetAndSeedIdentityAsync(SystemRoleCodes.Company, 1, null);
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var response = await client.GetAsync(
            "/api/weigh-station-management?branchId=10&stage=Second&" +
            "from=2026-08-06T00:00:00%2B07:00&to=2026-08-05T00:00:00%2B07:00");

        await AssertProblemAsync(
            response,
            HttpStatusCode.BadRequest,
            "Thời gian bắt đầu phải nhỏ hơn thời gian kết thúc.");
        Assert.Equal(0, factory.WeighStationDataSource.SearchCallCount);
    }

    [Fact]
    public async Task DatabaseTramLoi_Tra503VaKhongLoChiTietNoiBo()
    {
        var identity = await ResetAndSeedIdentityAsync(SystemRoleCodes.Company, 1, null);
        factory.WeighStationDataSource.SetUnavailable();
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var response = await client.GetAsync(
            "/api/weigh-station-management?branchId=10&stage=Second&" + TimeQuery);
        var body = await response.Content.ReadAsStringAsync();

        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
        var problem = JsonSerializer.Deserialize<ProblemDetails>(body, BranchTestSupport.JsonOptions);
        Assert.NotNull(problem);
        Assert.Equal("Dữ liệu trạm cân chưa sẵn sàng", problem.Detail);
        Assert.DoesNotContain("SqlException", body, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("should-not-leak", body, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task OpenApi_CongBoDuEndpointVaContractMoi()
    {
        await factory.ResetDatabaseAsync();
        using var client = factory.CreateClient();

        var response = await client.GetAsync("/openapi/v1.json");
        response.EnsureSuccessStatusCode();
        using var document = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
        var paths = document.RootElement.GetProperty("paths");
        AssertResponses(paths.GetProperty("/api/weigh-station-management/stations").GetProperty("get"),
            "200", "400", "401", "403");
        AssertResponses(paths.GetProperty("/api/weigh-station-management/filters").GetProperty("get"),
            "200", "400", "401", "403", "503");
        AssertResponses(paths.GetProperty("/api/weigh-station-management").GetProperty("get"),
            "200", "400", "401", "403", "503");
        AssertResponses(paths.GetProperty("/api/weigh-station-management/summary").GetProperty("get"),
            "200", "400", "401", "403", "503");
        AssertResponses(paths.GetProperty("/api/weigh-station-management/export").GetProperty("get"),
            "200", "400", "401", "403", "503");
        AssertResponses(paths.GetProperty("/api/weigh-station-management/summary/export").GetProperty("get"),
            "200", "400", "401", "403", "503");

        var schemas = document.RootElement.GetProperty("components").GetProperty("schemas");
        var properties = schemas.GetProperty(nameof(WeighStationItemResponse)).GetProperty("properties");
        foreach (var propertyName in new[]
        {
            "stt", "id", "ticketNumber", "ticketCode", "weighingAt", "vehiclePlate",
            "driverName", "sealNumber", "inboundWeightKg", "outboundWeightKg", "goodsWeightKg",
            "hasConversionConfiguration", "convertedQuantity", "convertedUnit", "conversionMessage",
            "materialValueVnd",
            "unitName", "goodsName", "weighingType", "firstOperatorName", "secondOperatorName",
            "weighedInAt", "weighedOutAt"
        })
        {
            Assert.True(properties.TryGetProperty(propertyName, out _), $"Thiếu field {propertyName}.");
        }
        var summaryProperties = schemas.GetProperty(nameof(WeighStationSummaryResponse))
            .GetProperty("properties");
        foreach (var propertyName in new[]
        {
            "items", "totalCount", "totalGoodsWeightKg", "totalConvertedQuantities",
            "topGoods", "groups", "totalMaterialValueVnd", "canViewMaterialValue"
        })
        {
            Assert.True(summaryProperties.TryGetProperty(propertyName, out _),
                $"Thiếu field summary {propertyName}.");
        }
        var summaryItemProperties = schemas.GetProperty(nameof(WeighStationSummaryItemResponse))
            .GetProperty("properties");
        Assert.True(summaryItemProperties.TryGetProperty("conversionMessage", out _),
            "Thiếu field conversionMessage của dòng tổng hợp.");
    }

    private static WeighStationRow CreateRow(Guid id) =>
        new(
            153804,
            id,
            " 260805-0008 ",
            " 89 C 11415 ",
            " lợi ",
            " 202625136784 ",
            40740,
            15770,
            24970,
            2,
            " M3 ",
            " Cty Thành Phát ",
            " Bê tông thương phẩm ",
            " Bán hàng ",
            " vanhanh ",
            " vanhanh ",
            new DateTime(2026, 8, 5, 11, 2, 40),
            new DateTime(2026, 8, 5, 11, 4, 8),
            new DateTime(2026, 8, 5, 12, 50, 16));

    private async Task<BranchTestIdentity> ResetAndSeedIdentityAsync(
        string roleCode,
        int? companyId,
        string? branchIds,
        params ActiveKeyPermission[] additionalPermissions)
    {
        BranchTestIdentity identity = null!;
        await factory.ResetDatabaseAsync(async (services, authDbContext) =>
        {
            var permissions = new[] { ActiveKeyPermission.DSach }
                .Concat(additionalPermissions)
                .Distinct()
                .ToArray();
            identity = await BranchTestSupport.SeedWeighStationIdentityAsync(
                services,
                authDbContext,
                roleCode,
                companyId,
                branchIds,
                permissions);
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
            BranchTestSupport.CreateBranch(10, 1, "CAN_10", "Trạm cân 10", typeTram: 2),
            BranchTestSupport.CreateBranch(11, 1, "TRON_11", "Trạm trộn 11"),
            BranchTestSupport.CreateBranch(12, 1, "CAN_12", "Trạm cân khóa", 2, WebDataStatus.Inactive),
            BranchTestSupport.CreateBranch(20, 2, "CAN_20", "Trạm cân 20", typeTram: 2));
        await companyDbContext.SaveChangesAsync();
    }

    private static void AssertConverted(
        IReadOnlyList<WeighStationConvertedQuantityResponse> values,
        string unit,
        decimal expected) =>
        Assert.Equal(expected, values.Single(item => item.Unit == unit).Quantity);

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
            Assert.True(responses.TryGetProperty(statusCode, out _),
                $"Thiếu response {statusCode} trong OpenAPI.");
        }
    }
}
