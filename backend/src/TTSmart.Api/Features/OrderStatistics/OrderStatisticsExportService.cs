namespace TTSmart.Api.Features.OrderStatistics;

public sealed class OrderStatisticsExportService(
    IOrderStatisticsService orderStatisticsService,
    ILogger<OrderStatisticsExportService> logger)
    : IOrderStatisticsExportService
{
    public async Task<OrderStatisticsExportFile> ExportAsync(
        OrderStatisticsExportQuery query,
        int currentUserId,
        CancellationToken cancellationToken)
    {
        var response = await orderStatisticsService.SearchAllAsync(
            query.ToSearchQuery(),
            currentUserId,
            cancellationToken);

        if (response.Items.Count != response.TotalCount)
        {
            logger.LogWarning(
                "Order statistics export loaded {LoadedCount} of {ExpectedCount} rows.",
                response.Items.Count,
                response.TotalCount);
        }

        return new OrderStatisticsExportFile(
            OrderStatisticsXlsxWriter.Create(OrderStatisticsExportAdapter.Create(response)),
            OrderStatisticsExportDefaults.ContentType,
            OrderStatisticsExportDefaults.FileName);
    }
}
