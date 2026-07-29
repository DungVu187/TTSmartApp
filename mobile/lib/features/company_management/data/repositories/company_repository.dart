import 'dart:typed_data';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../models/company_models.dart';

abstract class CompanyRepository {
  Future<CompanyPage> getCompanies({
    int pageNumber = 1,
    int pageSize = 20,
    String? search,
    int? status = CompanyDataStatus.active,
    bool? isLocked,
  });

  Future<CompanyResponse> getCompany(int id);

  Future<CompanyResponse> createCompany(CompanyUpsertRequest request);

  Future<CompanyResponse> updateCompany(int id, CompanyUpsertRequest request);

  Future<CompanyResponse> setCompanyLock(int id, bool isLocked);

  Future<CompanyResponse> setCompanyExpiration(int id, DateTime? expiredDate);

  Future<CompanyResponse> uploadCompanyLogo({
    required int id,
    required List<int> bytes,
    required String fileName,
    required String contentType,
  });

  Future<Uint8List> getCompanyLogo(int id);

  Future<CompanyResponse> deleteCompany(int id);

  Future<CompanyResponse> restoreCompany(int id);
}

class ApiCompanyRepository implements CompanyRepository {
  ApiCompanyRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<CompanyPage> getCompanies({
    int pageNumber = 1,
    int pageSize = 20,
    String? search,
    int? status = CompanyDataStatus.active,
    bool? isLocked,
  }) async {
    if (pageNumber < 1) {
      throw ArgumentError.value(pageNumber, 'pageNumber', 'Phải lớn hơn 0.');
    }
    if (pageSize < 1 || pageSize > 100) {
      throw ArgumentError.value(
        pageSize,
        'pageSize',
        'Chỉ hỗ trợ từ 1 đến 100.',
      );
    }
    if (!CompanyDataStatus.isSupported(status)) {
      throw ArgumentError.value(status, 'status', 'Chỉ hỗ trợ 1 hoặc 99.');
    }
    final response = await _apiClient.get(
      '/api/companies',
      query: <String, Object?>{
        'pageNumber': pageNumber,
        'pageSize': pageSize,
        'search': _normalizedSearch(search),
        'status': status,
        'isLocked': isLocked,
      },
    );
    return _parse(() => CompanyPage.fromJson(response));
  }

  @override
  Future<CompanyResponse> getCompany(int id) => _getModel('/api/companies/$id');

  @override
  Future<CompanyResponse> createCompany(CompanyUpsertRequest request) =>
      _sendModel(
        () => _apiClient.post('/api/companies', body: request.toJson()),
      );

  @override
  Future<CompanyResponse> updateCompany(int id, CompanyUpsertRequest request) =>
      _sendModel(
        () => _apiClient.put('/api/companies/$id', body: request.toJson()),
      );

  @override
  Future<CompanyResponse> setCompanyLock(int id, bool isLocked) => _sendModel(
    () => _apiClient.put(
      '/api/companies/$id/lock',
      body: SetCompanyLockRequest(isLocked: isLocked).toJson(),
    ),
  );

  @override
  Future<CompanyResponse> setCompanyExpiration(int id, DateTime? expiredDate) =>
      _sendModel(
        () => _apiClient.put(
          '/api/companies/$id/expiration',
          body: SetCompanyExpirationRequest(expiredDate: expiredDate).toJson(),
        ),
      );

  @override
  Future<CompanyResponse> uploadCompanyLogo({
    required int id,
    required List<int> bytes,
    required String fileName,
    required String contentType,
  }) => _sendModel(
    () => _apiClient.postMultipart(
      '/api/companies/$id/logo',
      fieldName: 'file',
      bytes: bytes,
      fileName: fileName,
      contentType: contentType,
    ),
  );

  @override
  Future<Uint8List> getCompanyLogo(int id) =>
      _apiClient.getBytes('/api/companies/$id/logo');

  @override
  Future<CompanyResponse> deleteCompany(int id) =>
      _sendModel(() => _apiClient.delete('/api/companies/$id'));

  @override
  Future<CompanyResponse> restoreCompany(int id) =>
      _sendModel(() => _apiClient.post('/api/companies/$id/restore'));

  Future<CompanyResponse> _getModel(String path) =>
      _sendModel(() => _apiClient.get(path));

  Future<CompanyResponse> _sendModel(Future<Object?> Function() request) async {
    final response = await request();
    return _parse(() => CompanyResponse.fromJson(response));
  }

  T _parse<T>(T Function() parser) {
    try {
      return parser();
    } on FormatException catch (error) {
      throw ApiException.invalidResponse(error.message);
    }
  }

  String? _normalizedSearch(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
