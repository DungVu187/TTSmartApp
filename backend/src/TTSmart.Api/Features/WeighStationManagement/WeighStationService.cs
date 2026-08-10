using System.ComponentModel.DataAnnotations;
using System.Globalization;
using System.Text;
using TTSmart.Api.Data.StationOperations;
using TTSmart.Api.Features.BranchManagement;

namespace TTSmart.Api.Features.WeighStationManagement;

public sealed class WeighStationService(
    IBranchAccessResolver branchAccessResolver,
    IWeighStationDataSource dataSource) : IWeighStationService
{
    private static readonly TimeSpan VietnamOffset = TimeSpan.FromHours(7);
    public async Task<IReadOnlyList<WeighStationStationResponse>> GetStationsAsync(
        WeighStationStationQuery query,
        int currentUserId,
        CancellationToken cancellationToken)
    {
        var branches = await branchAccessResolver.GetWeighStationBranchesAsync(
            currentUserId,
            query.CompanyId,
            cancellationToken);
        return branches
            .Select(branch => new WeighStationStationResponse(branch.Id, branch.Name))
            .ToArray();
    }

    public async Task<WeighStationFilterOptionsResponse> GetFilterOptionsAsync(
        WeighStationFilterOptionsQuery query,
        int currentUserId,
        CancellationToken cancellationToken)
    {
        var stage = GetOptionalStage(query.Stage);
        var filter = CreateFilter(query.From, query.To);
        var branch = await branchAccessResolver.GetRequiredWeighStationBranchAsync(
            currentUserId,
            query.CompanyId,
            query.BranchId,
            cancellationToken);
        var options = await dataSource.GetFilterOptionsAsync(
            CreateTarget(branch),
            stage,
            filter,
            cancellationToken);
        return new WeighStationFilterOptionsResponse(
            options.VehiclePlates,
            options.GoodsNames,
            options.OperatorNames,
            options.UnitNames,
            options.WeighingTypes);
    }

    public async Task<WeighStationResponse> SearchAsync(
        WeighStationQuery query,
        int currentUserId,
        bool canViewMaterialValue,
        CancellationToken cancellationToken)
    {
        var stage = GetOptionalStage(query.Stage);
        var pageOffset = CalculatePageOffset(query.PageNumber);
        var filter = CreateFilter(query);
        var branch = await branchAccessResolver.GetRequiredWeighStationBranchAsync(
            currentUserId,
            query.CompanyId,
            query.BranchId,
            cancellationToken);
        var page = await dataSource.SearchAsync(
            CreateTarget(branch),
            stage,
            filter,
            pageOffset,
            cancellationToken);
        return CreateDetailResponse(
            page.Items,
            query.PageNumber,
            page.TotalCount,
            pageOffset,
            canViewMaterialValue);
    }

    public async Task<WeighStationResponse> SearchAllAsync(
        WeighStationQuery query,
        int currentUserId,
        bool canViewMaterialValue,
        CancellationToken cancellationToken)
    {
        var stage = GetOptionalStage(query.Stage);
        var filter = CreateFilter(query);
        var branch = await branchAccessResolver.GetRequiredWeighStationBranchAsync(
            currentUserId,
            query.CompanyId,
            query.BranchId,
            cancellationToken);
        var rows = await dataSource.SearchAllAsync(
            CreateTarget(branch),
            stage,
            filter,
            cancellationToken);
        var items = rows
            .Select((row, index) => MapItem(row, index + 1))
            .ToArray();
        return new WeighStationResponse(
            items,
            1,
            items.Length,
            items.Length,
            items.Length == 0 ? 0 : 1,
            canViewMaterialValue);
    }

    public async Task<WeighStationSummaryResponse> GetSummaryAsync(
        WeighStationQuery query,
        int currentUserId,
        bool canViewMaterialValue,
        CancellationToken cancellationToken)
    {
        var stage = GetOptionalStage(query.Stage);
        var pageOffset = CalculatePageOffset(query.PageNumber);
        var filter = CreateFilter(query);
        var branch = await branchAccessResolver.GetRequiredWeighStationBranchAsync(
            currentUserId,
            query.CompanyId,
            query.BranchId,
            cancellationToken);
        var aggregates = await dataSource.GetSummaryAsync(
            CreateTarget(branch),
            stage,
            filter,
            cancellationToken);
        return CreateSummaryResponse(
            aggregates,
            query.PageNumber,
            pageOffset,
            WeighStationContractDefaults.PageSize,
            canViewMaterialValue);
    }

    public async Task<WeighStationSummaryResponse> GetSummaryAllAsync(
        WeighStationQuery query,
        int currentUserId,
        bool canViewMaterialValue,
        CancellationToken cancellationToken)
    {
        var stage = GetOptionalStage(query.Stage);
        var filter = CreateFilter(query);
        var branch = await branchAccessResolver.GetRequiredWeighStationBranchAsync(
            currentUserId,
            query.CompanyId,
            query.BranchId,
            cancellationToken);
        var aggregates = await dataSource.GetSummaryAsync(
            CreateTarget(branch),
            stage,
            filter,
            cancellationToken);
        return CreateSummaryResponse(
            aggregates,
            1,
            0,
            int.MaxValue,
            canViewMaterialValue);
    }

    private static WeighStationResponse CreateDetailResponse(
        IReadOnlyList<WeighStationRow> rows,
        int pageNumber,
        int totalCount,
        int pageOffset,
        bool canViewMaterialValue)
    {
        var items = rows
            .Select((row, index) => MapItem(row, pageOffset + index + 1))
            .ToArray();
        return new WeighStationResponse(
            items,
            pageNumber,
            WeighStationContractDefaults.PageSize,
            totalCount,
            CalculateTotalPages(totalCount),
            canViewMaterialValue);
    }

    private static WeighStationItemResponse MapItem(WeighStationRow row, int stt)
    {
        var convertedUnit = NormalizeConversionUnit(row.ConversionUnit);
        var convertedQuantity = CalculateConvertedQuantity(
            row.GoodsWeight,
            row.ConversionFactor,
            row.ConversionUnit);
        var conversionMessage = GetConversionMessage(row.ConversionFactor);
        return new WeighStationItemResponse(
            stt,
            row.Id,
            row.TicketNumber,
            TrimOrNull(row.TicketCode),
            ToUtc(row.LastUpdatedAt),
            TrimOrNull(row.VehiclePlate),
            TrimOrNull(row.DriverName),
            TrimOrNull(row.SealNumber),
            NormalizeWeight(row.FirstWeight),
            NormalizeWeight(row.SecondWeight),
            row.GoodsWeight,
            convertedQuantity.HasValue,
            convertedQuantity,
            convertedUnit,
            conversionMessage,
            null,
            TrimOrNull(row.UnitName),
            TrimOrNull(row.GoodsName),
            TrimOrNull(row.WeighingType),
            TrimOrNull(row.FirstOperatorName),
            TrimOrNull(row.SecondOperatorName),
            ToUtc(row.FirstWeighedAt),
            ToUtc(row.SecondWeighedAt));
    }

    private static WeighStationSummaryResponse CreateSummaryResponse(
        IReadOnlyList<WeighStationSummaryAggregate> aggregates,
        int pageNumber,
        int pageOffset,
        int pageSize,
        bool canViewMaterialValue)
    {
        var materialTotals = new Dictionary<string, SummaryAccumulator>(
            StringComparer.OrdinalIgnoreCase);
        var totalConversions = new Dictionary<string, decimal>(StringComparer.OrdinalIgnoreCase);
        decimal totalGoodsWeight = 0;

        foreach (var aggregate in aggregates)
        {
            var goodsName = TrimOrNull(aggregate.GoodsName);
            var goodsKey = goodsName ?? string.Empty;
            if (!materialTotals.TryGetValue(goodsKey, out var material))
            {
                material = new SummaryAccumulator(goodsName);
                materialTotals.Add(goodsKey, material);
            }

            material.GoodsWeight += aggregate.GoodsWeight;
            totalGoodsWeight += aggregate.GoodsWeight;

            var unit = NormalizeConversionUnit(aggregate.ConversionUnit);
            var conversionMessage = GetConversionMessage(aggregate.ConversionFactor);
            if (conversionMessage is not null)
            {
                material.ConversionMessage = conversionMessage;
            }
            var convertedQuantity = CalculateConvertedQuantity(
                aggregate.GoodsWeight,
                aggregate.ConversionFactor,
                aggregate.ConversionUnit);
            if (!convertedQuantity.HasValue)
            {
                continue;
            }

            AddQuantity(material.ConvertedQuantities, unit, convertedQuantity.Value);
            AddQuantity(totalConversions, unit, convertedQuantity.Value);
        }

        var orderedMaterials = materialTotals.Values
            .OrderByDescending(item => item.GoodsWeight)
            .ThenBy(item => item.GoodsName, StringComparer.OrdinalIgnoreCase)
            .ToArray();
        var items = orderedMaterials
            .Skip(pageOffset)
            .Take(pageSize)
            .Select((item, index) => new WeighStationSummaryItemResponse(
                pageOffset + index + 1,
                item.GoodsName,
                RoundQuantity(item.GoodsWeight),
                MapConvertedQuantities(item.ConvertedQuantities),
                item.ConversionMessage,
                null))
            .ToArray();
        var topGoods = orderedMaterials.Length == 0
            ? null
            : new WeighStationTopGoodsResponse(
                orderedMaterials[0].GoodsName,
                RoundQuantity(orderedMaterials[0].GoodsWeight));

        return new WeighStationSummaryResponse(
            items,
            pageNumber,
            pageSize == int.MaxValue ? items.Length : pageSize,
            orderedMaterials.Length,
            pageSize == int.MaxValue
                ? orderedMaterials.Length == 0 ? 0 : 1
                : CalculateTotalPages(orderedMaterials.Length),
            RoundQuantity(totalGoodsWeight),
            MapConvertedQuantities(totalConversions),
            topGoods,
            Array.Empty<WeighStationSummaryGroupResponse>(),
            null,
            canViewMaterialValue);
    }

    private static IReadOnlyList<WeighStationConvertedQuantityResponse> MapConvertedQuantities(
        IReadOnlyDictionary<string, decimal> quantities) =>
        quantities
            .Where(item => item.Value != 0)
            .OrderBy(item => GetUnitOrder(item.Key))
            .ThenBy(item => item.Key, StringComparer.OrdinalIgnoreCase)
            .Select(item => new WeighStationConvertedQuantityResponse(
                RoundQuantity(item.Value),
                item.Key))
            .ToArray();

    private static void AddQuantity(
        IDictionary<string, decimal> quantities,
        string unit,
        decimal quantity)
    {
        quantities.TryGetValue(unit, out var current);
        quantities[unit] = current + quantity;
    }

    private static string NormalizeForSearch(string? value)
    {
        var trimmed = TrimOrNull(value);
        if (trimmed is null)
        {
            return string.Empty;
        }

        var builder = new StringBuilder(trimmed.Length);
        foreach (var character in trimmed.Normalize(NormalizationForm.FormD))
        {
            if (CharUnicodeInfo.GetUnicodeCategory(character) != UnicodeCategory.NonSpacingMark)
            {
                builder.Append(character);
            }
        }
        builder.Replace('Đ', 'D').Replace('đ', 'd');
        return builder.ToString()
            .Normalize(NormalizationForm.FormC)
            .ToUpperInvariant();
    }

    private static WeighStationFilter CreateFilter(WeighStationQuery query) =>
        CreateFilter(
            query.From,
            query.To,
            query.VehiclePlate,
            query.GoodsName,
            query.OperatorName,
            query.UnitName,
            query.WeighingType);

    private static WeighStationFilter CreateFilter(
        DateTimeOffset? from,
        DateTimeOffset? to,
        string? vehiclePlate = null,
        string? goodsName = null,
        string? operatorName = null,
        string? unitName = null,
        string? weighingType = null)
    {
        if (!from.HasValue || !to.HasValue)
        {
            throw new ValidationException("Khoảng thời gian là bắt buộc.");
        }

        var fromLocal = ToVietnamLocal(from.Value);
        var toExclusive = ToVietnamLocal(to.Value);
        if (fromLocal >= toExclusive)
        {
            throw new ValidationException("Thời gian bắt đầu phải nhỏ hơn thời gian kết thúc.");
        }

        return new WeighStationFilter(
            fromLocal,
            toExclusive,
            TrimOrNull(vehiclePlate),
            TrimOrNull(goodsName),
            TrimOrNull(operatorName),
            TrimOrNull(unitName),
            TrimOrNull(weighingType));
    }

    private static WeighStationStage? GetOptionalStage(WeighStationStage? stage)
    {
        if (stage.HasValue && !Enum.IsDefined(stage.Value))
        {
            throw new ValidationException("Kiểu thống kê cân không hợp lệ.");
        }
        return stage;
    }

    private static int CalculatePageOffset(int pageNumber)
    {
        if (pageNumber < 1)
        {
            throw new ValidationException("Số trang không hợp lệ.");
        }
        try
        {
            return checked((pageNumber - 1) * WeighStationContractDefaults.PageSize);
        }
        catch (OverflowException exception)
        {
            throw new ValidationException("Số trang vượt quá giới hạn cho phép.", exception);
        }
    }

    private static int CalculateTotalPages(int totalCount) =>
        totalCount == 0
            ? 0
            : (totalCount + WeighStationContractDefaults.PageSize - 1) /
                WeighStationContractDefaults.PageSize;

    private static StationDatabaseTarget CreateTarget(AuthorizedBranch branch) =>
        new(branch.Id, branch.DatabaseName, branch.TypeTram);

    private static DateTime ToVietnamLocal(DateTimeOffset value) =>
        DateTime.SpecifyKind(value.ToOffset(VietnamOffset).DateTime, DateTimeKind.Unspecified);

    private static DateTimeOffset? ToUtc(DateTime? value)
    {
        if (!value.HasValue)
        {
            return null;
        }
        var local = DateTime.SpecifyKind(value.Value, DateTimeKind.Unspecified);
        return new DateTimeOffset(local, VietnamOffset).ToUniversalTime();
    }

    private static decimal? NormalizeWeight(double? value)
    {
        if (!value.HasValue || !double.IsFinite(value.Value))
        {
            return null;
        }
        try
        {
            return RoundQuantity((decimal)value.Value);
        }
        catch (OverflowException)
        {
            return null;
        }
    }

    private static decimal? CalculateConvertedQuantity(
        decimal? goodsWeight,
        float? conversionFactor,
        string? conversionUnit)
    {
        var unitCode = NormalizeConversionUnitCode(conversionUnit);
        if (!goodsWeight.HasValue || HasUndefinedConversionFactor(conversionFactor))
        {
            return null;
        }
        try
        {
            var factor = conversionFactor.GetValueOrDefault();
            var divisor = unitCode == "KG"
                ? 1000m
                : (decimal)factor;
            return RoundQuantity(goodsWeight.Value / divisor);
        }
        catch (OverflowException)
        {
            return null;
        }
    }

    private static string? GetConversionMessage(float? conversionFactor) =>
        HasUndefinedConversionFactor(conversionFactor)
            ? WeighStationConversionMessages.Undefined
            : null;

    private static bool HasUndefinedConversionFactor(float? conversionFactor) =>
        !conversionFactor.HasValue ||
        !float.IsFinite(conversionFactor.Value) ||
        conversionFactor.Value <= 0;

    private static string NormalizeConversionUnit(string? value)
    {
        var unit = TrimOrNull(value) ?? "KG";
        var normalized = NormalizeForSearch(unit)
            .Replace("^", string.Empty, StringComparison.Ordinal)
            .Replace("³", "3", StringComparison.Ordinal)
            .Replace(" ", string.Empty, StringComparison.Ordinal);
        return normalized switch
        {
            "M3" => "m³",
            "TAN" or "TON" => "tấn",
            "L" or "LIT" or "LITER" => "L",
            "KG" => "tấn",
            _ => unit
        };
    }

    private static string NormalizeConversionUnitCode(string? value)
    {
        var unit = TrimOrNull(value) ?? "KG";
        return NormalizeForSearch(unit)
            .Replace("^", string.Empty, StringComparison.Ordinal)
            .Replace("³", "3", StringComparison.Ordinal)
            .Replace(" ", string.Empty, StringComparison.Ordinal);
    }

    private static int GetUnitOrder(string unit) => unit switch
    {
        "m³" => 0,
        "tấn" => 1,
        "L" => 2,
        _ => 3
    };

    private static decimal RoundQuantity(decimal value) =>
        Math.Round(value, 3, MidpointRounding.AwayFromZero);

    private static string? TrimOrNull(string? value)
    {
        var trimmed = value?.Trim();
        return string.IsNullOrEmpty(trimmed) ? null : trimmed;
    }

    private sealed class SummaryAccumulator(string? goodsName)
    {
        public string? GoodsName { get; } = goodsName;
        public decimal GoodsWeight { get; set; }
        public string? ConversionMessage { get; set; }
        public Dictionary<string, decimal> ConvertedQuantities { get; } =
            new(StringComparer.OrdinalIgnoreCase);
    }
}
