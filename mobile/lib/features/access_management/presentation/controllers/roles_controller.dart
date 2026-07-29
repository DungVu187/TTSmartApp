import 'package:flutter/foundation.dart';

import '../../../../core/network/api_exception.dart';
import '../../data/models/role_models.dart';
import '../../data/repositories/access_management_repository.dart';

class RolesController extends ChangeNotifier {
  RolesController(this.repository);

  final AccessManagementRepository repository;

  final List<RoleListItemResponse> items = <RoleListItemResponse>[];
  ApiException? error;
  ApiException? loadMoreError;
  bool isLoading = false;
  bool isRefreshing = false;
  bool isLoadingMore = false;
  int pageNumber = 1;
  int totalPages = 0;
  int totalCount = 0;
  String search = '';
  int? status;
  int _requestVersion = 0;
  bool _disposed = false;

  bool get canLoadMore => pageNumber < totalPages;

  Future<void> load() async {
    final requestVersion = ++_requestVersion;
    error = null;
    loadMoreError = null;
    if (items.isEmpty) {
      isLoading = true;
    } else {
      isRefreshing = true;
    }
    _notify();
    try {
      final page = await repository.getRoles(
        pageNumber: 1,
        search: search,
        status: status,
      );
      if (requestVersion != _requestVersion) return;
      items
        ..clear()
        ..addAll(page.items);
      pageNumber = page.pageNumber;
      totalPages = page.totalPages;
      totalCount = page.totalCount;
    } on ApiException catch (caught) {
      if (requestVersion == _requestVersion) error = caught;
    } finally {
      if (requestVersion == _requestVersion) {
        isLoading = false;
        isRefreshing = false;
        _notify();
      }
    }
  }

  Future<void> loadMore() async {
    if (!canLoadMore || isLoadingMore || isLoading || isRefreshing) return;
    final requestVersion = _requestVersion;
    isLoadingMore = true;
    loadMoreError = null;
    _notify();
    try {
      final page = await repository.getRoles(
        pageNumber: pageNumber + 1,
        search: search,
        status: status,
      );
      if (requestVersion != _requestVersion) return;
      final existingIds = items.map((item) => item.id).toSet();
      items.addAll(page.items.where((item) => existingIds.add(item.id)));
      pageNumber = page.pageNumber;
      totalPages = page.totalPages;
      totalCount = page.totalCount;
    } on ApiException catch (caught) {
      if (requestVersion == _requestVersion) loadMoreError = caught;
    } finally {
      if (requestVersion == _requestVersion) {
        isLoadingMore = false;
        _notify();
      }
    }
  }

  void setSearch(String value) => search = value;

  void setStatus(int? value) => status = value;

  Future<RoleResponse> getById(int id) => repository.getRole(id);

  Future<RoleResponse> create(CreateRoleRequest request) =>
      repository.createRole(request);

  Future<RoleResponse> update(int id, UpdateRoleRequest request) =>
      repository.updateRole(id, request);

  Future<RoleResponse> setActive(int id, bool isActive) =>
      repository.setRoleStatus(id, SetRoleStatusRequest(isActive: isActive));

  Future<List<RoleFunctionMatrixItemResponse>> getFunctionMatrix(int id) =>
      repository.getRoleFunctionMatrix(id);

  Future<RoleResponse> setFunctions(
    int id,
    Iterable<RoleFunctionMatrixItemResponse> items,
  ) => repository.setRoleFunctions(
    id,
    SetRoleFunctionsRequest(
      functions: items
          .where((item) => item.isAssigned)
          .map(
            (item) => RoleFunctionAssignmentRequest.fromPermissions(
              functionId: item.functionId,
              permissions: item.permissions,
            ),
          )
          .toList(growable: false),
    ),
  );

  Future<RoleResponse> setFunctionActiveKey(
    int id,
    int functionId,
    String activeKey,
  ) => repository.setRoleFunctionActiveKey(
    id,
    functionId,
    SetRoleFunctionActiveKeyRequest(activeKey: activeKey),
  );

  Future<void> deleteFunction(int id, int functionId) =>
      repository.deleteRoleFunction(id, functionId);

  Future<void> delete(int id) => repository.deleteRole(id);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
