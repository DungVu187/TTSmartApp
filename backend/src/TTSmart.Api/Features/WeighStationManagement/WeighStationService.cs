using System.ComponentModel.DataAnnotations;
using System.Globalization;
using System.Text;
using Microsoft.Extensions.Options;
using TTSmart.Api.Data.StationOperations;
using TTSmart.Api.Features.BranchManagement;

namespace TTSmart.Api.Features.WeighStationManagement;

public sealed class WeighStationService(
    IBranchAccessResolver branchAccessResolver,
    IWeighStationDataSource dataSource,
    IWeighStationMaterialValueDataSource materialValueDataSource,
    IOptions<WeighStationMaterialValueOptions> materialValueOptions,
    ILogger<WeighStationService> logger) : IWeighStationService
{
    private static readonly TimeSpan VietnamOffset = TimeSpan.FromHours(7);
    private static readonly string[] BusinessGroupOrder =
    [
        "NHAP_CAT_DA",
        "NHAP_XI",
        "NHAP_PHU_GIA",
        "NHAP_KHAC",
        "XUAT_HANG",
        "DICH_VU",
        "KHAC"
    ];
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
        var materialValues = WeighStationMaterialValues.Empty;
        if (canViewMaterialValue)
        {
            materialValues = await LoadMaterialValuesAsync(
                branch, currentUserId, page.Items, cancellationToken);
        }
        return CreateDetailResponse(
            page.Items,
            query.PageNumber,
            page.TotalCount,
            pageOffset,
            canViewMaterialValue,
            materialValues);
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
        var materialValues = canViewMaterialValue
            ? await LoadMaterialValuesAsync(branch, currentUserId, rows, cancellationToken)
            : WeighStationMaterialValues.Empty;
        var items = rows
            .Select((row, index) => MapItem(row, index + 1, materialValues))
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
        var target = CreateTarget(branch);
        var aggregatesTask = dataSource.GetSummaryAsync(
            target, stage, filter, cancellationToken);
        IReadOnlyList<WeighStationRow> materialRows = [];
        var materialValues = WeighStationMaterialValues.Empty;
        if (canViewMaterialValue)
        {
            var materialRowsTask = dataSource.SearchAllAsync(
                target, stage, filter, cancellationToken);
            await Task.WhenAll(aggregatesTask, materialRowsTask);
            materialRows = await materialRowsTask;
            materialValues = await LoadMaterialValuesAsync(
                branch, currentUserId, materialRows, cancellationToken);
        }
        var aggregates = await aggregatesTask;
        return CreateSummaryResponse(
            aggregates,
            query.PageNumber,
            pageOffset,
            WeighStationContractDefaults.PageSize,
            canViewMaterialValue,
            materialRows,
            materialValues);
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
        IReadOnlyList<WeighStationRow> materialRows = [];
        var materialValues = WeighStationMaterialValues.Empty;
        if (canViewMaterialValue)
        {
            materialRows = await dataSource.SearchAllAsync(
                CreateTarget(branch), stage, filter, cancellationToken);
            materialValues = await LoadMaterialValuesAsync(
                branch, currentUserId, materialRows, cancellationToken);
        }
        return CreateSummaryResponse(
            aggregates,
            1,
            0,
            int.MaxValue,
            canViewMaterialValue,
            materialRows,
            materialValues);
    }

    private static WeighStationResponse CreateDetailResponse(
        IReadOnlyList<WeighStationRow> rows,
        int pageNumber,
        int totalCount,
        int pageOffset,
        bool canViewMaterialValue,
        WeighStationMaterialValues materialValues)
    {
        var items = rows
            .Select((row, index) => MapItem(row, pageOffset + index + 1, materialValues))
            .ToArray();
        return new WeighStationResponse(
            items,
            pageNumber,
            WeighStationContractDefaults.PageSize,
            totalCount,
            CalculateTotalPages(totalCount),
            canViewMaterialValue);
    }

    private static WeighStationItemResponse MapItem(
        WeighStationRow row,
        int stt,
        WeighStationMaterialValues materialValues)
    {
        var conversion = ConvertScaleWeight(
            row.GoodsWeight,
            row.ConversionFactor,
            row.ConversionUnit,
            row.MaterialCategory,
            row.GoodsName);
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
            conversion.IsConfigured,
            conversion.Quantity,
            TrimOrNull(conversion.Unit),
            conversion.IsConfigured ? null : WeighStationConversionMessages.Undefined,
            materialValues.ByTicketNumber.TryGetValue(row.TicketNumber, out var materialValue)
                ? materialValue
                : null,
            TrimOrNull(row.UnitName),
            TrimOrNull(row.GoodsName),
            TrimOrNull(row.WeighingType),
            TrimOrNull(row.FirstOperatorName),
            TrimOrNull(row.SecondOperatorName),
            ToUtc(row.FirstWeighedAt),
            ToUtc(row.SecondWeighedAt),
            row.VehicleExitStatus);
    }

    private static WeighStationSummaryResponse CreateSummaryResponse(
        IReadOnlyList<WeighStationSummaryAggregate> aggregates,
        int pageNumber,
        int pageOffset,
        int pageSize,
        bool canViewMaterialValue,
        IReadOnlyList<WeighStationRow> materialRows,
        WeighStationMaterialValues materialValues)
    {
        var materialTotals = new Dictionary<string, SummaryAccumulator>(
            StringComparer.OrdinalIgnoreCase);
        var groupTotals = new Dictionary<string, GroupAccumulator>(StringComparer.OrdinalIgnoreCase);
        decimal totalGoodsWeight = 0;
        var materialValueByName = new Dictionary<string, decimal>(StringComparer.OrdinalIgnoreCase);
        var materialValueByGroup = new Dictionary<string, decimal>(StringComparer.OrdinalIgnoreCase);
        foreach (var row in materialRows)
        {
            if (!materialValues.ByTicketNumber.TryGetValue(row.TicketNumber, out var value))
            {
                continue;
            }
            var nameKey = NormalizeForSearch(row.GoodsName);
            materialValueByName.TryGetValue(nameKey, out var currentNameValue);
            materialValueByName[nameKey] = currentNameValue + value;
            var rowConversion = ConvertScaleWeight(
                row.GoodsWeight,
                row.ConversionFactor,
                row.ConversionUnit,
                row.MaterialCategory,
                row.GoodsName);
            var groupKey = GetBusinessGroupKey(
                row.WeighingType,
                row.MaterialCategory,
                row.GoodsName,
                rowConversion.Unit);
            materialValueByGroup.TryGetValue(groupKey, out var currentGroupValue);
            materialValueByGroup[groupKey] = currentGroupValue + value;
        }

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
            material.TicketCount += aggregate.TicketCount;
            totalGoodsWeight += aggregate.GoodsWeight;

            var conversion = ConvertScaleWeight(
                aggregate.GoodsWeight,
                aggregate.ConversionFactor,
                aggregate.ConversionUnit,
                aggregate.MaterialCategory,
                aggregate.GoodsName);
            material.AddConversion(conversion);

            var groupKey = GetBusinessGroupKey(
                aggregate.WeighingType,
                aggregate.MaterialCategory,
                aggregate.GoodsName,
                conversion.Unit);
            if (!groupTotals.TryGetValue(groupKey, out var group))
            {
                group = new GroupAccumulator(groupKey, GetBusinessGroupLabel(groupKey));
                groupTotals.Add(groupKey, group);
            }
            group.GoodsWeight += aggregate.GoodsWeight;
            if (conversion.IsConfigured && conversion.Quantity.HasValue)
            {
                AddQuantity(group.ConvertedQuantities, conversion.Unit, conversion.Quantity.Value);
            }
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
                materialValueByName.TryGetValue(NormalizeForSearch(item.GoodsName), out var itemValue)
                    ? RoundMoney(itemValue)
                    : null,
                item.TicketCount))
            .ToArray();
        var topGoods = orderedMaterials.Length == 0
            ? null
            : new WeighStationTopGoodsResponse(
                orderedMaterials[0].GoodsName,
                RoundQuantity(orderedMaterials[0].GoodsWeight));
        var totalConversions = new Dictionary<string, decimal>(StringComparer.OrdinalIgnoreCase);
        foreach (var material in orderedMaterials)
        {
            foreach (var conversion in material.ConvertedQuantities)
            {
                AddQuantity(totalConversions, conversion.Key, conversion.Value);
            }
        }
        var groups = BusinessGroupOrder
            .Where(groupTotals.ContainsKey)
            .Select(key => groupTotals[key])
            .Where(group => group.GoodsWeight > 0)
            .Select(group => new WeighStationSummaryGroupResponse(
                group.Key,
                group.Label,
                RoundQuantity(group.GoodsWeight),
                MapConvertedQuantities(group.ConvertedQuantities),
                materialValueByGroup.TryGetValue(group.Key, out var groupValue)
                    ? RoundMoney(groupValue)
                    : null))
            .ToArray();

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
            groups,
            materialValues.ByTicketNumber.Count == 0
                ? null
                : RoundMoney(materialValues.ByTicketNumber.Values.Sum()),
            canViewMaterialValue);
    }

    private async Task<WeighStationMaterialValues> LoadMaterialValuesAsync(
        AuthorizedBranch scaleBranch,
        int currentUserId,
        IReadOnlyList<WeighStationRow> rows,
        CancellationToken cancellationToken)
    {
        if (rows.Count == 0)
        {
            return WeighStationMaterialValues.Empty;
        }

        using var priceTimeout = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        priceTimeout.CancelAfter(materialValueOptions.Value.MaterialValueTimeoutMilliseconds);
        try
        {
            var mixingBranches = await branchAccessResolver
                .GetRelatedMixingBranchesForWeighStationAsync(
                    currentUserId,
                    scaleBranch.Id,
                    priceTimeout.Token);
            return await materialValueDataSource.CalculateAsync(
                CreateTarget(scaleBranch),
                CreateMixingTargets(scaleBranch, mixingBranches),
                rows,
                priceTimeout.Token);
        }
        catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
        {
            logger.LogWarning(
                "Weigh-station material-value calculation exceeded its optional time budget. " +
                "TimeoutMilliseconds={TimeoutMilliseconds}",
                materialValueOptions.Value.MaterialValueTimeoutMilliseconds);
            return WeighStationMaterialValues.Empty;
        }
        catch (Exception exception) when (!cancellationToken.IsCancellationRequested)
        {
            logger.LogWarning(
                "Weigh-station material-value calculation failed; scale data will be returned without values. " +
                "ErrorType={ErrorType}",
                exception.GetType().Name);
            return WeighStationMaterialValues.Empty;
        }
    }

    private static IReadOnlyList<StationDatabaseTarget> CreateMixingTargets(
        AuthorizedBranch scaleBranch,
        IReadOnlyList<AuthorizedBranch> mixingBranches)
    {
        var result = mixingBranches.Select(CreateTarget).ToList();
        var databaseName = ExtractInitialCatalog(scaleBranch.VehicleManagementConnection);
        if (databaseName.Length is > 0 and <= 128 &&
            databaseName.All(character => char.IsLetterOrDigit(character) || character == '_'))
        {
            result.Insert(0, new StationDatabaseTarget(-scaleBranch.Id, databaseName, null));
        }
        return result;
    }

    private static string ExtractInitialCatalog(string? connectionText)
    {
        var text = TrimOrNull(connectionText) ?? string.Empty;
        if (!text.Contains(';') && !text.Contains('='))
        {
            return text;
        }
        foreach (var part in text.Split(';', StringSplitOptions.RemoveEmptyEntries))
        {
            var tokens = part.Split('=', 2);
            if (tokens.Length == 2 &&
                (tokens[0].Trim().Equals("INITIAL CATALOG", StringComparison.OrdinalIgnoreCase) ||
                 tokens[0].Trim().Equals("DATABASE", StringComparison.OrdinalIgnoreCase)))
            {
                return tokens[1].Trim();
            }
        }
        return string.Empty;
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
        var toInclusive = ToVietnamLocal(to.Value);
        if (fromLocal > toInclusive)
        {
            throw new ValidationException("Thời gian bắt đầu phải nhỏ hơn hoặc bằng thời gian kết thúc.");
        }

        return new WeighStationFilter(
            fromLocal,
            toInclusive,
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

    private static ConversionResult ConvertScaleWeight(
        decimal? goodsWeight,
        float? conversionFactor,
        string? conversionUnit,
        string? materialCategory,
        string? goodsName)
    {
        if (!goodsWeight.HasValue)
        {
            return ConversionResult.Undefined(string.Empty);
        }

        var weight = goodsWeight.Value;
        var unitCode = NormalizeConversionUnitCode(conversionUnit);
        var categoryCode = NormalizeForSearch(materialCategory).Replace(" ", string.Empty, StringComparison.Ordinal);
        var nameCode = NormalizeForSearch(goodsName).Replace(" ", string.Empty, StringComparison.Ordinal);
        var factor = conversionFactor.HasValue && float.IsFinite(conversionFactor.Value)
            ? (decimal)conversionFactor.Value
            : 0m;

        try
        {
            if (IsAdditive(categoryCode, nameCode))
            {
                var divisor = factor > 0 ? factor : 1m;
                return ConversionResult.Configured(RoundQuantity(weight / divisor), "L");
            }
            if (unitCode is "M3" or "METKHOI")
            {
                return factor > 0
                    ? ConversionResult.Configured(RoundQuantity(weight / factor), "m³")
                    : ConversionResult.Undefined("m³");
            }
            if (unitCode is "KG" or "T" or "TAN" or "TON")
            {
                return ConversionResult.Configured(RoundQuantity(weight / 1000m), "tấn");
            }
            if (unitCode is "L" or "LIT" or "LITRE" or "LITER")
            {
                return factor > 0
                    ? ConversionResult.Configured(RoundQuantity(weight / factor), "L")
                    : ConversionResult.Undefined("L");
            }
            if (nameCode.Contains("XIMANG", StringComparison.Ordinal) ||
                nameCode.Contains("XYMANG", StringComparison.Ordinal))
            {
                return ConversionResult.Configured(RoundQuantity(weight / 1000m), "tấn");
            }
            if (factor >= 100m)
            {
                return ConversionResult.Configured(RoundQuantity(weight / factor), "m³");
            }
            return ConversionResult.Undefined(string.Empty);
        }
        catch (Exception exception) when (exception is OverflowException or DivideByZeroException)
        {
            return ConversionResult.Undefined(string.Empty);
        }
    }

    private static string NormalizeConversionUnitCode(string? value)
    {
        var unit = TrimOrNull(value) ?? string.Empty;
        return NormalizeForSearch(unit)
            .Replace("^", string.Empty, StringComparison.Ordinal)
            .Replace("³", "3", StringComparison.Ordinal)
            .Replace(" ", string.Empty, StringComparison.Ordinal);
    }

    private static bool IsAdditive(string categoryCode, string nameCode) =>
        categoryCode is "PHUGIA" or "ADDITIVE" ||
        nameCode.Contains("PHUGIA", StringComparison.Ordinal) ||
        nameCode.Contains("SIKA", StringComparison.Ordinal) ||
        nameCode.Contains("SILKROAD", StringComparison.Ordinal) ||
        nameCode.Contains("SP3000", StringComparison.Ordinal) ||
        nameCode.Contains("BASF", StringComparison.Ordinal) ||
        nameCode.Contains("TROBAY", StringComparison.Ordinal) ||
        nameCode.Contains("FLYASH", StringComparison.Ordinal);

    private static string GetBusinessGroupKey(
        string? weighingType,
        string? materialCategory,
        string? goodsName,
        string convertedUnit)
    {
        var type = NormalizeForSearch(weighingType).Replace(" ", string.Empty, StringComparison.Ordinal);
        if (type is "NHAPHANG" or "NHAP")
        {
            var materialGroup = DetectMaterialGroup(materialCategory, goodsName);
            var unit = NormalizeForSearch(convertedUnit)
                .Replace("³", "3", StringComparison.Ordinal)
                .Replace(" ", string.Empty, StringComparison.Ordinal);
            if (materialGroup is "CAT" or "DA" || unit == "M3") return "NHAP_CAT_DA";
            if (materialGroup == "XI" || unit is "TAN" or "T") return "NHAP_XI";
            if (materialGroup == "PHUGIA" || unit is "L" or "LIT") return "NHAP_PHU_GIA";
            return "NHAP_KHAC";
        }
        if (type is "BANHANG" or "BAN" or "XUATHANG" or "XUAT") return "XUAT_HANG";
        if (type == "DICHVU") return "DICH_VU";
        return "KHAC";
    }

    private static string DetectMaterialGroup(string? materialCategory, string? goodsName)
    {
        var category = NormalizeForSearch(materialCategory).Replace(" ", string.Empty, StringComparison.Ordinal);
        var name = NormalizeForSearch(goodsName).Replace(" ", string.Empty, StringComparison.Ordinal);
        if (category is "NUOC" or "WATER" || name.Contains("NUOC", StringComparison.Ordinal) || name.Contains("WATER", StringComparison.Ordinal)) return "NUOC";
        if (name.Contains("TROBAY", StringComparison.Ordinal) || name.Contains("FLYASH", StringComparison.Ordinal)) return "PHUGIA";
        if (category is "PHUGIA" or "ADDITIVE") return "PHUGIA";
        if (category == "CAT") return "CAT";
        if (category == "DA") return "DA";
        if (category is "XI" or "XIMANG" or "CEMENT") return "XI";
        if (name.Contains("PHUGIA", StringComparison.Ordinal) || name.Contains("ADDITIVE", StringComparison.Ordinal) || name.Contains("BIFI", StringComparison.Ordinal) || name.Contains("SILKROAD", StringComparison.Ordinal) || name.Contains("WPA", StringComparison.Ordinal)) return "PHUGIA";
        if (name.Contains("XIMANG", StringComparison.Ordinal) || name.Contains("XYMANG", StringComparison.Ordinal) || name.Contains("CEMENT", StringComparison.Ordinal) || name.StartsWith("XI", StringComparison.Ordinal)) return "XI";
        if (name.Contains("CAT", StringComparison.Ordinal)) return "CAT";
        if (name == "DA" || name.StartsWith("DA", StringComparison.Ordinal) || name.Contains("DAMAT", StringComparison.Ordinal) || name.Contains("DA1X2", StringComparison.Ordinal)) return "DA";
        return string.Empty;
    }

    private static string GetBusinessGroupLabel(string key) => key switch
    {
        "NHAP_CAT_DA" => "Nhập hàng - Cát, đá",
        "NHAP_XI" => "Nhập hàng - Xi măng",
        "NHAP_PHU_GIA" => "Nhập hàng - Phụ gia",
        "NHAP_KHAC" => "Nhập hàng - Khác",
        "XUAT_HANG" => "Xuất hàng",
        "DICH_VU" => "Dịch vụ",
        _ => "Khác"
    };

    private static int GetUnitOrder(string unit) => unit switch
    {
        "m³" => 0,
        "tấn" => 1,
        "L" => 2,
        _ => 3
    };

    private static decimal RoundQuantity(decimal value) =>
        Math.Round(value, 3, MidpointRounding.AwayFromZero);

    private static decimal RoundMoney(decimal value) =>
        Math.Round(value, 0, MidpointRounding.AwayFromZero);

    private static string? TrimOrNull(string? value)
    {
        var trimmed = value?.Trim();
        return string.IsNullOrEmpty(trimmed) ? null : trimmed;
    }

    private sealed class SummaryAccumulator(string? goodsName)
    {
        public string? GoodsName { get; } = goodsName;
        public decimal GoodsWeight { get; set; }
        public int TicketCount { get; set; }
        public string? ConversionMessage { get; set; }
        public Dictionary<string, decimal> ConvertedQuantities { get; } =
            new(StringComparer.OrdinalIgnoreCase);

        public void AddConversion(ConversionResult conversion)
        {
            if (!conversion.IsConfigured || !conversion.Quantity.HasValue)
            {
                ConversionMessage = WeighStationConversionMessages.Undefined;
                ConvertedQuantities.Clear();
                return;
            }
            if (ConversionMessage is not null)
            {
                return;
            }
            if (ConvertedQuantities.Count > 0 && !ConvertedQuantities.ContainsKey(conversion.Unit))
            {
                ConversionMessage = WeighStationConversionMessages.Undefined;
                ConvertedQuantities.Clear();
                return;
            }
            AddQuantity(ConvertedQuantities, conversion.Unit, conversion.Quantity.Value);
        }
    }

    private sealed class GroupAccumulator(string key, string label)
    {
        public string Key { get; } = key;
        public string Label { get; } = label;
        public decimal GoodsWeight { get; set; }
        public Dictionary<string, decimal> ConvertedQuantities { get; } =
            new(StringComparer.OrdinalIgnoreCase);
    }

    private sealed record ConversionResult(decimal? Quantity, string Unit, bool IsConfigured)
    {
        public static ConversionResult Configured(decimal quantity, string unit) =>
            new(quantity, unit, true);

        public static ConversionResult Undefined(string unit) => new(null, unit, false);
    }
}
