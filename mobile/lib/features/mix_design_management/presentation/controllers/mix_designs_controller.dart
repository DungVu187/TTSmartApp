import 'package:flutter/foundation.dart';

import '../../../../core/network/api_exception.dart';
import '../../../company_management/data/models/company_models.dart';
import '../../../company_management/data/repositories/company_repository.dart';
import '../../data/models/mix_design_models.dart';
import '../../data/repositories/mix_design_repository.dart';

class MixDesignsController extends ChangeNotifier {
  MixDesignsController(
    this._repository,
    this._companyRepository, {
    required this.isAdmin,
    required int? initialCompanyId,
  }) : selectedCompanyId = isAdmin ? null : initialCompanyId;

  final MixDesignRepository _repository;
  final CompanyRepository _companyRepository;
  final bool isAdmin;

  final List<CompanyResponse> companies = <CompanyResponse>[];
  final List<MixDesignStation> stations = <MixDesignStation>[];

  int? selectedCompanyId;
  int? selectedStationId;
  MixDesignPage? result;
  ApiException? scopeError;
  ApiException? resultError;
  String? validationMessage;
  bool isLoadingCompanies = false;
  bool isLoadingStations = false;
  bool isLoadingResult = false;

  int _scopeRequestVersion = 0;
  int _resultRequestVersion = 0;
  bool _disposed = false;

  MixDesignStation? get selectedStation {
    for (final station in stations) {
      if (station.id == selectedStationId) return station;
    }
    return null;
  }

  int get currentPage => result?.pageNumber ?? 0;
  int get totalPages => result?.totalPages ?? 0;
  bool get canGoFirst => !isLoadingResult && currentPage > 1;
  bool get canGoPrevious => canGoFirst;
  bool get canGoNext =>
      !isLoadingResult && totalPages > 0 && currentPage < totalPages;
  bool get canGoLast => canGoNext;

  Future<void> initialize() async {
    if (isAdmin) {
      await _loadCompanies();
      return;
    }
    await _loadStations();
  }

  Future<void> selectCompany(int? companyId) async {
    if (!isAdmin || selectedCompanyId == companyId) return;
    selectedCompanyId = companyId;
    selectedStationId = null;
    stations.clear();
    _clearResult();
    scopeError = null;
    validationMessage = null;
    _notify();
    if (companyId != null) await _loadStations();
  }

  void selectStation(int? stationId) {
    if (selectedStationId == stationId) return;
    selectedStationId = stationId;
    validationMessage = null;
    _clearResult();
    _notify();
  }

  Future<void> search() => _loadPage(1);

  Future<void> retryStations() => _loadStations();

  Future<void> retryScope() =>
      isAdmin && companies.isEmpty ? _loadCompanies() : _loadStations();

  Future<void> retryResult() => _loadPage(result?.pageNumber ?? 1);

  Future<void> goToFirstPage() => _loadPage(1);

  Future<void> goToPreviousPage() => _loadPage(currentPage - 1);

  Future<void> goToNextPage() => _loadPage(currentPage + 1);

  Future<void> goToLastPage() => _loadPage(totalPages);

  Future<void> resetFilters() async {
    validationMessage = null;
    scopeError = null;
    selectedStationId = null;
    _clearResult();
    if (isAdmin) {
      selectedCompanyId = null;
      stations.clear();
    }
    _notify();
  }

  Future<void> _loadCompanies() async {
    final requestVersion = ++_scopeRequestVersion;
    isLoadingCompanies = true;
    scopeError = null;
    _notify();
    try {
      final loaded = <CompanyResponse>[];
      var pageNumber = 1;
      var totalPages = 1;
      do {
        final page = await _companyRepository.getCompanies(
          pageNumber: pageNumber,
          pageSize: 100,
          status: CompanyDataStatus.active,
        );
        if (requestVersion != _scopeRequestVersion) return;
        loaded.addAll(page.items);
        totalPages = page.totalPages;
        pageNumber++;
      } while (pageNumber <= totalPages);
      if (requestVersion != _scopeRequestVersion) return;
      companies
        ..clear()
        ..addAll(loaded);
    } on ApiException catch (error) {
      if (requestVersion == _scopeRequestVersion) scopeError = error;
    } finally {
      if (requestVersion == _scopeRequestVersion) {
        isLoadingCompanies = false;
        _notify();
      }
    }
  }

  Future<void> _loadStations() async {
    if (isAdmin && selectedCompanyId == null) return;
    final requestVersion = ++_scopeRequestVersion;
    isLoadingStations = true;
    scopeError = null;
    validationMessage = null;
    _notify();
    try {
      final loaded = await _repository.getStations(
        companyId: isAdmin ? selectedCompanyId : null,
      );
      if (requestVersion != _scopeRequestVersion) return;
      stations
        ..clear()
        ..addAll(loaded);
      if (!loaded.any((station) => station.id == selectedStationId)) {
        selectedStationId = loaded.length == 1 ? loaded.single.id : null;
      }
    } on ApiException catch (error) {
      if (requestVersion != _scopeRequestVersion) return;
      stations.clear();
      selectedStationId = null;
      scopeError = error;
    } finally {
      if (requestVersion == _scopeRequestVersion) {
        isLoadingStations = false;
        _notify();
      }
    }
  }

  Future<void> _loadPage(int pageNumber) async {
    if (isLoadingResult || pageNumber < 1) return;
    if (isAdmin && selectedCompanyId == null) {
      validationMessage = 'Vui lòng chọn công ty';
      _notify();
      return;
    }
    final stationId = selectedStationId;
    if (stationId == null) {
      validationMessage = 'Vui lòng chọn trạm';
      _notify();
      return;
    }
    if (result != null &&
        result!.totalPages > 0 &&
        pageNumber > result!.totalPages) {
      return;
    }
    final requestVersion = ++_resultRequestVersion;
    final previousResult = result;
    validationMessage = null;
    resultError = null;
    isLoadingResult = true;
    _notify();
    try {
      final page = await _repository.getMixDesigns(
        MixDesignQuery(
          companyId: isAdmin ? selectedCompanyId : null,
          stationId: stationId,
          pageNumber: pageNumber,
        ),
      );
      if (requestVersion != _resultRequestVersion ||
          stationId != selectedStationId) {
        return;
      }
      result = page;
    } on ApiException catch (error) {
      if (requestVersion != _resultRequestVersion) return;
      result = previousResult;
      resultError = error;
    } finally {
      if (requestVersion == _resultRequestVersion) {
        isLoadingResult = false;
        _notify();
      }
    }
  }

  void _clearResult() {
    _resultRequestVersion++;
    result = null;
    resultError = null;
    isLoadingResult = false;
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
