import 'dart:typed_data';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/json_helpers.dart';
import '../models/report_models.dart';

class OrderStatisticsExportQuery {
  const OrderStatisticsExportQuery({
    required this.from,
    required this.to,
    required this.branchId,
    this.companyId,
    this.vehiclePlate,
    this.customerName,
    this.concreteGradeName,
    this.employeeName,
  });

  final DateTime from;
  final DateTime to;
  final int? companyId;
  final int? branchId;
  final String? vehiclePlate;
  final String? customerName;
  final String? concreteGradeName;
  final String? employeeName;

  Map<String, Object?> toQueryParameters() => <String, Object?>{
    'companyId': companyId,
    'branchId': branchId,
    'from': formatOrderStatisticsDateTime(from),
    'to': formatOrderStatisticsDateTime(to),
    'vehiclePlate': _normalizedFilter(vehiclePlate),
    'customerName': _normalizedFilter(customerName),
    'concreteGradeName': _normalizedFilter(concreteGradeName),
    'employeeName': _normalizedFilter(employeeName),
  };
}

class OrderStatisticsExportFile {
  const OrderStatisticsExportFile({
    required this.bytes,
    this.fileName = defaultFileName,
    this.contentType = defaultContentType,
  });

  static const String defaultFileName = 'thong-ke-don-hang.xlsx';
  static const String defaultContentType =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  final Uint8List bytes;
  final String fileName;
  final String contentType;
}

abstract interface class ReportsRepository {
  Future<List<OrderStatisticsStation>> getStations({int? companyId});

  Future<OrderStatisticsFilterOptions> getFilterOptions(
    OrderStatisticsFilterQuery query,
  );

  Future<OrderStatisticsPage> search(OrderStatisticsQuery query);

  Future<OrderStatisticsExportFile> export(OrderStatisticsExportQuery query);
}

class ApiReportsRepository implements ReportsRepository {
  ApiReportsRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<List<OrderStatisticsStation>> getStations({int? companyId}) async {
    _validateId(companyId, 'companyId');
    final response = await _apiClient.get(
      '/api/order-statistics/stations',
      query: <String, Object?>{'companyId': companyId},
    );
    return _parse(
      () => requireJsonList(
        response,
        'danh sách trạm thống kê',
      ).map(OrderStatisticsStation.fromJson).toList(growable: false),
    );
  }

  @override
  Future<OrderStatisticsFilterOptions> getFilterOptions(
    OrderStatisticsFilterQuery query,
  ) async {
    _validateId(query.companyId, 'companyId');
    _validateId(query.branchId, 'branchId');
    final response = await _apiClient.get(
      '/api/order-statistics/filters',
      query: query.toQueryParameters(),
    );
    return _parse(() => OrderStatisticsFilterOptions.fromJson(response));
  }

  @override
  Future<OrderStatisticsPage> search(OrderStatisticsQuery query) async {
    _validateId(query.companyId, 'companyId');
    _validateId(query.branchId, 'branchId');
    if (query.pageNumber < 1) {
      throw ArgumentError.value(query.pageNumber, 'pageNumber');
    }
    final response = await _apiClient.get(
      '/api/order-statistics',
      query: query.toQueryParameters(),
    );
    return _parse(() => OrderStatisticsPage.fromJson(response));
  }

  @override
  Future<OrderStatisticsExportFile> export(
    OrderStatisticsExportQuery query,
  ) async {
    _validateId(query.companyId, 'companyId');
    _validateId(query.branchId, 'branchId');
    final bytes = await _apiClient.getBytes(
      '/api/order-statistics/export',
      query: query.toQueryParameters(),
      accept: OrderStatisticsExportFile.defaultContentType,
    );
    return OrderStatisticsExportFile(bytes: bytes);
  }

  void _validateId(int? value, String name) {
    if (value != null && value < 1) {
      throw ArgumentError.value(value, name, 'Phải lớn hơn 0.');
    }
  }

  T _parse<T>(T Function() parser) {
    try {
      return parser();
    } on FormatException catch (error) {
      throw ApiException.invalidResponse(error.message);
    }
  }
}

class MockReportsRepository implements ReportsRepository {
  const MockReportsRepository();

  @override
  Future<List<OrderStatisticsStation>> getStations({int? companyId}) async =>
      const <OrderStatisticsStation>[];

  @override
  Future<OrderStatisticsFilterOptions> getFilterOptions(
    OrderStatisticsFilterQuery query,
  ) async => OrderStatisticsFilterOptions.empty;

  @override
  Future<OrderStatisticsPage> search(OrderStatisticsQuery query) async =>
      OrderStatisticsPage.empty(
        viewMode: query.viewMode,
        pageNumber: query.pageNumber,
      );

  @override
  Future<OrderStatisticsExportFile> export(
    OrderStatisticsExportQuery query,
  ) async => OrderStatisticsExportFile(bytes: Uint8List(0));
}

String? _normalizedFilter(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}
