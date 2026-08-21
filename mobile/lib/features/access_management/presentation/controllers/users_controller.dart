import 'package:flutter/foundation.dart';

import '../../../../core/network/api_exception.dart';
import '../../data/models/user_models.dart';
import '../../data/models/role_models.dart';
import '../../data/repositories/access_management_repository.dart';

class UsersController extends ChangeNotifier {
  UsersController(this.repository);

  final AccessManagementRepository repository;

  final List<UserResponse> items = <UserResponse>[];
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
  int? roleId;
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
      final page = await repository.getUsers(
        pageNumber: 1,
        search: search,
        status: status,
        roleId: roleId,
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
      final page = await repository.getUsers(
        pageNumber: pageNumber + 1,
        search: search,
        status: status,
        roleId: roleId,
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

  void setRoleId(int? value) => roleId = value;

  Future<UserResponse> getById(int id) => repository.getUser(id);

  Future<List<RoleListItemResponse>> getAvailableRoles() =>
      repository.getAssignableRoles();

  Future<UserResponse> create(CreateUserRequest request) =>
      repository.createUser(request);

  Future<UserResponse> update(int id, UpdateUserRequest request) =>
      repository.updateUser(id, request);

  Future<UserResponse> setActive(int id, bool isActive) =>
      repository.setUserStatus(id, SetUserStatusRequest(isActive: isActive));

  Future<UserResponse> setRoles(int id, List<int> roleIds) =>
      repository.setUserRoles(id, SetUserRolesRequest(roleIds: roleIds));

  Future<void> resetPassword(int id) =>
      repository.resetUserPassword(id, const ResetPasswordRequest());

  Future<void> delete(int id) => repository.deleteUser(id);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
