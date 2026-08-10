using TTSmart.Api.Features.OrderStatistics;

namespace TTSmart.Api.Tests;

public sealed class OrderStatisticsHistoricalMaterialNormalizationTests
{
    [Fact]
    public void CandidateSlotIds_DungKhoaChinhTheoSnapshotVaSoCuaLonNhat()
    {
        var materialRows = new[]
        {
            CreateMaterialRow(101, 201, 1001, 1, 1, 1, 1),
            CreateMaterialRow(101, 201, 1003, 3, 1, 1, 1),
            CreateMaterialRow(102, 202, 2002, 2, 1, 1, 1)
        };

        var result = SqlOrderStatisticsDataSource.BuildHistoricalMaterialSlotIdCandidates(
            materialRows,
            maximumSlotNumber: 4);

        Assert.Equal(
            [1001L, 1002L, 1003L, 1004L, 2001L, 2002L, 2003L, 2004L],
            result);
    }

    [Fact]
    public void SnapshotCoCuaKhongCoDinhLuong_VanTraDuLayoutVaGiaTriKhong()
    {
        const long snapshotKey = 1000;
        var materialRows = new[]
        {
            CreateMaterialRow(101, 201, 1001, 1, 10, 11, 12),
            CreateMaterialRow(101, 201, 1001, 1, 5, 6, 7),
            CreateMaterialRow(101, 201, 1003, 3, 30, 31, 32)
        };
        IReadOnlyDictionary<long, IReadOnlyList<SqlOrderStatisticsDataSource.HistoricalMaterialLayoutEntry>>
            layouts = new Dictionary<long, IReadOnlyList<SqlOrderStatisticsDataSource.HistoricalMaterialLayoutEntry>>
            {
                [snapshotKey] =
                [
                    CreateLayout(snapshotKey, 1001, 1, "\u0043\u00e1t 3", "CAT", 1),
                    CreateLayout(snapshotKey, 1003, 3, "\u0043\u00e1t 1", "CAT", 2),
                    CreateLayout(snapshotKey, 1002, 2, "\u0110\u00e1 1", "DA", 1)
                ]
            };

        var result = SqlOrderStatisticsDataSource.NormalizeHistoricalMaterials(
            materialRows,
            layouts,
            expectedBatchCount: 1);

        Assert.Equal([1001L, 1003L, 1002L], result.Select(item => item.MaterialSlotId));
        var firstSand = Assert.Single(result, item => item.MaterialSlotId == 1001);
        Assert.Equal(15d, firstSand.DesignQuantity);
        Assert.Equal(17d, firstSand.TQuantity);
        Assert.Equal(19d, firstSand.ActualQuantity);
        var missingStone = Assert.Single(result, item => item.MaterialSlotId == 1002);
        Assert.Equal(2, missingStone.SlotNumber);
        Assert.Equal("\u0110\u00e1 1", missingStone.MaterialName);
        Assert.Equal("DA", missingStone.CategoryCode);
        Assert.Equal(1, missingStone.TypePosition);
        Assert.Equal(0d, missingStone.DesignQuantity);
        Assert.Equal(0d, missingStone.TQuantity);
        Assert.Equal(0d, missingStone.ActualQuantity);
    }

    [Fact]
    public void MotMeTronThamChieuNhieuSnapshot_ThatBaiThayViDoanLayout()
    {
        var materialRows = new[]
        {
            CreateMaterialRow(101, 201, 1001, 1, 1, 1, 1),
            CreateMaterialRow(101, 201, 2002, 2, 1, 1, 1)
        };

        var exception = Assert.Throws<InvalidOperationException>(() =>
            SqlOrderStatisticsDataSource.NormalizeHistoricalMaterials(
                materialRows,
                new Dictionary<long, IReadOnlyList<SqlOrderStatisticsDataSource.HistoricalMaterialLayoutEntry>>(),
                expectedBatchCount: 1));

        Assert.Contains("Multiple historical material snapshots", exception.Message);
        Assert.Contains("1000", exception.Message);
        Assert.Contains("2000", exception.Message);
    }

    [Fact]
    public void SnapshotKhongTonTai_ThatBaiThayViDungLayoutHienHanh()
    {
        var materialRows = new[]
        {
            CreateMaterialRow(101, 201, 1001, 1, 1, 1, 1)
        };

        var exception = Assert.Throws<InvalidOperationException>(() =>
            SqlOrderStatisticsDataSource.NormalizeHistoricalMaterials(
                materialRows,
                new Dictionary<long, IReadOnlyList<SqlOrderStatisticsDataSource.HistoricalMaterialLayoutEntry>>(),
                expectedBatchCount: 1));

        Assert.Contains("snapshot 1000 was not found", exception.Message);
    }

    [Fact]
    public void MeTronKhongCoDongVatLieu_ThatBaiThayViTraLayoutHienHanh()
    {
        var exception = Assert.Throws<InvalidOperationException>(() =>
            SqlOrderStatisticsDataSource.NormalizeHistoricalMaterials(
                [],
                new Dictionary<long, IReadOnlyList<SqlOrderStatisticsDataSource.HistoricalMaterialLayoutEntry>>(),
                expectedBatchCount: 1));

        Assert.Contains("Expected 1 batches but found 0", exception.Message);
    }

    private static SqlOrderStatisticsDataSource.MaterialAggregateQueryRow CreateMaterialRow(
        long mixingDetailId,
        long mixingHistoryId,
        long materialSlotId,
        int slotNumber,
        double designQuantity,
        double tQuantity,
        double actualQuantity) =>
        new()
        {
            MixingDetailId = mixingDetailId,
            MixingHistoryId = mixingHistoryId,
            MaterialSlotId = materialSlotId,
            SlotNumber = slotNumber,
            DesignQuantity = designQuantity,
            TQuantity = tQuantity,
            ActualQuantity = actualQuantity
        };

    private static SqlOrderStatisticsDataSource.HistoricalMaterialLayoutEntry CreateLayout(
        long snapshotKey,
        long materialSlotId,
        int slotNumber,
        string materialName,
        string categoryCode,
        int typePosition) =>
        new(
            snapshotKey,
            materialSlotId,
            slotNumber,
            materialName,
            categoryCode,
            typePosition);
}
