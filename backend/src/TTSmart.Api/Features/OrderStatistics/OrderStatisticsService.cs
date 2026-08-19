using System.ComponentModel.DataAnnotations;
using System.Diagnostics;
using System.Security.Cryptography;
using System.Text;
using Microsoft.Extensions.Options;
using TTSmart.Api.Common.Diagnostics;
using TTSmart.Api.Data.StationOperations;
using TTSmart.Api.Features.BranchManagement;

namespace TTSmart.Api.Features.OrderStatistics;

public sealed class OrderStatisticsService(
    IBranchAccessResolver branchAccessResolver,
    IOrderStatisticsDataSource dataSource,
    ILogger<OrderStatisticsService> logger,
    IHttpContextAccessor httpContextAccessor,
    IOptionsMonitor<PerformanceLoggingOptions> performanceLoggingOptions)
    : IOrderStatisticsService
{
    private static readonly TimeSpan VietnamOffset = TimeSpan.FromHours(7);

    public async Task<IReadOnlyList<OrderStatisticsStationResponse>> GetStationsAsync(
        OrderStatisticsStationQuery query,
        int currentUserId,
        CancellationToken cancellationToken)
    {
        var branches = await branchAccessResolver.GetOrderStatisticsBranchesAsync(
            currentUserId,
            query.CompanyId,
            cancellationToken);
        return branches
            .Select(branch => new OrderStatisticsStationResponse(
                branch.Id,
                branch.CompanyId,
                branch.Code,
                branch.Name,
                branch.TypeTram,
                branch.CompanyName))
            .ToArray();
    }

    public async Task<OrderStatisticsFilterOptionsResponse> GetFilterOptionsAsync(
        OrderStatisticsFilterOptionsQuery query,
        int currentUserId,
        CancellationToken cancellationToken)
    {
        var branch = await MeasureStageAsync(
            "ResolveBranch",
            () => branchAccessResolver.GetRequiredOrderStatisticsBranchAsync(
                currentUserId,
                query.CompanyId,
                query.BranchId,
                cancellationToken));
        var filter = CreateFilter(
            query.From,
            query.To,
            vehiclePlate: null,
            customerName: null,
            concreteGradeName: null,
            employeeName: null);
        var options = await dataSource.GetFilterOptionsAsync(
            CreateTarget(branch),
            filter,
            cancellationToken);
        return new OrderStatisticsFilterOptionsResponse(
            options.VehiclePlates,
            options.CustomerNames,
            options.ConcreteGradeNames,
            options.EmployeeNames);
    }

    public async Task<OrderStatisticsResponse> SearchAsync(
        OrderStatisticsQuery query,
        int currentUserId,
        CancellationToken cancellationToken) =>
        await SearchCoreAsync(query, currentUserId, loadAllRows: false, cancellationToken);

    public async Task<OrderStatisticsResponse> SearchAllAsync(
        OrderStatisticsQuery query,
        int currentUserId,
        CancellationToken cancellationToken) =>
        await SearchCoreAsync(query, currentUserId, loadAllRows: true, cancellationToken);

    private async Task<OrderStatisticsResponse> SearchCoreAsync(
        OrderStatisticsQuery query,
        int currentUserId,
        bool loadAllRows,
        CancellationToken cancellationToken)
    {
        var branch = await MeasureStageAsync(
            "ResolveBranch",
            () => branchAccessResolver.GetRequiredOrderStatisticsBranchAsync(
                currentUserId,
                query.CompanyId,
                query.BranchId,
                cancellationToken));
        ValidatePagination(query.PageNumber, query.PageSize);
        var filter = CreateFilter(
            query.From,
            query.To,
            query.VehiclePlate,
            query.CustomerName,
            query.ConcreteGradeName,
            query.EmployeeName);
        var viewMode = ParseViewMode(query.ViewMode);
        var page = await MeasureStageAsync(
            loadAllRows ? "SearchAllStationDatabase" : "SearchStationDatabase",
            () => loadAllRows
                ? dataSource.SearchAllAsync(
                    CreateTarget(branch),
                    filter,
                    viewMode,
                    cancellationToken)
                : dataSource.SearchAsync(
                    CreateTarget(branch),
                    filter,
                    viewMode,
                    query.PageNumber,
                    cancellationToken));

        return MapResponse(branch, page, viewMode);
    }

    private static OrderStatisticsResponse MapResponse(
        AuthorizedBranch branch,
        OrderStatisticsPage page,
        OrderStatisticsViewMode viewMode)
    {
        var pageOffset = CalculatePageOffset(page.PageNumber, page.PageSize);
        var currentMaterialLayout = CreateMaterialLayout(page.MaterialColumns);
        var rowLayouts = page.Items
            .Select(row => row.Materials.Count == 0
                ? currentMaterialLayout
                : BuildRowMaterialLayout(row.Materials, currentMaterialLayout))
            .ToArray();
        var items = page.Items
            .Select((row, index) => MapItem(
                row,
                branch,
                checked(pageOffset + index + 1),
                rowLayouts[index]))
            .ToArray();
        var layouts = rowLayouts
            .Append(currentMaterialLayout)
            .GroupBy(layout => layout.LayoutKey, StringComparer.Ordinal)
            .Select(group => group.First())
            .Where(layout => layout.Columns.Count > 0 || page.Items.Count == 0)
            .Select(layout => new OrderStatisticsMaterialLayoutResponse(
                layout.LayoutKey,
                layout.Columns.Select(column => column.Response).ToArray()))
            .ToArray();
        var totalPages = page.TotalCount == 0
            ? 0
            : checked((int)(((long)page.TotalCount + page.PageSize - 1) / page.PageSize));
        var materialSummaryRows = BuildMaterialSummaryRows(page.Summary.Materials);
        var totalMaterialQuantity = NormalizeNumber(page.Summary.TotalMaterialQuantity, 2);
        var totalConcreteVolume = NormalizeNumber(page.Summary.TotalMixedVolume);

        return new OrderStatisticsResponse(
            items,
            page.TotalCount,
            totalPages,
            page.PageNumber,
            page.PageSize,
            items.Length == 0 ? 0 : pageOffset + 1,
            items.Length == 0 ? 0 : pageOffset + items.Length,
            totalMaterialQuantity,
            totalConcreteVolume,
            layouts,
            materialSummaryRows);
    }

    private static OrderStatisticsItemResponse MapItem(
        OrderStatisticsRow row,
        AuthorizedBranch branch,
        int rowNumber,
        MaterialLayoutMapping materialLayout)
    {
        var valuesByPosition = AggregateMaterialsByCategoryPosition(row.Materials);
        var valuesBySlotNumber = AggregateMaterialsBySlot(row.Materials);
        var layoutSlotNumbers = materialLayout.Columns
            .Select(column => column.Response.SlotNumber)
            .ToHashSet();
        var materials = materialLayout.Columns
            .Select(column =>
            {
                var value = ResolveMaterialValue(
                    column.Response,
                    valuesByPosition,
                    valuesBySlotNumber,
                    layoutSlotNumbers);

                return new OrderStatisticsMaterialResponse(
                    value?.MaterialSlotId ?? column.Response.MaterialSlotId,
                    column.Response.SlotNumber,
                    TrimOrNull(value?.MaterialName) ?? column.Response.MaterialName,
                    TrimOrNull(value?.Category) ?? column.Response.Category,
                    NormalizeMaterialNumber(value?.DesignQuantity, column.Response.CategoryCode),
                    NormalizeMaterialNumber(value?.TQuantity, column.Response.CategoryCode),
                    NormalizeMaterialNumber(value?.ActualQuantity, column.Response.CategoryCode),
                    NormalizeMaterialNumber(value?.Variance, column.Response.CategoryCode))
                {
                    CategoryCode = column.Response.CategoryCode,
                    TypePosition = column.Response.TypePosition,
                    ColumnKey = column.Response.ColumnKey
                };
            })
            .ToArray();

        return new OrderStatisticsItemResponse(
            rowNumber,
            branch.Id,
            branch.Code,
            branch.Name,
            row.MixingDate.HasValue ? DateOnly.FromDateTime(row.MixingDate.Value) : null,
            ToUtc(row.StartedAt),
            ToUtc(row.FinishedAt),
            TrimOrNull(row.CustomerName),
            TrimOrNull(row.ProjectName),
            TrimOrNull(row.WorkItemName),
            TrimOrNull(row.LocationName),
            TrimOrNull(row.VehiclePlate),
            TrimOrNull(row.DriverName),
            TrimOrNull(row.ConcreteGradeName),
            TrimOrNull(row.Slump),
            TrimOrNull(row.SalesEmployeeName),
            TrimOrNull(row.EmployeeName),
            NormalizeNumber(row.RequestedVolume, 2),
            NormalizeNumber(row.MixedVolume),
            materials)
        {
            LayoutKey = materialLayout.LayoutKey
        };
    }

    private static MaterialLayoutMapping CreateMaterialLayout(
        IReadOnlyList<OrderStatisticsMaterialValue> sourceValues) =>
        CreateMaterialLayout(CreateMaterialColumns(sourceValues));

    private static IReadOnlyList<OrderStatisticsMaterialColumn> CreateMaterialColumns(
        IReadOnlyList<OrderStatisticsMaterialValue> sourceValues) =>
        sourceValues
            .Where(value => value.SlotNumber is >= 1)
            .Select(value =>
            {
                var slotNumber = value.SlotNumber!.Value;
                var materialName = TrimOrNull(value.MaterialName) ??
                    $"\u0056\u1eadt li\u1ec7u {slotNumber}";
                return new OrderStatisticsMaterialColumn(
                    value.MaterialSlotId,
                    slotNumber,
                    materialName,
                    value.Category,
                    $"\u0110M.{materialName}",
                    $"T.{materialName}",
                    materialName,
                    $"SS.{materialName}",
                    value.CategoryCode,
                    value.TypePosition);
            })
            // Một số layout lịch sử có nhiều MaterialSlotId cho cùng một cửa.
            // Layout mobile chỉ có một cột cho mỗi cửa, ưu tiên cấu hình mới nhất;
            // các định lượng vẫn được cộng ở AggregateMaterialsBy* phía dưới.
            .GroupBy(column => column.SlotNumber!.Value)
            .Select(group => group
                .OrderByDescending(column => column.MaterialSlotId)
                .ThenByDescending(column => column.TypePosition)
                .First())
            .ToArray();

    private static MaterialLayoutMapping BuildRowMaterialLayout(
        IReadOnlyList<OrderStatisticsMaterialValue> sourceValues,
        MaterialLayoutMapping currentMaterialLayout)
    {
        var rowColumns = CreateMaterialColumns(sourceValues);
        if (rowColumns.Count == 0)
        {
            return currentMaterialLayout;
        }

        var currentColumnsBySlot = currentMaterialLayout.Columns
            .Select(column => column.Response)
            .ToDictionary(column => column.SlotNumber);
        var isCompatibleWithCurrentLayout = rowColumns.All(column =>
            currentColumnsBySlot.TryGetValue(column.SlotNumber!.Value, out var currentColumn) &&
            currentColumn.CategoryCode == OrderStatisticsMaterialCategories.Normalize(
                column.CategoryCode,
                column.Category,
                column.MaterialName));
        if (!isCompatibleWithCurrentLayout)
        {
            return CreateMaterialLayout(rowColumns);
        }

        var rowColumnsBySlot = rowColumns.ToDictionary(column => column.SlotNumber!.Value);
        var mergedColumns = currentMaterialLayout.Columns
            .Select(column => rowColumnsBySlot.TryGetValue(column.Response.SlotNumber, out var rowColumn)
                ? rowColumn
                : new OrderStatisticsMaterialColumn(
                    column.Response.MaterialSlotId ?? 0,
                    column.Response.SlotNumber,
                    column.Response.MaterialName,
                    column.Response.Category,
                    column.Response.DesignLabel,
                    column.Response.TLabel,
                    column.Response.ActualLabel,
                    column.Response.VarianceLabel,
                    column.Response.CategoryCode,
                    column.Response.TypePosition))
            .ToArray();
        return CreateMaterialLayout(mergedColumns);
    }

    private static MaterialLayoutMapping CreateMaterialLayout(
        IReadOnlyList<OrderStatisticsMaterialColumn> sourceColumns)
    {
        var validColumns = sourceColumns
            .Where(column => column.SlotNumber is >= 1)
            .ToArray();
        var duplicateSlotNumbers = validColumns
            .GroupBy(column => column.SlotNumber!.Value)
            .Where(group => group.Count() > 1)
            .Select(group => group.Key)
            .OrderBy(slotNumber => slotNumber)
            .ToArray();
        if (duplicateSlotNumbers.Length > 0)
        {
            throw new InvalidOperationException(
                $"Duplicate material slotNumber: {string.Join(", ", duplicateSlotNumbers)}.");
        }

        var definitions = validColumns
            .Select(column =>
            {
                var slotNumber = column.SlotNumber!.Value;
                var materialName = TrimOrNull(column.MaterialName) ??
                    $"\u0056\u1eadt li\u1ec7u {slotNumber}";
                var category = TrimOrNull(column.Category);
                return new MaterialColumnDefinition(
                    column.MaterialSlotId,
                    slotNumber,
                    materialName,
                    category,
                    OrderStatisticsMaterialCategories.Normalize(
                        column.CategoryCode,
                        category,
                        materialName),
                    TrimOrNull(column.DesignLabel) ?? $"\u0110M.{materialName}",
                    TrimOrNull(column.TLabel) ?? $"T.{materialName}",
                    TrimOrNull(column.ActualLabel) ?? materialName,
                    TrimOrNull(column.VarianceLabel) ?? $"SS.{materialName}")
                {
                    TypePosition = column.TypePosition
                };
            })
            .OrderBy(column => OrderStatisticsMaterialCategories.SortOrder(column.CategoryCode))
            .ThenBy(column => column.SlotNumber)
            .ThenBy(column => column.MaterialSlotId)
            .ToArray();

        var positionedDefinitions = definitions
            .GroupBy(column => column.CategoryCode, StringComparer.Ordinal)
            .SelectMany(AssignTypePositions)
            .OrderBy(column => OrderStatisticsMaterialCategories.SortOrder(column.CategoryCode))
            .ThenBy(column => column.TypePosition)
            .ThenBy(column => column.SlotNumber)
            .ToArray();
        var layoutKey = CreateLayoutKey(positionedDefinitions);
        var columns = positionedDefinitions
            .Select(column => CreateMaterialColumn(column, layoutKey))
            .ToArray();

        return new MaterialLayoutMapping(layoutKey, columns);
    }

    private static IEnumerable<MaterialColumnDefinition> AssignTypePositions(
        IGrouping<string, MaterialColumnDefinition> categoryColumns)
    {
        var orderedColumns = categoryColumns
            .OrderBy(column => column.TypePosition > 0 ? column.TypePosition : int.MaxValue)
            .ThenBy(column => column.SlotNumber)
            .ToArray();
        var canKeepSourcePositions = orderedColumns.All(column => column.TypePosition > 0) &&
            orderedColumns.Select(column => column.TypePosition).Distinct().Count() == orderedColumns.Length;

        return orderedColumns.Select((column, index) =>
            column with
            {
                TypePosition = canKeepSourcePositions
                    ? column.TypePosition
                    : index + 1
            });
    }

    private static MaterialColumnMapping CreateMaterialColumn(
        MaterialColumnDefinition column,
        string layoutKey)
    {
        var columnKey = $"{layoutKey}:slot-{column.SlotNumber}";
        return new MaterialColumnMapping(
            new OrderStatisticsMaterialColumnResponse(
                column.MaterialSlotId,
                column.SlotNumber,
                column.MaterialName,
                column.Category,
                column.DesignLabel,
                column.TLabel,
                column.ActualLabel,
                column.VarianceLabel,
                OrderStatisticsMaterialCategories.Unit(column.CategoryCode))
            {
                CategoryCode = column.CategoryCode,
                TypePosition = column.TypePosition,
                ColumnKey = columnKey
            });
    }

    private static AggregatedMaterialValue? ResolveMaterialValue(
        OrderStatisticsMaterialColumnResponse column,
        IReadOnlyDictionary<(string CategoryCode, int TypePosition), AggregatedMaterialValue> valuesByPosition,
        IReadOnlyDictionary<(int SlotNumber, string CategoryCode), AggregatedMaterialValue> valuesBySlotNumber,
        IReadOnlySet<int> layoutSlotNumbers)
    {
        if (valuesBySlotNumber.TryGetValue(
            (column.SlotNumber, column.CategoryCode),
            out var slotValue))
        {
            return slotValue;
        }

        if (valuesByPosition.TryGetValue(
                (column.CategoryCode, column.TypePosition),
                out var positionValue) &&
            (!positionValue.SlotNumber.HasValue ||
             !layoutSlotNumbers.Contains(positionValue.SlotNumber.Value)))
        {
            return positionValue;
        }

        return null;
    }

    private static IReadOnlyList<OrderStatisticsMaterialSummaryRowResponse> BuildMaterialSummaryRows(
        IReadOnlyList<OrderStatisticsMaterialValue> sourceRows)
    {
        var valuesByPosition = AggregateMaterialsByCategoryPosition(sourceRows);
        var summaryRowCount = valuesByPosition.Keys
            .Select(key => key.TypePosition)
            .DefaultIfEmpty(0)
            .Max();
        var categoryCodes = OrderStatisticsMaterialCategories.StandardCodes
            .Concat(valuesByPosition.Keys
                .Select(key => key.CategoryCode)
                .Where(categoryCode =>
                    !OrderStatisticsMaterialCategories.StandardCodes.Contains(categoryCode)))
            .Distinct(StringComparer.Ordinal)
            .ToArray();

        return Enumerable.Range(1, summaryRowCount)
            .Select(rowNumber => new OrderStatisticsMaterialSummaryRowResponse(
                rowNumber,
                categoryCodes
                    .Select(categoryCode => CreateSummaryCell(
                        categoryCode,
                        rowNumber,
                        valuesByPosition))
                    .ToArray()))
            .ToArray();
    }

    private static OrderStatisticsMaterialSummaryCellResponse CreateSummaryCell(
        string categoryCode,
        int typePosition,
        IReadOnlyDictionary<(string CategoryCode, int TypePosition), AggregatedMaterialValue> valuesByPosition)
    {
        if (!valuesByPosition.TryGetValue((categoryCode, typePosition), out var value))
        {
            return new OrderStatisticsMaterialSummaryCellResponse(
                categoryCode,
                typePosition,
                null,
                null,
                null,
                OrderStatisticsMaterialCategories.DisplayName(categoryCode),
                null,
                0m,
                OrderStatisticsMaterialCategories.Unit(categoryCode));
        }

        return new OrderStatisticsMaterialSummaryCellResponse(
            categoryCode,
            typePosition,
            value.MaterialSlotId > 0 ? value.MaterialSlotId : null,
            value.SlotNumber,
            TrimOrNull(value.MaterialName),
            TrimOrNull(value.Category) ?? OrderStatisticsMaterialCategories.DisplayName(categoryCode),
            $"summary:{categoryCode.ToLowerInvariant()}:{typePosition}",
            NormalizeNumber(value.ActualQuantity, 2),
            OrderStatisticsMaterialCategories.Unit(categoryCode));
    }

    private static IReadOnlyDictionary<(string CategoryCode, int TypePosition), AggregatedMaterialValue>
        AggregateMaterialsByCategoryPosition(IEnumerable<OrderStatisticsMaterialValue> sourceRows)
    {
        var rows = sourceRows
            .Select(material => new
            {
                Material = material,
                CategoryCode = OrderStatisticsMaterialCategories.Normalize(
                    material.CategoryCode,
                    material.Category,
                    material.MaterialName)
            })
            .ToArray();
        var fallbackPositions = rows
            .Where(row => row.Material.TypePosition <= 0)
            .GroupBy(row => row.CategoryCode, StringComparer.Ordinal)
            .SelectMany(group => group
                .Select(row => row.Material.SlotNumber)
                .Where(slotNumber => slotNumber is >= 1)
                .Distinct()
                .OrderBy(slotNumber => slotNumber)
                .Select((slotNumber, index) => new
                {
                    CategoryCode = group.Key,
                    SlotNumber = slotNumber!.Value,
                    TypePosition = index + 1
                }))
            .ToDictionary(
                item => (item.CategoryCode, item.SlotNumber),
                item => item.TypePosition);

        return rows
            .Select(row => new
            {
                row.Material,
                row.CategoryCode,
                TypePosition = row.Material.TypePosition > 0
                    ? row.Material.TypePosition
                    : row.Material.SlotNumber is >= 1 &&
                      fallbackPositions.TryGetValue(
                          (row.CategoryCode, row.Material.SlotNumber.Value),
                          out var fallbackPosition)
                        ? fallbackPosition
                        : 1
            })
            .GroupBy(row => (row.CategoryCode, row.TypePosition))
            .ToDictionary(
                group => group.Key,
                group =>
                {
                    var representative = group
                        .OrderByDescending(row => row.Material.MaterialSlotId)
                        .First();
                    var designQuantity = group.Sum(row => row.Material.DesignQuantity);
                    var tQuantity = group.Sum(row => row.Material.TQuantity);
                    var actualQuantity = group.Sum(row => row.Material.ActualQuantity);
                    return new AggregatedMaterialValue(
                        representative.Material.MaterialSlotId,
                        representative.Material.SlotNumber,
                        representative.Material.MaterialName,
                        representative.Material.Category,
                        group.Key.CategoryCode,
                        designQuantity,
                        tQuantity,
                        actualQuantity,
                        actualQuantity - designQuantity);
                });
    }

    private static IReadOnlyDictionary<(int SlotNumber, string CategoryCode), AggregatedMaterialValue>
        AggregateMaterialsBySlot(IEnumerable<OrderStatisticsMaterialValue> sourceRows) =>
        sourceRows
            .Where(material => material.SlotNumber is >= 1)
            .Select(material => new
            {
                Material = material,
                CategoryCode = OrderStatisticsMaterialCategories.Normalize(
                    material.CategoryCode,
                    material.Category,
                    material.MaterialName)
            })
            .GroupBy(row => (row.Material.SlotNumber!.Value, row.CategoryCode))
            .ToDictionary(
                group => group.Key,
                group =>
                {
                    var representative = group
                        .OrderByDescending(row => row.Material.MaterialSlotId)
                        .First();
                    var designQuantity = group.Sum(row => row.Material.DesignQuantity);
                    var tQuantity = group.Sum(row => row.Material.TQuantity);
                    var actualQuantity = group.Sum(row => row.Material.ActualQuantity);
                    return new AggregatedMaterialValue(
                        representative.Material.MaterialSlotId,
                        representative.Material.SlotNumber,
                        representative.Material.MaterialName,
                        representative.Material.Category,
                        group.Key.CategoryCode,
                        designQuantity,
                        tQuantity,
                        actualQuantity,
                        actualQuantity - designQuantity);
                });

    private static OrderStatisticsFilter CreateFilter(
        DateTimeOffset? from,
        DateTimeOffset? to,
        string? vehiclePlate,
        string? customerName,
        string? concreteGradeName,
        string? employeeName)
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

        return new OrderStatisticsFilter(
            fromLocal,
            toInclusive,
            TrimOrNull(vehiclePlate),
            TrimOrNull(customerName),
            TrimOrNull(concreteGradeName),
            TrimOrNull(employeeName),
            UseFinishedAtInclusive: true);
    }

    private static OrderStatisticsViewMode ParseViewMode(string? value) =>
        TrimOrNull(value)?.ToLowerInvariant() switch
        {
            null or OrderStatisticsViewModes.Detail => OrderStatisticsViewMode.Detail,
            OrderStatisticsViewModes.Total => OrderStatisticsViewMode.Total,
            _ => throw new ValidationException("ViewMode chỉ nhận giá trị detail hoặc total.")
        };

    private static void ValidatePagination(int pageNumber, int pageSize)
    {
        if (pageNumber < 1)
        {
            throw new ValidationException("PageNumber phải lớn hơn hoặc bằng 1.");
        }

        if (pageSize != OrderStatisticsContractDefaults.PageSize)
        {
            throw new ValidationException("PageSize của Thống kê đơn hàng phải bằng 10.");
        }

        _ = CalculatePageOffset(pageNumber, pageSize);
    }

    private static int CalculatePageOffset(int pageNumber, int pageSize)
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

    private static decimal NormalizeNumber(double? value, int digits = 3)
    {
        if (!value.HasValue || !double.IsFinite(value.Value))
        {
            return 0m;
        }

        try
        {
            return Math.Round((decimal)value.Value, digits, MidpointRounding.AwayFromZero);
        }
        catch (OverflowException)
        {
            return 0m;
        }
    }

    private static decimal NormalizeMaterialNumber(double? value, string categoryCode) =>
        NormalizeNumber(value, categoryCode switch
        {
            OrderStatisticsMaterialCategories.Sand or
            OrderStatisticsMaterialCategories.Stone => 0,
            OrderStatisticsMaterialCategories.Cement or
            OrderStatisticsMaterialCategories.Water => 1,
            _ => 2
        });

    private static string CreateLayoutKey(
        IReadOnlyList<MaterialColumnDefinition> columns)
    {
        var canonicalLayout = string.Join(
            "\n",
            columns.Select(column => string.Join(
                "|",
                column.SlotNumber,
                column.CategoryCode,
                column.MaterialName.Normalize(NormalizationForm.FormC))));
        var hash = SHA256.HashData(Encoding.UTF8.GetBytes(canonicalLayout));
        return $"layout-{Convert.ToHexString(hash).ToLowerInvariant()}";
    }

    private static string? TrimOrNull(string? value)
    {
        var trimmed = value?.Trim();
        return string.IsNullOrEmpty(trimmed) ? null : trimmed;
    }

    private async Task<T> MeasureStageAsync<T>(string stage, Func<Task<T>> operation)
    {
        var stopwatch = Stopwatch.StartNew();
        try
        {
            var result = await operation();
            stopwatch.Stop();
            if (performanceLoggingOptions.CurrentValue.LogOrderStatisticsStages)
            {
                logger.LogInformation(
                    "Order statistics service stage completed. TraceId={TraceId}, Stage={Stage}, ElapsedMs={ElapsedMs}",
                    httpContextAccessor.HttpContext?.TraceIdentifier ?? "background",
                    stage,
                    stopwatch.ElapsedMilliseconds);
            }
            return result;
        }
        catch (OperationCanceledException)
        {
            stopwatch.Stop();
            logger.LogWarning(
                "Order statistics service stage canceled. TraceId={TraceId}, Stage={Stage}, ElapsedMs={ElapsedMs}",
                httpContextAccessor.HttpContext?.TraceIdentifier ?? "background",
                stage,
                stopwatch.ElapsedMilliseconds);
            throw;
        }
        catch (Exception exception)
        {
            stopwatch.Stop();
            logger.LogError(
                "Order statistics service stage failed. TraceId={TraceId}, Stage={Stage}, ElapsedMs={ElapsedMs}, ErrorType={ErrorType}",
                httpContextAccessor.HttpContext?.TraceIdentifier ?? "background",
                stage,
                stopwatch.ElapsedMilliseconds,
                exception.GetType().Name);
            throw;
        }
    }

    private sealed record MaterialColumnDefinition(
        long MaterialSlotId,
        int SlotNumber,
        string MaterialName,
        string? Category,
        string CategoryCode,
        string DesignLabel,
        string TLabel,
        string ActualLabel,
        string VarianceLabel)
    {
        public int TypePosition { get; init; }
    }

    private sealed record MaterialColumnMapping(OrderStatisticsMaterialColumnResponse Response);

    private sealed record MaterialLayoutMapping(
        string LayoutKey,
        IReadOnlyList<MaterialColumnMapping> Columns);

    private sealed record AggregatedMaterialValue(
        long MaterialSlotId,
        int? SlotNumber,
        string? MaterialName,
        string? Category,
        string CategoryCode,
        double DesignQuantity,
        double TQuantity,
        double ActualQuantity,
        double Variance);
}
