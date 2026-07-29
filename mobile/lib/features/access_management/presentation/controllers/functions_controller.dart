import 'package:flutter/foundation.dart';

import '../../../../core/network/api_exception.dart';
import '../../data/models/function_models.dart';
import '../../data/repositories/access_management_repository.dart';

class FunctionsController extends ChangeNotifier {
  FunctionsController(this.repository);

  final AccessManagementRepository repository;

  List<FunctionTreeNodeResponse> items = const <FunctionTreeNodeResponse>[];
  ApiException? error;
  bool isLoading = false;
  bool isRefreshing = false;
  String search = '';
  int? status;
  int _requestVersion = 0;
  bool _disposed = false;

  Future<void> load() async {
    final requestVersion = ++_requestVersion;
    error = null;
    if (items.isEmpty) {
      isLoading = true;
    } else {
      isRefreshing = true;
    }
    _notify();
    try {
      final result = await repository.getFunctionTree(
        search: search,
        status: status,
      );
      if (requestVersion != _requestVersion) return;
      items = result;
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

  void setSearch(String value) => search = value;

  void setStatus(int? value) => status = value;

  Future<List<FunctionResponse>> getAll({int? status}) =>
      repository.getFunctions(status: status);

  Future<List<FunctionTreeNodeResponse>> getTree({int? status}) =>
      repository.getFunctionTree(status: status);

  Future<FunctionResponse> getById(int id) => repository.getFunction(id);

  Future<FunctionResponse> create(CreateFunctionRequest request) =>
      repository.createFunction(request);

  Future<FunctionResponse> update(int id, UpdateFunctionRequest request) =>
      repository.updateFunction(id, request);

  Future<FunctionResponse> setActive(int id, bool isActive) => repository
      .setFunctionStatus(id, SetFunctionStatusRequest(isActive: isActive));

  Future<void> delete(int id) => repository.deleteFunction(id);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
