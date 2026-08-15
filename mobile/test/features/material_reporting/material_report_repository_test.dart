import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ttsmart_mobile/core/network/api_client.dart';
import 'package:ttsmart_mobile/features/material_reporting/data/models/material_report_models.dart';
import 'package:ttsmart_mobile/features/material_reporting/data/repositories/material_report_repository.dart';

void main() {
  test('parses FIFO values, nullable price and warnings', () {
    final report = MaterialReport.fromJson(_reportJson());

    expect(report.totals.inventoryQuantityKg, -20);
    expect(report.totals.inventoryValueVnd, 0);
    expect(report.groups.single.materials.single.hasMissingImportPrice, isTrue);
    expect(report.transactions.single.details.single.unitPriceVndPerKg, isNull);
    expect(report.warnings, ['Thiếu cột giá nhập.']);
  });

  test(
    'repository sends authorized station scope and fixed page size',
    () async {
      late Uri requestedUri;
      final client = ApiClient(
        baseUri: Uri.parse('https://example.test'),
        timeout: const Duration(seconds: 2),
        httpClient: MockClient((request) async {
          requestedUri = request.url;
          return http.Response(
            jsonEncode(_reportJson()),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      )..accessToken = 'test-token';
      addTearDown(client.close);

      final report = await ApiMaterialReportRepository(client).getReport(
        MaterialReportQuery(
          branchId: 10,
          companyId: 2,
          from: DateTime(2026, 8, 1),
          to: DateTime(2026, 8, 14, 23, 59),
          materialGroup: MaterialGroupFilter.cement,
          viewMode: MaterialViewMode.inventory,
          valueMode: MaterialValueMode.value,
          pageNumber: 3,
        ),
      );

      expect(report.stationId, 10);
      expect(requestedUri.path, '/api/material-reports');
      expect(requestedUri.queryParameters['companyId'], '2');
      expect(requestedUri.queryParameters['branchId'], '10');
      expect(requestedUri.queryParameters['materialGroup'], 'cement');
      expect(requestedUri.queryParameters['viewMode'], 'inventory');
      expect(requestedUri.queryParameters['valueMode'], 'value');
      expect(requestedUri.queryParameters['pageNumber'], '3');
      expect(requestedUri.queryParameters['pageSize'], '10');
      expect(requestedUri.queryParameters['from'], '2026-08-01T00:00:00+07:00');
    },
  );
}

Map<String, Object?> _reportJson() => <String, Object?>{
  'stationId': 10,
  'stationName': 'Trạm A',
  'from': '2026-07-31T17:00:00Z',
  'to': '2026-08-14T16:59:00Z',
  'inventoryAsOf': '2026-08-14T16:59:00Z',
  'materialGroup': 'all',
  'viewMode': 'all',
  'valueMode': 'quantity',
  'groups': [
    {
      'code': 'cement',
      'name': 'Xi măng',
      'materials': [
        {
          'materialCode': 1,
          'slotNumber': 1,
          'materialTypeId': 2,
          'name': 'Xi măng PCB40',
          'groupCode': 'cement',
          'importQuantityKg': 100,
          'exportQuantityKg': 120,
          'inventoryQuantityKg': -20,
          'importValueVnd': 400000,
          'exportValueVnd': 400000,
          'inventoryValueVnd': 0,
          'kilogramsPerCubicMeter': null,
          'kilogramsPerLiter': null,
          'hasMissingImportPrice': true,
        },
      ],
    },
  ],
  'chartItems': [
    {
      'materialCode': 1,
      'name': 'Xi măng PCB40',
      'groupCode': 'cement',
      'importQuantityKg': 100,
      'exportQuantityKg': 120,
      'inventoryQuantityKg': -20,
      'importValueVnd': 400000,
      'exportValueVnd': 400000,
      'inventoryValueVnd': 0,
    },
  ],
  'transactions': [
    {
      'rowNumber': 1,
      'id': 'PX-1',
      'occurredAt': '2026-08-14T03:00:00Z',
      'periodFrom': null,
      'periodTo': null,
      'type': 'export-manual',
      'content': 'Phiếu xuất kho',
      'importQuantityKg': 0,
      'exportQuantityKg': 120,
      'valueVnd': 400000,
      'note': null,
      'details': [
        {
          'materialCode': 1,
          'name': 'Xi măng PCB40',
          'quantityKg': 120,
          'valueVnd': 400000,
          'unitPriceVndPerKg': null,
          'conversionVolume': null,
          'conversionUnit': null,
          'conversionCoefficientKgPerUnit': null,
        },
      ],
    },
  ],
  'totalCount': 1,
  'totalPages': 1,
  'pageNumber': 1,
  'pageSize': 10,
  'fromRowNumber': 1,
  'toRowNumber': 1,
  'totals': {
    'importQuantityKg': 100,
    'exportQuantityKg': 120,
    'inventoryQuantityKg': -20,
    'importValueVnd': 400000,
    'exportValueVnd': 400000,
    'inventoryValueVnd': 0,
  },
  'warnings': ['Thiếu cột giá nhập.'],
};
