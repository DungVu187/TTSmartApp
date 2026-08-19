using System.ComponentModel.DataAnnotations;

namespace TTSmart.Api.Features.WeighStationManagement;

public static class WeighStationContractDefaults
{
    public const int PageSize = 10;
}

public static class WeighStationConversionMessages
{
    public const string Undefined = "Chưa xác định";
}

public enum WeighStationStage
{
    First = 1,
    Second = 2
}

public sealed class WeighStationStationQuery
{
    [Range(1, int.MaxValue)]
    public int? CompanyId { get; init; }
}

public sealed class WeighStationFilterOptionsQuery
{
    [Range(1, int.MaxValue)]
    public int? CompanyId { get; init; }

    [Range(1, int.MaxValue)]
    public int? BranchId { get; init; }

    public WeighStationStage? Stage { get; init; }

    [Required]
    public DateTimeOffset? From { get; init; }

    [Required]
    public DateTimeOffset? To { get; init; }
}

public sealed class WeighStationQuery
{
    [Range(1, int.MaxValue)]
    public int? CompanyId { get; init; }

    [Range(1, int.MaxValue)]
    public int? BranchId { get; init; }

    public WeighStationStage? Stage { get; init; }

    [Required]
    public DateTimeOffset? From { get; init; }

    [Required]
    public DateTimeOffset? To { get; init; }

    [StringLength(1000)]
    public string? VehiclePlate { get; init; }

    [StringLength(1000)]
    public string? GoodsName { get; init; }

    [StringLength(1000)]
    public string? OperatorName { get; init; }

    [StringLength(1000)]
    public string? UnitName { get; init; }

    [StringLength(1000)]
    public string? WeighingType { get; init; }

    [Range(1, int.MaxValue)]
    public int PageNumber { get; init; } = 1;
}

public sealed record WeighStationStationResponse(int StationId, string? StationName);

public sealed record WeighStationFilterOptionsResponse(
    IReadOnlyList<string> VehiclePlates,
    IReadOnlyList<string> GoodsNames,
    IReadOnlyList<string> OperatorNames,
    IReadOnlyList<string> UnitNames,
    IReadOnlyList<string> WeighingTypes);

public sealed record WeighStationItemResponse(
    int Stt,
    Guid Id,
    int TicketNumber,
    string? TicketCode,
    DateTimeOffset? WeighingAt,
    string? VehiclePlate,
    string? DriverName,
    string? SealNumber,
    decimal? InboundWeightKg,
    decimal? OutboundWeightKg,
    decimal? GoodsWeightKg,
    bool HasConversionConfiguration,
    decimal? ConvertedQuantity,
    string? ConvertedUnit,
    string? ConversionMessage,
    decimal? MaterialValueVnd,
    string? UnitName,
    string? GoodsName,
    string? WeighingType,
    string? FirstOperatorName,
    string? SecondOperatorName,
    DateTimeOffset? WeighedInAt,
    DateTimeOffset? WeighedOutAt,
    byte? VehicleExitStatus = null);

public sealed record WeighStationResponse(
    IReadOnlyList<WeighStationItemResponse> Items,
    int PageNumber,
    int PageSize,
    int TotalCount,
    int TotalPages,
    bool CanViewMaterialValue);

public sealed record WeighStationConvertedQuantityResponse(
    decimal Quantity,
    string Unit);

public sealed record WeighStationSummaryItemResponse(
    int Stt,
    string? GoodsName,
    decimal GoodsWeightKg,
    IReadOnlyList<WeighStationConvertedQuantityResponse> ConvertedQuantities,
    string? ConversionMessage,
    decimal? MaterialValueVnd,
    int TicketCount = 0);

public sealed record WeighStationTopGoodsResponse(
    string? GoodsName,
    decimal GoodsWeightKg);

public sealed record WeighStationSummaryGroupResponse(
    string Key,
    string Label,
    decimal GoodsWeightKg,
    IReadOnlyList<WeighStationConvertedQuantityResponse> ConvertedQuantities,
    decimal? MaterialValueVnd);

public sealed record WeighStationSummaryResponse(
    IReadOnlyList<WeighStationSummaryItemResponse> Items,
    int PageNumber,
    int PageSize,
    int TotalCount,
    int TotalPages,
    decimal TotalGoodsWeightKg,
    IReadOnlyList<WeighStationConvertedQuantityResponse> TotalConvertedQuantities,
    WeighStationTopGoodsResponse? TopGoods,
    IReadOnlyList<WeighStationSummaryGroupResponse> Groups,
    decimal? TotalMaterialValueVnd,
    bool CanViewMaterialValue);
