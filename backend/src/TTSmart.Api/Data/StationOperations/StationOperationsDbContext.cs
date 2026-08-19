using Microsoft.EntityFrameworkCore;

namespace TTSmart.Api.Data.StationOperations;

public sealed class StationOperationsDbContext(DbContextOptions<StationOperationsDbContext> options)
    : DbContext(options)
{
    public DbSet<StationOrder> Orders => Set<StationOrder>();
    public DbSet<StationCustomer> Customers => Set<StationCustomer>();
    public DbSet<StationProject> Projects => Set<StationProject>();
    public DbSet<StationConcreteGrade> ConcreteGrades => Set<StationConcreteGrade>();
    public DbSet<StationMixDesignMaterial> MixDesignMaterials => Set<StationMixDesignMaterial>();
    public DbSet<StationMixDesignMaterialSlot> MixDesignMaterialSlots => Set<StationMixDesignMaterialSlot>();
    public DbSet<StationCurrentMaterialType> CurrentMaterialTypes => Set<StationCurrentMaterialType>();
    public DbSet<StationEmployee> Employees => Set<StationEmployee>();
    public DbSet<StationOrderHistory> OrderHistories => Set<StationOrderHistory>();
    public DbSet<StationMixingHistory> MixingHistories => Set<StationMixingHistory>();
    public DbSet<StationMixingDetail> MixingDetails => Set<StationMixingDetail>();
    public DbSet<StationVehicle> Vehicles => Set<StationVehicle>();
    public DbSet<StationMixingMaterial> MixingMaterials => Set<StationMixingMaterial>();
    public DbSet<StationMaterialSlot> MaterialSlots => Set<StationMaterialSlot>();
    public DbSet<StationMaterialType> MaterialTypes => Set<StationMaterialType>();
    public DbSet<StationAccount> Accounts => Set<StationAccount>();
    public DbSet<StationCompletedWeighTicket> CompletedWeighTickets => Set<StationCompletedWeighTicket>();
    public DbSet<StationPendingWeighTicket> PendingWeighTickets => Set<StationPendingWeighTicket>();
    public DbSet<StationScaleMaterial> ScaleMaterials => Set<StationScaleMaterial>();

    public override int SaveChanges(bool acceptAllChangesOnSuccess) =>
        throw new InvalidOperationException("Database vận hành chỉ được truy vấn read-only.");

    public override Task<int> SaveChangesAsync(
        bool acceptAllChangesOnSuccess,
        CancellationToken cancellationToken = default) =>
        throw new InvalidOperationException("Database vận hành chỉ được truy vấn read-only.");

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        var order = modelBuilder.Entity<StationOrder>();
        order.ToTable("DATHANG", "dbo");
        order.HasKey(item => item.OrderId);
        order.Property(item => item.OrderId).HasColumnName("MADATHANG");
        order.Property(item => item.CustomerId).HasColumnName("MAKH");
        order.Property(item => item.EmployeeId).HasColumnName("MANV");
        order.Property(item => item.ProjectId).HasColumnName("MADUAN");
        order.Property(item => item.OrderedVolume).HasColumnName("METKHOIDATHANG").HasColumnType("real");
        order.Property(item => item.OrderedAt).HasColumnName("NGAYDATHANG").HasColumnType("datetime");
        order.Property(item => item.ProducedVolume).HasColumnName("METKHOITICHLUY").HasColumnType("real");
        order.Property(item => item.ConcreteGradeId).HasColumnName("MAMACBETONG");

        var customer = modelBuilder.Entity<StationCustomer>();
        customer.ToTable("KHACHHANG", "dbo");
        customer.HasKey(item => item.CustomerId);
        customer.Property(item => item.CustomerId).HasColumnName("MAKH");
        customer.Property(item => item.Name).HasColumnName("TENKHACHHANG").HasColumnType("nvarchar(max)");

        var project = modelBuilder.Entity<StationProject>();
        project.ToTable("DUAN", "dbo");
        project.HasKey(item => item.ProjectId);
        project.Property(item => item.ProjectId).HasColumnName("MADUAN");
        project.Property(item => item.Name).HasColumnName("TENDUAN").HasColumnType("nvarchar(max)");

        var concreteGrade = modelBuilder.Entity<StationConcreteGrade>();
        concreteGrade.ToTable("MACBETONG", "dbo");
        concreteGrade.HasKey(item => item.ConcreteGradeId);
        concreteGrade.Property(item => item.ConcreteGradeId).HasColumnName("MAMACBETONG");
        concreteGrade.Property(item => item.Name).HasColumnName("TENMACBETONG").HasColumnType("nvarchar(max)");
        concreteGrade.Property(item => item.Strength).HasColumnName("CUONGDO");
        concreteGrade.Property(item => item.MaximumAggregateSize).HasColumnName("COTLIEUMAX");
        concreteGrade.Property(item => item.Slump).HasColumnName("DOSUT").HasColumnType("nvarchar(max)");

        var mixDesignMaterial = modelBuilder.Entity<StationMixDesignMaterial>();
        mixDesignMaterial.ToTable("SOLUONGVL", "dbo");
        mixDesignMaterial.HasKey(item => new { item.ConcreteGradeId, item.MaterialSlotId });
        mixDesignMaterial.Property(item => item.ConcreteGradeId).HasColumnName("MAMACBETONG");
        mixDesignMaterial.Property(item => item.MaterialSlotId).HasColumnName("MACUAVL");
        mixDesignMaterial.Property(item => item.Quantity).HasColumnName("SOLUONG").HasColumnType("real");

        var mixDesignMaterialSlot = modelBuilder.Entity<StationMixDesignMaterialSlot>();
        mixDesignMaterialSlot.ToTable("CUAVL", "dbo");
        mixDesignMaterialSlot.HasKey(item => item.MaterialSlotId);
        mixDesignMaterialSlot.Property(item => item.MaterialSlotId).HasColumnName("MACUAVL");
        mixDesignMaterialSlot.Property(item => item.SlotNumber).HasColumnName("STTCUAVL");
        mixDesignMaterialSlot.Property(item => item.StationInternalId).HasColumnName("MATRAM");
        mixDesignMaterialSlot.Property(item => item.MaterialTypeId).HasColumnName("MALOAIVL");
        mixDesignMaterialSlot.Property(item => item.Name).HasColumnName("TENCUAVL").HasColumnType("nvarchar(max)");

        var currentMaterialType = modelBuilder.Entity<StationCurrentMaterialType>();
        currentMaterialType.ToTable("LOAIVL", "dbo");
        currentMaterialType.HasKey(item => item.MaterialTypeId);
        currentMaterialType.Property(item => item.MaterialTypeId).HasColumnName("MALOAIVL");
        currentMaterialType.Property(item => item.Name).HasColumnName("TENLOAIVL").HasColumnType("nvarchar(max)");

        var employee = modelBuilder.Entity<StationEmployee>();
        employee.ToTable("NHANVIEN", "dbo");
        employee.HasKey(item => item.EmployeeId);
        employee.Property(item => item.EmployeeId).HasColumnName("MANV");
        employee.Property(item => item.Name).HasColumnName("TENNV").HasColumnType("nvarchar(max)");

        var orderHistory = modelBuilder.Entity<StationOrderHistory>();
        orderHistory.ToTable("LSDATHANG", "dbo");
        orderHistory.HasKey(item => item.OrderHistoryId);
        orderHistory.Property(item => item.OrderHistoryId).HasColumnName("STT");
        orderHistory.Property(item => item.OrderId).HasColumnName("MADATHANG");
        orderHistory.Property(item => item.SalesEmployeeId).HasColumnName("MANV");
        orderHistory.Property(item => item.OrderedVolume).HasColumnName("METKHOIDATHANG").HasColumnType("real");
        orderHistory.Property(item => item.CustomerName).HasColumnName("TENKHACHHANG").HasColumnType("nvarchar(max)");
        orderHistory.Property(item => item.OrderedAt).HasColumnName("NGAYDATHANG").HasColumnType("datetime");
        orderHistory.Property(item => item.ProjectName).HasColumnName("TENDUAN").HasColumnType("nvarchar(max)");
        orderHistory.Property(item => item.LocationName).HasColumnName("DIADIEMXD").HasColumnType("nvarchar(max)");
        orderHistory.Property(item => item.WorkItemName).HasColumnName("TENHANGMUC").HasColumnType("nvarchar(max)");
        orderHistory.Property(item => item.RequestedVolumeText).HasColumnName("MATHENV").HasColumnType("nvarchar(max)");
        orderHistory.Property(item => item.EmployeeName).HasColumnName("TENNV").HasColumnType("nvarchar(max)");

        var mixingHistory = modelBuilder.Entity<StationMixingHistory>();
        mixingHistory.ToTable("LSTRON", "dbo");
        mixingHistory.HasKey(item => item.MixingHistoryId);
        mixingHistory.Property(item => item.MixingHistoryId).HasColumnName("MALSTRON");
        mixingHistory.Property(item => item.StationInternalId).HasColumnName("MATRAM");
        mixingHistory.Property(item => item.OrderHistoryId).HasColumnName("STTLSDATHANG");
        mixingHistory.Property(item => item.ConcreteGradeName).HasColumnName("TENMACBETONG").HasColumnType("nvarchar(max)");
        mixingHistory.Property(item => item.Slump).HasColumnName("DOSUT").HasColumnType("nvarchar(max)");
        mixingHistory.Property(item => item.ReceiptNumber).HasColumnName("SOPHIEU");
        mixingHistory.Property(item => item.VehiclePlate).HasColumnName("BIENSO").HasColumnType("nvarchar(max)");
        mixingHistory.Property(item => item.DriverName).HasColumnName("TENLAIXE").HasColumnType("nvarchar(max)");
        mixingHistory.Property(item => item.MixingDate).HasColumnName("NGAYTRON").HasColumnType("datetime");
        mixingHistory.Property(item => item.StartedAt).HasColumnName("GIOBATDAU").HasColumnType("datetime");
        mixingHistory.Property(item => item.FinishedAt).HasColumnName("GIOXONG").HasColumnType("datetime");
        mixingHistory.Property(item => item.IsFinished).HasColumnName("FINISHOK");
        mixingHistory.Property(item => item.Username).HasColumnName("USERNAME").HasColumnType("nvarchar(50)");

        var mixingDetail = modelBuilder.Entity<StationMixingDetail>();
        mixingDetail.ToTable("LSCHITIETMETRON", "dbo");
        mixingDetail.HasKey(item => item.MixingDetailId);
        mixingDetail.Property(item => item.MixingDetailId).HasColumnName("MACHITIETMETRON");
        mixingDetail.Property(item => item.MixingHistoryId).HasColumnName("MALSTRON");
        mixingDetail.Property(item => item.MixedVolume).HasColumnName("M3METRON").HasColumnType("real");
        mixingDetail.Property(item => item.BatchNumber).HasColumnName("SOTTMETRON");

        var vehicle = modelBuilder.Entity<StationVehicle>();
        vehicle.ToTable("XE", "dbo");
        vehicle.HasKey(item => item.VehiclePlate);
        vehicle.Property(item => item.VehiclePlate)
            .HasColumnName("BIENSO")
            .HasColumnType("nvarchar(50)");
        vehicle.Property(item => item.DriverName)
            .HasColumnName("TENLAIXE")
            .HasColumnType("nvarchar(max)");

        var mixingMaterial = modelBuilder.Entity<StationMixingMaterial>();
        mixingMaterial.ToTable("LSCHITIETMETRONLSCUAVL", "dbo");
        mixingMaterial.HasKey(item => new { item.MixingDetailId, item.MaterialSlotId });
        mixingMaterial.Property(item => item.MixingDetailId).HasColumnName("MACHITIETMETRON");
        mixingMaterial.Property(item => item.MaterialSlotId).HasColumnName("MACUAVL");
        mixingMaterial.Property(item => item.ActualQuantity).HasColumnName("SOLUONG").HasColumnType("real");
        mixingMaterial.Property(item => item.TQuantity).HasColumnName("SOLUONGT").HasColumnType("real");
        mixingMaterial.Property(item => item.DesignQuantity).HasColumnName("SOLUONGCP").HasColumnType("real");

        var materialSlot = modelBuilder.Entity<StationMaterialSlot>();
        materialSlot.ToTable("LSCUAVL", "dbo");
        materialSlot.HasKey(item => item.MaterialSlotId);
        materialSlot.Property(item => item.MaterialSlotId).HasColumnName("MACUAVL");
        materialSlot.Property(item => item.StationInternalId).HasColumnName("MATRAM");
        materialSlot.Property(item => item.MaterialTypeId).HasColumnName("MALOAIVL");
        materialSlot.Property(item => item.Name).HasColumnName("TENCUAVL").HasColumnType("nvarchar(max)");
        materialSlot.Property(item => item.SlotNumber).HasColumnName("STTCUAVL");

        var materialType = modelBuilder.Entity<StationMaterialType>();
        materialType.ToTable("LSLOAIVL", "dbo");
        materialType.HasKey(item => item.MaterialTypeId);
        materialType.Property(item => item.MaterialTypeId).HasColumnName("MALOAIVL");
        materialType.Property(item => item.Name).HasColumnName("TENLOAIVL").HasColumnType("nvarchar(max)");

        var account = modelBuilder.Entity<StationAccount>();
        account.ToTable("ACCOUNT", "dbo");
        account.HasKey(item => item.Username);
        account.Property(item => item.Username).HasColumnName("USERNAME").HasColumnType("nvarchar(50)");
        account.Property(item => item.FullName).HasColumnName("FULLNAME").HasColumnType("nvarchar(50)");

        var completedWeighTicket = modelBuilder.Entity<StationCompletedWeighTicket>();
        completedWeighTicket.ToTable("TC_XEVAORA", "dbo");
        completedWeighTicket.HasKey(item => item.Sequence);
        completedWeighTicket.Property(item => item.Sequence).HasColumnName("STT");
        completedWeighTicket.Property(item => item.Id).HasColumnName("ID").HasColumnType("uniqueidentifier");
        completedWeighTicket.Property(item => item.TicketCode).HasColumnName("MAPHIEU").HasColumnType("nvarchar(400)");
        completedWeighTicket.Property(item => item.VehiclePlate).HasColumnName("BIENXE").HasColumnType("nvarchar(max)");
        completedWeighTicket.Property(item => item.DriverName).HasColumnName("CHUXE").HasColumnType("nvarchar(max)");
        completedWeighTicket.Property(item => item.SealNumber).HasColumnName("MASO").HasColumnType("nvarchar(max)");
        completedWeighTicket.Property(item => item.FirstWeight).HasColumnName("KHOILUONGCANLAN1").HasColumnType("float");
        completedWeighTicket.Property(item => item.SecondWeight).HasColumnName("KHOILUONGCANLAN2").HasColumnType("float");
        completedWeighTicket.Property(item => item.GoodsWeight).HasColumnName("DECIMAL1").HasColumnType("decimal(18,0)");
        completedWeighTicket.Property(item => item.ConversionFactor).HasColumnName("HESOQUYDOI").HasColumnType("real");
        completedWeighTicket.Property(item => item.ConversionUnit).HasColumnName("DONVITINH").HasColumnType("nvarchar(max)");
        completedWeighTicket.Property(item => item.UnitName).HasColumnName("DONVI").HasColumnType("nvarchar(max)");
        completedWeighTicket.Property(item => item.GoodsName).HasColumnName("TENVATLIEU").HasColumnType("nvarchar(max)");
        completedWeighTicket.Property(item => item.MaterialCode).HasColumnName("MAVATLIEU").HasColumnType("nvarchar(max)");
        completedWeighTicket.Property(item => item.WeighingType).HasColumnName("LOAICAN").HasColumnType("nvarchar(max)");
        completedWeighTicket.Property(item => item.MixingStationConnection).HasColumnName("TRAMTRONCONNECTION").HasColumnType("nvarchar(max)");
        completedWeighTicket.Property(item => item.VehicleExitStatus).HasColumnName("XERACHUA").HasColumnType("bit");
        completedWeighTicket.Property(item => item.FirstOperatorName).HasColumnName("USERNAME").HasColumnType("nvarchar(max)");
        completedWeighTicket.Property(item => item.SecondOperatorName).HasColumnName("USERNAME2").HasColumnType("nvarchar(max)");
        completedWeighTicket.Property(item => item.FirstWeighedAt).HasColumnName("THOIGIANCANLAN1").HasColumnType("datetime");
        completedWeighTicket.Property(item => item.SecondWeighedAt).HasColumnName("THOIGIANCANLAN2").HasColumnType("datetime");
        completedWeighTicket.Property(item => item.LastUpdatedAt).HasColumnName("Lastupdated").HasColumnType("datetime");

        var pendingWeighTicket = modelBuilder.Entity<StationPendingWeighTicket>();
        pendingWeighTicket.ToTable("TC_XEVAORA_BANGTAM", "dbo");
        pendingWeighTicket.HasKey(item => item.Sequence);
        pendingWeighTicket.Property(item => item.Sequence).HasColumnName("STT");
        pendingWeighTicket.Property(item => item.Id).HasColumnName("ID").HasColumnType("uniqueidentifier");
        pendingWeighTicket.Property(item => item.TicketCode).HasColumnName("MAPHIEU").HasColumnType("nvarchar(40)");
        pendingWeighTicket.Property(item => item.VehiclePlate).HasColumnName("BIENXE").HasColumnType("nvarchar(max)");
        pendingWeighTicket.Property(item => item.DriverName).HasColumnName("CHUXE").HasColumnType("nvarchar(max)");
        pendingWeighTicket.Property(item => item.SealNumber).HasColumnName("MASO").HasColumnType("nvarchar(max)");
        pendingWeighTicket.Property(item => item.FirstWeight).HasColumnName("KHOILUONGCANLAN1").HasColumnType("float");
        pendingWeighTicket.Property(item => item.SecondWeight).HasColumnName("KHOILUONGCANLAN2").HasColumnType("float");
        pendingWeighTicket.Property(item => item.GoodsWeight).HasColumnName("DECIMAL1").HasColumnType("decimal(18,0)");
        pendingWeighTicket.Property(item => item.ConversionFactor).HasColumnName("HESOQUYDOI").HasColumnType("real");
        pendingWeighTicket.Property(item => item.ConversionUnit).HasColumnName("DONVITINH").HasColumnType("nvarchar(max)");
        pendingWeighTicket.Property(item => item.UnitName).HasColumnName("DONVI").HasColumnType("nvarchar(max)");
        pendingWeighTicket.Property(item => item.GoodsName).HasColumnName("TENVATLIEU").HasColumnType("nvarchar(max)");
        pendingWeighTicket.Property(item => item.WeighingType).HasColumnName("LOAICAN").HasColumnType("nvarchar(max)");
        pendingWeighTicket.Property(item => item.FirstOperatorName).HasColumnName("USERNAME").HasColumnType("nvarchar(max)");
        pendingWeighTicket.Property(item => item.SecondOperatorName).HasColumnName("USERNAME2").HasColumnType("nvarchar(max)");
        pendingWeighTicket.Property(item => item.FirstWeighedAt).HasColumnName("THOIGIANCANLAN1").HasColumnType("datetime");
        pendingWeighTicket.Property(item => item.SecondWeighedAt).HasColumnName("THOIGIANCANLAN2").HasColumnType("datetime");
        pendingWeighTicket.Property(item => item.LastUpdatedAt).HasColumnName("Lastupdated").HasColumnType("datetime");

        var scaleMaterial = modelBuilder.Entity<StationScaleMaterial>();
        scaleMaterial.ToTable("TC_VATLIEU", "dbo");
        scaleMaterial.HasKey(item => item.MaterialCode);
        scaleMaterial.Property(item => item.MaterialCode).HasColumnName("MAVATLIEU");
        scaleMaterial.Property(item => item.Name).HasColumnName("TENVATLIEU").HasColumnType("nvarchar(max)");
        scaleMaterial.Property(item => item.Category).HasColumnName("LOAIVL").HasColumnType("nvarchar(max)");
        scaleMaterial.Property(item => item.ConversionUnit).HasColumnName("DONVITINH").HasColumnType("nvarchar(max)");
        scaleMaterial.Property(item => item.ConversionFactor).HasColumnName("HESOQUYDOI").HasColumnType("real");
    }
}
