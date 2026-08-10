namespace TTSmart.Api.Features.CompanyManagement;

public sealed class CompanyAccessOptions
{
    public const string SectionName = "CompanyAccess";
    public bool EnforceExpiration { get; init; }
}
