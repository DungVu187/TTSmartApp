namespace TTSmart.Api.Features.MaterialReporting;

/// <summary>
/// One range of mixing detail ids (LSCHITIETMETRON) read from the station: per mix, its finish
/// time; per mix, slot and historical name of the slot, the consumption summed like the mixing
/// query (each detail row rounded to the kg first). Immutable; a new read replaces it whole.
/// </summary>
internal sealed class MaterialMixingLedgerChunk
{
    /// <summary>A slot that is NULL in LSCUAVL.</summary>
    public const int NoSlot = int.MinValue;

    public MaterialMixingLedgerChunk(
        long detailAfter,
        long detailUpTo,
        long[] mixIds,
        long[] finish3Ticks,
        long[] finish7Ticks,
        int[] mixEntryStart,
        int[] slots,
        int[] nameIndexes,
        long[] quantities)
    {
        DetailAfter = detailAfter;
        DetailUpTo = detailUpTo;
        MixIds = mixIds;
        Finish3Ticks = finish3Ticks;
        Finish7Ticks = finish7Ticks;
        MixEntryStart = mixEntryStart;
        Slots = slots;
        NameIndexes = nameIndexes;
        Quantities = quantities;
    }

    /// <summary>Exclusive lower detail id.</summary>
    public long DetailAfter { get; }

    /// <summary>Inclusive upper detail id; <see cref="long.MaxValue"/> for the open tail.</summary>
    public long DetailUpTo { get; }

    /// <summary>Mixes in id order.</summary>
    public long[] MixIds { get; }

    /// <summary>GIOXONG as datetime2(3): what the boundaries are compared with.</summary>
    public long[] Finish3Ticks { get; }

    /// <summary>GIOXONG as datetime2(7): what "GIOXONG &lt;= @To" compares.</summary>
    public long[] Finish7Ticks { get; }

    /// <summary>First entry of each mix; one more item than mixes.</summary>
    public int[] MixEntryStart { get; }

    /// <summary>Per entry, in (slot, name) order within a mix.</summary>
    public int[] Slots { get; }

    public int[] NameIndexes { get; }

    public long[] Quantities { get; }

    public int EntryCount => Slots.Length;

    public long MinMixId => MixIds.Length == 0 ? long.MaxValue : MixIds[0];

    public long MaxMixId => MixIds.Length == 0 ? long.MinValue : MixIds[^1];

    public static MaterialMixingLedgerChunk Empty(long detailAfter, long detailUpTo) =>
        new(detailAfter, detailUpTo, [], [], [], [0], [], [], []);

    /// <summary>Builds a chunk from the rows of the chunk query, in any order.</summary>
    public static MaterialMixingLedgerChunk Create(
        long detailAfter,
        long detailUpTo,
        IEnumerable<MaterialMixingLedgerRow> rows)
    {
        var ordered = rows
            .OrderBy(row => row.MixId)
            .ThenBy(row => row.Slot ?? NoSlot)
            .ThenBy(row => row.NameIndex)
            .ToArray();
        var mixIds = new List<long>();
        var finish3 = new List<long>();
        var finish7 = new List<long>();
        var starts = new List<int>();
        var slots = new int[ordered.Length];
        var names = new int[ordered.Length];
        var quantities = new long[ordered.Length];
        for (var index = 0; index < ordered.Length; index++)
        {
            var row = ordered[index];
            if (mixIds.Count == 0 || mixIds[^1] != row.MixId)
            {
                mixIds.Add(row.MixId);
                finish3.Add(row.Finish3.Ticks);
                finish7.Add(row.Finish7.Ticks);
                starts.Add(index);
            }
            slots[index] = row.Slot ?? NoSlot;
            names[index] = row.NameIndex;
            quantities[index] = row.QuantityKg;
        }
        starts.Add(ordered.Length);
        return new MaterialMixingLedgerChunk(
            detailAfter,
            detailUpTo,
            [.. mixIds],
            [.. finish3],
            [.. finish7],
            [.. starts],
            slots,
            names,
            quantities);
    }

    /// <summary>Same range and the same numbers.</summary>
    public bool SameContentAs(MaterialMixingLedgerChunk other) =>
        DetailAfter == other.DetailAfter &&
        DetailUpTo == other.DetailUpTo &&
        MixIds.AsSpan().SequenceEqual(other.MixIds) &&
        Finish3Ticks.AsSpan().SequenceEqual(other.Finish3Ticks) &&
        Finish7Ticks.AsSpan().SequenceEqual(other.Finish7Ticks) &&
        MixEntryStart.AsSpan().SequenceEqual(other.MixEntryStart) &&
        Slots.AsSpan().SequenceEqual(other.Slots) &&
        NameIndexes.AsSpan().SequenceEqual(other.NameIndexes) &&
        Quantities.AsSpan().SequenceEqual(other.Quantities);
}

/// <summary>One row of the chunk query with its name resolved to the ledger's name list.</summary>
internal readonly record struct MaterialMixingLedgerRow(
    long MixId,
    DateTime Finish3,
    DateTime Finish7,
    int? Slot,
    int NameIndex,
    long QuantityKg);

/// <summary>
/// The mixing consumption of a station, kept so a report does not add up the whole history on the
/// station database again: sealed chunks that no longer change, plus the open tail (the last days,
/// read again on every refresh). Replaces only the mixing query; lots, other issues and FIFO are
/// computed as before. Immutable: every change makes a new ledger.
/// </summary>
internal sealed class MaterialMixingLedger
{
    private readonly HashSet<long> splitMixes;

    public MaterialMixingLedger(
        bool hasMixingTables,
        IReadOnlyList<string> names,
        IReadOnlyList<MaterialMixingLedgerChunk> sealedChunks,
        MaterialMixingLedgerChunk tail,
        IReadOnlyDictionary<long, DateTime> tailFirstSeenUtc,
        DateTime builtAtUtc,
        DateTime verifiedAtUtc,
        IReadOnlySet<long>? sealedSplitMixes = null)
    {
        HasMixingTables = hasMixingTables;
        Names = names;
        SealedChunks = sealedChunks;
        Tail = tail;
        TailFirstSeenUtc = tailFirstSeenUtc;
        BuiltAtUtc = builtAtUtc;
        VerifiedAtUtc = verifiedAtUtc;
        SealedSplitMixes = sealedSplitMixes ?? FindSplitMixes(sealedChunks);
        splitMixes = [.. SealedSplitMixes];
        foreach (var mixId in FindSharedMixes(tail, sealedChunks))
        {
            splitMixes.Add(mixId);
        }
        EntryCount = sealedChunks.Sum(chunk => (long)chunk.EntryCount) + tail.EntryCount;
    }

    /// <summary>False when the station has no mixing history tables.</summary>
    public bool HasMixingTables { get; }

    /// <summary>Historical slot names (LSCUAVL.TENCUAVL) by index, see <see cref="MaterialMixingNameTable"/>.</summary>
    public IReadOnlyList<string> Names { get; }

    public IReadOnlyList<MaterialMixingLedgerChunk> SealedChunks { get; }

    public MaterialMixingLedgerChunk Tail { get; }

    /// <summary>When each detail id of the tail was first read: a late one is not sealed at once.</summary>
    public IReadOnlyDictionary<long, DateTime> TailFirstSeenUtc { get; }

    public DateTime BuiltAtUtc { get; }

    public DateTime VerifiedAtUtc { get; }

    /// <summary>Mixes whose details fall in more than one sealed chunk.</summary>
    public IReadOnlySet<long> SealedSplitMixes { get; }

    public long SealedUpTo => Tail.DetailAfter;

    public long EntryCount { get; }

    public static MaterialMixingLedger WithoutMixingTables(DateTime nowUtc) => new(
        false,
        [],
        [],
        MaterialMixingLedgerChunk.Empty(0, long.MaxValue),
        new Dictionary<long, DateTime>(),
        nowUtc,
        nowUtc,
        new HashSet<long>());

    public MaterialMixingLedger WithTail(
        MaterialMixingLedgerChunk tail,
        IReadOnlyList<string> names,
        IReadOnlyDictionary<long, DateTime> tailFirstSeenUtc) => new(
        HasMixingTables,
        names,
        SealedChunks,
        tail,
        tailFirstSeenUtc,
        BuiltAtUtc,
        VerifiedAtUtc,
        SealedSplitMixes);

    /// <summary>
    /// The rows the bucketed mixing query returns for these boundaries: per mix, the slots still in
    /// CUAVL are mapped by slot number whatever their historical name, the others keep their name;
    /// a mix counts for a key only when its consumption there is positive and it finished by
    /// <paramref name="toLocal"/>; mixes are added up per bucket (the last boundary at or before
    /// their finish), except a mix finishing exactly at an issue boundary, which stays on its own.
    /// </summary>
    public IReadOnlyList<MaterialMixingBucketRow> ToBucketRows(
        IReadOnlyList<MaterialDefinition> materials,
        IReadOnlyList<MaterialFifoBoundary> boundaries,
        DateTime toLocal)
    {
        if (!HasMixingTables || boundaries.Count == 0)
        {
            return [];
        }

        var currentSlots = materials.Select(item => item.SlotNumber).ToHashSet();
        var boundaryTicks = boundaries.Select(item => item.At.Ticks).ToArray();
        var toTicks = toLocal.Ticks;
        var totals = new Dictionary<BucketKey, long>();
        var pending = new Dictionary<long, PendingMix>();
        var keys = new List<(int Slot, int Name, long Quantity)>();

        foreach (var chunk in SealedChunks.Append(Tail))
        {
            for (var mix = 0; mix < chunk.MixIds.Length; mix++)
            {
                if (chunk.Finish7Ticks[mix] > toTicks)
                {
                    continue;
                }

                var mixId = chunk.MixIds[mix];
                var start = chunk.MixEntryStart[mix];
                var end = chunk.MixEntryStart[mix + 1];
                if (splitMixes.Contains(mixId))
                {
                    if (!pending.TryGetValue(mixId, out var split))
                    {
                        split = new PendingMix(chunk.Finish3Ticks[mix]);
                        pending.Add(mixId, split);
                    }
                    for (var entry = start; entry < end; entry++)
                    {
                        split.Entries.Add((chunk.Slots[entry], chunk.NameIndexes[entry], chunk.Quantities[entry]));
                    }
                    continue;
                }

                keys.Clear();
                for (var entry = start; entry < end; entry++)
                {
                    keys.Add((chunk.Slots[entry], chunk.NameIndexes[entry], chunk.Quantities[entry]));
                }
                AddMix(mixId, chunk.Finish3Ticks[mix], keys);
            }
        }

        foreach (var (mixId, split) in pending.OrderBy(pair => pair.Key))
        {
            split.Entries.Sort((left, right) =>
                left.Slot != right.Slot ? left.Slot.CompareTo(right.Slot) : left.Name.CompareTo(right.Name));
            AddMix(mixId, split.Finish3Ticks, split.Entries);
        }

        var materialsBySlot = materials
            .GroupBy(item => item.SlotNumber)
            .ToDictionary(group => group.Key, group => group.ToArray());
        var rows = new List<MaterialMixingBucketRow>(totals.Count);
        foreach (var (key, total) in totals
                     .OrderBy(pair => pair.Key.BucketNo)
                     .ThenBy(pair => pair.Key.TieMixingId ?? long.MinValue)
                     .ThenBy(pair => pair.Key.Slot)
                     .ThenBy(pair => pair.Key.Name))
        {
            var slot = key.Slot == MaterialMixingLedgerChunk.NoSlot ? (int?)null : key.Slot;
            // The query returns decimal(24,4): same value and the same digits in the JSON.
            var quantity = total * QueryQuantityScale;
            if (key.Name == CurrentSlotName)
            {
                // One row per CUAVL row of the slot, like the LEFT JOIN on STTCUAVL.
                foreach (var material in materialsBySlot[key.Slot])
                {
                    rows.Add(new MaterialMixingBucketRow(
                        key.BucketNo, key.TieMixingId, material.Code, slot, material.Name, quantity));
                }
            }
            else
            {
                rows.Add(new MaterialMixingBucketRow(
                    key.BucketNo, key.TieMixingId, null, slot, Names[key.Name], quantity));
            }
        }
        return rows;

        void AddMix(long mixId, long finish3Ticks, List<(int Slot, int Name, long Quantity)> entries)
        {
            var bucket = LastAtOrBefore(boundaryTicks, finish3Ticks);
            if (bucket < 0)
            {
                return;
            }
            var boundary = boundaries[bucket];
            long? tie = boundary.IsIssue && boundaryTicks[bucket] == finish3Ticks ? mixId : null;

            var index = 0;
            while (index < entries.Count)
            {
                var slot = entries[index].Slot;
                var isCurrent = slot != MaterialMixingLedgerChunk.NoSlot && currentSlots.Contains(slot);
                var name = isCurrent ? CurrentSlotName : entries[index].Name;
                var sum = 0L;
                while (index < entries.Count &&
                       entries[index].Slot == slot &&
                       (isCurrent || entries[index].Name == name))
                {
                    sum += entries[index].Quantity;
                    index++;
                }
                if (sum > 0)
                {
                    var key = new BucketKey(boundary.BucketNo, tie, slot, name);
                    totals[key] = totals.GetValueOrDefault(key) + sum;
                }
            }
        }
    }

    private const int CurrentSlotName = -1;

    private const decimal QueryQuantityScale = 1.0000m;

    private static int LastAtOrBefore(long[] ticks, long value)
    {
        var index = Array.BinarySearch(ticks, value);
        return index >= 0 ? index : ~index - 1;
    }

    /// <summary>Mixes found in more than one of the chunks (details of a mix split by a chunk end).</summary>
    public static HashSet<long> FindSplitMixes(IReadOnlyList<MaterialMixingLedgerChunk> chunks)
    {
        var result = new HashSet<long>();
        var ordered = chunks.Where(chunk => chunk.MixIds.Length > 0).OrderBy(chunk => chunk.MinMixId).ToArray();
        for (var index = 0; index < ordered.Length; index++)
        {
            for (var other = index + 1; other < ordered.Length && ordered[other].MinMixId <= ordered[index].MaxMixId; other++)
            {
                Intersect(ordered[index].MixIds, ordered[other].MixIds, result);
            }
        }
        return result;
    }

    private static IEnumerable<long> FindSharedMixes(
        MaterialMixingLedgerChunk tail,
        IReadOnlyList<MaterialMixingLedgerChunk> sealedChunks)
    {
        if (tail.MixIds.Length == 0)
        {
            return [];
        }
        var result = new HashSet<long>();
        foreach (var chunk in sealedChunks)
        {
            if (chunk.MixIds.Length > 0 && chunk.MinMixId <= tail.MaxMixId && tail.MinMixId <= chunk.MaxMixId)
            {
                Intersect(chunk.MixIds, tail.MixIds, result);
            }
        }
        return result;
    }

    private static void Intersect(long[] left, long[] right, HashSet<long> result)
    {
        var i = 0;
        var j = 0;
        while (i < left.Length && j < right.Length)
        {
            if (left[i] == right[j])
            {
                result.Add(left[i]);
                i++;
                j++;
            }
            else if (left[i] < right[j])
            {
                i++;
            }
            else
            {
                j++;
            }
        }
    }

    private readonly record struct BucketKey(int BucketNo, long? TieMixingId, int Slot, int Name);

    private sealed class PendingMix(long finish3Ticks)
    {
        public long Finish3Ticks { get; } = finish3Ticks;
        public List<(int Slot, int Name, long Quantity)> Entries { get; } = [];
    }
}

/// <summary>
/// The historical slot names of a station, by the SHA1 the chunk query groups them with. Indexes
/// never change, so chunks read at any time share one numbering; a ledger keeps a snapshot.
/// </summary>
internal sealed class MaterialMixingNameTable
{
    private readonly object sync = new();
    private readonly List<string> names = [];
    private readonly List<string> hashes = [];
    private readonly Dictionary<string, int> indexByHash = new(StringComparer.Ordinal);

    public MaterialMixingNameTable()
    {
    }

    public MaterialMixingNameTable(IEnumerable<(string Hash, string Name)> entries)
    {
        foreach (var (hash, name) in entries)
        {
            Add(hash, name);
        }
    }

    public bool TryGetIndex(string hash, out int index)
    {
        lock (sync)
        {
            return indexByHash.TryGetValue(hash, out index);
        }
    }

    public int Add(string hash, string name)
    {
        lock (sync)
        {
            if (indexByHash.TryGetValue(hash, out var existing))
            {
                return existing;
            }
            names.Add(name);
            hashes.Add(hash);
            indexByHash.Add(hash, names.Count - 1);
            return names.Count - 1;
        }
    }

    public string[] SnapshotNames()
    {
        lock (sync)
        {
            return [.. names];
        }
    }

    public (string Hash, string Name)[] SnapshotEntries()
    {
        lock (sync)
        {
            return hashes.Zip(names).ToArray();
        }
    }
}
