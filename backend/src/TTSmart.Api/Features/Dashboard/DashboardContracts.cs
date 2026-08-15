using System.ComponentModel.DataAnnotations;

namespace TTSmart.Api.Features.Dashboard;

public static class DashboardIntervals
{
    public const string Hour = "hour";
    public const string Day = "day";
}

public sealed record DashboardScopeResponse(
    string KeyName,
    string Label,
    string Type,
    int? CompanyId,
    int? BranchId,
    string? Description);

public sealed class DashboardQuery
{
    [Range(1, int.MaxValue)]
    public int? CompanyId { get; init; }

    [Range(1, int.MaxValue)]
    public int? BranchId { get; init; }

    [Required]
    public DateTimeOffset? From { get; init; }

    [Required]
    public DateTimeOffset? To { get; init; }

    [RegularExpression("^(hour|day)$")]
    public string Interval { get; init; } = DashboardIntervals.Hour;
}

public sealed record DashboardVolumePointResponse(
    DateTimeOffset StartedAt,
    string Label,
    decimal MixedVolume);

public sealed record DashboardStationSummaryResponse(
    int BranchId,
    int? CompanyId,
    string? CompanyName,
    string? StationName,
    bool IsAvailable,
    int OrderCount,
    decimal MixedVolume,
    int MixerTruckCount);

public sealed record DashboardResponse(
    DateTimeOffset UpdatedAt,
    int OrderCount,
    int ConcreteGradeCount,
    int MixerTruckCount,
    int SalesEmployeeCount,
    decimal TotalMixedVolume,
    IReadOnlyList<DashboardVolumePointResponse> VolumePoints,
    IReadOnlyList<DashboardStationSummaryResponse> Stations,
    int UnavailableStationCount);
