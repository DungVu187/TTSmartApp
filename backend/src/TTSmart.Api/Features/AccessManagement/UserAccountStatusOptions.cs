namespace TTSmart.Api.Features.AccessManagement;

public sealed class UserAccountStatusOptions
{
    public const string SectionName = "UserAccountStatus";
    public bool StatusChangesEnabled { get; init; }
}
