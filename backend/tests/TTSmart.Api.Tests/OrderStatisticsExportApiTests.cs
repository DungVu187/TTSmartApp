using System.IO.Compression;
using System.Net;
using Microsoft.Extensions.DependencyInjection;
using TTSmart.Api.Data.Company;
using TTSmart.Api.Data.WebAuth;
using TTSmart.Api.Features.Authorization;
using TTSmart.Api.Features.OrderStatistics;

namespace TTSmart.Api.Tests;

public sealed class OrderStatisticsExportApiTests(TTSmartApiFactory factory)
    : IClassFixture<TTSmartApiFactory>
{
    private const string ExportUri =
        "/api/order-statistics/export?branchId=10&" +
        "from=2026-08-03T00%3A00%3A00%2B07%3A00&to=2026-08-04T00%3A00%3A00%2B07%3A00";

    [Fact]
    public async Task ChuaDangNhap_ExportTra401()
    {
        await factory.ResetDatabaseAsync();
        using var client = factory.CreateClient();

        var response = await client.GetAsync(ExportUri);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        Assert.Equal(0, factory.OrderStatisticsDataSource.SearchCallCount);
        Assert.Equal(0, factory.OrderStatisticsDataSource.SearchAllCallCount);
    }

    [Fact]
    public async Task ChiCoQuyenDanhSach_ExportTra403()
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

        var response = await client.GetAsync(ExportUri);

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        Assert.Equal(0, factory.OrderStatisticsDataSource.SearchCallCount);
        Assert.Equal(0, factory.OrderStatisticsDataSource.SearchAllCallCount);
    }

    [Fact]
    public async Task DaDangNhap_ExportTraFileXlsxHopLe()
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
                ActiveKeyPermission.DSach,
                ActiveKeyPermission.Export);
            await SeedCompanyAndBranchAsync(services);
        });
        var material = new OrderStatisticsMaterialValue(
            100,
            1,
            "Cát 1",
            "Cát",
            10,
            0,
            10,
            0,
            OrderStatisticsMaterialCategories.Sand,
            1);
        var rows = Enumerable.Range(1, OrderStatisticsContractDefaults.PageSize + 1)
            .Select(index => CreateRow(material, index))
            .ToArray();
        var summary = new OrderStatisticsSummary(
            rows.Length,
            10,
            [material]);
        var columns = new[] { CreateColumn(material) };
        factory.OrderStatisticsDataSource.SetPages(
            new OrderStatisticsPage(
                rows.Take(OrderStatisticsContractDefaults.PageSize).ToArray(),
                1,
                OrderStatisticsContractDefaults.PageSize,
                rows.Length,
                summary,
                columns),
            new OrderStatisticsPage(
                rows.Skip(OrderStatisticsContractDefaults.PageSize).ToArray(),
                2,
                OrderStatisticsContractDefaults.PageSize,
                rows.Length,
                summary,
                columns));
        factory.OrderStatisticsDataSource.SetAllRowsPage(new OrderStatisticsPage(
            rows,
            1,
            rows.Length,
            rows.Length,
            summary,
            columns));
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var response = await client.GetAsync(ExportUri);

        response.EnsureSuccessStatusCode();
        Assert.Equal(
            OrderStatisticsExportDefaults.ContentType,
            response.Content.Headers.ContentType?.MediaType);
        var contentDisposition = response.Content.Headers.ContentDisposition;
        Assert.NotNull(contentDisposition);
        var fileName = contentDisposition.FileNameStar ?? contentDisposition.FileName;
        Assert.Equal(OrderStatisticsExportDefaults.FileName, fileName?.Trim('"'));

        var bytes = await response.Content.ReadAsByteArrayAsync();
        Assert.True(bytes.Length > 4);
        Assert.Equal((byte)'P', bytes[0]);
        Assert.Equal((byte)'K', bytes[1]);
        using var stream = new MemoryStream(bytes);
        using var archive = new ZipArchive(stream, ZipArchiveMode.Read);
        Assert.NotNull(archive.GetEntry("xl/workbook.xml"));
        Assert.Contains(archive.Entries, entry =>
            entry.FullName.StartsWith("xl/worksheets/sheet", StringComparison.Ordinal) &&
            entry.FullName.EndsWith(".xml", StringComparison.Ordinal));
        Assert.Equal(0, factory.OrderStatisticsDataSource.SearchCallCount);
        Assert.Equal(1, factory.OrderStatisticsDataSource.SearchAllCallCount);
        Assert.Empty(factory.OrderStatisticsDataSource.SeenPageNumbers);
        Assert.Single(factory.OrderStatisticsDataSource.SeenFilters);
        Assert.Equal(
            [OrderStatisticsViewMode.Detail],
            factory.OrderStatisticsDataSource.SeenViewModes);
    }

    private static OrderStatisticsRow CreateRow(
        OrderStatisticsMaterialValue material,
        int sequence) =>
        new(
            100 + sequence,
            200 + sequence,
            sequence,
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
            [material],
            "Nhân viên kinh doanh");

    private static OrderStatisticsMaterialColumn CreateColumn(
        OrderStatisticsMaterialValue material) =>
        new(
            material.MaterialSlotId,
            material.SlotNumber,
            material.MaterialName,
            material.Category,
            $"ĐM.{material.MaterialName}",
            $"T.{material.MaterialName}",
            material.MaterialName ?? "Vật liệu",
            $"SS.{material.MaterialName}",
            material.CategoryCode,
            material.TypePosition);

    private static async Task SeedCompanyAndBranchAsync(IServiceProvider services)
    {
        var companyDbContext = services.GetRequiredService<CompanyDbContext>();
        companyDbContext.Companies.Add(BranchTestSupport.CreateCompany(1, "CT_1", "Công ty 1"));
        companyDbContext.Branches.Add(BranchTestSupport.CreateBranch(10, 1, "TRAM_10", "Trạm 10"));
        await companyDbContext.SaveChangesAsync();
    }
}
