import '../../../../core/models/data_scope.dart';
import '../../../../core/models/time_range_preset.dart';
import '../models/report_models.dart';

abstract interface class ReportsRepository {
  Future<List<DataScopeOption>> getAvailableScopes();

  Future<ReportSnapshot> getReport({
    required DataScopeOption scope,
    required TimeRangePreset timeRange,
  });
}

class MockReportsRepository implements ReportsRepository {
  const MockReportsRepository();

  static const _scopes = <DataScopeOption>[
    DataScopeOption(
      keyName: 'all-company',
      label: 'Toàn công ty',
      type: DataScopeType.company,
    ),
    DataScopeOption(
      keyName: 'station-tan-phu',
      label: 'Trạm Tân Phú',
      type: DataScopeType.station,
    ),
    DataScopeOption(
      keyName: 'station-binh-chanh',
      label: 'Trạm Bình Chánh',
      type: DataScopeType.station,
    ),
  ];

  @override
  Future<List<DataScopeOption>> getAvailableScopes() async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    return _scopes;
  }

  @override
  Future<ReportSnapshot> getReport({
    required DataScopeOption scope,
    required TimeRangePreset timeRange,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    final isCompany = scope.type == DataScopeType.company;
    final multiplier = switch (timeRange) {
      TimeRangePreset.today => 1,
      TimeRangePreset.sevenDays => 6,
      TimeRangePreset.thisMonth => 24,
    };
    final scopeFactor = isCompany ? 1.0 : 0.42;
    final volume = 2450 * multiplier * scopeFactor;
    final orders = (128 * multiplier * scopeFactor).round();

    return ReportSnapshot(
      scope: scope,
      timeRange: timeRange,
      updatedAt: DateTime.now(),
      metrics: <ReportMetric>[
        ReportMetric(
          type: ReportMetricType.orders,
          label: 'Đơn hàng',
          value: '$orders',
          caption: 'Trong kỳ đã chọn',
        ),
        ReportMetric(
          type: ReportMetricType.mixedVolume,
          label: 'Sản lượng',
          value: '${_compact(volume)} m³',
          caption: 'Khối lượng đã trộn',
        ),
        const ReportMetric(
          type: ReportMetricType.completionRate,
          label: 'Hoàn thành',
          value: '92%',
          caption: 'Đơn giao đủ khối lượng',
        ),
        ReportMetric(
          type: ReportMetricType.activeStations,
          label: 'Trạm hoạt động',
          value: isCompany ? '6/7' : '1/1',
          caption: 'Trong phạm vi hiện tại',
        ),
      ],
      chartLabels: timeRange == TimeRangePreset.today
          ? const <String>['06h', '08h', '10h', '12h', '14h', '16h', '18h']
          : timeRange == TimeRangePreset.sevenDays
          ? const <String>['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN']
          : const <String>['Tuần 1', 'Tuần 2', 'Tuần 3', 'Tuần 4'],
      chartValues: timeRange == TimeRangePreset.today
          ? <double>[120, 280, 510, 760, 1180, 1850, volume]
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
      stationRows: isCompany
          ? const <StationReportRow>[
              StationReportRow(
                stationName: 'Trạm Tân Phú',
                orderCount: 46,
                mixedVolume: 890,
                completionRate: 0.96,
              ),
              StationReportRow(
                stationName: 'Trạm Bình Chánh',
                orderCount: 38,
                mixedVolume: 720,
                completionRate: 0.89,
              ),
              StationReportRow(
                stationName: 'Trạm Thủ Đức',
                orderCount: 31,
                mixedVolume: 650,
                completionRate: 0.93,
              ),
            ]
          : <StationReportRow>[
              StationReportRow(
                stationName: scope.label,
                orderCount: orders,
                mixedVolume: volume,
                completionRate: 0.93,
              ),
            ],
    );
  }

  static String _compact(double value) {
    if (value >= 1000) {
      final compact = value / 1000;
      return compact == compact.roundToDouble()
          ? '${compact.round()}K'
          : '${compact.toStringAsFixed(1)}K';
    }
    return value.round().toString();
  }
}
