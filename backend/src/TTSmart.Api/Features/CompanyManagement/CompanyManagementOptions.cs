namespace TTSmart.Api.Features.CompanyManagement;

public sealed class CompanyManagementOptions
{
    public const string SectionName = "CompanyManagement";
    public bool LockChangesEnabled { get; init; }
    public bool ExpirationChangesEnabled { get; init; }
}
