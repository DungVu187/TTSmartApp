using System.ComponentModel.DataAnnotations;
using System.Data.Common;
using Microsoft.EntityFrameworkCore;
using TTSmart.Api.Common.Exceptions;
using TTSmart.Api.Data.StationOperations;

namespace TTSmart.Api.Features.MixDesignManagement;

public sealed record MixDesignRow(
    int ConcreteGradeId,
    string? ConcreteGradeName,
    int? Strength,
    int? MaxAggregate,
    string? Slump,
    IReadOnlyList<MixDesignMaterialValue> Materials)
{
    public MixDesignRow(
        int concreteGradeId,
        string? concreteGradeName,
        int? strength,
        int? maxAggregate,
        string? slump,
        double? sand1,
        double? sand2,
        double? stone1,
        double? stone2,
        double? stone3,
        double? cement1,
        double? cement2,
        double? cement3,
        double? cement4,
        double? water,
        double? sika,
        double? tulog,
        double? sikaroad,
        double? bifi)
        : this(
            concreteGradeId,
            concreteGradeName,
            strength,
            maxAggregate,
            slump,
            CreateLegacyMaterials(
                sand1,
                sand2,
                stone1,
                stone2,
                stone3,
                cement1,
                cement2,
                cement3,
                cement4,
                water,
                sika,
                tulog,
                sikaroad,
                bifi))
    {
    }

    private static IReadOnlyList<MixDesignMaterialValue> CreateLegacyMaterials(
        params double?[] quantities) =>
        quantities
            .Select((quantity, index) => new MixDesignMaterialValue(index + 1, quantity))
            .ToArray();
}

public sealed record MixDesignMaterialColumn(
    int MaterialSlotId,
    int SlotNumber,
    int? MaterialTypeId,
    string? MaterialTypeName,
    string? MaterialName);

public sealed record MixDesignMaterialValue(
    int MaterialSlotId,
    double? Quantity);

public sealed record MixDesignPage(
    IReadOnlyList<MixDesignRow> Items,
    int PageNumber,
    int PageSize,
    int TotalCount,
    IReadOnlyList<MixDesignMaterialColumn> MaterialColumns)
{
    public MixDesignPage(
        IReadOnlyList<MixDesignRow> items,
        int pageNumber,
        int pageSize,
        int totalCount)
        : this(items, pageNumber, pageSize, totalCount, LegacyMaterialColumns)
    {
    }

    private static IReadOnlyList<MixDesignMaterialColumn> LegacyMaterialColumns { get; } =
    [
        new(1, 1, 1, "C\u00e1t", "C\u00e1t 1"),
        new(2, 2, 1, "C\u00e1t", "C\u00e1t 2"),
        new(3, 3, 2, "\u0110\u00e1", "\u0110\u00e1 1"),
        new(4, 4, 2, "\u0110\u00e1", "\u0110\u00e1 2"),
        new(5, 5, 2, "\u0110\u00e1", "\u0110\u00e1 3"),
        new(6, 6, 3, "Xi m\u0103ng", "Xi m\u0103ng 1"),
        new(7, 7, 3, "Xi m\u0103ng", "Xi m\u0103ng 2"),
        new(8, 8, 3, "Xi m\u0103ng", "Xi m\u0103ng 3"),
        new(9, 9, 3, "Xi m\u0103ng", "Xi m\u0103ng 4"),
        new(10, 10, 4, "N\u01b0\u1edbc", "N\u01b0\u1edbc"),
        new(11, 11, 5, "Ph\u1ee5 gia", "SIKA"),
        new(12, 12, 5, "Ph\u1ee5 gia", "TULOG"),
        new(13, 13, 5, "Ph\u1ee5 gia", "SIKAROAD"),
        new(14, 14, 5, "Ph\u1ee5 gia", "BIFI")
    ];
}

public interface IMixDesignDataSource
{
    Task<MixDesignPage> GetPageAsync(
        StationDatabaseTarget target,
        int pageNumber,
        CancellationToken cancellationToken);
}

public sealed class SqlMixDesignDataSource(
    IStationOperationsDbContextFactory dbContextFactory) : IMixDesignDataSource
{
    private const string StationUnavailableMessage = "Dữ liệu trạm chưa sẵn sàng";
    public Task<MixDesignPage> GetPageAsync(
        StationDatabaseTarget target,
        int pageNumber,
        CancellationToken cancellationToken) =>
        ExecuteAsync(
            target,
            dbContext => LoadPageAsync(dbContext, pageNumber, cancellationToken));

    private static async Task<MixDesignPage> LoadPageAsync(
        StationOperationsDbContext dbContext,
        int pageNumber,
        CancellationToken cancellationToken)
    {
        var pageOffset = CalculatePageOffset(pageNumber);
        var materialColumns = await LoadMaterialColumnsAsync(dbContext, cancellationToken);
        var concreteGrades = dbContext.ConcreteGrades.AsNoTracking();
        var totalCount = await concreteGrades.CountAsync(cancellationToken);
        var pageRows = await concreteGrades
            .OrderBy(item => item.ConcreteGradeId)
            .Skip(pageOffset)
            .Take(MixDesignContractDefaults.PageSize)
            .Select(item => new MixDesignGradeRow(
                item.ConcreteGradeId,
                item.Name,
                item.Strength,
                item.MaximumAggregateSize,
                item.Slump))
            .ToArrayAsync(cancellationToken);

        if (pageRows.Length == 0)
        {
            return new MixDesignPage(
                [],
                pageNumber,
                MixDesignContractDefaults.PageSize,
                totalCount,
                materialColumns);
        }

        var concreteGradeIds = pageRows
            .Select(item => item.ConcreteGradeId)
            .ToArray();
        var materialRows = await (
            from material in dbContext.MixDesignMaterials.AsNoTracking()
            where concreteGradeIds.Contains(material.ConcreteGradeId)
            select new MixDesignMaterialRow(
                material.ConcreteGradeId,
                material.MaterialSlotId,
                material.Quantity))
            .ToArrayAsync(cancellationToken);
        var materialValuesByGrade = GroupMaterials(materialRows, materialColumns);
        var items = pageRows
            .Select(item => CreateRow(item, materialValuesByGrade))
            .ToArray();

        return new MixDesignPage(
            items,
            pageNumber,
            MixDesignContractDefaults.PageSize,
            totalCount,
            materialColumns);
    }

    private static async Task<IReadOnlyList<MixDesignMaterialColumn>> LoadMaterialColumnsAsync(
        StationOperationsDbContext dbContext,
        CancellationToken cancellationToken)
    {
        var rows = await (
            from materialSlot in dbContext.MixDesignMaterialSlots.AsNoTracking()
            join materialType in dbContext.CurrentMaterialTypes.AsNoTracking()
                on materialSlot.MaterialTypeId equals (int?)materialType.MaterialTypeId into typeGroup
            from materialType in typeGroup.DefaultIfEmpty()
            where materialSlot.SlotNumber > 0
            orderby materialSlot.SlotNumber, materialSlot.MaterialSlotId
            select new MixDesignMaterialColumn(
                materialSlot.MaterialSlotId,
                materialSlot.SlotNumber,
                materialSlot.MaterialTypeId,
                materialType == null ? null : materialType.Name,
                materialSlot.Name))
            .ToArrayAsync(cancellationToken);
        var duplicateSlotNumbers = rows
            .GroupBy(row => row.SlotNumber)
            .Where(group => group.Count() > 1)
            .Select(group => group.Key)
            .OrderBy(slotNumber => slotNumber)
            .ToArray();
        if (duplicateSlotNumbers.Length > 0)
        {
            throw new ServiceUnavailableException(StationUnavailableMessage);
        }

        return rows;
    }

    private static IReadOnlyDictionary<int, IReadOnlyList<MixDesignMaterialValue>> GroupMaterials(
        IReadOnlyList<MixDesignMaterialRow> materialRows,
        IReadOnlyList<MixDesignMaterialColumn> materialColumns)
    {
        var configuredMaterialSlotIds = materialColumns
            .Select(column => column.MaterialSlotId)
            .ToHashSet();
        if (materialRows.Any(row => !configuredMaterialSlotIds.Contains(row.MaterialSlotId)))
        {
            throw new ServiceUnavailableException(StationUnavailableMessage);
        }

        return materialRows
            .GroupBy(row => row.ConcreteGradeId)
            .ToDictionary(
                group => group.Key,
                group => (IReadOnlyList<MixDesignMaterialValue>)group
                    .Select(row => new MixDesignMaterialValue(
                        row.MaterialSlotId,
                        ToDouble(row.Quantity)))
                    .ToArray());
    }

    private static MixDesignRow CreateRow(
        MixDesignGradeRow grade,
        IReadOnlyDictionary<int, IReadOnlyList<MixDesignMaterialValue>> materialValuesByGrade)
    {
        materialValuesByGrade.TryGetValue(grade.ConcreteGradeId, out var materials);
        return new MixDesignRow(
            grade.ConcreteGradeId,
            grade.ConcreteGradeName,
            grade.Strength,
            grade.MaxAggregate,
            grade.Slump,
            materials ?? []);
    }

    private static double? ToDouble(float? value) =>
        value.HasValue ? value.Value : null;

    private static int CalculatePageOffset(int pageNumber)
    {
        if (pageNumber < 1)
        {
            throw new ValidationException("Số trang không hợp lệ");
        }

        try
        {
            return checked((pageNumber - 1) * MixDesignContractDefaults.PageSize);
        }
        catch (OverflowException exception)
        {
            throw new ValidationException("Số trang không hợp lệ", exception);
        }
    }

    private async Task<TResult> ExecuteAsync<TResult>(
        StationDatabaseTarget target,
        Func<StationOperationsDbContext, Task<TResult>> operation)
    {
        try
        {
            await using var dbContext = dbContextFactory.Create(target);
            return await operation(dbContext);
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch (StationDatabaseConfigurationException exception)
        {
            throw new ServiceUnavailableException(
                StationUnavailableMessage,
                exception);
        }
        catch (InvalidOperationException exception)
            when (FindDatabaseException(exception) is not null)
        {
            throw new ServiceUnavailableException(
                StationUnavailableMessage,
                exception);
        }
        catch (DbException exception)
        {
            throw new ServiceUnavailableException(
                StationUnavailableMessage,
                exception);
        }
        catch (TimeoutException exception)
        {
            throw new ServiceUnavailableException(
                StationUnavailableMessage,
                exception);
        }
    }

    private static DbException? FindDatabaseException(Exception exception)
    {
        for (var current = exception; current is not null; current = current.InnerException)
        {
            if (current is DbException databaseException)
            {
                return databaseException;
            }
        }

        return null;
    }

    private sealed record MixDesignGradeRow(
        int ConcreteGradeId,
        string? ConcreteGradeName,
        int? Strength,
        int? MaxAggregate,
        string? Slump);

    private sealed record MixDesignMaterialRow(
        int ConcreteGradeId,
        int MaterialSlotId,
        float? Quantity);
}
