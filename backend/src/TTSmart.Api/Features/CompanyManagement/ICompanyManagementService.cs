using TTSmart.Api.Common.Models;

namespace TTSmart.Api.Features.CompanyManagement;

public interface ICompanyManagementService
{
    Task<PagedResponse<CompanyResponse>> GetPageAsync(
        CompanyListQuery query,
        int currentUserId,
        CancellationToken cancellationToken);

    Task<CompanyResponse> GetByIdAsync(int id, int currentUserId, CancellationToken cancellationToken);

    Task<CompanyResponse> CreateAsync(
        CreateCompanyRequest request,
        int currentUserId,
        CancellationToken cancellationToken);

    Task<CompanyResponse> UpdateAsync(
        int id,
        UpdateCompanyRequest request,
        int currentUserId,
        CancellationToken cancellationToken);

    Task<CompanyResponse> SetLockAsync(
        int id,
        SetCompanyLockRequest request,
        int currentUserId,
        CancellationToken cancellationToken);

    Task<CompanyResponse> SetExpirationAsync(
        int id,
        SetCompanyExpirationRequest request,
        int currentUserId,
        CancellationToken cancellationToken);

    Task<CompanyResponse> UploadLogoAsync(
        int id,
        UploadCompanyLogoRequest request,
        int currentUserId,
        CancellationToken cancellationToken);

    Task<CompanyLogoReadResult> GetLogoAsync(
        int id,
        int currentUserId,
        CancellationToken cancellationToken);

    Task<CompanyResponse> DeleteAsync(
        int id,
        int currentUserId,
        CancellationToken cancellationToken);

    Task<CompanyResponse> RestoreAsync(
        int id,
        int currentUserId,
        CancellationToken cancellationToken);
}
