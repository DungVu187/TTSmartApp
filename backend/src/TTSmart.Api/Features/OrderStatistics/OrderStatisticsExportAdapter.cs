namespace TTSmart.Api.Features.OrderStatistics;

internal sealed record OrderStatisticsExportDataset(
    IReadOnlyList<OrderStatisticsExportLayout> Layouts,
    OrderStatisticsExportSummaryTable MaterialSummary,
    decimal TotalMaterialQuantity,
    decimal TotalConcreteVolume);

internal sealed record OrderStatisticsExportLayout(
    string LayoutKey,
    IReadOnlyList<OrderStatisticsExportMaterialColumn> MaterialColumns,
    IReadOnlyList<OrderStatisticsItemResponse> Items);

internal sealed record OrderStatisticsExportMaterialColumn(
    int SlotNumber,
    string? MaterialName,
    string? Category,
    string DesignLabel,
    string TLabel,
    string ActualLabel,
    string VarianceLabel);

internal sealed record OrderStatisticsExportSummaryTable(
    IReadOnlyList<string> Headers,
    IReadOnlyList<IReadOnlyList<OrderStatisticsExportValue>> Rows);

internal readonly record struct OrderStatisticsExportValue(string? Text, decimal? Number)
{
    public static OrderStatisticsExportValue FromText(string? value) =>
        new(value, null);

    public static OrderStatisticsExportValue FromNumber(decimal value) =>
        new(null, value);
}

internal static class OrderStatisticsExportAdapter
{
    public static OrderStatisticsExportDataset Create(OrderStatisticsResponse response)
    {
        var layoutsByKey = response.Layouts.ToDictionary(
            layout => layout.LayoutKey,
            layout => new LayoutBuilder(
                layout.LayoutKey,
                MapColumns(layout.Columns)),
            StringComparer.Ordinal);
        var fallbackLayoutKey = response.Layouts.Count == 1
            ? response.Layouts[0].LayoutKey
            : string.Empty;

        foreach (var item in response.Items)
        {
            var layoutKey = string.IsNullOrWhiteSpace(item.LayoutKey)
                ? fallbackLayoutKey
                : item.LayoutKey;
            if (!layoutsByKey.TryGetValue(layoutKey, out var layout))
            {
                layout = new LayoutBuilder(layoutKey, []);
                layoutsByKey.Add(layoutKey, layout);
            }

            layout.Items.Add(item);
        }

        return new OrderStatisticsExportDataset(
            layoutsByKey.Values
                .Select(layout => new OrderStatisticsExportLayout(
                    layout.LayoutKey,
                    layout.Columns,
                    layout.Items))
                .ToArray(),
            BuildMaterialSummary(response.MaterialSummaryRows),
            response.TotalMaterialQuantity,
            response.TotalConcreteVolume);
    }

    private static IReadOnlyList<OrderStatisticsExportMaterialColumn> MapColumns(
        IReadOnlyList<OrderStatisticsMaterialColumnResponse> columns) =>
        columns
            .Select(column => new OrderStatisticsExportMaterialColumn(
                column.SlotNumber,
                column.MaterialName,
                column.Category,
                column.DesignLabel,
                column.TLabel,
                column.ActualLabel,
                column.VarianceLabel))
            .ToArray();

    private static OrderStatisticsExportSummaryTable BuildMaterialSummary(
        IReadOnlyList<OrderStatisticsMaterialSummaryRowResponse> sourceRows)
    {
        var categoryCodes = OrderStatisticsMaterialCategories.StandardCodes
            .Concat(sourceRows
                .SelectMany(row => row.Cells)
                .Select(cell => cell.CategoryCode)
                .Where(categoryCode =>
                    !OrderStatisticsMaterialCategories.StandardCodes.Contains(categoryCode)))
            .Distinct(StringComparer.Ordinal)
            .OrderBy(OrderStatisticsMaterialCategories.SortOrder)
            .ToArray();
        var rows = sourceRows
            .OrderBy(row => row.RowNumber)
            .Select(row =>
            {
                var actualByCategory = row.Cells
                    .GroupBy(cell => cell.CategoryCode, StringComparer.Ordinal)
                    .ToDictionary(
                        group => group.Key,
                        group => group.Sum(cell => cell.ActualQuantity),
                        StringComparer.Ordinal);
                return (IReadOnlyList<OrderStatisticsExportValue>)
                [
                    OrderStatisticsExportValue.FromNumber(row.RowNumber),
                    .. categoryCodes.Select(categoryCode =>
                        OrderStatisticsExportValue.FromNumber(
                            actualByCategory.GetValueOrDefault(categoryCode)))
                ];
            })
            .ToArray();

        return new OrderStatisticsExportSummaryTable(
            [
                "STT",
                .. categoryCodes.Select(OrderStatisticsMaterialCategories.DisplayName)
            ],
            rows);
    }

    private sealed class LayoutBuilder(
        string layoutKey,
        IReadOnlyList<OrderStatisticsExportMaterialColumn> columns)
    {
        public string LayoutKey { get; } = layoutKey;
        public IReadOnlyList<OrderStatisticsExportMaterialColumn> Columns { get; } = columns;
        public List<OrderStatisticsItemResponse> Items { get; } = [];
    }
}
