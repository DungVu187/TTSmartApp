using System.Globalization;
using System.Text;

namespace TTSmart.Api.Features.MaterialReporting;

/// <summary>An instant that splits mixing consumption for FIFO.</summary>
/// <param name="BucketNo">Position in time order; the bucket that starts at this instant.</param>
/// <param name="IsIssue">Another issue (scale sale, manual export/stocktake) happens at this instant.</param>
internal sealed record MaterialFifoBoundary(int BucketNo, DateTime At, bool IsIssue);

/// <summary>One row of the mixing query: the consumption of a material slot in a bucket.</summary>
/// <param name="TieMixingId">Set when the mix finished exactly at an issue boundary: the row is that single mix.</param>
internal sealed record MaterialMixingBucketRow(
    int BucketNo,
    long? TieMixingId,
    int? MaterialCode,
    int? SlotNumber,
    string? MaterialName,
    decimal QuantityKg);

/// <summary>
/// Mixing history holds one consumption per mix and material slot (millions of rows on a busy
/// station). For FIFO only the events that can change what a mix consumes matter: lot arrivals
/// and the other issues. Between two such instants consecutive mixes of a material take from the
/// same lots one after another, so their sum consumes and values exactly like the single mixes;
/// the query adds them up per bucket and only returns a few rows.
/// </summary>
internal static class MaterialMixingBuckets
{
    /// <summary>Start of the first bucket, before any lot or issue.</summary>
    internal static readonly DateTime Origin = new(1, 1, 1);

    /// <summary>Above every source sequence, so a bucket sorts after the issue it starts at.</summary>
    internal const long BucketSequenceBase = 4_000_000_000_000_000_000;

    /// <summary>
    /// Boundaries in time order: the origin, every lot arrival and every other issue up to
    /// <paramref name="toLocal"/>, and the start of the period (the summary export only counts
    /// the issues from it on). Instants are rounded up to the millisecond of the mixing times.
    /// </summary>
    public static IReadOnlyList<MaterialFifoBoundary> BuildBoundaries(
        IEnumerable<MaterialImportLot> imports,
        IEnumerable<MaterialIssueEvent> issues,
        DateTime fromLocal,
        DateTime toLocal)
    {
        var instants = new SortedDictionary<DateTime, bool> { [Origin] = false };

        void Add(DateTime at, bool isIssue)
        {
            var instant = CeilingToMillisecond(at);
            if (instant <= toLocal)
            {
                instants[instant] = instants.GetValueOrDefault(instant) || isIssue;
            }
        }

        foreach (var import in imports)
        {
            if (import.QuantityKg > 0)
            {
                Add(import.OccurredAt, false);
            }
        }
        foreach (var issue in issues)
        {
            if (issue.QuantityKg > 0)
            {
                Add(issue.OccurredAt, true);
            }
        }
        Add(fromLocal, false);

        var index = 0;
        return instants.Select(pair => new MaterialFifoBoundary(index++, pair.Key, pair.Value)).ToArray();
    }

    /// <summary>The boundaries as the XML read by the mixing query.</summary>
    public static string ToXml(IReadOnlyList<MaterialFifoBoundary> boundaries)
    {
        var builder = new StringBuilder(boundaries.Count * 56 + 7);
        builder.Append("<r>");
        foreach (var boundary in boundaries)
        {
            builder.Append("<b n=\"")
                .Append(boundary.BucketNo.ToString(CultureInfo.InvariantCulture))
                .Append("\" t=\"")
                .Append(boundary.At.ToString("yyyy-MM-dd'T'HH:mm:ss.fff", CultureInfo.InvariantCulture))
                .Append("\" i=\"")
                .Append(boundary.IsIssue ? '1' : '0')
                .Append("\"/>");
        }
        return builder.Append("</r>").ToString();
    }

    /// <summary>
    /// The issue events of the rows: a bucket is one event at its start instant, after the issue
    /// there (if any); a tie keeps the single mix at its own time and sequence, as before.
    /// </summary>
    public static IReadOnlyList<MaterialIssueEvent> ToIssueEvents(
        IEnumerable<MaterialMixingBucketRow> rows,
        IReadOnlyList<MaterialFifoBoundary> boundaries)
    {
        var events = new List<MaterialIssueEvent>();
        var sourceIds = new HashSet<string>(StringComparer.Ordinal);
        foreach (var row in rows)
        {
            if (row.QuantityKg <= 0)
            {
                continue;
            }

            var boundary = boundaries[row.BucketNo];
            var identity = row.MaterialCode ?? row.SlotNumber ?? 0;
            var identityText = identity.ToString(CultureInfo.InvariantCulture);
            string sourceId;
            long sequence;
            if (row.TieMixingId is { } mixingId)
            {
                sourceId = $"mix:{mixingId.ToString(CultureInfo.InvariantCulture)}:{identityText}";
                sequence = checked(mixingId * 100 + identity);
            }
            else
            {
                sourceId = $"mix-bucket:{boundary.BucketNo.ToString(CultureInfo.InvariantCulture)}:{identityText}";
                sequence = BucketSequenceBase + events.Count;
            }

            // Two historical names of a slot no longer in CUAVL give two rows; keep both.
            var uniqueSourceId = sourceId;
            for (var suffix = 2; !sourceIds.Add(uniqueSourceId); suffix++)
            {
                uniqueSourceId = $"{sourceId}:{suffix.ToString(CultureInfo.InvariantCulture)}";
            }

            events.Add(new MaterialIssueEvent(
                uniqueSourceId,
                sequence,
                row.MaterialCode,
                row.SlotNumber,
                row.MaterialName,
                boundary.At,
                row.QuantityKg));
        }
        return events;
    }

    private static DateTime CeilingToMillisecond(DateTime value)
    {
        var remainder = value.Ticks % TimeSpan.TicksPerMillisecond;
        return remainder == 0 ? value : value.AddTicks(TimeSpan.TicksPerMillisecond - remainder);
    }
}
