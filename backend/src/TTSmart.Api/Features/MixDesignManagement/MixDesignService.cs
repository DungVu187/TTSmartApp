using System.ComponentModel.DataAnnotations;
using TTSmart.Api.Common.Exceptions;
using TTSmart.Api.Data.StationOperations;
using TTSmart.Api.Features.BranchManagement;

namespace TTSmart.Api.Features.MixDesignManagement;

public sealed class MixDesignService(
    IBranchAccessResolver branchAccessResolver,
    IMixDesignDataSource dataSource) : IMixDesignService
{
    private const string StationUnavailableMessage = "Dữ liệu trạm chưa sẵn sàng";

    public async Task<IReadOnlyList<MixDesignStationResponse>> GetStationsAsync(
        MixDesignStationQuery query,
        int currentUserId,
        CancellationToken cancellationToken)
    {
        var branches = await branchAccessResolver.GetMixDesignBranchesAsync(
            currentUserId,
            query.CompanyId,
            cancellationToken);
        return branches
            .Select(branch => new MixDesignStationResponse(branch.Id, branch.Name))
            .ToArray();
    }

    public async Task<MixDesignResponse> GetAsync(
        MixDesignQuery query,
        int currentUserId,
        CancellationToken cancellationToken)
    {
        var branch = await branchAccessResolver.GetRequiredMixDesignBranchAsync(
            currentUserId,
            query.CompanyId,
            query.StationId,
            cancellationToken);
        ValidatePageNumber(query.PageNumber);

        var page = await dataSource.GetPageAsync(
            CreateTarget(branch),
            query.PageNumber,
            cancellationToken);
        var materialColumns = NormalizeMaterialColumns(page.MaterialColumns);
        var pageOffset = CalculatePageOffset(page.PageNumber);
        var items = page.Items
            .Select((row, index) => MapItem(
                row,
                checked(pageOffset + index + 1),
                materialColumns))
            .ToArray();
        var totalPages = page.TotalCount == 0
            ? 0
            : (int)((page.TotalCount + (long)page.PageSize - 1) / page.PageSize);

        return new MixDesignResponse(
            items,
            page.PageNumber,
            page.PageSize,
            page.TotalCount,
            totalPages)
        {
            MaterialColumns = materialColumns
                .Select(MapMaterialColumn)
                .ToArray()
        };
    }

    private static MixDesignItemResponse MapItem(
        MixDesignRow row,
        int stt,
        IReadOnlyList<NormalizedMaterialColumn> materialColumns)
    {
        var quantitiesByMaterialSlotId = row.Materials
            .GroupBy(material => material.MaterialSlotId)
            .ToDictionary(
                group => group.Key,
                group => NormalizeQuantity(group.Sum(material => material.Quantity ?? 0d)));
        var configuredMaterialSlotIds = materialColumns
            .Select(column => column.MaterialSlotId)
            .ToHashSet();
        if (quantitiesByMaterialSlotId.Keys.Any(
            materialSlotId => !configuredMaterialSlotIds.Contains(materialSlotId)))
        {
            throw new ServiceUnavailableException(StationUnavailableMessage);
        }

        var materials = materialColumns
            .Select(column => new MixDesignMaterialResponse(
                column.MaterialSlotId,
                column.SlotNumber,
                column.ColumnKey,
                quantitiesByMaterialSlotId.GetValueOrDefault(column.MaterialSlotId)))
            .ToArray();
        var quantitiesByCategoryPosition = materialColumns
            .ToDictionary(
                column => (column.CategoryCode, column.TypePosition),
                column => quantitiesByMaterialSlotId.GetValueOrDefault(column.MaterialSlotId));
        decimal GetQuantity(string categoryCode, int typePosition) =>
            quantitiesByCategoryPosition.GetValueOrDefault((categoryCode, typePosition));

        return new MixDesignItemResponse(
            stt,
            row.ConcreteGradeName,
            row.Strength ?? 0,
            row.MaxAggregate ?? 0,
            row.Slump ?? "0",
            GetQuantity(MixDesignMaterialCategories.Sand, 1),
            GetQuantity(MixDesignMaterialCategories.Sand, 2),
            GetQuantity(MixDesignMaterialCategories.Stone, 1),
            GetQuantity(MixDesignMaterialCategories.Stone, 2),
            GetQuantity(MixDesignMaterialCategories.Stone, 3),
            GetQuantity(MixDesignMaterialCategories.Cement, 1),
            GetQuantity(MixDesignMaterialCategories.Cement, 2),
            GetQuantity(MixDesignMaterialCategories.Cement, 3),
            GetQuantity(MixDesignMaterialCategories.Cement, 4),
            GetQuantity(MixDesignMaterialCategories.Water, 1),
            GetQuantity(MixDesignMaterialCategories.Additive, 1),
            GetQuantity(MixDesignMaterialCategories.Additive, 2),
            GetQuantity(MixDesignMaterialCategories.Additive, 3),
            GetQuantity(MixDesignMaterialCategories.Additive, 4))
        {
            Materials = materials
        };
    }

    private static IReadOnlyList<NormalizedMaterialColumn> NormalizeMaterialColumns(
        IReadOnlyList<MixDesignMaterialColumn> materialColumns)
    {
        var duplicateSlotNumbers = materialColumns
            .GroupBy(column => column.SlotNumber)
            .Where(group => group.Count() > 1)
            .Select(group => group.Key)
            .OrderBy(slotNumber => slotNumber)
            .ToArray();
        if (duplicateSlotNumbers.Length > 0)
        {
            throw new ServiceUnavailableException(StationUnavailableMessage);
        }

        return materialColumns
            .Select(column => new
            {
                Column = column,
                CategoryCode = MixDesignMaterialCategories.Normalize(
                    column.MaterialTypeId,
                    column.MaterialTypeName)
            })
            .GroupBy(item => item.CategoryCode)
            .SelectMany(group => group
                .OrderBy(item => item.Column.SlotNumber)
                .ThenBy(item => item.Column.MaterialSlotId)
                .Select((item, index) => new NormalizedMaterialColumn(
                    item.Column.MaterialSlotId,
                    item.Column.SlotNumber,
                    NormalizeMaterialName(
                        item.Column.MaterialName,
                        item.Column.SlotNumber),
                    MixDesignMaterialCategories.DisplayName(item.CategoryCode),
                    item.CategoryCode,
                    index + 1,
                    $"slot-{item.Column.SlotNumber}")))
            .OrderBy(column => column.SlotNumber)
            .ThenBy(column => column.MaterialSlotId)
            .ToArray();
    }

    private static MixDesignMaterialColumnResponse MapMaterialColumn(
        NormalizedMaterialColumn column) =>
        new(
            column.MaterialSlotId,
            column.SlotNumber,
            column.MaterialName,
            column.Category,
            column.CategoryCode,
            column.TypePosition,
            column.ColumnKey);

    private static string NormalizeMaterialName(string? materialName, int slotNumber)
    {
        var normalized = materialName?.Trim();
        return string.IsNullOrEmpty(normalized)
            ? $"\u0056\u1eadt li\u1ec7u {slotNumber}"
            : normalized;
    }

    private static decimal NormalizeQuantity(double? value)
    {
        if (!value.HasValue || !double.IsFinite(value.Value))
        {
            return 0m;
        }

        try
        {
            return Math.Round(
                (decimal)value.Value,
                2,
                MidpointRounding.AwayFromZero);
        }
        catch (OverflowException)
        {
            return 0m;
        }
    }

    private static void ValidatePageNumber(int pageNumber)
    {
        if (pageNumber < 1)
        {
            throw new ValidationException("Số trang không hợp lệ");
        }

        _ = CalculatePageOffset(pageNumber);
    }

    private static int CalculatePageOffset(int pageNumber)
    {
        try
        {
            return checked((pageNumber - 1) * MixDesignContractDefaults.PageSize);
        }
        catch (OverflowException exception)
        {
            throw new ValidationException("Số trang không hợp lệ", exception);
        }
    }

    private static StationDatabaseTarget CreateTarget(AuthorizedBranch branch) =>
        new(branch.Id, branch.DatabaseName, branch.TypeTram);

    private sealed record NormalizedMaterialColumn(
        int MaterialSlotId,
        int SlotNumber,
        string MaterialName,
        string Category,
        string CategoryCode,
        int TypePosition,
        string ColumnKey);
}
