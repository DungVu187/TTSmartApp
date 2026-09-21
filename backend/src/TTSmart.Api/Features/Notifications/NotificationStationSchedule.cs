namespace TTSmart.Api.Features.Notifications;

public sealed class NotificationStationSchedule
{
    private readonly object synchronization = new();
    private readonly Dictionary<int, ScheduledStation> stations = [];

    public void Synchronize(IEnumerable<NotificationStation> roster, DateTimeOffset now)
    {
        lock (synchronization)
        {
            var currentStations = roster.ToDictionary(station => station.Id);
            foreach (var removedStationId in stations.Keys.Except(currentStations.Keys).ToArray())
            {
                stations.Remove(removedStationId);
            }

            foreach (var station in currentStations.Values)
            {
                if (stations.TryGetValue(station.Id, out var scheduledStation))
                {
                    scheduledStation.Station = station;
                }
                else
                {
                    stations.Add(station.Id, new ScheduledStation(station, now));
                }
            }
        }
    }

    public IReadOnlyList<NotificationStation> StartDue(DateTimeOffset now)
    {
        lock (synchronization)
        {
            return stations.Values
                .Where(item => !item.IsInProgress && item.NextDueAtUtc <= now)
                .OrderBy(item => item.NextDueAtUtc)
                .ThenBy(item => item.Station.Id)
                .Select(item =>
                {
                    item.IsInProgress = true;
                    return item.Station;
                })
                .ToArray();
        }
    }

    public void CompleteSuccess(int stationId, DateTimeOffset completedAtUtc, TimeSpan pollingInterval)
    {
        lock (synchronization)
        {
            if (!stations.TryGetValue(stationId, out var station)) return;
            station.IsInProgress = false;
            station.ConsecutiveFailures = 0;
            station.NextDueAtUtc = completedAtUtc.Add(pollingInterval);
        }
    }

    public int CompleteFailure(
        int stationId,
        DateTimeOffset completedAtUtc,
        TimeSpan initialBackoff,
        TimeSpan maximumBackoff)
    {
        lock (synchronization)
        {
            if (!stations.TryGetValue(stationId, out var station)) return 0;
            station.IsInProgress = false;
            station.ConsecutiveFailures++;
            var multiplier = Math.Pow(2, Math.Min(station.ConsecutiveFailures - 1, 30));
            var backoff = TimeSpan.FromMilliseconds(Math.Min(
                maximumBackoff.TotalMilliseconds,
                initialBackoff.TotalMilliseconds * multiplier));
            station.NextDueAtUtc = completedAtUtc.Add(backoff);
            return station.ConsecutiveFailures;
        }
    }

    private sealed class ScheduledStation(NotificationStation station, DateTimeOffset nextDueAtUtc)
    {
        public NotificationStation Station { get; set; } = station;
        public DateTimeOffset NextDueAtUtc { get; set; } = nextDueAtUtc;
        public bool IsInProgress { get; set; }
        public int ConsecutiveFailures { get; set; }
    }
}
