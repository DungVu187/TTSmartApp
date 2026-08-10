import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/json_helpers.dart';
import '../models/order_report_models.dart';

abstract interface class OrderReportRepository {
  Future<List<OrderReportStation>> getStations({int? companyId});

  Future<List<OrderReportEmployee>> getEmployees({
    required int branchId,
    int? companyId,
    required DateTime fromDate,
    required DateTime toDate,
  });

  Future<OrderReportPage> search(OrderReportQuery query);
}

class ApiOrderReportRepository implements OrderReportRepository {
  ApiOrderReportRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<List<OrderReportStation>> getStations({int? companyId}) async {
    if (companyId != null && companyId < 1) {
      throw ArgumentError.value(companyId, 'companyId', 'Phải lớn hơn 0.');
    }
    final response = await _apiClient.get(
      '/api/order-reports/stations',
      query: <String, Object?>{'companyId': companyId},
    );
    return _parse(
      () => requireJsonList(
        response,
        'danh sách trạm báo cáo',
      ).map(OrderReportStation.fromJson).toList(growable: false),
    );
  }

  @override
  Future<List<OrderReportEmployee>> getEmployees({
    required int branchId,
    int? companyId,
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    _validateOptionalId(branchId, 'branchId');
    _validateOptionalId(companyId, 'companyId');
    if (!fromDate.isBefore(toDate)) {
      throw ArgumentError.value(
        toDate,
        'toDate',
        'Phải sau thời gian bắt đầu.',
      );
    }
    final response = await _apiClient.get(
      '/api/order-reports/employees',
      query: <String, Object?>{
        'branchId': branchId,
        'companyId': companyId,
        'from': formatVietnamDateTimeOffset(fromDate),
        'to': formatVietnamDateTimeOffset(toDate),
      },
    );
    return _parse(
      () => requireJsonList(
        response,
        'danh sách nhân viên báo cáo',
      ).map(OrderReportEmployee.fromJson).toList(growable: false),
    );
  }

  @override
  Future<OrderReportPage> search(OrderReportQuery query) async {
    _validateOptionalId(query.branchId, 'branchId');
    _validateOptionalId(query.companyId, 'companyId');
    if (!query.fromDate.isBefore(query.toDate)) {
      throw ArgumentError.value(
        query.toDate,
        'toDate',
        'Phải sau thời gian bắt đầu.',
      );
    }
    if (query.pageNumber < 1) {
      throw ArgumentError.value(
        query.pageNumber,
        'pageNumber',
        'Phải lớn hơn 0.',
      );
    }
    if (query.pageSize < 1 || query.pageSize > 100) {
      throw ArgumentError.value(
        query.pageSize,
        'pageSize',
        'Chỉ hỗ trợ từ 1 đến 100.',
      );
    }
    final employeeName = query.employeeName?.trim();
    if (employeeName != null && employeeName.length > 1000) {
      throw ArgumentError.value(
        query.employeeName,
        'employeeName',
        'Không được vượt quá 1000 ký tự.',
      );
    }
    final response = await _apiClient.get(
      '/api/order-reports',
      query: query.toQueryParameters(),
    );
    return _parse(() => OrderReportPage.fromJson(response));
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
