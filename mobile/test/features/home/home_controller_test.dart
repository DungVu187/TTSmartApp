import 'package:flutter_test/flutter_test.dart';
import 'package:ttsmart_mobile/core/models/data_scope.dart';
import 'package:ttsmart_mobile/core/models/time_range_preset.dart';
import 'package:ttsmart_mobile/features/home/data/models/dashboard_models.dart';
import 'package:ttsmart_mobile/features/home/data/repositories/home_repository.dart';
import 'package:ttsmart_mobile/features/home/presentation/controllers/home_controller.dart';

class _FakeHomeRepository implements HomeRepository {
  static const scopes = <DataScopeOption>[
    DataScopeOption(
      keyName: 'company',
      label: 'Toàn công ty',
      type: DataScopeType.company,
    ),
    DataScopeOption(
      keyName: 'station',
      label: 'Trạm A',
      type: DataScopeType.station,
    ),
  ];

  @override
  Future<List<DataScopeOption>> getAvailableScopes() async => scopes;

  @override
  Future<DashboardSnapshot> getDashboard({
    required DataScopeOption scope,
    required TimeRangePreset timeRange,
  }) async => DashboardSnapshot(
    scope: scope,
    timeRange: timeRange,
    updatedAt: DateTime.utc(2026, 7, 27),
    totalMixedVolume: 100,
    metrics: const <DashboardMetric>[],
    chartLabels: const <String>[],
    chartValues: const <double>[],
    stations: const <StationOverview>[],
    activities: const <DashboardActivity>[],
  );
}

void main() {
  test('HomeController đổi phạm vi và khoảng thời gian', () async {
    final controller = HomeController(_FakeHomeRepository());

    await controller.initialize();
    expect(controller.selectedScope?.keyName, 'company');
    expect(controller.snapshot?.scope.keyName, 'company');

    await controller.selectScope(_FakeHomeRepository.scopes.last);
    await controller.selectTimeRange(TimeRangePreset.thisMonth);

    expect(controller.snapshot?.scope.keyName, 'station');
    expect(controller.snapshot?.timeRange, TimeRangePreset.thisMonth);
    expect(controller.errorMessage, isNull);

    controller.dispose();
  });
}
