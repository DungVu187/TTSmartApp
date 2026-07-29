import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/models/data_scope.dart';
import '../../../../core/models/time_range_preset.dart';
import '../../data/models/order_models.dart';
import '../../data/repositories/orders_repository.dart';

class OrdersController extends ChangeNotifier {
  OrdersController(this._repository);

  final OrdersRepository _repository;

  List<DataScopeOption> _scopes = const <DataScopeOption>[];
  DataScopeOption? _selectedScope;
  TimeRangePreset _timeRange = TimeRangePreset.today;
  OrderStatus? _status;
  String _searchText = '';
  List<OrderSummary> _orders = const <OrderSummary>[];
  String? _errorMessage;
  bool _isLoading = false;
  bool _initialized = false;
  Timer? _searchDebounce;
  int _requestVersion = 0;

  List<DataScopeOption> get scopes => _scopes;
  DataScopeOption? get selectedScope => _selectedScope;
  TimeRangePreset get timeRange => _timeRange;
  OrderStatus? get status => _status;
  String get searchText => _searchText;
  List<OrderSummary> get orders => _orders;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  int get activeFilterCount =>
      (_status == null ? 0 : 1) +
      (_timeRange == TimeRangePreset.today ? 0 : 1) +
      (_selectedScope?.type == DataScopeType.station ? 1 : 0);

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _isLoading = true;
    notifyListeners();
    try {
      _scopes = await _repository.getAvailableScopes();
      if (_scopes.isEmpty) {
        _errorMessage = 'Tài khoản chưa được cấp phạm vi đơn hàng.';
        return;
      }
      _selectedScope = _scopes.first;
      await _loadOrders();
    } catch (_) {
      _errorMessage = 'Không thể tải danh sách đơn hàng.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void updateSearch(String value) {
    _searchText = value;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), refresh);
  }

  Future<void> applyFilters({
    required DataScopeOption scope,
    required TimeRangePreset timeRange,
    required OrderStatus? status,
  }) async {
    _selectedScope = scope;
    _timeRange = timeRange;
    _status = status;
    await refresh();
  }

  Future<void> clearFilters() async {
    if (_scopes.isEmpty) return;
    _selectedScope = _scopes.first;
    _timeRange = TimeRangePreset.today;
    _status = null;
    await refresh();
  }

  Future<void> refresh() async {
    if (_selectedScope == null) return;
    final version = ++_requestVersion;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final result = await _repository.searchOrders(_query());
      if (version != _requestVersion) return;
      _orders = result;
    } catch (_) {
      if (version == _requestVersion) {
        _errorMessage = 'Không thể cập nhật đơn hàng. Vui lòng thử lại.';
      }
    } finally {
      if (version == _requestVersion) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<OrderDetails> getDetails(String id) => _repository.getOrderDetails(id);

  OrdersQuery _query() => OrdersQuery(
    searchText: _searchText,
    scope: _selectedScope!,
    timeRange: _timeRange,
    status: _status,
  );

  Future<void> _loadOrders() async {
    _orders = await _repository.searchOrders(_query());
    _errorMessage = null;
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }
}
