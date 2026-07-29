import '../../../../core/models/data_scope.dart';
import '../../../../core/models/time_range_preset.dart';
import '../models/dashboard_models.dart';

abstract interface class HomeRepository {
  Future<List<DataScopeOption>> getAvailableScopes();

  Future<DashboardSnapshot> getDashboard({
    required DataScopeOption scope,
    required TimeRangePreset timeRange,
  });
}

class MockHomeRepository implements HomeRepository {
  const MockHomeRepository();

  static const _scopes = <DataScopeOption>[
    DataScopeOption(
      keyName: 'all-company',
      label: 'Toàn công ty',
      type: DataScopeType.company,
      description: 'Tổng hợp tất cả trạm được cấp quyền',
    ),
    DataScopeOption(
      keyName: 'station-tan-phu',
      label: 'Trạm Tân Phú',
      type: DataScopeType.station,
      description: 'Phạm vi một trạm',
    ),
    DataScopeOption(
      keyName: 'station-binh-chanh',
      label: 'Trạm Bình Chánh',
      type: DataScopeType.station,
      description: 'Phạm vi một trạm',
    ),
  ];

  @override
  Future<List<DataScopeOption>> getAvailableScopes() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return _scopes;
  }

  @override
  Future<DashboardSnapshot> getDashboard({
    required DataScopeOption scope,
    required TimeRangePreset timeRange,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    final isCompany = scope.type == DataScopeType.company;
    final rangeFactor = switch (timeRange) {
      TimeRangePreset.today => 1,
      TimeRangePreset.sevenDays => 6,
      TimeRangePreset.thisMonth => 24,
    };
    final scopeFactor = isCompany ? 1.0 : 0.42;
    final orderCount = (128 * rangeFactor * scopeFactor).round();
    final mixedVolume = 2450 * rangeFactor * scopeFactor;
    final now = DateTime.now();

    return DashboardSnapshot(
      scope: scope,
      timeRange: timeRange,
      updatedAt: now,
      totalMixedVolume: mixedVolume,
      metrics: <DashboardMetric>[
        DashboardMetric(
          type: DashboardMetricType.orders,
          label: 'Đơn hàng',
          value: '$orderCount',
          caption: timeRange.label,
        ),
        DashboardMetric(
          type: DashboardMetricType.concreteGrades,
          label: 'Mác bê tông',
          value: isCompany ? '12' : '7',
          caption: 'Đang sử dụng',
        ),
        DashboardMetric(
          type: DashboardMetricType.mixerTrucks,
          label: 'Xe trộn',
          value: isCompany ? '36' : '14',
          caption: 'Đang hoạt động',
        ),
        DashboardMetric(
          type: DashboardMetricType.salesWithOrders,
          label: 'Có đơn hàng',
          value: isCompany ? '18' : '8',
          caption: 'Nhân viên kinh doanh',
        ),
      ],
      chartLabels: timeRange == TimeRangePreset.today
          ? const <String>['06h', '08h', '10h', '12h', '14h', '16h', '18h']
          : timeRange == TimeRangePreset.sevenDays
          ? const <String>['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN']
          : const <String>['Tuần 1', 'Tuần 2', 'Tuần 3', 'Tuần 4'],
      chartValues: timeRange == TimeRangePreset.today
          ? <double>[120, 280, 510, 760, 1180, 1850, mixedVolume]
          : timeRange == TimeRangePreset.sevenDays
          ? <double>[
              2180,
              2460,
              2310,
              2740,
              2950,
              2560,
              2210,
            ].map((value) => value * scopeFactor).toList(growable: false)
          : <double>[
              14200,
              15650,
              14980,
              16840,
            ].map((value) => value * scopeFactor).toList(growable: false),
      stations: isCompany
          ? const <StationOverview>[
              StationOverview(
                id: 'tan-phu',
                name: 'Trạm Tân Phú',
                health: StationHealth.stable,
                orderCount: 8,
                mixedVolume: 420,
                activeVehicles: 6,
              ),
              StationOverview(
                id: 'binh-chanh',
                name: 'Trạm Bình Chánh',
                health: StationHealth.attention,
                orderCount: 3,
                mixedVolume: 180,
                activeVehicles: 4,
                alertCount: 1,
              ),
              StationOverview(
                id: 'thu-duc',
                name: 'Trạm Thủ Đức',
                health: StationHealth.stable,
                orderCount: 6,
                mixedVolume: 365,
                activeVehicles: 5,
              ),
            ]
          : <StationOverview>[
              StationOverview(
                id: scope.keyName,
                name: scope.label,
                health: StationHealth.stable,
                orderCount: 8,
                mixedVolume: 420,
                activeVehicles: 6,
              ),
            ],
      activities: <DashboardActivity>[
        DashboardActivity(
          type: DashboardActivityType.order,
          title: 'Đơn DH-1028 đã hoàn thành',
          description: 'Đã giao đủ 42 m³ tại Trạm Tân Phú',
          occurredAt: now.subtract(const Duration(minutes: 10)),
        ),
        DashboardActivity(
          type: DashboardActivityType.station,
          title: 'Bắt đầu trộn đơn DH-1031',
          description: 'Trạm Bình Chánh · Mác 300',
          occurredAt: now.subtract(const Duration(minutes: 25)),
        ),
        DashboardActivity(
          type: DashboardActivityType.report,
          title: 'Báo cáo ngày đã cập nhật',
          description: 'Số liệu tổng hợp theo phạm vi hiện tại',
          occurredAt: now.subtract(const Duration(minutes: 45)),
        ),
      ],
    );
  }
}
