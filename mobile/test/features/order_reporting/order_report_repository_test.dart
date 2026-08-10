import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ttsmart_mobile/core/network/api_client.dart';
import 'package:ttsmart_mobile/features/order_reporting/data/models/order_report_models.dart';
import 'package:ttsmart_mobile/features/order_reporting/data/repositories/order_report_repository.dart';

http.Response _jsonResponse(Object value) =>
    http.Response.bytes(utf8.encode(jsonEncode(value)), 200);

void main() {
  test('sends authorized station, employee and report queries', () async {
    final requests = <http.Request>[];
    final client = ApiClient(
      baseUri: Uri.parse('http://localhost:5052'),
      timeout: const Duration(seconds: 1),
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/stations')) {
          return _jsonResponse([
            {'id': 10, 'companyId': 3, 'name': 'Trạm 10', 'typeTram': 1},
          ]);
        }
        if (request.url.path.endsWith('/employees')) {
          return _jsonResponse([
            {'name': 'Nguyễn Văn A'},
          ]);
        }
        return _jsonResponse({
          'items': <Object?>[],
          'pageNumber': 2,
          'pageSize': 10,
          'totalCount': 0,
          'totalPages': 0,
          'totalOrderedVolume': 0,
          'totalProducedVolume': 0,
          'stationSummaries': <Object?>[],
          'isPartial': false,
          'successfulStationCount': 1,
          'unavailableStationCount': 0,
          'unavailableStations': <Object?>[],
        });
      }),
    )..accessToken = 'token';
    final repository = ApiOrderReportRepository(client);

    await repository.getStations(companyId: 3);
    await repository.getEmployees(
      branchId: 10,
      companyId: 3,
      fromDate: DateTime(2026, 7, 1),
      toDate: DateTime(2026, 7, 31),
    );
    await repository.search(
      OrderReportQuery(
        branchId: 10,
        companyId: 3,
        fromDate: DateTime(2026, 7, 1),
        toDate: DateTime(2026, 7, 31),
        employeeName: ' Nguyễn Văn A ',
        pageNumber: 2,
      ),
    );

    expect(requests[0].url.path, '/api/order-reports/stations');
    expect(requests[0].url.queryParameters, {'companyId': '3'});
    expect(requests[1].url.path, '/api/order-reports/employees');
    expect(requests[1].url.queryParameters, {
      'branchId': '10',
      'companyId': '3',
      'from': '2026-07-01T00:00:00+07:00',
      'to': '2026-07-31T00:00:00+07:00',
    });
    expect(requests[2].url.path, '/api/order-reports');
    expect(requests[2].url.queryParameters, {
      'branchId': '10',
      'companyId': '3',
      'from': '2026-07-01T00:00:00+07:00',
      'to': '2026-07-31T00:00:00+07:00',
      'employeeName': 'Nguyễn Văn A',
      'pageNumber': '2',
      'pageSize': '10',
    });
  });
}
