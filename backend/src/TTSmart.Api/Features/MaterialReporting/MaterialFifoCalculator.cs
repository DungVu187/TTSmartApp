using System.Globalization;
using System.Text;

namespace TTSmart.Api.Features.MaterialReporting;

internal sealed record MaterialCalculatedValue(
    MaterialDefinition Material,
    decimal ImportQuantityKg,
    decimal ExportQuantityKg,
    decimal InventoryQuantityKg,
    decimal ImportValueVnd,
    decimal ExportValueVnd,
    decimal InventoryValueVnd,
    decimal? KilogramsPerCubicMeter,
    decimal? KilogramsPerLiter,
    bool HasMissingImportPrice);

internal sealed record MaterialFifoCalculation(
    IReadOnlyList<MaterialCalculatedValue> Materials,
    IReadOnlyDictionary<string, decimal> IssueValueByTransactionId,
    IReadOnlyDictionary<string, decimal> IssueValueBySourceId);

internal static class MaterialFifoCalculator
{
    public static MaterialFifoCalculation Calculate(
        MaterialReportSnapshot snapshot,
        DateTime fromLocal,
        DateTime toLocal)
    {
        var resolver = new MaterialResolver(snapshot.Materials);
        var states = snapshot.Materials.ToDictionary(
            material => material.Code,
            material => new MaterialState(material));

        foreach (var import in snapshot.Imports
                     .Where(item => item.OccurredAt <= toLocal)
                     .OrderBy(item => item.OccurredAt)
                     .ThenBy(item => item.SourceSequence))
        {
            var material = resolver.Resolve(import.MaterialCode, null, import.MaterialName);
            if (material is null || import.QuantityKg <= 0)
            {
                continue;
            }

            var state = states[material.Code];
            var quantity = RoundKg(import.QuantityKg);
            var price = RoundVnd(import.UnitPriceVndPerKg);
            state.ImportQuantityKg += quantity;
            state.ImportValueVnd += RoundVnd(quantity * price);
            state.HasMissingImportPrice |= quantity > 0 && price <= 0;
            state.Lots.Add(new FifoLot(
                import.OccurredAt,
                import.SourceSequence,
                quantity,
                price));
            UpdateConversion(state, import);
        }

        var issueValueByTransactionId = new Dictionary<string, decimal>(StringComparer.Ordinal);
        var issueValueBySourceId = new Dictionary<string, decimal>(StringComparer.Ordinal);
        foreach (var issue in snapshot.Issues
                     .Where(item => item.OccurredAt <= toLocal)
                     .OrderBy(item => item.OccurredAt)
                     .ThenBy(item => item.SourceSequence))
        {
            var material = resolver.Resolve(issue.MaterialCode, issue.SlotNumber, issue.MaterialName);
            if (material is null || issue.QuantityKg <= 0)
            {
                continue;
            }

            var state = states[material.Code];
            var issueQuantity = RoundKg(issue.QuantityKg);
            state.ExportQuantityKg += issueQuantity;
            CoverPreviousShortage(state, issue.OccurredAt);

            var remainingNeed = issueQuantity;
            var issueValue = 0m;
            foreach (var lot in state.Lots
                         .Where(item => item.RemainingKg > 0 && item.OccurredAt <= issue.OccurredAt)
                         .OrderBy(item => item.OccurredAt)
                         .ThenBy(item => item.SourceSequence))
            {
                if (remainingNeed <= 0)
                {
                    break;
                }

                var used = RoundKg(Math.Min(remainingNeed, lot.RemainingKg));
                lot.RemainingKg = Math.Max(0m, RoundKg(lot.RemainingKg - used));
                remainingNeed = Math.Max(0m, RoundKg(remainingNeed - used));
                issueValue += RoundVnd(used * lot.UnitPriceVndPerKg);
            }

            if (remainingNeed > 0)
            {
                state.ShortageKg += remainingNeed;
            }

            state.ExportValueVnd += issueValue;
            issueValueBySourceId[issue.SourceId] = issueValue;
            if (!string.IsNullOrWhiteSpace(issue.TransactionId))
            {
                issueValueByTransactionId[issue.TransactionId] =
                    issueValueByTransactionId.GetValueOrDefault(issue.TransactionId) + issueValue;
            }
        }

        foreach (var state in states.Values)
        {
            CoverPreviousShortage(state, toLocal);
        }

        var values = states.Values
            .OrderBy(item => item.Material.SlotNumber)
            .ThenBy(item => item.Material.Code)
            .Select(state => new MaterialCalculatedValue(
                state.Material,
                RoundKg(state.ImportQuantityKg),
                RoundKg(state.ExportQuantityKg),
                RoundKg(state.ImportQuantityKg - state.ExportQuantityKg),
                RoundVnd(state.ImportValueVnd),
                RoundVnd(state.ExportValueVnd),
                RoundVnd(state.Lots.Sum(lot => lot.RemainingKg * lot.UnitPriceVndPerKg)),
                state.KilogramsPerCubicMeter,
                state.KilogramsPerLiter,
                state.HasMissingImportPrice))
            .ToArray();

        return new MaterialFifoCalculation(values, issueValueByTransactionId, issueValueBySourceId);
    }

    private static void CoverPreviousShortage(MaterialState state, DateTime availableAt)
    {
        if (state.ShortageKg <= 0)
        {
            return;
        }

        foreach (var lot in state.Lots
                     .Where(item => item.RemainingKg > 0 && item.OccurredAt <= availableAt)
                     .OrderBy(item => item.OccurredAt)
                     .ThenBy(item => item.SourceSequence))
        {
            if (state.ShortageKg <= 0)
            {
                break;
            }

            var covered = RoundKg(Math.Min(state.ShortageKg, lot.RemainingKg));
            lot.RemainingKg = Math.Max(0m, RoundKg(lot.RemainingKg - covered));
            state.ShortageKg = Math.Max(0m, RoundKg(state.ShortageKg - covered));
        }
    }

    private static void UpdateConversion(MaterialState state, MaterialImportLot import)
    {
        var unit = NormalizeUnit(import.ConversionUnit);
        var coefficient = import.ConversionCoefficientKgPerUnit.GetValueOrDefault();
        if (coefficient <= 0 && import.ConversionVolume.GetValueOrDefault() > 0)
        {
            coefficient = import.QuantityKg / import.ConversionVolume!.Value;
        }
        if (coefficient <= 0)
        {
            return;
        }

        if (unit == "m3")
        {
            state.KilogramsPerCubicMeter = coefficient;
            state.KilogramsPerLiter = coefficient / 1000m;
        }
        else if (unit == "lit")
        {
            state.KilogramsPerLiter = coefficient;
            state.KilogramsPerCubicMeter = coefficient * 1000m;
        }
    }

    internal static string GroupCode(int materialTypeId, string materialName) =>
        materialTypeId switch
        {
            1 => MaterialReportGroups.Sand,
            2 => MaterialReportGroups.Stone,
            3 => MaterialReportGroups.Cement,
            4 => MaterialReportGroups.Water,
            5 => MaterialReportGroups.Additive,
            _ => InferGroup(materialName)
        };

    internal static string NormalizeText(string? value)
    {
        var decomposed = (value ?? string.Empty).Trim().ToUpperInvariant()
            .Normalize(NormalizationForm.FormD);
        var builder = new StringBuilder(decomposed.Length);
        foreach (var character in decomposed)
        {
            if (CharUnicodeInfo.GetUnicodeCategory(character) != UnicodeCategory.NonSpacingMark &&
                !char.IsWhiteSpace(character))
            {
                builder.Append(character == 'Đ' ? 'D' : character);
            }
        }
        return builder.ToString().Normalize(NormalizationForm.FormC);
    }

    internal static decimal RoundKg(decimal value) =>
        Math.Round(value, 0, MidpointRounding.AwayFromZero);

    internal static decimal RoundVnd(decimal value) =>
        Math.Round(value, 0, MidpointRounding.AwayFromZero);

    private static string NormalizeUnit(string? value)
    {
        var unit = NormalizeText(value).Replace("³", "3", StringComparison.Ordinal)
            .Replace(".", string.Empty, StringComparison.Ordinal)
            .ToLowerInvariant();
        return unit switch
        {
            "l" or "lit" or "liter" or "litre" => "lit",
            "m3" or "metkhoi" => "m3",
            "t" or "tan" or "ton" or "tons" or "tonne" => "tan",
            _ => unit
        };
    }

    private static string InferGroup(string name)
    {
        var normalized = NormalizeText(name);
        if (normalized.StartsWith("CAT", StringComparison.Ordinal)) return MaterialReportGroups.Sand;
        if (normalized.StartsWith("DA", StringComparison.Ordinal)) return MaterialReportGroups.Stone;
        if (normalized.StartsWith("XI", StringComparison.Ordinal)) return MaterialReportGroups.Cement;
        if (normalized.StartsWith("NUOC", StringComparison.Ordinal)) return MaterialReportGroups.Water;
        return MaterialReportGroups.Additive;
    }

    private sealed class MaterialResolver
    {
        private readonly IReadOnlyDictionary<int, MaterialDefinition> byCode;
        private readonly IReadOnlyDictionary<int, MaterialDefinition> bySlot;
        private readonly IReadOnlyDictionary<string, MaterialDefinition> byName;

        public MaterialResolver(IReadOnlyList<MaterialDefinition> materials)
        {
            byCode = materials.GroupBy(item => item.Code).ToDictionary(group => group.Key, group => group.First());
            bySlot = materials.Where(item => item.SlotNumber > 0).GroupBy(item => item.SlotNumber)
                .ToDictionary(group => group.Key, group => group.First());
            byName = materials.Where(item => !string.IsNullOrWhiteSpace(item.Name))
                .GroupBy(item => NormalizeText(item.Name), StringComparer.Ordinal)
                .ToDictionary(group => group.Key, group => group.First(), StringComparer.Ordinal);
        }

        public MaterialDefinition? Resolve(int? code, int? slotNumber, string? name)
        {
            if (code.HasValue && byCode.TryGetValue(code.Value, out var byExactCode)) return byExactCode;
            if (slotNumber.HasValue && bySlot.TryGetValue(slotNumber.Value, out var byExactSlot)) return byExactSlot;
            return byName.GetValueOrDefault(NormalizeText(name));
        }
    }

    private sealed class MaterialState(MaterialDefinition material)
    {
        public MaterialDefinition Material { get; } = material;
        public List<FifoLot> Lots { get; } = [];
        public decimal ImportQuantityKg { get; set; }
        public decimal ExportQuantityKg { get; set; }
        public decimal ImportValueVnd { get; set; }
        public decimal ExportValueVnd { get; set; }
        public decimal ShortageKg { get; set; }
        public decimal? KilogramsPerCubicMeter { get; set; }
        public decimal? KilogramsPerLiter { get; set; }
        public bool HasMissingImportPrice { get; set; }
    }

    private sealed class FifoLot(
        DateTime occurredAt,
        long sourceSequence,
        decimal remainingKg,
        decimal unitPriceVndPerKg)
    {
        public DateTime OccurredAt { get; } = occurredAt;
        public long SourceSequence { get; } = sourceSequence;
        public decimal RemainingKg { get; set; } = remainingKg;
        public decimal UnitPriceVndPerKg { get; } = unitPriceVndPerKg;
    }
}
