using System.Data;
using System.Data.Common;
using System.Globalization;

namespace TTSmart.Api.Features.MaterialReporting;

/// <summary>A consumption value that is not a whole kg: the ledger cannot keep it exactly.</summary>
internal sealed class MaterialMixingLedgerUnsupportedException(string message) : Exception(message);

/// <summary>Consumption of one mix, slot and historical name, before names get their index.</summary>
internal readonly record struct MaterialMixingLedgerSourceRow(
    long MixId,
    DateTime Finish3,
    DateTime Finish7,
    int? Slot,
    string NameHash,
    long NameSourceId,
    long QuantityKg);

/// <summary>A mixing detail id and the finish time of its mix (null while it has none).</summary>
internal readonly record struct MaterialMixingDetail(long DetailId, DateTime? Finish7);

/// <summary>
/// Read-only queries of the ledger. Every one seeks a range of the clustered keys (detail ids,
/// then the mix and door ids of that range, which grow with them), so a chunk costs about its own
/// size whatever the size of the history.
/// </summary>
internal static class MaterialMixingLedgerSql
{
    private static readonly string[] MixingTables = ["LSTRON", "LSCHITIETMETRON", "LSCHITIETMETRONLSCUAVL", "LSCUAVL"];

    public static async Task<bool> HasMixingTablesAsync(
        DbConnection connection,
        int commandTimeoutSeconds,
        CancellationToken cancellationToken)
    {
        await using var command = connection.CreateCommand();
        command.CommandTimeout = commandTimeoutSeconds;
        command.CommandText = $"""
            SELECT COUNT(*) FROM sys.tables
            WHERE [schema_id]=SCHEMA_ID(N'dbo') AND [name] IN ({string.Join(",", MixingTables.Select(name => $"N'{name}'"))});
            """;
        var count = Convert.ToInt32(await command.ExecuteScalarAsync(cancellationToken), CultureInfo.InvariantCulture);
        return count == MixingTables.Length;
    }

    public static async Task<(long Min, long Max)?> GetDetailRangeAsync(
        DbConnection connection,
        int commandTimeoutSeconds,
        CancellationToken cancellationToken)
    {
        await using var command = connection.CreateCommand();
        command.CommandTimeout = commandTimeoutSeconds;
        command.CommandText = "SELECT MIN([MACHITIETMETRON]), MAX([MACHITIETMETRON]) FROM [dbo].[LSCHITIETMETRON];";
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken) || reader.IsDBNull(0))
        {
            return null;
        }
        return (Convert.ToInt64(reader.GetValue(0), CultureInfo.InvariantCulture),
            Convert.ToInt64(reader.GetValue(1), CultureInfo.InvariantCulture));
    }

    /// <summary>
    /// The number of mixing detail rows from the table's statistics (no scan), for the progress of
    /// a first read; null when SQL Server does not give it.
    /// </summary>
    public static async Task<long?> CountDetailRowsAsync(
        DbConnection connection,
        int commandTimeoutSeconds,
        CancellationToken cancellationToken)
    {
        await using var command = connection.CreateCommand();
        command.CommandTimeout = commandTimeoutSeconds;
        command.CommandText = """
            SELECT SUM(CAST(P.[rows] AS bigint)) FROM sys.partitions P
            WHERE P.[object_id]=OBJECT_ID(N'dbo.LSCHITIETMETRON') AND P.[index_id] IN (0,1);
            """;
        var value = await command.ExecuteScalarAsync(cancellationToken);
        return value is null or DBNull ? null : Convert.ToInt64(value, CultureInfo.InvariantCulture);
    }

    /// <summary>The detail id <paramref name="rows"/> rows after <paramref name="after"/>, or the last one.</summary>
    public static async Task<long?> FindChunkEndAsync(
        DbConnection connection,
        long after,
        int rows,
        int commandTimeoutSeconds,
        CancellationToken cancellationToken)
    {
        await using var command = connection.CreateCommand();
        command.CommandTimeout = commandTimeoutSeconds;
        command.CommandText = """
            SELECT MAX(X.[MACHITIETMETRON])
            FROM (SELECT TOP (@Rows) [MACHITIETMETRON] FROM [dbo].[LSCHITIETMETRON]
                  WHERE [MACHITIETMETRON] > @After ORDER BY [MACHITIETMETRON]) X;
            """;
        AddParameter(command, "@After", DbType.Int64, after);
        AddParameter(command, "@Rows", DbType.Int32, rows);
        var value = await command.ExecuteScalarAsync(cancellationToken);
        return value is null or DBNull ? null : Convert.ToInt64(value, CultureInfo.InvariantCulture);
    }

    /// <summary>The detail ids of a range with the finish time of their mix, in id order.</summary>
    public static async Task<IReadOnlyList<MaterialMixingDetail>> ReadDetailsAsync(
        DbConnection connection,
        long after,
        long upTo,
        int commandTimeoutSeconds,
        CancellationToken cancellationToken)
    {
        await using var command = connection.CreateCommand();
        command.CommandTimeout = commandTimeoutSeconds;
        command.CommandText = """
            SELECT MD.[MACHITIETMETRON], CAST(M.[GIOXONG] AS datetime2(7))
            FROM [dbo].[LSCHITIETMETRON] MD
            LEFT JOIN [dbo].[LSTRON] M ON M.[MALSTRON]=MD.[MALSTRON]
            WHERE MD.[MACHITIETMETRON] > @After AND MD.[MACHITIETMETRON] <= @UpTo
            ORDER BY MD.[MACHITIETMETRON];
            """;
        AddParameter(command, "@After", DbType.Int64, after);
        AddParameter(command, "@UpTo", DbType.Int64, upTo);
        var result = new List<MaterialMixingDetail>();
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            result.Add(new MaterialMixingDetail(
                Convert.ToInt64(reader.GetValue(0), CultureInfo.InvariantCulture),
                reader.IsDBNull(1) ? null : reader.GetDateTime(1)));
        }
        return result;
    }

    /// <summary>
    /// The consumption of the mixes of a detail range, per mix, slot and historical name, summed
    /// exactly like the mixing query: each detail row rounded to the kg by SQL Server (on its real
    /// values), then added up. The rows are added up here: per mix a slot has nearly always one
    /// row, and a GROUP BY on the name hash made SQL Server spill to tempdb.
    /// </summary>
    public static async Task<IReadOnlyList<MaterialMixingLedgerSourceRow>> ReadChunkAsync(
        DbConnection connection,
        long after,
        long upTo,
        int commandTimeoutSeconds,
        CancellationToken cancellationToken)
    {
        await using var command = connection.CreateCommand();
        command.CommandTimeout = commandTimeoutSeconds;
        command.CommandText = """
            DECLARE @DoorFrom bigint, @DoorTo bigint, @MixFrom bigint, @MixTo bigint;
            SELECT @DoorFrom=MIN(D.[MACUAVL]), @DoorTo=MAX(D.[MACUAVL])
            FROM [dbo].[LSCHITIETMETRONLSCUAVL] D
            WHERE D.[MACHITIETMETRON] > @After AND D.[MACHITIETMETRON] <= @UpTo;
            SELECT @MixFrom=MIN(MD.[MALSTRON]), @MixTo=MAX(MD.[MALSTRON])
            FROM [dbo].[LSCHITIETMETRON] MD
            WHERE MD.[MACHITIETMETRON] > @After AND MD.[MACHITIETMETRON] <= @UpTo;

            SELECT
                CAST(M.[MALSTRON] AS bigint) AS MixId,
                CAST(M.[GIOXONG] AS datetime2(3)) AS Finish3,
                CAST(M.[GIOXONG] AS datetime2(7)) AS Finish7,
                CAST(H.[STTCUAVL] AS int) AS Slot,
                CAST(HASHBYTES('SHA1',ISNULL(CAST(H.[TENCUAVL] AS nvarchar(4000)),N'')) AS binary(20)) AS NameHash,
                CAST(H.[MACUAVL] AS bigint) AS DoorId,
                CAST(ROUND(ISNULL(D.[SOLUONG],0)+ISNULL(D.[SOLUONGT],0),0) AS float) AS QuantityKg
            FROM [dbo].[LSCHITIETMETRON] MD
            INNER JOIN [dbo].[LSTRON] M ON M.[MALSTRON]=MD.[MALSTRON]
            INNER JOIN [dbo].[LSCHITIETMETRONLSCUAVL] D ON D.[MACHITIETMETRON]=MD.[MACHITIETMETRON]
            INNER JOIN [dbo].[LSCUAVL] H ON H.[MACUAVL]=D.[MACUAVL]
            WHERE MD.[MACHITIETMETRON] > @After AND MD.[MACHITIETMETRON] <= @UpTo
              AND D.[MACHITIETMETRON] > @After AND D.[MACHITIETMETRON] <= @UpTo
              AND M.[MALSTRON] BETWEEN @MixFrom AND @MixTo
              AND H.[MACUAVL] BETWEEN @DoorFrom AND @DoorTo
              AND M.[GIOXONG] IS NOT NULL
            OPTION (RECOMPILE);
            """;
        AddParameter(command, "@After", DbType.Int64, after);
        AddParameter(command, "@UpTo", DbType.Int64, upTo);
        var groups = new Dictionary<(long MixId, int? Slot, string NameHash), MaterialMixingLedgerSourceRow>();
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            var mixId = reader.GetInt64(0);
            var quantity = reader.IsDBNull(6) ? 0d : reader.GetDouble(6);
            if (!double.IsFinite(quantity) || quantity != Math.Floor(quantity) || Math.Abs(quantity) > 1e15)
            {
                throw new MaterialMixingLedgerUnsupportedException(
                    $"Mix {mixId.ToString(CultureInfo.InvariantCulture)} has a consumption that is not a whole kg.");
            }
            var slot = reader.IsDBNull(3) ? (int?)null : reader.GetInt32(3);
            var nameHash = Convert.ToHexString((byte[])reader.GetValue(4));
            var doorId = reader.GetInt64(5);
            var key = (mixId, slot, nameHash);
            groups[key] = groups.TryGetValue(key, out var group)
                ? group with
                {
                    NameSourceId = Math.Min(group.NameSourceId, doorId),
                    QuantityKg = checked(group.QuantityKg + (long)quantity)
                }
                : new MaterialMixingLedgerSourceRow(
                    mixId,
                    reader.GetDateTime(1),
                    reader.GetDateTime(2),
                    slot,
                    nameHash,
                    doorId,
                    (long)quantity);
        }
        return [.. groups.Values];
    }

    /// <summary>The historical names of these LSCUAVL rows, as the mixing query shows them.</summary>
    public static async Task<IReadOnlyDictionary<long, string>> ReadNamesAsync(
        DbConnection connection,
        IReadOnlyCollection<long> doorIds,
        int commandTimeoutSeconds,
        CancellationToken cancellationToken)
    {
        var result = new Dictionary<long, string>();
        foreach (var batch in doorIds.Distinct().Chunk(500))
        {
            await using var command = connection.CreateCommand();
            command.CommandTimeout = commandTimeoutSeconds;
            // Numbers read from the database, not user input.
            command.CommandText = $"""
                SELECT CAST([MACUAVL] AS bigint), ISNULL(CAST([TENCUAVL] AS nvarchar(max)),N'')
                FROM [dbo].[LSCUAVL]
                WHERE [MACUAVL] IN ({string.Join(",", batch.Select(id => id.ToString(CultureInfo.InvariantCulture)))});
                """;
            await using var reader = await command.ExecuteReaderAsync(cancellationToken);
            while (await reader.ReadAsync(cancellationToken))
            {
                result[reader.GetInt64(0)] = reader.GetString(1);
            }
        }
        return result;
    }

    private static void AddParameter(DbCommand command, string name, DbType type, object value)
    {
        var parameter = command.CreateParameter();
        parameter.ParameterName = name;
        parameter.DbType = type;
        parameter.Value = value;
        command.Parameters.Add(parameter);
    }
}
