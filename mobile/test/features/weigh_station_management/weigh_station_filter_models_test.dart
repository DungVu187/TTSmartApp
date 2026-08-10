import 'package:flutter_test/flutter_test.dart';
import 'package:ttsmart_mobile/features/weigh_station_management/data/models/weigh_station_filter_models.dart';

void main() {
  test('filter query không gửi stage khi chưa chọn giai đoạn', () {
    final query = WeighStationFilterQuery(
      branchId: 42,
      from: DateTime(2026, 8, 10),
      to: DateTime(2026, 8, 11),
    );

    expect(query.stage, isNull);
    expect(query.toQueryParameters(), isNot(contains('stage')));
  });

  test('search query giữ stage nullable khi đổi trang', () {
    final query = WeighStationSearchQuery(
      branchId: 42,
      from: DateTime(2026, 8, 10),
      to: DateTime(2026, 8, 11),
      pageNumber: 1,
    );

    final nextPage = query.withPageNumber(2);

    expect(nextPage.stage, isNull);
    expect(nextPage.pageNumber, 2);
    expect(nextPage.toQueryParameters(), isNot(contains('stage')));
    expect(
      nextPage.toQueryParameters(includePageNumber: false),
      isNot(contains('stage')),
    );
  });

  for (final testCase in <(WeighStationStage, String)>[
    (WeighStationStage.first, 'First'),
    (WeighStationStage.second, 'Second'),
  ]) {
    test('các query gửi đúng stage ${testCase.$2} khi người dùng chọn', () {
      final filterQuery = WeighStationFilterQuery(
        branchId: 42,
        stage: testCase.$1,
        from: DateTime(2026, 8, 10),
        to: DateTime(2026, 8, 11),
      );
      final searchQuery = WeighStationSearchQuery(
        branchId: 42,
        stage: testCase.$1,
        from: DateTime(2026, 8, 10),
        to: DateTime(2026, 8, 11),
        pageNumber: 1,
      );

      expect(filterQuery.toQueryParameters()['stage'], testCase.$2);
      expect(searchQuery.toQueryParameters()['stage'], testCase.$2);
      expect(
        searchQuery.toQueryParameters(includePageNumber: false)['stage'],
        testCase.$2,
      );
    });
  }
}
