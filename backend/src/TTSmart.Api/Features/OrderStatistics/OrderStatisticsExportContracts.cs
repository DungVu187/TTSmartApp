using System.ComponentModel.DataAnnotations;

namespace TTSmart.Api.Features.OrderStatistics;

public static class OrderStatisticsExportDefaults
{
    public const string ContentType =
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";

    public const string FileName = "thong-ke-don-hang.xlsx";
}

public sealed class OrderStatisticsExportQuery
{
    [Range(1, int.MaxValue)]
    public int? CompanyId { get; init; }

    [Range(1, int.MaxValue)]
    public int? BranchId { get; init; }

    [Required]
    public DateTimeOffset? From { get; init; }

    [Required]
    public DateTimeOffset? To { get; init; }

    public string? VehiclePlate { get; init; }
    public string? CustomerName { get; init; }
    public string? ConcreteGradeName { get; init; }
    public string? EmployeeName { get; init; }

    internal OrderStatisticsQuery ToSearchQuery() => new()
    {
        CompanyId = CompanyId,
        BranchId = BranchId,
        From = From,
        To = To,
        ViewMode = OrderStatisticsViewModes.Detail,
        VehiclePlate = VehiclePlate,
        CustomerName = CustomerName,
        ConcreteGradeName = ConcreteGradeName,
        EmployeeName = EmployeeName,
        PageNumber = 1,
        PageSize = OrderStatisticsContractDefaults.PageSize
    };
}

public sealed record OrderStatisticsExportFile(
    byte[] Content,
    string ContentType,
    string FileName);

public interface IOrderStatisticsExportService
{
    Task<OrderStatisticsExportFile> ExportAsync(
        OrderStatisticsExportQuery query,
        int currentUserId,
        CancellationToken cancellationToken);
}
