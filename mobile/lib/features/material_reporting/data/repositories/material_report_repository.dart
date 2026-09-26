import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/api_request_cancellation.dart';
import '../../../../core/network/json_helpers.dart';
import '../models/material_report_models.dart';

/// The API is still reading the station's mixing history for the first time
/// (a few minutes on a large station, once); ask again a few seconds later.
class MaterialReportPreparing implements Exception {
  const MaterialReportPreparing({required this.progressPercent});

  final int progressPercent;
}

abstract interface class MaterialReportRepository {
  Future<List<MaterialReportStation>> getStations({int? companyId});

  Future<MaterialReport> getReport(
    MaterialReportQuery query, {
    ApiRequestCancellation? cancellation,
  });
}

class ApiMaterialReportRepository implements MaterialReportRepository {
  ApiMaterialReportRepository(this._apiClient);

  static const _reportRequestTimeout = Duration(seconds: 150);

  final ApiClient _apiClient;

  @override
  Future<List<MaterialReportStation>> getStations({int? companyId}) async {
    _validateOptionalId(companyId, 'companyId');
    final response = await _apiClient.get(
      '/api/material-reports/stations',
      query: <String, Object?>{'companyId': companyId},
    );
    return _parse(
      () => requireJsonList(
        response,
        'danh sách trạm báo cáo vật liệu',
      ).map(MaterialReportStation.fromJson).toList(growable: false),
    );
  }

  @override
  Future<MaterialReport> getReport(
    MaterialReportQuery query, {
    ApiRequestCancellation? cancellation,
  }) async {
    _validateOptionalId(query.companyId, 'companyId');
    _validateOptionalId(query.branchId, 'branchId');
    if (query.from.isAfter(query.to)) {
      throw ArgumentError.value(
        query.to,
        'to',
        'Không được trước thời gian bắt đầu.',
      );
    }
    if (query.pageNumber < 1) {
      throw ArgumentError.value(query.pageNumber, 'pageNumber', 'Phải từ 1.');
    }
    final response = await _apiClient.get(
      '/api/material-reports',
      query: query.toQueryParameters(),
      cancellation: cancellation,
      requestTimeout: _reportRequestTimeout,
    );
    if (response is Map<String, dynamic> && response['status'] == 'preparing') {
      final progress = response['progressPercent'];
      throw MaterialReportPreparing(
        progressPercent: progress is num ? progress.round().clamp(0, 99) : 0,
      );
    }
    return _parse(() => MaterialReport.fromJson(response));
  }

  T _parse<T>(T Function() parser) {
    try {
      return parser();
    } on FormatException catch (error) {
      throw ApiException.invalidResponse(error.message);
    }
  }

  void _validateOptionalId(int? value, String name) {
    if (value != null && value < 1) {
      throw ArgumentError.value(value, name, 'Phải lớn hơn 0.');
    }
  }
}
