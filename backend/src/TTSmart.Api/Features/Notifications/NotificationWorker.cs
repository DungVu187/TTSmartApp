using System.Diagnostics;
using Microsoft.Extensions.Options;

namespace TTSmart.Api.Features.Notifications;

public sealed class NotificationWorker(
    IServiceScopeFactory scopeFactory,
    IOptions<NotificationOptions> options,
    TimeProvider timeProvider,
    ILogger<NotificationWorker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        if (!options.Value.Enabled) return;

        var configuration = options.Value;
        var schedule = new NotificationStationSchedule();
        var activeScans = new HashSet<Task>();
        using var gate = new SemaphoreSlim(configuration.MaxParallelStations, configuration.MaxParallelStations);
        var nextRosterRefreshAtUtc = DateTimeOffset.MinValue;

        try
        {
            while (!stoppingToken.IsCancellationRequested)
            {
                var now = timeProvider.GetUtcNow();
                if (now >= nextRosterRefreshAtUtc)
                {
                    await RefreshRosterAsync(schedule, now, stoppingToken);
                    nextRosterRefreshAtUtc = now.AddSeconds(configuration.StationRosterRefreshSeconds);
                }

                foreach (var station in schedule.StartDue(now))
                {
                    var scanTask = ScanStationAsync(station, schedule, gate, configuration, stoppingToken);
                    activeScans.Add(scanTask);
                }

                activeScans.RemoveWhere(task => task.IsCompleted);
                await Task.Delay(TimeSpan.FromSeconds(1), stoppingToken);
            }
        }
        catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
        {
        }
        finally
        {
            try
            {
                await Task.WhenAll(activeScans);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
            }
        }
    }

    private async Task RefreshRosterAsync(
        NotificationStationSchedule schedule,
        DateTimeOffset now,
        CancellationToken cancellationToken)
    {
        try
        {
            using var rosterScope = scopeFactory.CreateScope();
            var stations = await rosterScope.ServiceProvider.GetRequiredService<INotificationStationSource>()
                .GetActiveMixingStationsAsync(cancellationToken);
            schedule.Synchronize(stations, now);
            logger.LogInformation("Notification station roster refreshed: {StationCount} active mixing stations.", stations.Count);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception exception)
        {
            logger.LogWarning("Notification station roster refresh failed: {ExceptionType}.", exception.GetType().Name);
        }
    }

    private async Task ScanStationAsync(
        NotificationStation station,
        NotificationStationSchedule schedule,
        SemaphoreSlim gate,
        NotificationOptions configuration,
        CancellationToken stoppingToken)
    {
        await gate.WaitAsync(stoppingToken);
        var started = Stopwatch.GetTimestamp();
        try
        {
            using var timeoutSource = CancellationTokenSource.CreateLinkedTokenSource(stoppingToken);
            timeoutSource.CancelAfter(TimeSpan.FromSeconds(configuration.StationScanTimeoutSeconds));
            using var stationScope = scopeFactory.CreateScope();
            var result = await stationScope.ServiceProvider.GetRequiredService<IOrderCreatedDetector>()
                .DetectAsync(station, timeoutSource.Token);
            schedule.CompleteSuccess(
                station.Id,
                timeProvider.GetUtcNow(),
                TimeSpan.FromSeconds(configuration.PollingIntervalSeconds));
            logger.LogInformation(
                "Notification scan completed for station {StationId}: observed {ObservedCount}, created {CreatedEventCount}, baseline {WasBaseline}, elapsed {ElapsedMilliseconds}ms.",
                station.Id,
                result.ObservedCount,
                result.CreatedEventCount,
                result.WasBaseline,
                Stopwatch.GetElapsedTime(started).TotalMilliseconds);
        }
        catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception exception)
        {
            var failureCount = schedule.CompleteFailure(
                station.Id,
                timeProvider.GetUtcNow(),
                TimeSpan.FromSeconds(configuration.FailedStationInitialBackoffSeconds),
                TimeSpan.FromSeconds(configuration.FailedStationMaxBackoffSeconds));
            logger.LogWarning(
                "Notification scan failed for station {StationId}: {ExceptionType}; consecutive failures {FailureCount}.",
                station.Id,
                exception.GetType().Name,
                failureCount);
        }
        finally
        {
            gate.Release();
        }
    }
}
