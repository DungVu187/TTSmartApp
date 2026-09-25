using TTSmart.Api.Common.Models;

namespace TTSmart.Api.Features.AccessManagement;

public interface IUserAdministrationService
{
    Task<PagedResponse<UserResponse>> GetPageAsync(
        UserListQuery query,
        int currentUserId,
        CancellationToken cancellationToken);
    Task<IReadOnlyList<RoleListItemResponse>> GetAssignableRolesAsync(
        int currentUserId,
        CancellationToken cancellationToken);
    Task<UserResponse> GetByIdAsync(int id, int currentUserId, CancellationToken cancellationToken);
    Task<UserResponse> CreateAsync(CreateUserRequest request, int currentUserId, CancellationToken cancellationToken);
    Task<UserResponse> UpdateAsync(int id, UpdateUserRequest request, int currentUserId, CancellationToken cancellationToken);
    Task<UserResponse> SetStatusAsync(int id, int currentUserId, SetUserStatusRequest request, CancellationToken cancellationToken);
    Task<UserResponse> SetRolesAsync(int id, int currentUserId, SetUserRolesRequest request, CancellationToken cancellationToken);
    Task ResetPasswordAsync(int id, int currentUserId, ResetPasswordRequest request, CancellationToken cancellationToken);
    Task DeleteAsync(int id, int currentUserId, CancellationToken cancellationToken);
}

public interface IRoleAdministrationService
{
    Task<PagedResponse<RoleListItemResponse>> GetPageAsync(RoleListQuery query, CancellationToken cancellationToken);
    Task<RoleResponse> GetByIdAsync(int id, CancellationToken cancellationToken);
    Task<RoleResponse> CreateAsync(CreateRoleRequest request, int currentUserId, CancellationToken cancellationToken);
    Task<RoleResponse> UpdateAsync(int id, UpdateRoleRequest request, int currentUserId, CancellationToken cancellationToken);
    Task<RoleResponse> SetStatusAsync(int id, int currentUserId, SetRoleStatusRequest request, CancellationToken cancellationToken);
    Task<IReadOnlyList<RoleFunctionMatrixItemResponse>> GetFunctionMatrixAsync(int id, CancellationToken cancellationToken);
    Task<RoleResponse> SetFunctionsAsync(int id, int currentUserId, SetRoleFunctionsRequest request, CancellationToken cancellationToken);
    Task<RoleResponse> SetFunctionActiveKeyAsync(int roleId, int functionId, int currentUserId, SetRoleFunctionActiveKeyRequest request, CancellationToken cancellationToken);
    Task RemoveFunctionAsync(int roleId, int functionId, int currentUserId, CancellationToken cancellationToken);
    Task DeleteAsync(int id, int currentUserId, CancellationToken cancellationToken);
}

public interface IFunctionAdministrationService
{
    Task<IReadOnlyList<FunctionResponse>> GetListAsync(FunctionListQuery query, CancellationToken cancellationToken);
    Task<IReadOnlyList<FunctionTreeNodeResponse>> GetTreeAsync(FunctionListQuery query, CancellationToken cancellationToken);
    Task<FunctionResponse> GetByIdAsync(int id, CancellationToken cancellationToken);
    Task<FunctionResponse> CreateAsync(CreateFunctionRequest request, int currentUserId, CancellationToken cancellationToken);
    Task<FunctionResponse> UpdateAsync(int id, UpdateFunctionRequest request, int currentUserId, CancellationToken cancellationToken);
    Task<FunctionResponse> SetStatusAsync(int id, int currentUserId, SetFunctionStatusRequest request, CancellationToken cancellationToken);
    Task DeleteAsync(int id, int currentUserId, CancellationToken cancellationToken);
}
