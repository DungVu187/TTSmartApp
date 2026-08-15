import '../../../../core/models/data_scope.dart';
import '../../../../core/models/time_range_preset.dart';
import '../../../../core/network/json_helpers.dart';

class DashboardScope extends DataScopeOption {
  const DashboardScope({
    required super.keyName,
    required super.label,
    required super.type,
    super.description,
    this.companyId,
    this.branchId,
  });

  final int? companyId;
  final int? branchId;

  factory DashboardScope.fromJson(Object? value) {
    final json = requireJsonObject(value, 'phạm vi dashboard');
    final typeValue = requireString(json, 'type');
    return DashboardScope(
      keyName: requireString(json, 'keyName'),
      label: requireString(json, 'label'),
      type: switch (typeValue) {
        'company' => DataScopeType.company,
        'station' => DataScopeType.station,
        _ => throw FormatException('type phạm vi dashboard không hợp lệ.'),
      },
      description: optionalString(json, 'description'),
      companyId: optionalInt(json, 'companyId'),
      branchId: optionalInt(json, 'branchId'),
    );
  }
}

enum DashboardMetricType {
  orders,
  concreteGrades,
  mixerTrucks,
  salesWithOrders,
}

class DashboardMetric {
  const DashboardMetric({
    required this.type,
    required this.label,
    required this.value,
    required this.caption,
  });

  final DashboardMetricType type;
  final String label;
  final String value;
  final String caption;
}

class StationOverview {
  const StationOverview({
    required this.id,
    required this.name,
    required this.isAvailable,
    required this.orderCount,
    required this.mixedVolume,
    required this.mixerTruckCount,
  });

  final String id;
  final String name;
  final bool isAvailable;
  final int orderCount;
  final double mixedVolume;
  final int mixerTruckCount;
}

class DashboardSnapshot {
  const DashboardSnapshot({
    required this.scope,
    required this.timeRange,
    required this.updatedAt,
    required this.totalMixedVolume,
    required this.metrics,
    required this.chartLabels,
    required this.chartValues,
    required this.stations,
    this.unavailableStationCount = 0,
  });

  final DataScopeOption? scope;
  final TimeRangePreset timeRange;
  final DateTime updatedAt;
  final double totalMixedVolume;
  final List<DashboardMetric> metrics;
  final List<String> chartLabels;
  final List<double> chartValues;
  final List<StationOverview> stations;
  final int unavailableStationCount;
}
