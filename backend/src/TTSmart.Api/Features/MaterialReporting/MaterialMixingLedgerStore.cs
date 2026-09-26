using System.Collections.Concurrent;
using System.Data.Common;
using System.Diagnostics;
using System.Threading.Channels;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using TTSmart.Api.Data.StationOperations;

namespace TTSmart.Api.Features.MaterialReporting;

/// <summary>The first read of a station's mixing history is still running.</summary>
internal sealed class MaterialReportPreparingException(int progressPercent)
    : Exception("Đang tổng hợp dữ liệu tiêu hao của trạm.")
{
    public int ProgressPercent { get; } = progressPercent;
}

internal interface IMaterialMixingLedgerStore
{
    /// <summary>
    /// The station's ledger with the latest mixes read; null when the station's data cannot be kept
    /// exactly (the report then adds up the history with the query). Throws
    /// <see cref="MaterialReportPreparingException"/> while the first read runs.
    /// </summary>
    Task<MaterialMixingLedger?> GetAsync(StationDatabaseTarget target, CancellationToken cancellationToken);
}

/// <summary>
/// Keeps the mixing consumption of the stations that are looked at, so a report reads only what
/// changed on the station database. The first read of a station runs in the background in small
/// ranges of detail ids (one station at a time, a pause between ranges, so the shared server keeps
/// serving the stations and the web); afterwards a report reads the open tail (the last days) and
/// seals what is old enough. Once a day the sealed ranges are read again to take edits of old mixes.
/// Only reads the station databases; the ledger lives in memory and in files of the API.
/// </summary>
internal sealed class MaterialMixingLedgerStore(
    IServiceScopeFactory scopeFactory,
    IOptions<MaterialReportingOptions> options,
    IHostEnvironment environment,
    TimeProvider timeProvider,
    ILogger<MaterialMixingLedgerStore> logger) : IMaterialMixingLedgerStore
{
    private static readonly TimeSpan VietnamOffset = TimeSpan.FromHours(7);
    private static readonly TimeSpan FailureCooldown = TimeSpan.FromMinutes(1);
    private static readonly TimeSpan SealAfterSeen = TimeSpan.FromHours(2);
    private const int SealMinDetails = 500;
    private static readonly TimeSpan[] ChunkRetryDelays = [TimeSpan.FromSeconds(5), TimeSpan.FromSeconds(20)];

    private readonly ConcurrentDictionary<string, StationLedger> stations = new(StringComparer.OrdinalIgnoreCase);
    private readonly Channel<StationLedger> builds = Channel.CreateUnbounded<StationLedger>();
    private readonly Channel<StationLedger> verifications = Channel.CreateUnbounded<StationLedger>();
    private readonly object directorySync = new();
    private string? directory;
    private bool directoryResolved;

    private MaterialReportingOptions Options => options.Value;

    public async Task<MaterialMixingLedger?> GetAsync(
        StationDatabaseTarget target,
        CancellationToken cancellationToken)
    {
        var station = GetStation(target);
        station.LastAccessUtc = UtcNow;
        if (station.Unsupported)
        {
            return null;
        }

        var ledger = station.Current ?? await LoadFromDiskAsync(station, cancellationToken);
        if (ledger is null)
        {
            var build = EnsureBuild(station);
            var wait = Task.Delay(TimeSpan.FromSeconds(Options.LedgerPrepareWaitSeconds), cancellationToken);
            if (await Task.WhenAny(build, wait) != build)
            {
                cancellationToken.ThrowIfCancellationRequested();
                throw new MaterialReportPreparingException(station.ProgressPercent);
            }
            try
            {
                await build;
            }
            catch (MaterialMixingLedgerUnsupportedException)
            {
                return null;
            }
            ledger = station.Current;
            if (ledger is null)
            {
                throw new MaterialReportPreparingException(station.ProgressPercent);
            }
        }

        return await RefreshIfDueAsync(station, cancellationToken) ?? ledger;
    }

    /// <summary>The daily check of a station right now; for tests.</summary>
    internal async Task VerifyNowAsync(StationDatabaseTarget target, CancellationToken cancellationToken)
    {
        var station = GetStation(target);
        await VerifyAsync(station, cancellationToken);
    }

    /// <summary>Runs the background reads, one station at a time; first reads before daily checks.</summary>
    public async Task RunAsync(CancellationToken stoppingToken)
    {
        var nextVerificationScan = UtcNow;
        while (!stoppingToken.IsCancellationRequested)
        {
            if (UtcNow >= nextVerificationScan)
            {
                QueueDueVerifications();
                nextVerificationScan = UtcNow.AddMinutes(10);
            }

            if (builds.Reader.TryRead(out var building))
            {
                await BuildAsync(building, stoppingToken);
                continue;
            }
            if (verifications.Reader.TryRead(out var verifying))
            {
                await VerifyAsync(verifying, stoppingToken);
                continue;
            }

            using var idle = CancellationTokenSource.CreateLinkedTokenSource(stoppingToken);
            idle.CancelAfter(TimeSpan.FromMinutes(10));
            try
            {
                await Task.WhenAny(
                    builds.Reader.WaitToReadAsync(idle.Token).AsTask(),
                    verifications.Reader.WaitToReadAsync(idle.Token).AsTask());
            }
            catch (OperationCanceledException) when (!stoppingToken.IsCancellationRequested)
            {
            }
            finally
            {
                idle.Cancel();
            }
        }
    }

    private StationLedger GetStation(StationDatabaseTarget target)
    {
        using var scope = scopeFactory.CreateScope();
        var databaseName = scope.ServiceProvider.GetRequiredService<IStationOperationsDbContextFactory>()
            .ResolveDatabaseName(target);
        var station = stations.GetOrAdd(
            $"{target.BranchId}:{databaseName}",
            _ => new StationLedger(target, databaseName));
        station.Target = target;
        return station;
    }

    private Task EnsureBuild(StationLedger station)
    {
        lock (station)
        {
            if (station.Build is { Task.IsCompleted: false } running)
            {
                return running.Task;
            }
            if (station.Failure is { } failure && UtcNow - station.FailedAtUtc < FailureCooldown)
            {
                return Task.FromException(failure);
            }

            station.Failure = null;
            station.Progress = 0;
            station.Build = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
            builds.Writer.TryWrite(station);
            return station.Build.Task;
        }
    }

    private async Task BuildAsync(StationLedger station, CancellationToken stoppingToken)
    {
        var completion = station.Build;
        if (completion is null || completion.Task.IsCompleted)
        {
            return;
        }

        var stopwatch = Stopwatch.StartNew();
        try
        {
            await using var session = await OpenAsync(station.Target, stoppingToken);
            var ledger = await ReadAllAsync(session.Connection, station, trackProgress: true, stoppingToken);
            await station.Lock.WaitAsync(stoppingToken);
            try
            {
                station.Current = ledger;
                station.LastRefreshUtc = UtcNow;
            }
            finally
            {
                station.Lock.Release();
            }
            completion.TrySetResult();
            logger.LogInformation(
                "Material mixing ledger built. BranchId={BranchId}, Chunks={Chunks}, Entries={Entries}, ElapsedMs={ElapsedMs}",
                station.Target.BranchId,
                ledger.SealedChunks.Count + 1,
                ledger.EntryCount,
                stopwatch.ElapsedMilliseconds);
            await SaveAsync(station, ledger);
            EvictIfNeeded(station);
        }
        catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
        {
            completion.TrySetCanceled(stoppingToken);
        }
        catch (MaterialMixingLedgerUnsupportedException exception)
        {
            station.Unsupported = true;
            logger.LogWarning(exception, "Material mixing ledger not used for branch {BranchId}", station.Target.BranchId);
            completion.TrySetException(exception);
        }
        catch (Exception exception)
        {
            lock (station)
            {
                station.Failure = exception;
                station.FailedAtUtc = UtcNow;
            }
            logger.LogWarning(
                exception,
                "Material mixing ledger build failed. BranchId={BranchId}, ElapsedMs={ElapsedMs}",
                station.Target.BranchId,
                stopwatch.ElapsedMilliseconds);
            completion.TrySetException(exception);
        }
    }

    /// <summary>Reads the whole history in chunks: old ranges sealed, the last days as the tail.</summary>
    private async Task<MaterialMixingLedger> ReadAllAsync(
        DbConnection connection,
        StationLedger station,
        bool trackProgress,
        CancellationToken cancellationToken)
    {
        var timeout = Options.CommandTimeoutSeconds;
        var now = UtcNow;
        if (!await MaterialMixingLedgerSql.HasMixingTablesAsync(connection, timeout, cancellationToken))
        {
            return MaterialMixingLedger.WithoutMixingTables(now);
        }

        var range = await MaterialMixingLedgerSql.GetDetailRangeAsync(connection, timeout, cancellationToken);
        var after = range is { } known ? known.Min - 1 : 0;
        var chunks = new List<MaterialMixingLedgerChunk>();
        if (range is { } history)
        {
            while (true)
            {
                var end = await MaterialMixingLedgerSql.FindChunkEndAsync(
                    connection, after, Options.LedgerChunkDetailRows, timeout, cancellationToken);
                if (end is null || end.Value >= history.Max)
                {
                    break;
                }
                chunks.Add(await ReadChunkWithRetryAsync(connection, station, after, end.Value, cancellationToken));
                after = end.Value;
                if (trackProgress)
                {
                    station.Progress = (double)(after - history.Min) / Math.Max(1, history.Max - history.Min);
                }
                await Task.Delay(TimeSpan.FromMilliseconds(Options.LedgerChunkPauseMilliseconds), cancellationToken);
            }
        }

        // The rest: what finished before the open days is sealed now, the last days stay open.
        var details = await MaterialMixingLedgerSql.ReadDetailsAsync(connection, after, long.MaxValue, timeout, cancellationToken);
        var sealTo = SealPoint(details, after, now, firstSeenUtc: null);
        if (sealTo > after)
        {
            chunks.Add(await ReadChunkWithRetryAsync(connection, station, after, sealTo, cancellationToken));
            after = sealTo;
        }
        var tail = await ReadChunkWithRetryAsync(connection, station, after, long.MaxValue, cancellationToken);
        var firstSeen = details.Where(item => item.DetailId > after).ToDictionary(item => item.DetailId, _ => now);
        return new MaterialMixingLedger(true, station.Names.SnapshotNames(), chunks, tail, firstSeen, now, now);
    }

    /// <summary>Reads the tail again and seals what is old enough; coalesced per station.</summary>
    private async Task<MaterialMixingLedger?> RefreshIfDueAsync(StationLedger station, CancellationToken cancellationToken)
    {
        var interval = TimeSpan.FromSeconds(Options.LedgerRefreshSeconds);
        if (UtcNow - station.LastRefreshUtc < interval)
        {
            return station.Current;
        }

        await station.Lock.WaitAsync(cancellationToken);
        try
        {
            var ledger = station.Current;
            if (ledger is null || UtcNow - station.LastRefreshUtc < interval)
            {
                return ledger;
            }
            if (!ledger.HasMixingTables)
            {
                station.LastRefreshUtc = UtcNow;
                return ledger;
            }

            var now = UtcNow;
            var timeout = Options.CommandTimeoutSeconds;
            await using var session = await OpenAsync(station.Target, cancellationToken);
            var connection = session.Connection;
            var details = await MaterialMixingLedgerSql.ReadDetailsAsync(
                connection, ledger.SealedUpTo, long.MaxValue, timeout, cancellationToken);
            var firstSeen = details.ToDictionary(
                item => item.DetailId,
                item => ledger.TailFirstSeenUtc.TryGetValue(item.DetailId, out var seenAt) ? seenAt : now);
            var sealTo = SealPoint(details, ledger.SealedUpTo, now, firstSeen);
            var sealable = details.Count(item => item.DetailId <= sealTo);

            MaterialMixingLedger refreshed;
            if (sealTo > ledger.SealedUpTo && sealable >= SealMinDetails)
            {
                var sealedChunk = await ReadChunkAsync(connection, station, ledger.SealedUpTo, sealTo, cancellationToken);
                var tail = await ReadChunkAsync(connection, station, sealTo, long.MaxValue, cancellationToken);
                foreach (var detail in details.Where(item => item.DetailId <= sealTo))
                {
                    firstSeen.Remove(detail.DetailId);
                }
                refreshed = new MaterialMixingLedger(
                    true,
                    station.Names.SnapshotNames(),
                    [.. ledger.SealedChunks, sealedChunk],
                    tail,
                    firstSeen,
                    ledger.BuiltAtUtc,
                    ledger.VerifiedAtUtc);
                station.Current = refreshed;
                station.LastRefreshUtc = now;
                _ = Task.Run(() => SaveAsync(station, refreshed), CancellationToken.None);
            }
            else
            {
                var tail = await ReadChunkAsync(connection, station, ledger.SealedUpTo, long.MaxValue, cancellationToken);
                refreshed = ledger.WithTail(tail, station.Names.SnapshotNames(), firstSeen);
                station.Current = refreshed;
                station.LastRefreshUtc = now;
            }
            return refreshed;
        }
        finally
        {
            station.Lock.Release();
        }
    }

    /// <summary>Reads the sealed ranges again (edits of old mixes) and swaps the ones that changed.</summary>
    private async Task VerifyAsync(StationLedger station, CancellationToken stoppingToken)
    {
        station.VerificationQueued = false;
        var ledger = station.Current;
        if (ledger is null)
        {
            return;
        }

        var stopwatch = Stopwatch.StartNew();
        try
        {
            await using var session = await OpenAsync(station.Target, stoppingToken);
            var connection = session.Connection;
            var hasTables = await MaterialMixingLedgerSql.HasMixingTablesAsync(
                connection, Options.CommandTimeoutSeconds, stoppingToken);
            if (hasTables != ledger.HasMixingTables)
            {
                // The station gained or lost its mixing tables: everything is read again.
                var rebuilt = await ReadAllAsync(connection, station, trackProgress: false, stoppingToken);
                await station.Lock.WaitAsync(stoppingToken);
                try
                {
                    station.Current = rebuilt;
                    station.LastRefreshUtc = UtcNow;
                }
                finally
                {
                    station.Lock.Release();
                }
                logger.LogWarning(
                    "Material mixing ledger rebuilt: mixing tables changed. BranchId={BranchId}",
                    station.Target.BranchId);
            }
            else
            {
                var replaced = new Dictionary<(long, long), MaterialMixingLedgerChunk>();
                foreach (var chunk in ledger.SealedChunks)
                {
                    var fresh = await ReadChunkWithRetryAsync(
                        connection, station, chunk.DetailAfter, chunk.DetailUpTo, stoppingToken);
                    if (!fresh.SameContentAs(chunk))
                    {
                        replaced[(chunk.DetailAfter, chunk.DetailUpTo)] = fresh;
                    }
                    await Task.Delay(TimeSpan.FromMilliseconds(Options.LedgerChunkPauseMilliseconds), stoppingToken);
                }

                await station.Lock.WaitAsync(stoppingToken);
                try
                {
                    // Ranges sealed meanwhile stay; only the ranges read again are swapped.
                    var current = station.Current ?? ledger;
                    station.Current = new MaterialMixingLedger(
                        current.HasMixingTables,
                        station.Names.SnapshotNames(),
                        current.SealedChunks
                            .Select(chunk => replaced.GetValueOrDefault((chunk.DetailAfter, chunk.DetailUpTo)) ?? chunk)
                            .ToArray(),
                        current.Tail,
                        current.TailFirstSeenUtc,
                        current.BuiltAtUtc,
                        UtcNow,
                        replaced.Count == 0 ? current.SealedSplitMixes : null);
                }
                finally
                {
                    station.Lock.Release();
                }
                if (replaced.Count > 0)
                {
                    logger.LogWarning(
                        "Material mixing ledger corrected by the daily check. BranchId={BranchId}, ChangedChunks={ChangedChunks}",
                        station.Target.BranchId,
                        replaced.Count);
                }
            }

            logger.LogInformation(
                "Material mixing ledger checked. BranchId={BranchId}, ElapsedMs={ElapsedMs}",
                station.Target.BranchId,
                stopwatch.ElapsedMilliseconds);
            if (station.Current is { } checkedLedger)
            {
                await SaveAsync(station, checkedLedger);
            }
        }
        catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
        {
        }
        catch (MaterialMixingLedgerUnsupportedException exception)
        {
            station.Unsupported = true;
            station.Current = null;
            logger.LogWarning(exception, "Material mixing ledger not used for branch {BranchId}", station.Target.BranchId);
        }
        catch (Exception exception)
        {
            // Checked again at a later scan; the ledger in use stays.
            logger.LogWarning(exception, "Material mixing ledger check failed. BranchId={BranchId}", station.Target.BranchId);
        }
    }

    private void QueueDueVerifications()
    {
        var now = UtcNow;
        foreach (var station in stations.Values)
        {
            if (station.Current is { } ledger &&
                !station.VerificationQueued &&
                now - ledger.VerifiedAtUtc >= TimeSpan.FromHours(Options.LedgerVerifyHours) &&
                now - station.LastAccessUtc <= TimeSpan.FromDays(7))
            {
                station.VerificationQueued = true;
                verifications.Writer.TryWrite(station);
            }
        }
    }

    /// <summary>
    /// The last detail id of the prefix that no longer changes: its mix finished before the open days
    /// and, after the first read, it was already seen some time ago (details can arrive late).
    /// </summary>
    private long SealPoint(
        IReadOnlyList<MaterialMixingDetail> details,
        long after,
        DateTime nowUtc,
        IReadOnlyDictionary<long, DateTime>? firstSeenUtc)
    {
        var cutoffLocal = nowUtc.Add(VietnamOffset).AddDays(-Options.LedgerOpenDays);
        var sealTo = after;
        foreach (var detail in details)
        {
            if (detail.Finish7 is not { } finish || finish > cutoffLocal)
            {
                break;
            }
            if (firstSeenUtc is not null &&
                (!firstSeenUtc.TryGetValue(detail.DetailId, out var seenAt) || nowUtc - seenAt < SealAfterSeen))
            {
                break;
            }
            sealTo = detail.DetailId;
        }
        return sealTo;
    }

    private async Task<MaterialMixingLedgerChunk> ReadChunkWithRetryAsync(
        DbConnection connection,
        StationLedger station,
        long after,
        long upTo,
        CancellationToken cancellationToken)
    {
        for (var attempt = 0; ; attempt++)
        {
            try
            {
                return await ReadChunkAsync(connection, station, after, upTo, cancellationToken);
            }
            catch (DbException exception) when (attempt < ChunkRetryDelays.Length)
            {
                logger.LogWarning(
                    exception,
                    "Material mixing ledger chunk read failed, retrying. BranchId={BranchId}, After={After}",
                    station.Target.BranchId,
                    after);
                await Task.Delay(ChunkRetryDelays[attempt], cancellationToken);
                if (connection.State != System.Data.ConnectionState.Open)
                {
                    await connection.OpenAsync(cancellationToken);
                }
            }
        }
    }

    private async Task<MaterialMixingLedgerChunk> ReadChunkAsync(
        DbConnection connection,
        StationLedger station,
        long after,
        long upTo,
        CancellationToken cancellationToken)
    {
        var timeout = Options.CommandTimeoutSeconds;
        var rows = await MaterialMixingLedgerSql.ReadChunkAsync(connection, after, upTo, timeout, cancellationToken);
        var unknown = rows
            .Where(row => !station.Names.TryGetIndex(row.NameHash, out _))
            .GroupBy(row => row.NameHash, StringComparer.Ordinal)
            .ToDictionary(group => group.Key, group => group.Min(row => row.NameSourceId), StringComparer.Ordinal);
        if (unknown.Count > 0)
        {
            var names = await MaterialMixingLedgerSql.ReadNamesAsync(connection, unknown.Values, timeout, cancellationToken);
            foreach (var (hash, sourceId) in unknown)
            {
                station.Names.Add(hash, names.GetValueOrDefault(sourceId) ?? string.Empty);
            }
        }

        return MaterialMixingLedgerChunk.Create(after, upTo, rows.Select(row =>
        {
            station.Names.TryGetIndex(row.NameHash, out var nameIndex);
            return new MaterialMixingLedgerRow(row.MixId, row.Finish3, row.Finish7, row.Slot, nameIndex, row.QuantityKg);
        }));
    }

    private async Task<MaterialMixingLedger?> LoadFromDiskAsync(StationLedger station, CancellationToken cancellationToken)
    {
        await station.Lock.WaitAsync(cancellationToken);
        try
        {
            if (station.Current is { } loaded || station.DiskChecked)
            {
                return station.Current;
            }
            station.DiskChecked = true;
            var path = FilePath(station);
            if (path is null)
            {
                return null;
            }

            try
            {
                var saved = MaterialMixingLedgerFile.Load(path, station.Target.BranchId, station.DatabaseName);
                if (saved is not { } found)
                {
                    return null;
                }
                station.Names = new MaterialMixingNameTable(found.Names);
                station.Current = found.Ledger;
                // The tail is read again at once: the file may be hours old.
                station.LastRefreshUtc = DateTime.MinValue;
                station.Saved = true;
                if (UtcNow - found.Ledger.VerifiedAtUtc >= TimeSpan.FromHours(Options.LedgerVerifyHours) &&
                    !station.VerificationQueued)
                {
                    station.VerificationQueued = true;
                    verifications.Writer.TryWrite(station);
                }
                EvictIfNeeded(station);
                return found.Ledger;
            }
            catch (Exception exception) when (exception is IOException or InvalidDataException or EndOfStreamException or UnauthorizedAccessException)
            {
                logger.LogWarning(exception, "Material mixing ledger file ignored. BranchId={BranchId}", station.Target.BranchId);
                return null;
            }
        }
        finally
        {
            station.Lock.Release();
        }
    }

    private async Task SaveAsync(StationLedger station, MaterialMixingLedger ledger)
    {
        var path = FilePath(station);
        if (path is null)
        {
            return;
        }

        await station.SaveLock.WaitAsync();
        try
        {
            if (!ReferenceEquals(station.Current, ledger) && station.Current is not null)
            {
                ledger = station.Current;
            }
            MaterialMixingLedgerFile.Save(
                path,
                station.Target.BranchId,
                station.DatabaseName,
                ledger,
                station.Names.SnapshotEntries());
            station.Saved = true;
        }
        catch (Exception exception) when (exception is IOException or UnauthorizedAccessException)
        {
            logger.LogWarning(exception, "Material mixing ledger file not saved. BranchId={BranchId}", station.Target.BranchId);
        }
        finally
        {
            station.SaveLock.Release();
        }
    }

    /// <summary>Drops the least recently used ledgers that are saved when memory is over the limit.</summary>
    private void EvictIfNeeded(StationLedger keep)
    {
        var total = stations.Values.Sum(item => item.Current?.EntryCount ?? 0);
        if (total <= Options.LedgerMaxEntriesInMemory)
        {
            return;
        }
        foreach (var station in stations.Values
                     .Where(item => item != keep && item.Current is not null && item.Saved)
                     .OrderBy(item => item.LastAccessUtc))
        {
            if (total <= Options.LedgerMaxEntriesInMemory)
            {
                break;
            }
            if (!station.Lock.Wait(0))
            {
                continue;
            }
            try
            {
                total -= station.Current?.EntryCount ?? 0;
                station.Current = null;
                station.DiskChecked = false;
            }
            finally
            {
                station.Lock.Release();
            }
        }
    }

    private string? FilePath(StationLedger station)
    {
        var folder = ResolveDirectory();
        return folder is null ? null : Path.Combine(folder, $"{station.Target.BranchId}-{station.DatabaseName}.ledger");
    }

    /// <summary>The configured folder, else App_Data of the API, else the temp folder; null when none can be written.</summary>
    private string? ResolveDirectory()
    {
        lock (directorySync)
        {
            if (directoryResolved)
            {
                return directory;
            }
            directoryResolved = true;
            var candidates = new[]
            {
                Options.LedgerDirectory,
                Path.Combine(environment.ContentRootPath, "App_Data", "material-ledger"),
                Path.Combine(Path.GetTempPath(), "TTSmart", "material-ledger")
            };
            foreach (var candidate in candidates.Where(item => !string.IsNullOrWhiteSpace(item)))
            {
                try
                {
                    Directory.CreateDirectory(candidate!);
                    var probe = Path.Combine(candidate!, $".write-{Guid.NewGuid():N}");
                    File.WriteAllBytes(probe, []);
                    File.Delete(probe);
                    directory = candidate;
                    logger.LogInformation("Material mixing ledger files in {Directory}", candidate);
                    return directory;
                }
                catch (Exception exception) when (exception is IOException or UnauthorizedAccessException)
                {
                    logger.LogWarning("Material mixing ledger cannot write to {Directory}: {Error}", candidate, exception.Message);
                }
            }
            logger.LogWarning("Material mixing ledger kept in memory only.");
            return null;
        }
    }

    private async Task<StationSession> OpenAsync(StationDatabaseTarget target, CancellationToken cancellationToken)
    {
        var scope = scopeFactory.CreateScope();
        try
        {
            var dbContext = scope.ServiceProvider.GetRequiredService<IStationOperationsDbContextFactory>().Create(target);
            await dbContext.Database.OpenConnectionAsync(cancellationToken);
            return new StationSession(scope, dbContext);
        }
        catch
        {
            scope.Dispose();
            throw;
        }
    }

    private DateTime UtcNow => timeProvider.GetUtcNow().UtcDateTime;

    private sealed class StationSession(IServiceScope scope, StationOperationsDbContext dbContext) : IAsyncDisposable
    {
        public DbConnection Connection => dbContext.Database.GetDbConnection();

        public async ValueTask DisposeAsync()
        {
            await dbContext.DisposeAsync();
            scope.Dispose();
        }
    }

    private sealed class StationLedger(StationDatabaseTarget target, string databaseName)
    {
        public StationDatabaseTarget Target { get; set; } = target;
        public string DatabaseName { get; } = databaseName;
        public SemaphoreSlim Lock { get; } = new(1, 1);
        public SemaphoreSlim SaveLock { get; } = new(1, 1);
        private volatile MaterialMixingLedger? current;

        public MaterialMixingNameTable Names { get; set; } = new();

        /// <summary>The ledger in use; replaced whole, read without the lock.</summary>
        public MaterialMixingLedger? Current
        {
            get => current;
            set => current = value;
        }
        public TaskCompletionSource? Build { get; set; }
        public double Progress { get; set; }
        public int ProgressPercent => (int)Math.Clamp(Math.Floor(Progress * 100), 0, 99);
        public DateTime LastRefreshUtc { get; set; }
        public DateTime LastAccessUtc { get; set; }
        public Exception? Failure { get; set; }
        public DateTime FailedAtUtc { get; set; }
        public bool Unsupported { get; set; }
        public bool DiskChecked { get; set; }
        public bool Saved { get; set; }
        public bool VerificationQueued { get; set; }
    }
}

/// <summary>Runs the ledger's background reads.</summary>
internal sealed class MaterialMixingLedgerWorker(
    MaterialMixingLedgerStore store,
    IOptions<MaterialReportingOptions> options) : BackgroundService
{
    protected override Task ExecuteAsync(CancellationToken stoppingToken) =>
        options.Value.UseMixingLedger ? store.RunAsync(stoppingToken) : Task.CompletedTask;
}
