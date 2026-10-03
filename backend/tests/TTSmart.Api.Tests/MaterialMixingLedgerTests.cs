using TTSmart.Api.Features.MaterialReporting;

namespace TTSmart.Api.Tests;

public sealed class MaterialMixingLedgerTests
{
    private static readonly DateTime Start = new(2026, 7, 1);
    private static readonly MaterialDefinition Sand = new(101, 1, 1, "Cát 1");
    private static readonly MaterialDefinition Stone = new(102, 2, 2, "Đá 1");
    private static readonly MaterialDefinition StoneTwin = new(103, 2, 2, "Đá 1 (cân 2)");

    [Fact]
    public void SoTieuHao_RaDungCacDongCuaTruyVanGopMe()
    {
        for (var seed = 0; seed < 500; seed++)
        {
            var scenario = Scenario.Create(seed);
            foreach (var (fromLocal, toLocal) in scenario.Ranges)
            {
                var boundaries = MaterialMixingBuckets.BuildBoundaries(
                    scenario.Imports, scenario.Issues, fromLocal, toLocal);
                var expected = Canonical(Reference(scenario, boundaries, toLocal));
                var actual = Canonical(scenario.Ledger().ToBucketRows(scenario.Materials, boundaries, toLocal));
                Assert.Equal(expected, actual);
            }
        }
    }

    [Fact]
    public void FileSo_GhiRoiDocLai_GiuNguyenSoLieu()
    {
        var scenario = Scenario.Create(7);
        var ledger = scenario.Ledger();
        var path = Path.Combine(Path.GetTempPath(), $"ttsmart-ledger-{Guid.NewGuid():N}.ledger");
        try
        {
            MaterialMixingLedgerFile.Save(path, 42, "tram_online", ledger, scenario.Names.SnapshotEntries());
            var loaded = MaterialMixingLedgerFile.Load(path, 42, "tram_online");

            Assert.NotNull(loaded);
            Assert.Null(MaterialMixingLedgerFile.Load(path, 43, "tram_online"));
            Assert.Null(MaterialMixingLedgerFile.Load(path, 42, "tram_khac_online"));
            var copy = loaded.Value.Ledger;
            Assert.Equal(ledger.Names, copy.Names);
            Assert.Equal(ledger.SealedChunks.Count, copy.SealedChunks.Count);
            Assert.All(ledger.SealedChunks.Zip(copy.SealedChunks), pair => Assert.True(pair.First.SameContentAs(pair.Second)));
            Assert.True(ledger.Tail.SameContentAs(copy.Tail));
            Assert.Equal(ledger.SealedSplitMixes.Order(), copy.SealedSplitMixes.Order());
            var (fromLocal, toLocal) = scenario.Ranges[0];
            var boundaries = MaterialMixingBuckets.BuildBoundaries(scenario.Imports, scenario.Issues, fromLocal, toLocal);
            Assert.Equal(
                Canonical(ledger.ToBucketRows(scenario.Materials, boundaries, toLocal)),
                Canonical(copy.ToBucketRows(scenario.Materials, boundaries, toLocal)));
        }
        finally
        {
            File.Delete(path);
        }
    }

    [Fact]
    public void TramKhongCoBangTron_KhongCoTieuHao()
    {
        var ledger = MaterialMixingLedger.WithoutMixingTables(DateTime.UtcNow);
        var boundaries = MaterialMixingBuckets.BuildBoundaries([], [], Start, Start.AddDays(1));

        Assert.False(ledger.HasMixingTables);
        Assert.Empty(ledger.ToBucketRows([Sand], boundaries, Start.AddDays(1)));
    }

    /// <summary>The bucketed mixing query, written out on the detail rows.</summary>
    private static IEnumerable<MaterialMixingBucketRow> Reference(
        Scenario scenario,
        IReadOnlyList<MaterialFifoBoundary> boundaries,
        DateTime toLocal)
    {
        var currentSlots = scenario.Materials.Select(item => item.SlotNumber).ToHashSet();
        var perMix = scenario.Details
            .Where(detail => detail.Finish7 <= toLocal)
            .Select(detail =>
            {
                var boundary = boundaries.Last(item => item.At <= detail.Finish3);
                var tie = boundary.IsIssue && boundary.At == detail.Finish3 ? detail.MixId : (long?)null;
                var current = detail.Slot is { } slot && currentSlots.Contains(slot);
                return (Detail: detail, boundary.BucketNo, Tie: tie, Name: current ? null : detail.Name);
            })
            .GroupBy(item => (item.Detail.MixId, item.BucketNo, item.Tie, item.Detail.Slot, item.Name))
            .Select(group => (group.Key, Quantity: group.Sum(item => item.Detail.QuantityKg)))
            .Where(item => item.Quantity > 0);
        foreach (var bucket in perMix.GroupBy(item => (item.Key.BucketNo, item.Key.Tie, item.Key.Slot, item.Key.Name)))
        {
            // decimal(24,4), like the query.
            var quantity = bucket.Sum(item => item.Quantity) * 1.0000m;
            if (bucket.Key.Name is null)
            {
                foreach (var material in scenario.Materials.Where(item => item.SlotNumber == bucket.Key.Slot))
                {
                    yield return new MaterialMixingBucketRow(
                        bucket.Key.BucketNo, bucket.Key.Tie, material.Code, bucket.Key.Slot, material.Name, quantity);
                }
            }
            else
            {
                yield return new MaterialMixingBucketRow(
                    bucket.Key.BucketNo, bucket.Key.Tie, null, bucket.Key.Slot, bucket.Key.Name, quantity);
            }
        }
    }

    private static string[] Canonical(IEnumerable<MaterialMixingBucketRow> rows) => rows
        .Select(row => $"{row.BucketNo}|{row.TieMixingId}|{row.MaterialCode}|{row.SlotNumber}|{row.MaterialName}|{row.QuantityKg}")
        .Order(StringComparer.Ordinal)
        .ToArray();

    private sealed record Detail(long DetailId, long MixId, DateTime Finish3, DateTime Finish7, int? Slot, string Name, long QuantityKg);

    private sealed record Scenario(
        IReadOnlyList<MaterialDefinition> Materials,
        IReadOnlyList<MaterialImportLot> Imports,
        IReadOnlyList<MaterialIssueEvent> Issues,
        IReadOnlyList<Detail> Details,
        IReadOnlyList<(DateTime From, DateTime To)> Ranges,
        int Seed)
    {
        public MaterialMixingNameTable Names { get; } = new();

        /// <summary>
        /// The ledger the chunk query would give, with random chunk ends so a mix's details fall in
        /// two chunks, and the last chunk as the tail.
        /// </summary>
        public MaterialMixingLedger Ledger()
        {
            var random = new Random(Seed * 31 + 7);
            var ids = Details.Select(item => item.DetailId).Distinct().Order().ToArray();
            var ends = new List<long>();
            for (var index = random.Next(1, 6); index < ids.Length; index += random.Next(1, 12))
            {
                ends.Add(ids[index - 1]);
            }
            var chunks = new List<MaterialMixingLedgerChunk>();
            var after = 0L;
            foreach (var end in ends.Append(long.MaxValue))
            {
                var rows = Details
                    .Where(item => item.DetailId > after && item.DetailId <= end)
                    .GroupBy(item => (item.MixId, item.Slot, item.Name))
                    .Select(group => new MaterialMixingLedgerRow(
                        group.Key.MixId,
                        group.First().Finish3,
                        group.First().Finish7,
                        group.Key.Slot,
                        Names.Add(group.Key.Name, group.Key.Name),
                        group.Sum(item => item.QuantityKg)));
                chunks.Add(MaterialMixingLedgerChunk.Create(after, end, rows));
                after = end;
            }
            return new MaterialMixingLedger(
                true,
                Names.SnapshotNames(),
                chunks.Take(chunks.Count - 1).ToArray(),
                chunks[^1],
                new Dictionary<long, DateTime>(),
                DateTime.UtcNow,
                DateTime.UtcNow);
        }

        public static Scenario Create(int seed)
        {
            var random = new Random(seed);
            var materials = random.Next(3) == 0
                ? new[] { Sand, Stone, StoneTwin }
                : new[] { Sand, Stone };
            DateTime RandomTime() => Start.AddMinutes(random.Next(60 * 24 * 20)).AddMilliseconds(random.Next(3) * 3);

            var details = new List<Detail>();
            var detailId = 1000L;
            var mixCount = random.Next(3, 50);
            var mixTimes = new List<DateTime>();
            for (var mixId = 1; mixId <= mixCount; mixId++)
            {
                var finish = RandomTime();
                mixTimes.Add(finish);
                // datetime2(7) of a datetime ending in .003 is .0033333 on newer compatibility levels.
                var finish7 = finish.Millisecond % 10 == 3 && random.Next(2) == 0 ? finish.AddTicks(3333) : finish;
                for (var batch = 0; batch < random.Next(1, 3); batch++)
                {
                    detailId += random.Next(1, 3);
                    AddDoor(1, "Cát 1", random.Next(4) == 0 ? 0 : random.Next(1, 400));
                    AddDoor(2, random.Next(3) == 0 ? "Đá cũ" : "Đá 1", random.Next(-30, 600));
                    if (random.Next(3) == 0)
                    {
                        AddDoor(2, "Đá 1", random.Next(-400, 50));
                    }
                    AddDoor(9, random.Next(2) == 0 ? "Silicafume" : "8509", random.Next(-5, 50));
                    if (random.Next(5) == 0)
                    {
                        AddDoor(null, "Phụ gia lạ", random.Next(0, 30));
                    }
                }

                void AddDoor(int? slot, string name, long quantity) =>
                    details.Add(new Detail(detailId, mixId, finish, finish7, slot, name, quantity));
            }

            var imports = new List<MaterialImportLot>();
            for (var index = 0; index < random.Next(0, 8); index++)
            {
                var at = random.Next(3) == 0 ? mixTimes[random.Next(mixTimes.Count)] : RandomTime();
                imports.Add(new MaterialImportLot($"lot:{index}", index * 10 + 1, Sand.Code, Sand.Name, at, random.Next(0, 900), 1_000));
            }
            var issues = new List<MaterialIssueEvent>();
            for (var index = 0; index < random.Next(0, 8); index++)
            {
                var at = random.Next(2) == 0 ? mixTimes[random.Next(mixTimes.Count)] : RandomTime();
                issues.Add(new MaterialIssueEvent($"manual-item:{index}", index * 10 + 4, Stone.Code, null, Stone.Name, at, random.Next(-10, 300)));
            }

            var ranges = new List<(DateTime, DateTime)>
            {
                (Start.AddDays(5), Start.AddDays(25)),
                (Start.AddDays(2), mixTimes[random.Next(mixTimes.Count)]),
                (Start.AddDays(random.Next(0, 20)), Start.AddDays(random.Next(5, 21)).AddMilliseconds(3))
            };
            ranges = ranges.Select(range => range.Item1 <= range.Item2 ? range : (range.Item2, range.Item1)).ToList();
            return new Scenario(materials, imports, issues, details, ranges, seed);
        }
    }
}
