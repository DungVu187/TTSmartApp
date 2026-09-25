import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../models/station_models.dart';

abstract class StationRepository {
  Future<StationPage> getStations({
    int pageNumber = 1,
    int pageSize = 20,
    String? search,
    int? companyId,
    int? typeTram,
    int? status = StationDataStatus.active,
  });

  Future<StationResponse> getStation(int id);

  Future<StationResponse> createStation(CreateStationRequest request);

  Future<StationResponse> updateStation(int id, UpdateStationRequest request);

  Future<StationResponse> deleteStation(int id);

  Future<StationResponse> restoreStation(int id);
}

class ApiStationRepository implements StationRepository {
  ApiStationRepository(this._apiClient);

  final ApiClient _apiClient;

  String? resolveMediaUrl(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) return null;
    final parsed = Uri.tryParse(normalized);
    if (parsed?.hasScheme == true) return parsed.toString();
    return _apiClient.baseUri.resolve(normalized).toString();
  }

  @override
  Future<StationPage> getStations({
    int pageNumber = 1,
    int pageSize = 20,
    String? search,
    int? companyId,
    int? typeTram,
    int? status = StationDataStatus.active,
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
    if (!StationDataStatus.isSupported(status)) {
      throw ArgumentError.value(status, 'status', 'Chỉ hỗ trợ 1 hoặc 99.');
    }
    if (typeTram != null && typeTram != 1 && typeTram != 2) {
      throw ArgumentError.value(typeTram, 'typeTram', 'Chỉ hỗ trợ 1 hoặc 2.');
    }
    final response = await _apiClient.get(
      '/api/branches',
      query: <String, Object?>{
        'pageNumber': pageNumber,
        'pageSize': pageSize,
        'search': _normalizedSearch(search),
        'companyId': companyId,
        'typeTram': typeTram,
        'status': status,
      },
    );
    return _parse(() => StationPage.fromJson(response));
  }

  @override
  Future<StationResponse> getStation(int id) => _getModel('/api/branches/$id');

  @override
  Future<StationResponse> createStation(CreateStationRequest request) =>
      _sendModel(
        () => _apiClient.post('/api/branches', body: request.toJson()),
      );

  @override
  Future<StationResponse> updateStation(int id, UpdateStationRequest request) =>
      _sendModel(
        () => _apiClient.put('/api/branches/$id', body: request.toJson()),
      );

  @override
  Future<StationResponse> deleteStation(int id) =>
      _sendModel(() => _apiClient.delete('/api/branches/$id'));

  @override
  Future<StationResponse> restoreStation(int id) =>
      _sendModel(() => _apiClient.post('/api/branches/$id/restore'));

  Future<StationResponse> _getModel(String path) =>
      _sendModel(() => _apiClient.get(path));

  Future<StationResponse> _sendModel(Future<Object?> Function() request) async {
    final response = await request();
    return _parse(() => StationResponse.fromJson(response));
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
