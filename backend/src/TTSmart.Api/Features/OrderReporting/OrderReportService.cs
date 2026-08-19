using System.ComponentModel.DataAnnotations;
using Microsoft.Extensions.Options;
using TTSmart.Api.Common.Exceptions;
using TTSmart.Api.Common.Time;
using TTSmart.Api.Data.StationOperations;
using TTSmart.Api.Features.BranchManagement;

namespace TTSmart.Api.Features.OrderReporting;

public sealed class OrderReportService(
    IBranchAccessResolver branchAccessResolver,
    IOrderReportDataSource dataSource,
    IStationDatabaseAvailabilityResolver databaseAvailabilityResolver,
    IOptions<StationDatabaseOptions> stationDatabaseOptions) : IOrderReportService
{
    private static readonly TimeSpan VietnamOffset = TimeSpan.FromHours(7);

    private readonly int maxParallelStationQueries =
        stationDatabaseOptions.Value.MaxParallelQueries;

    public async Task<IReadOnlyList<OrderReportStationResponse>> GetStationsAsync(
        OrderReportStationQuery query,
        int currentUserId,
        CancellationToken cancellationToken)
    {
        var branches = await branchAccessResolver.GetOrderReportBranchesAsync(
            currentUserId,
            query.CompanyId,
            cancellationToken);
        return branches
            .Select(branch => new OrderReportStationResponse(
                branch.Id,
                branch.CompanyId,
                branch.Code,
                branch.Name,
                branch.TypeTram,
                branch.CompanyName))
            .ToArray();
    }

    public async Task<IReadOnlyList<OrderReportEmployeeResponse>> GetEmployeesAsync(
        OrderReportEmployeeQuery query,
        int currentUserId,
        CancellationToken cancellationToken)
    {
        var (fromLocal, toInclusive) = CreateTimeRange(query.From, query.To);
        var branches = await branchAccessResolver.GetRequiredOrderReportBranchesAsync(
            currentUserId,
            query.CompanyId,
            query.BranchId,
            cancellationToken);
        var availability = await ResolveAvailableBranchesAsync(
            branches,
            tolerateUnavailableBranches: !query.BranchId.HasValue,
            cancellationToken);
        var namesByBranch = await QueryBranchesAsync(
            availability.AvailableBranches,
            branch => dataSource.GetEmployeeNamesAsync(
                CreateTarget(branch),
                fromLocal,
                toInclusive,
                cancellationToken),
            tolerateUnavailableBranches: !query.BranchId.HasValue,
            cancellationToken);

        return namesByBranch.Results
            .SelectMany(names => names)
            .Select(TrimOrNull)
            .Where(name => name is not null)
            .Select(name => name!)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .OrderBy(name => name, StringComparer.OrdinalIgnoreCase)
            .Select(name => new OrderReportEmployeeResponse(name))
            .ToArray();
    }

    public async Task<OrderReportResponse> SearchAsync(
        OrderReportQuery query,
        int currentUserId,
        CancellationToken cancellationToken)
    {
        var (from, toInclusive) = CreateTimeRange(query.From, query.To);

        var pageOffset = CalculatePageOffset(query.PageNumber, query.PageSize);
        var branches = await branchAccessResolver.GetRequiredOrderReportBranchesAsync(
            currentUserId,
            query.CompanyId,
            query.BranchId,
            cancellationToken);
        var availability = await ResolveAvailableBranchesAsync(
            branches,
            tolerateUnavailableBranches: !query.BranchId.HasValue,
            cancellationToken);
        var aggregateScope = !query.BranchId.HasValue || branches.Count > 1;
        var stationQueryPageSize = aggregateScope
            ? CalculateStationPageSize(pageOffset, query.PageSize)
            : query.PageSize;
        var branchPageBatch = await QueryBranchesAsync(
            availability.AvailableBranches,
            branch => SearchBranchAsync(
                branch,
                from,
                toInclusive,
                TrimOrNull(query.EmployeeName),
                aggregateScope ? 0 : pageOffset,
                stationQueryPageSize,
                cancellationToken),
            tolerateUnavailableBranches: !query.BranchId.HasValue,
            cancellationToken);
        var branchPages = branchPageBatch.Results;

        var summaryByStation = branchPages
            .Select(result => new OrderReportStationSummaryResponse(
                result.Branch.Id,
                result.Branch.CompanyId,
                result.Branch.CompanyName,
                result.Branch.Code,
                result.Branch.Name,
                result.Page.TotalCount,
                NormalizeVolume(result.Page.TotalOrderedVolume) ?? 0,
                NormalizeVolume(result.Page.TotalProducedVolume) ?? 0))
            .OrderBy(summary => summary.CompanyName)
            .ThenBy(summary => summary.StationName)
            .ThenBy(summary => summary.BranchId)
            .ToArray();

        var combinedRows = branchPages
            .SelectMany(result => result.Page.Items.Select(item => new CombinedOrderReportRow(
                result.Branch,
                item)))
            .OrderByDescending(item => item.Row.OrderedAt)
            .ThenByDescending(item => item.Row.OrderId)
            .ThenByDescending(item => item.Branch.Id)
            .ToArray();

        var totalCount = branchPages.Sum(result => result.Page.TotalCount);
        var totalOrderedVolume = NormalizeVolume(
            branchPages.Sum(result => result.Page.TotalOrderedVolume)) ?? 0;
        var totalProducedVolume = NormalizeVolume(
            branchPages.Sum(result => result.Page.TotalProducedVolume)) ?? 0;
        var pageRows = aggregateScope
            ? combinedRows.Skip(pageOffset).Take(query.PageSize)
            : combinedRows;
        var items = pageRows
            .Select(item => new OrderReportItemResponse(
                item.Row.OrderId,
                item.Branch.Id,
                item.Branch.Code,
                item.Branch.Name,
                item.Row.CustomerName,
                item.Row.ProjectName,
                item.Row.ConcreteGradeName,
                NormalizeVolume(item.Row.OrderedVolume),
                NormalizeVolume(item.Row.ProducedVolume),
                VietnamTime.ToUtc(item.Row.OrderedAt),
                TrimOrNull(item.Row.EmployeeName),
                item.Branch.CompanyId,
                item.Branch.CompanyName))
            .ToArray();

        var totalPages = totalCount == 0
            ? 0
            : (int)Math.Ceiling(totalCount / (double)query.PageSize);
        var unavailableStations = availability.UnavailableBranches
            .Concat(branchPageBatch.UnavailableBranches)
            .DistinctBy(branch => branch.Id)
            .Select(branch => new OrderReportUnavailableStationResponse(
                branch.Id,
                branch.CompanyId,
                branch.CompanyName,
                branch.Code,
                branch.Name))
            .ToArray();

        return new OrderReportResponse(
            items,
            query.PageNumber,
            query.PageSize,
            totalCount,
            totalPages,
            totalOrderedVolume,
            totalProducedVolume,
            summaryByStation,
            unavailableStations.Length > 0,
            branchPages.Count,
            unavailableStations.Length,
            unavailableStations);
    }

    private async Task<BranchReportResult> SearchBranchAsync(
        AuthorizedBranch branch,
        DateTime from,
        DateTime toInclusive,
        string? employeeName,
        int pageOffset,
        int pageSize,
        CancellationToken cancellationToken) =>
        new(
            branch,
            await dataSource.SearchAsync(
                CreateTarget(branch),
                from,
                toInclusive,
                employeeName,
                pageOffset,
                pageSize,
                cancellationToken));

    private async Task<BranchAvailabilityBatch> ResolveAvailableBranchesAsync(
        IReadOnlyList<AuthorizedBranch> branches,
        bool tolerateUnavailableBranches,
        CancellationToken cancellationToken)
    {
        if (!tolerateUnavailableBranches || branches.Count == 0)
        {
            return new BranchAvailabilityBatch(branches, []);
        }

        var availability = await databaseAvailabilityResolver.ResolveAsync(
            branches.Select(CreateTarget).ToArray(),
            cancellationToken);
        var availableBranches = branches
            .Where(branch => availability.AvailableBranchIds.Contains(branch.Id))
            .ToArray();
        var unavailableBranches = branches
            .Where(branch => !availability.AvailableBranchIds.Contains(branch.Id))
            .ToArray();
        if (availableBranches.Length == 0 && unavailableBranches.Length > 0)
        {
            throw new ServiceUnavailableException("Station data is unavailable.");
        }

        return new BranchAvailabilityBatch(availableBranches, unavailableBranches);
    }

    private async Task<BranchQueryBatch<TResult>> QueryBranchesAsync<TResult>(
        IReadOnlyList<AuthorizedBranch> branches,
        Func<AuthorizedBranch, Task<TResult>> operation,
        bool tolerateUnavailableBranches,
        CancellationToken cancellationToken)
    {
        if (branches.Count == 0)
        {
            return new BranchQueryBatch<TResult>([], []);
        }

        using var gate = new SemaphoreSlim(
            Math.Min(maxParallelStationQueries, branches.Count));
        var tasks = branches.Select(async branch =>
        {
            await gate.WaitAsync(cancellationToken);
            try
            {
                return new BranchQueryAttempt<TResult>(
                    branch,
                    await operation(branch),
                    null);
            }
            catch (ServiceUnavailableException exception) when (tolerateUnavailableBranches)
            {
                return new BranchQueryAttempt<TResult>(branch, default!, exception);
            }
            finally
            {
                gate.Release();
            }
        });
        var attempts = await Task.WhenAll(tasks);
        var results = attempts
            .Where(attempt => attempt.Error is null)
            .Select(attempt => attempt.Result)
            .ToArray();
        var unavailableAttempts = attempts
            .Where(attempt => attempt.Error is not null)
            .ToArray();
        if (results.Length == 0 && unavailableAttempts.Length > 0)
        {
            throw new ServiceUnavailableException("Station data is unavailable.", unavailableAttempts[0].Error);
        }

        return new BranchQueryBatch<TResult>(
            results,
            unavailableAttempts.Select(attempt => attempt.Branch).ToArray());
    }

    private static StationDatabaseTarget CreateTarget(AuthorizedBranch branch) =>
        new(branch.Id, branch.DatabaseName, branch.TypeTram);

    private static DateTime ToVietnamLocal(DateTimeOffset value) =>
        DateTime.SpecifyKind(value.ToOffset(VietnamOffset).DateTime, DateTimeKind.Unspecified);

    private static (DateTime FromLocal, DateTime ToInclusive) CreateTimeRange(
        DateTimeOffset? from,
        DateTimeOffset? to)
    {
        if (!from.HasValue || !to.HasValue)
        {
            throw new ValidationException("Khoảng thời gian là bắt buộc.");
        }

        var fromLocal = ToVietnamLocal(from.Value);
        var toInclusive = ToVietnamLocal(to.Value);
        if (fromLocal > toInclusive)
        {
            throw new ValidationException("Thời gian bắt đầu phải nhỏ hơn thời gian kết thúc.");
        }

        return (fromLocal, toInclusive);
    }

    private static string? TrimOrNull(string? value)
    {
        var trimmed = value?.Trim();
        return string.IsNullOrEmpty(trimmed) ? null : trimmed;
    }

    private static int CalculatePageOffset(int pageNumber, int pageSize)
    {
        try
        {
            return checked((pageNumber - 1) * pageSize);
        }
        catch (OverflowException exception)
        {
            throw new ValidationException("Số trang vượt quá giới hạn cho phép.", exception);
        }
    }

    private static int CalculateStationPageSize(int pageOffset, int pageSize)
    {
        try
        {
            return checked(pageOffset + pageSize);
        }
        catch (OverflowException exception)
        {
            throw new ValidationException("Số trang vượt quá giới hạn cho phép.", exception);
        }
    }

    private static decimal? NormalizeVolume(float? value) =>
        value.HasValue && float.IsFinite(value.Value)
            ? Math.Round((decimal)value.Value, 1, MidpointRounding.AwayFromZero)
            : null;

    private static decimal? NormalizeVolume(double value) =>
        double.IsFinite(value)
            ? Math.Round((decimal)value, 1, MidpointRounding.AwayFromZero)
            : null;

    private sealed record BranchReportResult(
        AuthorizedBranch Branch,
        StationOrderReportPage Page);

    private sealed record BranchAvailabilityBatch(
        IReadOnlyList<AuthorizedBranch> AvailableBranches,
        IReadOnlyList<AuthorizedBranch> UnavailableBranches);

    private sealed record BranchQueryAttempt<TResult>(
        AuthorizedBranch Branch,
        TResult Result,
        ServiceUnavailableException? Error);

    private sealed record BranchQueryBatch<TResult>(
        IReadOnlyList<TResult> Results,
        IReadOnlyList<AuthorizedBranch> UnavailableBranches);

    private sealed record CombinedOrderReportRow(
        AuthorizedBranch Branch,
        StationOrderReportRow Row);
}
