import 'package:flutter/foundation.dart';

import '../../../../core/network/api_exception.dart';
import '../../../company_management/data/models/company_models.dart';
import '../../../company_management/data/repositories/company_repository.dart';
import '../../data/models/report_models.dart';
import '../../data/repositories/reports_repository.dart';
import '../../data/services/report_export_file_saver.dart';

class ReportsController extends ChangeNotifier {
  factory ReportsController({
    required ReportsRepository repository,
    required CompanyRepository companyRepository,
    DateTime Function()? now,
    ReportExportFileSaver? exportFileSaver,
  }) => ReportsController._(
    repository,
    companyRepository,
    now ?? DateTime.now,
    exportFileSaver ?? DeviceReportExportFileSaver(),
  );

  ReportsController._(
    this._repository,
    this._companyRepository,
    this._now,
    this._exportFileSaver,
  ) {
    final current = _now();
    fromDate = DateTime(current.year, current.month, current.day);
    toDate = current;
  }

  final ReportsRepository _repository;
  final CompanyRepository _companyRepository;
  final DateTime Function() _now;
  final ReportExportFileSaver _exportFileSaver;

  final companies = <CompanyResponse>[];
  final stations = <OrderStatisticsStation>[];
  OrderStatisticsFilterOptions filterOptions =
      OrderStatisticsFilterOptions.empty;

  ReportViewMode viewMode = ReportViewMode.detail;
  late DateTime fromDate;
  late DateTime toDate;
  int? selectedCompanyId;
  int? selectedStationId;
  String? selectedVehiclePlate;
  String? selectedCustomerName;
  String? selectedConcreteGradeName;
  String? selectedEmployeeName;

  OrderStatisticsPage? result;
  bool isAdmin = false;
  bool isInitialized = false;
  bool isLoadingScope = false;
  bool isLoadingOptions = false;
  bool isSearching = false;
  bool isExporting = false;
  bool usesDefaultTimeRange = true;
  String? resultErrorMessage;
  String? feedbackMessage;
  int feedbackVersion = 0;

  int _scopeRequestVersion = 0;
  int _optionsRequestVersion = 0;
  int _searchRequestVersion = 0;
  int? _failedPageNumber;

  bool get hasResult => result != null;
  int get currentPage => result?.pageNumber ?? 1;
  int get totalPages => result?.totalPages ?? 0;
  bool get canGoFirst => currentPage > 1 && !isSearching;
  bool get canGoPrevious => currentPage > 1 && !isSearching;
  bool get canGoNext => currentPage < totalPages && !isSearching;
  bool get canGoLast =>
      totalPages > 0 && currentPage < totalPages && !isSearching;

  CompanyResponse? get selectedCompany => _findCompany(selectedCompanyId);

  OrderStatisticsStation? get selectedStation =>
      _findStation(selectedStationId);

  Future<void> initialize({
    required bool isAdmin,
    int? initialCompanyId,
  }) async {
    if (isInitialized) return;
    isInitialized = true;
    this.isAdmin = isAdmin;
    if (isAdmin) {
      await _loadCompanies();
    } else {
      selectedCompanyId = initialCompanyId;
    }
    await _loadStations();
  }

  Future<void> retryScope() async {
    if (isAdmin && companies.isEmpty) await _loadCompanies();
    await _loadStations();
  }

  Future<void> selectCompany(int? companyId) async {
    if (!isAdmin || selectedCompanyId == companyId) return;
    selectedCompanyId = companyId;
    selectedStationId = null;
    _clearFilterOptions();
    _clearDependentFilters();
    _clearResult();
    _notify();
    await _loadStations();
  }

  Future<void> selectStation(int? stationId) async {
    if (selectedStationId == stationId) return;
    selectedStationId = stationId;
    _clearFilterOptions();
    _clearDependentFilters();
    _clearResult();
    _notify();
    if (stationId != null) await _loadFilterOptions();
  }

  Future<void> setTimeRange(DateTime nextFrom, DateTime nextTo) async {
    if (fromDate == nextFrom && toDate == nextTo && !usesDefaultTimeRange) {
      return;
    }
    fromDate = nextFrom;
    toDate = nextTo;
    usesDefaultTimeRange = false;
    _clearFilterOptions();
    _clearDependentFilters();
    _clearResult();
    _notify();
    if (selectedStationId != null) await _loadFilterOptions();
  }

  void setViewMode(ReportViewMode mode) {
    if (viewMode == mode) return;
    viewMode = mode;
    _clearResult();
    _notify();
  }

  void setVehiclePlate(String? value) {
    if (selectedVehiclePlate == value) return;
    selectedVehiclePlate = value;
    _clearResult();
    _notify();
  }

  void setCustomerName(String? value) {
    if (selectedCustomerName == value) return;
    selectedCustomerName = value;
    _clearResult();
    _notify();
  }

  void setConcreteGradeName(String? value) {
    if (selectedConcreteGradeName == value) return;
    selectedConcreteGradeName = value;
    _clearResult();
    _notify();
  }

  void setEmployeeName(String? value) {
    if (selectedEmployeeName == value) return;
    selectedEmployeeName = value;
    _clearResult();
    _notify();
  }

  Future<void> resetFilters() async {
    final current = _now();
    fromDate = DateTime(current.year, current.month, current.day);
    toDate = current;
    usesDefaultTimeRange = true;
    selectedVehiclePlate = null;
    selectedCustomerName = null;
    selectedConcreteGradeName = null;
    selectedEmployeeName = null;
    selectedStationId = null;
    _clearFilterOptions();
    _clearResult();
    if (isAdmin) selectedCompanyId = null;
    _notify();
    await _loadStations();
  }

  Future<void> search() async {
    if (isSearching) return;
    if (!_prepareRequest()) return;
    await _loadPage(1);
  }

  Future<void> exportExcel() async {
    if (isExporting) return;
    if (!_prepareRequest()) return;
    isExporting = true;
    _notify();
    try {
      final exportFile = await _repository.export(_buildExportQuery());
      final savedPath = await _exportFileSaver.save(exportFile);
      _feedback('Đã lưu file Excel tại $savedPath');
    } catch (error) {
      final message = error is ApiException && error.statusCode == 403
          ? 'Bạn không có quyền xuất Excel thống kê đơn hàng.'
          : _messageFor(error, 'Không thể xuất Excel. Vui lòng thử lại.');
      _feedback(message);
    } finally {
      isExporting = false;
      _notify();
    }
  }

  bool _prepareRequest() {
    if (isAdmin && selectedCompanyId == null) {
      _feedback('Chưa chọn công ty.');
      return false;
    }
    if (selectedStationId == null) {
      _feedback('Chưa chọn trạm.');
      return false;
    }
    if (usesDefaultTimeRange) {
      toDate = _now();
    }
    if (!toDate.isAfter(fromDate)) {
      _feedback('Thời gian kết thúc phải lớn hơn thời gian bắt đầu.');
      return false;
    }
    return true;
  }

  Future<void> goToFirstPage() => _loadPage(1);

  Future<void> goToPreviousPage() => _loadPage(currentPage - 1);

  Future<void> goToNextPage() => _loadPage(currentPage + 1);

  Future<void> goToLastPage() => _loadPage(totalPages);

  Future<void> retryResult() => _loadPage(_failedPageNumber ?? currentPage);

  Future<void> _loadPage(int pageNumber) async {
    if (isSearching || selectedStationId == null || pageNumber < 1) return;
    if (result != null && totalPages > 0 && pageNumber > totalPages) return;
    final previousResult = result;
    final requestVersion = ++_searchRequestVersion;
    isSearching = true;
    resultErrorMessage = null;
    _failedPageNumber = null;
    _notify();
    try {
      final page = await _repository.search(_buildQuery(pageNumber));
      if (requestVersion == _searchRequestVersion) result = page;
    } catch (error) {
      if (requestVersion == _searchRequestVersion) {
        result = previousResult;
        resultErrorMessage = _messageFor(
          error,
          'Không thể tải thống kê. Vui lòng thử lại.',
        );
        _failedPageNumber = pageNumber;
        _feedback(resultErrorMessage!);
      }
    } finally {
      isSearching = false;
      _notify();
    }
  }

  OrderStatisticsQuery _buildQuery(int pageNumber) => OrderStatisticsQuery(
    from: fromDate,
    to: toDate,
    companyId: selectedCompanyId,
    branchId: selectedStationId,
    viewMode: viewMode,
    pageNumber: pageNumber,
    vehiclePlate: selectedVehiclePlate,
    customerName: selectedCustomerName,
    concreteGradeName: selectedConcreteGradeName,
    employeeName: selectedEmployeeName,
  );

  OrderStatisticsExportQuery _buildExportQuery() => OrderStatisticsExportQuery(
    from: fromDate,
    to: toDate,
    companyId: selectedCompanyId,
    branchId: selectedStationId,
    vehiclePlate: selectedVehiclePlate,
    customerName: selectedCustomerName,
    concreteGradeName: selectedConcreteGradeName,
    employeeName: selectedEmployeeName,
  );

  Future<void> _loadCompanies() async {
    final requestVersion = ++_scopeRequestVersion;
    isLoadingScope = true;
    _notify();
    try {
      final loadedCompanies = <CompanyResponse>[];
      var pageNumber = 1;
      var totalPages = 1;
      do {
        final page = await _companyRepository.getCompanies(
          pageNumber: pageNumber,
          pageSize: 100,
          status: CompanyDataStatus.active,
        );
        if (requestVersion != _scopeRequestVersion) return;
        loadedCompanies.addAll(page.items);
        totalPages = page.totalPages;
        pageNumber++;
      } while (pageNumber <= totalPages);

      if (requestVersion != _scopeRequestVersion) return;
      companies
        ..clear()
        ..addAll(loadedCompanies);
    } catch (error) {
      if (requestVersion != _scopeRequestVersion) return;
      _feedback(_messageFor(error, 'Không thể tải danh sách công ty.'));
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
    _notify();
    try {
      final values = await _repository.getStations(
        companyId: selectedCompanyId,
      );
      if (requestVersion != _scopeRequestVersion) return;
      stations
        ..clear()
        ..addAll(values);
    } catch (error) {
      if (requestVersion != _scopeRequestVersion) return;
      stations.clear();
      _feedback(_messageFor(error, 'Không thể tải danh sách trạm.'));
    } finally {
      if (requestVersion == _scopeRequestVersion) {
        isLoadingScope = false;
        _notify();
      }
    }
  }

  Future<void> _loadFilterOptions() async {
    if (selectedStationId == null) return;
    if (usesDefaultTimeRange) toDate = _now();
    final requestVersion = ++_optionsRequestVersion;
    isLoadingOptions = true;
    _notify();
    try {
      final options = await _repository.getFilterOptions(
        OrderStatisticsFilterQuery(
          from: fromDate,
          to: toDate,
          companyId: selectedCompanyId,
          branchId: selectedStationId,
        ),
      );
      if (requestVersion != _optionsRequestVersion) return;
      filterOptions = options;
    } catch (error) {
      if (requestVersion != _optionsRequestVersion) return;
      filterOptions = OrderStatisticsFilterOptions.empty;
      _feedback(_messageFor(error, 'Không thể tải danh sách bộ lọc.'));
    } finally {
      if (requestVersion == _optionsRequestVersion) {
        isLoadingOptions = false;
        _notify();
      }
    }
  }

  void _clearDependentFilters() {
    selectedVehiclePlate = null;
    selectedCustomerName = null;
    selectedConcreteGradeName = null;
    selectedEmployeeName = null;
  }

  void _clearFilterOptions() {
    _optionsRequestVersion++;
    isLoadingOptions = false;
    filterOptions = OrderStatisticsFilterOptions.empty;
  }

  void _clearResult() {
    _searchRequestVersion++;
    result = null;
    resultErrorMessage = null;
    _failedPageNumber = null;
  }

  CompanyResponse? _findCompany(int? id) {
    for (final company in companies) {
      if (company.id == id) return company;
    }
    return null;
  }

  OrderStatisticsStation? _findStation(int? id) {
    for (final station in stations) {
      if (station.id == id) return station;
    }
    return null;
  }

  String _messageFor(Object error, String fallback) =>
      error is ApiException ? error.message : fallback;

  void _feedback(String message) {
    feedbackMessage = message;
    feedbackVersion++;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
