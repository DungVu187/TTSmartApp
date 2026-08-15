import 'package:flutter/foundation.dart';

import '../../../../core/network/api_exception.dart';
import '../../../company_management/data/models/company_models.dart';
import '../../../company_management/data/repositories/company_repository.dart';
import '../../data/models/material_report_models.dart';
import '../../data/repositories/material_report_repository.dart';

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
  MaterialGroupFilter materialGroup = MaterialGroupFilter.all;
  MaterialViewMode viewMode = MaterialViewMode.all;
  MaterialValueMode valueMode = MaterialValueMode.quantity;
  MaterialReport? report;
  ApiException? scopeError;
  ApiException? reportError;
  String? validationMessage;
  bool isLoadingScope = false;
  bool isLoadingReport = false;
  bool isRefreshing = false;

  var _scopeVersion = 0;
  var _reportVersion = 0;
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

  void setMaterialGroup(MaterialGroupFilter value) {
    if (materialGroup == value) return;
    materialGroup = value;
    _clearReport();
    _notify();
  }

  void setViewMode(MaterialViewMode value) {
    if (viewMode == value) return;
    viewMode = value;
    _clearReport();
    _notify();
  }

  void setValueMode(MaterialValueMode value) {
    if (valueMode == value) return;
    valueMode = value;
    _clearReport();
    _notify();
  }

  Future<void> loadReport({int pageNumber = 1, bool refresh = false}) async {
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
    validationMessage = null;
    reportError = null;
    if ((refresh || pageNumber != 1) && report != null) {
      isRefreshing = true;
    } else {
      isLoadingReport = true;
      if (pageNumber == 1) report = null;
    }
    _notify();
    try {
      final loaded = await repository.getReport(
        MaterialReportQuery(
          branchId: stationId,
          companyId: companyId,
          from: from,
          to: to,
          materialGroup: materialGroup,
          viewMode: viewMode,
          valueMode: valueMode,
          pageNumber: pageNumber,
        ),
      );
      if (version != _reportVersion || stationId != selectedStationId) return;
      report = loaded;
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

  Future<void> refresh() =>
      loadReport(pageNumber: report?.pageNumber ?? 1, refresh: true);

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
    report = null;
    reportError = null;
    validationMessage = null;
    isLoadingReport = false;
    isRefreshing = false;
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
    super.dispose();
  }
}
