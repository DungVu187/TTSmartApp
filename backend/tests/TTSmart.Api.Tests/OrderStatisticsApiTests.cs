using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.DependencyInjection;
using TTSmart.Api.Data.Company;
using TTSmart.Api.Data.WebAuth;
using TTSmart.Api.Features.Authorization;
using TTSmart.Api.Features.OrderStatistics;

namespace TTSmart.Api.Tests;

public sealed class OrderStatisticsApiTests(TTSmartApiFactory factory) : IClassFixture<TTSmartApiFactory>
{
    private const string SearchTimeQuery =
        "from=2026-08-03T00%3A00%3A00%2B07%3A00&to=2026-08-04T00%3A00%3A00%2B07%3A00";

    [Theory]
    [InlineData("/api/order-statistics/stations")]
    [InlineData("/api/order-statistics/filters?branchId=10&" + SearchTimeQuery)]
    [InlineData("/api/order-statistics?branchId=10&" + SearchTimeQuery)]
    public async Task ChuaDangNhap_Tra401(string requestUri)
    {
        await factory.ResetDatabaseAsync();
        using var client = factory.CreateClient();

        Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync(requestUri)).StatusCode);
    }

    [Fact]
    public async Task KhongCoQuyenTKDH_Tra403()
    {
        BranchTestIdentity identity = null!;
        await factory.ResetDatabaseAsync(async (services, authDbContext) =>
        {
            identity = await BranchTestSupport.SeedIdentityAsync(
                services,
                authDbContext,
                "CONGTY",
                1,
                null);
            await SeedCompanyAndBranchAsync(services);
        });
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        Assert.Equal(HttpStatusCode.Forbidden, (await client.GetAsync(
            "/api/order-statistics?branchId=10&" + SearchTimeQuery)).StatusCode);
    }

    [Theory]
    [InlineData("/api/order-statistics/stations")]
    [InlineData("/api/order-statistics/filters?companyId=1&branchId=10&" + SearchTimeQuery)]
    [InlineData("/api/order-statistics?companyId=1&branchId=10&" + SearchTimeQuery)]
    public async Task ADMIN_KhongCoFunctionTKDH_Tra403(string requestUri)
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
            await SeedCompanyAndBranchAsync(services);
        });
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        Assert.Equal(HttpStatusCode.Forbidden, (await client.GetAsync(requestUri)).StatusCode);
        Assert.Equal(0, factory.OrderStatisticsDataSource.SearchCallCount);
        Assert.Equal(0, factory.OrderStatisticsDataSource.FilterCallCount);
    }

    [Fact]
    public async Task ChiCoQuyenViewKhongCoDSach_Tra403()
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
                ActiveKeyPermission.View);
            await SeedCompanyAndBranchAsync(services);
        });
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        Assert.Equal(HttpStatusCode.Forbidden, (await client.GetAsync(
            "/api/order-statistics?branchId=10&" + SearchTimeQuery)).StatusCode);
        Assert.Equal(0, factory.OrderStatisticsDataSource.SearchCallCount);
    }

    [Fact]
    public async Task ADMIN_BatBuocChonCongTyRoiChonTram_VaKhongQueryDatabaseKhiThieuScope()
    {
        BranchTestIdentity identity = null!;
        await factory.ResetDatabaseAsync(async (services, authDbContext) =>
        {
            identity = await BranchTestSupport.SeedOrderStatisticsIdentityAsync(
                services,
                authDbContext,
                SystemRoleCodes.Admin,
                null,
                null,
                ActiveKeyPermission.DSach);
            await SeedCompanyAndBranchAsync(services);
        });
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var missingCompanyResponse = await client.GetAsync(
            "/api/order-statistics?" + SearchTimeQuery);
        Assert.Equal(HttpStatusCode.BadRequest, missingCompanyResponse.StatusCode);
        var missingCompanyProblem = await missingCompanyResponse.Content
            .ReadFromJsonAsync<ProblemDetails>(BranchTestSupport.JsonOptions);
        Assert.Equal("Chưa chọn công ty.", missingCompanyProblem?.Detail);

        var missingBranchResponse = await client.GetAsync(
            "/api/order-statistics?companyId=1&" + SearchTimeQuery);
        Assert.Equal(HttpStatusCode.BadRequest, missingBranchResponse.StatusCode);
        var missingBranchProblem = await missingBranchResponse.Content
            .ReadFromJsonAsync<ProblemDetails>(BranchTestSupport.JsonOptions);
        Assert.Equal("Chưa chọn trạm.", missingBranchProblem?.Detail);
        Assert.Equal(0, factory.OrderStatisticsDataSource.SearchCallCount);
    }

    [Theory]
    [InlineData("/api/order-statistics/filters?" + SearchTimeQuery)]
    [InlineData("/api/order-statistics?" + SearchTimeQuery)]
    public async Task CONGTY_ThieuTram_Tra400VaKhongQueryDataSource(string requestUri)
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
            await SeedCompanyAndBranchAsync(services);
        });
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var response = await client.GetAsync(requestUri);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var problem = await response.Content.ReadFromJsonAsync<ProblemDetails>(BranchTestSupport.JsonOptions);
        Assert.Equal("Chưa chọn trạm.", problem?.Detail);
        Assert.Equal(0, factory.OrderStatisticsDataSource.SearchCallCount);
        Assert.Equal(0, factory.OrderStatisticsDataSource.FilterCallCount);
    }

    [Fact]
    public async Task Filters_ADMIN_ThieuScope_KhongQueryDataSource()
    {
        BranchTestIdentity identity = null!;
        await factory.ResetDatabaseAsync(async (services, authDbContext) =>
        {
            identity = await BranchTestSupport.SeedOrderStatisticsIdentityAsync(
                services,
                authDbContext,
                SystemRoleCodes.Admin,
                null,
                null,
                ActiveKeyPermission.DSach);
            await SeedCompanyAndBranchAsync(services);
        });
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var missingCompanyResponse = await client.GetAsync(
            "/api/order-statistics/filters?" + SearchTimeQuery);
        var missingBranchResponse = await client.GetAsync(
            "/api/order-statistics/filters?companyId=1&" + SearchTimeQuery);

        Assert.Equal(HttpStatusCode.BadRequest, missingCompanyResponse.StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, missingBranchResponse.StatusCode);
        Assert.Equal(0, factory.OrderStatisticsDataSource.FilterCallCount);
    }

    [Fact]
    public async Task Filters_ThieuKhoangThoiGian_Tra400VaKhongQueryDataSource()
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
            await SeedCompanyAndBranchAsync(services);
        });
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var response = await client.GetAsync(
            "/api/order-statistics/filters?branchId=10");

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Equal(0, factory.OrderStatisticsDataSource.FilterCallCount);
    }

    [Fact]
    public async Task MocThoiGianBangNhau_DuocChapNhanViWebLocInclusive()
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
            await SeedCompanyAndBranchAsync(services);
        });
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);
        const string sameTime =
            "from=2026-08-03T08%3A15%3A42%2B07%3A00&to=2026-08-03T08%3A15%3A42%2B07%3A00";

        var response = await client.GetAsync(
            "/api/order-statistics?branchId=10&" + sameTime);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.True(Assert.Single(factory.OrderStatisticsDataSource.SeenFilters)
            .UseFinishedAtInclusive);
    }

    [Fact]
    public async Task CONGTY_LocCheoCongTy_Tra403VaKhongQueryDataSource()
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
            companyDbContext.Companies.AddRange(
                BranchTestSupport.CreateCompany(1, "CT_1", "Công ty 1"),
                BranchTestSupport.CreateCompany(2, "CT_2", "Công ty 2"));
            companyDbContext.Branches.AddRange(
                BranchTestSupport.CreateBranch(10, 1, "TRAM_10", "Trạm 10"),
                BranchTestSupport.CreateBranch(20, 2, "TRAM_20", "Trạm 20"));
            await companyDbContext.SaveChangesAsync();
        });
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var response = await client.GetAsync(
            "/api/order-statistics?companyId=2&branchId=20&" + SearchTimeQuery);

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        Assert.Equal(0, factory.OrderStatisticsDataSource.SearchCallCount);
    }

    [Fact]
    public async Task TaiKhoanTheoTram_TruyCapCheoTram_Tra404VaKhongQueryDataSource()
    {
        BranchTestIdentity identity = null!;
        await factory.ResetDatabaseAsync(async (services, authDbContext) =>
        {
            identity = await BranchTestSupport.SeedOrderStatisticsIdentityAsync(
                services,
                authDbContext,
                "QUANLY",
                1,
                "10",
                ActiveKeyPermission.DSach);
            var companyDbContext = services.GetRequiredService<CompanyDbContext>();
            companyDbContext.Companies.Add(BranchTestSupport.CreateCompany(1, "CT_1", "Công ty 1"));
            companyDbContext.Branches.AddRange(
                BranchTestSupport.CreateBranch(10, 1, "TRAM_10", "Trạm được cấp"),
                BranchTestSupport.CreateBranch(11, 1, "TRAM_11", "Trạm ngoài phạm vi"));
            await companyDbContext.SaveChangesAsync();
        });
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var response = await client.GetAsync(
            "/api/order-statistics/filters?branchId=11&" + SearchTimeQuery);

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        Assert.Equal(0, factory.OrderStatisticsDataSource.FilterCallCount);
    }

    [Fact]
    public async Task TramKhongHoatDongHoacKhongPhaiTramTron_Tra404VaKhongQueryDataSource()
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
            companyDbContext.Companies.Add(BranchTestSupport.CreateCompany(1, "CT_1", "Công ty 1"));
            companyDbContext.Branches.AddRange(
                BranchTestSupport.CreateBranch(
                    10,
                    1,
                    "INACTIVE",
                    "Trạm ngừng hoạt động",
                    status: WebDataStatus.Inactive),
                BranchTestSupport.CreateBranch(11, 1, "WEIGH", "Trạm cân", typeTram: 2));
            await companyDbContext.SaveChangesAsync();
        });
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var inactiveResponse = await client.GetAsync(
            "/api/order-statistics?branchId=10&" + SearchTimeQuery);
        var nonMixingResponse = await client.GetAsync(
            "/api/order-statistics/filters?branchId=11&" + SearchTimeQuery);

        Assert.Equal(HttpStatusCode.NotFound, inactiveResponse.StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, nonMixingResponse.StatusCode);
        Assert.Equal(0, factory.OrderStatisticsDataSource.SearchCallCount);
        Assert.Equal(0, factory.OrderStatisticsDataSource.FilterCallCount);
    }

    [Fact]
    public async Task FiltersVaTimKiem_GiuNguyenCanTrenExclusive_TrimVaTruyenDungViewMode()
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
            await SeedCompanyAndBranchAsync(services);
        });
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);
        var filterQuery = string.Join('&',
            "from=2026-08-03T08%3A15%3A42%2B07%3A00",
            "to=2026-08-03T08%3A30%3A59%2B07%3A00",
            $"vehiclePlate={Uri.EscapeDataString("  30A-12345  ")}",
            $"customerName={Uri.EscapeDataString("  Khách hàng A  ")}",
            $"concreteGradeName={Uri.EscapeDataString("  M300  ")}",
            $"employeeName={Uri.EscapeDataString("  Nhân viên A  ")}");

        var filtersResponse = await client.GetAsync(
            $"/api/order-statistics/filters?branchId=10&{filterQuery}");
        var searchResponse = await client.GetAsync(
            $"/api/order-statistics?branchId=10&viewMode=total&{filterQuery}");

        Assert.Equal(HttpStatusCode.OK, filtersResponse.StatusCode);
        Assert.Equal(HttpStatusCode.OK, searchResponse.StatusCode);
        var optionFilter = Assert.Single(
            factory.OrderStatisticsDataSource.SeenFilterOptionFilters);
        Assert.Equal(new DateTime(2026, 8, 3, 8, 15, 42), optionFilter.FromInclusive);
        Assert.Equal(new DateTime(2026, 8, 3, 8, 30, 59), optionFilter.ToExclusive);
        Assert.True(optionFilter.UseFinishedAtInclusive);
        Assert.Null(optionFilter.VehiclePlate);
        Assert.Null(optionFilter.CustomerName);
        Assert.Null(optionFilter.ConcreteGradeName);
        Assert.Null(optionFilter.EmployeeName);
        Assert.Single(factory.OrderStatisticsDataSource.SeenFilters);
        Assert.All(factory.OrderStatisticsDataSource.SeenFilters, filter =>
        {
            Assert.Equal(new DateTime(2026, 8, 3, 8, 15, 42), filter.FromInclusive);
            Assert.Equal(new DateTime(2026, 8, 3, 8, 30, 59), filter.ToExclusive);
            Assert.True(filter.UseFinishedAtInclusive);
            Assert.Equal("30A-12345", filter.VehiclePlate);
            Assert.Equal("Khách hàng A", filter.CustomerName);
            Assert.Equal("M300", filter.ConcreteGradeName);
            Assert.Equal("Nhân viên A", filter.EmployeeName);
        });
        Assert.Equal(OrderStatisticsViewMode.Total, factory.OrderStatisticsDataSource.SeenViewModes.Single());
    }

    [Fact]
    public async Task TimKiemKhongCoDuLieu_TraTongVaKhoangDongBang0()
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
            await SeedCompanyAndBranchAsync(services);
        });
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var response = await client.GetFromJsonAsync<OrderStatisticsResponse>(
            "/api/order-statistics?branchId=10&" + SearchTimeQuery,
            BranchTestSupport.JsonOptions);

        Assert.NotNull(response);
        Assert.Empty(response.Items);
        Assert.Equal(0, response.TotalCount);
        Assert.Equal(0, response.TotalPages);
        Assert.Equal(0, response.FromRowNumber);
        Assert.Equal(0, response.ToRowNumber);
        Assert.Equal(0m, response.TotalMaterialQuantity);
        Assert.Equal(0m, response.TotalConcreteVolume);
        Assert.Single(response.Layouts);
        Assert.Empty(response.MaterialSummaryRows);
    }

    [Theory]
    [InlineData("pageNumber=0&pageSize=10")]
    [InlineData("pageNumber=1&pageSize=9")]
    [InlineData("pageNumber=1&pageSize=11")]
    [InlineData("pageNumber=2147483647&pageSize=10")]
    public async Task PageHoacPageSizeKhongHopLe_Tra400VaKhongQueryDataSource(string pagingQuery)
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
            await SeedCompanyAndBranchAsync(services);
        });
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var response = await client.GetAsync(
            $"/api/order-statistics?branchId=10&{pagingQuery}&{SearchTimeQuery}");

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Equal(0, factory.OrderStatisticsDataSource.SearchCallCount);
    }

    [Fact]
    public async Task TimKiem_LayoutLichSuTrungSoCua_GopDuLieuKhongCrash()
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
            await SeedCompanyAndBranchAsync(services);
        });
        var previousSlot = new OrderStatisticsMaterialValue(
            500,
            5,
            "Cát cũ",
            "Cát",
            1,
            2,
            3,
            2,
            "SAND",
            1);
        var currentSlot = new OrderStatisticsMaterialValue(
            501,
            5,
            "Cát mới",
            "Cát",
            4,
            5,
            6,
            2,
            "SAND",
            1);
        factory.OrderStatisticsDataSource.SetPage(CreatePage(
            [CreateRow(201, [previousSlot, currentSlot])],
            [currentSlot],
            [CreateColumn(currentSlot)]));

        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var response = await client.GetFromJsonAsync<OrderStatisticsResponse>(
            "/api/order-statistics?branchId=10&viewMode=total&" + SearchTimeQuery,
            BranchTestSupport.JsonOptions);

        Assert.NotNull(response);
        var item = Assert.Single(response.Items);
        var material = Assert.Single(item.Materials);
        Assert.Equal(5, material.SlotNumber);
        Assert.Equal("Cát mới", material.MaterialName);
        Assert.Equal(9m, material.ActualQuantity);
        Assert.Single(response.Layouts.Single().Columns);
    }

    [Fact]
    public async Task TimKiem_MapDuLieuPhanTrangUtcTongVaDungLayoutVatLieuDong()
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
            await SeedCompanyAndBranchAsync(services);
        });
        var material = new OrderStatisticsMaterialValue(
            100,
            1,
            "Cát 1",
            "Cát",
            10,
            11,
            12,
            2);
        factory.OrderStatisticsDataSource.SetPage(new OrderStatisticsPage(
            [new OrderStatisticsRow(
                101,
                201,
                3,
                new DateTime(2026, 8, 3),
                new DateTime(2026, 8, 3, 8, 0, 0),
                new DateTime(2026, 8, 3, 8, 2, 0),
                "Khách hàng A",
                "Dự án A",
                "Hạng mục A",
                "Địa điểm A",
                "30A-12345",
                "Lái xe A",
                "M300",
                "12+-2",
                2,
                2,
                "NV01",
                "Nhân viên A",
                1,
                [material])],
            2,
            OrderStatisticsContractDefaults.PageSize,
            11,
            new OrderStatisticsSummary(6, 12, [material]),
            [new OrderStatisticsMaterialColumn(
                100,
                1,
                "Cát 1",
                "Cát",
                "ĐM.Cát 1",
                "T.Cát 1",
                "Cát 1",
                "SS.Cát 1")]));
        factory.OrderStatisticsDataSource.SetFilterOptions(new OrderStatisticsFilterOptions(
            ["30A-12345"],
            ["Khách hàng A"],
            ["M300"],
            ["Nhân viên A"]));

        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var stations = await client.GetFromJsonAsync<OrderStatisticsStationResponse[]>(
            "/api/order-statistics/stations",
            BranchTestSupport.JsonOptions);
        Assert.NotNull(stations);
        Assert.Equal([10], stations.Select(station => station.Id).ToArray());
        Assert.Equal("TRAM_10", stations[0].Code);

        var filters = await client.GetFromJsonAsync<OrderStatisticsFilterOptionsResponse>(
            "/api/order-statistics/filters?branchId=10&" + SearchTimeQuery,
            BranchTestSupport.JsonOptions);
        Assert.NotNull(filters);
        Assert.Equal(["30A-12345"], filters.VehiclePlates);

        var response = await client.GetFromJsonAsync<OrderStatisticsResponse>(
            "/api/order-statistics?branchId=10&pageNumber=2&pageSize=10&viewMode=detail&" + SearchTimeQuery,
            BranchTestSupport.JsonOptions);
        Assert.NotNull(response);
        Assert.Equal(11, response.TotalCount);
        Assert.Equal(2, response.TotalPages);
        Assert.Equal(11, response.FromRowNumber);
        Assert.Equal(11, response.ToRowNumber);
        Assert.Equal(12m, response.TotalMaterialQuantity);
        Assert.Equal(6m, response.TotalConcreteVolume);
        Assert.Single(response.Items);
        Assert.Equal(11, response.Items[0].RowNumber);
        Assert.Equal("TRAM_10", response.Items[0].StationCode);
        Assert.Single(response.Items[0].Materials);
        Assert.Single(response.Layouts);
        Assert.Single(response.Layouts.Single().Columns);
        Assert.Single(response.MaterialSummaryRows);
        Assert.Equal(TimeSpan.Zero, response.Items[0].StartedAt?.Offset);
        Assert.Equal(new DateTimeOffset(2026, 8, 3, 1, 0, 0, TimeSpan.Zero), response.Items[0].StartedAt);
        Assert.Equal(10, factory.OrderStatisticsDataSource.SeenTargets.Last().BranchId);
        Assert.Equal("TRAM_10_online", factory.OrderStatisticsDataSource.SeenTargets.Last().DatabaseName);
    }

    [Fact]
    public async Task BaCuaCat_ChiTraBaCotVaBaDongTong()
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
            await SeedCompanyAndBranchAsync(services);
        });
        var materials = new[]
        {
            CreateMaterial(101, 1, "Cát 3", "Cát", OrderStatisticsMaterialCategories.Sand, 1, 30),
            CreateMaterial(102, 2, "Cát 2", "Cát", OrderStatisticsMaterialCategories.Sand, 2, 20),
            CreateMaterial(103, 3, "Cát 1", "Cát", OrderStatisticsMaterialCategories.Sand, 3, 10)
        };
        factory.OrderStatisticsDataSource.SetPage(CreatePage(
            [CreateRow(301, materials)],
            materials,
            materials.Select(CreateColumn).ToArray()));
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var response = await client.GetFromJsonAsync<OrderStatisticsResponse>(
            "/api/order-statistics?branchId=10&" + SearchTimeQuery,
            BranchTestSupport.JsonOptions);

        Assert.NotNull(response);
        var columns = Assert.Single(response.Layouts).Columns;
        Assert.Equal(3, columns.Count);
        Assert.Equal(["Cát 3", "Cát 2", "Cát 1"],
            columns.Select(column => column.MaterialName!).ToArray());
        Assert.Equal([1, 2, 3],
            columns.Select(column => column.TypePosition).ToArray());
        Assert.Equal(3, response.Items.Single().Materials.Count);
        Assert.Equal(3, response.MaterialSummaryRows.Count);
        Assert.Equal([1, 2, 3], response.MaterialSummaryRows.Select(row => row.RowNumber).ToArray());
        Assert.All(
            response.MaterialSummaryRows.SelectMany(row => row.Cells),
            cell => Assert.Equal(
                cell.CategoryCode == OrderStatisticsMaterialCategories.Water ? "LÍT" : "KG",
                cell.Unit));
    }

    [Fact]
    public async Task VatLieu_LamTronTheoNhomGiongWeb()
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
            await SeedCompanyAndBranchAsync(services);
        });
        var materials = new[]
        {
            CreateMaterial(701, 1, "Cát", "Cát", OrderStatisticsMaterialCategories.Sand, 1, 10.55),
            CreateMaterial(702, 2, "Xi măng", "Xi măng", OrderStatisticsMaterialCategories.Cement, 1, 10.55),
            CreateMaterial(703, 3, "Phụ gia", "Phụ gia", OrderStatisticsMaterialCategories.Additive, 1, 10.555)
        };
        factory.OrderStatisticsDataSource.SetPage(CreatePage(
            [CreateRow(701, materials)],
            materials,
            materials.Select(CreateColumn).ToArray()));
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var response = await client.GetFromJsonAsync<OrderStatisticsResponse>(
            "/api/order-statistics?branchId=10&" + SearchTimeQuery,
            BranchTestSupport.JsonOptions);

        Assert.NotNull(response);
        var values = response.Items.Single().Materials;
        Assert.Equal(11m, values.Single(item => item.CategoryCode == "CAT").ActualQuantity);
        Assert.Equal(10.6m, values.Single(item => item.CategoryCode == "XIMANG").ActualQuantity);
        Assert.Equal(10.56m, values.Single(item => item.CategoryCode == "PHUGIA").ActualQuantity);
        Assert.Equal(31.66m, response.TotalMaterialQuantity);
    }

    [Fact]
    public async Task MuoiSauVatLieu_TraDuCotDongKhongGioiHanMuoiBon()
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
            await SeedCompanyAndBranchAsync(services);
        });
        var materials = Enumerable.Range(1, 16)
            .Select(position => CreateMaterial(
                1000 + position,
                position,
                $"Cát {position}",
                "Cát",
                OrderStatisticsMaterialCategories.Sand,
                position,
                position))
            .ToArray();
        factory.OrderStatisticsDataSource.SetPage(CreatePage(
            [CreateRow(401, materials)],
            materials,
            materials.Select(CreateColumn).ToArray()));
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var response = await client.GetFromJsonAsync<OrderStatisticsResponse>(
            "/api/order-statistics?branchId=10&" + SearchTimeQuery,
            BranchTestSupport.JsonOptions);

        Assert.NotNull(response);
        var columns = Assert.Single(response.Layouts).Columns;
        Assert.Equal(16, columns.Count);
        Assert.Equal(16, response.Items.Single().Materials.Count);
        Assert.Equal(16, response.MaterialSummaryRows.Count);
        Assert.Contains(columns, column => column.SlotNumber == 16);
    }

    [Fact]
    public async Task HaiItemKhacLayout_TraLayoutKeyKhacVaDanhSachLayoutsDayDu()
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
            await SeedCompanyAndBranchAsync(services);
        });
        var firstLayout = new[]
        {
            CreateMaterial(201, 1, "Cát 1", "Cát", OrderStatisticsMaterialCategories.Sand, 1, 10),
            CreateMaterial(202, 2, "Đá 1", "Đá", OrderStatisticsMaterialCategories.Stone, 1, 20)
        };
        var secondLayout = new[]
        {
            CreateMaterial(301, 1, "Cát 1", "Cát", OrderStatisticsMaterialCategories.Sand, 1, 11),
            CreateMaterial(302, 2, "Nước 1", "Nước", OrderStatisticsMaterialCategories.Water, 1, 21)
        };
        factory.OrderStatisticsDataSource.SetPage(CreatePage(
            [CreateRow(501, firstLayout), CreateRow(502, secondLayout)],
            [.. firstLayout, .. secondLayout],
            firstLayout.Select(CreateColumn).ToArray()));
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var response = await client.GetFromJsonAsync<OrderStatisticsResponse>(
            "/api/order-statistics?branchId=10&" + SearchTimeQuery,
            BranchTestSupport.JsonOptions);

        Assert.NotNull(response);
        Assert.Equal(2, response.Items.Count);
        Assert.NotEqual(response.Items[0].LayoutKey, response.Items[1].LayoutKey);
        Assert.Equal(2, response.Layouts.Count);
        Assert.All(response.Items, item =>
            Assert.Contains(response.Layouts, layout => layout.LayoutKey == item.LayoutKey));
        Assert.Contains(response.Layouts, layout => layout.Columns.Any(
            column => column.CategoryCode == OrderStatisticsMaterialCategories.Water));
    }

    [Fact]
    public async Task CurrentLayoutBaCat_RowThieuViTriHai_VanTraDuBaCellVaKhongDonViTriBa()
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
            await SeedCompanyAndBranchAsync(services);
        });
        var currentLayout = new[]
        {
            CreateMaterial(101, 1, "Cat 1", "Cat", OrderStatisticsMaterialCategories.Sand, 1, 0),
            CreateMaterial(102, 2, "Cat 2", "Cat", OrderStatisticsMaterialCategories.Sand, 2, 0),
            CreateMaterial(103, 3, "Cat 3", "Cat", OrderStatisticsMaterialCategories.Sand, 3, 0)
        };
        var rowMaterials = new[]
        {
            CreateMaterial(201, 1, "Cat 1", "Cat", OrderStatisticsMaterialCategories.Sand, 1, 10),
            CreateMaterial(203, 3, "Cat 3", "Cat", OrderStatisticsMaterialCategories.Sand, 2, 30)
        };
        factory.OrderStatisticsDataSource.SetPage(CreatePage(
            [CreateRow(601, rowMaterials)],
            rowMaterials,
            currentLayout.Select(CreateColumn).ToArray()));
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var response = await client.GetFromJsonAsync<OrderStatisticsResponse>(
            "/api/order-statistics?branchId=10&" + SearchTimeQuery,
            BranchTestSupport.JsonOptions);

        Assert.NotNull(response);
        var materials = response.Items.Single().Materials;
        Assert.Equal(3, materials.Count);
        Assert.Equal([1, 2, 3], materials.Select(material => material.TypePosition).ToArray());
        var missingPosition = Assert.Single(materials, material => material.TypePosition == 2);
        Assert.Equal(2, missingPosition.SlotNumber);
        Assert.Equal(0m, missingPosition.DesignQuantity);
        Assert.Equal(0m, missingPosition.TQuantity);
        Assert.Equal(0m, missingPosition.ActualQuantity);
        Assert.Equal(0m, missingPosition.Variance);
        var thirdPosition = Assert.Single(materials, material => material.TypePosition == 3);
        Assert.Equal(3, thirdPosition.SlotNumber);
        Assert.Equal("Cat 3", thirdPosition.MaterialName);
        Assert.Equal(30m, thirdPosition.ActualQuantity);
    }

    [Fact]
    public async Task HistoricalSlotMotCat_CurrentSlotMotDa_ItemVanGiuLayoutCat()
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
            await SeedCompanyAndBranchAsync(services);
        });
        var currentMaterial = CreateMaterial(
            301,
            1,
            "Da hien tai",
            "Da",
            OrderStatisticsMaterialCategories.Stone,
            1,
            0);
        var historicalMaterial = CreateMaterial(
            401,
            1,
            "Cat lich su",
            "Cat",
            OrderStatisticsMaterialCategories.Sand,
            1,
            25);
        factory.OrderStatisticsDataSource.SetPage(CreatePage(
            [CreateRow(602, [historicalMaterial])],
            [historicalMaterial],
            [CreateColumn(currentMaterial)]));
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var response = await client.GetFromJsonAsync<OrderStatisticsResponse>(
            "/api/order-statistics?branchId=10&" + SearchTimeQuery,
            BranchTestSupport.JsonOptions);

        Assert.NotNull(response);
        Assert.Contains(
            response.Layouts.SelectMany(layout => layout.Columns),
            column => column.CategoryCode == OrderStatisticsMaterialCategories.Stone);
        var item = response.Items.Single();
        var itemMaterial = Assert.Single(item.Materials);
        Assert.Equal(OrderStatisticsMaterialCategories.Sand, itemMaterial.CategoryCode);
        Assert.Equal("Cat lich su", itemMaterial.MaterialName);
        Assert.Equal(25m, itemMaterial.ActualQuantity);
        var itemLayout = Assert.Single(
            response.Layouts,
            layout => layout.LayoutKey == item.LayoutKey);
        Assert.Equal(OrderStatisticsMaterialCategories.Sand,
            itemLayout.Columns.Single().CategoryCode);
    }

    [Fact]
    public async Task DuplicateMaterialColumnsCungSlot_RequestFailThayViAmThamChonMot()
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
            await SeedCompanyAndBranchAsync(services);
        });
        var firstColumn = CreateMaterial(
            501,
            1,
            "Cat cua mot",
            "Cat",
            OrderStatisticsMaterialCategories.Sand,
            1,
            10);
        var duplicateColumn = CreateMaterial(
            502,
            1,
            "Cat cua mot trung",
            "Cat",
            OrderStatisticsMaterialCategories.Sand,
            2,
            20);
        factory.OrderStatisticsDataSource.SetPage(CreatePage(
            [CreateRow(603, [firstColumn])],
            [firstColumn],
            [CreateColumn(firstColumn), CreateColumn(duplicateColumn)]));
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var response = await client.GetAsync(
            "/api/order-statistics?branchId=10&" + SearchTimeQuery);

        Assert.Equal(HttpStatusCode.InternalServerError, response.StatusCode);
    }

    [Fact]
    public async Task UnknownCategory_XuatHienTrongMaterialSummaryRowsDeDoiChieuTong()
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
            await SeedCompanyAndBranchAsync(services);
        });
        var unknownMaterial = CreateMaterial(
            601,
            9,
            "Vat lieu khac",
            "Khac",
            "UNKNOWN",
            1,
            17);
        factory.OrderStatisticsDataSource.SetPage(CreatePage(
            [CreateRow(604, [unknownMaterial])],
            [unknownMaterial],
            [CreateColumn(unknownMaterial)]));
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var response = await client.GetFromJsonAsync<OrderStatisticsResponse>(
            "/api/order-statistics?branchId=10&" + SearchTimeQuery,
            BranchTestSupport.JsonOptions);

        Assert.NotNull(response);
        var unknownCell = Assert.Single(
            response.MaterialSummaryRows[0].Cells,
            cell => cell.CategoryCode == "UNKNOWN");
        Assert.Equal(1, unknownCell.TypePosition);
        Assert.Equal(9, unknownCell.SlotNumber);
        Assert.Equal("Vat lieu khac", unknownCell.MaterialName);
        Assert.Equal(17m, unknownCell.ActualQuantity);
        Assert.Equal(response.TotalMaterialQuantity, unknownCell.ActualQuantity);
    }

    [Fact]
    public async Task DatabaseTramLoi_Tra503()
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
            await SeedCompanyAndBranchAsync(services);
        });
        factory.OrderStatisticsDataSource.SetUnavailable();
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        Assert.Equal(HttpStatusCode.ServiceUnavailable, (await client.GetAsync(
            "/api/order-statistics?branchId=10&" + SearchTimeQuery)).StatusCode);
    }

    [Fact]
    public async Task Filters_DatabaseTramLoi_Tra503VaKhongLoChiTietNoiBo()
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
            await SeedCompanyAndBranchAsync(services);
        });
        factory.OrderStatisticsDataSource.SetUnavailable();
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var response = await client.GetAsync(
            "/api/order-statistics/filters?branchId=10&" + SearchTimeQuery);

        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
        var body = await response.Content.ReadAsStringAsync();
        var problem = JsonSerializer.Deserialize<ProblemDetails>(body, BranchTestSupport.JsonOptions);
        Assert.NotNull(problem);
        Assert.Equal((int)HttpStatusCode.ServiceUnavailable, problem.Status);
        Assert.Equal("Dữ liệu trạm chưa sẵn sàng", problem.Detail);
        Assert.DoesNotContain("SqlException", body, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("TRAM_online", body, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("should-not-leak", body, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task OpenApi_CongBoDuEndpointVaResponseTKDH()
    {
        await factory.ResetDatabaseAsync();
        using var client = factory.CreateClient();

        var response = await client.GetAsync("/openapi/v1.json");
        response.EnsureSuccessStatusCode();
        using var document = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
        var paths = document.RootElement.GetProperty("paths");

        AssertResponses(paths.GetProperty("/api/order-statistics/stations").GetProperty("get"),
            "200", "400", "401", "403");
        AssertResponses(paths.GetProperty("/api/order-statistics/filters").GetProperty("get"),
            "200", "400", "401", "403", "404", "503");
        AssertResponses(paths.GetProperty("/api/order-statistics").GetProperty("get"),
            "200", "400", "401", "403", "404", "503");
        AssertResponses(paths.GetProperty("/api/order-statistics/export").GetProperty("get"),
            "200", "400", "401", "403", "404", "503");
    }

    private static OrderStatisticsMaterialValue CreateMaterial(
        long materialSlotId,
        int slotNumber,
        string materialName,
        string category,
        string categoryCode,
        int typePosition,
        double actualQuantity) =>
        new(
            materialSlotId,
            slotNumber,
            materialName,
            category,
            actualQuantity,
            0,
            actualQuantity,
            0,
            categoryCode,
            typePosition);

    private static OrderStatisticsMaterialColumn CreateColumn(
        OrderStatisticsMaterialValue material)
    {
        var materialName = material.MaterialName ?? $"Vật liệu {material.SlotNumber}";
        return new OrderStatisticsMaterialColumn(
            material.MaterialSlotId,
            material.SlotNumber,
            materialName,
            material.Category,
            $"ĐM.{materialName}",
            $"T.{materialName}",
            materialName,
            $"SS.{materialName}",
            material.CategoryCode,
            material.TypePosition);
    }

    private static OrderStatisticsRow CreateRow(
        long mixingHistoryId,
        IReadOnlyList<OrderStatisticsMaterialValue> materials) =>
        new(
            mixingHistoryId,
            mixingHistoryId,
            checked((int)(mixingHistoryId % 1000)),
            new DateTime(2026, 8, 3),
            new DateTime(2026, 8, 3, 8, 0, 0),
            new DateTime(2026, 8, 3, 8, 2, 0),
            "Khách hàng",
            "Dự án",
            "Hạng mục",
            "Địa điểm",
            "30A-12345",
            "Lái xe",
            "M300",
            "12+-2",
            1,
            1,
            "NV01",
            "Nhân viên vận hành",
            1,
            materials,
            "Nhân viên kinh doanh");

    private static OrderStatisticsPage CreatePage(
        IReadOnlyList<OrderStatisticsRow> items,
        IReadOnlyList<OrderStatisticsMaterialValue> summaryMaterials,
        IReadOnlyList<OrderStatisticsMaterialColumn> materialColumns) =>
        new(
            items,
            1,
            OrderStatisticsContractDefaults.PageSize,
            items.Count,
            new OrderStatisticsSummary(
                items.Count,
                summaryMaterials.Sum(material => material.ActualQuantity),
                summaryMaterials),
            materialColumns);

    private static async Task SeedCompanyAndBranchAsync(IServiceProvider services)
    {
        var companyDbContext = services.GetRequiredService<CompanyDbContext>();
        companyDbContext.Companies.Add(BranchTestSupport.CreateCompany(1, "CT_1", "Công ty 1"));
        companyDbContext.Branches.Add(BranchTestSupport.CreateBranch(10, 1, "TRAM_10", "Trạm 10"));
        await companyDbContext.SaveChangesAsync();
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
