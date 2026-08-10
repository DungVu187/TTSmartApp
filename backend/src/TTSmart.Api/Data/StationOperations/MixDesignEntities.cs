namespace TTSmart.Api.Data.StationOperations;

public sealed class StationMixDesignMaterial
{
    public int ConcreteGradeId { get; set; }
    public int MaterialSlotId { get; set; }
    public float? Quantity { get; set; }
}

public sealed class StationMixDesignMaterialSlot
{
    public int MaterialSlotId { get; set; }
    public int SlotNumber { get; set; }
    public int? StationInternalId { get; set; }
    public int? MaterialTypeId { get; set; }
    public string? Name { get; set; }
}

public sealed class StationCurrentMaterialType
{
    public int MaterialTypeId { get; set; }
    public string? Name { get; set; }
}
