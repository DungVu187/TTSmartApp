import 'package:flutter_test/flutter_test.dart';
import 'package:ttsmart_mobile/features/weigh_station_management/data/models/weigh_station_result_models.dart';

void main() {
  test('chi tiết parse số thập phân và giữ nguyên nullable', () {
    final page = WeighStationPage.fromJson({
      'items': [
        {
          'stt': 1,
          'id': '11111111-1111-1111-1111-111111111111',
          'ticketNumber': 10,
          'goodsWeightKg': 1000,
          'hasConversionConfiguration': true,
          'convertedQuantity': 28.09,
          'conversionMessage': null,
          'convertedUnit': 'tấn',
          'materialValueVnd': null,
        },
        {
          'stt': 2,
          'id': '22222222-2222-2222-2222-222222222222',
          'ticketNumber': 11,
          'goodsWeightKg': null,
          'hasConversionConfiguration': false,
          'convertedQuantity': null,
          'conversionMessage': '  Ch\u01b0a x\u00e1c \u0111\u1ecbnh  ',
          'convertedUnit': null,
          'materialValueVnd': null,
        },
      ],
      'pageNumber': 1,
      'pageSize': 10,
      'totalCount': 2,
      'totalPages': 1,
      'canViewMaterialValue': false,
    });

    expect(page.items.first.goodsWeightKg, 1000);
    expect(page.items.first.convertedQuantity, closeTo(28.09, 0.000001));
    expect(page.items.first.conversionMessage, isNull);
    expect(page.items.first.convertedUnit, 'tấn');
    expect(page.items.last.goodsWeightKg, isNull);
    expect(page.items.last.convertedQuantity, isNull);
    expect(
      page.items.last.conversionMessage,
      'Ch\u01b0a x\u00e1c \u0111\u1ecbnh',
    );
    expect(page.items.last.convertedUnit, isNull);
    expect(page.items.last.materialValueVnd, isNull);
  });

  test('summary parse nhiều đơn vị đúng thứ tự và label backend', () {
    final summary = WeighStationSummary.fromJson({
      'items': [
        {
          'stt': 1,
          'goodsName': 'Đá 1x2',
          'goodsWeightKg': 4132780,
          'ticketCount': 3,
          'convertedQuantities': [
            {'quantity': 4070.75, 'unit': 'tấn'},
            {'quantity': 62030, 'unit': 'L'},
          ],
          'materialValueVnd': null,
        },
      ],
      'pageNumber': 1,
      'pageSize': 10,
      'totalCount': 1,
      'totalPages': 1,
      'totalGoodsWeightKg': 4132780,
      'totalConvertedQuantities': [
        {'quantity': 4070.75, 'unit': 'tấn'},
        {'quantity': 62030, 'unit': 'L'},
        {'quantity': 1.350, 'unit': 'm³'},
      ],
      'topGoods': {'goodsName': 'Đá 1x2', 'goodsWeightKg': 4132780},
      'groups': [
        {
          'key': 'NHAP_CAT_DA',
          'label': 'Nhãn backend cho Đá 1x2',
          'goodsWeightKg': 4132780,
          'convertedQuantities': [
            {'quantity': 4070.75, 'unit': 'tấn'},
            {'quantity': 62030, 'unit': 'L'},
          ],
          'materialValueVnd': null,
        },
      ],
      'totalMaterialValueVnd': null,
      'canViewMaterialValue': false,
    });

    expect(
      summary.totalConvertedQuantities.map((value) => value.unit),
      orderedEquals(['tấn', 'L', 'm³']),
    );
    expect(summary.totalConvertedQuantities[0].quantity, 4070.75);
    expect(summary.totalConvertedQuantities[1].quantity, 62030);
    expect(summary.totalConvertedQuantities[2].quantity, 1.35);
    expect(summary.items.single.ticketCount, 3);
    expect(summary.groups.single.keyName, 'NHAP_CAT_DA');
    expect(summary.groups.single.label, 'Nhãn backend cho Đá 1x2');
    expect(summary.totalMaterialValueVnd, isNull);
  });

  test('summary defaults missing or null groups to an empty list', () {
    Map<String, Object?> summaryJson() => {
      'items': <Object?>[],
      'pageNumber': 1,
      'pageSize': 10,
      'totalCount': 0,
      'totalPages': 0,
      'totalGoodsWeightKg': 1590590,
      'totalConvertedQuantities': [
        {'quantity': 1587.45, 'unit': 't\u1ea5n'},
        {'quantity': 3140, 'unit': 'L'},
      ],
      'topGoods': null,
      'totalMaterialValueVnd': null,
      'canViewMaterialValue': false,
    };

    final missingGroups = WeighStationSummary.fromJson(summaryJson());
    final nullGroups = WeighStationSummary.fromJson({
      ...summaryJson(),
      'groups': null,
    });

    expect(missingGroups.groups, isEmpty);
    expect(nullGroups.groups, isEmpty);
    expect(missingGroups.totalGoodsWeightKg, 1590590);
    expect(
      missingGroups.totalConvertedQuantities.map((value) => value.unit),
      orderedEquals(['t\u1ea5n', 'L']),
    );
    expect(missingGroups.totalConvertedQuantities[0].quantity, 1587.45);
    expect(missingGroups.totalConvertedQuantities[1].quantity, 3140);
  });

  test('summary item parses and trims conversionMessage', () {
    final item = WeighStationSummaryItem.fromJson({
      'stt': 1,
      'goodsName': 'Xi Mang Roi PCB40',
      'goodsWeightKg': 280010,
      'convertedQuantities': <Object?>[],
      'conversionMessage': '  Ch\u01b0a x\u00e1c \u0111\u1ecbnh  ',
      'materialValueVnd': null,
    });

    expect(item.conversionMessage, 'Ch\u01b0a x\u00e1c \u0111\u1ecbnh');
    expect(item.convertedQuantities, isEmpty);
  });

  test('empty conversionMessage becomes null', () {
    final item = WeighStationSummaryItem.fromJson({
      'stt': 1,
      'goodsWeightKg': 1000,
      'convertedQuantities': <Object?>[],
      'conversionMessage': '   ',
    });

    expect(item.conversionMessage, isNull);
  });

  test('legacy responses without conversionMessage still parse', () {
    final page = WeighStationPage.fromJson({
      'items': [
        {
          'stt': 1,
          'id': '33333333-3333-3333-3333-333333333333',
          'ticketNumber': 12,
          'hasConversionConfiguration': false,
          'convertedQuantity': null,
          'convertedUnit': null,
        },
      ],
      'pageNumber': 1,
      'pageSize': 10,
      'totalCount': 1,
      'totalPages': 1,
      'canViewMaterialValue': false,
    });
    final summaryItem = WeighStationSummaryItem.fromJson({
      'stt': 1,
      'goodsWeightKg': 280010,
      'convertedQuantities': <Object?>[],
    });

    expect(page.items.single.conversionMessage, isNull);
    expect(summaryItem.conversionMessage, isNull);
  });
}
