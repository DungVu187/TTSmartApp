import 'package:flutter_test/flutter_test.dart';
import 'package:ttsmart_mobile/core/models/data_scope.dart';
import 'package:ttsmart_mobile/core/models/time_range_preset.dart';
import 'package:ttsmart_mobile/core/network/api_exception.dart';
import 'package:ttsmart_mobile/features/home/data/models/dashboard_models.dart';
import 'package:ttsmart_mobile/features/home/data/repositories/home_repository.dart';
import 'package:ttsmart_mobile/features/home/presentation/controllers/home_controller.dart';

class _FakeHomeRepository implements HomeRepository {
  final dashboardScopes = <DashboardScope?>[];

  static const scopes = <DashboardScope>[
    DashboardScope(
      keyName: 'company-1',
      label: 'Công ty A',
      type: DataScopeType.company,
      companyId: 1,
    ),
    DashboardScope(
      keyName: 'company-2',
      label: 'Công ty B',
      type: DataScopeType.company,
      companyId: 2,
    ),
    DashboardScope(
      keyName: 'station-10',
      label: 'Trạm A',
      type: DataScopeType.station,
      companyId: 1,
      branchId: 10,
    ),
    DashboardScope(
      keyName: 'station-20',
      label: 'Trạm B',
      type: DataScopeType.station,
      companyId: 2,
      branchId: 20,
    ),
  ];

  @override
  Future<List<DashboardScope>> getAvailableScopes() async => scopes;

  @override
  Future<DashboardSnapshot> getDashboard({
    required DashboardScope? scope,
    required TimeRangePreset timeRange,
  }) async {
    dashboardScopes.add(scope);
    return DashboardSnapshot(
      scope: scope,
      timeRange: timeRange,
      updatedAt: DateTime.utc(2026, 7, 27),
      totalMixedVolume: 100,
      metrics: const <DashboardMetric>[],
      chartLabels: const <String>[],
      chartValues: const <double>[],
      stations: const <StationOverview>[],
    );
  }
}

class _RetryHomeRepository extends _FakeHomeRepository {
  var scopeCallCount = 0;

  @override
  Future<List<DashboardScope>> getAvailableScopes() async {
    scopeCallCount++;
    if (scopeCallCount == 1) {
      throw const ApiException(
        type: ApiFailureType.server,
        message: 'Không đọc được phạm vi dashboard từ máy chủ.',
        statusCode: 500,
      );
    }
    return _FakeHomeRepository.scopes;
  }
}

void main() {
  test(
    'HomeController mặc định toàn quyền và liên kết trạm với công ty',
    () async {
      final repository = _FakeHomeRepository();
      final controller = HomeController(repository);

      await controller.initialize();
      expect(controller.selectedCompany, isNull);
      expect(controller.selectedStation, isNull);
      expect(controller.timeRange, TimeRangePreset.today);
      expect(controller.stationScopes.map((scope) => scope.keyName), [
        'station-10',
        'station-20',
      ]);
      expect(repository.dashboardScopes, <DashboardScope?>[null]);
      expect(controller.snapshot?.scope, isNull);

      await controller.selectStation(_FakeHomeRepository.scopes[3]);

      expect(controller.selectedCompany?.keyName, 'company-2');
      expect(controller.selectedStation?.keyName, 'station-20');
      expect(controller.snapshot?.scope?.keyName, 'station-20');

      await controller.clearStation();

      expect(controller.selectedStation, isNull);
      expect(controller.snapshot?.scope?.keyName, 'company-2');

      await controller.selectCompany(_FakeHomeRepository.scopes[0]);

      expect(controller.selectedCompany?.keyName, 'company-1');
      expect(controller.stationScopes.map((scope) => scope.keyName), [
        'station-10',
      ]);

      await controller.clearCompany();

      expect(controller.selectedCompany, isNull);
      expect(controller.selectedStation, isNull);
      expect(controller.stationScopes.map((scope) => scope.keyName), [
        'station-10',
        'station-20',
      ]);
      expect(controller.snapshot?.scope, isNull);
      expect(controller.errorMessage, isNull);

      controller.dispose();
    },
  );

  test('HomeController hiện lỗi API và tải lại scope khi retry', () async {
    final repository = _RetryHomeRepository();
    final controller = HomeController(repository);

    await controller.initialize();

    expect(
      controller.errorMessage,
      'Không đọc được phạm vi dashboard từ máy chủ.',
    );
    expect(controller.selectedScope, isNull);

    await controller.retry();

    expect(repository.scopeCallCount, 2);
    expect(controller.errorMessage, isNull);
    expect(controller.selectedCompany, isNull);
    expect(controller.selectedStation, isNull);
    expect(controller.snapshot, isNotNull);

    controller.dispose();
  });
}
