using System.Data.Common;
using System.Diagnostics;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using TTSmart.Api.Common.Diagnostics;
using TTSmart.Api.Common.Exceptions;
using TTSmart.Api.Data.StationOperations;

namespace TTSmart.Api.Features.OrderStatistics;

public enum OrderStatisticsViewMode
{
    Detail,
    Total
}

public enum DashboardAggregationInterval
{
    Hour,
    Day
}

public sealed record OrderStatisticsDashboardBucket(
    DateTime StartedAt,
    double MixedVolume);

public sealed record OrderStatisticsDashboardData(
    int OrderCount,
    IReadOnlyList<string> ConcreteGradeNames,
    IReadOnlyList<string> VehiclePlates,
    IReadOnlyList<string> SalesEmployeeKeys,
    double TotalMixedVolume,
    IReadOnlyList<OrderStatisticsDashboardBucket> VolumeBuckets);

public sealed record OrderStatisticsDashboardMetrics(
    IReadOnlyList<string> ConcreteGradeNames,
    IReadOnlyList<string> VehiclePlates);

public sealed record OrderStatisticsFilter(
    DateTime FromInclusive,
    DateTime ToExclusive,
    string? VehiclePlate = null,
    string? CustomerName = null,
    string? ConcreteGradeName = null,
    string? EmployeeName = null,
    bool UseFinishedAtInclusive = false);

public sealed record OrderStatisticsMaterialValue(
    long MaterialSlotId,
    int? SlotNumber,
    string? MaterialName,
    string? Category,
    double DesignQuantity,
    double TQuantity,
    double ActualQuantity,
    double Variance,
    string CategoryCode = OrderStatisticsMaterialCategories.Unknown,
    int TypePosition = 0);

public sealed record OrderStatisticsMaterialColumn(
    long MaterialSlotId,
    int? SlotNumber,
    string? MaterialName,
    string? Category,
    string DesignLabel,
    string TLabel,
    string ActualLabel,
    string VarianceLabel,
    string CategoryCode = OrderStatisticsMaterialCategories.Unknown,
    int TypePosition = 0);

public sealed record OrderStatisticsRow(
    long? MixingDetailId,
    long MixingHistoryId,
    int? BatchNumber,
    DateTime? MixingDate,
    DateTime? StartedAt,
    DateTime? FinishedAt,
    string? CustomerName,
    string? ProjectName,
    string? WorkItemName,
    string? LocationName,
    string? VehiclePlate,
    string? DriverName,
    string? ConcreteGradeName,
    string? Slump,
    double? RequestedVolume,
    double? MixedVolume,
    string? SalesEmployeeCode,
    string? EmployeeName,
    int CompletedBatchCount,
    IReadOnlyList<OrderStatisticsMaterialValue> Materials,
    string? SalesEmployeeName = null);

public sealed record OrderStatisticsSummary(
    double TotalMixedVolume,
    double TotalMaterialQuantity,
    IReadOnlyList<OrderStatisticsMaterialValue> Materials);

public sealed record OrderStatisticsFilterOptions(
    IReadOnlyList<string> VehiclePlates,
    IReadOnlyList<string> CustomerNames,
    IReadOnlyList<string> ConcreteGradeNames,
    IReadOnlyList<string> EmployeeNames);

public sealed record OrderStatisticsPage(
    IReadOnlyList<OrderStatisticsRow> Items,
    int PageNumber,
    int PageSize,
    int TotalCount,
    OrderStatisticsSummary Summary,
    IReadOnlyList<OrderStatisticsMaterialColumn> MaterialColumns);

public interface IOrderStatisticsDataSource
{
    Task<OrderStatisticsDashboardMetrics> GetDashboardMetricsAsync(
        StationDatabaseTarget target,
        OrderStatisticsFilter filter,
        CancellationToken cancellationToken);

    Task<OrderStatisticsDashboardData> GetDashboardAsync(
        StationDatabaseTarget target,
        OrderStatisticsFilter filter,
        DashboardAggregationInterval interval,
        CancellationToken cancellationToken);

    Task<OrderStatisticsFilterOptions> GetFilterOptionsAsync(
        StationDatabaseTarget target,
        OrderStatisticsFilter filter,
        CancellationToken cancellationToken);

    Task<OrderStatisticsPage> SearchAsync(
        StationDatabaseTarget target,
        OrderStatisticsFilter filter,
        OrderStatisticsViewMode viewMode,
        int pageNumber,
        CancellationToken cancellationToken);

    Task<OrderStatisticsPage> SearchAllAsync(
        StationDatabaseTarget target,
        OrderStatisticsFilter filter,
        OrderStatisticsViewMode viewMode,
        CancellationToken cancellationToken);
}

public sealed class SqlOrderStatisticsDataSource(
    IStationOperationsDbContextFactory dbContextFactory,
    ILogger<SqlOrderStatisticsDataSource> logger,
    IHttpContextAccessor httpContextAccessor,
    IOptionsMonitor<PerformanceLoggingOptions> performanceLoggingOptions)
    : IOrderStatisticsDataSource
{
    private const string StationUnavailableMessage = "Dữ liệu trạm chưa sẵn sàng";
    private const int HistoricalMaterialSlotIdChunkSize = 1000;

    public Task<OrderStatisticsDashboardMetrics> GetDashboardMetricsAsync(
        StationDatabaseTarget target,
        OrderStatisticsFilter filter,
        CancellationToken cancellationToken) =>
        ExecuteAsync(target, cancellationToken, dbContext => LoadDashboardMetricsAsync(
            dbContext,
            filter,
            cancellationToken));

    public Task<OrderStatisticsDashboardData> GetDashboardAsync(
        StationDatabaseTarget target,
        OrderStatisticsFilter filter,
        DashboardAggregationInterval interval,
        CancellationToken cancellationToken) =>
        ExecuteAsync(target, cancellationToken, dbContext => LoadDashboardAsync(
            dbContext,
            filter,
            interval,
            cancellationToken));

    private static async Task<OrderStatisticsDashboardMetrics> LoadDashboardMetricsAsync(
        StationOperationsDbContext dbContext,
        OrderStatisticsFilter filter,
        CancellationToken cancellationToken)
    {
        var histories = CreateWebDashboardHistoryQuery(dbContext, filter);
        var concreteGradeNames = await histories
            .Where(history =>
                history.ConcreteGradeName != null && history.ConcreteGradeName != string.Empty)
            .Select(history => history.ConcreteGradeName!)
            .Distinct()
            .ToListAsync(cancellationToken);
        var vehiclePlates = await histories
            .Select(history => history.VehiclePlate ?? string.Empty)
            .Distinct()
            .ToListAsync(cancellationToken);
        return new OrderStatisticsDashboardMetrics(concreteGradeNames, vehiclePlates);
    }

    public Task<OrderStatisticsFilterOptions> GetFilterOptionsAsync(
        StationDatabaseTarget target,
        OrderStatisticsFilter filter,
        CancellationToken cancellationToken) =>
        ExecuteAsync(target, cancellationToken, dbContext => LoadFilterOptionsAsync(
            dbContext,
            filter,
            cancellationToken));

    public Task<OrderStatisticsPage> SearchAsync(
        StationDatabaseTarget target,
        OrderStatisticsFilter filter,
        OrderStatisticsViewMode viewMode,
        int pageNumber,
        CancellationToken cancellationToken) =>
        ExecuteAsync(target, cancellationToken, dbContext => SearchCoreAsync(
            dbContext,
            filter,
            viewMode,
            pageNumber,
            loadAllRows: false,
            cancellationToken));

    public Task<OrderStatisticsPage> SearchAllAsync(
        StationDatabaseTarget target,
        OrderStatisticsFilter filter,
        OrderStatisticsViewMode viewMode,
        CancellationToken cancellationToken) =>
        ExecuteAsync(target, cancellationToken, dbContext => SearchCoreAsync(
            dbContext,
            filter,
            viewMode,
            pageNumber: 1,
            loadAllRows: true,
            cancellationToken));

    private async Task<OrderStatisticsPage> SearchCoreAsync(
        StationOperationsDbContext dbContext,
        OrderStatisticsFilter filter,
        OrderStatisticsViewMode viewMode,
        int pageNumber,
        bool loadAllRows,
        CancellationToken cancellationToken)
    {
        ValidateSearch(filter, pageNumber);
        var currentMaterialLayout = await MeasureStageAsync(
            "LoadCurrentMaterialLayout",
            () => LoadCurrentMaterialLayoutAsync(dbContext, cancellationToken));
        var filteredBatches = ApplyFilters(
            CreateBatchQuery(dbContext),
            filter);
        var metrics = await MeasureStageAsync(
            "LoadFilteredBatchMetrics",
            () => LoadFilteredBatchMetricsAsync(
                filteredBatches,
                cancellationToken));
        var totalCount = viewMode == OrderStatisticsViewMode.Detail
            ? metrics.CompletedBatchCount
            : metrics.CompletedOrderCount;
        var summary = await MeasureStageAsync(
            "LoadSummary",
            () => LoadSummaryAsync(
                dbContext,
                filteredBatches,
                metrics,
                currentMaterialLayout,
                cancellationToken));
        if (summary.Materials.Any(material =>
            material.CategoryCode == OrderStatisticsMaterialCategories.Unknown))
        {
            logger.LogWarning(
                "Order statistics contains material rows with an unknown category. TraceId={TraceId}",
                CurrentTraceId);
        }
        var pageOffset = loadAllRows
            ? 0
            : checked((pageNumber - 1) * OrderStatisticsContractDefaults.PageSize);
        IReadOnlyList<BatchQueryRow> detailItems = [];
        IReadOnlyList<TotalQueryRow> totalItems = [];
        if (viewMode == OrderStatisticsViewMode.Detail)
        {
            detailItems = await MeasureStageAsync(
                loadAllRows ? "LoadAllDetailRows" : "LoadDetailPage",
                () => LoadDetailRowsAsync(
                    filteredBatches,
                    pageOffset,
                    loadAllRows,
                    cancellationToken));
        }
        else
        {
            totalItems = await MeasureStageAsync(
                loadAllRows ? "LoadAllTotalRows" : "LoadTotalPage",
                () => LoadTotalRowsAsync(
                    filteredBatches,
                    pageOffset,
                    loadAllRows,
                    cancellationToken));
        }

        var materialValues = viewMode == OrderStatisticsViewMode.Detail
            ? await MeasureStageAsync(
                "LoadDetailMaterials",
                () => LoadDetailMaterialsAsync(
                    dbContext,
                    detailItems,
                    currentMaterialLayout,
                    cancellationToken))
            : await MeasureStageAsync(
                "LoadTotalMaterials",
                () => LoadTotalMaterialsAsync(
                    dbContext,
                    filteredBatches,
                    totalItems,
                    currentMaterialLayout,
                    cancellationToken));
        IReadOnlyList<OrderStatisticsRow> rows = viewMode == OrderStatisticsViewMode.Detail
            ? MapDetailRows(detailItems, materialValues)
            : MapTotalRows(totalItems, materialValues);
        var materialColumns = BuildMaterialColumns(currentMaterialLayout);
        var resultPageSize = loadAllRows
            ? Math.Max(totalCount, 1)
            : OrderStatisticsContractDefaults.PageSize;

        return new OrderStatisticsPage(
            rows,
            pageNumber,
            resultPageSize,
            totalCount,
            summary,
            materialColumns);
    }

    private static async Task<OrderStatisticsDashboardData> LoadDashboardAsync(
        StationOperationsDbContext dbContext,
        OrderStatisticsFilter filter,
        DashboardAggregationInterval interval,
        CancellationToken cancellationToken)
    {
        var histories = CreateWebDashboardHistoryQuery(dbContext, filter);
        var mixedRows =
            from history in histories
            join detail in dbContext.MixingDetails.AsNoTracking()
                on history.MixingHistoryId equals detail.MixingHistoryId
            select new
            {
                history.MixingHistoryId,
                history.FinishedAt,
                detail.MixedVolume
            };
        var historyCount = await histories.CountAsync(cancellationToken);
        var totalMixedVolume = await mixedRows
            .GroupBy(_ => 1)
            .Select(group => group.Sum(row => (double)(row.MixedVolume ?? 0f)))
            .SingleOrDefaultAsync(cancellationToken);

        var concreteGradeNames = await histories
            .Where(history =>
                history.ConcreteGradeName != null && history.ConcreteGradeName != string.Empty)
            .Select(history => history.ConcreteGradeName!)
            .Distinct()
            .ToListAsync(cancellationToken);
        var vehiclePlates = await histories
            .Select(history => history.VehiclePlate ?? string.Empty)
            .Distinct()
            .ToListAsync(cancellationToken);

        IReadOnlyList<OrderStatisticsDashboardBucket> buckets;
        if (interval == DashboardAggregationInterval.Hour)
        {
            var hourlyRows = await mixedRows
                .Where(row => row.FinishedAt.HasValue)
                .GroupBy(row => new
                {
                    Year = row.FinishedAt!.Value.Year,
                    Month = row.FinishedAt.Value.Month,
                    Day = row.FinishedAt.Value.Day,
                    Hour = row.FinishedAt.Value.Hour
                })
                .Select(group => new
                {
                    group.Key.Year,
                    group.Key.Month,
                    group.Key.Day,
                    group.Key.Hour,
                    MixedVolume = group.Sum(row => (double)(row.MixedVolume ?? 0f))
                })
                .OrderBy(row => row.Year)
                .ThenBy(row => row.Month)
                .ThenBy(row => row.Day)
                .ThenBy(row => row.Hour)
                .ToListAsync(cancellationToken);
            buckets = hourlyRows
                .Select(row => new OrderStatisticsDashboardBucket(
                    new DateTime(row.Year, row.Month, row.Day, row.Hour, 0, 0),
                    row.MixedVolume))
                .ToArray();
        }
        else
        {
            var dailyRows = await mixedRows
                .Where(row => row.FinishedAt.HasValue)
                .GroupBy(row => new
                {
                    Year = row.FinishedAt!.Value.Year,
                    Month = row.FinishedAt.Value.Month,
                    Day = row.FinishedAt.Value.Day
                })
                .Select(group => new
                {
                    group.Key.Year,
                    group.Key.Month,
                    group.Key.Day,
                    MixedVolume = group.Sum(row => (double)(row.MixedVolume ?? 0f))
                })
                .OrderBy(row => row.Year)
                .ThenBy(row => row.Month)
                .ThenBy(row => row.Day)
                .ToListAsync(cancellationToken);
            buckets = dailyRows
                .Select(row => new OrderStatisticsDashboardBucket(
                    new DateTime(row.Year, row.Month, row.Day),
                    row.MixedVolume))
                .ToArray();
        }

        return new OrderStatisticsDashboardData(
            historyCount,
            concreteGradeNames,
            vehiclePlates,
            [],
            totalMixedVolume,
            buckets);
    }

    private static IQueryable<StationMixingHistory> CreateWebDashboardHistoryQuery(
        StationOperationsDbContext dbContext,
        OrderStatisticsFilter filter) =>
        from history in dbContext.MixingHistories.AsNoTracking()
        join order in dbContext.OrderHistories.AsNoTracking()
            on history.OrderHistoryId equals (long?)order.OrderHistoryId
        where history.FinishedAt >= filter.FromInclusive &&
            history.FinishedAt <= filter.ToExclusive
        select history;

    private static void ValidateSearch(OrderStatisticsFilter filter, int pageNumber)
    {
        if (filter.UseFinishedAtInclusive
            ? filter.FromInclusive > filter.ToExclusive
            : filter.FromInclusive >= filter.ToExclusive)
        {
            throw new ArgumentException(
                "Thời gian bắt đầu phải nhỏ hơn thời gian kết thúc.",
                nameof(filter));
        }

        if (pageNumber < 1)
        {
            throw new ArgumentOutOfRangeException(nameof(pageNumber));
        }
    }

    private async Task<OrderStatisticsFilterOptions> LoadFilterOptionsAsync(
        StationOperationsDbContext dbContext,
        OrderStatisticsFilter filter,
        CancellationToken cancellationToken)
    {
        var rows = await MeasureStageAsync(
            "LoadFilterOptions",
            () => (
                from history in dbContext.MixingHistories.AsNoTracking()
                join orderHistory in dbContext.OrderHistories.AsNoTracking()
                    on history.OrderHistoryId equals (long?)orderHistory.OrderHistoryId into orderHistoryGroup
                from orderHistory in orderHistoryGroup.DefaultIfEmpty()
                where filter.UseFinishedAtInclusive
                    ? history.FinishedAt >= filter.FromInclusive &&
                      history.FinishedAt <= filter.ToExclusive
                    : history.StartedAt >= filter.FromInclusive &&
                      history.StartedAt < filter.ToExclusive
                select new
                {
                    history.VehiclePlate,
                    CustomerName = orderHistory == null ? null : orderHistory.CustomerName,
                    history.ConcreteGradeName,
                    EmployeeName = orderHistory == null ? null : orderHistory.EmployeeName
                }).ToListAsync(cancellationToken));

        return new OrderStatisticsFilterOptions(
            DistinctValues(rows.Select(row => row.VehiclePlate)),
            DistinctValues(rows.Select(row => row.CustomerName)),
            DistinctValues(rows.Select(row => row.ConcreteGradeName)),
            DistinctValues(rows.Select(row => row.EmployeeName)));
    }

    private static IReadOnlyList<string> DistinctValues(IEnumerable<string?> values) =>
        values
            .Select(TrimOrNull)
            .Where(value => value is not null)
            .Select(value => value!)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .OrderBy(value => value, StringComparer.OrdinalIgnoreCase)
            .ToArray();

    private static IQueryable<BatchQueryRow> CreateBatchQuery(
        StationOperationsDbContext dbContext,
        OrderStatisticsFilter? dashboardFilter = null)
    {
        var histories = dbContext.MixingHistories.AsNoTracking();
        if (dashboardFilter is not null)
        {
            histories = dashboardFilter.UseFinishedAtInclusive
                ? histories.Where(history =>
                    history.FinishedAt >= dashboardFilter.FromInclusive &&
                    history.FinishedAt <= dashboardFilter.ToExclusive)
                : histories.Where(history =>
                    history.StartedAt >= dashboardFilter.FromInclusive &&
                    history.StartedAt < dashboardFilter.ToExclusive);
        }

        var query =
            from history in histories
            join detail in dbContext.MixingDetails.AsNoTracking()
                on history.MixingHistoryId equals detail.MixingHistoryId
            join orderHistory in dbContext.OrderHistories.AsNoTracking()
                on history.OrderHistoryId equals (long?)orderHistory.OrderHistoryId into orderHistoryGroup
            from orderHistory in orderHistoryGroup.DefaultIfEmpty()
            join vehicle in dbContext.Vehicles.AsNoTracking()
                on history.VehiclePlate equals vehicle.VehiclePlate into vehicleGroup
            from vehicle in vehicleGroup.DefaultIfEmpty()
            where dbContext.MixingMaterials.AsNoTracking().Any(material =>
                material.MixingDetailId == detail.MixingDetailId)
            select new BatchQueryRow
            {
                MixingDetailId = detail.MixingDetailId,
                MixingHistoryId = history.MixingHistoryId,
                BatchNumber = detail.BatchNumber,
                MixingDate = history.MixingDate,
                StartedAt = history.StartedAt,
                FinishedAt = history.FinishedAt,
                CustomerName = orderHistory == null ? null : orderHistory.CustomerName,
                ProjectName = orderHistory == null ? null : orderHistory.ProjectName,
                WorkItemName = orderHistory == null ? null : orderHistory.WorkItemName,
                LocationName = orderHistory == null ? null : orderHistory.LocationName,
                VehiclePlate = history.VehiclePlate,
                DriverName = vehicle != null &&
                    vehicle.DriverName != null &&
                    vehicle.DriverName.Trim() != string.Empty
                        ? vehicle.DriverName
                        : history.Username,
                ConcreteGradeName = history.ConcreteGradeName,
                Slump = history.Slump,
                RequestedVolume = orderHistory != null &&
                    orderHistory.RequestedVolumeText != null &&
                    EF.Functions.IsNumeric(orderHistory.RequestedVolumeText)
                        ? Convert.ToDouble(orderHistory.RequestedVolumeText)
                        : 0d,
                MixedVolume = detail.MixedVolume,
                SalesEmployeeId = orderHistory == null ? null : orderHistory.SalesEmployeeId,
                SalesEmployeeCode = null,
                SalesEmployeeName = orderHistory == null ? null : orderHistory.EmployeeName,
                EmployeeName = null
            };

        return query;
    }

    private static IQueryable<BatchQueryRow> ApplyFilters(
        IQueryable<BatchQueryRow> query,
        OrderStatisticsFilter filter)
    {
        var vehiclePlate = TrimOrNull(filter.VehiclePlate);
        if (vehiclePlate is not null)
        {
            query = query.Where(row =>
                row.VehiclePlate != null && row.VehiclePlate.Trim() == vehiclePlate);
        }

        var customerName = TrimOrNull(filter.CustomerName);
        if (customerName is not null)
        {
            query = query.Where(row =>
                row.CustomerName != null && row.CustomerName.Trim() == customerName);
        }

        var concreteGradeName = TrimOrNull(filter.ConcreteGradeName);
        if (concreteGradeName is not null)
        {
            query = query.Where(row =>
                row.ConcreteGradeName != null && row.ConcreteGradeName.Trim() == concreteGradeName);
        }

        var employeeName = TrimOrNull(filter.EmployeeName);
        if (employeeName is not null)
        {
            query = query.Where(row =>
                row.SalesEmployeeName != null && row.SalesEmployeeName.Trim() == employeeName);
        }

        query = filter.UseFinishedAtInclusive
            ? query.Where(row =>
                row.FinishedAt >= filter.FromInclusive &&
                row.FinishedAt <= filter.ToExclusive)
            : query.Where(row =>
                row.StartedAt >= filter.FromInclusive &&
                row.StartedAt < filter.ToExclusive);

        return query;
    }

    private static async Task<FilteredBatchMetrics> LoadFilteredBatchMetricsAsync(
        IQueryable<BatchQueryRow> filteredBatches,
        CancellationToken cancellationToken) =>
        await filteredBatches
            .GroupBy(_ => 1)
            .Select(group => new FilteredBatchMetrics
            {
                CompletedBatchCount = group.Count(),
                CompletedOrderCount = group
                    .Select(batch => batch.MixingHistoryId)
                    .Distinct()
                    .Count(),
                TotalMixedVolume = group.Sum(batch =>
                    (double)(batch.MixedVolume ?? 0f))
            })
            .SingleOrDefaultAsync(cancellationToken) ?? new FilteredBatchMetrics();

    private static async Task<OrderStatisticsSummary> LoadSummaryAsync(
        StationOperationsDbContext dbContext,
        IQueryable<BatchQueryRow> filteredBatches,
        FilteredBatchMetrics metrics,
        IReadOnlyList<MaterialLayoutEntry> currentMaterialLayout,
        CancellationToken cancellationToken)
    {
        var materialQuery =
            from batch in filteredBatches
            join material in dbContext.MixingMaterials.AsNoTracking()
                on batch.MixingDetailId equals material.MixingDetailId
            join slot in dbContext.MaterialSlots.AsNoTracking()
                on material.MaterialSlotId equals slot.MaterialSlotId into slotGroup
            from slot in slotGroup.DefaultIfEmpty()
            join materialType in dbContext.MaterialTypes.AsNoTracking()
                on slot == null ? null : slot.MaterialTypeId equals materialType.MaterialTypeId into typeGroup
            from materialType in typeGroup.DefaultIfEmpty()
            select new
            {
                MaterialSlotId = material.MaterialSlotId,
                SlotNumber = slot == null ? null : slot.SlotNumber,
                MaterialName = slot == null ? null : slot.Name,
                Category = materialType == null ? null : materialType.Name,
                ActualQuantity = (double?)(material.ActualQuantity ?? 0f)
            };
        var materialRows = await materialQuery
            .GroupBy(row => new
            {
                row.MaterialSlotId,
                row.SlotNumber,
                row.MaterialName,
                row.Category
            })
            .Select(group => new MaterialAggregateQueryRow
            {
                MaterialSlotId = group.Key.MaterialSlotId,
                SlotNumber = group.Key.SlotNumber,
                MaterialName = group.Key.MaterialName,
                Category = group.Key.Category,
                ActualQuantity = group.Sum(row => row.ActualQuantity ?? 0d)
            })
            .ToListAsync(cancellationToken);

        var historicalLayouts = await LoadHistoricalMaterialLayoutsAsync(
            dbContext,
            materialRows,
            currentMaterialLayout,
            cancellationToken);
        var normalizedMaterials = NormalizeSummaryMaterials(
            materialRows,
            historicalLayouts);
        var materials = BuildSummaryMaterials(
            normalizedMaterials,
            currentMaterialLayout);
        return new OrderStatisticsSummary(
            metrics.TotalMixedVolume,
            normalizedMaterials.Sum(material => material.ActualQuantity),
            materials);
    }

    private static IQueryable<TotalQueryRow> CreateTotalQuery(
        IQueryable<BatchQueryRow> filteredBatches)
    {
        // Database trạm legacy có thể dùng text/ntext cho thông tin đơn hàng.
        // SQL Server không cho aggregate MAX/MIN trực tiếp trên các kiểu đó,
        // nên chỉ aggregate dữ liệu số rồi join lại một chi tiết đại diện của mẻ.
        var aggregates =
            from batch in filteredBatches
            group batch by batch.MixingHistoryId
            into grouped
            select new
            {
                MixingHistoryId = grouped.Key,
                RepresentativeDetailId = grouped.Min(row => row.MixingDetailId),
                BatchNumber = grouped.Max(row => row.BatchNumber),
                RequestedVolume = grouped.Sum(row => row.RequestedVolume ?? 0d),
                MixedVolume = grouped.Sum(row => (double)(row.MixedVolume ?? 0f)),
                CompletedBatchCount = grouped.Count()
            };

        return
            from aggregate in aggregates
            join representative in filteredBatches
                on aggregate.RepresentativeDetailId equals representative.MixingDetailId
            select new TotalQueryRow
            {
                MixingHistoryId = aggregate.MixingHistoryId,
                BatchNumber = aggregate.BatchNumber,
                MixingDate = representative.MixingDate,
                StartedAt = representative.StartedAt,
                FinishedAt = representative.FinishedAt,
                CustomerName = representative.CustomerName,
                ProjectName = representative.ProjectName,
                WorkItemName = representative.WorkItemName,
                LocationName = representative.LocationName,
                VehiclePlate = representative.VehiclePlate,
                DriverName = representative.DriverName,
                ConcreteGradeName = representative.ConcreteGradeName,
                Slump = representative.Slump,
                RequestedVolume = aggregate.RequestedVolume,
                MixedVolume = aggregate.MixedVolume,
                SalesEmployeeId = representative.SalesEmployeeId,
                SalesEmployeeCode = representative.SalesEmployeeCode,
                SalesEmployeeName = representative.SalesEmployeeName,
                EmployeeName = representative.EmployeeName,
                CompletedBatchCount = aggregate.CompletedBatchCount
            };
    }

    private static async Task<IReadOnlyList<BatchQueryRow>> LoadDetailRowsAsync(
        IQueryable<BatchQueryRow> filteredBatches,
        int pageOffset,
        bool loadAllRows,
        CancellationToken cancellationToken) =>
        await ApplyPagination(
                filteredBatches
                    .OrderBy(row => row.MixingDetailId),
                pageOffset,
                loadAllRows)
            .ToListAsync(cancellationToken);

    private static async Task<IReadOnlyList<TotalQueryRow>> LoadTotalRowsAsync(
        IQueryable<BatchQueryRow> filteredBatches,
        int pageOffset,
        bool loadAllRows,
        CancellationToken cancellationToken) =>
        await ApplyPagination(
                CreateTotalQuery(filteredBatches)
                    .OrderBy(row => row.MixingDate)
                    .ThenBy(row => row.StartedAt)
                    .ThenBy(row => row.FinishedAt)
                    .ThenBy(row => row.MixingHistoryId),
                pageOffset,
                loadAllRows)
            .ToListAsync(cancellationToken);

    private static IQueryable<T> ApplyPagination<T>(
        IQueryable<T> query,
        int pageOffset,
        bool loadAllRows) =>
        loadAllRows
            ? query
            : query.Skip(pageOffset).Take(OrderStatisticsContractDefaults.PageSize);

    private static async Task<IReadOnlyDictionary<long, IReadOnlyList<OrderStatisticsMaterialValue>>> LoadDetailMaterialsAsync(
        StationOperationsDbContext dbContext,
        IReadOnlyList<BatchQueryRow> pageRows,
        IReadOnlyList<MaterialLayoutEntry> currentMaterialLayout,
        CancellationToken cancellationToken)
    {
        var detailIds = pageRows
            .Select(row => row.MixingDetailId)
            .Distinct()
            .ToArray();
        if (detailIds.Length == 0)
        {
            return new Dictionary<long, IReadOnlyList<OrderStatisticsMaterialValue>>();
        }

        var materialRows = await (
            from material in dbContext.MixingMaterials.AsNoTracking()
            join slot in dbContext.MaterialSlots.AsNoTracking()
                on material.MaterialSlotId equals slot.MaterialSlotId into slotGroup
            from slot in slotGroup.DefaultIfEmpty()
            join materialType in dbContext.MaterialTypes.AsNoTracking()
                on slot == null ? null : slot.MaterialTypeId equals materialType.MaterialTypeId into typeGroup
            from materialType in typeGroup.DefaultIfEmpty()
            where detailIds.Contains(material.MixingDetailId)
            select new MaterialAggregateQueryRow
            {
                MixingDetailId = material.MixingDetailId,
                MaterialSlotId = material.MaterialSlotId,
                SlotNumber = slot == null ? null : slot.SlotNumber,
                MaterialName = slot == null ? null : slot.Name,
                Category = materialType == null ? null : materialType.Name,
                DesignQuantity = (double?)(material.DesignQuantity ?? 0f),
                TQuantity = (double?)(material.TQuantity ?? 0f),
                ActualQuantity = (double?)(material.ActualQuantity ?? 0f)
            }).ToListAsync(cancellationToken);

        var historyIdsByDetail = pageRows.ToDictionary(
            row => row.MixingDetailId,
            row => row.MixingHistoryId);
        foreach (var materialRow in materialRows)
        {
            if (materialRow.MixingDetailId.HasValue &&
                historyIdsByDetail.TryGetValue(materialRow.MixingDetailId.Value, out var mixingHistoryId))
            {
                materialRow.MixingHistoryId = mixingHistoryId;
            }
        }

        var historicalLayouts = await LoadHistoricalMaterialLayoutsAsync(
            dbContext,
            materialRows,
            currentMaterialLayout,
            cancellationToken);
        return NormalizeHistoricalMaterials(
                materialRows,
                historicalLayouts,
                pageRows.Count)
            .GroupBy(row => row.MixingDetailId)
            .ToDictionary(
                group => group.Key,
                group => (IReadOnlyList<OrderStatisticsMaterialValue>)group
                    .OrderBy(row => OrderStatisticsMaterialCategories.SortOrder(row.CategoryCode))
                    .ThenBy(row => row.TypePosition)
                    .Select(MapMaterialValue)
                    .ToArray());
    }

    private static async Task<IReadOnlyDictionary<long, IReadOnlyList<OrderStatisticsMaterialValue>>> LoadTotalMaterialsAsync(
        StationOperationsDbContext dbContext,
        IQueryable<BatchQueryRow> filteredBatches,
        IReadOnlyList<TotalQueryRow> pageRows,
        IReadOnlyList<MaterialLayoutEntry> currentMaterialLayout,
        CancellationToken cancellationToken)
    {
        var historyIds = pageRows
            .Select(row => row.MixingHistoryId)
            .Distinct()
            .ToArray();
        if (historyIds.Length == 0)
        {
            return new Dictionary<long, IReadOnlyList<OrderStatisticsMaterialValue>>();
        }

        var materialRows = await (
            from batch in filteredBatches
            join material in dbContext.MixingMaterials.AsNoTracking()
                on batch.MixingDetailId equals material.MixingDetailId
            join slot in dbContext.MaterialSlots.AsNoTracking()
                on material.MaterialSlotId equals slot.MaterialSlotId into slotGroup
            from slot in slotGroup.DefaultIfEmpty()
            join materialType in dbContext.MaterialTypes.AsNoTracking()
                on slot == null ? null : slot.MaterialTypeId equals materialType.MaterialTypeId into typeGroup
            from materialType in typeGroup.DefaultIfEmpty()
            where historyIds.Contains(batch.MixingHistoryId)
            select new MaterialAggregateQueryRow
            {
                MixingDetailId = batch.MixingDetailId,
                MixingHistoryId = batch.MixingHistoryId,
                MaterialSlotId = material.MaterialSlotId,
                SlotNumber = slot == null ? null : slot.SlotNumber,
                MaterialName = slot == null ? null : slot.Name,
                Category = materialType == null ? null : materialType.Name,
                DesignQuantity = (double?)(material.DesignQuantity ?? 0f),
                TQuantity = (double?)(material.TQuantity ?? 0f),
                ActualQuantity = (double?)(material.ActualQuantity ?? 0f)
            }).ToListAsync(cancellationToken);

        var historicalLayouts = await LoadHistoricalMaterialLayoutsAsync(
            dbContext,
            materialRows,
            currentMaterialLayout,
            cancellationToken);
        return NormalizeHistoricalMaterials(
                materialRows,
                historicalLayouts,
                pageRows.Sum(row => row.CompletedBatchCount))
            .GroupBy(row => row.MixingHistoryId)
            .ToDictionary(
                group => group.Key,
                group => AggregateMaterialValuesByCategoryPosition(
                    group,
                    currentMaterialLayout));
    }

    private static IReadOnlyList<OrderStatisticsRow> MapDetailRows(
        IReadOnlyList<BatchQueryRow> pageRows,
        IReadOnlyDictionary<long, IReadOnlyList<OrderStatisticsMaterialValue>> materialValues) =>
        pageRows
            .Select(row => new OrderStatisticsRow(
                row.MixingDetailId,
                row.MixingHistoryId,
                row.BatchNumber,
                row.MixingDate,
                row.StartedAt,
                row.FinishedAt,
                row.CustomerName,
                row.ProjectName,
                row.WorkItemName,
                row.LocationName,
                row.VehiclePlate,
                row.DriverName,
                row.ConcreteGradeName,
                row.Slump,
                row.RequestedVolume,
                ToDouble(row.MixedVolume),
                row.SalesEmployeeCode,
                row.EmployeeName,
                1,
                GetMaterials(materialValues, row.MixingDetailId),
                row.SalesEmployeeName))
            .ToArray();

    private static IReadOnlyList<OrderStatisticsMaterialValue> GetMaterials(
        IReadOnlyDictionary<long, IReadOnlyList<OrderStatisticsMaterialValue>> materialValues,
        long key) =>
        materialValues.TryGetValue(key, out var values)
            ? values
            : Array.Empty<OrderStatisticsMaterialValue>();

    private static IReadOnlyList<OrderStatisticsRow> MapTotalRows(
        IReadOnlyList<TotalQueryRow> pageRows,
        IReadOnlyDictionary<long, IReadOnlyList<OrderStatisticsMaterialValue>> materialValues) =>
        pageRows
            .Select(row => new OrderStatisticsRow(
                null,
                row.MixingHistoryId,
                row.BatchNumber,
                row.MixingDate,
                row.StartedAt,
                row.FinishedAt,
                row.CustomerName,
                row.ProjectName,
                row.WorkItemName,
                row.LocationName,
                row.VehiclePlate,
                row.DriverName,
                row.ConcreteGradeName,
                row.Slump,
                row.RequestedVolume,
                row.MixedVolume,
                row.SalesEmployeeCode,
                row.EmployeeName,
                row.CompletedBatchCount,
                materialValues.TryGetValue(row.MixingHistoryId, out var values)
                    ? values
                    : Array.Empty<OrderStatisticsMaterialValue>(),
                row.SalesEmployeeName))
            .ToArray();

    private static IReadOnlyList<OrderStatisticsMaterialColumn> BuildMaterialColumns(
        IReadOnlyList<MaterialLayoutEntry> materials) =>
        materials
            .OrderBy(material => OrderStatisticsMaterialCategories.SortOrder(material.CategoryCode))
            .ThenBy(material => material.TypePosition)
            .ThenBy(material => material.SlotNumber)
            .Select(material =>
            {
                var name = material.MaterialName ?? string.Empty;
                return new OrderStatisticsMaterialColumn(
                    material.MaterialSlotId,
                    material.SlotNumber,
                    material.MaterialName,
                    material.Category,
                    $"ĐM.{name}",
                    $"T.{name}",
                    name,
                    $"SS.{name}",
                    material.CategoryCode,
                    material.TypePosition);
            })
            .ToArray();

    private static OrderStatisticsMaterialValue MapMaterialValue(
        NormalizedMaterialRow row) =>
        new(
            row.MaterialSlotId,
            row.SlotNumber,
            row.MaterialName,
            row.Category,
            row.DesignQuantity,
            row.TQuantity,
            row.ActualQuantity,
            row.ActualQuantity - row.DesignQuantity,
            row.CategoryCode,
            row.TypePosition);

    private static IReadOnlyList<OrderStatisticsMaterialValue> AggregateMaterialValuesByCategoryPosition(
        IEnumerable<NormalizedMaterialRow> rows,
        IReadOnlyList<MaterialLayoutEntry> currentMaterialLayout) =>
        rows
            .GroupBy(row => new { row.CategoryCode, row.TypePosition })
            .Select(group =>
            {
                var representative = group
                    .OrderByDescending(row => row.MaterialSlotId)
                    .First();
                var layoutEntry = currentMaterialLayout.FirstOrDefault(item =>
                    item.CategoryCode == group.Key.CategoryCode &&
                    item.TypePosition == group.Key.TypePosition);
                var designQuantity = group.Sum(row => row.DesignQuantity);
                var tQuantity = group.Sum(row => row.TQuantity);
                var actualQuantity = group.Sum(row => row.ActualQuantity);
                return new OrderStatisticsMaterialValue(
                    layoutEntry?.MaterialSlotId ?? representative.MaterialSlotId,
                    layoutEntry?.SlotNumber ?? representative.SlotNumber,
                    layoutEntry?.MaterialName ?? representative.MaterialName,
                    OrderStatisticsMaterialCategories.DisplayName(group.Key.CategoryCode),
                    designQuantity,
                    tQuantity,
                    actualQuantity,
                    actualQuantity - designQuantity,
                    group.Key.CategoryCode,
                    group.Key.TypePosition);
            })
            .OrderBy(material => OrderStatisticsMaterialCategories.SortOrder(material.CategoryCode))
            .ThenBy(material => material.TypePosition)
            .ToArray();

    private static IReadOnlyList<OrderStatisticsMaterialValue> BuildSummaryMaterials(
        IReadOnlyList<NormalizedMaterialRow> normalizedMaterials,
        IReadOnlyList<MaterialLayoutEntry> currentMaterialLayout)
    {
        var aggregatedMaterials = AggregateMaterialValuesByCategoryPosition(
            normalizedMaterials,
            currentMaterialLayout);
        var valuesByPosition = aggregatedMaterials.ToDictionary(
            material => (material.CategoryCode, material.TypePosition));
        var layoutByPosition = currentMaterialLayout
            .GroupBy(material => (material.CategoryCode, material.TypePosition))
            .ToDictionary(group => group.Key, group => group.First());
        var maximumTypePosition = Math.Max(
            currentMaterialLayout.Select(material => material.TypePosition).DefaultIfEmpty(0).Max(),
            aggregatedMaterials.Select(material => material.TypePosition).DefaultIfEmpty(0).Max());
        var summaryRowCount = maximumTypePosition;
        var categoryCodes = OrderStatisticsMaterialCategories.StandardCodes
            .Concat(aggregatedMaterials
                .Select(material => material.CategoryCode)
                .Where(categoryCode =>
                    !OrderStatisticsMaterialCategories.StandardCodes.Contains(categoryCode)))
            .Distinct(StringComparer.Ordinal)
            .ToArray();
        var result = new List<OrderStatisticsMaterialValue>(
            checked(summaryRowCount * categoryCodes.Length));

        for (var typePosition = 1; typePosition <= summaryRowCount; typePosition++)
        {
            foreach (var categoryCode in categoryCodes)
            {
                if (valuesByPosition.TryGetValue((categoryCode, typePosition), out var value))
                {
                    result.Add(value);
                    continue;
                }

                layoutByPosition.TryGetValue((categoryCode, typePosition), out var layoutEntry);
                result.Add(new OrderStatisticsMaterialValue(
                    layoutEntry?.MaterialSlotId ?? 0,
                    layoutEntry?.SlotNumber,
                    layoutEntry?.MaterialName,
                    OrderStatisticsMaterialCategories.DisplayName(categoryCode),
                    0d,
                    0d,
                    0d,
                    0d,
                    categoryCode,
                    typePosition));
            }
        }

        return result;
    }

    private static async Task<IReadOnlyList<MaterialLayoutEntry>> LoadCurrentMaterialLayoutAsync(
        StationOperationsDbContext dbContext,
        CancellationToken cancellationToken)
    {
        var rows = await (
            from slot in dbContext.MixDesignMaterialSlots.AsNoTracking()
            join materialType in dbContext.CurrentMaterialTypes.AsNoTracking()
                on slot.MaterialTypeId equals (int?)materialType.MaterialTypeId into typeGroup
            from materialType in typeGroup.DefaultIfEmpty()
            where slot.SlotNumber > 0
            select new
            {
                slot.MaterialSlotId,
                slot.SlotNumber,
                slot.MaterialTypeId,
                slot.Name,
                MaterialTypeName = materialType == null ? null : materialType.Name
            }).ToListAsync(cancellationToken);

        var duplicateSlotNumbers = rows
            .GroupBy(row => row.SlotNumber)
            .Where(group => group.Count() > 1)
            .Select(group => group.Key)
            .OrderBy(slotNumber => slotNumber)
            .ToArray();
        if (duplicateSlotNumbers.Length > 0)
        {
            throw new InvalidOperationException(
                $"Duplicate current material STTCUAVL: {string.Join(", ", duplicateSlotNumbers)}.");
        }

        return rows
            .Select(row => new
            {
                Row = row,
                CategoryCode = OrderStatisticsMaterialCategories.NormalizeCurrent(
                    row.MaterialTypeId,
                    row.MaterialTypeName)
            })
            .GroupBy(item => item.CategoryCode)
            .SelectMany(group => group
                .OrderBy(item => item.Row.SlotNumber)
                .ThenBy(item => item.Row.MaterialSlotId)
                .Select((item, index) => new MaterialLayoutEntry(
                    item.Row.MaterialSlotId,
                    item.Row.SlotNumber,
                    item.Row.Name,
                    OrderStatisticsMaterialCategories.DisplayName(item.CategoryCode),
                    item.CategoryCode,
                    index + 1)))
            .OrderBy(item => OrderStatisticsMaterialCategories.SortOrder(item.CategoryCode))
            .ThenBy(item => item.TypePosition)
            .ToArray();
    }

    private static async Task<IReadOnlyDictionary<long, IReadOnlyList<HistoricalMaterialLayoutEntry>>> LoadHistoricalMaterialLayoutsAsync(
        StationOperationsDbContext dbContext,
        IReadOnlyList<MaterialAggregateQueryRow> materialRows,
        IReadOnlyList<MaterialLayoutEntry> currentMaterialLayout,
        CancellationToken cancellationToken)
    {
        var snapshotKeys = materialRows
            .Select(row => GetHistoricalSnapshotKey(row.MaterialSlotId, row.SlotNumber))
            .Where(snapshotKey => snapshotKey.HasValue)
            .Select(snapshotKey => snapshotKey!.Value)
            .ToHashSet();
        if (snapshotKeys.Count == 0)
        {
            return new Dictionary<long, IReadOnlyList<HistoricalMaterialLayoutEntry>>();
        }

        var maximumSlotNumber = Math.Max(
            currentMaterialLayout.Select(row => row.SlotNumber).DefaultIfEmpty(0).Max(),
            materialRows.Select(row => row.SlotNumber ?? 0).DefaultIfEmpty(0).Max());
        var candidateSlotIds = BuildHistoricalMaterialSlotIdCandidates(
            materialRows,
            maximumSlotNumber);
        var rows = new List<HistoricalMaterialLayoutQueryRow>(candidateSlotIds.Count);
        foreach (var candidateSlotIdChunk in candidateSlotIds.Chunk(HistoricalMaterialSlotIdChunkSize))
        {
            var chunk = candidateSlotIdChunk.ToArray();
            var chunkRows = await (
                from slot in dbContext.MaterialSlots.AsNoTracking()
                join materialType in dbContext.MaterialTypes.AsNoTracking()
                    on slot.MaterialTypeId equals (long?)materialType.MaterialTypeId into typeGroup
                from materialType in typeGroup.DefaultIfEmpty()
                where slot.SlotNumber > 0 && chunk.Contains(slot.MaterialSlotId)
                select new HistoricalMaterialLayoutQueryRow
                {
                    SnapshotKey = slot.MaterialSlotId - (slot.SlotNumber ?? 0),
                    MaterialSlotId = slot.MaterialSlotId,
                    SlotNumber = slot.SlotNumber ?? 0,
                    MaterialName = slot.Name,
                    Category = materialType == null ? null : materialType.Name
                }).ToListAsync(cancellationToken);
            rows.AddRange(chunkRows.Where(row => snapshotKeys.Contains(row.SnapshotKey)));
        }

        return BuildHistoricalMaterialLayouts(rows, currentMaterialLayout);
    }

    internal static IReadOnlyList<long> BuildHistoricalMaterialSlotIdCandidates(
        IReadOnlyList<MaterialAggregateQueryRow> materialRows,
        int maximumSlotNumber)
    {
        if (maximumSlotNumber <= 0)
        {
            return [];
        }

        return materialRows
            .Select(row => GetHistoricalSnapshotKey(row.MaterialSlotId, row.SlotNumber))
            .Where(snapshotKey => snapshotKey.HasValue)
            .Select(snapshotKey => snapshotKey!.Value)
            .Distinct()
            .SelectMany(snapshotKey => Enumerable.Range(1, maximumSlotNumber)
                .Select(slotNumber => checked(snapshotKey + slotNumber)))
            .Distinct()
            .OrderBy(materialSlotId => materialSlotId)
            .ToArray();
    }

    private static IReadOnlyDictionary<long, IReadOnlyList<HistoricalMaterialLayoutEntry>> BuildHistoricalMaterialLayouts(
        IReadOnlyList<HistoricalMaterialLayoutQueryRow> rows,
        IReadOnlyList<MaterialLayoutEntry> currentMaterialLayout)
    {
        var currentLayoutBySlotAndCategory = currentMaterialLayout
            .GroupBy(item => (item.SlotNumber, item.CategoryCode))
            .ToDictionary(group => group.Key, group => group.First());
        var result = new Dictionary<long, IReadOnlyList<HistoricalMaterialLayoutEntry>>();

        foreach (var snapshotGroup in rows.GroupBy(row => row.SnapshotKey))
        {
            result.Add(
                snapshotGroup.Key,
                BuildHistoricalMaterialLayoutSnapshot(
                    snapshotGroup.Key,
                    snapshotGroup,
                    currentLayoutBySlotAndCategory));
        }

        return result;
    }

    private static IReadOnlyList<HistoricalMaterialLayoutEntry> BuildHistoricalMaterialLayoutSnapshot(
        long snapshotKey,
        IEnumerable<HistoricalMaterialLayoutQueryRow> snapshotRows,
        IReadOnlyDictionary<(int SlotNumber, string CategoryCode), MaterialLayoutEntry> currentLayout)
    {
        var rows = snapshotRows.ToArray();
        ValidateHistoricalMaterialLayoutSnapshot(snapshotKey, rows);
        return NormalizeHistoricalMaterialLayoutSnapshot(snapshotKey, rows, currentLayout);
    }

    private static void ValidateHistoricalMaterialLayoutSnapshot(
        long snapshotKey,
        IReadOnlyList<HistoricalMaterialLayoutQueryRow> rows)
    {
        var duplicateSlotNumbers = rows
            .GroupBy(row => row.SlotNumber)
            .Where(group => group.Count() > 1)
            .Select(group => group.Key)
            .OrderBy(slotNumber => slotNumber)
            .ToArray();
        if (duplicateSlotNumbers.Length > 0)
        {
            throw new InvalidOperationException(
                $"Duplicate historical material STTCUAVL in snapshot {snapshotKey}: " +
                $"{string.Join(", ", duplicateSlotNumbers)}.");
        }
    }

    private static IReadOnlyList<HistoricalMaterialLayoutEntry> NormalizeHistoricalMaterialLayoutSnapshot(
        long snapshotKey,
        IEnumerable<HistoricalMaterialLayoutQueryRow> rows,
        IReadOnlyDictionary<(int SlotNumber, string CategoryCode), MaterialLayoutEntry> currentLayout) =>
        rows
            .Select(row =>
            {
                var categoryCode = OrderStatisticsMaterialCategories.NormalizeHistorical(
                    row.Category);
                currentLayout.TryGetValue(
                    (row.SlotNumber, categoryCode),
                    out var currentLayoutEntry);
                var materialName = TrimOrNull(row.MaterialName) ??
                    currentLayoutEntry?.MaterialName ??
                    $"\u0056\u1eadt li\u1ec7u {row.SlotNumber}";
                return new
                {
                    Row = row,
                    MaterialName = materialName,
                    CategoryCode = categoryCode
                };
            })
            .GroupBy(item => item.CategoryCode)
            .SelectMany(group => group
                .OrderBy(item => item.Row.SlotNumber)
                .ThenBy(item => item.Row.MaterialSlotId)
                .Select((item, index) => new HistoricalMaterialLayoutEntry(
                    snapshotKey,
                    item.Row.MaterialSlotId,
                    item.Row.SlotNumber,
                    item.MaterialName,
                    item.CategoryCode,
                    index + 1)))
            .OrderBy(item => OrderStatisticsMaterialCategories.SortOrder(item.CategoryCode))
            .ThenBy(item => item.TypePosition)
            .ToArray();

    private static IReadOnlyList<NormalizedMaterialRow> NormalizeSummaryMaterials(
        IReadOnlyList<MaterialAggregateQueryRow> materialRows,
        IReadOnlyDictionary<long, IReadOnlyList<HistoricalMaterialLayoutEntry>> historicalLayouts)
    {
        var result = new List<NormalizedMaterialRow>(materialRows.Count);
        foreach (var row in materialRows)
        {
            var snapshotKey = GetHistoricalSnapshotKey(row.MaterialSlotId, row.SlotNumber);
            if (!snapshotKey.HasValue ||
                !historicalLayouts.TryGetValue(snapshotKey.Value, out var layout))
            {
                throw new InvalidOperationException(
                    $"Historical material snapshot was not found for MACUAVL {row.MaterialSlotId}.");
            }

            var layoutEntry = layout.FirstOrDefault(item =>
                item.MaterialSlotId == row.MaterialSlotId);
            if (layoutEntry is null)
            {
                throw new InvalidOperationException(
                    $"Historical material MACUAVL {row.MaterialSlotId} does not belong to snapshot {snapshotKey.Value}.");
            }

            result.Add(new NormalizedMaterialRow(
                0,
                0,
                layoutEntry.MaterialSlotId,
                layoutEntry.SlotNumber,
                layoutEntry.MaterialName,
                OrderStatisticsMaterialCategories.DisplayName(layoutEntry.CategoryCode),
                layoutEntry.CategoryCode,
                layoutEntry.TypePosition,
                0d,
                0d,
                row.ActualQuantity ?? 0d));
        }

        return result;
    }

    internal static IReadOnlyList<NormalizedMaterialRow> NormalizeHistoricalMaterials(
        IReadOnlyList<MaterialAggregateQueryRow> materialRows,
        IReadOnlyDictionary<long, IReadOnlyList<HistoricalMaterialLayoutEntry>> historicalLayouts,
        int expectedBatchCount)
    {
        var result = new List<NormalizedMaterialRow>();
        var batchGroups = materialRows
            .Where(row => row.MixingDetailId.HasValue && row.MixingHistoryId.HasValue)
            .GroupBy(row => new
            {
                MixingDetailId = row.MixingDetailId!.Value,
                MixingHistoryId = row.MixingHistoryId!.Value
            })
            .ToArray();
        if (batchGroups.Length != expectedBatchCount)
        {
            throw new InvalidOperationException(
                $"Historical material rows are missing for one or more mixing details. " +
                $"Expected {expectedBatchCount} batches but found {batchGroups.Length}.");
        }

        foreach (var batchGroup in batchGroups)
        {
            result.AddRange(NormalizeHistoricalBatch(
                batchGroup.Key.MixingDetailId,
                batchGroup.Key.MixingHistoryId,
                batchGroup.ToArray(),
                historicalLayouts));
        }

        return result;
    }

    private static IReadOnlyList<NormalizedMaterialRow> NormalizeHistoricalBatch(
        long mixingDetailId,
        long mixingHistoryId,
        IReadOnlyList<MaterialAggregateQueryRow> rows,
        IReadOnlyDictionary<long, IReadOnlyList<HistoricalMaterialLayoutEntry>> historicalLayouts)
    {
        var snapshotKey = ResolveHistoricalSnapshotKey(mixingDetailId, rows);
        if (!historicalLayouts.TryGetValue(snapshotKey, out var layout) || layout.Count == 0)
        {
            throw new InvalidOperationException(
                $"Historical material snapshot {snapshotKey} was not found for mixing detail " +
                $"{mixingDetailId}.");
        }

        var layoutByMaterialSlotId = layout.ToDictionary(item => item.MaterialSlotId);
        var quantitiesByMaterialSlotId = rows
            .GroupBy(row => row.MaterialSlotId)
            .ToDictionary(
                group => group.Key,
                group => new HistoricalMaterialQuantity(
                    group.Sum(row => row.DesignQuantity ?? 0d),
                    group.Sum(row => row.TQuantity ?? 0d),
                    group.Sum(row => row.ActualQuantity ?? 0d)));
        var unknownMaterialSlotIds = quantitiesByMaterialSlotId.Keys
            .Where(materialSlotId => !layoutByMaterialSlotId.ContainsKey(materialSlotId))
            .OrderBy(materialSlotId => materialSlotId)
            .ToArray();
        if (unknownMaterialSlotIds.Length > 0)
        {
            throw new InvalidOperationException(
                $"Historical material MACUAVL does not belong to snapshot {snapshotKey} " +
                $"for mixing detail {mixingDetailId}: " +
                $"{string.Join(", ", unknownMaterialSlotIds)}.");
        }

        return layout
            .Select(layoutEntry =>
            {
                quantitiesByMaterialSlotId.TryGetValue(
                    layoutEntry.MaterialSlotId,
                    out var quantity);
                return new NormalizedMaterialRow(
                    mixingDetailId,
                    mixingHistoryId,
                    layoutEntry.MaterialSlotId,
                    layoutEntry.SlotNumber,
                    layoutEntry.MaterialName,
                    OrderStatisticsMaterialCategories.DisplayName(layoutEntry.CategoryCode),
                    layoutEntry.CategoryCode,
                    layoutEntry.TypePosition,
                    quantity?.DesignQuantity ?? 0d,
                    quantity?.TQuantity ?? 0d,
                    quantity?.ActualQuantity ?? 0d);
            })
            .ToArray();
    }

    private static long ResolveHistoricalSnapshotKey(
        long mixingDetailId,
        IReadOnlyList<MaterialAggregateQueryRow> rows)
    {
        var unresolvedMaterialSlotIds = rows
            .Where(row => !GetHistoricalSnapshotKey(
                row.MaterialSlotId,
                row.SlotNumber).HasValue)
            .Select(row => row.MaterialSlotId)
            .Distinct()
            .OrderBy(materialSlotId => materialSlotId)
            .ToArray();
        if (unresolvedMaterialSlotIds.Length > 0)
        {
            throw new InvalidOperationException(
                $"Cannot resolve historical material snapshot for mixing detail {mixingDetailId}. " +
                $"Missing valid STTCUAVL for MACUAVL: " +
                $"{string.Join(", ", unresolvedMaterialSlotIds)}.");
        }

        var snapshotKeys = rows
            .Select(row => GetHistoricalSnapshotKey(
                row.MaterialSlotId,
                row.SlotNumber)!.Value)
            .Distinct()
            .OrderBy(snapshotKey => snapshotKey)
            .ToArray();
        if (snapshotKeys.Length != 1)
        {
            throw new InvalidOperationException(
                $"Multiple historical material snapshots found for mixing detail {mixingDetailId}: " +
                $"{string.Join(", ", snapshotKeys)}.");
        }

        return snapshotKeys[0];
    }

    private static long? GetHistoricalSnapshotKey(
        long materialSlotId,
        int? slotNumber) =>
        slotNumber is > 0
            ? materialSlotId - slotNumber.Value
            : null;

    private static double? ToDouble(float? value) =>
        value.HasValue ? value.Value : null;

    private static string? TrimOrNull(string? value)
    {
        var trimmed = value?.Trim();
        return string.IsNullOrEmpty(trimmed) ? null : trimmed;
    }

    private string CurrentTraceId =>
        httpContextAccessor.HttpContext?.TraceIdentifier ?? "background";

    private async Task MeasureStageAsync(string stage, Func<Task> operation)
    {
        await MeasureStageAsync(stage, async () =>
        {
            await operation();
            return true;
        });
    }

    private async Task<TResult> MeasureStageAsync<TResult>(
        string stage,
        Func<Task<TResult>> operation)
    {
        var stopwatch = Stopwatch.StartNew();
        try
        {
            var result = await operation();
            stopwatch.Stop();
            if (performanceLoggingOptions.CurrentValue.LogOrderStatisticsStages)
            {
                logger.LogInformation(
                    "Order statistics data stage completed. TraceId={TraceId}, Stage={Stage}, ElapsedMs={ElapsedMs}",
                    CurrentTraceId,
                    stage,
                    stopwatch.ElapsedMilliseconds);
            }
            return result;
        }
        catch (OperationCanceledException)
        {
            stopwatch.Stop();
            logger.LogWarning(
                "Order statistics data stage canceled. TraceId={TraceId}, Stage={Stage}, ElapsedMs={ElapsedMs}",
                CurrentTraceId,
                stage,
                stopwatch.ElapsedMilliseconds);
            throw;
        }
        catch (SqlException exception)
        {
            stopwatch.Stop();
            logger.LogError(
                "Order statistics data stage failed. TraceId={TraceId}, Stage={Stage}, ElapsedMs={ElapsedMs}, ErrorType={ErrorType}, SqlNumber={SqlNumber}, SqlState={SqlState}, SqlClass={SqlClass}",
                CurrentTraceId,
                stage,
                stopwatch.ElapsedMilliseconds,
                exception.GetType().Name,
                exception.Number,
                exception.State,
                exception.Class);
            throw;
        }
        catch (Exception exception)
        {
            stopwatch.Stop();
            logger.LogError(
                "Order statistics data stage failed. TraceId={TraceId}, Stage={Stage}, ElapsedMs={ElapsedMs}, ErrorType={ErrorType}",
                CurrentTraceId,
                stage,
                stopwatch.ElapsedMilliseconds,
                exception.GetType().Name);
            throw;
        }
    }

    private async Task<TResult> ExecuteAsync<TResult>(
        StationDatabaseTarget target,
        CancellationToken cancellationToken,
        Func<StationOperationsDbContext, Task<TResult>> operation)
    {
        try
        {
            var createStopwatch = Stopwatch.StartNew();
            await using var dbContext = dbContextFactory.Create(target);
            createStopwatch.Stop();
            if (performanceLoggingOptions.CurrentValue.LogOrderStatisticsStages)
            {
                logger.LogInformation(
                    "Order statistics DbContext created. TraceId={TraceId}, BranchId={BranchId}, ElapsedMs={ElapsedMs}",
                    CurrentTraceId,
                    target.BranchId,
                    createStopwatch.ElapsedMilliseconds);
            }
            await MeasureStageAsync(
                "OpenStationConnection",
                () => dbContext.Database.OpenConnectionAsync(cancellationToken));
            return await operation(dbContext);
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch (StationDatabaseConfigurationException exception)
        {
            throw new ServiceUnavailableException(
                StationUnavailableMessage,
                exception);
        }
        catch (InvalidOperationException exception)
            when (FindDatabaseException(exception) is not null)
        {
            throw new ServiceUnavailableException(
                StationUnavailableMessage,
                FindDatabaseException(exception));
        }
        catch (DbException exception)
        {
            throw new ServiceUnavailableException(
                StationUnavailableMessage,
                exception);
        }
        catch (TimeoutException exception)
        {
            throw new ServiceUnavailableException(
                StationUnavailableMessage,
                exception);
        }
    }

    private static DbException? FindDatabaseException(Exception exception)
    {
        for (var current = exception; current is not null; current = current.InnerException)
        {
            if (current is DbException databaseException)
            {
                return databaseException;
            }
        }

        return null;
    }

    private sealed class BatchQueryRow
    {
        public long MixingDetailId { get; set; }
        public long MixingHistoryId { get; set; }
        public int? BatchNumber { get; set; }
        public DateTime? MixingDate { get; set; }
        public DateTime? StartedAt { get; set; }
        public DateTime? FinishedAt { get; set; }
        public string? CustomerName { get; set; }
        public string? ProjectName { get; set; }
        public string? WorkItemName { get; set; }
        public string? LocationName { get; set; }
        public string? VehiclePlate { get; set; }
        public string? DriverName { get; set; }
        public string? ConcreteGradeName { get; set; }
        public string? Slump { get; set; }
        public double? RequestedVolume { get; set; }
        public float? MixedVolume { get; set; }
        public int? SalesEmployeeId { get; set; }
        public string? SalesEmployeeCode { get; set; }
        public string? SalesEmployeeName { get; set; }
        public string? EmployeeName { get; set; }
    }

    private sealed class FilteredBatchMetrics
    {
        public int CompletedBatchCount { get; set; }
        public int CompletedOrderCount { get; set; }
        public double TotalMixedVolume { get; set; }
    }

    private sealed class TotalQueryRow
    {
        public long MixingHistoryId { get; set; }
        public int? BatchNumber { get; set; }
        public DateTime? MixingDate { get; set; }
        public DateTime? StartedAt { get; set; }
        public DateTime? FinishedAt { get; set; }
        public string? CustomerName { get; set; }
        public string? ProjectName { get; set; }
        public string? WorkItemName { get; set; }
        public string? LocationName { get; set; }
        public string? VehiclePlate { get; set; }
        public string? DriverName { get; set; }
        public string? ConcreteGradeName { get; set; }
        public string? Slump { get; set; }
        public double? RequestedVolume { get; set; }
        public double? MixedVolume { get; set; }
        public int? SalesEmployeeId { get; set; }
        public string? SalesEmployeeCode { get; set; }
        public string? SalesEmployeeName { get; set; }
        public string? EmployeeName { get; set; }
        public int CompletedBatchCount { get; set; }
    }

    internal sealed class MaterialAggregateQueryRow
    {
        public long? MixingDetailId { get; set; }
        public long? MixingHistoryId { get; set; }
        public long MaterialSlotId { get; set; }
        public int? SlotNumber { get; set; }
        public string? MaterialName { get; set; }
        public string? Category { get; set; }
        public double? DesignQuantity { get; set; }
        public double? TQuantity { get; set; }
        public double? ActualQuantity { get; set; }
    }

    private sealed record MaterialLayoutEntry(
        long MaterialSlotId,
        int SlotNumber,
        string? MaterialName,
        string Category,
        string CategoryCode,
        int TypePosition);

    private sealed class HistoricalMaterialLayoutQueryRow
    {
        public long SnapshotKey { get; set; }
        public long MaterialSlotId { get; set; }
        public int SlotNumber { get; set; }
        public string? MaterialName { get; set; }
        public string? Category { get; set; }
    }

    internal sealed record HistoricalMaterialLayoutEntry(
        long SnapshotKey,
        long MaterialSlotId,
        int SlotNumber,
        string MaterialName,
        string CategoryCode,
        int TypePosition);

    private sealed record HistoricalMaterialQuantity(
        double DesignQuantity,
        double TQuantity,
        double ActualQuantity);

    internal sealed record NormalizedMaterialRow(
        long MixingDetailId,
        long MixingHistoryId,
        long MaterialSlotId,
        int? SlotNumber,
        string? MaterialName,
        string Category,
        string CategoryCode,
        int TypePosition,
        double DesignQuantity,
        double TQuantity,
        double ActualQuantity);
}
