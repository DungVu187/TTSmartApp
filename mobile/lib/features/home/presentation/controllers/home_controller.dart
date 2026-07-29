import 'package:flutter/foundation.dart';

import '../../../../core/models/data_scope.dart';
import '../../../../core/models/time_range_preset.dart';
import '../../data/models/dashboard_models.dart';
import '../../data/repositories/home_repository.dart';

class HomeController extends ChangeNotifier {
  HomeController(this._repository);

  final HomeRepository _repository;

  List<DataScopeOption> _scopes = const <DataScopeOption>[];
  DataScopeOption? _selectedScope;
  TimeRangePreset _timeRange = TimeRangePreset.today;
  DashboardSnapshot? _snapshot;
  String? _errorMessage;
  bool _isLoading = false;
  bool _initialized = false;

  List<DataScopeOption> get scopes => _scopes;
  DataScopeOption? get selectedScope => _selectedScope;
  TimeRangePreset get timeRange => _timeRange;
  DashboardSnapshot? get snapshot => _snapshot;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _isLoading = true;
    notifyListeners();
    try {
      _scopes = await _repository.getAvailableScopes();
      if (_scopes.isEmpty) {
        _errorMessage = 'Tài khoản chưa được cấp phạm vi dữ liệu.';
        return;
      }
      _selectedScope = _scopes.first;
      await _loadDashboard();
    } catch (_) {
      _errorMessage = 'Không thể tải dữ liệu tổng quan. Vui lòng thử lại.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    if (_selectedScope == null || _isLoading) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _loadDashboard();
    } catch (_) {
      _errorMessage = 'Không thể cập nhật dữ liệu. Vui lòng thử lại.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectScope(DataScopeOption scope) async {
    if (_selectedScope?.keyName == scope.keyName) return;
    _selectedScope = scope;
    await refresh();
  }

  Future<void> selectTimeRange(TimeRangePreset value) async {
    if (_timeRange == value) return;
    _timeRange = value;
    await refresh();
  }

  Future<void> _loadDashboard() async {
    final scope = _selectedScope;
    if (scope == null) return;
    _snapshot = await _repository.getDashboard(
      scope: scope,
      timeRange: _timeRange,
    );
    _errorMessage = null;
  }
}
