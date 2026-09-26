import 'package:flutter/foundation.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/api_request_cancellation.dart';
import '../../../company_management/data/models/company_models.dart';
import '../../../company_management/data/repositories/company_repository.dart';
import '../../data/models/material_report_models.dart';
import '../../data/repositories/material_report_repository.dart';
import '../widgets/material_units.dart';

/// State of "Quản lý vật liệu".
///
/// One report for all materials and all voucher types (page 1) feeds the
/// stock and chart tabs, the material details (its "Xuất tổng" row gives the
/// export of the period per material) and the first vouchers. Switching
/// quantity / value, the chart group and the display units only changes what
/// is shown: the API returns every number at once and takes a few seconds.
/// Only the vouchers tab asks again, for another type or group or page.
class MaterialReportController extends ChangeNotifier {
  MaterialReportController({
    required this.repository,
    required this.companyRepository,
    required this.isAdmin,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    final current = _now();
    from = DateTime(current.year, current.month);
    to = current;
  }

  final MaterialReportRepository repository;
  final CompanyRepository companyRepository;
  final bool isAdmin;
  final DateTime Function() _now;

  final List<CompanyResponse> companies = <CompanyResponse>[];
  final List<MaterialReportStation> stations = <MaterialReportStation>[];

  late DateTime from;
  late DateTime to;
  int? selectedCompanyId;
  int? selectedStationId;

  /// All materials, all voucher types, page 1.
  MaterialReport? report;
  ApiException? scopeError;
  ApiException? reportError;
  String? validationMessage;
  bool isLoadingScope = false;
  bool isLoadingReport = false;
  bool isRefreshing = false;

  // Display only.
  MaterialValueMode valueMode = MaterialValueMode.quantity;
  MaterialGroupFilter chartGroup = MaterialGroupFilter.all;
  final Map<String, MaterialUnit> _units = <String, MaterialUnit>{};

  // Vouchers tab.
  MaterialViewMode voucherType = MaterialViewMode.all;
  MaterialGroupFilter voucherGroup = MaterialGroupFilter.all;
  final List<MaterialTransaction> vouchers = <MaterialTransaction>[];
  int voucherCount = 0;
  int _voucherPage = 0;
  bool isLoadingVouchers = false;
  bool isLoadingMoreVouchers = false;
  ApiException? voucherError;

  var _scopeVersion = 0;
  var _reportVersion = 0;
  var _voucherVersion = 0;
  final _reportRequest = LatestApiRequest();
  final _voucherRequest = LatestApiRequest();
  var _initialized = false;
  var _disposed = false;

  CompanyResponse? get selectedCompany => _firstWhereOrNull(
    companies,
    (company) => company.id == selectedCompanyId,
  );

  MaterialReportStation? get selectedStation =>
      _firstWhereOrNull(stations, (station) => station.id == selectedStationId);

  bool get canViewReport =>
      selectedStationId != null && (!isAdmin || selectedCompanyId != null);

  /// Every material of the station, in the API order (group, then door).
  List<MaterialSummaryItem> get materials => [
    for (final group in report?.groups ?? const <MaterialGroupSummary>[])
      ...group.materials,
  ];

  /// "Xuất tổng trong kỳ": exports of the period per material.
  MaterialTransaction? get summaryExport =>
      _firstWhereOrNull(report?.transactions ?? const [], (t) => t.isSummary);

  MaterialUnit unitFor(String groupCode) =>
      _units[groupCode] ?? MaterialUnit.kg;

  bool get canLoadMoreVouchers =>
      !isLoadingVouchers &&
      !isLoadingMoreVouchers &&
      _voucherPage > 0 &&
      _voucherPage * _pageSize < voucherCount;

  static const _pageSize = 10;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    if (isAdmin) {
      await _loadCompanies();
    } else {
      await _loadStations();
    }
  }

  Future<void> retryScope() async {
    if (isAdmin && selectedCompanyId == null) {
      await _loadCompanies();
      return;
    }
    await _loadStations();
  }

  Future<void> selectCompany(int? companyId) async {
    if (!isAdmin || companyId == selectedCompanyId) return;
    selectedCompanyId = companyId;
    selectedStationId = null;
    stations.clear();
    _clearReport();
    _notify();
    if (companyId != null) await _loadStations();
  }

  void selectStation(int? stationId) {
    if (stationId == selectedStationId) return;
    selectedStationId = stationId;
    _clearReport();
    _notify();
  }

  void setDateRange(DateTime start, DateTime end) {
    if (from == start && to == end) return;
    from = start;
    to = end;
    _clearReport();
    _notify();
  }

  void setValueMode(MaterialValueMode value) {
    if (valueMode == value) return;
    valueMode = value;
    _notify();
  }

  void setChartGroup(MaterialGroupFilter value) {
    if (chartGroup == value) return;
    chartGroup = value;
    _notify();
  }

  void setUnit(String groupCode, MaterialUnit unit) {
    if (unitFor(groupCode) == unit) return;
    _units[groupCode] = unit;
    _notify();
  }

  Future<void> setVoucherFilters({
    MaterialViewMode? type,
    MaterialGroupFilter? group,
  }) async {
    final nextType = type ?? voucherType;
    final nextGroup = group ?? voucherGroup;
    if (nextType == voucherType && nextGroup == voucherGroup) return;
    voucherType = nextType;
    voucherGroup = nextGroup;
    if (report == null) {
      _notify();
      return;
    }
    await _loadVouchers();
  }

  Future<void> loadReport({bool refresh = false}) async {
    final stationId = selectedStationId;
    final companyId = isAdmin ? selectedCompanyId : null;
    if (isAdmin && companyId == null) {
      validationMessage = 'Chọn công ty trước khi xem báo cáo.';
      _notify();
      return;
    }
    if (stationId == null) {
      validationMessage = 'Chọn trạm trộn trước khi xem báo cáo.';
      _notify();
      return;
    }
    if (from.isAfter(to)) {
      validationMessage =
          'Thời gian kết thúc không được trước thời gian bắt đầu.';
      _notify();
      return;
    }

    final version = ++_reportVersion;
    final cancellation = _reportRequest.next();
    validationMessage = null;
    reportError = null;
    if (refresh && report != null) {
      isRefreshing = true;
    } else {
      isLoadingReport = true;
      report = null;
    }
    _notify();
    try {
      final loaded = await repository.getReport(
        _query(
          stationId,
          companyId,
          MaterialViewMode.all,
          MaterialGroupFilter.all,
          1,
        ),
        cancellation: cancellation,
      );
      if (version != _reportVersion || stationId != selectedStationId) return;
      report = loaded;
      isLoadingReport = false;
      isRefreshing = false;
      if (_vouchersFromOverview) {
        // Drops a vouchers request still running for an older filter.
        ++_voucherVersion;
        _voucherRequest.cancel();
        isLoadingVouchers = false;
        isLoadingMoreVouchers = false;
        _takeVouchers(loaded, page: 1, append: false);
        voucherError = null;
      } else {
        _notify();
        await _loadVouchers();
        return;
      }
    } on ApiRequestCancelledException {
      return;
    } on ApiException catch (error) {
      if (version == _reportVersion) reportError = error;
    } finally {
      if (version == _reportVersion) {
        isLoadingReport = false;
        isRefreshing = false;
        _notify();
      }
    }
  }

  Future<void> refresh() => loadReport(refresh: true);

  Future<void> loadMoreVouchers() async {
    if (!canLoadMoreVouchers) return;
    final stationId = selectedStationId!;
    final companyId = isAdmin ? selectedCompanyId : null;
    final version = _voucherVersion;
    final cancellation = _voucherRequest.next();
    final page = _voucherPage + 1;
    isLoadingMoreVouchers = true;
    voucherError = null;
    _notify();
    try {
      final loaded = await repository.getReport(
        _query(stationId, companyId, voucherType, voucherGroup, page),
        cancellation: cancellation,
      );
      if (version != _voucherVersion) return;
      _takeVouchers(loaded, page: page, append: true);
    } on ApiRequestCancelledException {
      return;
    } on ApiException catch (error) {
      if (version == _voucherVersion) voucherError = error;
    } finally {
      if (version == _voucherVersion) {
        isLoadingMoreVouchers = false;
        _notify();
      }
    }
  }

  bool get _vouchersFromOverview =>
      voucherType == MaterialViewMode.all &&
      voucherGroup == MaterialGroupFilter.all;

  Future<void> _loadVouchers() async {
    final version = ++_voucherVersion;
    _voucherRequest.cancel();
    final overview = report;
    if (overview == null) return;
    voucherError = null;
    isLoadingMoreVouchers = false;
    if (_vouchersFromOverview) {
      isLoadingVouchers = false;
      _takeVouchers(overview, page: 1, append: false);
      _notify();
      return;
    }
    final stationId = selectedStationId!;
    final companyId = isAdmin ? selectedCompanyId : null;
    isLoadingVouchers = true;
    vouchers.clear();
    voucherCount = 0;
    _voucherPage = 0;
    _notify();
    final cancellation = _voucherRequest.next();
    try {
      final loaded = await repository.getReport(
        _query(stationId, companyId, voucherType, voucherGroup, 1),
        cancellation: cancellation,
      );
      if (version != _voucherVersion) return;
      _takeVouchers(loaded, page: 1, append: false);
    } on ApiRequestCancelledException {
      return;
    } on ApiException catch (error) {
      if (version == _voucherVersion) voucherError = error;
    } finally {
      if (version == _voucherVersion) {
        isLoadingVouchers = false;
        _notify();
      }
    }
  }

  /// The "Xuất tổng" row rides along on every page of all/all; it is shown
  /// on its own, so it is neither a voucher nor counted as one.
  void _takeVouchers(
    MaterialReport data, {
    required int page,
    required bool append,
  }) {
    final rows = data.transactions.where((item) => !item.isSummary);
    final hasSummary = data.transactions.any((item) => item.isSummary);
    if (!append) vouchers.clear();
    vouchers.addAll(rows);
    voucherCount = data.totalCount - (hasSummary ? 1 : 0);
    _voucherPage = page;
  }

  MaterialReportQuery _query(
    int stationId,
    int? companyId,
    MaterialViewMode type,
    MaterialGroupFilter group,
    int page,
  ) => MaterialReportQuery(
    branchId: stationId,
    companyId: companyId,
    from: from,
    to: to,
    materialGroup: group,
    viewMode: type,
    valueMode: MaterialValueMode.quantity,
    pageNumber: page,
  );

  Future<void> _loadCompanies() async {
    final version = ++_scopeVersion;
    isLoadingScope = true;
    scopeError = null;
    _notify();
    try {
      final loaded = <CompanyResponse>[];
      var pageNumber = 1;
      var totalPages = 1;
      do {
        final page = await companyRepository.getCompanies(
          pageNumber: pageNumber,
          pageSize: 100,
          status: CompanyDataStatus.active,
        );
        loaded.addAll(page.items);
        totalPages = page.totalPages;
        pageNumber++;
      } while (pageNumber <= totalPages);
      if (version != _scopeVersion) return;
      companies
        ..clear()
        ..addAll(loaded);
    } on ApiException catch (error) {
      if (version == _scopeVersion) scopeError = error;
    } finally {
      if (version == _scopeVersion) {
        isLoadingScope = false;
        _notify();
      }
    }
  }

  Future<void> _loadStations() async {
    final companyId = isAdmin ? selectedCompanyId : null;
    if (isAdmin && companyId == null) return;
    final version = ++_scopeVersion;
    isLoadingScope = true;
    scopeError = null;
    stations.clear();
    selectedStationId = null;
    _clearReport();
    _notify();
    try {
      final loaded = await repository.getStations(companyId: companyId);
      if (version != _scopeVersion ||
          companyId != (isAdmin ? selectedCompanyId : null)) {
        return;
      }
      stations.addAll(loaded);
    } on ApiException catch (error) {
      if (version == _scopeVersion) scopeError = error;
    } finally {
      if (version == _scopeVersion) {
        isLoadingScope = false;
        _notify();
      }
    }
  }

  void _clearReport() {
    ++_reportVersion;
    ++_voucherVersion;
    _reportRequest.cancel();
    _voucherRequest.cancel();
    report = null;
    reportError = null;
    validationMessage = null;
    isLoadingReport = false;
    isRefreshing = false;
    vouchers.clear();
    voucherCount = 0;
    _voucherPage = 0;
    isLoadingVouchers = false;
    isLoadingMoreVouchers = false;
    voucherError = null;
  }

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
    _reportRequest.cancel();
    _voucherRequest.cancel();
    super.dispose();
  }
}
