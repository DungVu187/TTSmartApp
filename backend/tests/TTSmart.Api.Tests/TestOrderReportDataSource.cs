using TTSmart.Api.Data.StationOperations;
using TTSmart.Api.Features.OrderReporting;

namespace TTSmart.Api.Tests;

internal sealed class TestOrderReportDataSource : IOrderReportDataSource
{
    private readonly Dictionary<int, List<TestOrder>> ordersByBranch = [];
    private readonly HashSet<int> unavailableBranches = [];

    public List<StationDatabaseTarget> SeenTargets { get; } = [];
    public List<(int BranchId, DateTime From, DateTime To)> SeenDashboardMetricRanges { get; } = [];
    public List<(int BranchId, int PageOffset, int PageSize)> SeenSearchPages { get; } = [];

    public void Reset()
    {
        ordersByBranch.Clear();
        unavailableBranches.Clear();
        SeenTargets.Clear();
        SeenDashboardMetricRanges.Clear();
        SeenSearchPages.Clear();
    }

    public void Seed(int branchId, params TestOrder[] orders) =>
        ordersByBranch[branchId] = orders.ToList();

    public void SetUnavailable(int branchId) => unavailableBranches.Add(branchId);

    public Task<OrderReportDashboardMetrics> GetDashboardMetricsAsync(
        StationDatabaseTarget target,
        DateTime from,
        DateTime toExclusive,
        CancellationToken cancellationToken)
    {
        EnsureAvailable(target);
        SeenDashboardMetricRanges.Add((target.BranchId, from, toExclusive));
        var filtered = GetOrders(target.BranchId)
            .Where(order => order.OrderedAt >= from && order.OrderedAt < toExclusive)
            .ToArray();
        var employeeKeys = filtered
            .Select(order => order.EmployeeName?.Trim() ?? string.Empty)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToArray();
        return Task.FromResult(new OrderReportDashboardMetrics(filtered.Length, employeeKeys));
    }

    public Task<IReadOnlyList<string>> GetEmployeeNamesAsync(
        StationDatabaseTarget target,
        DateTime from,
        DateTime toInclusive,
        CancellationToken cancellationToken)
    {
        EnsureAvailable(target);
        var names = GetOrders(target.BranchId)
            .Where(order => order.OrderedAt >= from && order.OrderedAt <= toInclusive)
            .Select(order => order.EmployeeName?.Trim())
            .Where(name => !string.IsNullOrWhiteSpace(name))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .OrderBy(name => name, StringComparer.OrdinalIgnoreCase)
            .Select(name => name!)
            .ToArray();
        return Task.FromResult<IReadOnlyList<string>>(names);
    }

    public Task<StationOrderReportPage> SearchAsync(
        StationDatabaseTarget target,
        DateTime from,
        DateTime to,
        string? employeeName,
        int pageOffset,
        int pageSize,
        CancellationToken cancellationToken)
    {
        EnsureAvailable(target);
        SeenSearchPages.Add((target.BranchId, pageOffset, pageSize));
        var filtered = GetOrders(target.BranchId)
            .Where(order => order.OrderedAt >= from && order.OrderedAt <= to)
            .Where(order => string.IsNullOrWhiteSpace(employeeName) ||
                string.Equals(order.EmployeeName?.Trim(), employeeName, StringComparison.OrdinalIgnoreCase))
            .OrderByDescending(order => order.OrderedAt)
            .ThenByDescending(order => order.OrderId)
            .ToArray();
        var rows = filtered
            .Skip(pageOffset)
            .Take(pageSize)
            .Select(order => new StationOrderReportRow(
                order.OrderId,
                order.CustomerName,
                order.ProjectName,
                order.ConcreteGradeName,
                order.OrderedVolume,
                order.ProducedVolume,
                order.OrderedAt,
                order.EmployeeName))
            .ToArray();
        return Task.FromResult(new StationOrderReportPage(
            rows,
            filtered.Length,
            filtered.Sum(order => (double)(order.OrderedVolume ?? 0)),
            filtered.Sum(order => (double)(order.ProducedVolume ?? 0))));
    }

    private void EnsureAvailable(StationDatabaseTarget target)
    {
        SeenTargets.Add(target);
        if (unavailableBranches.Contains(target.BranchId))
        {
            throw new TTSmart.Api.Common.Exceptions.ServiceUnavailableException(
                "Không thể kết nối dữ liệu vận hành của trạm.",
                new InvalidOperationException(
                    "SqlException Server=internal;Database=TRAM_online;SensitiveDetail=should-not-leak"));
        }
    }

    private IEnumerable<TestOrder> GetOrders(int branchId) =>
        ordersByBranch.TryGetValue(branchId, out var orders)
            ? orders
            : [];
}

internal sealed record TestOrder(
    int OrderId,
    DateTime OrderedAt,
    string? EmployeeName,
    string? CustomerName = null,
    string? ProjectName = null,
    string? ConcreteGradeName = null,
    float? OrderedVolume = null,
    float? ProducedVolume = null);
