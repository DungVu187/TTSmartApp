using System.IO.Compression;
using System.Net;
using Microsoft.Extensions.DependencyInjection;
using TTSmart.Api.Data.Company;
using TTSmart.Api.Features.Authorization;
using TTSmart.Api.Features.WeighStationManagement;

namespace TTSmart.Api.Tests;

public sealed class WeighStationExportApiTests(TTSmartApiFactory factory)
    : IClassFixture<TTSmartApiFactory>
{
    private const string Query =
        "branchId=10&stage=Second&" +
        "from=2026-08-05T00:00:00%2B07:00&to=2026-08-06T00:00:00%2B07:00";

    [Theory]
    [InlineData("/api/weigh-station-management/export?")]
    [InlineData("/api/weigh-station-management/summary/export?")]
    public async Task ChiCoQuyenDanhSach_ExportTra403(string route)
    {
        var identity = await ResetAndSeedIdentityAsync(ActiveKeyPermission.DSach);
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var response = await client.GetAsync(route + Query);

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        Assert.Equal(0, factory.WeighStationDataSource.SearchAllCallCount);
        Assert.Equal(0, factory.WeighStationDataSource.SummaryCallCount);
    }

    [Fact]
    public async Task CoQuyenExport_TraHaiFileXlsxHopLeVaTaiToanBoDuLieu()
    {
        var identity = await ResetAndSeedIdentityAsync(
            ActiveKeyPermission.DSach,
            ActiveKeyPermission.Export,
            ActiveKeyPermission.Other);
        var validRow = CreateRow();
        factory.WeighStationDataSource.SetAllRows(
        [
            validRow,
            validRow with
            {
                TicketNumber = 153805,
                Id = Guid.NewGuid(),
                GoodsWeight = 280010,
                ConversionFactor = 0,
                ConversionUnit = null,
                GoodsName = "Không xác định"
            }
        ]);
        factory.WeighStationDataSource.SetSummary(
        [
            new("Cát vàng", "Nhập hàng", 1000, 2, "M3"),
            new("Bê tông thương phẩm", "Bán hàng", 400, 1, "KG"),
            new("Không xác định", "Nhập hàng", 280010, 0, null)
        ]);
        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, identity);

        var detail = await client.GetAsync("/api/weigh-station-management/export?" + Query);
        var summary = await client.GetAsync("/api/weigh-station-management/summary/export?" + Query);

        await AssertWorkbookAsync(
            detail,
            WeighStationExportDefaults.DetailFileName,
            "Số phiếu",
            "153804",
            WeighStationConversionMessages.Undefined,
            "Giá trị (VNĐ)");
        await AssertWorkbookAsync(
            summary,
            WeighStationExportDefaults.SummaryFileName,
            "Tổng số loại hàng",
            "Tổng khối lượng (kg)",
            "Tổng khối lượng quy đổi",
            WeighStationConversionMessages.Undefined,
            "0.4 tấn");
        Assert.Equal(2, factory.WeighStationDataSource.SearchAllCallCount);
        Assert.Equal(1, factory.WeighStationDataSource.SummaryCallCount);
        Assert.Equal(0, factory.WeighStationDataSource.SearchCallCount);
    }

    private async Task<BranchTestIdentity> ResetAndSeedIdentityAsync(
        params ActiveKeyPermission[] permissions)
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
                permissions);
            var companyDbContext = services.GetRequiredService<CompanyDbContext>();
            companyDbContext.Companies.Add(
                BranchTestSupport.CreateCompany(1, "CT_1", "Công ty 1"));
            companyDbContext.Branches.Add(
                BranchTestSupport.CreateBranch(10, 1, "CAN_10", "Trạm cân 10", typeTram: 2));
            await companyDbContext.SaveChangesAsync();
        });
        return identity;
    }

    private static WeighStationRow CreateRow() =>
        new(
            153804,
            Guid.NewGuid(),
            "260805-0008",
            "89 C 11415",
            "Lợi",
            "202625136784",
            40740,
            15770,
            24970,
            2,
            "M3",
            "Cty Thành Phát",
            "Bê tông thương phẩm",
            "Bán hàng",
            "vanhanh",
            "vanhanh",
            new DateTime(2026, 8, 5, 11, 2, 40),
            new DateTime(2026, 8, 5, 11, 4, 8),
            new DateTime(2026, 8, 5, 12, 50, 16));

    private static async Task AssertWorkbookAsync(
        HttpResponseMessage response,
        string expectedFileName,
        params string[] expectedTexts)
    {
        response.EnsureSuccessStatusCode();
        Assert.Equal(
            WeighStationExportDefaults.ContentType,
            response.Content.Headers.ContentType?.MediaType);
        var contentDisposition = response.Content.Headers.ContentDisposition;
        Assert.NotNull(contentDisposition);
        var fileName = contentDisposition.FileNameStar ?? contentDisposition.FileName;
        Assert.Equal(expectedFileName, fileName?.Trim('"'));

        var bytes = await response.Content.ReadAsByteArrayAsync();
        Assert.True(bytes.Length > 4);
        Assert.Equal((byte)'P', bytes[0]);
        Assert.Equal((byte)'K', bytes[1]);
        using var stream = new MemoryStream(bytes);
        using var archive = new ZipArchive(stream, ZipArchiveMode.Read);
        Assert.NotNull(archive.GetEntry("xl/workbook.xml"));
        var sheet = archive.GetEntry("xl/worksheets/sheet1.xml");
        Assert.NotNull(sheet);
        using var reader = new StreamReader(sheet.Open());
        var xml = await reader.ReadToEndAsync();
        foreach (var expectedText in expectedTexts)
        {
            Assert.Contains(expectedText, xml, StringComparison.Ordinal);
        }
    }
}
