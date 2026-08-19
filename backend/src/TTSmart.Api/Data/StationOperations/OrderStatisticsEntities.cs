namespace TTSmart.Api.Data.StationOperations;

public sealed class StationOrderHistory
{
    public long OrderHistoryId { get; set; }
    public int? OrderId { get; set; }
    public int? SalesEmployeeId { get; set; }
    public float? OrderedVolume { get; set; }
    public string? CustomerName { get; set; }
    public DateTime? OrderedAt { get; set; }
    public string? ProjectName { get; set; }
    public string? LocationName { get; set; }
    public string? WorkItemName { get; set; }
    public string? RequestedVolumeText { get; set; }
    public string? EmployeeName { get; set; }
}

public sealed class StationMixingHistory
{
    public long MixingHistoryId { get; set; }
    public int StationInternalId { get; set; }
    public long? OrderHistoryId { get; set; }
    public string? ConcreteGradeName { get; set; }
    public string? Slump { get; set; }
    public int? ReceiptNumber { get; set; }
    public string? VehiclePlate { get; set; }
    public string? DriverName { get; set; }
    public DateTime? MixingDate { get; set; }
    public DateTime? StartedAt { get; set; }
    public DateTime? FinishedAt { get; set; }
    public bool? IsFinished { get; set; }
    public string? Username { get; set; }
}

public sealed class StationMixingDetail
{
    public long MixingDetailId { get; set; }
    public long MixingHistoryId { get; set; }
    public float? MixedVolume { get; set; }
    public int? BatchNumber { get; set; }
}

public sealed class StationVehicle
{
    public string VehiclePlate { get; set; } = string.Empty;
    public string? DriverName { get; set; }
}

public sealed class StationMixingMaterial
{
    public long MixingDetailId { get; set; }
    public long MaterialSlotId { get; set; }
    public float? ActualQuantity { get; set; }
    public float? TQuantity { get; set; }
    public float? DesignQuantity { get; set; }
}

public sealed class StationMaterialSlot
{
    public long MaterialSlotId { get; set; }
    public int? StationInternalId { get; set; }
    public long? MaterialTypeId { get; set; }
    public string? Name { get; set; }
    public int? SlotNumber { get; set; }
}

public sealed class StationMaterialType
{
    public long MaterialTypeId { get; set; }
    public string? Name { get; set; }
}

public sealed class StationAccount
{
    public string Username { get; set; } = string.Empty;
    public string? FullName { get; set; }
}
