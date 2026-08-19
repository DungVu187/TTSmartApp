import 'package:flutter_test/flutter_test.dart';
import 'package:ttsmart_mobile/features/order_reporting/data/models/order_report_models.dart';

void main() {
  test(
    'parses order report response with nullable fields and decimal totals',
    () {
      final page = OrderReportPage.fromJson({
        'items': [
          {
            'orderId': 101,
            'companyId': 3,
            'companyName': 'Company 3',
            'branchId': 10,
            'stationCode': 'TRAM_10',
            'stationName': 'Trạm 10',
            'customerName': 'Khách hàng A',
            'projectName': null,
            'concreteGradeName': 'M250',
            'orderedVolume': 24.5,
            'producedVolume': 20.333,
            'orderedAtUtc': '2026-07-31T03:00:00Z',
            'employeeName': 'Nguyễn Văn A',
          },
        ],
        'pageNumber': 1,
        'pageSize': 20,
        'totalCount': 1,
        'totalPages': 1,
        'totalOrderedVolume': 24.5,
        'totalProducedVolume': 20.333,
        'stationSummaries': [
          {
            'branchId': 10,
            'companyId': 3,
            'companyName': 'Company 3',
            'stationCode': 'TRAM_10',
            'stationName': 'Station 10',
            'orderCount': 1,
            'orderedVolume': 24.5,
            'producedVolume': 20.333,
          },
        ],
        'isPartial': true,
        'successfulStationCount': 1,
        'unavailableStationCount': 1,
        'unavailableStations': [
          {
            'branchId': 20,
            'companyId': 3,
            'companyName': 'Company 3',
            'stationCode': 'TRAM_20',
            'stationName': 'Station 20',
          },
        ],
      });

      expect(page.items.single.orderId, 101);
      expect(page.items.single.projectName, isNull);
      expect(page.items.single.orderedAtUtc, DateTime.utc(2026, 7, 31, 3));
      expect(page.totalOrderedVolume, 24.5);
      expect(page.totalProducedVolume, 20.333);
      expect(page.items.single.companyName, 'Company 3');
      expect(page.items.single.stationDisplayName, 'TRAM_10 • Trạm 10');
      expect(page.stationSummaries.single.orderCount, 1);
      expect(page.stationSummaries.single.displayName, 'TRAM_10 • Station 10');
      expect(page.isPartial, isTrue);
      expect(page.successfulStationCount, 1);
      expect(page.unavailableStationCount, 1);
      expect(
        page.unavailableStations.single.scopedDisplayName,
        'Company 3 • TRAM_20 • Station 20',
      );
    },
  );

  test('parses and displays station code from station lookup', () {
    final station = OrderReportStation.fromJson({
      'id': 10,
      'companyId': 3,
      'code': 'TRAM_10',
      'name': 'Trạm 10',
      'typeTram': 1,
      'companyName': 'Company 3',
    });

    expect(station.displayName, 'TRAM_10 • Trạm 10');
    expect(station.scopedDisplayName, 'Company 3 • TRAM_10 • Trạm 10');
  });

  test('keeps station display compatible with legacy responses', () {
    final legacyItem = OrderReportItem.fromJson({
      'orderId': 101,
      'branchId': 10,
      'stationName': 'Trạm cũ',
    });

    expect(legacyItem.stationCode, isNull);
    expect(legacyItem.stationDisplayName, 'Trạm cũ');
    expect(
      const OrderReportStation(
        id: 11,
        companyId: null,
        name: null,
        typeTram: null,
        code: 'TRAM_11',
      ).displayName,
      'TRAM_11',
    );
    expect(
      const OrderReportStation(
        id: 12,
        companyId: null,
        name: null,
        typeTram: null,
      ).displayName,
      'Trạm #12',
    );
  });

  test('formats report boundaries with Vietnam offset', () {
    final query = OrderReportQuery(
      branchId: 10,
      fromDate: DateTime(2026, 7, 1),
      toDate: DateTime(2026, 7, 31),
      employeeName: ' Nguyễn Văn A ',
    );

    expect(query.toQueryParameters(), {
      'branchId': 10,
      'from': '2026-07-01T00:00:00+07:00',
      'to': '2026-07-31T00:00:00+07:00',
      'employeeName': 'Nguyễn Văn A',
      'pageNumber': 1,
      'pageSize': 10,
    });
  });
}
