using TTSmart.Api.Features.MaterialReporting;

namespace TTSmart.Api.Tests;

public sealed class MaterialMixingBucketsTests
{
    private static readonly DateTime From = new(2026, 8, 10);
    private static readonly DateTime To = new(2026, 8, 31, 23, 59, 59);
    private static readonly MaterialDefinition Sand = new(101, 1, 1, "Cát 1");
    private static readonly MaterialDefinition Stone = new(102, 2, 2, "Đá 1");
    private static readonly MaterialDefinition Additive = new(103, 3, 5, "Silicafume");

    [Fact]
    public void Moc_GomLoNhapPhieuXuatVaTuNgay_TheoThuTuThoiGian()
    {
        var boundaries = MaterialMixingBuckets.BuildBoundaries(
            [
                Lot("l1", At(3), 100),
                Lot("l2", At(3), 50),
                Lot("l0", At(1), 0),
                Lot("late", To.AddDays(1), 100)
            ],
            [
                Issue("e1", At(3), 10),
                Issue("e2", At(5), 10),
                Issue("adjust", At(6), -10)
            ],
            From.AddTicks(1),
            To);

        Assert.Equal(
            [MaterialMixingBuckets.Origin, At(3), At(5), From.AddMilliseconds(1)],
            boundaries.Select(item => item.At));
        Assert.Equal([0, 1, 2, 3], boundaries.Select(item => item.BucketNo));
        // A lot and an issue at the same instant: the mixes finishing then stay single.
        Assert.Equal([false, true, true, false], boundaries.Select(item => item.IsIssue));
        Assert.StartsWith(
            "<r><b n=\"0\" t=\"0001-01-01T00:00:00.000\" i=\"0\"/><b n=\"1\" t=\"2026-08-03T08:00:00.000\" i=\"1\"/>",
            MaterialMixingBuckets.ToXml(boundaries));
        Assert.EndsWith("<b n=\"3\" t=\"2026-08-10T00:00:00.001\" i=\"0\"/></r>", MaterialMixingBuckets.ToXml(boundaries));
    }

    [Fact]
    public void DongKetQua_ThanhSuKienFifo_GiuMeTrungMocVaTachTenLichSu()
    {
        var boundaries = MaterialMixingBuckets.BuildBoundaries(
            [Lot("l1", At(3), 100)],
            [Issue("e1", At(5), 10)],
            From,
            To);

        var events = MaterialMixingBuckets.ToIssueEvents(
            [
                new MaterialMixingBucketRow(1, null, Sand.Code, Sand.SlotNumber, Sand.Name, 40),
                new MaterialMixingBucketRow(2, 7_001, Sand.Code, Sand.SlotNumber, Sand.Name, 5),
                new MaterialMixingBucketRow(2, null, null, 9, "Sika", 3),
                new MaterialMixingBucketRow(2, null, null, 9, "8509", 2),
                new MaterialMixingBucketRow(3, null, Stone.Code, Stone.SlotNumber, Stone.Name, 0)
            ],
            boundaries);

        Assert.Equal(4, events.Count);
        Assert.Equal(At(3), events[0].OccurredAt);
        Assert.True(events[0].SourceSequence >= MaterialMixingBuckets.BucketSequenceBase);
        // The mix that finished with the issue keeps its own id, time and sequence.
        Assert.Equal("mix:7001:101", events[1].SourceId);
        Assert.Equal(At(5), events[1].OccurredAt);
        Assert.Equal(7_001 * 100 + 101, events[1].SourceSequence);
        // Two historical names of a slot no longer in CUAVL stay two events.
        Assert.Equal(["mix-bucket:2:9", "mix-bucket:2:9:2"], events.Skip(2).Select(item => item.SourceId));
        Assert.Equal(["Sika", "8509"], events.Skip(2).Select(item => item.MaterialName));
        Assert.All(events.Skip(2), item => Assert.Null(item.MaterialCode));
    }

    [Fact]
    public void GopMeTheoMoc_KetQuaFifoBangTungMe()
    {
        for (var seed = 0; seed < 400; seed++)
        {
            var scenario = Scenario.Create(seed);
            var single = Calculate(scenario, scenario.Mixes.Select(mix => mix.ToEvent()).ToArray());
            var bucketed = Calculate(scenario, Bucket(scenario));

            Assert.Equal(single.Materials, bucketed.Materials);
            foreach (var issue in scenario.OtherIssues)
            {
                Assert.Equal(
                    single.IssueValueBySourceId.GetValueOrDefault(issue.SourceId),
                    bucketed.IssueValueBySourceId.GetValueOrDefault(issue.SourceId));
            }
            Assert.Equal(single.IssueValueByTransactionId, bucketed.IssueValueByTransactionId);
            Assert.Equal(SummaryExport(single, scenario, single.Issues), SummaryExport(bucketed, scenario, bucketed.Issues));
        }
    }

    [Fact]
    public void FifoTheoConTro_BangThuatToanLocVaSapXepTungLanXuat()
    {
        for (var seed = 0; seed < 400; seed++)
        {
            var scenario = Scenario.Create(seed);
            var snapshot = new MaterialReportSnapshot(
                scenario.Materials,
                scenario.Imports,
                scenario.OtherIssues.Concat(scenario.Mixes.Select(mix => mix.ToEvent())).ToArray(),
                [],
                []);

            var actual = MaterialFifoCalculator.Calculate(snapshot, From, To);
            var expected = ReferenceFifo.Calculate(snapshot, To);

            Assert.Equal(expected.Materials, actual.Materials.Select(item => (
                item.Material.Code,
                item.ImportQuantityKg,
                item.ExportQuantityKg,
                item.InventoryQuantityKg,
                item.ImportValueVnd,
                item.ExportValueVnd,
                item.InventoryValueVnd)));
            Assert.Equal(expected.IssueValueBySourceId, actual.IssueValueBySourceId);
        }
    }

    /// <summary>What the mixing query returns: positive mixes added up per bucket and material key.</summary>
    private static IReadOnlyList<MaterialIssueEvent> Bucket(Scenario scenario)
    {
        var boundaries = MaterialMixingBuckets.BuildBoundaries(scenario.Imports, scenario.OtherIssues, From, To);
        var rows = scenario.Mixes
            .Where(mix => mix.QuantityKg > 0)
            .Select(mix =>
            {
                var boundary = boundaries.Last(item => item.At <= mix.OccurredAt);
                var tie = boundary.IsIssue && boundary.At == mix.OccurredAt;
                return (Boundary: boundary, TieMixingId: tie ? mix.MixingId : (long?)null, Mix: mix);
            })
            .GroupBy(item => (item.Boundary.BucketNo, item.TieMixingId, item.Mix.MaterialCode, item.Mix.SlotNumber, item.Mix.MaterialName))
            .Select(group => new MaterialMixingBucketRow(
                group.Key.BucketNo,
                group.Key.TieMixingId,
                group.Key.MaterialCode,
                group.Key.SlotNumber,
                group.Key.MaterialName,
                group.Sum(item => item.Mix.QuantityKg)))
            .ToArray();
        return MaterialMixingBuckets.ToIssueEvents(rows, boundaries);
    }

    private static (IReadOnlyList<MaterialCalculatedValue> Materials,
        IReadOnlyDictionary<string, decimal> IssueValueBySourceId,
        IReadOnlyDictionary<string, decimal> IssueValueByTransactionId,
        IReadOnlyList<MaterialIssueEvent> Issues) Calculate(Scenario scenario, IReadOnlyList<MaterialIssueEvent> mixingIssues)
    {
        var issues = scenario.OtherIssues.Concat(mixingIssues).ToArray();
        var result = MaterialFifoCalculator.Calculate(
            new MaterialReportSnapshot(scenario.Materials, scenario.Imports, issues, [], []),
            From,
            To);
        return (result.Materials, result.IssueValueBySourceId, result.IssueValueByTransactionId, issues);
    }

    /// <summary>The "Xuất tổng trong kỳ" row: issues of the period, per material.</summary>
    private static string SummaryExport(
        (IReadOnlyList<MaterialCalculatedValue> Materials,
            IReadOnlyDictionary<string, decimal> IssueValueBySourceId,
            IReadOnlyDictionary<string, decimal> IssueValueByTransactionId,
            IReadOnlyList<MaterialIssueEvent> Issues) result,
        Scenario scenario,
        IReadOnlyList<MaterialIssueEvent> issues)
    {
        var byName = scenario.Materials.ToDictionary(item => MaterialFifoCalculator.NormalizeText(item.Name));
        var codes = scenario.Materials.Select(item => item.Code).ToHashSet();
        return string.Join(';', issues
            .Where(item => item.OccurredAt >= From && item.OccurredAt <= To &&
                           (item.QuantityKg > 0 || item.IsQuantityOnlyAdjustment && item.QuantityKg < 0))
            .Select(item => (Issue: item, Code: item.MaterialCode is { } code && codes.Contains(code)
                ? code
                : byName.GetValueOrDefault(MaterialFifoCalculator.NormalizeText(item.MaterialName))?.Code))
            .Where(item => item.Code is not null)
            .GroupBy(item => item.Code)
            .OrderBy(group => group.Key)
            .Select(group => $"{group.Key}:{group.Sum(item => item.Issue.QuantityKg)}:" +
                             group.Sum(item => result.IssueValueBySourceId.GetValueOrDefault(item.Issue.SourceId))));
    }

    private static DateTime At(int day, int minute = 0) => new DateTime(2026, 8, day, 8, 0, 0).AddMinutes(minute);

    private static MaterialImportLot Lot(string id, DateTime at, decimal quantity, int code = 101) =>
        new(id, id.GetHashCode(), code, null, at, quantity, 1_000);

    private static MaterialIssueEvent Issue(string id, DateTime at, decimal quantity) =>
        new(id, id.GetHashCode(), Sand.Code, null, null, at, quantity);

    private sealed record Mix(long MixingId, DateTime OccurredAt, int? MaterialCode, int? SlotNumber, string? MaterialName, decimal QuantityKg)
    {
        public MaterialIssueEvent ToEvent() => new(
            $"mix:{MixingId}:{MaterialCode ?? SlotNumber ?? 0}:{MaterialName}",
            MixingId * 100 + (MaterialCode ?? SlotNumber ?? 0),
            MaterialCode,
            SlotNumber,
            MaterialName,
            OccurredAt,
            QuantityKg);
    }

    private sealed record Scenario(
        IReadOnlyList<MaterialDefinition> Materials,
        IReadOnlyList<MaterialImportLot> Imports,
        IReadOnlyList<MaterialIssueEvent> OtherIssues,
        IReadOnlyList<Mix> Mixes)
    {
        public static Scenario Create(int seed)
        {
            var random = new Random(seed);
            var start = From.AddDays(-12);
            var minutes = (int)(To - start).TotalMinutes;
            DateTime RandomTime() => start.AddMinutes(random.Next(minutes)).AddMilliseconds(random.Next(3) * 3);
            var materials = new[] { Sand, Stone, Additive };

            var mixes = new List<Mix>();
            for (var id = 1; id <= random.Next(5, 60); id++)
            {
                var at = RandomTime();
                // Current slots, a slot gone from CUAVL mapped by its historical name (or not),
                // zero consumption, and the rare negative correction.
                mixes.Add(new Mix(id, at, Sand.Code, 1, Sand.Name, random.Next(0, 4) == 0 ? 0 : random.Next(1, 400)));
                mixes.Add(new Mix(id, at, Stone.Code, 2, Stone.Name, random.Next(-20, 600)));
                mixes.Add(new Mix(id, at, null, 9, random.Next(2) == 0 ? "Silicafume" : "8509", random.Next(0, 50)));
            }
            var mixTimes = mixes.Select(item => item.OccurredAt).Distinct().ToArray();

            var imports = new List<MaterialImportLot>();
            for (var index = 0; index < random.Next(0, 12); index++)
            {
                var material = materials[random.Next(materials.Length)];
                var at = random.Next(3) == 0 ? mixTimes[random.Next(mixTimes.Length)] : RandomTime();
                imports.Add(new MaterialImportLot(
                    $"lot:{index}",
                    index * 10 + 1,
                    random.Next(5) == 0 ? null : material.Code,
                    material.Name,
                    at,
                    random.Next(5) == 0 ? 0.4m : random.Next(50, 3_000),
                    random.Next(0, 6) * 1_000,
                    IsQuantityOnlyAdjustment: false));
            }

            var otherIssues = new List<MaterialIssueEvent>();
            for (var index = 0; index < random.Next(0, 8); index++)
            {
                var material = materials[random.Next(materials.Length)];
                var at = random.Next(2) == 0 ? mixTimes[random.Next(mixTimes.Length)] : RandomTime();
                var adjustment = random.Next(6) == 0;
                otherIssues.Add(new MaterialIssueEvent(
                    $"manual-item:{index}",
                    random.Next(2) == 0 ? index * 10 + 4 : 1_000_000 + index,
                    material.Code,
                    null,
                    material.Name,
                    at,
                    adjustment ? -random.Next(1, 100) : random.Next(1, 500),
                    $"manual:{index % 3}",
                    adjustment));
            }

            return new Scenario(materials, imports, otherIssues, mixes);
        }
    }

    /// <summary>The FIFO before the lot cursor: filter and sort the lots for every issue.</summary>
    private static class ReferenceFifo
    {
        public static ((int, decimal, decimal, decimal, decimal, decimal, decimal)[] Materials,
            Dictionary<string, decimal> IssueValueBySourceId) Calculate(MaterialReportSnapshot snapshot, DateTime toLocal)
        {
            var byCode = snapshot.Materials.GroupBy(item => item.Code).ToDictionary(group => group.Key, group => group.First());
            var bySlot = snapshot.Materials.Where(item => item.SlotNumber > 0).GroupBy(item => item.SlotNumber)
                .ToDictionary(group => group.Key, group => group.First());
            var byName = snapshot.Materials.Where(item => !string.IsNullOrWhiteSpace(item.Name))
                .GroupBy(item => MaterialFifoCalculator.NormalizeText(item.Name))
                .ToDictionary(group => group.Key, group => group.First());
            MaterialDefinition? Resolve(int? code, int? slot, string? name)
            {
                if (code.HasValue && byCode.TryGetValue(code.Value, out var exact)) return exact;
                if (slot.HasValue && bySlot.TryGetValue(slot.Value, out var bySlotNumber)) return bySlotNumber;
                return byName.GetValueOrDefault(MaterialFifoCalculator.NormalizeText(name));
            }
            decimal Kg(decimal value) => Math.Round(value, 0, MidpointRounding.AwayFromZero);

            var states = snapshot.Materials.ToDictionary(item => item.Code, item => new State(item));
            foreach (var import in snapshot.Imports.Where(item => item.OccurredAt <= toLocal)
                         .OrderBy(item => item.OccurredAt).ThenBy(item => item.SourceSequence))
            {
                var material = Resolve(import.MaterialCode, null, import.MaterialName);
                if (material is null || import.QuantityKg <= 0) continue;
                var state = states[material.Code];
                var quantity = Kg(import.QuantityKg);
                var price = Kg(import.UnitPriceVndPerKg);
                state.Import += quantity;
                state.ImportValue += Kg(quantity * price);
                state.Lots.Add(new Lot(import.OccurredAt, import.SourceSequence, quantity, price));
            }
            foreach (var adjustment in snapshot.Imports.Where(item => item.IsQuantityOnlyAdjustment && item.QuantityKg < 0 && item.OccurredAt <= toLocal))
            {
                var material = Resolve(adjustment.MaterialCode, null, adjustment.MaterialName);
                if (material is not null) states[material.Code].Import += Kg(adjustment.QuantityKg);
            }

            void Cover(State state, DateTime availableAt)
            {
                if (state.Shortage <= 0) return;
                foreach (var lot in state.Lots.Where(item => item.Remaining > 0 && item.OccurredAt <= availableAt)
                             .OrderBy(item => item.OccurredAt).ThenBy(item => item.Sequence))
                {
                    if (state.Shortage <= 0) break;
                    var covered = Kg(Math.Min(state.Shortage, lot.Remaining));
                    lot.Remaining = Math.Max(0m, Kg(lot.Remaining - covered));
                    state.Shortage = Math.Max(0m, Kg(state.Shortage - covered));
                }
            }

            var values = new Dictionary<string, decimal>();
            foreach (var issue in snapshot.Issues.Where(item => item.OccurredAt <= toLocal)
                         .OrderBy(item => item.OccurredAt).ThenBy(item => item.SourceSequence))
            {
                var material = Resolve(issue.MaterialCode, issue.SlotNumber, issue.MaterialName);
                if (material is null || issue.QuantityKg <= 0) continue;
                var state = states[material.Code];
                var quantity = Kg(issue.QuantityKg);
                state.Export += quantity;
                Cover(state, issue.OccurredAt);
                var need = quantity;
                var value = 0m;
                foreach (var lot in state.Lots.Where(item => item.Remaining > 0 && item.OccurredAt <= issue.OccurredAt)
                             .OrderBy(item => item.OccurredAt).ThenBy(item => item.Sequence))
                {
                    if (need <= 0) break;
                    var used = Kg(Math.Min(need, lot.Remaining));
                    lot.Remaining = Math.Max(0m, Kg(lot.Remaining - used));
                    need = Math.Max(0m, Kg(need - used));
                    value += Kg(used * lot.Price);
                }
                if (need > 0) state.Shortage += need;
                state.ExportValue += value;
                values[issue.SourceId] = value;
            }
            foreach (var adjustment in snapshot.Issues.Where(item => item.IsQuantityOnlyAdjustment && item.QuantityKg < 0 && item.OccurredAt <= toLocal))
            {
                var material = Resolve(adjustment.MaterialCode, adjustment.SlotNumber, adjustment.MaterialName);
                if (material is not null) states[material.Code].Export += Kg(adjustment.QuantityKg);
            }
            foreach (var state in states.Values) Cover(state, toLocal);

            return (states.Values
                .OrderBy(item => item.Material.SlotNumber).ThenBy(item => item.Material.Code)
                .Select(item => (
                    item.Material.Code,
                    Kg(item.Import),
                    Kg(item.Export),
                    Kg(item.Import - item.Export),
                    Kg(item.ImportValue),
                    Kg(item.ExportValue),
                    Kg(item.Lots.Sum(lot => lot.Remaining * lot.Price))))
                .ToArray(), values);
        }

        private sealed class State(MaterialDefinition material)
        {
            public MaterialDefinition Material { get; } = material;
            public List<Lot> Lots { get; } = [];
            public decimal Import { get; set; }
            public decimal Export { get; set; }
            public decimal ImportValue { get; set; }
            public decimal ExportValue { get; set; }
            public decimal Shortage { get; set; }
        }

        private sealed class Lot(DateTime occurredAt, long sequence, decimal remaining, decimal price)
        {
            public DateTime OccurredAt { get; } = occurredAt;
            public long Sequence { get; } = sequence;
            public decimal Remaining { get; set; } = remaining;
            public decimal Price { get; } = price;
        }
    }
}
