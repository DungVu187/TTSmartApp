using System.ComponentModel.DataAnnotations;

namespace TTSmart.Api.Features.OrderStatistics;

public static class OrderStatisticsViewModes
{
    public const string Detail = "detail";
    public const string Total = "total";
}

public static class OrderStatisticsContractDefaults
{
    public const int DefaultPageNumber = 1;
    public const int PageSize = 10;
}

public sealed class OrderStatisticsStationQuery
{
    [Range(1, int.MaxValue)]
    public int? CompanyId { get; init; }
}

public sealed record OrderStatisticsStationResponse(
    int Id,
    int? CompanyId,
    string? Name,
    int? TypeTram,
    string? CompanyName);

public sealed class OrderStatisticsFilterOptionsQuery
{
    [Range(1, int.MaxValue)]
    public int? CompanyId { get; init; }

    [Range(1, int.MaxValue)]
    public int? BranchId { get; init; }

    [Required]
    public DateTimeOffset? From { get; init; }

    [Required]
    public DateTimeOffset? To { get; init; }
}

public sealed record OrderStatisticsFilterOptionsResponse(
    IReadOnlyList<string> VehiclePlates,
    IReadOnlyList<string> CustomerNames,
    IReadOnlyList<string> ConcreteGradeNames,
    IReadOnlyList<string> EmployeeNames);

public sealed class OrderStatisticsQuery
{
    [Range(1, int.MaxValue)]
    public int? CompanyId { get; init; }

    [Range(1, int.MaxValue)]
    public int? BranchId { get; init; }

    [Required]
    public DateTimeOffset? From { get; init; }

    [Required]
    public DateTimeOffset? To { get; init; }

    [RegularExpression("^(detail|total)$")]
    public string ViewMode { get; init; } = OrderStatisticsViewModes.Detail;

    public string? VehiclePlate { get; init; }
    public string? CustomerName { get; init; }
    public string? ConcreteGradeName { get; init; }
    public string? EmployeeName { get; init; }

    [Range(1, int.MaxValue)]
    public int PageNumber { get; init; } = OrderStatisticsContractDefaults.DefaultPageNumber;

    [Range(OrderStatisticsContractDefaults.PageSize, OrderStatisticsContractDefaults.PageSize)]
    public int PageSize { get; init; } = OrderStatisticsContractDefaults.PageSize;
}

public sealed record OrderStatisticsItemResponse(
    int RowNumber,
    int StationId,
    string? StationName,
    DateOnly? MixingDate,
    DateTimeOffset? StartedAt,
    DateTimeOffset? FinishedAt,
    string? CustomerName,
    string? ProjectName,
    string? WorkItemName,
    string? LocationName,
    string? VehiclePlate,
    string? DriverName,
    string? ConcreteGradeName,
    string? Slump,
    string? SalesEmployeeName,
    string? EmployeeName,
    decimal RequestedVolume,
    decimal MixedVolume,
    IReadOnlyList<OrderStatisticsMaterialResponse> Materials)
{
    public string LayoutKey { get; init; } = string.Empty;
}

public sealed record OrderStatisticsMaterialResponse(
    long? MaterialSlotId,
    int SlotNumber,
    string? MaterialName,
    string? Category,
    decimal DesignQuantity,
    decimal TQuantity,
    decimal ActualQuantity,
    decimal Variance)
{
    public string CategoryCode { get; init; } = string.Empty;

    public int TypePosition { get; init; }

    public string ColumnKey { get; init; } = string.Empty;
}

public sealed record OrderStatisticsMaterialColumnResponse(
    long? MaterialSlotId,
    int SlotNumber,
    string? MaterialName,
    string? Category,
    string DesignLabel,
    string TLabel,
    string ActualLabel,
    string VarianceLabel,
    string? Unit)
{
    public string CategoryCode { get; init; } = string.Empty;

    public int TypePosition { get; init; }

    public string ColumnKey { get; init; } = string.Empty;
}

public sealed record OrderStatisticsMaterialLayoutResponse(
    string LayoutKey,
    IReadOnlyList<OrderStatisticsMaterialColumnResponse> Columns);

public sealed record OrderStatisticsMaterialSummaryCellResponse(
    string CategoryCode,
    int TypePosition,
    long? MaterialSlotId,
    int? SlotNumber,
    string? MaterialName,
    string? Category,
    string? ColumnKey,
    decimal ActualQuantity,
    string Unit);

public sealed record OrderStatisticsMaterialSummaryRowResponse(
    int RowNumber,
    IReadOnlyList<OrderStatisticsMaterialSummaryCellResponse> Cells);

public sealed record OrderStatisticsResponse(
    IReadOnlyList<OrderStatisticsItemResponse> Items,
    int TotalCount,
    int TotalPages,
    int PageNumber,
    int PageSize,
    int FromRowNumber,
    int ToRowNumber,
    decimal TotalMaterialQuantity,
    decimal TotalConcreteVolume,
    IReadOnlyList<OrderStatisticsMaterialLayoutResponse> Layouts,
    IReadOnlyList<OrderStatisticsMaterialSummaryRowResponse> MaterialSummaryRows);
