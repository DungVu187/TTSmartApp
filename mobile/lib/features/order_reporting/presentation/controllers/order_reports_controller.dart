import 'package:flutter/foundation.dart';

import '../../../../core/network/api_exception.dart';
import '../../../company_management/data/models/company_models.dart';
import '../../../company_management/data/repositories/company_repository.dart';
import '../../data/models/order_report_models.dart';
import '../../data/repositories/order_report_repository.dart';

class OrderReportsController extends ChangeNotifier {
  OrderReportsController({
    required this.repository,
    required this.companyRepository,
    required this.isAdmin,
    this.initialCompanyId,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    final now = _now();
    fromDate = _dateOnly(now);
    toDate = now;
  }

  final OrderReportRepository repository;
  final CompanyRepository companyRepository;
  final bool isAdmin;
  final int? initialCompanyId;
  final DateTime Function() _now;

  final List<CompanyResponse> companies = <CompanyResponse>[];
  final List<OrderReportStation> stations = <OrderReportStation>[];
  final List<OrderReportEmployee> employees = <OrderReportEmployee>[];
  final List<OrderReportItem> items = <OrderReportItem>[];
  final List<OrderReportStationSummary> stationSummaries =
      <OrderReportStationSummary>[];
  final List<OrderReportUnavailableStation> unavailableStations =
      <OrderReportUnavailableStation>[];

  late DateTime fromDate;
  late DateTime toDate;
  int? selectedCompanyId;
  int? selectedStationId;
  String? selectedEmployeeName;

  bool isLoadingScope = false;
  bool isLoadingEmployees = false;
  bool isLoadingReport = false;
  bool isRefreshing = false;
  bool isLoadingMore = false;
  bool hasLoadedReport = false;
  ApiException? scopeError;
  ApiException? employeeError;
  ApiException? reportError;
  ApiException? loadMoreError;
  String? validationMessage;

  int pageNumber = 1;
  int pageSize = 10;
  int totalCount = 0;
  int totalPages = 0;
  double totalOrderedVolume = 0;
  double totalProducedVolume = 0;
  bool isPartial = false;
  int successfulStationCount = 0;
  int unavailableStationCount = 0;

  int _scopeRequestVersion = 0;
  int _employeeRequestVersion = 0;
  int _reportRequestVersion = 0;
  bool _initialized = false;
  bool _disposed = false;

  bool get canLoadMore => pageNumber < totalPages;

  bool get canSearch => isAdmin || selectedStationId != null;

  OrderReportStation? get selectedStation =>
      _firstWhereOrNull(stations, (station) => station.id == selectedStationId);

  CompanyResponse? get selectedCompany => _firstWhereOrNull(
    companies,
    (company) => company.id == selectedCompanyId,
  );

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    if (isAdmin) {
      await _loadCompanies();
    }
    await _loadStations();
  }

  Future<void> retryScope() async {
    if (isAdmin && companies.isEmpty) {
      await _loadCompanies();
    }
    await _loadStations();
  }

  Future<void> selectCompany(int? companyId) async {
    if (!isAdmin || selectedCompanyId == companyId) return;
    selectedCompanyId = companyId;
    selectedStationId = null;
    _clearStationData();
    _notify();
    await _loadStations();
  }

  Future<void> selectStation(int? branchId) async {
    if (selectedStationId == branchId) return;
    if (!isAdmin && branchId == null) return;
    selectedStationId = branchId;
    _clearStationData();
    _notify();
    if (branchId != null) await _loadEmployees();
  }

  Future<void> setDateRange(DateTimeRangeValue range) async {
    final nextFromDate = range.start;
    final nextToDate = range.end;
    if (fromDate == nextFromDate && toDate == nextToDate) return;
    fromDate = nextFromDate;
    toDate = nextToDate;
    _clearStationData();
    _notify();
    if (selectedStationId != null) await _loadEmployees();
  }

  void setEmployeeName(String? value) {
    final normalized = value?.trim();
    final nextEmployeeName = normalized == null || normalized.isEmpty
        ? null
        : normalized;
    if (selectedEmployeeName == nextEmployeeName) return;
    selectedEmployeeName = nextEmployeeName;
    _clearReport();
    _notify();
  }

  Future<void> loadReport() => _loadFirstPage(refreshing: items.isNotEmpty);

  Future<void> refresh() async {
    if (selectedStationId == null) return;
    await _loadEmployees(preserveSelection: true);
  }

  Future<void> resetFilters() async {
    final now = _now();
    fromDate = _dateOnly(now);
    toDate = now;

    if (isAdmin) {
      selectedCompanyId = null;
      selectedStationId = null;
      _clearStationData();
      _notify();
      await _loadStations();
      return;
    }

    selectedEmployeeName = null;
    _clearReport();
    _notify();
    if (selectedStationId != null) await _loadEmployees();
  }

  Future<void> loadMore() async {
    if (!canLoadMore ||
        isLoadingMore ||
        isLoadingReport ||
        isRefreshing ||
        !canSearch) {
      return;
    }
    final requestVersion = _reportRequestVersion;
    isLoadingMore = true;
    loadMoreError = null;
    _notify();
    try {
      final page = await repository.search(_query(pageNumber + 1));
      if (requestVersion != _reportRequestVersion) return;
      final existingIds = items.map(_itemKey).toSet();
      items.addAll(page.items.where((item) => existingIds.add(_itemKey(item))));
      _applyPageMetadata(page);
    } on ApiException catch (caught) {
      if (requestVersion == _reportRequestVersion) loadMoreError = caught;
    } finally {
      if (requestVersion == _reportRequestVersion) {
        isLoadingMore = false;
        _notify();
      }
    }
  }

  Future<void> _loadCompanies() async {
    final requestVersion = ++_scopeRequestVersion;
    isLoadingScope = true;
    scopeError = null;
    _notify();
    try {
      final loaded = <CompanyResponse>[];
      var nextPage = 1;
      var totalPages = 1;
      do {
        final page = await companyRepository.getCompanies(
          pageNumber: nextPage,
          pageSize: 100,
          status: CompanyDataStatus.active,
        );
        loaded.addAll(page.items);
        totalPages = page.totalPages;
        nextPage++;
      } while (nextPage <= totalPages);
      if (requestVersion != _scopeRequestVersion) return;
      companies
        ..clear()
        ..addAll(loaded);
      selectedCompanyId = _preferredId(
        loaded.map((company) => company.id),
        initialCompanyId,
      );
    } on ApiException catch (caught) {
      if (requestVersion == _scopeRequestVersion) scopeError = caught;
    } finally {
      if (requestVersion == _scopeRequestVersion) {
        isLoadingScope = false;
        _notify();
      }
    }
  }

  Future<void> _loadStations() async {
    final requestVersion = ++_scopeRequestVersion;
    isLoadingScope = true;
    scopeError = null;
    stations.clear();
    selectedStationId = null;
    _clearStationData();
    _notify();
    try {
      final loaded = await repository.getStations(
        companyId: isAdmin ? selectedCompanyId : null,
      );
      if (requestVersion != _scopeRequestVersion) return;
      stations.addAll(loaded);
    } on ApiException catch (caught) {
      if (requestVersion == _scopeRequestVersion) scopeError = caught;
    } finally {
      if (requestVersion == _scopeRequestVersion) {
        isLoadingScope = false;
        _notify();
      }
    }
  }

  Future<void> _loadEmployees({bool preserveSelection = false}) async {
    final branchId = selectedStationId;
    final companyId = isAdmin ? selectedCompanyId : null;
    final requestedFromDate = fromDate;
    final requestedToDate = toDate;
    if (branchId == null) return;
    final requestVersion = ++_employeeRequestVersion;
    isLoadingEmployees = true;
    employeeError = null;
    _notify();
    try {
      final loaded = await repository.getEmployees(
        branchId: branchId,
        companyId: companyId,
        fromDate: requestedFromDate,
        toDate: requestedToDate,
      );
      if (requestVersion != _employeeRequestVersion ||
          branchId != selectedStationId ||
          companyId != (isAdmin ? selectedCompanyId : null) ||
          requestedFromDate != fromDate ||
          requestedToDate != toDate) {
        return;
      }
      employees
        ..clear()
        ..addAll(loaded);
      final previousEmployeeName = selectedEmployeeName;
      if (!preserveSelection ||
          !loaded.any((employee) => employee.name == selectedEmployeeName)) {
        selectedEmployeeName = null;
      }
      if (previousEmployeeName != selectedEmployeeName) _clearReport();
    } on ApiException catch (caught) {
      if (requestVersion == _employeeRequestVersion) employeeError = caught;
    } finally {
      if (requestVersion == _employeeRequestVersion) {
        isLoadingEmployees = false;
        _notify();
      }
    }
  }

  Future<void> _loadFirstPage({required bool refreshing}) async {
    final branchId = selectedStationId;
    final companyId = isAdmin ? selectedCompanyId : null;
    if (!isAdmin && branchId == null) {
      validationMessage = 'Chọn trạm trước khi xem đơn hàng.';
      _notify();
      return;
    }
    if (!fromDate.isBefore(toDate)) {
      validationMessage =
          'Thời gian kết thúc phải từ thời gian bắt đầu trở đi.';
      _notify();
      return;
    }
    final requestVersion = ++_reportRequestVersion;
    validationMessage = null;
    reportError = null;
    loadMoreError = null;
    if (refreshing) {
      isRefreshing = true;
    } else {
      isLoadingReport = true;
      items.clear();
    }
    _notify();
    try {
      final page = await repository.search(_query(1));
      if (requestVersion != _reportRequestVersion ||
          branchId != selectedStationId ||
          (isAdmin ? selectedCompanyId : null) != companyId) {
        return;
      }
      items
        ..clear()
        ..addAll(page.items);
      _applyPageMetadata(page);
      hasLoadedReport = true;
    } on ApiException catch (caught) {
      if (requestVersion == _reportRequestVersion) reportError = caught;
    } finally {
      if (requestVersion == _reportRequestVersion) {
        isLoadingReport = false;
        isRefreshing = false;
        _notify();
      }
    }
  }

  OrderReportQuery _query(int requestedPage) => OrderReportQuery(
    branchId: selectedStationId,
    companyId: isAdmin ? selectedCompanyId : null,
    fromDate: fromDate,
    toDate: toDate,
    employeeName: selectedEmployeeName,
    pageNumber: requestedPage,
    pageSize: pageSize,
  );

  void _applyPageMetadata(OrderReportPage page) {
    pageNumber = page.pageNumber;
    pageSize = page.pageSize;
    totalCount = page.totalCount;
    totalPages = page.totalPages;
    totalOrderedVolume = page.totalOrderedVolume;
    totalProducedVolume = page.totalProducedVolume;
    stationSummaries
      ..clear()
      ..addAll(page.stationSummaries);
    isPartial = page.isPartial;
    successfulStationCount = page.successfulStationCount;
    unavailableStationCount = page.unavailableStationCount;
    unavailableStations
      ..clear()
      ..addAll(page.unavailableStations);
  }

  void _clearStationData() {
    ++_employeeRequestVersion;
    employees.clear();
    selectedEmployeeName = null;
    employeeError = null;
    isLoadingEmployees = false;
    _clearReport();
  }

  void _clearReport() {
    ++_reportRequestVersion;
    items.clear();
    stationSummaries.clear();
    unavailableStations.clear();
    pageNumber = 1;
    totalCount = 0;
    totalPages = 0;
    totalOrderedVolume = 0;
    totalProducedVolume = 0;
    isPartial = false;
    successfulStationCount = 0;
    unavailableStationCount = 0;
    hasLoadedReport = false;
    reportError = null;
    loadMoreError = null;
    validationMessage = null;
    isLoadingReport = false;
    isRefreshing = false;
    isLoadingMore = false;
  }

  int? _preferredId(Iterable<int> values, int? preferred) {
    final ids = values.toList(growable: false);
    if (preferred != null && ids.contains(preferred)) return preferred;
    return ids.length == 1 ? ids.single : null;
  }

  String _itemKey(OrderReportItem item) => '${item.branchId}:${item.orderId}';

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  T? _firstWhereOrNull<T>(Iterable<T> values, bool Function(T) test) {
    for (final value in values) {
      if (test(value)) return value;
    }
    return null;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class DateTimeRangeValue {
  const DateTimeRangeValue({required this.start, required this.end});

  final DateTime start;
  final DateTime end;
}
