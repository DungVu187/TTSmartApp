import '../../../../core/models/data_scope.dart';
import '../../../../core/models/time_range_preset.dart';

enum ReportMetricType { orders, mixedVolume, completionRate, activeStations }

class ReportMetric {
  const ReportMetric({
    required this.type,
    required this.label,
    required this.value,
    required this.caption,
  });

  final ReportMetricType type;
  final String label;
  final String value;
  final String caption;
}

class StationReportRow {
  const StationReportRow({
    required this.stationName,
    required this.orderCount,
    required this.mixedVolume,
    required this.completionRate,
  });

  final String stationName;
  final int orderCount;
  final double mixedVolume;
  final double completionRate;
}

class ReportSnapshot {
  const ReportSnapshot({
    required this.scope,
    required this.timeRange,
    required this.updatedAt,
    required this.metrics,
    required this.chartLabels,
    required this.chartValues,
    required this.stationRows,
  });

  final DataScopeOption scope;
  final TimeRangePreset timeRange;
  final DateTime updatedAt;
  final List<ReportMetric> metrics;
  final List<String> chartLabels;
  final List<double> chartValues;
  final List<StationReportRow> stationRows;
}
