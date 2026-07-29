using TTSmart.Api.Common.Models;

namespace TTSmart.Api.Features.BranchManagement;

public interface IBranchManagementService
{
    Task<PagedResponse<BranchListItemResponse>> GetPageAsync(BranchListQuery query, int currentUserId, CancellationToken cancellationToken);
    Task<BranchResponse> GetByIdAsync(int id, int currentUserId, CancellationToken cancellationToken);
    Task<BranchResponse> CreateAsync(CreateBranchRequest request, int currentUserId, CancellationToken cancellationToken);
    Task<BranchResponse> UpdateAsync(int id, UpdateBranchRequest request, int currentUserId, CancellationToken cancellationToken);
    Task<BranchResponse> DeleteAsync(int id, int currentUserId, CancellationToken cancellationToken);
    Task<BranchResponse> RestoreAsync(int id, int currentUserId, CancellationToken cancellationToken);
}
