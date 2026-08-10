import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ttsmart_mobile/core/network/api_client.dart';
import 'package:ttsmart_mobile/features/reports/data/models/report_models.dart';
import 'package:ttsmart_mobile/features/reports/data/repositories/reports_repository.dart';

void main() {
  test('calls statistics endpoints with the backend contract', () async {
    final requests = <http.Request>[];
    final exportBytes = <int>[80, 75, 3, 4, 1, 2, 3];
    final client = ApiClient(
      baseUri: Uri.parse('http://localhost:5052'),
      timeout: const Duration(seconds: 1),
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/order-statistics/export') {
          return http.Response.bytes(
            exportBytes,
            200,
            headers: const {
              'content-type':
                  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
              'content-disposition':
                  'attachment; filename=thong-ke-don-hang.xlsx',
            },
          );
        }
        final body = switch (request.url.path) {
          '/api/order-statistics/stations' => jsonEncode([
            {
              'id': 10,
              'companyId': 3,
              'name': 'Trạm 10',
              'typeTram': 1,
              'companyName': 'Công ty 3',
            },
          ]),
          '/api/order-statistics/filters' => jsonEncode({
            'vehiclePlates': ['51A-12345'],
            'customerNames': ['Khách hàng A'],
            'concreteGradeNames': ['M250'],
            'employeeNames': ['Nhân viên A'],
          }),
          '/api/order-statistics' => jsonEncode(_emptyPage()),
          _ => throw StateError('Unexpected path ${request.url.path}'),
        };
        return http.Response.bytes(
          utf8.encode(body),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    )..accessToken = 'token';
    final repository = ApiReportsRepository(client);

    await repository.getStations(companyId: 3);
    final filterQuery = OrderStatisticsFilterQuery(
      from: DateTime(2026, 8, 3),
      to: DateTime(2026, 8, 3, 8, 37),
      companyId: 3,
      branchId: 10,
    );
    await repository.getFilterOptions(filterQuery);
    await repository.search(
      OrderStatisticsQuery(
        from: DateTime(2026, 8, 3),
        to: DateTime(2026, 8, 3, 8, 37),
        companyId: 3,
        branchId: 10,
        viewMode: ReportViewMode.total,
        pageNumber: 2,
      ),
    );
    final exportFile = await repository.export(
      OrderStatisticsExportQuery(
        from: DateTime(2026, 8, 3),
        to: DateTime(2026, 8, 3, 8, 37),
        companyId: 3,
        branchId: 10,
        vehiclePlate: ' 51A-12345 ',
        customerName: ' Customer A ',
        concreteGradeName: ' M250 ',
        employeeName: ' Employee A ',
      ),
    );

    expect(requests[0].url.queryParameters['companyId'], '3');
    expect(
      requests[1].url.queryParameters['from'],
      '2026-08-03T00:00:00+07:00',
    );
    expect(requests[1].url.queryParameters['to'], '2026-08-03T08:37:00+07:00');
    expect(requests[1].url.queryParameters['branchId'], '10');
    expect(requests[2].url.queryParameters['viewMode'], 'total');
    expect(requests[2].url.queryParameters['pageNumber'], '2');
    expect(requests[2].url.queryParameters['pageSize'], '10');
    expect(requests[3].method, 'GET');
    expect(requests[3].url.path, '/api/order-statistics/export');
    expect(requests[3].url.queryParameters, <String, String>{
      'companyId': '3',
      'branchId': '10',
      'from': '2026-08-03T00:00:00+07:00',
      'to': '2026-08-03T08:37:00+07:00',
      'vehiclePlate': '51A-12345',
      'customerName': 'Customer A',
      'concreteGradeName': 'M250',
      'employeeName': 'Employee A',
    });
    expect(requests[3].url.queryParameters, isNot(contains('viewMode')));
    expect(requests[3].url.queryParameters, isNot(contains('pageNumber')));
    expect(requests[3].url.queryParameters, isNot(contains('pageSize')));
    expect(
      requests[3].headers['Accept'],
      OrderStatisticsExportFile.defaultContentType,
    );
    expect(exportFile.bytes, orderedEquals(exportBytes));
    expect(exportFile.fileName, 'thong-ke-don-hang.xlsx');
    expect(
      exportFile.contentType,
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  });
}

Map<String, Object?> _emptyPage() => {
  'items': <Object?>[],
  'totalCount': 0,
  'totalPages': 0,
  'pageNumber': 1,
  'pageSize': 10,
  'fromRowNumber': 0,
  'toRowNumber': 0,
  'totalMaterialQuantity': 0,
  'totalConcreteVolume': 0,
  'layouts': <Object?>[],
  'materialSummaryRows': <Object?>[],
};
