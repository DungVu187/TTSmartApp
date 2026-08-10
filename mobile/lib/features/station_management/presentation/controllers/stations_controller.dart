import 'package:flutter/foundation.dart';

import '../../../../core/network/api_exception.dart';
import '../../data/models/station_models.dart';
import '../../data/repositories/station_repository.dart';

class StationsController extends ChangeNotifier {
  StationsController(this.repository);

  final StationRepository repository;

  final List<StationListItem> items = <StationListItem>[];
  ApiException? error;
  ApiException? loadMoreError;
  bool isLoading = false;
  bool isRefreshing = false;
  bool isLoadingMore = false;
  int pageNumber = 1;
  int totalPages = 0;
  int totalCount = 0;
  String search = '';
  int? companyId;
  int? typeTram;
  int status = StationDataStatus.active;
  int _requestVersion = 0;
  bool _disposed = false;

  bool get canLoadMore => pageNumber < totalPages;

  Future<void> load() async {
    final requestVersion = ++_requestVersion;
    error = null;
    loadMoreError = null;
    if (items.isEmpty) {
      isLoading = true;
    } else {
      isRefreshing = true;
    }
    _notify();
    try {
      final page = await repository.getStations(
        pageNumber: 1,
        search: search,
        companyId: companyId,
        typeTram: typeTram,
        status: status,
      );
      if (requestVersion != _requestVersion) return;
      items
        ..clear()
        ..addAll(page.items);
      pageNumber = page.pageNumber;
      totalPages = page.totalPages;
      totalCount = page.totalCount;
    } on ApiException catch (caught) {
      if (requestVersion == _requestVersion) error = caught;
    } finally {
      if (requestVersion == _requestVersion) {
        isLoading = false;
        isRefreshing = false;
        _notify();
      }
    }
  }

  Future<void> loadMore() async {
    if (!canLoadMore || isLoadingMore || isLoading || isRefreshing) return;
    final requestVersion = _requestVersion;
    isLoadingMore = true;
    loadMoreError = null;
    _notify();
    try {
      final page = await repository.getStations(
        pageNumber: pageNumber + 1,
        search: search,
        companyId: companyId,
        typeTram: typeTram,
        status: status,
      );
      if (requestVersion != _requestVersion) return;
      final existingIds = items.map((item) => item.id).toSet();
      items.addAll(page.items.where((item) => existingIds.add(item.id)));
      pageNumber = page.pageNumber;
      totalPages = page.totalPages;
      totalCount = page.totalCount;
    } on ApiException catch (caught) {
      if (requestVersion == _requestVersion) loadMoreError = caught;
    } finally {
      if (requestVersion == _requestVersion) {
        isLoadingMore = false;
        _notify();
      }
    }
  }

  void setSearch(String value) => search = value;

  void setCompanyId(int? value) => companyId = value;

  void setTypeTram(int? value) => typeTram = value;

  void setStatus(int value) => status = value;

  Future<StationResponse> getById(int id) => repository.getStation(id);

  Future<StationResponse> create(CreateStationRequest request) =>
      repository.createStation(request);

  Future<StationResponse> update(int id, UpdateStationRequest request) =>
      repository.updateStation(id, request);

  Future<StationResponse> delete(int id) => repository.deleteStation(id);

  Future<StationResponse> restore(int id) => repository.restoreStation(id);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
