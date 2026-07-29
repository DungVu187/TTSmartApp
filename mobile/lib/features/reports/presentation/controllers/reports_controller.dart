import 'package:flutter/foundation.dart';

import '../../../../core/models/data_scope.dart';
import '../../../../core/models/time_range_preset.dart';
import '../../data/models/report_models.dart';
import '../../data/repositories/reports_repository.dart';

class ReportsController extends ChangeNotifier {
  ReportsController(this._repository);

  final ReportsRepository _repository;

  List<DataScopeOption> _scopes = const <DataScopeOption>[];
  DataScopeOption? _selectedScope;
  TimeRangePreset _timeRange = TimeRangePreset.sevenDays;
  ReportSnapshot? _snapshot;
  String? _errorMessage;
  bool _isLoading = false;
  bool _initialized = false;

  List<DataScopeOption> get scopes => _scopes;
  DataScopeOption? get selectedScope => _selectedScope;
  TimeRangePreset get timeRange => _timeRange;
  ReportSnapshot? get snapshot => _snapshot;
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
        _errorMessage = 'Tài khoản chưa được cấp phạm vi báo cáo.';
        return;
      }
      _selectedScope = _scopes.first;
      await _load();
    } catch (_) {
      _errorMessage = 'Không thể tải báo cáo.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateFilters({
    required DataScopeOption scope,
    required TimeRangePreset timeRange,
  }) async {
    _selectedScope = scope;
    _timeRange = timeRange;
    await refresh();
  }

  Future<void> refresh() async {
    if (_selectedScope == null || _isLoading) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _load();
    } catch (_) {
      _errorMessage = 'Không thể cập nhật báo cáo. Vui lòng thử lại.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _load() async {
    _snapshot = await _repository.getReport(
      scope: _selectedScope!,
      timeRange: _timeRange,
    );
    _errorMessage = null;
  }
}
