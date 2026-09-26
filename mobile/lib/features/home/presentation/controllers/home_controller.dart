import 'package:flutter/foundation.dart';

import '../../../../core/models/data_scope.dart';
import '../../../../core/models/time_range_preset.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/api_request_cancellation.dart';
import '../../data/models/dashboard_models.dart';
import '../../data/repositories/home_repository.dart';

class HomeController extends ChangeNotifier {
  HomeController(this._repository);

  final HomeRepository _repository;

  List<DashboardScope> _scopes = const <DashboardScope>[];
  DashboardScope? _selectedCompany;
  DashboardScope? _selectedStation;
  TimeRangePreset _timeRange = TimeRangePreset.today;
  DashboardSnapshot? _snapshot;
  String? _errorMessage;
  bool _isLoading = false;
  bool _initialized = false;
  bool _disposed = false;
  int _loadVersion = 0;
  final _dashboardRequest = LatestApiRequest();

  List<DashboardScope> get scopes => _scopes;
  List<DashboardScope> get companyScopes => _scopes
      .where((scope) => scope.type == DataScopeType.company)
      .toList(growable: false);
  List<DashboardScope> get stationScopes {
    final companyId = _selectedCompany?.companyId;
    return _scopes
        .where(
          (scope) =>
              scope.type == DataScopeType.station &&
              (companyId == null || scope.companyId == companyId),
        )
        .toList(growable: false);
  }

  DashboardScope? get selectedCompany => _selectedCompany;
  DashboardScope? get selectedStation => _selectedStation;
  DashboardScope? get selectedScope => _selectedStation ?? _selectedCompany;
  TimeRangePreset get timeRange => _timeRange;
  DashboardSnapshot? get snapshot => _snapshot;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    final version = ++_loadVersion;
    _isLoading = true;
    _errorMessage = null;
    _notify();
    try {
      _scopes = await _repository.getAvailableScopes();
      if (_scopes.isEmpty) {
        _errorMessage = 'Tài khoản chưa được cấp phạm vi dữ liệu.';
        return;
      }
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return;
    } catch (_) {
      _errorMessage = 'Không thể tải dữ liệu tổng quan. Vui lòng thử lại.';
      return;
    } finally {
      if (version == _loadVersion && _errorMessage != null) {
        _isLoading = false;
        _notify();
      }
    }
    if (version != _loadVersion) return;
    await _reload('Không thể tải dữ liệu tổng quan. Vui lòng thử lại.');
  }

  /// Pull to refresh: joins the load already running.
  Future<void> refresh() async {
    if (_isLoading) return;
    await _reload('Không thể cập nhật dữ liệu. Vui lòng thử lại.');
  }

  Future<void> selectCompany(DashboardScope company) async {
    if (company.type != DataScopeType.company) {
      throw ArgumentError.value(company, 'company', 'Phạm vi phải là công ty.');
    }
    if (_selectedCompany?.keyName == company.keyName &&
        _selectedStation == null) {
      return;
    }
    _selectedCompany = company;
    _selectedStation = null;
    await _reloadForNewScope();
  }

  Future<void> clearCompany() async {
    if (_selectedCompany == null && _selectedStation == null) return;
    _selectedCompany = null;
    _selectedStation = null;
    await _reloadForNewScope();
  }

  Future<void> selectStation(DashboardScope station) async {
    if (station.type != DataScopeType.station) {
      throw ArgumentError.value(station, 'station', 'Phạm vi phải là trạm.');
    }
    if (_selectedStation?.keyName == station.keyName) return;
    _selectedCompany = _findCompany(station.companyId);
    _selectedStation = station;
    await _reloadForNewScope();
  }

  Future<void> clearStation() async {
    if (_selectedStation == null) return;
    _selectedStation = null;
    await _reloadForNewScope();
  }

  Future<void> selectTimeRange(TimeRangePreset value) async {
    if (_timeRange == value) return;
    _timeRange = value;
    await _reloadForNewScope();
  }

  Future<void> retry() async {
    if (_isLoading) return;
    if (_scopes.isNotEmpty) {
      await refresh();
      return;
    }

    _initialized = false;
    await initialize();
  }

  /// A new station, company or time range replaces the load in progress:
  /// the old answer would not match what is selected.
  Future<void> _reloadForNewScope() async {
    if (_scopes.isEmpty) return;
    await _reload('Không thể cập nhật dữ liệu. Vui lòng thử lại.');
  }

  Future<void> _reload(String fallbackMessage) async {
    final version = ++_loadVersion;
    final cancellation = _dashboardRequest.next();
    _isLoading = true;
    _errorMessage = null;
    _notify();
    try {
      final snapshot = await _repository.getDashboard(
        scope: selectedScope,
        timeRange: _timeRange,
        cancellation: cancellation,
      );
      if (version != _loadVersion) return;
      _snapshot = snapshot;
    } on ApiRequestCancelledException {
      return;
    } on ApiException catch (error) {
      if (version == _loadVersion) _errorMessage = error.message;
    } catch (_) {
      if (version == _loadVersion) _errorMessage = fallbackMessage;
    } finally {
      if (version == _loadVersion) {
        _isLoading = false;
        _notify();
      }
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _dashboardRequest.cancel();
    super.dispose();
  }

  DashboardScope? _findCompany(int? companyId) {
    if (companyId == null) return null;
    for (final company in companyScopes) {
      if (company.companyId == companyId) return company;
    }
    return null;
  }
}
