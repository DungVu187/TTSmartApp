using System.ComponentModel.DataAnnotations;
using Microsoft.Extensions.Options;
using TTSmart.Api.Common.Exceptions;
using TTSmart.Api.Data.StationOperations;
using TTSmart.Api.Features.BranchManagement;
using TTSmart.Api.Features.OrderReporting;
using TTSmart.Api.Features.OrderStatistics;

namespace TTSmart.Api.Features.Dashboard;

public sealed class DashboardService(
    IBranchAccessResolver branchAccessResolver,
    IOrderStatisticsDataSource dataSource,
    IOrderReportDataSource orderReportDataSource,
    IStationDatabaseAvailabilityResolver databaseAvailabilityResolver,
    IOptions<StationDatabaseOptions> stationDatabaseOptions) : IDashboardService
{
    private static readonly TimeSpan VietnamOffset = TimeSpan.FromHours(7);
    private readonly int maxParallelQueries = stationDatabaseOptions.Value.MaxParallelQueries;

    public async Task<IReadOnlyList<DashboardScopeResponse>> GetScopesAsync(
        int currentUserId,
        CancellationToken cancellationToken)
    {
        var branches = await branchAccessResolver.GetDashboardBranchesAsync(
            currentUserId,
            companyId: null,
            cancellationToken);

        var companyScopes = branches
            .Where(branch => branch.CompanyId.HasValue)
            .GroupBy(branch => new { Id = branch.CompanyId!.Value, branch.CompanyName })
            .OrderBy(group => group.Key.CompanyName)
            .ThenBy(group => group.Key.Id)
            .Select(group => new DashboardScopeResponse(
                $"company-{group.Key.Id}",
                string.IsNullOrWhiteSpace(group.Key.CompanyName)
                    ? $"Công ty {group.Key.Id}"
                    : group.Key.CompanyName.Trim(),
                "company",
                group.Key.Id,
                null,
                $"Tổng hợp {group.Count()} trạm được cấp quyền"));
        var stationScopes = branches
            .OrderBy(branch => branch.CompanyName)
            .ThenBy(branch => branch.Name)
            .ThenBy(branch => branch.Id)
            .Select(branch => new DashboardScopeResponse(
                $"station-{branch.Id}",
                string.IsNullOrWhiteSpace(branch.Name)
                    ? $"Trạm {branch.Id}"
                    : branch.Name.Trim(),
                "station",
                branch.CompanyId,
                branch.Id,
                string.IsNullOrWhiteSpace(branch.CompanyName)
                    ? "Phạm vi một trạm"
                    : branch.CompanyName.Trim()));

        return companyScopes.Concat(stationScopes).ToArray();
    }

    public async Task<DashboardResponse> GetDashboardAsync(
        DashboardQuery query,
        int currentUserId,
        CancellationToken cancellationToken)
    {
        var filter = CreateFilter(query.From, query.To);
        var interval = ParseInterval(query.Interval);
        var branches = await branchAccessResolver.GetDashboardBranchesAsync(
            currentUserId,
            query.CompanyId,
            cancellationToken);
        if (query.BranchId.HasValue)
        {
            branches = branches
                .Where(branch => branch.Id == query.BranchId.Value)
                .ToArray();
            if (branches.Count == 0)
            {
                throw new NotFoundException("Không tìm thấy trạm.");
            }
        }
        if (branches.Count == 0)
        {
            throw new NotFoundException("Không có trạm trộn trong phạm vi được cấp.");
        }

        var availability = await databaseAvailabilityResolver.ResolveAsync(
            branches.Select(CreateTarget).ToArray(),
            cancellationToken);
        var availableBranches = branches
            .Where(branch => availability.AvailableBranchIds.Contains(branch.Id))
            .ToArray();
        var unavailableBranches = branches
            .Where(branch => availability.UnavailableBranchIds.Contains(branch.Id))
            .ToArray();
        if (query.BranchId.HasValue && availableBranches.Length == 0)
        {
            throw new ServiceUnavailableException("Dữ liệu trạm chưa sẵn sàng");
        }

        var results = await QueryBranchesAsync(
            availableBranches,
            filter,
            interval,
            tolerateUnavailable: !query.BranchId.HasValue,
            cancellationToken);
        var kpiResults = await QueryKpiBranchesAsync(
            availableBranches,
            filter,
            tolerateUnavailable: !query.BranchId.HasValue,
            cancellationToken);
        var unavailableIds = unavailableBranches
            .Select(branch => branch.Id)
            .Concat(results.UnavailableBranchIds)
            .Concat(kpiResults.UnavailableBranchIds)
            .ToHashSet();
        var successfulBranchIds = results.Results
            .Select(result => result.Branch.Id)
            .Intersect(kpiResults.Results.Select(result => result.Branch.Id))
            .ToHashSet();
        var successfulResults = results.Results
            .Where(result => successfulBranchIds.Contains(result.Branch.Id))
            .ToArray();
        var successfulKpiResults = kpiResults.Results
            .Where(result => successfulBranchIds.Contains(result.Branch.Id))
            .ToArray();
        var stationSummaries = branches
            .Select(branch =>
            {
                var result = successfulResults.FirstOrDefault(item => item.Branch.Id == branch.Id);
                return new DashboardStationSummaryResponse(
                    branch.Id,
                    branch.CompanyId,
                    branch.CompanyName,
                    branch.Name,
                    result is not null,
                    result?.Data.OrderCount ?? 0,
                    Normalize(result?.Data.TotalMixedVolume),
                    result is null ? 0 : DistinctCount(result.Data.VehiclePlates));
            })
            .OrderBy(station => station.CompanyName)
            .ThenBy(station => station.StationName)
            .ThenBy(station => station.BranchId)
            .ToArray();

        var volumeByBucket = successfulResults
            .SelectMany(result => result.Data.VolumeBuckets)
            .GroupBy(bucket => bucket.StartedAt)
            .ToDictionary(
                group => group.Key,
                group => group.Sum(bucket => bucket.MixedVolume));
        var points = CreateBuckets(filter, interval)
            .Select(bucket => new DashboardVolumePointResponse(
                ToUtc(bucket),
                interval == DashboardAggregationInterval.Hour
                    ? $"{bucket:HH}H"
                    : bucket.ToString("dd/MM"),
                Normalize(volumeByBucket.GetValueOrDefault(bucket))))
            .ToArray();

        return new DashboardResponse(
            DateTimeOffset.UtcNow,
            successfulKpiResults.Sum(result => result.Data.Orders.OrderCount),
            DistinctCount(successfulKpiResults.SelectMany(result => result.Data.Statistics.ConcreteGradeNames)),
            DistinctCount(successfulKpiResults.SelectMany(result => result.Data.Statistics.VehiclePlates)),
            DistinctCount(successfulKpiResults.SelectMany(CreateScopedSalesEmployeeKeys)),
            Normalize(successfulResults.Sum(result => result.Data.TotalMixedVolume)),
            points,
            stationSummaries,
            unavailableIds.Count);
    }

    private async Task<DashboardQueryBatch> QueryBranchesAsync(
        IReadOnlyList<AuthorizedBranch> branches,
        OrderStatisticsFilter filter,
        DashboardAggregationInterval interval,
        bool tolerateUnavailable,
        CancellationToken cancellationToken)
    {
        using var semaphore = new SemaphoreSlim(Math.Max(1, maxParallelQueries));
        var attempts = await Task.WhenAll(branches.Select(async branch =>
        {
            await semaphore.WaitAsync(cancellationToken);
            try
            {
                var data = await dataSource.GetDashboardAsync(
                    CreateTarget(branch),
                    filter,
                    interval,
                    cancellationToken);
                return new DashboardQueryAttempt(branch, data, null);
            }
            catch (ServiceUnavailableException exception) when (tolerateUnavailable)
            {
                return new DashboardQueryAttempt(branch, null, exception);
            }
            finally
            {
                semaphore.Release();
            }
        }));

        return new DashboardQueryBatch(
            attempts
                .Where(attempt => attempt.Data is not null)
                .Select(attempt => new DashboardBranchResult(attempt.Branch, attempt.Data!))
                .ToArray(),
            attempts
                .Where(attempt => attempt.Error is not null)
                .Select(attempt => attempt.Branch.Id)
                .ToHashSet());
    }

    private async Task<DashboardKpiQueryBatch> QueryKpiBranchesAsync(
        IReadOnlyList<AuthorizedBranch> branches,
        OrderStatisticsFilter filter,
        bool tolerateUnavailable,
        CancellationToken cancellationToken)
    {
        using var semaphore = new SemaphoreSlim(Math.Max(1, maxParallelQueries));
        var attempts = await Task.WhenAll(branches.Select(async branch =>
        {
            await semaphore.WaitAsync(cancellationToken);
            try
            {
                var target = CreateTarget(branch);
                var statistics = await dataSource.GetDashboardMetricsAsync(
                    target,
                    filter,
                    cancellationToken);
                var orders = await orderReportDataSource.GetDashboardMetricsAsync(
                    target,
                    filter.FromInclusive,
                    filter.ToExclusive,
                    cancellationToken);
                return new DashboardKpiQueryAttempt(
                    branch,
                    new DashboardKpiData(statistics, orders),
                    null);
            }
            catch (ServiceUnavailableException exception) when (tolerateUnavailable)
            {
                return new DashboardKpiQueryAttempt(branch, null, exception);
            }
            finally
            {
                semaphore.Release();
            }
        }));

        return new DashboardKpiQueryBatch(
            attempts
                .Where(attempt => attempt.Data is not null)
                .Select(attempt => new DashboardKpiBranchResult(attempt.Branch, attempt.Data!))
                .ToArray(),
            attempts
                .Where(attempt => attempt.Error is not null)
                .Select(attempt => attempt.Branch.Id)
                .ToHashSet());
    }

    private static OrderStatisticsFilter CreateFilter(
        DateTimeOffset? from,
        DateTimeOffset? to)
    {
        if (!from.HasValue || !to.HasValue)
        {
            throw new ValidationException("Khoảng thời gian là bắt buộc.");
        }
        var fromLocal = ToVietnamLocal(from.Value);
        var toLocal = ToVietnamLocal(to.Value);
        if (fromLocal >= toLocal)
        {
            throw new ValidationException("Thời gian bắt đầu phải nhỏ hơn thời gian kết thúc.");
        }
        if (toLocal - fromLocal > TimeSpan.FromDays(31))
        {
            throw new ValidationException("Dashboard chỉ hỗ trợ khoảng thời gian tối đa 31 ngày.");
        }
        return new OrderStatisticsFilter(fromLocal, toLocal);
    }

    private static DashboardAggregationInterval ParseInterval(string value) => value switch
    {
        DashboardIntervals.Hour => DashboardAggregationInterval.Hour,
        DashboardIntervals.Day => DashboardAggregationInterval.Day,
        _ => throw new ValidationException("Interval chỉ hỗ trợ hour hoặc day.")
    };

    private static IEnumerable<DateTime> CreateBuckets(
        OrderStatisticsFilter filter,
        DashboardAggregationInterval interval)
    {
        var current = interval == DashboardAggregationInterval.Hour
            ? new DateTime(
                filter.FromInclusive.Year,
                filter.FromInclusive.Month,
                filter.FromInclusive.Day,
                filter.FromInclusive.Hour,
                0,
                0)
            : filter.FromInclusive.Date;
        var step = interval == DashboardAggregationInterval.Hour
            ? TimeSpan.FromHours(1)
            : TimeSpan.FromDays(1);
        while (current < filter.ToExclusive)
        {
            yield return current;
            current = current.Add(step);
        }
    }

    private static DateTime ToVietnamLocal(DateTimeOffset value) =>
        DateTime.SpecifyKind(value.ToOffset(VietnamOffset).DateTime, DateTimeKind.Unspecified);

    private static DateTimeOffset ToUtc(DateTime value) =>
        new DateTimeOffset(DateTime.SpecifyKind(value, DateTimeKind.Unspecified), VietnamOffset)
            .ToUniversalTime();

    private static decimal Normalize(double? value)
    {
        if (!value.HasValue || !double.IsFinite(value.Value))
        {
            return 0m;
        }
        return Math.Round((decimal)value.Value, 3, MidpointRounding.AwayFromZero);
    }

    private static int DistinctCount(IEnumerable<string> values) =>
        values
            .Select(value => value.Trim())
            .Where(value => value.Length > 0)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .Count();

    private static IEnumerable<string> CreateScopedSalesEmployeeKeys(
        DashboardBranchResult result)
    {
        var scopeKey = result.Branch.CompanyId.HasValue
            ? $"company:{result.Branch.CompanyId.Value}"
            : $"branch:{result.Branch.Id}";
        return result.Data.SalesEmployeeKeys.Select(key => $"{scopeKey}:{key}");
    }

    private static IEnumerable<string> CreateScopedSalesEmployeeKeys(
        DashboardKpiBranchResult result)
    {
        var scopeKey = result.Branch.CompanyId.HasValue
            ? $"company:{result.Branch.CompanyId.Value}"
            : $"branch:{result.Branch.Id}";
        return result.Data.Orders.SalesEmployeeKeys.Select(key => $"{scopeKey}:{key}");
    }

    private static StationDatabaseTarget CreateTarget(AuthorizedBranch branch) =>
        new(branch.Id, branch.DatabaseName, branch.TypeTram);

    private sealed record DashboardBranchResult(
        AuthorizedBranch Branch,
        OrderStatisticsDashboardData Data);

    private sealed record DashboardQueryAttempt(
        AuthorizedBranch Branch,
        OrderStatisticsDashboardData? Data,
        ServiceUnavailableException? Error);

    private sealed record DashboardQueryBatch(
        IReadOnlyList<DashboardBranchResult> Results,
        IReadOnlySet<int> UnavailableBranchIds);

    private sealed record DashboardKpiData(
        OrderStatisticsDashboardMetrics Statistics,
        OrderReportDashboardMetrics Orders);

    private sealed record DashboardKpiBranchResult(
        AuthorizedBranch Branch,
        DashboardKpiData Data);

    private sealed record DashboardKpiQueryAttempt(
        AuthorizedBranch Branch,
        DashboardKpiData? Data,
        ServiceUnavailableException? Error);

    private sealed record DashboardKpiQueryBatch(
        IReadOnlyList<DashboardKpiBranchResult> Results,
        IReadOnlySet<int> UnavailableBranchIds);
}
