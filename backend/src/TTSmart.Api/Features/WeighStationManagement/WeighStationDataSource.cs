using System.Data.Common;
using System.Diagnostics;
using Microsoft.EntityFrameworkCore;
using TTSmart.Api.Common.Exceptions;
using TTSmart.Api.Data.StationOperations;

namespace TTSmart.Api.Features.WeighStationManagement;

public sealed record WeighStationFilter(
    DateTime FromInclusive,
    DateTime ToExclusive,
    string? VehiclePlate = null,
    string? GoodsName = null,
    string? OperatorName = null,
    string? UnitName = null,
    string? WeighingType = null);

public sealed record WeighStationFilterOptions(
    IReadOnlyList<string> VehiclePlates,
    IReadOnlyList<string> GoodsNames,
    IReadOnlyList<string> OperatorNames,
    IReadOnlyList<string> UnitNames,
    IReadOnlyList<string> WeighingTypes);

public sealed record WeighStationRow(
    int TicketNumber,
    Guid Id,
    string? TicketCode,
    string? VehiclePlate,
    string? DriverName,
    string? SealNumber,
    double? FirstWeight,
    double? SecondWeight,
    decimal? GoodsWeight,
    float? ConversionFactor,
    string? ConversionUnit,
    string? UnitName,
    string? GoodsName,
    string? WeighingType,
    string? FirstOperatorName,
    string? SecondOperatorName,
    DateTime? FirstWeighedAt,
    DateTime? SecondWeighedAt,
    DateTime? LastUpdatedAt);

public sealed record WeighStationPage(IReadOnlyList<WeighStationRow> Items, int TotalCount);

public sealed record WeighStationSummaryAggregate(
    string? GoodsName,
    string? WeighingType,
    decimal GoodsWeight,
    float? ConversionFactor,
    string? ConversionUnit);

public interface IWeighStationDataSource
{
    Task<WeighStationFilterOptions> GetFilterOptionsAsync(
        StationDatabaseTarget target,
        WeighStationStage? stage,
        WeighStationFilter filter,
        CancellationToken cancellationToken);

    Task<WeighStationPage> SearchAsync(
        StationDatabaseTarget target,
        WeighStationStage? stage,
        WeighStationFilter filter,
        int pageOffset,
        CancellationToken cancellationToken);

    Task<IReadOnlyList<WeighStationRow>> SearchAllAsync(
        StationDatabaseTarget target,
        WeighStationStage? stage,
        WeighStationFilter filter,
        CancellationToken cancellationToken);

    Task<IReadOnlyList<WeighStationSummaryAggregate>> GetSummaryAsync(
        StationDatabaseTarget target,
        WeighStationStage? stage,
        WeighStationFilter filter,
        CancellationToken cancellationToken);
}

public sealed class SqlWeighStationDataSource(
    IStationOperationsDbContextFactory dbContextFactory,
    ILogger<SqlWeighStationDataSource> logger,
    IHttpContextAccessor httpContextAccessor) : IWeighStationDataSource
{
    private const string StationUnavailableMessage = "Dữ liệu trạm cân chưa sẵn sàng";

    public Task<WeighStationFilterOptions> GetFilterOptionsAsync(
        StationDatabaseTarget target,
        WeighStationStage? stage,
        WeighStationFilter filter,
        CancellationToken cancellationToken) =>
        ExecuteAsync("LoadFilters", target, async dbContext =>
        {
            var rows = await ApplyDateRange(BuildQuery(dbContext, stage), filter)
                .Select(row => new
                {
                    row.VehiclePlate,
                    row.GoodsName,
                    OperatorName = row.EffectiveOperatorName,
                    row.UnitName,
                    row.WeighingType
                })
                .ToListAsync(cancellationToken);

            return new WeighStationFilterOptions(
                NormalizeOptions(rows.Select(row => row.VehiclePlate)),
                NormalizeOptions(rows.Select(row => row.GoodsName)),
                NormalizeOptions(rows.Select(row => row.OperatorName)),
                NormalizeOptions(rows.Select(row => row.UnitName)),
                NormalizeOptions(rows.Select(row => row.WeighingType)));
        }, cancellationToken);

    public Task<WeighStationPage> SearchAsync(
        StationDatabaseTarget target,
        WeighStationStage? stage,
        WeighStationFilter filter,
        int pageOffset,
        CancellationToken cancellationToken) =>
        ExecuteAsync("Search", target, async dbContext =>
        {
            var filteredQuery = BuildFilteredQuery(dbContext, stage, filter);
            var totalCount = await filteredQuery.CountAsync(cancellationToken);
            var items = await ProjectRows(OrderRows(filteredQuery))
                .Skip(pageOffset)
                .Take(WeighStationContractDefaults.PageSize)
                .ToListAsync(cancellationToken);
            return new WeighStationPage(items, totalCount);
        }, cancellationToken);

    public Task<IReadOnlyList<WeighStationRow>> SearchAllAsync(
        StationDatabaseTarget target,
        WeighStationStage? stage,
        WeighStationFilter filter,
        CancellationToken cancellationToken) =>
        ExecuteAsync<IReadOnlyList<WeighStationRow>>("SearchAll", target, async dbContext =>
            await ProjectRows(OrderRows(BuildFilteredQuery(dbContext, stage, filter)))
                .ToListAsync(cancellationToken), cancellationToken);

    public Task<IReadOnlyList<WeighStationSummaryAggregate>> GetSummaryAsync(
        StationDatabaseTarget target,
        WeighStationStage? stage,
        WeighStationFilter filter,
        CancellationToken cancellationToken) =>
        ExecuteAsync<IReadOnlyList<WeighStationSummaryAggregate>>(
            "LoadSummary",
            target,
            async dbContext => await BuildFilteredQuery(dbContext, stage, filter)
                .GroupBy(row => new
                {
                    row.GoodsName,
                    row.WeighingType,
                    row.ConversionFactor,
                    row.ConversionUnit
                })
                .Select(group => new WeighStationSummaryAggregate(
                    group.Key.GoodsName,
                    group.Key.WeighingType,
                    group.Sum(row => row.GoodsWeight ?? 0m),
                    group.Key.ConversionFactor,
                    group.Key.ConversionUnit))
                .ToListAsync(cancellationToken),
            cancellationToken);

    private static IQueryable<WeighStationQueryRow> BuildFilteredQuery(
        StationOperationsDbContext dbContext,
        WeighStationStage? stage,
        WeighStationFilter filter) =>
        ApplyFilters(ApplyDateRange(BuildQuery(dbContext, stage), filter), filter);

    private static IQueryable<WeighStationQueryRow> BuildQuery(
        StationOperationsDbContext dbContext,
        WeighStationStage? stage)
    {
        var pendingQuery = dbContext.PendingWeighTickets.AsNoTracking()
            .Select(row => new WeighStationQueryRow
            {
                TicketNumber = row.Sequence,
                Id = row.Id,
                TicketCode = row.TicketCode,
                VehiclePlate = row.VehiclePlate,
                DriverName = row.DriverName,
                SealNumber = row.SealNumber,
                FirstWeight = row.FirstWeight,
                SecondWeight = row.SecondWeight,
                GoodsWeight = row.GoodsWeight,
                ConversionFactor = row.ConversionFactor,
                ConversionUnit = row.ConversionUnit,
                UnitName = row.UnitName,
                GoodsName = row.GoodsName,
                WeighingType = row.WeighingType,
                FirstOperatorName = row.FirstOperatorName,
                SecondOperatorName = row.SecondOperatorName,
                FirstWeighedAt = row.FirstWeighedAt,
                SecondWeighedAt = row.SecondWeighedAt,
                LastUpdatedAt = row.LastUpdatedAt,
                EffectiveOperatorName = row.FirstOperatorName,
                EffectiveWeighedAt = row.FirstWeighedAt
            });
        var completedQuery = dbContext.CompletedWeighTickets.AsNoTracking()
            .Select(row => new WeighStationQueryRow
            {
                TicketNumber = row.Sequence,
                Id = row.Id,
                TicketCode = row.TicketCode,
                VehiclePlate = row.VehiclePlate,
                DriverName = row.DriverName,
                SealNumber = row.SealNumber,
                FirstWeight = row.FirstWeight,
                SecondWeight = row.SecondWeight,
                GoodsWeight = row.GoodsWeight,
                ConversionFactor = row.ConversionFactor,
                ConversionUnit = row.ConversionUnit,
                UnitName = row.UnitName,
                GoodsName = row.GoodsName,
                WeighingType = row.WeighingType,
                FirstOperatorName = row.FirstOperatorName,
                SecondOperatorName = row.SecondOperatorName,
                FirstWeighedAt = row.FirstWeighedAt,
                SecondWeighedAt = row.SecondWeighedAt,
                LastUpdatedAt = row.LastUpdatedAt,
                EffectiveOperatorName = row.SecondOperatorName,
                EffectiveWeighedAt = row.SecondWeighedAt
            });

        return stage switch
        {
            WeighStationStage.First => pendingQuery,
            WeighStationStage.Second => completedQuery,
            null => pendingQuery.Concat(completedQuery),
            _ => throw new ArgumentOutOfRangeException(nameof(stage))
        };
    }

    private static IOrderedQueryable<WeighStationQueryRow> OrderRows(
        IQueryable<WeighStationQueryRow> query) =>
        query.OrderByDescending(row => row.EffectiveWeighedAt)
            .ThenByDescending(row => row.TicketNumber);

    private static IQueryable<WeighStationRow> ProjectRows(
        IQueryable<WeighStationQueryRow> query) =>
        query.Select(row => new WeighStationRow(
            row.TicketNumber,
            row.Id,
            row.TicketCode,
            row.VehiclePlate,
            row.DriverName,
            row.SealNumber,
            row.FirstWeight,
            row.SecondWeight,
            row.GoodsWeight,
            row.ConversionFactor,
            row.ConversionUnit,
            row.UnitName,
            row.GoodsName,
            row.WeighingType,
            row.FirstOperatorName,
            row.SecondOperatorName,
            row.FirstWeighedAt,
            row.SecondWeighedAt,
            row.LastUpdatedAt));

    private static IQueryable<WeighStationQueryRow> ApplyDateRange(
        IQueryable<WeighStationQueryRow> query,
        WeighStationFilter filter) =>
        query.Where(row => row.EffectiveWeighedAt >= filter.FromInclusive &&
            row.EffectiveWeighedAt < filter.ToExclusive);

    private static IQueryable<WeighStationQueryRow> ApplyFilters(
        IQueryable<WeighStationQueryRow> query,
        WeighStationFilter filter)
    {
        if (filter.VehiclePlate is not null)
        {
            query = query.Where(row => row.VehiclePlate != null &&
                row.VehiclePlate.Trim() == filter.VehiclePlate);
        }
        if (filter.GoodsName is not null)
        {
            query = query.Where(row => row.GoodsName != null &&
                row.GoodsName.Trim() == filter.GoodsName);
        }
        if (filter.OperatorName is not null)
        {
            query = query.Where(row => row.EffectiveOperatorName != null &&
                row.EffectiveOperatorName.Trim() == filter.OperatorName);
        }
        if (filter.UnitName is not null)
        {
            query = query.Where(row => row.UnitName != null &&
                row.UnitName.Trim() == filter.UnitName);
        }
        if (filter.WeighingType is not null)
        {
            query = query.Where(row => row.WeighingType != null &&
                row.WeighingType.Trim() == filter.WeighingType);
        }
        return query;
    }

    private async Task<TResult> ExecuteAsync<TResult>(
        string stage,
        StationDatabaseTarget target,
        Func<StationOperationsDbContext, Task<TResult>> operation,
        CancellationToken cancellationToken)
    {
        var stopwatch = Stopwatch.StartNew();
        try
        {
            await using var dbContext = dbContextFactory.Create(target);
            return await operation(dbContext);
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch (Exception exception) when (
            exception is StationDatabaseConfigurationException or TimeoutException ||
            FindDatabaseException(exception) is not null)
        {
            logger.LogError(
                exception,
                "Weigh station data stage failed. TraceId={TraceId}, Stage={Stage}, ElapsedMs={ElapsedMs}, ErrorType={ErrorType}",
                httpContextAccessor.HttpContext?.TraceIdentifier ?? "background",
                stage,
                stopwatch.ElapsedMilliseconds,
                exception.GetType().Name);
            throw new ServiceUnavailableException(StationUnavailableMessage, exception);
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

    private static IReadOnlyList<string> NormalizeOptions(IEnumerable<string?> values) =>
        values.Select(value => value?.Trim())
            .Where(value => !string.IsNullOrEmpty(value))
            .Select(value => value!)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .OrderBy(value => value, StringComparer.OrdinalIgnoreCase)
            .ToArray();

    private sealed class WeighStationQueryRow
    {
        public int TicketNumber { get; init; }
        public Guid Id { get; init; }
        public string? TicketCode { get; init; }
        public string? VehiclePlate { get; init; }
        public string? DriverName { get; init; }
        public string? SealNumber { get; init; }
        public double? FirstWeight { get; init; }
        public double? SecondWeight { get; init; }
        public decimal? GoodsWeight { get; init; }
        public float? ConversionFactor { get; init; }
        public string? ConversionUnit { get; init; }
        public string? UnitName { get; init; }
        public string? GoodsName { get; init; }
        public string? WeighingType { get; init; }
        public string? FirstOperatorName { get; init; }
        public string? SecondOperatorName { get; init; }
        public DateTime? FirstWeighedAt { get; init; }
        public DateTime? SecondWeighedAt { get; init; }
        public DateTime? LastUpdatedAt { get; init; }
        public string? EffectiveOperatorName { get; init; }
        public DateTime? EffectiveWeighedAt { get; init; }
    }
}
