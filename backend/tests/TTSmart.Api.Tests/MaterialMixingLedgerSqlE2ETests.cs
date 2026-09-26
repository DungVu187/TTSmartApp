using System.Diagnostics;
using Microsoft.AspNetCore.Hosting;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using TTSmart.Api.Data.StationOperations;
using TTSmart.Api.Features.MaterialReporting;
using Xunit.Abstractions;

namespace TTSmart.Api.Tests;

/// <summary>
/// The report from the ledger against the query over the whole history, on copies of real station
/// databases: every material, value and summary number of several periods must be the same, with
/// big and small chunks, an open tail of the last days or of half the history, after a seal and
/// after the daily check.
/// </summary>
public sealed class MaterialMixingLedgerSqlE2ETests(ITestOutputHelper output)
{
    private static readonly TimeSpan VietnamOffset = TimeSpan.FromHours(7);

    [MaterialLedgerSqlE2EFact]
    [Trait("Category", "SqlE2E")]
    public async Task SoTieuHao_RaDungSoCuaTruyVanToanBoLichSu_TrenDatabaseTram()
    {
        var connection = Environment.GetEnvironmentVariable(MaterialReportSqlE2EFactAttribute.StationConnectionEnvironmentVariable)!;
        var databases = Environment.GetEnvironmentVariable(MaterialLedgerSqlE2EFactAttribute.DatabasesEnvironmentVariable)!
            .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        await using var factory = new LedgerFactory(connection, databases);
        using var scope = factory.Services.CreateScope();
        var stationFactory = scope.ServiceProvider.GetRequiredService<IStationOperationsDbContextFactory>();
        var scopeFactory = factory.Services.GetRequiredService<IServiceScopeFactory>();
        var environment = factory.Services.GetRequiredService<IHostEnvironment>();

        for (var index = 0; index < databases.Length; index++)
        {
            var target = new StationDatabaseTarget(LedgerFactory.FirstBranchId + index, databases[index]);
            var span = await HistorySpanAsync(stationFactory, target);
            var ranges = Ranges(span);
            var sql = new SqlMaterialReportDataSource(
                stationFactory,
                new UnusedLedgerStore(),
                Options.Create(new MaterialReportingOptions { UseMixingLedger = false }),
                NullLogger<SqlMaterialReportDataSource>.Instance);
            var expected = new List<MaterialReportSnapshot>();
            foreach (var (fromLocal, toLocal) in ranges)
            {
                expected.Add(await sql.LoadAsync(target, fromLocal, toLocal, CancellationToken.None));
            }

            var configurations = new (string Name, int ChunkRows, DateTime NowUtc)[]
            {
                ("today", 10_000, DateTime.UtcNow),
                ("tail of the last days", 1_500, span.Max.AddDays(1) - VietnamOffset),
                ("tail of half the history", 700, span.Min + (span.Max - span.Min) / 2 - VietnamOffset)
            };
            foreach (var configuration in configurations)
            {
                var clock = new ManualClock(configuration.NowUtc);
                var directory = Path.Combine(Path.GetTempPath(), $"ttsmart-ledger-e2e-{Guid.NewGuid():N}");
                var options = Options.Create(new MaterialReportingOptions
                {
                    LedgerDirectory = directory,
                    LedgerChunkDetailRows = configuration.ChunkRows,
                    LedgerChunkPauseMilliseconds = 0,
                    LedgerRefreshSeconds = 0,
                    LedgerPrepareWaitSeconds = 60
                });
                var store = new MaterialMixingLedgerStore(
                    scopeFactory, options, environment, clock, NullLogger<MaterialMixingLedgerStore>.Instance);
                using var stop = new CancellationTokenSource();
                var worker = store.RunAsync(stop.Token);
                try
                {
                    var ledgerSource = new SqlMaterialReportDataSource(
                        stationFactory, store, options, NullLogger<SqlMaterialReportDataSource>.Instance);
                    var started = DateTime.UtcNow;
                    var ledger = await store.GetAsync(target, CancellationToken.None);
                    Assert.NotNull(ledger);
                    output.WriteLine(
                        $"{databases[index]} [{configuration.Name}]: {ledger.SealedChunks.Count} sealed chunks, " +
                        $"{ledger.EntryCount} entries, tail {ledger.Tail.MixIds.Length} mixes, " +
                        $"built in {(DateTime.UtcNow - started).TotalSeconds:F1}s");

                    await AssertSameAsync(ledgerSource, target, ranges, expected, $"{databases[index]} [{configuration.Name}]");

                    // Twenty days later the old part of the tail is sealed; the numbers stay the same.
                    clock.Advance(TimeSpan.FromDays(20));
                    await AssertSameAsync(ledgerSource, target, ranges, expected, $"{databases[index]} [{configuration.Name}, sealed]");

                    // The daily check reads every sealed chunk again and finds nothing to correct.
                    clock.Advance(TimeSpan.FromDays(1));
                    var before = await store.GetAsync(target, CancellationToken.None);
                    await store.VerifyNowAsync(target, CancellationToken.None);
                    var after = await store.GetAsync(target, CancellationToken.None);
                    Assert.NotNull(before);
                    Assert.NotNull(after);
                    Assert.All(before.SealedChunks.Zip(after.SealedChunks), pair => Assert.Same(pair.First, pair.Second));
                    await AssertSameAsync(ledgerSource, target, ranges, expected, $"{databases[index]} [{configuration.Name}, checked]");

                    // A restart reads the file instead of the station.
                    var reloaded = new MaterialMixingLedgerStore(
                        scopeFactory, options, environment, clock, NullLogger<MaterialMixingLedgerStore>.Instance);
                    var fromFile = new SqlMaterialReportDataSource(
                        stationFactory, reloaded, options, NullLogger<SqlMaterialReportDataSource>.Instance);
                    await AssertSameAsync(fromFile, target, ranges, expected, $"{databases[index]} [{configuration.Name}, file]");
                }
                finally
                {
                    await stop.CancelAsync();
                    await worker;
                    if (Directory.Exists(directory))
                    {
                        Directory.Delete(directory, recursive: true);
                    }
                }
            }
        }
    }

    private async Task AssertSameAsync(
        SqlMaterialReportDataSource source,
        StationDatabaseTarget target,
        IReadOnlyList<(DateTime From, DateTime To)> ranges,
        IReadOnlyList<MaterialReportSnapshot> expected,
        string label)
    {
        for (var index = 0; index < ranges.Count; index++)
        {
            var (fromLocal, toLocal) = ranges[index];
            var loading = Stopwatch.StartNew();
            var actual = await source.LoadAsync(target, fromLocal, toLocal, CancellationToken.None);
            var loadedIn = loading.ElapsedMilliseconds;
            var want = expected[index];
            var context = $"{label} {fromLocal:yyyy-MM-dd HH:mm:ss.fffffff}..{toLocal:yyyy-MM-dd HH:mm:ss.fffffff}";

            Assert.Equal(want.Warnings, actual.Warnings);
            Assert.Equal(want.Imports.Count, actual.Imports.Count);
            Assert.Equal(want.Transactions.Count, actual.Transactions.Count);
            var wantIssues = Issues(want);
            var actualIssues = Issues(actual);
            Assert.True(
                wantIssues.SequenceEqual(actualIssues),
                $"{context}: mixing issues differ ({want.Issues.Count} vs {actual.Issues.Count}). " +
                $"Query only: {string.Join(" ; ", wantIssues.Except(actualIssues).Take(8))}. " +
                $"Ledger only: {string.Join(" ; ", actualIssues.Except(wantIssues).Take(8))}.");

            var wantCalculation = MaterialFifoCalculator.Calculate(want, fromLocal, toLocal);
            var actualCalculation = MaterialFifoCalculator.Calculate(actual, fromLocal, toLocal);
            Assert.Equal(wantCalculation.Materials, actualCalculation.Materials);
            Assert.Equal(
                wantCalculation.IssueValueByTransactionId.OrderBy(pair => pair.Key, StringComparer.Ordinal),
                actualCalculation.IssueValueByTransactionId.OrderBy(pair => pair.Key, StringComparer.Ordinal));
            Assert.Equal(
                PeriodIssues(want, wantCalculation, fromLocal, toLocal),
                PeriodIssues(actual, actualCalculation, fromLocal, toLocal));
            output.WriteLine(
                $"  {context}: {actual.Issues.Count} issues, export " +
                $"{actualCalculation.Materials.Sum(item => item.ExportQuantityKg):N0} kg, same, loaded in {loadedIn} ms");
        }
    }

    /// <summary>The issues in a fixed order, without the ids whose numbering follows the row order.</summary>
    private static string[] Issues(MaterialReportSnapshot snapshot) => snapshot.Issues
        .Select(item =>
            $"{item.OccurredAt.Ticks}|{item.MaterialCode}|{item.SlotNumber}|{item.MaterialName}|{item.QuantityKg}|" +
            $"{item.SourceId.StartsWith("mix:", StringComparison.Ordinal)}|{item.TransactionId}|{item.IsQuantityOnlyAdjustment}")
        .Order(StringComparer.Ordinal)
        .ToArray();

    /// <summary>What "Xuất tổng trong kỳ" adds up: the issues of the period with their FIFO value.</summary>
    private static string[] PeriodIssues(
        MaterialReportSnapshot snapshot,
        MaterialFifoCalculation calculation,
        DateTime fromLocal,
        DateTime toLocal) => snapshot.Issues
        .Where(item => item.OccurredAt >= fromLocal && item.OccurredAt <= toLocal)
        .GroupBy(item => $"{item.MaterialCode}|{item.SlotNumber}|{item.MaterialName}")
        .Select(group =>
            $"{group.Key}|{group.Sum(item => item.QuantityKg)}|" +
            $"{group.Sum(item => calculation.IssueValueBySourceId.GetValueOrDefault(item.SourceId))}")
        .Order(StringComparer.Ordinal)
        .ToArray();

    /// <summary>A month to the last mix, a past month, and a period ending exactly at a mix.</summary>
    private static IReadOnlyList<(DateTime From, DateTime To)> Ranges((DateTime Min, DateTime Max, DateTime NearMiddle) span)
    {
        var middle = span.Min + (span.Max - span.Min) / 2;
        return
        [
            (new DateTime(span.Max.Year, span.Max.Month, 1), span.Max.Date.AddDays(1).AddTicks(-1)),
            (middle.Date.AddDays(-20), middle.Date.AddTicks(-1)),
            (span.Min.Date, span.NearMiddle)
        ];
    }

    private static async Task<(DateTime Min, DateTime Max, DateTime NearMiddle)> HistorySpanAsync(
        IStationOperationsDbContextFactory factory,
        StationDatabaseTarget target)
    {
        await using var dbContext = factory.Create(target);
        await dbContext.Database.OpenConnectionAsync();
        await using var command = dbContext.Database.GetDbConnection().CreateCommand();
        command.CommandText = """
            DECLARE @Min datetime2(7), @Max datetime2(7);
            SELECT @Min=MIN(CAST(GIOXONG AS datetime2(7))), @Max=MAX(CAST(GIOXONG AS datetime2(7))) FROM dbo.LSTRON;
            SELECT @Min, @Max,
                (SELECT TOP 1 CAST(GIOXONG AS datetime2(7)) FROM dbo.LSTRON
                 WHERE GIOXONG >= DATEADD(day, DATEDIFF(day, @Min, @Max) / 2 + 10, @Min) ORDER BY GIOXONG);
            """;
        await using var reader = await command.ExecuteReaderAsync();
        await reader.ReadAsync();
        var max = reader.GetDateTime(1);
        return (reader.GetDateTime(0), max, reader.IsDBNull(2) ? max : reader.GetDateTime(2));
    }

    private sealed class ManualClock(DateTime utcNow) : TimeProvider
    {
        private DateTime now = DateTime.SpecifyKind(utcNow, DateTimeKind.Utc);

        public override DateTimeOffset GetUtcNow() => new(now, TimeSpan.Zero);

        public void Advance(TimeSpan by) => now = now.Add(by);
    }

    private sealed class UnusedLedgerStore : IMaterialMixingLedgerStore
    {
        public Task<MaterialMixingLedger?> GetAsync(StationDatabaseTarget target, CancellationToken cancellationToken) =>
            throw new InvalidOperationException("The query path must not use the ledger.");
    }

    private sealed class LedgerFactory(string stationConnection, IReadOnlyList<string> databases) : TTSmartApiFactory
    {
        public const int FirstBranchId = 900;

        protected override void ConfigureWebHost(IWebHostBuilder builder)
        {
            base.ConfigureWebHost(builder);
            builder.ConfigureAppConfiguration((_, configuration) =>
            {
                var settings = new Dictionary<string, string?>
                {
                    ["ConnectionStrings:StationConnection"] = stationConnection,
                    ["MaterialReporting:UseMixingLedger"] = "false"
                };
                for (var index = 0; index < databases.Count; index++)
                {
                    settings[$"StationDatabase:BranchDatabaseOverrides:{FirstBranchId + index}"] = databases[index];
                }
                configuration.AddInMemoryCollection(settings);
            });
        }
    }
}

public sealed class MaterialLedgerSqlE2EFactAttribute : FactAttribute
{
    public const string DatabasesEnvironmentVariable = "TTSMART_MATERIAL_LEDGER_DATABASES";

    public MaterialLedgerSqlE2EFactAttribute()
    {
        if (string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable(
                MaterialReportSqlE2EFactAttribute.StationConnectionEnvironmentVariable)) ||
            string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable(DatabasesEnvironmentVariable)))
        {
            Skip = $"Thiếu biến môi trường {MaterialReportSqlE2EFactAttribute.StationConnectionEnvironmentVariable} " +
                   $"hoặc {DatabasesEnvironmentVariable}.";
        }
    }
}
