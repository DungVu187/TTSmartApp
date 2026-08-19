using TTSmart.Api.Features.MaterialReporting;

namespace TTSmart.Api.Tests;

public sealed class MaterialFifoCalculatorTests
{
    private static readonly DateTime From = new(2026, 8, 1);
    private static readonly DateTime To = new(2026, 8, 31, 23, 59, 59);
    private static readonly MaterialDefinition Sand = new(101, 1, 1, "Cát 1");

    [Fact]
    public void FifoBinhThuong_AnLoCuTruoc()
    {
        var result = Calculate(
            [Import("i1", 1, 100, 4_000), Import("i2", 2, 100, 5_000)],
            [Issue("e1", 3, 120)]);

        var material = Assert.Single(result.Materials);
        Assert.Equal(200m, material.ImportQuantityKg);
        Assert.Equal(120m, material.ExportQuantityKg);
        Assert.Equal(80m, material.InventoryQuantityKg);
        Assert.Equal(500_000m, material.ExportValueVnd);
        Assert.Equal(400_000m, material.InventoryValueVnd);
    }

    [Fact]
    public void XuatVuotTon_PhanVuotGiaBangKhongVaTonAmGiaBangKhong()
    {
        var result = Calculate(
            [Import("i1", 1, 100, 4_000)],
            [Issue("e1", 2, 120)]);

        var material = Assert.Single(result.Materials);
        Assert.Equal(-20m, material.InventoryQuantityKg);
        Assert.Equal(400_000m, material.ExportValueVnd);
        Assert.Equal(0m, material.InventoryValueVnd);
        Assert.Equal(400_000m, result.IssueValueBySourceId["e1"]);
    }

    [Fact]
    public void LoNhapSau_BuTonAmTruoc_ChiPhanConLaiCoGiaTriTon()
    {
        var result = Calculate(
            [Import("i1", 1, 100, 4_000), Import("i2", 3, 50, 5_000)],
            [Issue("e1", 2, 120)]);

        var material = Assert.Single(result.Materials);
        Assert.Equal(30m, material.InventoryQuantityKg);
        Assert.Equal(400_000m, material.ExportValueVnd);
        Assert.Equal(150_000m, material.InventoryValueVnd);
    }

    [Fact]
    public void LoNhapSauKhongHoiToGiaChoPhanXuatVuot()
    {
        var result = Calculate(
            [Import("i1", 1, 100, 4_000), Import("i2", 3, 20, 9_000)],
            [Issue("e1", 2, 120)]);

        var material = Assert.Single(result.Materials);
        Assert.Equal(0m, material.InventoryQuantityKg);
        Assert.Equal(400_000m, material.ExportValueVnd);
        Assert.Equal(0m, material.InventoryValueVnd);
        Assert.Equal(400_000m, result.IssueValueBySourceId["e1"]);
    }

    [Fact]
    public void TongHopGiaTriXuat_LuyKeTuDauLichSuDenMocTo()
    {
        var result = MaterialFifoCalculator.Calculate(
            new MaterialReportSnapshot(
                [Sand],
                [new MaterialImportLot("i1", 1, Sand.Code, Sand.Name, From.AddDays(-10), 100, 4_000)],
                [new MaterialIssueEvent("e1", 2, Sand.Code, Sand.SlotNumber, Sand.Name, From.AddDays(-5), 20)],
                [],
                []),
            From,
            To);

        Assert.Equal(80_000m, Assert.Single(result.Materials).ExportValueVnd);
    }

    [Fact]
    public void DieuChinhAm_ChiSuaKhoiLuongKhongTaoLoHoacDaoGiaTriFifo()
    {
        var result = Calculate(
            [
                Import("i1", 1, 100, 4_000),
                Import("i-adjust", 2, -20, 9_000) with
                {
                    IsQuantityOnlyAdjustment = true
                }
            ],
            [
                Issue("e1", 3, 50),
                Issue("e-adjust", 4, -10) with
                {
                    IsQuantityOnlyAdjustment = true
                }
            ]);

        var material = Assert.Single(result.Materials);
        Assert.Equal(80m, material.ImportQuantityKg);
        Assert.Equal(40m, material.ExportQuantityKg);
        Assert.Equal(40m, material.InventoryQuantityKg);
        Assert.Equal(400_000m, material.ImportValueVnd);
        Assert.Equal(200_000m, material.ExportValueVnd);
        Assert.Equal(200_000m, material.InventoryValueVnd);
        Assert.DoesNotContain("e-adjust", result.IssueValueBySourceId.Keys);
    }

    [Fact]
    public void SoLuongAmKhongDanhDauDieuChinh_KhongAnhHuongTongKho()
    {
        var result = Calculate(
            [Import("i1", 1, 100, 4_000), Import("legacy-negative", 2, -20, 4_000)],
            [Issue("e1", 3, 50), Issue("legacy-negative-issue", 4, -10)]);

        var material = Assert.Single(result.Materials);
        Assert.Equal(100m, material.ImportQuantityKg);
        Assert.Equal(50m, material.ExportQuantityKg);
        Assert.Equal(50m, material.InventoryQuantityKg);
    }

    private static MaterialFifoCalculation Calculate(
        IReadOnlyList<MaterialImportLot> imports,
        IReadOnlyList<MaterialIssueEvent> issues) =>
        MaterialFifoCalculator.Calculate(
            new MaterialReportSnapshot([Sand], imports, issues, [], []),
            From,
            To);

    private static MaterialImportLot Import(
        string id,
        int day,
        decimal quantity,
        decimal price) =>
        new(id, day, Sand.Code, Sand.Name, From.AddDays(day), quantity, price);

    private static MaterialIssueEvent Issue(string id, int day, decimal quantity) =>
        new(id, day, Sand.Code, Sand.SlotNumber, Sand.Name, From.AddDays(day), quantity);
}
