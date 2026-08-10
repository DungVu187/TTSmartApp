using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata;
using TTSmart.Api.Data.StationOperations;

namespace TTSmart.Api.Tests;

public sealed class MixDesignMappingTests
{
    [Fact]
    public void ConcreteGrade_GiuDungBangCotKhoaVaDuCotQlcp()
    {
        using var dbContext = CreateDbContext();
        var entity = dbContext.Model.FindEntityType(typeof(StationConcreteGrade))!;
        var table = AssertTable(entity, "MACBETONG");

        AssertKey(entity, nameof(StationConcreteGrade.ConcreteGradeId));
        AssertColumn(entity, table, nameof(StationConcreteGrade.ConcreteGradeId), "MAMACBETONG", false);
        AssertColumn(entity, table, nameof(StationConcreteGrade.Name), "TENMACBETONG", true, "nvarchar(max)");
        AssertColumn(entity, table, nameof(StationConcreteGrade.Strength), "CUONGDO", true);
        AssertColumn(entity, table, nameof(StationConcreteGrade.MaximumAggregateSize), "COTLIEUMAX", true);
        AssertColumn(entity, table, nameof(StationConcreteGrade.Slump), "DOSUT", true, "nvarchar(max)");
    }

    [Fact]
    public void MixDesignMaterial_GiuDungBangCotKhoaGhepVaKieuReal()
    {
        using var dbContext = CreateDbContext();
        var entity = dbContext.Model.FindEntityType(typeof(StationMixDesignMaterial))!;
        var table = AssertTable(entity, "SOLUONGVL");

        AssertKey(
            entity,
            nameof(StationMixDesignMaterial.ConcreteGradeId),
            nameof(StationMixDesignMaterial.MaterialSlotId));
        AssertColumn(entity, table, nameof(StationMixDesignMaterial.ConcreteGradeId), "MAMACBETONG", false);
        AssertColumn(entity, table, nameof(StationMixDesignMaterial.MaterialSlotId), "MACUAVL", false);
        AssertColumn(entity, table, nameof(StationMixDesignMaterial.Quantity), "SOLUONG", true, "real");
    }

    [Fact]
    public void MixDesignMaterialSlot_GiuDungBangCotVaKhoa()
    {
        using var dbContext = CreateDbContext();
        var entity = dbContext.Model.FindEntityType(typeof(StationMixDesignMaterialSlot))!;
        var table = AssertTable(entity, "CUAVL");

        AssertKey(entity, nameof(StationMixDesignMaterialSlot.MaterialSlotId));
        AssertColumn(entity, table, nameof(StationMixDesignMaterialSlot.MaterialSlotId), "MACUAVL", false);
        AssertColumn(entity, table, nameof(StationMixDesignMaterialSlot.SlotNumber), "STTCUAVL", false);
        AssertColumn(entity, table, nameof(StationMixDesignMaterialSlot.MaterialTypeId), "MALOAIVL", true);
        AssertColumn(entity, table, nameof(StationMixDesignMaterialSlot.Name), "TENCUAVL", true, "nvarchar(max)");
    }

    [Fact]
    public void CurrentMaterialType_GiuDungBangCotVaKhoa()
    {
        using var dbContext = CreateDbContext();
        var entity = dbContext.Model.FindEntityType(typeof(StationCurrentMaterialType))!;
        var table = AssertTable(entity, "LOAIVL");

        AssertKey(entity, nameof(StationCurrentMaterialType.MaterialTypeId));
        AssertColumn(entity, table, nameof(StationCurrentMaterialType.MaterialTypeId), "MALOAIVL", false);
        AssertColumn(entity, table, nameof(StationCurrentMaterialType.Name), "TENLOAIVL", true, "nvarchar(max)");
    }

    private static StationOperationsDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<StationOperationsDbContext>()
            .UseSqlServer("Server=(local);Database=unused;Trusted_Connection=True;")
            .Options;

        return new StationOperationsDbContext(options);
    }

    private static StoreObjectIdentifier AssertTable(IEntityType entity, string tableName)
    {
        Assert.Equal(tableName, entity.GetTableName());
        Assert.Equal("dbo", entity.GetSchema());
        return StoreObjectIdentifier.Table(tableName, "dbo");
    }

    private static void AssertKey(IEntityType entity, params string[] propertyNames)
    {
        var primaryKey = entity.FindPrimaryKey()!;
        Assert.Equal(propertyNames, primaryKey.Properties.Select(property => property.Name));
    }

    private static void AssertColumn(
        IEntityType entity,
        StoreObjectIdentifier table,
        string propertyName,
        string columnName,
        bool isNullable,
        string? columnType = null)
    {
        var property = entity.FindProperty(propertyName)!;

        Assert.Equal(columnName, property.GetColumnName(table));
        Assert.Equal(isNullable, property.IsNullable);
        if (columnType is not null)
        {
            Assert.Equal(columnType, property.GetColumnType());
        }
    }
}
