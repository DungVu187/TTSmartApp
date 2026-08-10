namespace TTSmart.Api.Features.OrderStatistics;

public interface IOrderStatisticsService
{
    Task<IReadOnlyList<OrderStatisticsStationResponse>> GetStationsAsync(
        OrderStatisticsStationQuery query,
        int currentUserId,
        CancellationToken cancellationToken);

    Task<OrderStatisticsFilterOptionsResponse> GetFilterOptionsAsync(
        OrderStatisticsFilterOptionsQuery query,
        int currentUserId,
        CancellationToken cancellationToken);

    Task<OrderStatisticsResponse> SearchAsync(
        OrderStatisticsQuery query,
        int currentUserId,
        CancellationToken cancellationToken);

    Task<OrderStatisticsResponse> SearchAllAsync(
        OrderStatisticsQuery query,
        int currentUserId,
        CancellationToken cancellationToken);
}
