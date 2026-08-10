namespace TTSmart.Api.Features.OrderReporting;

public interface IOrderReportService
{
    Task<IReadOnlyList<OrderReportStationResponse>> GetStationsAsync(
        OrderReportStationQuery query,
        int currentUserId,
        CancellationToken cancellationToken);

    Task<IReadOnlyList<OrderReportEmployeeResponse>> GetEmployeesAsync(
        OrderReportEmployeeQuery query,
        int currentUserId,
        CancellationToken cancellationToken);

    Task<OrderReportResponse> SearchAsync(
        OrderReportQuery query,
        int currentUserId,
        CancellationToken cancellationToken);
}
