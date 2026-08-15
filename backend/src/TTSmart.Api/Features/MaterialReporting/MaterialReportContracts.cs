using System.ComponentModel.DataAnnotations;

namespace TTSmart.Api.Features.MaterialReporting;

public static class MaterialReportViewModes
{
    public const string All = "all";
    public const string Import = "import";
    public const string Export = "export";
    public const string Inventory = "inventory";
    public const string Stocktake = "stocktake";
}

public static class MaterialReportValueModes
{
    public const string Quantity = "quantity";
    public const string Value = "value";
}

public static class MaterialReportGroups
{
    public const string All = "all";
    public const string Sand = "sand";
    public const string Stone = "stone";
    public const string Cement = "cement";
    public const string Water = "water";
    public const string Additive = "additive";
    public const string Unknown = "unknown";
}

public static class MaterialReportContractDefaults
{
    public const int PageSize = 10;
}

public sealed class MaterialReportStationQuery
{
    [Range(1, int.MaxValue)]
    public int? CompanyId { get; init; }
}

public sealed record MaterialReportStationResponse(
    int Id,
    int? CompanyId,
    string? Name,
    string? CompanyName,
    int? TypeTram);

public sealed class MaterialReportQuery
{
    [Range(1, int.MaxValue)]
    public int? CompanyId { get; init; }

    [Range(1, int.MaxValue)]
    public int? BranchId { get; init; }

    [Required]
    public DateTimeOffset? From { get; init; }

    [Required]
    public DateTimeOffset? To { get; init; }

    [RegularExpression("^(all|sand|stone|cement|water|additive)$")]
    public string MaterialGroup { get; init; } = MaterialReportGroups.All;

    [RegularExpression("^(all|import|export|inventory|stocktake)$")]
    public string ViewMode { get; init; } = MaterialReportViewModes.All;

    [RegularExpression("^(quantity|value)$")]
    public string ValueMode { get; init; } = MaterialReportValueModes.Quantity;

    [Range(1, int.MaxValue)]
    public int PageNumber { get; init; } = 1;

    [Range(MaterialReportContractDefaults.PageSize, MaterialReportContractDefaults.PageSize)]
    public int PageSize { get; init; } = MaterialReportContractDefaults.PageSize;
}

public sealed record MaterialReportResponse(
    int StationId,
    string? StationName,
    DateTimeOffset From,
    DateTimeOffset To,
    DateTimeOffset InventoryAsOf,
    string MaterialGroup,
    string ViewMode,
    string ValueMode,
    IReadOnlyList<MaterialGroupSummaryResponse> Groups,
    IReadOnlyList<MaterialChartItemResponse> ChartItems,
    IReadOnlyList<MaterialTransactionResponse> Transactions,
    int TotalCount,
    int TotalPages,
    int PageNumber,
    int PageSize,
    int FromRowNumber,
    int ToRowNumber,
    MaterialReportTotalsResponse Totals,
    IReadOnlyList<string> Warnings);

public sealed record MaterialGroupSummaryResponse(
    string Code,
    string Name,
    IReadOnlyList<MaterialSummaryItemResponse> Materials);

public sealed record MaterialSummaryItemResponse(
    int MaterialCode,
    int SlotNumber,
    int MaterialTypeId,
    string Name,
    string GroupCode,
    decimal ImportQuantityKg,
    decimal ExportQuantityKg,
    decimal InventoryQuantityKg,
    decimal ImportValueVnd,
    decimal ExportValueVnd,
    decimal InventoryValueVnd,
    decimal? KilogramsPerCubicMeter,
    decimal? KilogramsPerLiter,
    bool HasMissingImportPrice);

public sealed record MaterialChartItemResponse(
    int MaterialCode,
    string Name,
    string GroupCode,
    decimal ImportQuantityKg,
    decimal ExportQuantityKg,
    decimal InventoryQuantityKg,
    decimal ImportValueVnd,
    decimal ExportValueVnd,
    decimal InventoryValueVnd);

public sealed record MaterialTransactionResponse(
    int RowNumber,
    string Id,
    DateTimeOffset? OccurredAt,
    DateTimeOffset? PeriodFrom,
    DateTimeOffset? PeriodTo,
    string Type,
    string Content,
    decimal ImportQuantityKg,
    decimal ExportQuantityKg,
    decimal? ValueVnd,
    string? Note,
    IReadOnlyList<MaterialTransactionDetailResponse> Details);

public sealed record MaterialTransactionDetailResponse(
    int MaterialCode,
    string Name,
    decimal QuantityKg,
    decimal? ValueVnd,
    decimal? UnitPriceVndPerKg,
    decimal? ConversionVolume,
    string? ConversionUnit,
    decimal? ConversionCoefficientKgPerUnit);

public sealed record MaterialReportTotalsResponse(
    decimal ImportQuantityKg,
    decimal ExportQuantityKg,
    decimal InventoryQuantityKg,
    decimal ImportValueVnd,
    decimal ExportValueVnd,
    decimal InventoryValueVnd);
