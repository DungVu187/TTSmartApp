import 'package:flutter_test/flutter_test.dart';
import 'package:ttsmart_mobile/features/mix_design_management/data/models/mix_design_models.dart';
import 'package:ttsmart_mobile/features/mix_design_management/presentation/widgets/mix_design_widgets.dart';

void main() {
  test('parses station and full mix design page contract', () {
    final station = MixDesignStation.fromJson({
      'stationId': 10,
      'stationName': 'Trạm Bình Chánh',
    });
    final page = MixDesignPage.fromJson({
      'items': [
        {
          'stt': 11,
          'concreteGradeName': 'M300',
          'strength': 300,
          'maxAggregate': 40,
          'slump': '12±2',
          'sand1': 400,
          'sand2': 0,
          'stone1': 500.25,
          'stone2': 600,
          'stone3': 0,
          'cement1': 250,
          'cement2': 150,
          'cement3': 0,
          'cement4': 0,
          'water': 150,
          'sika': 2.68,
          'tulog': 0,
          'sikaroad': 0,
          'bifi': 0,
        },
      ],
      'pageNumber': 2,
      'pageSize': 10,
      'totalCount': 12,
      'totalPages': 2,
    });

    expect(station.id, 10);
    expect(station.displayName, 'Trạm Bình Chánh');
    expect(page.pageNumber, 2);
    expect(page.items.single.stt, 11);
    expect(page.items.single.stone1, 500.25);
    expect(page.items.single.sika, 2.68);
    expect(formatMixDesignNumber(page.items.single.stone1), '500,25');
    expect(formatMixDesignNumber(0), '0');
  });

  test('keeps nullable grade name and validates query parameters', () {
    final item = MixDesignItem.fromJson({
      'stt': 1,
      'concreteGradeName': null,
      'strength': 0,
      'maxAggregate': 0,
      'slump': '0',
      'sand1': 0,
      'sand2': 0,
      'stone1': 0,
      'stone2': 0,
      'stone3': 0,
      'cement1': 0,
      'cement2': 0,
      'cement3': 0,
      'cement4': 0,
      'water': 0,
      'sika': 0,
      'tulog': 0,
      'sikaroad': 0,
      'bifi': 0,
    });
    const query = MixDesignQuery(companyId: 3, stationId: 10, pageNumber: 2);

    expect(item.concreteGradeName, isNull);
    expect(item.displayConcreteGradeName, 'Chưa đặt tên');
    expect(query.toQueryParameters(), {
      'companyId': 3,
      'stationId': 10,
      'pageNumber': 2,
    });
  });
}
