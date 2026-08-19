using System.ComponentModel.DataAnnotations;
using TTSmart.Api.Data.StationOperations;
using TTSmart.Api.Features.BranchManagement;

namespace TTSmart.Api.Features.MaterialReporting;

public sealed class MaterialReportService(
    IBranchAccessResolver branchAccessResolver,
    IMaterialReportDataSource dataSource) : IMaterialReportService
{
    private static readonly TimeSpan VietnamOffset = TimeSpan.FromHours(7);

    public async Task<IReadOnlyList<MaterialReportStationResponse>> GetStationsAsync(
        MaterialReportStationQuery query,
        int currentUserId,
        CancellationToken cancellationToken)
    {
        var branches = await branchAccessResolver.GetMaterialReportBranchesAsync(
            currentUserId,
            query.CompanyId,
            cancellationToken);
        return branches.Select(branch => new MaterialReportStationResponse(
            branch.Id,
            branch.CompanyId,
            branch.Name,
            branch.CompanyName,
            branch.TypeTram)).ToArray();
    }

    public async Task<MaterialReportResponse> GetAsync(
        MaterialReportQuery query,
        int currentUserId,
        CancellationToken cancellationToken)
    {
        var (fromLocal, toLocal) = ValidateAndNormalize(query);
        var branch = await branchAccessResolver.GetRequiredMaterialReportBranchAsync(
            currentUserId,
            query.CompanyId,
            query.BranchId,
            cancellationToken);
        var snapshot = await dataSource.LoadAsync(
            new StationDatabaseTarget(branch.Id, branch.DatabaseName, branch.TypeTram),
            fromLocal,
            toLocal,
            cancellationToken);
        var calculation = MaterialFifoCalculator.Calculate(snapshot, fromLocal, toLocal);
        var materialByCode = calculation.Materials.ToDictionary(item => item.Material.Code);
        var materialByName = calculation.Materials
            .Where(item => !string.IsNullOrWhiteSpace(item.Material.Name))
            .GroupBy(item => MaterialFifoCalculator.NormalizeText(item.Material.Name), StringComparer.Ordinal)
            .ToDictionary(group => group.Key, group => group.First(), StringComparer.Ordinal);

        MaterialCalculatedValue? Resolve(int? code, string? name)
        {
            if (code.HasValue && materialByCode.TryGetValue(code.Value, out var exact))
            {
                return exact;
            }
            return materialByName.GetValueOrDefault(MaterialFifoCalculator.NormalizeText(name));
        }

        bool Included(MaterialCalculatedValue? item) =>
            item is not null &&
            (query.MaterialGroup == MaterialReportGroups.All ||
             MaterialFifoCalculator.GroupCode(item.Material.MaterialTypeId, item.Material.Name) == query.MaterialGroup);

        var selectedMaterials = calculation.Materials.Where(Included).ToArray();
        var groups = BuildGroups(selectedMaterials, query.MaterialGroup);
        var charts = selectedMaterials.Select(ToChart).ToArray();
        var realTransactions = snapshot.Transactions
            .Where(item => item.OccurredAt >= fromLocal && item.OccurredAt <= toLocal)
            .Where(item => MatchesViewMode(item.Type, query.ViewMode))
            .Select(item => MapTransaction(item, calculation, Resolve, query.MaterialGroup))
            .Where(item => item is not null)
            .Cast<MaterialTransactionResponse>()
            .OrderByDescending(item => item.OccurredAt)
            .ThenByDescending(item => item.Id, StringComparer.Ordinal)
            .ToArray();

        var offset = CalculateOffset(query.PageNumber, query.PageSize);
        var pageRows = realTransactions.Skip(offset).Take(query.PageSize).ToList();
        var includeSummaryExport = query.MaterialGroup == MaterialReportGroups.All &&
                                   query.ViewMode == MaterialReportViewModes.All;
        var totalCount = realTransactions.Length + (includeSummaryExport ? 1 : 0);
        for (var index = 0; index < pageRows.Count; index++)
        {
            pageRows[index] = pageRows[index] with { RowNumber = offset + index + 1 };
        }
        if (includeSummaryExport)
        {
            pageRows.Add(BuildSummaryExport(
                snapshot,
                calculation,
                fromLocal,
                toLocal,
                Resolve,
                totalCount));
        }

        var totals = new MaterialReportTotalsResponse(
            selectedMaterials.Sum(item => item.ImportQuantityKg),
            selectedMaterials.Sum(item => item.ExportQuantityKg),
            selectedMaterials.Sum(item => item.InventoryQuantityKg),
            selectedMaterials.Sum(item => item.ImportValueVnd),
            selectedMaterials.Sum(item => item.ExportValueVnd),
            selectedMaterials.Sum(item => item.InventoryValueVnd));
        var warnings = snapshot.Warnings
            .Concat(selectedMaterials.Any(item => item.HasMissingImportPrice)
                ? ["Một số lô nhập chưa có đơn giá nên phần giá trị tương ứng được tính bằng 0."]
                : Array.Empty<string>())
            .Distinct(StringComparer.Ordinal)
            .ToArray();
        var totalPages = totalCount == 0
            ? 0
            : (int)Math.Ceiling(totalCount / (decimal)query.PageSize);
        var realPageCount = Math.Min(Math.Max(realTransactions.Length - offset, 0), query.PageSize);
        var fromRow = realPageCount > 0
            ? offset + 1
            : includeSummaryExport ? totalCount : 0;
        var toRow = realPageCount > 0
            ? offset + realPageCount
            : includeSummaryExport ? totalCount : 0;

        return new MaterialReportResponse(
            branch.Id,
            branch.Name,
            ToUtc(fromLocal),
            ToUtc(toLocal),
            ToUtc(toLocal),
            query.MaterialGroup,
            query.ViewMode,
            query.ValueMode,
            groups,
            charts,
            pageRows,
            totalCount,
            totalPages,
            query.PageNumber,
            query.PageSize,
            fromRow,
            toRow,
            totals,
            warnings);
    }

    private static (DateTime FromLocal, DateTime ToLocal) ValidateAndNormalize(MaterialReportQuery query)
    {
        if (!query.From.HasValue || !query.To.HasValue)
        {
            throw new ValidationException("Khoảng thời gian là bắt buộc.");
        }
        if (query.PageNumber < 1 || query.PageSize != MaterialReportContractDefaults.PageSize)
        {
            throw new ValidationException("PageNumber phải từ 1 và PageSize phải bằng 10.");
        }

        var fromLocal = ToVietnamLocal(query.From.Value);
        var toLocal = ToVietnamLocal(query.To.Value);
        if (fromLocal > toLocal)
        {
            throw new ValidationException("Thời gian bắt đầu không được lớn hơn thời gian kết thúc.");
        }
        _ = CalculateOffset(query.PageNumber, query.PageSize);
        return (fromLocal, toLocal);
    }

    private static int CalculateOffset(int pageNumber, int pageSize)
    {
        try
        {
            return checked((pageNumber - 1) * pageSize);
        }
        catch (OverflowException exception)
        {
            throw new ValidationException("Số trang vượt quá giới hạn cho phép.", exception);
        }
    }

    private static bool MatchesViewMode(string type, string viewMode) => viewMode switch
    {
        MaterialReportViewModes.Import => type == MaterialReportViewModes.Import,
        MaterialReportViewModes.Export => type == MaterialReportViewModes.Export,
        MaterialReportViewModes.Stocktake => type == MaterialReportViewModes.Stocktake,
        _ => true
    };

    private static MaterialTransactionResponse? MapTransaction(
        MaterialTransactionData source,
        MaterialFifoCalculation calculation,
        Func<int?, string?, MaterialCalculatedValue?> resolve,
        string materialGroup)
    {
        var selectedDetails = source.Details.Select(detail => new
        {
            Detail = detail,
            Material = resolve(detail.MaterialCode, detail.MaterialName)
        })
            .Where(item => materialGroup == MaterialReportGroups.All ||
                item.Material is not null &&
                MaterialFifoCalculator.GroupCode(
                    item.Material.Material.MaterialTypeId,
                    item.Material.Material.Name) == materialGroup)
            .ToArray();
        var details = selectedDetails.Select(item =>
        {
            var detail = item.Detail;
            var material = item.Material;
            var value = source.Type == MaterialReportViewModes.Import
                ? MaterialFifoCalculator.RoundVnd(detail.QuantityKg * detail.UnitPriceVndPerKg)
                : detail.IssueSourceId is null
                    ? (decimal?)null
                    : calculation.IssueValueBySourceId.GetValueOrDefault(detail.IssueSourceId);
            return new MaterialTransactionDetailResponse(
                material?.Material.Code ?? detail.MaterialCode ?? 0,
                material?.Material.Name ?? detail.MaterialName ?? "Không xác định",
                MaterialFifoCalculator.RoundKg(detail.QuantityKg),
                value,
                detail.UnitPriceVndPerKg,
                detail.ConversionVolume,
                detail.ConversionUnit,
                detail.ConversionCoefficientKgPerUnit);
        })
            .ToArray();
        if (details.Length == 0)
        {
            return null;
        }

        var importQuantity = source.Type == MaterialReportViewModes.Import
            ? details.Sum(item => item.QuantityKg)
            : 0m;
        var exportQuantity = source.Type is MaterialReportViewModes.Export or MaterialReportViewModes.Stocktake
            ? details.Sum(item => item.QuantityKg)
            : 0m;
        var value = source.Type == MaterialReportViewModes.Import
            ? details.Sum(item => item.ValueVnd ?? 0m)
            : selectedDetails.Any(item => item.Detail.IssueSourceId is not null)
                ? details.Sum(item => item.ValueVnd ?? 0m)
                : calculation.IssueValueByTransactionId.GetValueOrDefault(source.Id);
        return new MaterialTransactionResponse(
            0,
            source.Id,
            ToUtc(source.OccurredAt),
            null,
            null,
            source.Type,
            source.Name ?? TypeName(source.Type),
            importQuantity,
            exportQuantity,
            value,
            null,
            details);
    }

    private static MaterialTransactionResponse BuildSummaryExport(
        MaterialReportSnapshot snapshot,
        MaterialFifoCalculation calculation,
        DateTime fromLocal,
        DateTime toLocal,
        Func<int?, string?, MaterialCalculatedValue?> resolve,
        int rowNumber)
    {
        var details = snapshot.Issues
            .Where(item =>
                item.OccurredAt >= fromLocal &&
                item.OccurredAt <= toLocal &&
                (item.QuantityKg > 0 ||
                 item.IsQuantityOnlyAdjustment && item.QuantityKg < 0))
            .Select(item => new { Issue = item, Material = resolve(item.MaterialCode, item.MaterialName) })
            .Where(item => item.Material is not null)
            .GroupBy(item => item.Material!.Material.Code)
            .Select(group => new MaterialTransactionDetailResponse(
                group.Key,
                group.First().Material!.Material.Name,
                MaterialFifoCalculator.RoundKg(group.Sum(item => item.Issue.QuantityKg)),
                MaterialFifoCalculator.RoundVnd(group.Sum(item =>
                    calculation.IssueValueBySourceId.GetValueOrDefault(item.Issue.SourceId))),
                null,
                null,
                null,
                null))
            .OrderBy(item => item.MaterialCode)
            .ToArray();
        return new MaterialTransactionResponse(
            rowNumber,
            "summary-export",
            null,
            ToUtc(fromLocal),
            ToUtc(toLocal),
            "summary-export",
            "Xuất tổng trong kỳ",
            0m,
            details.Sum(item => item.QuantityKg),
            details.Sum(item => item.ValueVnd ?? 0m),
            null,
            details);
    }

    private static IReadOnlyList<MaterialGroupSummaryResponse> BuildGroups(
        IReadOnlyList<MaterialCalculatedValue> materials,
        string selectedGroup)
    {
        var definitions = new[]
        {
            (MaterialReportGroups.Sand, "Nhóm Cát"),
            (MaterialReportGroups.Stone, "Nhóm Đá"),
            (MaterialReportGroups.Cement, "Nhóm Xi"),
            (MaterialReportGroups.Water, "Nhóm Nước"),
            (MaterialReportGroups.Additive, "Nhóm Phụ gia")
        };
        return definitions
            .Where(group => selectedGroup == MaterialReportGroups.All || selectedGroup == group.Item1)
            .Select(group => new MaterialGroupSummaryResponse(
                group.Item1,
                group.Item2,
                materials
                    .Where(item => MaterialFifoCalculator.GroupCode(
                        item.Material.MaterialTypeId,
                        item.Material.Name) == group.Item1)
                    .Select(ToSummary)
                    .ToArray()))
            .ToArray();
    }

    private static MaterialSummaryItemResponse ToSummary(MaterialCalculatedValue item) => new(
        item.Material.Code,
        item.Material.SlotNumber,
        item.Material.MaterialTypeId,
        item.Material.Name,
        MaterialFifoCalculator.GroupCode(item.Material.MaterialTypeId, item.Material.Name),
        item.ImportQuantityKg,
        item.ExportQuantityKg,
        item.InventoryQuantityKg,
        item.ImportValueVnd,
        item.ExportValueVnd,
        item.InventoryValueVnd,
        item.KilogramsPerCubicMeter,
        item.KilogramsPerLiter,
        item.HasMissingImportPrice);

    private static MaterialChartItemResponse ToChart(MaterialCalculatedValue item) => new(
        item.Material.Code,
        item.Material.Name,
        MaterialFifoCalculator.GroupCode(item.Material.MaterialTypeId, item.Material.Name),
        item.ImportQuantityKg,
        item.ExportQuantityKg,
        item.InventoryQuantityKg,
        item.ImportValueVnd,
        item.ExportValueVnd,
        item.InventoryValueVnd);

    private static string TypeName(string type) => type switch
    {
        MaterialReportViewModes.Export => "Xuất kho",
        MaterialReportViewModes.Stocktake => "Kiểm kê",
        _ => "Nhập kho"
    };

    private static DateTime ToVietnamLocal(DateTimeOffset value) =>
        DateTime.SpecifyKind(value.ToOffset(VietnamOffset).DateTime, DateTimeKind.Unspecified);

    private static DateTimeOffset ToUtc(DateTime local) =>
        new DateTimeOffset(DateTime.SpecifyKind(local, DateTimeKind.Unspecified), VietnamOffset)
            .ToUniversalTime();
}
