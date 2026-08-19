using System.Data;
using System.Data.Common;
using System.Diagnostics;
using System.Globalization;
using System.Text;
using System.Text.RegularExpressions;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using TTSmart.Api.Common.Diagnostics;
using TTSmart.Api.Data.StationOperations;

namespace TTSmart.Api.Features.WeighStationManagement;

public sealed record WeighStationMaterialValues(
    IReadOnlyDictionary<int, decimal> ByTicketNumber)
{
    public static WeighStationMaterialValues Empty { get; } = new(
        new Dictionary<int, decimal>());
}

public interface IWeighStationMaterialValueDataSource
{
    Task<WeighStationMaterialValues> CalculateAsync(
        StationDatabaseTarget scaleTarget,
        IReadOnlyList<StationDatabaseTarget> mixingTargets,
        IReadOnlyList<WeighStationRow> scaleRows,
        CancellationToken cancellationToken);
}

public sealed class SqlWeighStationMaterialValueDataSource(
    IStationOperationsDbContextFactory dbContextFactory,
    ILogger<SqlWeighStationMaterialValueDataSource> logger,
    IHttpContextAccessor httpContextAccessor,
    IOptionsMonitor<PerformanceLoggingOptions> performanceLoggingOptions)
    : IWeighStationMaterialValueDataSource
{
    public async Task<WeighStationMaterialValues> CalculateAsync(
        StationDatabaseTarget scaleTarget,
        IReadOnlyList<StationDatabaseTarget> mixingTargets,
        IReadOnlyList<WeighStationRow> scaleRows,
        CancellationToken cancellationToken)
    {
        var eligibleRows = scaleRows
            .Where(IsValidScaleRow)
            .OrderBy(row => GetLoadedTime(row))
            .ToArray();
        if (eligibleRows.Length == 0)
        {
            return WeighStationMaterialValues.Empty;
        }

        var result = new Dictionary<int, decimal>();
        var mixTargets = BuildMixingTargets(scaleTarget, mixingTargets, eligibleRows);
        var targets = DistinctTargets([scaleTarget, .. mixTargets]);

        // Web ưu tiên giá xe nhập đã lưu/sync trong dữ liệu cân.
        foreach (var target in targets)
        {
            try
            {
                var pricedRows = await MeasureStageAsync(
                    "LoadPricedInputRows",
                    () => LoadPricedInputRowsAsync(target, eligibleRows, cancellationToken));
                MatchInputPrices(eligibleRows, pricedRows, result);
            }
            catch (OperationCanceledException)
            {
                throw;
            }
            catch (Exception exception) when (IsDatabaseFailure(exception))
            {
                logger.LogWarning(
                    "A weigh-station material price source is unavailable. ErrorType={ErrorType}",
                    exception.GetType().Name);
            }
        }

        var concreteRows = eligibleRows
            .Where(row => !result.ContainsKey(row.TicketNumber) && IsConcreteOutput(row.GoodsName))
            .ToArray();
        if (concreteRows.Length == 0)
        {
            return new WeighStationMaterialValues(result);
        }

        var usedTickets = new HashSet<int>();
        foreach (var target in mixTargets)
        {
            try
            {
                var targetRows = FilterRowsForMixTarget(target, concreteRows);
                if (targetRows.Count == 0)
                {
                    continue;
                }
                var mixes = await MeasureStageAsync(
                    "LoadRelatedMixes",
                    () => LoadMixesAsync(target, targetRows, cancellationToken));
                if (mixes.Count == 0)
                {
                    continue;
                }
                var prices = await MeasureStageAsync(
                    "LoadUnitPriceHistory",
                    () => LoadUnitPricesAsync(
                        target,
                        mixes.Min(item => item.CompletedAt),
                        mixes.Max(item => item.CompletedAt),
                        cancellationToken));
                if (prices.Count == 0)
                {
                    continue;
                }

                var pricedMixes = mixes.ToDictionary(
                    mix => mix.Key,
                    mix => CalculateMixValue(mix, prices),
                    StringComparer.OrdinalIgnoreCase);
                var candidates = (
                    from mix in mixes
                    let mixPlate = ResolvePlateKey(mix.VehiclePlate)
                    where mixPlate.Length > 0
                    from scale in targetRows
                    where !result.ContainsKey(scale.TicketNumber) &&
                          ResolvePlateKey(scale.VehiclePlate) == mixPlate
                    let loadedAt = GetLoadedTime(scale)!.Value
                    let signedMinutes = (loadedAt - mix.CompletedAt).TotalMinutes
                    where signedMinutes >= -15d && signedMinutes <= 30d
                    select new MatchCandidate(
                        scale,
                        mix,
                        pricedMixes[mix.Key],
                        Math.Abs(signedMinutes),
                        signedMinutes))
                    .OrderBy(item => item.AbsoluteMinutes)
                    .ThenBy(item => item.SignedMinutes >= 0 ? 0 : 1)
                    .ThenBy(item => item.Mix.CompletedAt)
                    .ThenBy(item => item.Mix.Key, StringComparer.OrdinalIgnoreCase)
                    .ToArray();

                var usedMixes = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
                foreach (var candidate in candidates)
                {
                    if (result.ContainsKey(candidate.Scale.TicketNumber) ||
                        usedTickets.Contains(candidate.Scale.TicketNumber) ||
                        !usedMixes.Add(candidate.Mix.Key))
                    {
                        continue;
                    }

                    usedTickets.Add(candidate.Scale.TicketNumber);
                    if (candidate.Value > 0)
                    {
                        result[candidate.Scale.TicketNumber] = RoundMoney(candidate.Value);
                    }
                }
            }
            catch (OperationCanceledException)
            {
                throw;
            }
            catch (Exception exception) when (IsDatabaseFailure(exception))
            {
                logger.LogWarning(
                    "A mixing-station material value source is unavailable. ErrorType={ErrorType}",
                    exception.GetType().Name);
            }
        }

        return new WeighStationMaterialValues(result);
    }

    private async Task<IReadOnlyList<PricedInputRow>> LoadPricedInputRowsAsync(
        StationDatabaseTarget target,
        IReadOnlyList<WeighStationRow> scaleRows,
        CancellationToken cancellationToken)
    {
        var inputRows = scaleRows.Where(row => IsInput(row.WeighingType)).ToArray();
        if (inputRows.Length == 0)
        {
            return [];
        }

        await using var dbContext = dbContextFactory.Create(target);
        var connection = dbContext.Database.GetDbConnection();
        await dbContext.Database.OpenConnectionAsync(cancellationToken);
        var columns = await GetColumnsAsync(connection, "TC_XEVAORA", cancellationToken);
        if (!RequiredInputPriceColumns.All(columns.Contains))
        {
            return [];
        }

        var minTime = inputRows.Min(row => row.SecondWeighedAt!.Value).AddMinutes(-10);
        var maxTime = inputRows.Max(row => row.SecondWeighedAt!.Value).AddMinutes(10);
        await using var command = connection.CreateCommand();
        command.CommandText = """
            SELECT STT, BIENXE, THOIGIANCANLAN2,
                   CAST(ABS(ISNULL(KHOILUONGCANLAN1,0)-ISNULL(KHOILUONGCANLAN2,0)) AS decimal(28,6)),
                   CAST(ISNULL(Price,0) AS decimal(28,6)),
                   CAST(ISNULL(Total_Money,0) AS decimal(28,6))
            FROM dbo.TC_XEVAORA
            WHERE LOAICAN = N'Nhập hàng'
              AND THOIGIANCANLAN2 >= @MinTime
              AND THOIGIANCANLAN2 <= @MaxTime
              AND (ISNULL(Total_Money,0) > 0 OR ISNULL(Price,0) > 0)
            """;
        AddParameter(command, "@MinTime", minTime);
        AddParameter(command, "@MaxTime", maxTime);
        var result = new List<PricedInputRow>();
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            result.Add(new PricedInputRow(
                GetInt32(reader, 0),
                GetString(reader, 1),
                GetDateTime(reader, 2),
                GetDecimal(reader, 3),
                GetDecimal(reader, 4),
                GetDecimal(reader, 5)));
        }
        return result;
    }

    private static void MatchInputPrices(
        IReadOnlyList<WeighStationRow> scaleRows,
        IReadOnlyList<PricedInputRow> pricedRows,
        IDictionary<int, decimal> result)
    {
        foreach (var scale in scaleRows.Where(row => IsInput(row.WeighingType)))
        {
            if (result.ContainsKey(scale.TicketNumber) || !scale.SecondWeighedAt.HasValue)
            {
                continue;
            }
            var match = pricedRows
                .Where(row => IsSamePlate(scale.VehiclePlate, row.VehiclePlate))
                .Select(row => new
                {
                    Row = row,
                    SameTicket = row.TicketNumber == scale.TicketNumber,
                    Minutes = Math.Abs((GetLoadedTime(scale)!.Value - row.WeighedAt).TotalMinutes),
                    WeightDifference = row.WeightKg <= 0 || !scale.GoodsWeight.HasValue
                        ? decimal.MaxValue
                        : Math.Abs(scale.GoodsWeight.Value - row.WeightKg) / row.WeightKg * 100m
                })
                .Where(item => (item.SameTicket || item.Minutes <= 10d) && item.WeightDifference <= 1m)
                .OrderByDescending(item => item.SameTicket)
                .ThenBy(item => item.Minutes)
                .ThenBy(item => item.WeightDifference)
                .FirstOrDefault();
            if (match is null)
            {
                continue;
            }
            var value = match.Row.UnitPriceKg > 0
                ? match.Row.UnitPriceKg * match.Row.WeightKg
                : match.Row.TotalMoney;
            if (value > 0)
            {
                result[scale.TicketNumber] = RoundMoney(value);
            }
        }
    }

    private async Task<IReadOnlyList<MixTicket>> LoadMixesAsync(
        StationDatabaseTarget target,
        IReadOnlyList<WeighStationRow> scaleRows,
        CancellationToken cancellationToken)
    {
        await using var dbContext = dbContextFactory.Create(target);
        var connection = dbContext.Database.GetDbConnection();
        await dbContext.Database.OpenConnectionAsync(cancellationToken);
        if (!await HasTablesAsync(connection, MixTables, cancellationToken))
        {
            return [];
        }

        var minTime = scaleRows.Min(row => GetLoadedTime(row)!.Value).AddMinutes(-240);
        var maxTime = scaleRows.Max(row => GetLoadedTime(row)!.Value).AddMinutes(240);
        await using var command = connection.CreateCommand();
        command.CommandText = """
            SELECT CAST(A.MALSTRON AS nvarchar(100)), A.BIENSO, A.GIOXONG,
                   ISNULL(COALESCE(CV_DIRECT.MACUAVL,CV_STT.MACUAVL,CT.MACUAVL),0),
                   ISNULL(CAST(COALESCE(CV_DIRECT.TENCUAVL,CV_STT.TENCUAVL) AS nvarchar(255)),CAST(CT.MACUAVL AS nvarchar(50))),
                   ISNULL(CAST(COALESCE(LV_DIRECT.TENLOAIVL,LV_STT.TENLOAIVL) AS nvarchar(50)),N''),
                   CAST(SUM(ISNULL(CT.SOLUONG,0)+ISNULL(CT.SOLUONGT,0)) AS decimal(28,6))
            FROM dbo.LSTRON A
            INNER JOIN dbo.LSCHITIETMETRON B ON B.MALSTRON=A.MALSTRON
            INNER JOIN dbo.LSCHITIETMETRONLSCUAVL CT ON CT.MACHITIETMETRON=B.MACHITIETMETRON
            LEFT JOIN dbo.CUAVL CV_DIRECT ON CV_DIRECT.MACUAVL=CT.MACUAVL
            LEFT JOIN dbo.LSCUAVL LSCV ON LSCV.MACUAVL=CT.MACUAVL
            LEFT JOIN dbo.CUAVL CV_STT ON CV_STT.STTCUAVL=LSCV.STTCUAVL
            LEFT JOIN dbo.LOAIVL LV_DIRECT ON LV_DIRECT.MALOAIVL=CV_DIRECT.MALOAIVL
            LEFT JOIN dbo.LOAIVL LV_STT ON LV_STT.MALOAIVL=CV_STT.MALOAIVL
            WHERE A.GIOXONG>=@MinTime AND A.GIOXONG<=@MaxTime
            GROUP BY A.MALSTRON,A.BIENSO,A.GIOXONG,
                     COALESCE(CV_DIRECT.MACUAVL,CV_STT.MACUAVL,CT.MACUAVL),
                     COALESCE(CV_DIRECT.TENCUAVL,CV_STT.TENCUAVL),CT.MACUAVL,
                     COALESCE(LV_DIRECT.TENLOAIVL,LV_STT.TENLOAIVL)
            HAVING SUM(ISNULL(CT.SOLUONG,0)+ISNULL(CT.SOLUONGT,0))>0
            """;
        AddParameter(command, "@MinTime", minTime);
        AddParameter(command, "@MaxTime", maxTime);
        var map = new Dictionary<string, MixTicket>(StringComparer.OrdinalIgnoreCase);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            var key = GetString(reader, 0);
            if (key.Length == 0)
            {
                continue;
            }
            if (!map.TryGetValue(key, out var mix))
            {
                mix = new MixTicket(key, GetString(reader, 1), GetDateTime(reader, 2), []);
                map.Add(key, mix);
            }
            mix.Details.Add(new MixMaterial(
                GetInt32(reader, 3),
                GetString(reader, 4),
                GetString(reader, 5),
                GetDecimal(reader, 6)));
        }
        return map.Values.ToArray();
    }

    private async Task<IReadOnlyList<UnitPrice>> LoadUnitPricesAsync(
        StationDatabaseTarget target,
        DateTime fromDate,
        DateTime toDate,
        CancellationToken cancellationToken)
    {
        await using var dbContext = dbContextFactory.Create(target);
        var connection = dbContext.Database.GetDbConnection();
        await dbContext.Database.OpenConnectionAsync(cancellationToken);
        var scaleColumns = await GetColumnsAsync(connection, "TC_XEVAORA", cancellationToken);
        var hasScale = await HasTablesAsync(connection, ["TC_XEVAORA", "CUAVL"], cancellationToken) &&
            RequiredInputPriceColumns.All(scaleColumns.Contains) &&
            scaleColumns.Contains("MACUAVL");
        var hasOrders = await HasTablesAsync(connection, ["OrderItemTram", "OrderTram", "CUAVL"], cancellationToken);
        if (!hasScale && !hasOrders)
        {
            return [];
        }

        var statements = new List<string>();
        if (hasScale)
        {
            statements.Add("""
                SELECT A.MACUAVL,B.TENCUAVL,A.THOIGIANCANLAN2,
                       CAST(CASE WHEN ABS(ISNULL(A.KHOILUONGCANLAN1,0)-ISNULL(A.KHOILUONGCANLAN2,0))>0
                            THEN CASE WHEN ISNULL(A.Price,0)>0 THEN A.Price
                                      WHEN ISNULL(A.Total_Money,0)>0 THEN A.Total_Money/ABS(ISNULL(A.KHOILUONGCANLAN1,0)-ISNULL(A.KHOILUONGCANLAN2,0))
                                      ELSE 0 END ELSE 0 END AS decimal(28,6))
                FROM dbo.TC_XEVAORA A INNER JOIN dbo.CUAVL B ON A.MACUAVL=B.MACUAVL
                WHERE A.LOAICAN=N'Nhập hàng' AND A.THOIGIANCANLAN2<=@ToDate
                  AND (ISNULL(A.Total_Money,0)>0 OR ISNULL(A.Price,0)>0)
                """);
        }
        if (hasOrders)
        {
            statements.Add("""
                SELECT A.MACUAVL,A.TENCUAVL,B.CreatedAt,
                       CAST(CASE WHEN ISNULL(C.Quantity,0)>0
                            THEN CASE WHEN ISNULL(C.Price,0)>0 THEN C.Price
                                      WHEN ISNULL(C.Total_Money,0)>0 THEN C.Total_Money/ISNULL(C.Quantity,0)
                                      ELSE 0 END ELSE 0 END AS decimal(28,6))
                FROM dbo.CUAVL A
                INNER JOIN dbo.OrderItemTram C ON A.MACUAVL=C.CodeCuaVL
                INNER JOIN dbo.OrderTram B ON B.OrderTramId=C.OrderTramId
                WHERE B.TypePhieu=1 AND B.CreatedAt<=@ToDate
                """);
        }
        await using var command = connection.CreateCommand();
        command.CommandText = BuildUnitPriceQuery(statements);
        AddParameter(command, "@FromDate", fromDate);
        AddParameter(command, "@ToDate", toDate);
        var result = new List<UnitPrice>();
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            var value = GetDecimal(reader, 3);
            if (value <= 0)
            {
                continue;
            }
            var name = GetString(reader, 1);
            result.Add(new UnitPrice(
                GetInt32(reader, 0),
                Normalize(name),
                DetectMaterialGroup(null, name),
                GetDateTime(reader, 2),
                value));
        }
        return result;
    }

    private static string BuildUnitPriceQuery(IReadOnlyList<string> statements)
    {
        var historyQuery = string.Join("\nUNION ALL\n", statements);
        return $"""
            WITH PriceHistory(MaterialCode, MaterialName, PriceDate, UnitPrice) AS
            (
                {historyQuery}
            ),
            BeforeRange AS
            (
                SELECT MaterialCode, MaterialName, PriceDate, UnitPrice,
                       ROW_NUMBER() OVER (
                           PARTITION BY MaterialCode
                           ORDER BY PriceDate DESC) AS RowNumber
                FROM PriceHistory
                WHERE PriceDate < @FromDate
            )
            SELECT MaterialCode, MaterialName, PriceDate, UnitPrice
            FROM PriceHistory
            WHERE PriceDate >= @FromDate AND PriceDate <= @ToDate
            UNION ALL
            SELECT MaterialCode, MaterialName, PriceDate, UnitPrice
            FROM BeforeRange
            WHERE RowNumber = 1
            """;
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
                    "Weigh station material-value stage slow. TraceId={TraceId}, Stage={Stage}, ElapsedMs={ElapsedMs}",
                    httpContextAccessor.HttpContext?.TraceIdentifier ?? "background",
                    stage,
                    stopwatch.ElapsedMilliseconds);
            }
            else if (settings.LogWeighStationStages)
            {
                logger.LogInformation(
                    "Weigh station material-value stage completed. TraceId={TraceId}, Stage={Stage}, ElapsedMs={ElapsedMs}",
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
                "Weigh station material-value stage canceled. TraceId={TraceId}, Stage={Stage}, ElapsedMs={ElapsedMs}",
                httpContextAccessor.HttpContext?.TraceIdentifier ?? "background",
                stage,
                stopwatch.ElapsedMilliseconds);
            throw;
        }
    }

    private static decimal CalculateMixValue(MixTicket mix, IReadOnlyList<UnitPrice> prices)
    {
        decimal total = 0;
        foreach (var detail in mix.Details.Where(item => IsPriceMaterial(item.Category, item.Name)))
        {
            var price = FindPrice(prices, detail, mix.CompletedAt);
            if (price is not null)
            {
                total += detail.QuantityKg * price.ValuePerKg;
            }
        }
        return RoundMoney(total);
    }

    private static UnitPrice? FindPrice(
        IReadOnlyList<UnitPrice> prices,
        MixMaterial detail,
        DateTime mixTime)
    {
        var key = Normalize(detail.Name);
        var group = DetectMaterialGroup(detail.Category, detail.Name);
        IEnumerable<UnitPrice>[] candidates =
        [
            detail.MaterialCode > 0 ? prices.Where(item => item.MaterialCode == detail.MaterialCode) : [],
            key.Length > 0 ? prices.Where(item => item.NameKey == key) : [],
            group is not ("" or "NUOC") ? prices.Where(item => item.MaterialGroup == group) : []
        ];
        foreach (var source in candidates)
        {
            var before = source.Where(item => item.Date <= mixTime)
                .OrderByDescending(item => item.Date)
                .FirstOrDefault();
            if (before is not null)
            {
                return before;
            }
        }
        foreach (var source in candidates)
        {
            var nearest = source
                .OrderBy(item => Math.Abs((item.Date - mixTime).TotalMinutes))
                .ThenByDescending(item => item.Date <= mixTime)
                .FirstOrDefault();
            if (nearest is not null)
            {
                return nearest;
            }
        }
        return null;
    }

    private IReadOnlyList<StationDatabaseTarget> DistinctTargets(
        IEnumerable<StationDatabaseTarget> targets)
    {
        var result = new List<StationDatabaseTarget>();
        var databases = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var target in targets)
        {
            string database;
            try
            {
                database = dbContextFactory.ResolveDatabaseName(target);
            }
            catch (StationDatabaseConfigurationException)
            {
                continue;
            }
            if (databases.Add(database))
            {
                result.Add(target);
            }
        }
        return result;
    }

    private IReadOnlyList<StationDatabaseTarget> BuildMixingTargets(
        StationDatabaseTarget scaleTarget,
        IReadOnlyList<StationDatabaseTarget> configuredTargets,
        IReadOnlyList<WeighStationRow> rows)
    {
        var candidates = new List<StationDatabaseTarget>();
        var syntheticId = -1;
        void AddExact(string? databaseName)
        {
            var value = ExtractInitialCatalog(databaseName);
            if (DatabaseNamePattern.IsMatch(value))
            {
                candidates.Add(new StationDatabaseTarget(syntheticId--, value, null));
            }
        }

        foreach (var row in rows)
        {
            AddExact(row.MixingStationConnection);
        }

        candidates.AddRange(configuredTargets.Where(target => target.BranchId < 0));

        var scaleDatabase = dbContextFactory.ResolveDatabaseName(scaleTarget);
        const string suffix = "_tc_online";
        if (scaleDatabase.EndsWith(suffix, StringComparison.OrdinalIgnoreCase))
        {
            var baseName = scaleDatabase[..^suffix.Length];
            AddExact(baseName + "_online");
            var withoutTc = Regex.Replace(baseName, "tc", string.Empty, RegexOptions.IgnoreCase);
            if (!string.Equals(withoutTc, baseName, StringComparison.OrdinalIgnoreCase))
            {
                AddExact(withoutTc + "_online");
            }
        }
        candidates.AddRange(configuredTargets.Where(target => target.BranchId >= 0));
        return DistinctTargets(candidates);
    }

    private IReadOnlyList<WeighStationRow> FilterRowsForMixTarget(
        StationDatabaseTarget target,
        IReadOnlyList<WeighStationRow> rows)
    {
        var targetDatabase = dbContextFactory.ResolveDatabaseName(target);
        return rows.Where(row =>
        {
            var explicitDatabase = ExtractInitialCatalog(row.MixingStationConnection);
            return !DatabaseNamePattern.IsMatch(explicitDatabase) ||
                   string.Equals(explicitDatabase, targetDatabase, StringComparison.OrdinalIgnoreCase);
        }).ToArray();
    }

    private static string ExtractInitialCatalog(string? connectionText)
    {
        var text = connectionText?.Trim() ?? string.Empty;
        if (!text.Contains(';') && !text.Contains('='))
        {
            return text;
        }
        foreach (var part in text.Split(';', StringSplitOptions.RemoveEmptyEntries))
        {
            var tokens = part.Split('=', 2);
            if (tokens.Length == 2 &&
                (tokens[0].Trim().Equals("INITIAL CATALOG", StringComparison.OrdinalIgnoreCase) ||
                 tokens[0].Trim().Equals("DATABASE", StringComparison.OrdinalIgnoreCase)))
            {
                return tokens[1].Trim();
            }
        }
        return string.Empty;
    }

    private static readonly string[] RequiredInputPriceColumns =
    [
        "STT", "BIENXE", "THOIGIANCANLAN2", "KHOILUONGCANLAN1",
        "KHOILUONGCANLAN2", "LOAICAN", "Price", "Total_Money"
    ];
    private static readonly string[] MixTables =
    ["LSTRON", "LSCHITIETMETRON", "LSCHITIETMETRONLSCUAVL", "LSCUAVL", "CUAVL", "LOAIVL"];
    private static readonly Regex DatabaseNamePattern = new(
        "^[A-Za-z0-9_]{1,128}$",
        RegexOptions.CultureInvariant | RegexOptions.Compiled);

    private static async Task<HashSet<string>> GetColumnsAsync(
        DbConnection connection,
        string table,
        CancellationToken cancellationToken)
    {
        await using var command = connection.CreateCommand();
        command.CommandText = """
            SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS
            WHERE TABLE_SCHEMA=N'dbo' AND TABLE_NAME=@Table
            """;
        AddParameter(command, "@Table", table);
        var result = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            result.Add(GetString(reader, 0));
        }
        return result;
    }

    private static async Task<bool> HasTablesAsync(
        DbConnection connection,
        IReadOnlyList<string> tables,
        CancellationToken cancellationToken)
    {
        foreach (var table in tables)
        {
            await using var command = connection.CreateCommand();
            command.CommandText = """
                SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES
                WHERE TABLE_SCHEMA=N'dbo' AND TABLE_NAME=@Table
                """;
            AddParameter(command, "@Table", table);
            if (Convert.ToInt32(await command.ExecuteScalarAsync(cancellationToken), CultureInfo.InvariantCulture) == 0)
            {
                return false;
            }
        }
        return true;
    }

    private static void AddParameter(DbCommand command, string name, object value)
    {
        var parameter = command.CreateParameter();
        parameter.ParameterName = name;
        parameter.Value = value;
        command.Parameters.Add(parameter);
    }

    private static bool IsValidScaleRow(WeighStationRow row) =>
        row.FirstWeight is > 0 && row.SecondWeight is > 0 &&
        row.GoodsWeight is > 0 && GetLoadedTime(row).HasValue;

    private static DateTime? GetLoadedTime(WeighStationRow row) =>
        row.FirstWeight >= row.SecondWeight ? row.FirstWeighedAt : row.SecondWeighedAt;

    private static bool IsInput(string? value)
    {
        var code = Normalize(value);
        return code is "NHAPHANG" or "NHAP";
    }

    private static bool IsConcreteOutput(string? value)
    {
        var code = Normalize(value);
        return code.Contains("MAC", StringComparison.Ordinal) ||
               code.Contains("BETONG", StringComparison.Ordinal) ||
               code.StartsWith("BT", StringComparison.Ordinal);
    }

    private static bool IsSamePlate(string? first, string? second)
    {
        var a = Normalize(first);
        var b = Normalize(second);
        return a.Length > 0 && b.Length > 0 &&
               (a == b || ResolvePlateKey(a) == ResolvePlateKey(b));
    }

    private static string ResolvePlateKey(string? value)
    {
        var plate = Normalize(value);
        var key = plate.Length <= 5 ? plate : plate[^5..];
        return key switch
        {
            "36252" => "36552",
            "1026" => "F1026",
            _ => key
        };
    }

    private static bool IsPriceMaterial(string? category, string? name) =>
        DetectMaterialGroup(category, name) is "CAT" or "DA" or "XI" or "PHUGIA";

    private static string DetectMaterialGroup(string? category, string? name)
    {
        var type = Normalize(category);
        var text = Normalize(name);
        if (type is "NUOC" or "WATER" || text.Contains("NUOC") || text.Contains("WATER")) return "NUOC";
        if (text.Contains("TROBAY") || text.Contains("FLYASH")) return "PHUGIA";
        if (type is "PHUGIA" or "ADDITIVE") return "PHUGIA";
        if (type == "CAT") return "CAT";
        if (type == "DA") return "DA";
        if (type is "XI" or "XIMANG" or "CEMENT") return "XI";
        if (text.Contains("PHUGIA") || text.Contains("ADDITIVE") || text.Contains("SP") ||
            text.Contains("BIFI") || text.Contains("SILKROAD") || text.Contains("WPA")) return "PHUGIA";
        if (text.Contains("XIMANG") || text.Contains("XYMANG") || text.Contains("CEMENT") || text.StartsWith("XI")) return "XI";
        if (text.Contains("CAT")) return "CAT";
        if (text == "DA" || text.StartsWith("DA") || text.Contains("DAMAT") || text.Contains("DA1X2")) return "DA";
        return string.Empty;
    }

    private static string Normalize(string? value)
    {
        var text = (value ?? string.Empty).Trim().ToUpperInvariant().Replace('Đ', 'D');
        var builder = new StringBuilder(text.Length);
        foreach (var character in text.Normalize(NormalizationForm.FormD))
        {
            if (CharUnicodeInfo.GetUnicodeCategory(character) == UnicodeCategory.NonSpacingMark)
            {
                continue;
            }
            if (char.IsLetterOrDigit(character))
            {
                builder.Append(character);
            }
        }
        return builder.ToString().Normalize(NormalizationForm.FormC);
    }

    private static bool IsDatabaseFailure(Exception exception)
    {
        for (var current = exception; current is not null; current = current.InnerException)
        {
            if (current is DbException or TimeoutException or StationDatabaseConfigurationException)
            {
                return true;
            }
        }
        return false;
    }

    private static int GetInt32(DbDataReader reader, int ordinal) =>
        reader.IsDBNull(ordinal) ? 0 : Convert.ToInt32(reader.GetValue(ordinal), CultureInfo.InvariantCulture);
    private static decimal GetDecimal(DbDataReader reader, int ordinal) =>
        reader.IsDBNull(ordinal) ? 0 : Convert.ToDecimal(reader.GetValue(ordinal), CultureInfo.InvariantCulture);
    private static DateTime GetDateTime(DbDataReader reader, int ordinal) =>
        reader.IsDBNull(ordinal) ? DateTime.MinValue : Convert.ToDateTime(reader.GetValue(ordinal), CultureInfo.InvariantCulture);
    private static string GetString(DbDataReader reader, int ordinal) =>
        reader.IsDBNull(ordinal) ? string.Empty : Convert.ToString(reader.GetValue(ordinal), CultureInfo.InvariantCulture)?.Trim() ?? string.Empty;
    private static decimal RoundMoney(decimal value) => Math.Round(value, 0, MidpointRounding.AwayFromZero);

    private sealed record PricedInputRow(
        int TicketNumber,
        string VehiclePlate,
        DateTime WeighedAt,
        decimal WeightKg,
        decimal UnitPriceKg,
        decimal TotalMoney);
    private sealed record MixMaterial(int MaterialCode, string Name, string Category, decimal QuantityKg);
    private sealed record MixTicket(string Key, string VehiclePlate, DateTime CompletedAt, List<MixMaterial> Details);
    private sealed record UnitPrice(int MaterialCode, string NameKey, string MaterialGroup, DateTime Date, decimal ValuePerKg);
    private sealed record MatchCandidate(
        WeighStationRow Scale,
        MixTicket Mix,
        decimal Value,
        double AbsoluteMinutes,
        double SignedMinutes);
}
