using System.Data;
using System.Data.Common;
using System.Diagnostics;
using System.Globalization;
using System.Text;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using TTSmart.Api.Common.Diagnostics;
using TTSmart.Api.Common.Exceptions;
using TTSmart.Api.Data.StationOperations;

namespace TTSmart.Api.Features.WeighStationManagement;

public sealed record WeighStationFilter(
    DateTime FromInclusive,
    DateTime ToInclusive,
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
    DateTime? LastUpdatedAt,
    string? MaterialCode = null,
    string? MaterialCategory = null,
    byte? VehicleExitStatus = null,
    string? MixingStationConnection = null);

public sealed record WeighStationPage(IReadOnlyList<WeighStationRow> Items, int TotalCount);

public sealed record WeighStationSummaryAggregate(
    string? GoodsName,
    string? WeighingType,
    decimal GoodsWeight,
    float? ConversionFactor,
    string? ConversionUnit,
    int TicketCount = 0,
    string? MaterialCode = null,
    string? MaterialCategory = null);

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
    IHttpContextAccessor httpContextAccessor,
    IOptionsMonitor<PerformanceLoggingOptions> performanceLoggingOptions)
    : IWeighStationDataSource
{
    private const string StationUnavailableMessage = "Dữ liệu trạm cân chưa sẵn sàng";

    public Task<WeighStationFilterOptions> GetFilterOptionsAsync(
        StationDatabaseTarget target,
        WeighStationStage? stage,
        WeighStationFilter filter,
        CancellationToken cancellationToken) =>
        ExecuteAsync("LoadFilters", target, async dbContext =>
        {
            var rows = await MeasureStageAsync(
                "LoadFilterRows",
                () => ApplyDateRange(dbContext, BuildQuery(dbContext, stage), filter)
                    .Select(row => new
                    {
                        row.VehiclePlate,
                        row.GoodsName,
                        OperatorName = row.FirstOperatorName,
                        row.UnitName,
                        row.WeighingType
                    })
                    .ToListAsync(cancellationToken));

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
            var totalCount = await MeasureStageAsync(
                "CountFilteredTickets",
                () => filteredQuery.CountAsync(cancellationToken));
            var rows = await MeasureStageAsync(
                "LoadDetailPage",
                () => ProjectRows(OrderRows(filteredQuery))
                    .Skip(pageOffset)
                    .Take(WeighStationContractDefaults.PageSize)
                    .ToListAsync(cancellationToken));
            var catalog = await MeasureStageAsync(
                "LoadMaterialCatalog",
                () => LoadMaterialCatalogAsync(dbContext, cancellationToken));
            return new WeighStationPage(EnrichRows(rows, catalog), totalCount);
        }, cancellationToken);

    public Task<IReadOnlyList<WeighStationRow>> SearchAllAsync(
        StationDatabaseTarget target,
        WeighStationStage? stage,
        WeighStationFilter filter,
        CancellationToken cancellationToken) =>
        ExecuteAsync<IReadOnlyList<WeighStationRow>>("SearchAll", target, async dbContext =>
        {
            var rows = await MeasureStageAsync(
                "LoadAllFilteredTickets",
                () => ProjectRows(OrderRows(BuildFilteredQuery(dbContext, stage, filter)))
                    .ToListAsync(cancellationToken));
            var catalog = await MeasureStageAsync(
                "LoadMaterialCatalogForAllRows",
                () => LoadMaterialCatalogAsync(dbContext, cancellationToken));
            return EnrichRows(rows, catalog);
        }, cancellationToken);

    public Task<IReadOnlyList<WeighStationSummaryAggregate>> GetSummaryAsync(
        StationDatabaseTarget target,
        WeighStationStage? stage,
        WeighStationFilter filter,
        CancellationToken cancellationToken) =>
        ExecuteAsync<IReadOnlyList<WeighStationSummaryAggregate>>(
            "LoadSummary",
            target,
            async dbContext =>
            {
                var aggregates = await MeasureStageAsync(
                    "LoadSummaryAggregates",
                    () => BuildFilteredQuery(dbContext, stage, filter)
                        .GroupBy(row => new
                        {
                            row.GoodsName,
                            row.WeighingType,
                            row.MaterialCode,
                            row.ConversionFactor,
                            row.ConversionUnit
                        })
                        .Select(group => new WeighStationSummaryAggregate(
                            group.Key.GoodsName,
                            group.Key.WeighingType,
                            group.Sum(row => row.GoodsWeight ?? 0m),
                            group.Key.ConversionFactor,
                            group.Key.ConversionUnit,
                            group.Count(),
                            group.Key.MaterialCode))
                        .ToListAsync(cancellationToken));
                var catalog = await MeasureStageAsync(
                    "LoadMaterialCatalogForSummary",
                    () => LoadMaterialCatalogAsync(dbContext, cancellationToken));
                return EnrichAggregates(aggregates, catalog);
            },
            cancellationToken);

    private static IQueryable<WeighStationQueryRow> BuildFilteredQuery(
        StationOperationsDbContext dbContext,
        WeighStationStage? stage,
        WeighStationFilter filter) =>
        ApplyFilters(
            ApplyDateRange(dbContext, BuildQuery(dbContext, stage), filter),
            filter);

    private static IQueryable<WeighStationQueryRow> BuildQuery(
        StationOperationsDbContext dbContext,
        WeighStationStage? stage)
    {
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
                GoodsWeight = (decimal)Math.Abs(
                    (row.FirstWeight ?? 0d) - (row.SecondWeight ?? 0d)),
                ConversionFactor = row.ConversionFactor,
                ConversionUnit = row.ConversionUnit,
                UnitName = row.UnitName,
                GoodsName = row.GoodsName,
                MaterialCode = row.MaterialCode,
                WeighingType = row.WeighingType,
                MixingStationConnection = row.MixingStationConnection,
                VehicleExitStatus = row.VehicleExitStatus,
                FirstOperatorName = row.FirstOperatorName,
                SecondOperatorName = row.SecondOperatorName,
                FirstWeighedAt = row.FirstWeighedAt,
                SecondWeighedAt = row.SecondWeighedAt,
                LastUpdatedAt = row.LastUpdatedAt
            });

        return stage switch
        {
            WeighStationStage.First => completedQuery.Where(row =>
                row.VehicleExitStatus == null || row.VehicleExitStatus == false),
            WeighStationStage.Second => completedQuery.Where(row =>
                row.VehicleExitStatus == true),
            null => completedQuery,
            _ => throw new ArgumentOutOfRangeException(nameof(stage))
        };
    }

    private static IOrderedQueryable<WeighStationQueryRow> OrderRows(
        IQueryable<WeighStationQueryRow> query) =>
        query.OrderBy(row => row.TicketNumber);

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
            row.LastUpdatedAt,
            row.MaterialCode,
            null,
            row.VehicleExitStatus == null
                ? null
                : row.VehicleExitStatus == true
                    ? (byte?)1
                    : (byte?)0,
            row.MixingStationConnection));

    private static IQueryable<WeighStationQueryRow> ApplyDateRange(
        StationOperationsDbContext dbContext,
        IQueryable<WeighStationQueryRow> query,
        WeighStationFilter filter)
    {
        var tickets = dbContext.CompletedWeighTickets.AsNoTracking();
        var ticketNumbers = tickets
            .Where(row => row.LastUpdatedAt >= filter.FromInclusive &&
                row.LastUpdatedAt <= filter.ToInclusive)
            .Select(row => row.Sequence)
            .Union(tickets
                .Where(row => row.FirstWeighedAt >= filter.FromInclusive &&
                    row.FirstWeighedAt <= filter.ToInclusive)
                .Select(row => row.Sequence))
            .Union(tickets
                .Where(row => row.SecondWeighedAt >= filter.FromInclusive &&
                    row.SecondWeighedAt <= filter.ToInclusive)
                .Select(row => row.Sequence));
        return query.Where(row => ticketNumbers.Contains(row.TicketNumber));
    }

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
            query = query.Where(row => row.FirstOperatorName != null &&
                row.FirstOperatorName.Trim() == filter.OperatorName);
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

    private async Task<IReadOnlyList<MaterialDefinition>> LoadMaterialCatalogAsync(
        StationOperationsDbContext dbContext,
        CancellationToken cancellationToken)
    {
        try
        {
            var connection = dbContext.Database.GetDbConnection();
            await dbContext.Database.OpenConnectionAsync(cancellationToken);
            await using var columnsCommand = connection.CreateCommand();
            columnsCommand.CommandText = """
                SELECT COLUMN_NAME
                FROM INFORMATION_SCHEMA.COLUMNS
                WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'TC_VATLIEU'
                """;
            var columns = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            await using (var reader = await columnsCommand.ExecuteReaderAsync(cancellationToken))
            {
                while (await reader.ReadAsync(cancellationToken))
                {
                    columns.Add(reader.GetString(0));
                }
            }
            if (!columns.Contains("MAVATLIEU") || !columns.Contains("TENVATLIEU"))
            {
                return [];
            }

            var categoryExpression = columns.Contains("LOAIVL")
                ? "ISNULL(CAST([LOAIVL] AS nvarchar(50)),N'')"
                : "CAST(N'' AS nvarchar(50))";
            var unitExpression = columns.Contains("DONVITINH")
                ? "ISNULL(CAST([DONVITINH] AS nvarchar(50)),N'')"
                : "CAST(N'' AS nvarchar(50))";
            var factorExpression = columns.Contains("HESOQUYDOI")
                ? "CAST(ISNULL([HESOQUYDOI],0) AS real)"
                : "CAST(0 AS real)";
            await using var dataCommand = connection.CreateCommand();
            dataCommand.CommandText = $"""
                SELECT CAST([MAVATLIEU] AS int),
                       ISNULL(CAST([TENVATLIEU] AS nvarchar(max)),N''),
                       {categoryExpression},
                       {unitExpression},
                       {factorExpression}
                FROM [dbo].[TC_VATLIEU]
                """;
            var result = new List<MaterialDefinition>();
            await using var dataReader = await dataCommand.ExecuteReaderAsync(cancellationToken);
            while (await dataReader.ReadAsync(cancellationToken))
            {
                result.Add(new MaterialDefinition(
                    Convert.ToInt32(dataReader.GetValue(0), CultureInfo.InvariantCulture),
                    dataReader.IsDBNull(1) ? null : dataReader.GetString(1),
                    dataReader.IsDBNull(2) ? null : dataReader.GetString(2),
                    dataReader.IsDBNull(3) ? null : dataReader.GetString(3),
                    dataReader.IsDBNull(4)
                        ? null
                        : Convert.ToSingle(dataReader.GetValue(4), CultureInfo.InvariantCulture)));
            }
            return result;
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch (Exception exception) when (FindDatabaseException(exception) is not null)
        {
            logger.LogWarning(
                "Scale material catalog is unavailable; ticket values will use embedded conversion configuration. ErrorType={ErrorType}",
                exception.GetType().Name);
            return [];
        }
    }

    private static IReadOnlyList<WeighStationRow> EnrichRows(
        IReadOnlyList<WeighStationRow> rows,
        IReadOnlyList<MaterialDefinition> catalog) =>
        rows.Select(row =>
        {
            var definition = FindMaterialDefinition(catalog, row.MaterialCode, row.GoodsName);
            return row with
            {
                ConversionFactor = ResolveConversionFactor(row.ConversionFactor, definition),
                ConversionUnit = ResolveConversionUnit(row.ConversionUnit, definition),
                MaterialCategory = definition?.Category
            };
        }).ToArray();

    private static IReadOnlyList<WeighStationSummaryAggregate> EnrichAggregates(
        IReadOnlyList<WeighStationSummaryAggregate> aggregates,
        IReadOnlyList<MaterialDefinition> catalog) =>
        aggregates.Select(row =>
        {
            var definition = FindMaterialDefinition(catalog, row.MaterialCode, row.GoodsName);
            return row with
            {
                ConversionFactor = ResolveConversionFactor(row.ConversionFactor, definition),
                ConversionUnit = ResolveConversionUnit(row.ConversionUnit, definition),
                MaterialCategory = definition?.Category
            };
        }).ToArray();

    private static MaterialDefinition? FindMaterialDefinition(
        IReadOnlyList<MaterialDefinition> catalog,
        string? materialCode,
        string? materialName)
    {
        if (int.TryParse(materialCode, NumberStyles.Integer, CultureInfo.InvariantCulture, out var code))
        {
            var byCode = catalog.FirstOrDefault(item => item.Code == code);
            if (byCode is not null)
            {
                return byCode;
            }
        }

        var normalizedName = NormalizeForComparison(materialName);
        return normalizedName.Length == 0
            ? null
            : catalog.FirstOrDefault(item =>
                NormalizeForComparison(item.Name) == normalizedName);
    }

    private static float? ResolveConversionFactor(
        float? ticketValue,
        MaterialDefinition? definition) =>
        ticketValue.HasValue && float.IsFinite(ticketValue.Value) && ticketValue.Value > 0
            ? ticketValue
            : definition?.ConversionFactor;

    private static string? ResolveConversionUnit(
        string? ticketValue,
        MaterialDefinition? definition) =>
        string.IsNullOrWhiteSpace(ticketValue)
            ? definition?.ConversionUnit
            : ticketValue;

    private static string NormalizeForComparison(string? value)
    {
        var text = (value ?? string.Empty).Trim().ToUpperInvariant().Replace('Đ', 'D');
        var builder = new StringBuilder(text.Length);
        foreach (var character in text.Normalize(NormalizationForm.FormD))
        {
            if (CharUnicodeInfo.GetUnicodeCategory(character) != UnicodeCategory.NonSpacingMark)
            {
                builder.Append(character);
            }
        }
        return builder.ToString().Normalize(NormalizationForm.FormC);
    }

    private async Task<T> MeasureStageAsync<T>(string stage, Func<Task<T>> operation)
    {
        var stopwatch = Stopwatch.StartNew();
        try
        {
            var result = await operation();
            stopwatch.Stop();
            var settings = performanceLoggingOptions.CurrentValue;
            if (stopwatch.ElapsedMilliseconds >= settings.SlowDatabaseCommandThresholdMilliseconds)
            {
                logger.LogWarning(
                    "Weigh station stage slow. TraceId={TraceId}, Stage={Stage}, ElapsedMs={ElapsedMs}",
                    httpContextAccessor.HttpContext?.TraceIdentifier ?? "background",
                    stage,
                    stopwatch.ElapsedMilliseconds);
            }
            else if (settings.LogWeighStationStages)
            {
                logger.LogInformation(
                    "Weigh station stage completed. TraceId={TraceId}, Stage={Stage}, ElapsedMs={ElapsedMs}",
                    httpContextAccessor.HttpContext?.TraceIdentifier ?? "background",
                    stage,
                    stopwatch.ElapsedMilliseconds);
            }
            return result;
        }
        catch (OperationCanceledException)
        {
            stopwatch.Stop();
            logger.LogWarning(
                "Weigh station stage canceled. TraceId={TraceId}, Stage={Stage}, ElapsedMs={ElapsedMs}",
                httpContextAccessor.HttpContext?.TraceIdentifier ?? "background",
                stage,
                stopwatch.ElapsedMilliseconds);
            throw;
        }
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
        public string? MaterialCode { get; init; }
        public string? WeighingType { get; init; }
        public string? MixingStationConnection { get; init; }
        public bool? VehicleExitStatus { get; init; }
        public string? FirstOperatorName { get; init; }
        public string? SecondOperatorName { get; init; }
        public DateTime? FirstWeighedAt { get; init; }
        public DateTime? SecondWeighedAt { get; init; }
        public DateTime? LastUpdatedAt { get; init; }
    }

    private sealed record MaterialDefinition(
        int Code,
        string? Name,
        string? Category,
        string? ConversionUnit,
        float? ConversionFactor);
}
