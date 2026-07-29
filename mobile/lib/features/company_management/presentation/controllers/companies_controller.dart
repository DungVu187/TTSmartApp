import 'package:flutter/foundation.dart';

import '../../../../core/network/api_exception.dart';
import '../../data/models/company_models.dart';
import '../../data/repositories/company_repository.dart';

class CompaniesController extends ChangeNotifier {
  CompaniesController(this.repository);

  final CompanyRepository repository;

  final List<CompanyResponse> items = <CompanyResponse>[];
  ApiException? error;
  ApiException? loadMoreError;
  bool isLoading = false;
  bool isRefreshing = false;
  bool isLoadingMore = false;
  int pageNumber = 1;
  int totalPages = 0;
  int totalCount = 0;
  String search = '';
  int status = CompanyDataStatus.active;
  bool? isLocked;
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
      final page = await repository.getCompanies(
        pageNumber: 1,
        search: search,
        status: status,
        isLocked: isLocked,
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
      final page = await repository.getCompanies(
        pageNumber: pageNumber + 1,
        search: search,
        status: status,
        isLocked: isLocked,
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

  void setStatus(int value) => status = value;

  void setLocked(bool? value) => isLocked = value;

  Future<CompanyResponse> getById(int id) => repository.getCompany(id);

  Future<CompanyResponse> create(CompanyUpsertRequest request) =>
      repository.createCompany(request);

  Future<CompanyResponse> update(int id, CompanyUpsertRequest request) =>
      repository.updateCompany(id, request);

  Future<CompanyResponse> setLock(int id, bool isLocked) =>
      repository.setCompanyLock(id, isLocked);

  Future<CompanyResponse> setExpiration(int id, DateTime? expiredDate) =>
      repository.setCompanyExpiration(id, expiredDate);

  Future<CompanyResponse> uploadLogo({
    required int id,
    required List<int> bytes,
    required String fileName,
    required String contentType,
  }) => repository.uploadCompanyLogo(
    id: id,
    bytes: bytes,
    fileName: fileName,
    contentType: contentType,
  );

  Future<Uint8List> getLogo(int id) => repository.getCompanyLogo(id);

  Future<CompanyResponse> delete(int id) => repository.deleteCompany(id);

  Future<CompanyResponse> restore(int id) => repository.restoreCompany(id);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
