import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/json_helpers.dart';
import '../models/function_models.dart';
import '../models/pagination_models.dart';
import '../models/role_models.dart';
import '../models/user_models.dart';

class AccessManagementRepository {
  const AccessManagementRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<PagedResponse<UserResponse>> getUsers({
    int pageNumber = 1,
    int pageSize = 20,
    String? search,
    int? status,
    int? roleId,
    int? companyId,
    int? branchId,
    bool? withoutRole,
  }) async {
    _validateStatus(status);
    final response = await _apiClient.get(
      '/api/users',
      query: <String, Object?>{
        'pageNumber': pageNumber,
        'pageSize': pageSize,
        'search': _normalizedSearch(search),
        'status': status,
        'roleId': roleId,
        'companyId': companyId,
        'branchId': branchId,
        'withoutRole': withoutRole,
      },
    );
    return _parse(
      () => PagedResponse.fromJson(response, UserResponse.fromJson),
    );
  }

  Future<UserResponse> getUser(int id) =>
      _getModel('/api/users/$id', UserResponse.fromJson);

  Future<UserResponse> createUser(CreateUserRequest request) => _sendModel(
    () => _apiClient.post('/api/users', body: request.toJson()),
    UserResponse.fromJson,
  );

  Future<UserResponse> updateUser(int id, UpdateUserRequest request) =>
      _sendModel(
        () => _apiClient.put('/api/users/$id', body: request.toJson()),
        UserResponse.fromJson,
      );

  Future<UserResponse> setUserStatus(int id, SetUserStatusRequest request) =>
      _sendModel(
        () => _apiClient.put('/api/users/$id/status', body: request.toJson()),
        UserResponse.fromJson,
      );

  Future<UserResponse> setUserRoles(int id, SetUserRolesRequest request) =>
      _sendModel(
        () => _apiClient.put('/api/users/$id/roles', body: request.toJson()),
        UserResponse.fromJson,
      );

  Future<void> resetUserPassword(int id, ResetPasswordRequest request) async {
    await _apiClient.post(
      '/api/users/$id/reset-password',
      body: request.toJson(),
    );
  }

  Future<void> deleteUser(int id) async {
    await _apiClient.delete('/api/users/$id');
  }

  Future<PagedResponse<RoleListItemResponse>> getRoles({
    int pageNumber = 1,
    int pageSize = 20,
    String? search,
    int? status,
  }) async {
    _validateStatus(status);
    final response = await _apiClient.get(
      '/api/roles',
      query: <String, Object?>{
        'pageNumber': pageNumber,
        'pageSize': pageSize,
        'search': _normalizedSearch(search),
        'status': status,
      },
    );
    return _parse(
      () => PagedResponse.fromJson(response, RoleListItemResponse.fromJson),
    );
  }

  Future<List<RoleListItemResponse>> getAllRoles({int? status}) async {
    const pageSize = 100;
    var pageNumber = 1;
    final roles = <RoleListItemResponse>[];
    while (true) {
      final page = await getRoles(
        pageNumber: pageNumber,
        pageSize: pageSize,
        status: status,
      );
      roles.addAll(page.items);
      if (page.totalPages == 0 || page.pageNumber >= page.totalPages) {
        return roles;
      }
      pageNumber++;
    }
  }

  Future<List<RoleListItemResponse>> getAssignableRoles() async {
    final response = await _apiClient.get('/api/users/assignable-roles');
    return _parse(
      () => requireJsonList(
        response,
        'vai trò được phép gán',
      ).map(RoleListItemResponse.fromJson).toList(growable: false),
    );
  }

  Future<RoleResponse> getRole(int id) =>
      _getModel('/api/roles/$id', RoleResponse.fromJson);

  Future<RoleResponse> createRole(CreateRoleRequest request) => _sendModel(
    () => _apiClient.post('/api/roles', body: request.toJson()),
    RoleResponse.fromJson,
  );

  Future<RoleResponse> updateRole(int id, UpdateRoleRequest request) =>
      _sendModel(
        () => _apiClient.put('/api/roles/$id', body: request.toJson()),
        RoleResponse.fromJson,
      );

  Future<RoleResponse> setRoleStatus(int id, SetRoleStatusRequest request) =>
      _sendModel(
        () => _apiClient.put('/api/roles/$id/status', body: request.toJson()),
        RoleResponse.fromJson,
      );

  Future<List<RoleFunctionMatrixItemResponse>> getRoleFunctionMatrix(
    int id,
  ) async {
    final response = await _apiClient.get('/api/roles/$id/function-matrix');
    return _parse(
      () => requireJsonList(
        response,
        'function matrix',
      ).map(RoleFunctionMatrixItemResponse.fromJson).toList(growable: false),
    );
  }

  Future<RoleResponse> setRoleFunctions(
    int id,
    SetRoleFunctionsRequest request,
  ) => _sendModel(
    () => _apiClient.put('/api/roles/$id/functions', body: request.toJson()),
    RoleResponse.fromJson,
  );

  Future<RoleResponse> setRoleFunctionActiveKey(
    int id,
    int functionId,
    SetRoleFunctionActiveKeyRequest request,
  ) => _sendModel(
    () => _apiClient.put(
      '/api/roles/$id/functions/$functionId/active-key',
      body: request.toJson(),
    ),
    RoleResponse.fromJson,
  );

  Future<void> deleteRoleFunction(int id, int functionId) async {
    await _apiClient.delete('/api/roles/$id/functions/$functionId');
  }

  Future<void> deleteRole(int id) async {
    await _apiClient.delete('/api/roles/$id');
  }

  Future<List<FunctionResponse>> getFunctions({
    String? search,
    int? status,
  }) async {
    _validateStatus(status);
    final response = await _apiClient.get(
      '/api/functions',
      query: <String, Object?>{
        'search': _normalizedSearch(search),
        'status': status,
      },
    );
    return _parse(() => parseFunctionList(response));
  }

  Future<List<FunctionTreeNodeResponse>> getFunctionTree({
    String? search,
    int? status,
  }) async {
    _validateStatus(status);
    final response = await _apiClient.get(
      '/api/functions/tree',
      query: <String, Object?>{
        'search': _normalizedSearch(search),
        'status': status,
      },
    );
    return _parse(() => parseFunctionTree(response));
  }

  Future<FunctionResponse> getFunction(int id) =>
      _getModel('/api/functions/$id', FunctionResponse.fromJson);

  Future<FunctionResponse> createFunction(CreateFunctionRequest request) =>
      _sendModel(
        () => _apiClient.post('/api/functions', body: request.toJson()),
        FunctionResponse.fromJson,
      );

  Future<FunctionResponse> updateFunction(
    int id,
    UpdateFunctionRequest request,
  ) => _sendModel(
    () => _apiClient.put('/api/functions/$id', body: request.toJson()),
    FunctionResponse.fromJson,
  );

  Future<FunctionResponse> setFunctionStatus(
    int id,
    SetFunctionStatusRequest request,
  ) => _sendModel(
    () => _apiClient.put('/api/functions/$id/status', body: request.toJson()),
    FunctionResponse.fromJson,
  );

  Future<void> deleteFunction(int id) async {
    await _apiClient.delete('/api/functions/$id');
  }

  Future<T> _getModel<T>(String path, T Function(Object? value) parser) =>
      _sendModel(() => _apiClient.get(path), parser);

  Future<T> _sendModel<T>(
    Future<Object?> Function() request,
    T Function(Object? value) parser,
  ) async {
    final response = await request();
    return _parse(() => parser(response));
  }

  T _parse<T>(T Function() parser) {
    try {
      return parser();
    } on FormatException catch (error) {
      throw ApiException.invalidResponse(error.message);
    }
  }

  void _validateStatus(int? status) {
    if (!AccessStatus.isSupported(status)) {
      throw ArgumentError.value(status, 'status', 'Chỉ hỗ trợ 1 hoặc 99.');
    }
  }

  String? _normalizedSearch(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
