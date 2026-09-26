using System.Data;
using System.Data.Common;
using System.Diagnostics;
using System.Globalization;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using TTSmart.Api.Common.Exceptions;
using TTSmart.Api.Data.StationOperations;

namespace TTSmart.Api.Features.MaterialReporting;

public sealed record MaterialDefinition(
    int Code,
    int SlotNumber,
    int MaterialTypeId,
    string Name);

public sealed record MaterialImportLot(
    string SourceId,
    long SourceSequence,
    int? MaterialCode,
    string? MaterialName,
    DateTime OccurredAt,
    decimal QuantityKg,
    decimal UnitPriceVndPerKg,
    decimal? ConversionVolume = null,
    string? ConversionUnit = null,
    decimal? ConversionCoefficientKgPerUnit = null,
    bool IsQuantityOnlyAdjustment = false);

public sealed record MaterialIssueEvent(
    string SourceId,
    long SourceSequence,
    int? MaterialCode,
    int? SlotNumber,
    string? MaterialName,
    DateTime OccurredAt,
    decimal QuantityKg,
    string? TransactionId = null,
    bool IsQuantityOnlyAdjustment = false);

public sealed record MaterialTransactionData(
    string Id,
    DateTime OccurredAt,
    string Type,
    string? Name,
    IReadOnlyList<MaterialTransactionDetailData> Details);

public sealed record MaterialTransactionDetailData(
    int? MaterialCode,
    string? MaterialName,
    decimal QuantityKg,
    decimal UnitPriceVndPerKg,
    decimal? ConversionVolume,
    string? ConversionUnit,
    decimal? ConversionCoefficientKgPerUnit,
    string? IssueSourceId = null);

public sealed record MaterialReportSnapshot(
    IReadOnlyList<MaterialDefinition> Materials,
    IReadOnlyList<MaterialImportLot> Imports,
    IReadOnlyList<MaterialIssueEvent> Issues,
    IReadOnlyList<MaterialTransactionData> Transactions,
    IReadOnlyList<string> Warnings);

public interface IMaterialReportDataSource
{
    Task<MaterialReportSnapshot> LoadAsync(
        StationDatabaseTarget target,
        DateTime fromLocal,
        DateTime toLocal,
        CancellationToken cancellationToken);
}

public sealed class MaterialReportingOptions
{
    public const string SectionName = "MaterialReporting";

    public int CommandTimeoutSeconds { get; init; } = 120;

    /// <summary>
    /// Keep the mixing consumption of the stations (see MaterialMixingLedgerStore) instead of
    /// adding up the whole history on the station database for every report.
    /// </summary>
    public bool UseMixingLedger { get; init; } = true;

    /// <summary>Folder of the ledger files; by default App_Data/material-ledger of the API.</summary>
    public string? LedgerDirectory { get; init; }

    /// <summary>Mixing detail rows read per query while a ledger is built or checked.</summary>
    public int LedgerChunkDetailRows { get; init; } = 10_000;

    /// <summary>Pause between two chunk queries, so the station server keeps serving others.</summary>
    public int LedgerChunkPauseMilliseconds { get; init; } = 200;

    /// <summary>The mixes of the last days stay open: read again on every refresh.</summary>
    public int LedgerOpenDays { get; init; } = 3;

    /// <summary>A report reads the new mixes of a station at most this often.</summary>
    public int LedgerRefreshSeconds { get; init; } = 15;

    /// <summary>How long a report waits for a first build before answering "preparing".</summary>
    public int LedgerPrepareWaitSeconds { get; init; } = 8;

    /// <summary>The sealed ranges are read again after this many hours (edits of old mixes).</summary>
    public int LedgerVerifyHours { get; init; } = 24;

    /// <summary>Ledger entries kept in memory for all stations (about 16 bytes each).</summary>
    public long LedgerMaxEntriesInMemory { get; init; } = 8_000_000;
}

internal sealed class SqlMaterialReportDataSource(
    IStationOperationsDbContextFactory dbContextFactory,
    IMaterialMixingLedgerStore ledgerStore,
    IOptions<MaterialReportingOptions> options,
    ILogger<SqlMaterialReportDataSource> logger) : IMaterialReportDataSource
{
    private const string UnavailableMessage = "Dữ liệu Quản lý vật liệu của trạm chưa sẵn sàng.";

    public async Task<MaterialReportSnapshot> LoadAsync(
        StationDatabaseTarget target,
        DateTime fromLocal,
        DateTime toLocal,
        CancellationToken cancellationToken)
    {
        try
        {
            // First, so a station whose history is still being read answers at once.
            var ledger = options.Value.UseMixingLedger
                ? await GetLedgerAsync(target, cancellationToken)
                : null;

            await using var dbContext = dbContextFactory.Create(target);
            var materials = await dbContext.MixDesignMaterialSlots.AsNoTracking()
                .OrderBy(item => item.SlotNumber)
                .ThenBy(item => item.MaterialSlotId)
                .Select(item => new MaterialDefinition(
                    item.MaterialSlotId,
                    item.SlotNumber,
                    item.MaterialTypeId ?? 0,
                    item.Name ?? string.Empty))
                .ToListAsync(cancellationToken);

            var imports = new List<MaterialImportLot>();
            var issues = new List<MaterialIssueEvent>();
            var transactions = new List<MaterialTransactionData>();
            var warnings = new List<string>();
            var connection = dbContext.Database.GetDbConnection();
            await dbContext.Database.OpenConnectionAsync(cancellationToken);

            await MeasureStageAsync(
                "ScaleEvents",
                target.BranchId,
                () => LoadScaleEventsAsync(
                    connection,
                    fromLocal,
                    toLocal,
                    imports,
                    issues,
                    transactions,
                    warnings,
                    options.Value.CommandTimeoutSeconds,
                    cancellationToken));
            await MeasureStageAsync(
                "ManualEvents",
                target.BranchId,
                () => LoadManualEventsAsync(
                    connection,
                    fromLocal,
                    toLocal,
                    imports,
                    issues,
                    transactions,
                    warnings,
                    options.Value.CommandTimeoutSeconds,
                    cancellationToken));
            // Must stay last: the mixing consumption is added up between the lots and issues
            // loaded above, so FIFO needs exactly those (see MaterialMixingBuckets).
            await MeasureStageAsync(
                "MixingIssues",
                target.BranchId,
                () => ledger is null
                    ? LoadMixingIssuesAsync(
                        connection,
                        materials,
                        imports,
                        issues,
                        fromLocal,
                        toLocal,
                        warnings,
                        options.Value.CommandTimeoutSeconds,
                        cancellationToken)
                    : AddMixingIssues(ledger, materials, imports, issues, fromLocal, toLocal, warnings));

            return new MaterialReportSnapshot(
                materials,
                imports,
                issues,
                transactions.OrderByDescending(item => item.OccurredAt).ThenByDescending(item => item.Id).ToArray(),
                warnings.Distinct(StringComparer.Ordinal).ToArray());
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch (ServiceUnavailableException)
        {
            throw;
        }
        catch (DbException exception)
        {
            logger.LogWarning(exception, "Material report station query failed for branch {BranchId}", target.BranchId);
            throw new ServiceUnavailableException(UnavailableMessage, exception);
        }
        catch (TimeoutException exception)
        {
            logger.LogWarning(exception, "Material report station query timed out for branch {BranchId}", target.BranchId);
            throw new ServiceUnavailableException(UnavailableMessage, exception);
        }
        catch (InvalidOperationException exception)
        {
            logger.LogWarning(exception, "Material report schema is incompatible for branch {BranchId}", target.BranchId);
            throw new ServiceUnavailableException(UnavailableMessage, exception);
        }
    }

    private async Task<MaterialMixingLedger?> GetLedgerAsync(
        StationDatabaseTarget target,
        CancellationToken cancellationToken)
    {
        var stopwatch = Stopwatch.StartNew();
        var ledger = await ledgerStore.GetAsync(target, cancellationToken);
        logger.LogInformation(
            "Material report stage completed. BranchId={BranchId}, Stage=MixingLedger, ElapsedMs={ElapsedMs:F1}",
            target.BranchId,
            stopwatch.Elapsed.TotalMilliseconds);
        return ledger;
    }

    /// <summary>The mixing issues from the ledger: the rows of the bucketed query.</summary>
    private static Task AddMixingIssues(
        MaterialMixingLedger ledger,
        IReadOnlyList<MaterialDefinition> materials,
        IReadOnlyCollection<MaterialImportLot> imports,
        ICollection<MaterialIssueEvent> issues,
        DateTime fromLocal,
        DateTime toLocal,
        ICollection<string> warnings)
    {
        if (!ledger.HasMixingTables)
        {
            warnings.Add("Trạm chưa có đủ dữ liệu tiêu hao vật liệu khi trộn.");
            return Task.CompletedTask;
        }

        var boundaries = MaterialMixingBuckets.BuildBoundaries(imports, issues.ToArray(), fromLocal, toLocal);
        var rows = ledger.ToBucketRows(materials, boundaries, toLocal);
        foreach (var issue in MaterialMixingBuckets.ToIssueEvents(rows, boundaries))
        {
            issues.Add(issue);
        }
        return Task.CompletedTask;
    }

    private async Task MeasureStageAsync(
        string stage,
        int branchId,
        Func<Task> action)
    {
        var stopwatch = Stopwatch.StartNew();
        try
        {
            await action();
            logger.LogInformation(
                "Material report stage completed. BranchId={BranchId}, Stage={Stage}, ElapsedMs={ElapsedMs:F1}",
                branchId,
                stage,
                stopwatch.Elapsed.TotalMilliseconds);
        }
        catch (Exception exception) when (exception is not OperationCanceledException)
        {
            logger.LogWarning(
                exception,
                "Material report stage failed. BranchId={BranchId}, Stage={Stage}, ElapsedMs={ElapsedMs:F1}",
                branchId,
                stage,
                stopwatch.Elapsed.TotalMilliseconds);
            throw;
        }
    }

    private static async Task LoadScaleEventsAsync(
        DbConnection connection,
        DateTime fromLocal,
        DateTime toLocal,
        ICollection<MaterialImportLot> imports,
        ICollection<MaterialIssueEvent> issues,
        ICollection<MaterialTransactionData> transactions,
        ICollection<string> warnings,
        int commandTimeoutSeconds,
        CancellationToken cancellationToken)
    {
        var columns = await GetColumnsAsync(connection, "TC_XEVAORA", cancellationToken);
        if (columns.Count == 0)
        {
            warnings.Add("Trạm không có nguồn phiếu cân TC_XEVAORA.");
            return;
        }

        var materialCode = ColumnOrNull(columns, "MACUAVL", "int");
        var materialName = ColumnOrEmpty(columns, "TENVATLIEU");
        var conversionFactor = ColumnOrNull(columns, "HESOQUYDOI", "decimal(24,6)");
        var conversionUnit = ColumnOrEmpty(columns, "DONVITINH");
        var conversionVolume = columns.Contains("KHOILUONGHANGQUYDOI")
            ? "CAST(ISNULL([KHOILUONGHANGQUYDOI],0) AS decimal(24,6))"
            : columns.Contains("KHOILUONGQUYDOI")
                ? "CAST(ISNULL([KHOILUONGQUYDOI],0) AS decimal(24,6))"
                : "CAST(NULL AS decimal(24,6))";
        var price = BuildUnitPriceExpression(columns, "[KHOILUONGCANLAN1]", "[KHOILUONGCANLAN2]");
        if (!columns.Contains("PRICE") && !columns.Contains("TOTAL_MONEY"))
        {
            warnings.Add("Phiếu cân chưa có cột đơn giá; giá trị các lô nhập từ trạm cân được tính bằng 0.");
        }

        await using var command = connection.CreateCommand();
        command.CommandTimeout = commandTimeoutSeconds;
        command.CommandText = $"""
            SELECT
                CAST([STT] AS bigint) AS SourceSequence,
                {materialCode} AS MaterialCode,
                {materialName} AS MaterialName,
                CAST([THOIGIANCANLAN2] AS datetime2(3)) AS OccurredAt,
                CAST(ROUND(ABS(ISNULL([KHOILUONGCANLAN2],0)-ISNULL([KHOILUONGCANLAN1],0)),0) AS decimal(24,4)) AS QuantityKg,
                {price} AS UnitPrice,
                {conversionVolume} AS ConversionVolume,
                {conversionUnit} AS ConversionUnit,
                {conversionFactor} AS ConversionCoefficient,
                ISNULL(CAST([LOAICAN] AS nvarchar(200)),N'') AS WeighingType
            FROM [dbo].[TC_XEVAORA]
            WHERE [THOIGIANCANLAN2] IS NOT NULL AND [THOIGIANCANLAN2] <= @To;
            """;
        AddDateTimeParameter(command, "@To", toLocal);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            var sequence = reader.GetInt64(0);
            var code = GetNullableInt32(reader, 1);
            var name = GetNullableString(reader, 2);
            var occurredAt = reader.GetDateTime(3);
            var quantity = GetDecimal(reader, 4);
            var unitPrice = GetDecimal(reader, 5);
            var volume = GetNullableDecimal(reader, 6);
            var unit = GetNullableString(reader, 7);
            var coefficient = GetNullableDecimal(reader, 8);
            var weighingType = MaterialFifoCalculator.NormalizeText(GetNullableString(reader, 9));
            var sourceId = $"scale:{sequence.ToString(CultureInfo.InvariantCulture)}";

            if (weighingType.Contains("NHAP", StringComparison.Ordinal))
            {
                imports.Add(new MaterialImportLot(
                    sourceId,
                    checked(sequence * 10 + 1),
                    code,
                    name,
                    occurredAt,
                    quantity,
                    unitPrice,
                    volume,
                    unit,
                    coefficient));
                if (occurredAt >= fromLocal)
                {
                    transactions.Add(new MaterialTransactionData(
                        sourceId,
                        occurredAt,
                        MaterialReportViewModes.Import,
                        "Nhập hàng từ trạm cân",
                        [new MaterialTransactionDetailData(code, name, quantity, unitPrice, volume, unit, coefficient)]));
                }
            }
            else if (weighingType.Contains("BAN", StringComparison.Ordinal))
            {
                issues.Add(new MaterialIssueEvent(
                    sourceId,
                    checked(sequence * 10 + 2),
                    code,
                    null,
                    name,
                    occurredAt,
                    quantity));
            }
        }
    }

    private static async Task LoadManualEventsAsync(
        DbConnection connection,
        DateTime fromLocal,
        DateTime toLocal,
        ICollection<MaterialImportLot> imports,
        ICollection<MaterialIssueEvent> issues,
        ICollection<MaterialTransactionData> transactions,
        ICollection<string> warnings,
        int commandTimeoutSeconds,
        CancellationToken cancellationToken)
    {
        var orderColumns = await GetColumnsAsync(connection, "OrderTram", cancellationToken);
        var itemColumns = await GetColumnsAsync(connection, "OrderItemTram", cancellationToken);
        if (orderColumns.Count == 0 || itemColumns.Count == 0)
        {
            warnings.Add("Trạm không có nguồn phiếu nhập/xuất thủ công.");
            return;
        }

        var conversionVolume = ColumnOrNull(itemColumns, "CONVERSION_VOLUME", "decimal(24,6)", "I");
        var conversionUnit = ColumnOrEmpty(itemColumns, "CONVERSION_UNIT", "I");
        var conversionCoefficient = ColumnOrNull(itemColumns, "CONVERSION_COEFFICIENT", "decimal(24,6)", "I");
        var totalMoney = ColumnOrNull(itemColumns, "TOTAL_MONEY", "decimal(24,4)", "I");
        var price = itemColumns.Contains("PRICE")
            ? "CAST(ISNULL(I.[Price],0) AS decimal(24,4))"
            : "CAST(0 AS decimal(24,4))";
        var unitPrice = itemColumns.Contains("PRICE") && itemColumns.Contains("TOTAL_MONEY")
            ? $"CAST(CASE WHEN ISNULL(I.[Price],0)>0 THEN I.[Price] WHEN ISNULL(I.[Quantity],0)>0 THEN {totalMoney}/I.[Quantity] ELSE 0 END AS decimal(24,4))"
            : itemColumns.Contains("PRICE")
                ? price
            : itemColumns.Contains("TOTAL_MONEY")
                ? $"CAST(CASE WHEN ISNULL(I.[Quantity],0)>0 THEN {totalMoney}/I.[Quantity] ELSE 0 END AS decimal(24,4))"
                : "CAST(0 AS decimal(24,4))";
        if (!itemColumns.Contains("PRICE") && !itemColumns.Contains("TOTAL_MONEY"))
        {
            warnings.Add("Phiếu thủ công chưa có cột đơn giá; giá trị lô nhập thủ công được tính bằng 0.");
        }

        await using var command = connection.CreateCommand();
        command.CommandTimeout = commandTimeoutSeconds;
        command.CommandText = $"""
            SELECT
                CAST(O.[OrderTramId] AS int) AS OrderId,
                CAST(I.[OrderItemTramId] AS bigint) AS ItemId,
                CAST(ISNULL(O.[TypePhieu],1) AS int) AS VoucherType,
                CAST(O.[TypePhieu] AS int) AS RawVoucherType,
                CAST(O.[CreatedAt] AS datetime2(3)) AS OccurredAt,
                ISNULL(CAST(O.[Name] AS nvarchar(1000)),N'') AS VoucherName,
                CAST(I.[CodeCuaVL] AS int) AS MaterialCode,
                ISNULL(CAST(M.[TENCUAVL] AS nvarchar(max)),N'') AS MaterialName,
                CAST(ROUND(ISNULL(I.[Quantity],0),0) AS decimal(24,4)) AS QuantityKg,
                {unitPrice} AS UnitPrice,
                {conversionVolume} AS ConversionVolume,
                {conversionUnit} AS ConversionUnit,
                {conversionCoefficient} AS ConversionCoefficient
            FROM [dbo].[OrderTram] O
            INNER JOIN [dbo].[OrderItemTram] I ON I.[OrderTramId]=O.[OrderTramId]
            LEFT JOIN [dbo].[CUAVL] M ON M.[MACUAVL]=I.[CodeCuaVL]
            WHERE O.[CreatedAt] IS NOT NULL
              AND O.[CreatedAt] <= @To
              AND ISNULL(O.[Status],1)<>99
              AND (O.[TypePhieu] IS NULL OR O.[TypePhieu] IN (0,1,2,3));
            """;
        AddDateTimeParameter(command, "@To", toLocal);
        var transactionBuilders = new Dictionary<int, ManualTransactionBuilder>();
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            var orderId = reader.GetInt32(0);
            var itemId = reader.GetInt64(1);
            var voucherType = reader.GetInt32(2);
            var rawVoucherType = GetNullableInt32(reader, 3);
            var occurredAt = reader.GetDateTime(4);
            var voucherName = GetNullableString(reader, 5);
            var code = GetNullableInt32(reader, 6);
            var name = GetNullableString(reader, 7);
            var quantity = GetDecimal(reader, 8);
            var itemPrice = GetDecimal(reader, 9);
            var volume = GetNullableDecimal(reader, 10);
            var unit = GetNullableString(reader, 11);
            var coefficient = GetNullableDecimal(reader, 12);
            var transactionId = $"manual:{orderId.ToString(CultureInfo.InvariantCulture)}";
            var sourceId = $"manual-item:{itemId.ToString(CultureInfo.InvariantCulture)}";

            if (voucherType is 0 or 1)
            {
                imports.Add(new MaterialImportLot(
                    sourceId,
                    checked(itemId * 10 + 3),
                    code,
                    name,
                    occurredAt,
                    quantity,
                    itemPrice,
                    volume,
                    unit,
                    coefficient,
                    quantity < 0 && rawVoucherType == 1));
            }
            else
            {
                issues.Add(new MaterialIssueEvent(
                    sourceId,
                    checked(itemId * 10 + 4),
                    code,
                    null,
                    name,
                    occurredAt,
                    quantity,
                    transactionId,
                    quantity < 0 && rawVoucherType is 2 or 3));
            }

            if (occurredAt < fromLocal)
            {
                continue;
            }
            if (!transactionBuilders.TryGetValue(orderId, out var builder))
            {
                builder = new ManualTransactionBuilder(
                    transactionId,
                    occurredAt,
                    VoucherType(voucherType),
                    voucherName);
                transactionBuilders.Add(orderId, builder);
            }
            builder.Details.Add(new MaterialTransactionDetailData(
                code,
                name,
                quantity,
                itemPrice,
                volume,
                unit,
                coefficient,
                voucherType is 2 or 3 ? sourceId : null));
        }

        foreach (var builder in transactionBuilders.Values)
        {
            transactions.Add(new MaterialTransactionData(
                builder.Id,
                builder.OccurredAt,
                builder.Type,
                builder.Name,
                builder.Details));
        }
    }

    private static async Task LoadMixingIssuesAsync(
        DbConnection connection,
        IReadOnlyList<MaterialDefinition> materials,
        IReadOnlyCollection<MaterialImportLot> imports,
        ICollection<MaterialIssueEvent> issues,
        DateTime fromLocal,
        DateTime toLocal,
        ICollection<string> warnings,
        int commandTimeoutSeconds,
        CancellationToken cancellationToken)
    {
        var requiredTables = new[] { "LSTRON", "LSCHITIETMETRON", "LSCHITIETMETRONLSCUAVL", "LSCUAVL" };
        foreach (var table in requiredTables)
        {
            if (!await TableExistsAsync(connection, table, cancellationToken))
            {
                warnings.Add("Trạm chưa có đủ dữ liệu tiêu hao vật liệu khi trộn.");
                return;
            }
        }

        // Only the scale and manual events are in `issues` yet: they and the lots are the
        // instants that split the mixing consumption (see MaterialMixingBuckets).
        var boundaries = MaterialMixingBuckets.BuildBoundaries(imports, issues.ToArray(), fromLocal, toLocal);

        // Slots still in CUAVL are mapped by slot number, so their historical names do not
        // matter; slots no longer there keep their historical name, which is how FIFO maps them.
        var currentSlots = materials.Select(item => item.SlotNumber).Distinct().Order().ToArray();
        var isCurrentSlot = currentSlots.Length == 0
            ? "1=0"
            : $"H.[STTCUAVL] IN ({string.Join(",", currentSlots.Select(slot => slot.ToString(CultureInfo.InvariantCulture)))})";
        var nameHash =
            $"CASE WHEN {isCurrentSlot} THEN NULL ELSE CAST(HASHBYTES('SHA1',ISNULL(CAST(H.[TENCUAVL] AS nvarchar(4000)),N'')) AS binary(20)) END";

        await using var command = connection.CreateCommand();
        command.CommandTimeout = commandTimeoutSeconds;
        // One pass over the history with narrow numeric keys (the previous query grouped and
        // sorted millions of rows on the nvarchar(max) names):
        // 1. each mix gets the last boundary at or before its finish time, once per mix instead
        //    of per detail row; a mix finishing exactly at an issue instant stays on its own;
        // 2. consumption per mix and slot, kept only when positive, like the single events;
        // 3. added up per bucket and slot, then CUAVL codes and names joined on the few results.
        command.CommandText = $"""
            DECLARE @Boundary TABLE
            (
                [BucketNo] int NOT NULL PRIMARY KEY,
                [At] datetime2(3) NOT NULL UNIQUE,
                [IsIssue] bit NOT NULL
            );
            INSERT INTO @Boundary ([BucketNo],[At],[IsIssue])
            SELECT X.value('@n','int'), X.value('@t','datetime2(3)'), X.value('@i','bit')
            FROM @Boundaries.nodes('/r/b') AS T(X);

            WITH MixingHistory AS
            (
                SELECT
                    M.[MALSTRON],
                    B.[BucketNo],
                    CASE WHEN B.[IsIssue]=1 AND B.[At]=CAST(M.[GIOXONG] AS datetime2(3)) THEN M.[MALSTRON] END AS [TieMixingId]
                FROM [dbo].[LSTRON] M
                CROSS APPLY
                (
                    SELECT TOP 1 X.[BucketNo], X.[At], X.[IsIssue]
                    FROM @Boundary X
                    WHERE X.[At] <= CAST(M.[GIOXONG] AS datetime2(3))
                    ORDER BY X.[At] DESC
                ) B
                WHERE M.[GIOXONG] IS NOT NULL AND M.[GIOXONG] <= @To
            ),
            MixingEvent AS
            (
                SELECT
                    M.[BucketNo],
                    M.[TieMixingId],
                    H.[STTCUAVL],
                    {nameHash} AS [NameHash],
                    MIN(CASE WHEN {isCurrentSlot} THEN NULL ELSE H.[MACUAVL] END) AS [NameSourceId],
                    SUM(ROUND(ISNULL(D.[SOLUONG],0)+ISNULL(D.[SOLUONGT],0),0)) AS [QuantityKg]
                FROM MixingHistory M
                INNER JOIN [dbo].[LSCHITIETMETRON] MD ON MD.[MALSTRON]=M.[MALSTRON]
                INNER JOIN [dbo].[LSCHITIETMETRONLSCUAVL] D ON D.[MACHITIETMETRON]=MD.[MACHITIETMETRON]
                INNER JOIN [dbo].[LSCUAVL] H ON H.[MACUAVL]=D.[MACUAVL]
                GROUP BY M.[MALSTRON], M.[BucketNo], M.[TieMixingId], H.[STTCUAVL], {nameHash}
            ),
            MixingBucket AS
            (
                SELECT
                    [BucketNo],
                    [TieMixingId],
                    [STTCUAVL],
                    [NameHash],
                    MIN([NameSourceId]) AS [NameSourceId],
                    SUM([QuantityKg]) AS [QuantityKg]
                FROM MixingEvent
                WHERE [QuantityKg] > 0
                GROUP BY [BucketNo], [TieMixingId], [STTCUAVL], [NameHash]
            )
            SELECT
                B.[BucketNo],
                CAST(B.[TieMixingId] AS bigint) AS TieMixingId,
                CAST(C.[MACUAVL] AS int) AS MaterialCode,
                CAST(B.[STTCUAVL] AS int) AS SlotNumber,
                ISNULL(CAST(CASE WHEN B.[NameHash] IS NULL THEN C.[TENCUAVL] ELSE HN.[TENCUAVL] END AS nvarchar(max)),N'') AS MaterialName,
                CAST(B.[QuantityKg] AS decimal(24,4)) AS QuantityKg
            FROM MixingBucket B
            LEFT JOIN [dbo].[CUAVL] C ON B.[NameHash] IS NULL AND C.[STTCUAVL]=B.[STTCUAVL]
            LEFT JOIN [dbo].[LSCUAVL] HN ON HN.[MACUAVL]=B.[NameSourceId]
            OPTION (RECOMPILE);
            """;
        AddDateTimeParameter(command, "@To", toLocal);
        AddXmlParameter(command, "@Boundaries", MaterialMixingBuckets.ToXml(boundaries));
        var rows = new List<MaterialMixingBucketRow>();
        await using (var reader = await command.ExecuteReaderAsync(cancellationToken))
        {
            while (await reader.ReadAsync(cancellationToken))
            {
                rows.Add(new MaterialMixingBucketRow(
                    reader.GetInt32(0),
                    reader.IsDBNull(1) ? null : reader.GetInt64(1),
                    GetNullableInt32(reader, 2),
                    GetNullableInt32(reader, 3),
                    GetNullableString(reader, 4),
                    GetDecimal(reader, 5)));
            }
        }

        foreach (var issue in MaterialMixingBuckets.ToIssueEvents(rows, boundaries))
        {
            issues.Add(issue);
        }
    }

    private static string BuildUnitPriceExpression(
        IReadOnlySet<string> columns,
        string firstWeight,
        string secondWeight)
    {
        if (columns.Contains("PRICE") && columns.Contains("TOTAL_MONEY"))
        {
            return $"CAST(CASE WHEN ISNULL([Price],0)>0 THEN [Price] WHEN ABS(ISNULL({secondWeight},0)-ISNULL({firstWeight},0))>0 THEN ISNULL([Total_Money],0)/ABS(ISNULL({secondWeight},0)-ISNULL({firstWeight},0)) ELSE 0 END AS decimal(24,4))";
        }
        if (columns.Contains("PRICE"))
        {
            return "CAST(ISNULL([Price],0) AS decimal(24,4))";
        }
        if (columns.Contains("TOTAL_MONEY"))
        {
            return $"CAST(CASE WHEN ABS(ISNULL({secondWeight},0)-ISNULL({firstWeight},0))>0 THEN ISNULL([Total_Money],0)/ABS(ISNULL({secondWeight},0)-ISNULL({firstWeight},0)) ELSE 0 END AS decimal(24,4))";
        }
        return "CAST(0 AS decimal(24,4))";
    }

    private static string ColumnOrNull(
        IReadOnlySet<string> columns,
        string column,
        string sqlType,
        string? alias = null) =>
        columns.Contains(column)
            ? $"CAST({(string.IsNullOrWhiteSpace(alias) ? string.Empty : alias + ".")}[{column}] AS {sqlType})"
            : $"CAST(NULL AS {sqlType})";

    private static string ColumnOrEmpty(
        IReadOnlySet<string> columns,
        string column,
        string? alias = null) =>
        columns.Contains(column)
            ? $"ISNULL(CAST({(string.IsNullOrWhiteSpace(alias) ? string.Empty : alias + ".")}[{column}] AS nvarchar(max)),N'')"
            : "CAST(N'' AS nvarchar(max))";

    private static async Task<HashSet<string>> GetColumnsAsync(
        DbConnection connection,
        string tableName,
        CancellationToken cancellationToken)
    {
        await using var command = connection.CreateCommand();
        command.CommandText = """
            SELECT C.[name]
            FROM sys.tables T
            INNER JOIN sys.columns C ON C.[object_id]=T.[object_id]
            WHERE T.[schema_id]=SCHEMA_ID(N'dbo') AND T.[name]=@TableName;
            """;
        AddStringParameter(command, "@TableName", tableName);
        var result = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            result.Add(reader.GetString(0));
        }
        return result;
    }

    private static async Task<bool> TableExistsAsync(
        DbConnection connection,
        string tableName,
        CancellationToken cancellationToken)
    {
        await using var command = connection.CreateCommand();
        command.CommandText = "SELECT CASE WHEN OBJECT_ID(N'dbo.'+@TableName,N'U') IS NULL THEN 0 ELSE 1 END;";
        AddStringParameter(command, "@TableName", tableName);
        return Convert.ToInt32(await command.ExecuteScalarAsync(cancellationToken), CultureInfo.InvariantCulture) == 1;
    }

    private static void AddDateTimeParameter(DbCommand command, string name, DateTime value)
    {
        var parameter = command.CreateParameter();
        parameter.ParameterName = name;
        parameter.DbType = DbType.DateTime2;
        parameter.Value = value;
        command.Parameters.Add(parameter);
    }

    private static void AddXmlParameter(DbCommand command, string name, string value)
    {
        var parameter = command.CreateParameter();
        parameter.ParameterName = name;
        parameter.DbType = DbType.Xml;
        parameter.Value = value;
        command.Parameters.Add(parameter);
    }

    private static void AddStringParameter(DbCommand command, string name, string value)
    {
        var parameter = command.CreateParameter();
        parameter.ParameterName = name;
        parameter.DbType = DbType.String;
        parameter.Value = value;
        command.Parameters.Add(parameter);
    }

    private static int? GetNullableInt32(DbDataReader reader, int ordinal) =>
        reader.IsDBNull(ordinal) ? null : Convert.ToInt32(reader.GetValue(ordinal), CultureInfo.InvariantCulture);

    private static decimal GetDecimal(DbDataReader reader, int ordinal) =>
        reader.IsDBNull(ordinal) ? 0m : Convert.ToDecimal(reader.GetValue(ordinal), CultureInfo.InvariantCulture);

    private static decimal? GetNullableDecimal(DbDataReader reader, int ordinal) =>
        reader.IsDBNull(ordinal) ? null : Convert.ToDecimal(reader.GetValue(ordinal), CultureInfo.InvariantCulture);

    private static string? GetNullableString(DbDataReader reader, int ordinal) =>
        reader.IsDBNull(ordinal) ? null : Convert.ToString(reader.GetValue(ordinal), CultureInfo.InvariantCulture);

    private static string VoucherType(int value) => value switch
    {
        2 => MaterialReportViewModes.Export,
        3 => MaterialReportViewModes.Stocktake,
        _ => MaterialReportViewModes.Import
    };

    private sealed class ManualTransactionBuilder(
        string id,
        DateTime occurredAt,
        string type,
        string? name)
    {
        public string Id { get; } = id;
        public DateTime OccurredAt { get; } = occurredAt;
        public string Type { get; } = type;
        public string? Name { get; } = name;
        public List<MaterialTransactionDetailData> Details { get; } = [];
    }
}
