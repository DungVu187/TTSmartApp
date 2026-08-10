namespace TTSmart.Api.Data.Company;

public sealed class CompanyDatabaseOptions
{
    public const string SectionName = "CompanyDatabase";
    public bool IsLockedColumnAvailable { get; init; }
}
