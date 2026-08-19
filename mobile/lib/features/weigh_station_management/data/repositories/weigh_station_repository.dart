import '../../../../core/files/export_file.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/api_request_cancellation.dart';
import '../../../../core/network/json_helpers.dart';
import '../models/weigh_station_filter_models.dart';
import '../models/weigh_station_result_models.dart';

abstract interface class WeighStationRepository {
  Future<List<WeighStationStation>> getStations({
    int? companyId,
    ApiRequestCancellation? cancellation,
  });

  Future<WeighStationFilterOptions> getFilterOptions(
    WeighStationFilterQuery query, {
    ApiRequestCancellation? cancellation,
  });

  Future<WeighStationPage> searchDetail(
    WeighStationSearchQuery query, {
    ApiRequestCancellation? cancellation,
  });

  Future<WeighStationSummary> searchSummary(
    WeighStationSearchQuery query, {
    ApiRequestCancellation? cancellation,
  });

  Future<ExportFile> exportDetail(WeighStationSearchQuery query);

  Future<ExportFile> exportSummary(WeighStationSearchQuery query);
}

class ApiWeighStationRepository implements WeighStationRepository {
  ApiWeighStationRepository(this._apiClient);

  static const _reportRequestTimeout = Duration(seconds: 90);
  static const _excelContentType =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  final ApiClient _apiClient;

  @override
  Future<List<WeighStationStation>> getStations({
    int? companyId,
    ApiRequestCancellation? cancellation,
  }) async {
    _validateOptionalId(companyId, 'companyId');
    final response = await _apiClient.get(
      '/api/weigh-station-management/stations',
      query: <String, Object?>{'companyId': companyId},
      cancellation: cancellation,
    );
    return _parse(
      () => requireJsonList(
        response,
        'danh sách trạm cân',
      ).map(WeighStationStation.fromJson).toList(growable: false),
    );
  }

  @override
  Future<WeighStationFilterOptions> getFilterOptions(
    WeighStationFilterQuery query, {
    ApiRequestCancellation? cancellation,
  }) async {
    _validateFilterQuery(query);
    final response = await _apiClient.get(
      '/api/weigh-station-management/filters',
      query: query.toQueryParameters(),
      cancellation: cancellation,
      requestTimeout: _reportRequestTimeout,
    );
    return _parse(() => WeighStationFilterOptions.fromJson(response));
  }

  @override
  Future<WeighStationPage> searchDetail(
    WeighStationSearchQuery query, {
    ApiRequestCancellation? cancellation,
  }) async {
    _validateSearchQuery(query);
    final response = await _apiClient.get(
      '/api/weigh-station-management',
      query: query.toQueryParameters(),
      cancellation: cancellation,
      requestTimeout: _reportRequestTimeout,
    );
    return _parse(() => WeighStationPage.fromJson(response));
  }

  @override
  Future<WeighStationSummary> searchSummary(
    WeighStationSearchQuery query, {
    ApiRequestCancellation? cancellation,
  }) async {
    _validateSearchQuery(query);
    final response = await _apiClient.get(
      '/api/weigh-station-management/summary',
      query: query.toQueryParameters(),
      cancellation: cancellation,
      requestTimeout: _reportRequestTimeout,
    );
    return _parse(() => WeighStationSummary.fromJson(response));
  }

  @override
  Future<ExportFile> exportDetail(WeighStationSearchQuery query) async {
    _validateSearchQuery(query);
    final bytes = await _apiClient.getBytes(
      '/api/weigh-station-management/export',
      query: query.toQueryParameters(includePageNumber: false),
      accept: _excelContentType,
      requestTimeout: _reportRequestTimeout,
    );
    return ExportFile(
      bytes: bytes,
      fileName: 'quan-ly-can-o-to.xlsx',
      contentType: _excelContentType,
    );
  }

  @override
  Future<ExportFile> exportSummary(WeighStationSearchQuery query) async {
    _validateSearchQuery(query);
    final bytes = await _apiClient.getBytes(
      '/api/weigh-station-management/summary/export',
      query: query.toQueryParameters(includePageNumber: false),
      accept: _excelContentType,
      requestTimeout: _reportRequestTimeout,
    );
    return ExportFile(
      bytes: bytes,
      fileName: 'tong-hop-can-o-to.xlsx',
      contentType: _excelContentType,
    );
  }

  void _validateFilterQuery(WeighStationFilterQuery query) {
    _validateOptionalId(query.companyId, 'companyId');
    _validateRequiredId(query.branchId, 'branchId');
    if (!query.to.isAfter(query.from)) {
      throw ArgumentError.value(query.to, 'to', 'Phải lớn hơn from.');
    }
  }

  void _validateSearchQuery(WeighStationSearchQuery query) {
    _validateOptionalId(query.companyId, 'companyId');
    _validateRequiredId(query.branchId, 'branchId');
    if (!query.to.isAfter(query.from)) {
      throw ArgumentError.value(query.to, 'to', 'Phải lớn hơn from.');
    }
    if (query.pageNumber < 1) {
      throw ArgumentError.value(
        query.pageNumber,
        'pageNumber',
        'Phải lớn hơn 0.',
      );
    }
  }

  void _validateOptionalId(int? value, String name) {
    if (value != null) _validateRequiredId(value, name);
  }

  void _validateRequiredId(int value, String name) {
    if (value < 1) throw ArgumentError.value(value, name, 'Phải lớn hơn 0.');
  }

  T _parse<T>(T Function() parser) {
    try {
      return parser();
    } on FormatException catch (error) {
      throw ApiException.invalidResponse(error.message);
    }
  }
}
