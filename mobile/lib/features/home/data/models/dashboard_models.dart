import '../../../../core/models/data_scope.dart';
import '../../../../core/models/time_range_preset.dart';

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

enum StationHealth { stable, attention, offline }

class StationOverview {
  const StationOverview({
    required this.id,
    required this.name,
    required this.health,
    required this.orderCount,
    required this.mixedVolume,
    required this.activeVehicles,
    this.alertCount = 0,
  });

  final String id;
  final String name;
  final StationHealth health;
  final int orderCount;
  final double mixedVolume;
  final int activeVehicles;
  final int alertCount;
}

enum DashboardActivityType { order, station, report, alert }

class DashboardActivity {
  const DashboardActivity({
    required this.type,
    required this.title,
    required this.description,
    required this.occurredAt,
  });

  final DashboardActivityType type;
  final String title;
  final String description;
  final DateTime occurredAt;
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
    required this.activities,
  });

  final DataScopeOption scope;
  final TimeRangePreset timeRange;
  final DateTime updatedAt;
  final double totalMixedVolume;
  final List<DashboardMetric> metrics;
  final List<String> chartLabels;
  final List<double> chartValues;
  final List<StationOverview> stations;
  final List<DashboardActivity> activities;
}
