using TTSmart.Api.Common.Exceptions;
using TTSmart.Api.Data.StationOperations;
using TTSmart.Api.Features.OrderStatistics;

namespace TTSmart.Api.Tests;

internal sealed class TestOrderStatisticsDataSource : IOrderStatisticsDataSource
{
    private OrderStatisticsPage page = EmptyPage();
    private OrderStatisticsPage? allRowsPage;
    private readonly Dictionary<int, OrderStatisticsPage> pages = [];
    private OrderStatisticsFilterOptions filterOptions = new([], [], [], []);
    private bool unavailable;
    private OrderStatisticsDashboardData dashboardData = EmptyDashboard();

    public List<StationDatabaseTarget> SeenTargets { get; } = [];
    public List<OrderStatisticsFilter> SeenFilterOptionFilters { get; } = [];
    public List<OrderStatisticsFilter> SeenFilters { get; } = [];
    public List<OrderStatisticsViewMode> SeenViewModes { get; } = [];
    public List<int> SeenPageNumbers { get; } = [];
    public int SearchCallCount { get; private set; }
    public int SearchAllCallCount { get; private set; }
    public int FilterCallCount { get; private set; }
    public int DashboardCallCount { get; private set; }
    public List<OrderStatisticsFilter> SeenDashboardMetricFilters { get; } = [];

    public void Reset()
    {
        page = EmptyPage();
        allRowsPage = null;
        pages.Clear();
        filterOptions = new([], [], [], []);
        unavailable = false;
        dashboardData = EmptyDashboard();
        SeenTargets.Clear();
        SeenFilterOptionFilters.Clear();
        SeenFilters.Clear();
        SeenViewModes.Clear();
        SeenPageNumbers.Clear();
        SearchCallCount = 0;
        SearchAllCallCount = 0;
        FilterCallCount = 0;
        DashboardCallCount = 0;
        SeenDashboardMetricFilters.Clear();
    }

    public void SetPage(OrderStatisticsPage value)
    {
        page = value;
        pages.Clear();
    }

    public void SetPages(params OrderStatisticsPage[] values)
    {
        pages.Clear();
        foreach (var value in values)
        {
            pages[value.PageNumber] = value;
        }

        page = values.FirstOrDefault() ?? EmptyPage();
    }

    public void SetAllRowsPage(OrderStatisticsPage value) => allRowsPage = value;

    public void SetFilterOptions(OrderStatisticsFilterOptions value) => filterOptions = value;

    public void SetUnavailable() => unavailable = true;

    public void SetDashboardData(OrderStatisticsDashboardData value) => dashboardData = value;

    public Task<OrderStatisticsDashboardMetrics> GetDashboardMetricsAsync(
        StationDatabaseTarget target,
        OrderStatisticsFilter filter,
        CancellationToken cancellationToken)
    {
        SeenDashboardMetricFilters.Add(filter);
        EnsureAvailable(target);
        return Task.FromResult(new OrderStatisticsDashboardMetrics(
            dashboardData.ConcreteGradeNames,
            dashboardData.VehiclePlates));
    }

    public Task<OrderStatisticsDashboardData> GetDashboardAsync(
        StationDatabaseTarget target,
        OrderStatisticsFilter filter,
        DashboardAggregationInterval interval,
        CancellationToken cancellationToken)
    {
        DashboardCallCount++;
        SeenFilters.Add(filter);
        EnsureAvailable(target);
        return Task.FromResult(dashboardData);
    }

    public Task<OrderStatisticsFilterOptions> GetFilterOptionsAsync(
        StationDatabaseTarget target,
        OrderStatisticsFilter filter,
        CancellationToken cancellationToken)
    {
        FilterCallCount++;
        SeenFilterOptionFilters.Add(filter);
        EnsureAvailable(target);
        return Task.FromResult(filterOptions);
    }

    public Task<OrderStatisticsPage> SearchAsync(
        StationDatabaseTarget target,
        OrderStatisticsFilter filter,
        OrderStatisticsViewMode viewMode,
        int pageNumber,
        CancellationToken cancellationToken)
    {
        SearchCallCount++;
        SeenFilters.Add(filter);
        SeenViewModes.Add(viewMode);
        SeenPageNumbers.Add(pageNumber);
        EnsureAvailable(target);
        var result = pages.TryGetValue(pageNumber, out var configuredPage)
            ? configuredPage
            : page;
        return Task.FromResult(result with { PageNumber = pageNumber });
    }

    public Task<OrderStatisticsPage> SearchAllAsync(
        StationDatabaseTarget target,
        OrderStatisticsFilter filter,
        OrderStatisticsViewMode viewMode,
        CancellationToken cancellationToken)
    {
        SearchAllCallCount++;
        SeenFilters.Add(filter);
        SeenViewModes.Add(viewMode);
        EnsureAvailable(target);
        var result = allRowsPage ?? page;
        return Task.FromResult(result with
        {
            PageNumber = 1,
            PageSize = Math.Max(result.TotalCount, 1)
        });
    }

    private void EnsureAvailable(StationDatabaseTarget target)
    {
        SeenTargets.Add(target);
        if (unavailable)
        {
            throw new ServiceUnavailableException(
                "Dữ liệu trạm chưa sẵn sàng",
                new InvalidOperationException(
                    "SqlException Server=internal;Database=TRAM_online;SensitiveDetail=should-not-leak"));
        }
    }

    private static OrderStatisticsPage EmptyPage() =>
        new(
            [],
            1,
            OrderStatisticsContractDefaults.PageSize,
            0,
            new OrderStatisticsSummary(0, 0, []),
            []);

    private static OrderStatisticsDashboardData EmptyDashboard() =>
        new(0, [], [], [], 0, []);
}
