import 'package:flutter/foundation.dart';

import '../../../../core/files/export_file_saver.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/api_request_cancellation.dart';
import '../../../../core/utils/vietnam_time.dart';
import '../../../company_management/data/models/company_models.dart';
import '../../../company_management/data/repositories/company_repository.dart';
import '../../data/models/weigh_station_filter_models.dart';
import '../../data/models/weigh_station_result_models.dart';
import '../../data/repositories/weigh_station_repository.dart';

class WeighStationController extends ChangeNotifier {
  WeighStationController({
    required this.repository,
    required this.companyRepository,
    required this.isAdmin,
    this.initialCompanyId,
    DateTime Function()? now,
    ExportFileSaver? exportFileSaver,
  }) : _now = now ?? DateTime.now,
       _exportFileSaver = exportFileSaver ?? DeviceExportFileSaver() {
    final today = vietnamDateOnly(_now());
    fromDate = today;
    toDate = today;
    if (!isAdmin) selectedCompanyId = initialCompanyId;
  }

  final WeighStationRepository repository;
  final CompanyRepository companyRepository;
  final bool isAdmin;
  final int? initialCompanyId;
  final DateTime Function() _now;
  final ExportFileSaver _exportFileSaver;

  final List<CompanyResponse> companies = <CompanyResponse>[];
  final List<WeighStationStation> stations = <WeighStationStation>[];
  WeighStationFilterOptions filterOptions = WeighStationFilterOptions.empty;

  late DateTime fromDate;
  late DateTime toDate;
  int? selectedCompanyId;
  int? selectedStationId;
  WeighStationStage? selectedStage;
  String? selectedVehiclePlate;
  String? selectedGoodsName;
  String? selectedOperatorName;
  String? selectedUnitName;
  String? selectedWeighingType;

  WeighStationPage? detailResult;
  WeighStationSummary? summaryResult;
  bool hasSearched = false;

  bool isLoadingCompanies = false;
  bool isLoadingStations = false;
  bool isLoadingOptions = false;
  bool isLoadingDetail = false;
  bool isLoadingSummary = false;
  bool isExportingDetail = false;
  bool isExportingSummary = false;

  ApiException? companyError;
  ApiException? stationError;
  ApiException? optionsError;
  ApiException? detailError;
  ApiException? summaryError;

  String? feedbackMessage;
  int feedbackVersion = 0;

  bool _initialized = false;
  bool _disposed = false;
  int _stationRequestVersion = 0;
  int _optionsRequestVersion = 0;
  int _detailRequestVersion = 0;
  int _summaryRequestVersion = 0;
  int? _failedDetailPage;
  int? _failedSummaryPage;
  WeighStationSearchQuery? _appliedQuery;
  ApiRequestCancellation? _stationCancellation;
  ApiRequestCancellation? _optionsCancellation;
  ApiRequestCancellation? _detailCancellation;
  ApiRequestCancellation? _summaryCancellation;

  int get detailPage => detailResult?.pageNumber ?? 1;
  int get detailTotalPages => detailResult?.totalPages ?? 0;
  int get summaryPage => summaryResult?.pageNumber ?? 1;
  int get summaryTotalPages => summaryResult?.totalPages ?? 0;
  bool get canLoadOptions => selectedStationId != null;

  CompanyResponse? get selectedCompany =>
      _firstWhereOrNull(companies, (item) => item.id == selectedCompanyId);

  WeighStationStation? get selectedStation =>
      _firstWhereOrNull(stations, (item) => item.id == selectedStationId);

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    if (isAdmin) {
      await _loadCompanies();
      return;
    }
    await _loadStations();
  }

  Future<void> retryCompanies() => _loadCompanies();

  Future<void> retryStations() => _loadStations();

  Future<void> retryOptions() => _loadFilterOptions();

  Future<void> selectCompany(int? companyId) async {
    if (!isAdmin || selectedCompanyId == companyId) return;
    selectedCompanyId = companyId;
    selectedStationId = null;
    stations.clear();
    _cancelStationRequest();
    _invalidateDependentState();
    stationError = null;
    _notify();
    if (companyId != null) await _loadStations();
  }

  Future<void> selectStation(int? stationId) async {
    if (selectedStationId == stationId) return;
    selectedStationId = stationId;
    _invalidateDependentState();
    _notify();
    await _loadOptionsWhenReady();
  }

  Future<void> selectStage(WeighStationStage? stage) async {
    if (selectedStage == stage) return;
    selectedStage = stage;
    _invalidateDependentState();
    _notify();
    await _loadOptionsWhenReady();
  }

  Future<void> setDateRange(DateTime start, DateTime end) async {
    final nextStart = vietnamDateOnly(start);
    final nextEnd = vietnamDateOnly(end);
    if (fromDate == nextStart && toDate == nextEnd) return;
    fromDate = nextStart;
    toDate = nextEnd;
    _invalidateDependentState();
    _notify();
    await _loadOptionsWhenReady();
  }

  void setVehiclePlate(String? value) =>
      _setLeafFilter(value, selectedVehiclePlate, (next) {
        selectedVehiclePlate = next;
      });

  void setGoodsName(String? value) =>
      _setLeafFilter(value, selectedGoodsName, (next) {
        selectedGoodsName = next;
      });

  void setOperatorName(String? value) =>
      _setLeafFilter(value, selectedOperatorName, (next) {
        selectedOperatorName = next;
      });

  void setUnitName(String? value) =>
      _setLeafFilter(value, selectedUnitName, (next) {
        selectedUnitName = next;
      });

  void setWeighingType(String? value) =>
      _setLeafFilter(value, selectedWeighingType, (next) {
        selectedWeighingType = next;
      });

  Future<void> resetFilters() async {
    final today = vietnamDateOnly(_now());
    fromDate = today;
    toDate = today;
    selectedStage = null;
    selectedStationId = null;
    if (isAdmin) selectedCompanyId = null;
    stations.clear();
    _cancelStationRequest();
    _invalidateDependentState();
    stationError = null;
    _notify();
    if (!isAdmin) await _loadStations();
  }

  Future<void> search() async {
    final query = _currentQuery(pageNumber: 1);
    if (query == null) return;
    _cancelResultRequests();
    _appliedQuery = query;
    hasSearched = true;
    detailResult = null;
    summaryResult = null;
    detailError = null;
    summaryError = null;
    _failedDetailPage = null;
    _failedSummaryPage = null;
    _notify();
    await Future.wait(<Future<void>>[_loadDetailPage(1), _loadSummaryPage(1)]);
  }

  Future<void> goToDetailPage(int pageNumber) => _loadDetailPage(pageNumber);

  Future<void> goToSummaryPage(int pageNumber) => _loadSummaryPage(pageNumber);

  Future<void> retryDetail() =>
      _loadDetailPage(_failedDetailPage ?? detailPage);

  Future<void> retrySummary() =>
      _loadSummaryPage(_failedSummaryPage ?? summaryPage);

  Future<void> exportDetail() => _export(isSummary: false);

  Future<void> exportSummary() => _export(isSummary: true);

  Future<void> _loadCompanies() async {
    if (isLoadingCompanies) return;
    isLoadingCompanies = true;
    companyError = null;
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
      companies
        ..clear()
        ..addAll(loaded);
    } on ApiException catch (error) {
      companyError = error;
    } finally {
      isLoadingCompanies = false;
      _notify();
    }
  }

  Future<void> _loadStations() async {
    if (isAdmin && selectedCompanyId == null) return;
    _cancelStationRequest();
    final cancellation = ApiRequestCancellation();
    _stationCancellation = cancellation;
    final requestVersion = ++_stationRequestVersion;
    isLoadingStations = true;
    stationError = null;
    stations.clear();
    _notify();
    try {
      final loaded = await repository.getStations(
        companyId: isAdmin ? selectedCompanyId : null,
        cancellation: cancellation,
      );
      if (requestVersion != _stationRequestVersion) return;
      stations.addAll(loaded);
    } on ApiRequestCancelledException {
      return;
    } on ApiException catch (error) {
      if (requestVersion == _stationRequestVersion) stationError = error;
    } finally {
      if (requestVersion == _stationRequestVersion) {
        isLoadingStations = false;
        _stationCancellation = null;
        _notify();
      }
    }
  }

  Future<void> _loadOptionsWhenReady() async {
    if (!canLoadOptions) return;
    await _loadFilterOptions();
  }

  Future<void> _loadFilterOptions() async {
    final branchId = selectedStationId;
    final stage = selectedStage;
    if (branchId == null) return;
    _cancelOptionsRequest();
    final cancellation = ApiRequestCancellation();
    _optionsCancellation = cancellation;
    final requestVersion = ++_optionsRequestVersion;
    final companyId = isAdmin ? selectedCompanyId : null;
    final requestedFrom = fromDate;
    final requestedTo = toDate;
    isLoadingOptions = true;
    optionsError = null;
    _notify();
    try {
      final options = await repository.getFilterOptions(
        WeighStationFilterQuery(
          companyId: companyId,
          branchId: branchId,
          stage: stage,
          from: requestedFrom,
          to: vietnamExclusiveDayAfter(requestedTo),
        ),
        cancellation: cancellation,
      );
      if (requestVersion != _optionsRequestVersion ||
          branchId != selectedStationId ||
          stage != selectedStage ||
          companyId != (isAdmin ? selectedCompanyId : null) ||
          requestedFrom != fromDate ||
          requestedTo != toDate) {
        return;
      }
      filterOptions = options;
      _retainValidLeafSelections(options);
    } on ApiRequestCancelledException {
      return;
    } on ApiException catch (error) {
      if (requestVersion == _optionsRequestVersion) optionsError = error;
    } finally {
      if (requestVersion == _optionsRequestVersion) {
        isLoadingOptions = false;
        _optionsCancellation = null;
        _notify();
      }
    }
  }

  Future<void> _loadDetailPage(int pageNumber) async {
    final appliedQuery = _appliedQuery;
    if (appliedQuery == null || pageNumber < 1 || isLoadingDetail) return;
    if (detailResult != null &&
        detailResult!.totalPages > 0 &&
        pageNumber > detailResult!.totalPages) {
      return;
    }
    _detailCancellation?.cancel();
    final cancellation = ApiRequestCancellation();
    _detailCancellation = cancellation;
    final requestVersion = ++_detailRequestVersion;
    final previousResult = detailResult;
    isLoadingDetail = true;
    detailError = null;
    _failedDetailPage = null;
    _notify();
    try {
      final result = await repository.searchDetail(
        appliedQuery.withPageNumber(pageNumber),
        cancellation: cancellation,
      );
      if (requestVersion == _detailRequestVersion) detailResult = result;
    } on ApiRequestCancelledException {
      return;
    } on ApiException catch (error) {
      if (requestVersion == _detailRequestVersion) {
        detailResult = previousResult;
        detailError = error;
        _failedDetailPage = pageNumber;
      }
    } finally {
      if (requestVersion == _detailRequestVersion) {
        isLoadingDetail = false;
        _detailCancellation = null;
        _notify();
      }
    }
  }

  Future<void> _loadSummaryPage(int pageNumber) async {
    final appliedQuery = _appliedQuery;
    if (appliedQuery == null || pageNumber < 1 || isLoadingSummary) return;
    if (summaryResult != null &&
        summaryResult!.totalPages > 0 &&
        pageNumber > summaryResult!.totalPages) {
      return;
    }
    _summaryCancellation?.cancel();
    final cancellation = ApiRequestCancellation();
    _summaryCancellation = cancellation;
    final requestVersion = ++_summaryRequestVersion;
    final previousResult = summaryResult;
    isLoadingSummary = true;
    summaryError = null;
    _failedSummaryPage = null;
    _notify();
    try {
      final result = await repository.searchSummary(
        appliedQuery.withPageNumber(pageNumber),
        cancellation: cancellation,
      );
      if (requestVersion == _summaryRequestVersion) summaryResult = result;
    } on ApiRequestCancelledException {
      return;
    } on ApiException catch (error) {
      if (requestVersion == _summaryRequestVersion) {
        summaryResult = previousResult;
        summaryError = error;
        _failedSummaryPage = pageNumber;
      }
    } finally {
      if (requestVersion == _summaryRequestVersion) {
        isLoadingSummary = false;
        _summaryCancellation = null;
        _notify();
      }
    }
  }

  Future<void> _export({required bool isSummary}) async {
    if (isSummary ? isExportingSummary : isExportingDetail) return;
    final query = _currentQuery(pageNumber: 1);
    if (query == null) return;
    if (isSummary) {
      isExportingSummary = true;
    } else {
      isExportingDetail = true;
    }
    _notify();
    try {
      final file = isSummary
          ? await repository.exportSummary(query)
          : await repository.exportDetail(query);
      final savedPath = await _exportFileSaver.save(file);
      _feedback('Đã lưu file Excel tại $savedPath');
    } on ApiException catch (error) {
      _feedback(
        error.statusCode == 403
            ? 'Bạn không có quyền xuất Excel cân ô tô.'
            : weighStationErrorMessage(
                error,
                fallback: 'Không thể xuất Excel. Vui lòng thử lại.',
              ),
      );
    } catch (_) {
      _feedback('Không thể lưu file Excel. Vui lòng thử lại.');
    } finally {
      if (isSummary) {
        isExportingSummary = false;
      } else {
        isExportingDetail = false;
      }
      _notify();
    }
  }

  WeighStationSearchQuery? _currentQuery({required int pageNumber}) {
    if (isAdmin && selectedCompanyId == null) {
      _feedback('Chưa chọn công ty.');
      return null;
    }
    final branchId = selectedStationId;
    if (branchId == null) {
      _feedback('Chưa chọn trạm cân.');
      return null;
    }
    final stage = selectedStage;
    if (toDate.isBefore(fromDate)) {
      _feedback('Ngày kết thúc không được trước ngày bắt đầu.');
      return null;
    }
    return WeighStationSearchQuery(
      companyId: isAdmin ? selectedCompanyId : null,
      branchId: branchId,
      stage: stage,
      from: fromDate,
      to: vietnamExclusiveDayAfter(toDate),
      vehiclePlate: selectedVehiclePlate,
      goodsName: selectedGoodsName,
      operatorName: selectedOperatorName,
      unitName: selectedUnitName,
      weighingType: selectedWeighingType,
      pageNumber: pageNumber,
    );
  }

  void _setLeafFilter(
    String? value,
    String? current,
    ValueChanged<String?> apply,
  ) {
    final normalized = _normalized(value);
    if (normalized == current) return;
    apply(normalized);
    _clearResults();
    _notify();
  }

  void _invalidateDependentState() {
    _cancelOptionsRequest();
    filterOptions = WeighStationFilterOptions.empty;
    optionsError = null;
    isLoadingOptions = false;
    _clearLeafSelections();
    _clearResults();
  }

  void _clearLeafSelections() {
    selectedVehiclePlate = null;
    selectedGoodsName = null;
    selectedOperatorName = null;
    selectedUnitName = null;
    selectedWeighingType = null;
  }

  void _retainValidLeafSelections(WeighStationFilterOptions options) {
    if (!options.vehiclePlates.contains(selectedVehiclePlate)) {
      selectedVehiclePlate = null;
    }
    if (!options.goodsNames.contains(selectedGoodsName)) {
      selectedGoodsName = null;
    }
    if (!options.operatorNames.contains(selectedOperatorName)) {
      selectedOperatorName = null;
    }
    if (!options.unitNames.contains(selectedUnitName)) {
      selectedUnitName = null;
    }
    if (!options.weighingTypes.contains(selectedWeighingType)) {
      selectedWeighingType = null;
    }
  }

  void _clearResults() {
    _cancelResultRequests();
    _appliedQuery = null;
    hasSearched = false;
    detailResult = null;
    summaryResult = null;
    detailError = null;
    summaryError = null;
    _failedDetailPage = null;
    _failedSummaryPage = null;
  }

  void _cancelStationRequest() {
    _stationRequestVersion++;
    _stationCancellation?.cancel();
    _stationCancellation = null;
    isLoadingStations = false;
  }

  void _cancelOptionsRequest() {
    _optionsRequestVersion++;
    _optionsCancellation?.cancel();
    _optionsCancellation = null;
    isLoadingOptions = false;
  }

  void _cancelResultRequests() {
    _detailRequestVersion++;
    _summaryRequestVersion++;
    _detailCancellation?.cancel();
    _summaryCancellation?.cancel();
    _detailCancellation = null;
    _summaryCancellation = null;
    isLoadingDetail = false;
    isLoadingSummary = false;
  }

  void _feedback(String message) {
    feedbackMessage = message;
    feedbackVersion++;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  T? _firstWhereOrNull<T>(Iterable<T> values, bool Function(T) test) {
    for (final value in values) {
      if (test(value)) return value;
    }
    return null;
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelStationRequest();
    _cancelOptionsRequest();
    _cancelResultRequests();
    super.dispose();
  }
}

String weighStationErrorMessage(
  ApiException error, {
  required String fallback,
}) {
  if (error.statusCode == 503) {
    return 'Dữ liệu trạm cân hoặc máy chủ chưa sẵn sàng.';
  }
  if (error.statusCode == 403) {
    return 'Bạn không có quyền truy cập dữ liệu cân ô tô.';
  }
  final message = error.message.trim();
  return message.isEmpty ? fallback : message;
}

String? _normalized(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}
