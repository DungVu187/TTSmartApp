import 'package:flutter_test/flutter_test.dart';
import 'package:ttsmart_mobile/features/reports/data/models/report_models.dart';

void main() {
  test('builds date-scoped filter option query', () {
    final query = OrderStatisticsFilterQuery(
      from: DateTime(2026, 8, 3, 6, 30),
      to: DateTime(2026, 8, 3, 17, 45),
      companyId: 3,
      branchId: 10,
    );

    expect(query.toQueryParameters(), {
      'companyId': 3,
      'branchId': 10,
      'from': '2026-08-03T06:30:00+07:00',
      'to': '2026-08-03T17:45:00+07:00',
    });
  });

  test('builds Vietnam offset query with fixed page size', () {
    final query = OrderStatisticsQuery(
      from: DateTime(2026, 8, 3),
      to: DateTime(2026, 8, 3, 8, 37, 36),
      companyId: 3,
      branchId: 10,
      viewMode: ReportViewMode.detail,
      pageNumber: 2,
      vehiclePlate: ' 51A-12345 ',
    );

    expect(query.toQueryParameters(), {
      'companyId': 3,
      'branchId': 10,
      'from': '2026-08-03T00:00:00+07:00',
      'to': '2026-08-03T08:37:36+07:00',
      'vehiclePlate': '51A-12345',
      'customerName': null,
      'concreteGradeName': null,
      'employeeName': null,
      'viewMode': 'detail',
      'pageNumber': 2,
      'pageSize': 10,
    });
  });

  test('parses the complete dynamic material contract', () {
    final page = OrderStatisticsPage.fromJson({
      'items': [
        {
          'rowNumber': 11,
          'stationId': 10,
          'stationCode': 'TRAM_10',
          'stationName': 'Trạm 10',
          'mixingDate': '2026-08-03',
          'startedAt': '2026-08-03T01:30:00Z',
          'finishedAt': '2026-08-03T01:45:00Z',
          'customerName': 'Khách hàng A',
          'projectName': 'Dự án A',
          'workItemName': 'Hạng mục A',
          'locationName': 'Vị trí A',
          'vehiclePlate': '51A-12345',
          'driverName': 'Tài xế A',
          'concreteGradeName': 'M250',
          'slump': '12±2',
          'salesEmployeeName': 'Nhân viên kinh doanh A',
          'employeeName': 'Nhân viên vận hành A',
          'layoutKey': 'layout-cat-da',
          'requestedVolume': 10.5,
          'mixedVolume': 9.75,
          'materials': [
            {
              'materialSlotId': 1,
              'slotNumber': 1,
              'materialName': 'Cát 3',
              'category': 'Cát',
              'categoryCode': 'CAT',
              'typePosition': 1,
              'columnKey': 'layout-cat-da:slot-1',
              'designQuantity': 100,
              'tQuantity': 101,
              'actualQuantity': 102,
              'variance': 2,
            },
          ],
        },
      ],
      'totalCount': 11,
      'totalPages': 2,
      'pageNumber': 2,
      'pageSize': 10,
      'fromRowNumber': 11,
      'toRowNumber': 11,
      'totalMaterialQuantity': 102,
      'totalConcreteVolume': 9.75,
      'layouts': [
        {
          'layoutKey': 'layout-cat-da',
          'columns': [
            {
              'materialSlotId': 1,
              'slotNumber': 1,
              'materialName': 'Cát 3',
              'category': 'Cát',
              'categoryCode': 'CAT',
              'typePosition': 1,
              'columnKey': 'layout-cat-da:slot-1',
              'designLabel': 'ĐM.Cát 3',
              'tLabel': 'T.Cát 3',
              'actualLabel': 'Cát 3',
              'varianceLabel': 'SS.Cát 3',
              'unit': 'kg',
            },
          ],
        },
      ],
      'materialSummaryRows': [
        {
          'rowNumber': 1,
          'cells': [
            {
              'categoryCode': 'CAT',
              'typePosition': 1,
              'materialSlotId': 1,
              'slotNumber': 1,
              'materialName': 'Cát 3',
              'category': 'Cát',
              'columnKey': 'summary:cat:1',
              'actualQuantity': 102,
              'unit': 'KG',
            },
            {
              'categoryCode': 'DA',
              'typePosition': 1,
              'materialSlotId': null,
              'slotNumber': null,
              'materialName': null,
              'category': 'Đá',
              'columnKey': null,
              'actualQuantity': null,
              'unit': 'KG',
            },
          ],
        },
      ],
    });

    expect(page.pageSize, 10);
    expect(page.items.single.rowNumber, 11);
    expect(page.items.single.stationCode, 'TRAM_10');
    expect(page.items.single.stationDisplayName, 'Trạm 10');
    expect(page.items.single.startedAt, DateTime.utc(2026, 8, 3, 1, 30));
    expect(page.items.single.layoutKey, 'layout-cat-da');
    expect(page.items.single.salesEmployeeName, 'Nhân viên kinh doanh A');
    expect(page.items.single.employeeName, 'Nhân viên vận hành A');

    final material = page.items.single.materials.single;
    expect(material.categoryCode, 'CAT');
    expect(material.typePosition, 1);
    expect(material.columnKey, 'layout-cat-da:slot-1');
    expect(material.actualQuantity, 102);

    final layout = page.layouts.single;
    expect(layout.layoutKey, 'layout-cat-da');
    final column = layout.columns.single;
    expect(column.categoryCode, 'CAT');
    expect(column.typePosition, 1);
    expect(column.columnKey, 'layout-cat-da:slot-1');
    expect(column.designLabel, 'ĐM.Cát 3');
    expect(column.tLabel, 'T.Cát 3');
    expect(column.actualLabel, 'Cát 3');
    expect(column.varianceLabel, 'SS.Cát 3');
    expect(column.unit, 'kg');

    final summaryRow = page.materialSummaryRows.single;
    expect(summaryRow.rowNumber, 1);
    expect(summaryRow.cells.first.columnKey, 'summary:cat:1');
    expect(summaryRow.cells.first.actualQuantity, 102);
    expect(summaryRow.cells.first.unit, 'KG');
    expect(summaryRow.cells.last.categoryCode, 'DA');
    expect(summaryRow.cells.last.materialSlotId, isNull);
    expect(summaryRow.cells.last.slotNumber, isNull);
    expect(summaryRow.cells.last.actualQuantity, 0);
    expect(summaryRow.cells.last.unit, 'KG');
  });

  test('station labels never expose code and use the required fallback', () {
    expect(
      const OrderStatisticsStation(
        id: 10,
        companyId: 3,
        name: 'Trạm Lam Sơn',
        typeTram: 1,
        companyName: 'Công ty A',
        code: 'LS01',
      ).displayName,
      'Trạm Lam Sơn',
    );
    expect(
      const OrderStatisticsStation(
        id: 11,
        companyId: 3,
        name: '   ',
        typeTram: 1,
        companyName: 'Công ty A',
        code: 'SECRET_CODE',
      ).displayName,
      'Chưa xác định',
    );
    expect(
      OrderStatisticsItem.fromJson({
        'rowNumber': 1,
        'stationId': 11,
        'stationCode': 'SECRET_CODE',
        'stationName': null,
        'requestedVolume': 0,
        'mixedVolume': 0,
        'materials': <Object>[],
      }).stationDisplayName,
      'Chưa xác định',
    );
  });

  test('parses response without optional dynamic contract fields', () {
    final page = OrderStatisticsPage.fromJson({
      'items': [
        {
          'rowNumber': 1,
          'stationId': 10,
          'stationName': 'Trạm 10',
          'mixingDate': '2026-08-03',
          'startedAt': null,
          'finishedAt': null,
          'customerName': null,
          'projectName': null,
          'workItemName': null,
          'locationName': null,
          'vehiclePlate': null,
          'driverName': null,
          'concreteGradeName': null,
          'slump': null,
          'employeeName': 'Nhân viên cũ',
          'requestedVolume': 1,
          'mixedVolume': 1,
          'materials': [
            {
              'materialSlotId': 1,
              'slotNumber': 1,
              'materialName': 'Cát cũ',
              'category': 'Cát',
              'tQuantity': null,
              'actualQuantity': 12,
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
      'totalMaterialQuantity': 12,
      'totalConcreteVolume': 1,
    });

    final item = page.items.single;
    expect(item.layoutKey, isEmpty);
    expect(item.salesEmployeeName, isNull);
    expect(item.employeeName, 'Nhân viên cũ');

    final material = item.materials.single;
    expect(material.categoryCode, isEmpty);
    expect(material.typePosition, 0);
    expect(material.columnKey, isEmpty);
    expect(material.designQuantity, 0);
    expect(material.tQuantity, 0);
    expect(material.actualQuantity, 12);
    expect(material.variance, 0);

    expect(page.layouts, isEmpty);
    expect(page.materialSummaryRows, isEmpty);
  });
}
