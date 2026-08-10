using System.ComponentModel.DataAnnotations;

namespace TTSmart.Api.Features.OrderReporting;

public sealed class OrderReportStationQuery
{
    [Range(1, int.MaxValue)]
    public int? CompanyId { get; init; }
}

public sealed class OrderReportEmployeeQuery
{
    [Range(1, int.MaxValue)]
    public int? BranchId { get; init; }

    [Range(1, int.MaxValue)]
    public int? CompanyId { get; init; }

    [Required]
    public DateTimeOffset? From { get; init; }

    [Required]
    public DateTimeOffset? To { get; init; }
}

public sealed class OrderReportQuery
{
    [Range(1, int.MaxValue)]
    public int? BranchId { get; init; }

    [Range(1, int.MaxValue)]
    public int? CompanyId { get; init; }

    [Required]
    public DateTimeOffset? From { get; init; }

    [Required]
    public DateTimeOffset? To { get; init; }

    [StringLength(1000)]
    public string? EmployeeName { get; init; }

    [Range(1, int.MaxValue)]
    public int PageNumber { get; init; } = 1;

    [Range(1, 100)]
    public int PageSize { get; init; } = 10;
}

public sealed record OrderReportStationResponse(
    int Id,
    int? CompanyId,
    string? Name,
    int? TypeTram,
    string? CompanyName);

public sealed record OrderReportEmployeeResponse(string Name);

public sealed record OrderReportItemResponse(
    int OrderId,
    int BranchId,
    string? StationName,
    string? CustomerName,
    string? ProjectName,
    string? ConcreteGradeName,
    decimal? OrderedVolume,
    decimal? ProducedVolume,
    DateTime? OrderedAtUtc,
    string? EmployeeName,
    int? CompanyId,
    string? CompanyName);

public sealed record OrderReportStationSummaryResponse(
    int BranchId,
    int? CompanyId,
    string? CompanyName,
    string? StationName,
    int OrderCount,
    decimal OrderedVolume,
    decimal ProducedVolume);

public sealed record OrderReportUnavailableStationResponse(
    int BranchId,
    int? CompanyId,
    string? CompanyName,
    string? StationName);

public sealed record OrderReportResponse(
    IReadOnlyList<OrderReportItemResponse> Items,
    int PageNumber,
    int PageSize,
    int TotalCount,
    int TotalPages,
    decimal TotalOrderedVolume,
    decimal TotalProducedVolume,
    IReadOnlyList<OrderReportStationSummaryResponse> StationSummaries,
    bool IsPartial,
    int SuccessfulStationCount,
    int UnavailableStationCount,
    IReadOnlyList<OrderReportUnavailableStationResponse> UnavailableStations);
