using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Options;
using TTSmart.Api.Data.StationOperations;

namespace TTSmart.Api.Tests;

public sealed class StationOperationsMappingTests
{
    [Fact]
    public void Mapping_BCDH_GiuDungTenBangCotVaKieuDuLieu()
    {
        var options = new DbContextOptionsBuilder<StationOperationsDbContext>()
            .UseSqlServer("Server=(local);Database=unused;Trusted_Connection=True;")
            .Options;
        using var dbContext = new StationOperationsDbContext(options);
        var order = dbContext.Model.FindEntityType(typeof(StationOrder))!;
        var orderTable = StoreObjectIdentifier.Table("DATHANG", "dbo");

        Assert.Equal("DATHANG", order.GetTableName());
        Assert.Equal("MADATHANG", order.FindProperty(nameof(StationOrder.OrderId))!.GetColumnName(orderTable));
        Assert.Equal("MAKH", order.FindProperty(nameof(StationOrder.CustomerId))!.GetColumnName(orderTable));
        Assert.Equal("MANV", order.FindProperty(nameof(StationOrder.EmployeeId))!.GetColumnName(orderTable));
        Assert.Equal("MADUAN", order.FindProperty(nameof(StationOrder.ProjectId))!.GetColumnName(orderTable));
        Assert.Equal("MAMACBETONG", order.FindProperty(nameof(StationOrder.ConcreteGradeId))!.GetColumnName(orderTable));
        Assert.Equal("METKHOIDATHANG", order.FindProperty(nameof(StationOrder.OrderedVolume))!.GetColumnName(orderTable));
        Assert.Equal("METKHOITICHLUY", order.FindProperty(nameof(StationOrder.ProducedVolume))!.GetColumnName(orderTable));
        Assert.Equal("NGAYDATHANG", order.FindProperty(nameof(StationOrder.OrderedAt))!.GetColumnName(orderTable));
        Assert.Equal("real", order.FindProperty(nameof(StationOrder.OrderedVolume))!.GetColumnType());
        Assert.Equal("real", order.FindProperty(nameof(StationOrder.ProducedVolume))!.GetColumnType());
        Assert.Equal("datetime", order.FindProperty(nameof(StationOrder.OrderedAt))!.GetColumnType());

        AssertLookupMapping<StationCustomer>(dbContext, "KHACHHANG", "CustomerId", "MAKH", "TENKHACHHANG");
        AssertLookupMapping<StationProject>(dbContext, "DUAN", "ProjectId", "MADUAN", "TENDUAN");
        AssertLookupMapping<StationConcreteGrade>(
            dbContext,
            "MACBETONG",
            "ConcreteGradeId",
            "MAMACBETONG",
            "TENMACBETONG");
        AssertLookupMapping<StationEmployee>(dbContext, "NHANVIEN", "EmployeeId", "MANV", "TENNV");
    }

    [Fact]
    public void Mapping_TKDH_GiuDungChuoiBangVaCotLichSuTron()
    {
        var options = new DbContextOptionsBuilder<StationOperationsDbContext>()
            .UseSqlServer("Server=(local);Database=unused;Trusted_Connection=True;")
            .Options;
        using var dbContext = new StationOperationsDbContext(options);

        AssertColumn<StationOrderHistory>(dbContext, "LSDATHANG", "OrderHistoryId", "STT");
        AssertColumn<StationOrderHistory>(dbContext, "LSDATHANG", "SalesEmployeeId", "MANV");
        AssertColumn<StationOrderHistory>(dbContext, "LSDATHANG", "SalesEmployeeCode", "MATHENV");
        AssertColumn<StationOrderHistory>(dbContext, "LSDATHANG", "EmployeeName", "TENNV");
        AssertColumn<StationMixingHistory>(dbContext, "LSTRON", "MixingHistoryId", "MALSTRON");
        AssertColumn<StationMixingHistory>(dbContext, "LSTRON", "OrderHistoryId", "STTLSDATHANG");
        AssertColumn<StationMixingObservation>(dbContext, "GIAMSATTRON", "ExternalId", "ID");
        AssertColumn<StationMixingObservation>(dbContext, "GIAMSATTRON", "StartedAt", "GIOBD");
        AssertColumn<StationMixingObservation>(dbContext, "GIAMSATTRON", "FinishedAt", "GIOKT");
        AssertColumn<StationMixingObservation>(dbContext, "GIAMSATTRON", "RequestedVolume", "SOM3METRON");
        AssertColumn<StationMixingObservation>(dbContext, "GIAMSATTRON", "IsFinished", "FINISH_OK");
        AssertColumn<StationMixingObservation>(dbContext, "GIAMSATTRON", "IsSaved", "DALUU");
        AssertColumn<StationMixingDetail>(dbContext, "LSCHITIETMETRON", "MixingDetailId", "MACHITIETMETRON");
        AssertColumn<StationMixingDetail>(dbContext, "LSCHITIETMETRON", "MixingHistoryId", "MALSTRON");
        AssertColumn<StationMixingDetail>(dbContext, "LSCHITIETMETRON", "MixedVolume", "M3METRON");
        AssertColumn<StationMixingDetail>(dbContext, "LSCHITIETMETRON", "MixingObservationExternalId", "GIAMSATTRONID");
        AssertColumn<StationMixingMaterial>(dbContext, "LSCHITIETMETRONLSCUAVL", "ActualQuantity", "SOLUONG");
        AssertColumn<StationMixingMaterial>(dbContext, "LSCHITIETMETRONLSCUAVL", "TQuantity", "SOLUONGT");
        AssertColumn<StationMixingMaterial>(dbContext, "LSCHITIETMETRONLSCUAVL", "DesignQuantity", "SOLUONGCP");
        AssertColumn<StationMaterialSlot>(dbContext, "LSCUAVL", "MaterialSlotId", "MACUAVL");
        AssertColumn<StationMaterialSlot>(dbContext, "LSCUAVL", "SlotNumber", "STTCUAVL");
        AssertColumn<StationMaterialType>(dbContext, "LSLOAIVL", "MaterialTypeId", "MALOAIVL");
    }

    [Fact]
    public void Mapping_TKTC_GiuDungHaiBangCanVa17CotHienThi()
    {
        var options = new DbContextOptionsBuilder<StationOperationsDbContext>()
            .UseSqlServer("Server=(local);Database=unused;Trusted_Connection=True;")
            .Options;
        using var dbContext = new StationOperationsDbContext(options);

        AssertWeighTicketMapping<StationCompletedWeighTicket>(
            dbContext,
            "TC_XEVAORA",
            "nvarchar(400)");
        AssertWeighTicketMapping<StationPendingWeighTicket>(
            dbContext,
            "TC_XEVAORA_BANGTAM",
            "nvarchar(40)");
    }

    [Fact]
    public void Factory_Development_ThayInitialCatalogBangOverrideVaTuChoiTenKhongAnToan()
    {
        var configuration = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["ConnectionStrings:StationConnection"] =
                    "Server=.\\SQLEXPRESS;Database=TTSmartMobile_Dev;Trusted_Connection=True;TrustServerCertificate=True;"
            })
            .Build();
        var options = Options.Create(new StationDatabaseOptions
        {
            BranchDatabaseOverrides = new Dictionary<int, string>
            {
                [10] = "QUANLYTAITRAM_Local"
            }
        });
        var factory = new StationOperationsDbContextFactory(
            configuration,
            options,
            new TestHostEnvironment("Development"));

        using var dbContext = factory.Create(new StationDatabaseTarget(10, "ignored_database"));
        Assert.Equal("QUANLYTAITRAM_Local", dbContext.Database.GetDbConnection().Database);
        Assert.Contains(
            "Application Intent=ReadOnly",
            dbContext.Database.GetConnectionString(),
            StringComparison.OrdinalIgnoreCase);
        Assert.Throws<StationDatabaseConfigurationException>(() =>
            factory.Create(new StationDatabaseTarget(11, "bad-database-name")));
    }

    [Theory]
    [InlineData(1, "ttsmart1", "ttsmart1_online")]
    [InlineData(1, "ttsmart1_online", "ttsmart1_online")]
    [InlineData(2, "ttsmart1", "ttsmart1_tc_online")]
    [InlineData(2, "ttsmart1_tc_online", "ttsmart1_tc_online")]
    public void Factory_ThemHauToDatabaseTheoLoaiTram(
        int typeTram,
        string databaseName,
        string expectedDatabaseName)
    {
        var configuration = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["ConnectionStrings:StationConnection"] =
                    "Server=.\\SQLEXPRESS;Database=master;Trusted_Connection=True;TrustServerCertificate=True;"
            })
            .Build();
        var factory = new StationOperationsDbContextFactory(
            configuration,
            Options.Create(new StationDatabaseOptions()),
            new TestHostEnvironment("Production"));

        using var dbContext = factory.Create(new StationDatabaseTarget(10, databaseName, typeTram));
        Assert.Equal(expectedDatabaseName, dbContext.Database.GetDbConnection().Database);
    }

    [Fact]
    public void Factory_ThieuStationConnection_ThiTuChoiThayViFallbackAuthConnection()
    {
        var configuration = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["ConnectionStrings:AuthConnection"] =
                    "Server=.\\SQLEXPRESS;Database=TTSmartMobile_Dev;Trusted_Connection=True;"
            })
            .Build();
        var factory = new StationOperationsDbContextFactory(
            configuration,
            Options.Create(new StationDatabaseOptions()),
            new TestHostEnvironment("Development"));

        Assert.Throws<StationDatabaseConfigurationException>(() =>
            factory.Create(new StationDatabaseTarget(10, "QUANLYTAITRAM_Local")));
    }

    [Fact]
    public void Factory_Production_TuChoiBranchDatabaseOverride()
    {
        var configuration = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["ConnectionStrings:StationConnection"] =
                    "Server=.\\SQLEXPRESS;Database=master;Trusted_Connection=True;"
            })
            .Build();
        var options = Options.Create(new StationDatabaseOptions
        {
            BranchDatabaseOverrides = new Dictionary<int, string>
            {
                [10] = "QUANLYTAITRAM_Local"
            }
        });
        var factory = new StationOperationsDbContextFactory(
            configuration,
            options,
            new TestHostEnvironment("Production"));

        Assert.Throws<StationDatabaseConfigurationException>(() =>
            factory.Create(new StationDatabaseTarget(10, "TRAM_10_online")));
    }

    [Fact]
    public async Task Context_VanHanh_TuChoiSaveChanges()
    {
        var options = new DbContextOptionsBuilder<StationOperationsDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        using var dbContext = new StationOperationsDbContext(options);

        Assert.Throws<InvalidOperationException>(() => dbContext.SaveChanges());
        await Assert.ThrowsAsync<InvalidOperationException>(() => dbContext.SaveChangesAsync());
    }

    private static void AssertLookupMapping<TEntity>(
        StationOperationsDbContext dbContext,
        string tableName,
        string keyPropertyName,
        string keyColumnName,
        string nameColumnName)
    {
        var entity = dbContext.Model.FindEntityType(typeof(TEntity))!;
        var table = StoreObjectIdentifier.Table(tableName, "dbo");

        Assert.Equal(tableName, entity.GetTableName());
        Assert.Equal(keyColumnName, entity.FindProperty(keyPropertyName)!.GetColumnName(table));
        Assert.Equal(nameColumnName, entity.FindProperty("Name")!.GetColumnName(table));
        Assert.Equal("nvarchar(max)", entity.FindProperty("Name")!.GetColumnType());
    }

    private static void AssertColumn<TEntity>(
        StationOperationsDbContext dbContext,
        string tableName,
        string propertyName,
        string columnName)
    {
        var entity = dbContext.Model.FindEntityType(typeof(TEntity))!;
        var table = StoreObjectIdentifier.Table(tableName, "dbo");

        Assert.Equal(tableName, entity.GetTableName());
        Assert.Equal(columnName, entity.FindProperty(propertyName)!.GetColumnName(table));
    }

    private static void AssertWeighTicketMapping<TEntity>(
        StationOperationsDbContext dbContext,
        string tableName,
        string ticketNumberColumnType)
    {
        var entity = dbContext.Model.FindEntityType(typeof(TEntity))!;
        var table = StoreObjectIdentifier.Table(tableName, "dbo");

        Assert.Equal(tableName, entity.GetTableName());
        Assert.Equal("STT", entity.FindProperty("Sequence")!.GetColumnName(table));
        Assert.Equal("ID", entity.FindProperty("Id")!.GetColumnName(table));
        Assert.Equal("MAPHIEU", entity.FindProperty("TicketCode")!.GetColumnName(table));
        Assert.Equal(ticketNumberColumnType, entity.FindProperty("TicketCode")!.GetColumnType());
        Assert.Equal("BIENXE", entity.FindProperty("VehiclePlate")!.GetColumnName(table));
        Assert.Equal("CHUXE", entity.FindProperty("DriverName")!.GetColumnName(table));
        Assert.Equal("MASO", entity.FindProperty("SealNumber")!.GetColumnName(table));
        Assert.Equal("KHOILUONGCANLAN1", entity.FindProperty("FirstWeight")!.GetColumnName(table));
        Assert.Equal("KHOILUONGCANLAN2", entity.FindProperty("SecondWeight")!.GetColumnName(table));
        Assert.Equal("DECIMAL1", entity.FindProperty("GoodsWeight")!.GetColumnName(table));
        Assert.Equal("HESOQUYDOI", entity.FindProperty("ConversionFactor")!.GetColumnName(table));
        Assert.Equal("DONVITINH", entity.FindProperty("ConversionUnit")!.GetColumnName(table));
        Assert.Equal("DONVI", entity.FindProperty("UnitName")!.GetColumnName(table));
        Assert.Equal("TENVATLIEU", entity.FindProperty("GoodsName")!.GetColumnName(table));
        Assert.Equal("LOAICAN", entity.FindProperty("WeighingType")!.GetColumnName(table));
        Assert.Equal("USERNAME", entity.FindProperty("FirstOperatorName")!.GetColumnName(table));
        Assert.Equal("USERNAME2", entity.FindProperty("SecondOperatorName")!.GetColumnName(table));
        Assert.Equal("THOIGIANCANLAN1", entity.FindProperty("FirstWeighedAt")!.GetColumnName(table));
        Assert.Equal("THOIGIANCANLAN2", entity.FindProperty("SecondWeighedAt")!.GetColumnName(table));
        Assert.Equal("Lastupdated", entity.FindProperty("LastUpdatedAt")!.GetColumnName(table));
        Assert.Equal("float", entity.FindProperty("FirstWeight")!.GetColumnType());
        Assert.Equal("decimal(18,0)", entity.FindProperty("GoodsWeight")!.GetColumnType());
        Assert.Equal("real", entity.FindProperty("ConversionFactor")!.GetColumnType());
        Assert.Equal("nvarchar(max)", entity.FindProperty("ConversionUnit")!.GetColumnType());
        Assert.Equal("datetime", entity.FindProperty("FirstWeighedAt")!.GetColumnType());
        Assert.Equal("datetime", entity.FindProperty("LastUpdatedAt")!.GetColumnType());
    }

    private sealed class TestHostEnvironment(string environmentName) : IHostEnvironment
    {
        public string EnvironmentName { get; set; } = environmentName;
        public string ApplicationName { get; set; } = "TTSmart.Api.Tests";
        public string ContentRootPath { get; set; } = AppContext.BaseDirectory;
        public IFileProvider ContentRootFileProvider { get; set; } = new NullFileProvider();
    }
}
