import '../../../../core/models/time_range_preset.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/json_helpers.dart';
import '../../../../core/utils/vietnam_time.dart';
import '../models/dashboard_models.dart';

abstract interface class HomeRepository {
  Future<List<DashboardScope>> getAvailableScopes();

  Future<DashboardSnapshot> getDashboard({
    required DashboardScope? scope,
    required TimeRangePreset timeRange,
  });
}

class ApiHomeRepository implements HomeRepository {
  ApiHomeRepository(this._apiClient, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final ApiClient _apiClient;
  final DateTime Function() _now;

  @override
  Future<List<DashboardScope>> getAvailableScopes() async {
    final response = await _apiClient.get('/api/dashboard/scopes');
    return _parse(
      () => requireJsonList(
        response,
        'phạm vi dashboard',
      ).map(DashboardScope.fromJson).toList(growable: false),
    );
  }

  @override
  Future<DashboardSnapshot> getDashboard({
    required DashboardScope? scope,
    required TimeRangePreset timeRange,
  }) async {
    final range = _rangeFor(timeRange, _now());
    final response = await _apiClient.get(
      '/api/dashboard',
      query: <String, Object?>{
        'companyId': scope?.companyId,
        'branchId': scope?.branchId,
        'from': formatVietnamIsoOffset(range.from),
        'to': formatVietnamIsoOffset(range.to),
        'interval': timeRange.usesHourlyBuckets ? 'hour' : 'day',
      },
    );
    return _parse(() => _snapshotFromJson(response, scope, timeRange));
  }

  DashboardSnapshot _snapshotFromJson(
    Object? value,
    DashboardScope? scope,
    TimeRangePreset timeRange,
  ) {
    final json = requireJsonObject(value, 'dashboard');
    final points = requireJsonList(json['volumePoints'], 'điểm biểu đồ')
        .map((value) {
          final point = requireJsonObject(value, 'điểm biểu đồ');
          return (
            label: requireString(point, 'label'),
            value: _requireDouble(point, 'mixedVolume'),
          );
        })
        .toList(growable: false);
    final stations = requireJsonList(json['stations'], 'tổng hợp trạm')
        .map((value) {
          final station = requireJsonObject(value, 'tổng hợp trạm');
          final available = requireBool(station, 'isAvailable');
          return StationOverview(
            id: requireInt(station, 'branchId').toString(),
            name: optionalString(station, 'stationName') ?? 'Trạm chưa đặt tên',
            isAvailable: available,
            orderCount: requireInt(station, 'orderCount'),
            mixedVolume: _requireDouble(station, 'mixedVolume'),
            mixerTruckCount: requireInt(station, 'mixerTruckCount'),
          );
        })
        .toList(growable: false);
    final unavailableStationCount = requireInt(json, 'unavailableStationCount');
    return DashboardSnapshot(
      scope: scope,
      timeRange: timeRange,
      updatedAt: requireUtcDateTime(json, 'updatedAt'),
      totalMixedVolume: _requireDouble(json, 'totalMixedVolume'),
      metrics: <DashboardMetric>[
        DashboardMetric(
          type: DashboardMetricType.orders,
          label: 'Đơn hàng',
          value: requireInt(json, 'orderCount').toString(),
          caption: timeRange.label,
        ),
        DashboardMetric(
          type: DashboardMetricType.concreteGrades,
          label: 'Mác bê tông',
          value: requireInt(json, 'concreteGradeCount').toString(),
          caption: timeRange.label,
        ),
        DashboardMetric(
          type: DashboardMetricType.mixerTrucks,
          label: 'Xe trộn',
          value: requireInt(json, 'mixerTruckCount').toString(),
          caption: timeRange.label,
        ),
        DashboardMetric(
          type: DashboardMetricType.salesWithOrders,
          label: 'Kinh doanh có đơn',
          value: requireInt(json, 'salesEmployeeCount').toString(),
          caption: timeRange.label,
        ),
      ],
      chartLabels: points.map((point) => point.label).toList(growable: false),
      chartValues: points.map((point) => point.value).toList(growable: false),
      stations: stations,
      unavailableStationCount: unavailableStationCount,
    );
  }

  ({DateTime from, DateTime to}) _rangeFor(
    TimeRangePreset preset,
    DateTime now,
  ) {
    final today = vietnamDateOnly(now);
    final thisWeek = today.subtract(Duration(days: today.weekday - 1));
    final thisMonth = DateTime(today.year, today.month);
    return switch (preset) {
      TimeRangePreset.today => (
        from: today,
        to: vietnamExclusiveDayAfter(today),
      ),
      TimeRangePreset.yesterday => (
        from: today.subtract(const Duration(days: 1)),
        to: today,
      ),
      TimeRangePreset.thisWeek => (
        from: thisWeek,
        to: thisWeek.add(const Duration(days: 7)),
      ),
      TimeRangePreset.lastWeek => (
        from: thisWeek.subtract(const Duration(days: 7)),
        to: thisWeek,
      ),
      TimeRangePreset.thisMonth => (
        from: thisMonth,
        to: DateTime(thisMonth.year, thisMonth.month + 1),
      ),
      TimeRangePreset.lastMonth => (
        from: DateTime(thisMonth.year, thisMonth.month - 1),
        to: thisMonth,
      ),
    };
  }

  double _requireDouble(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is num && value.isFinite) return value.toDouble();
    throw FormatException('$key phải là số.');
  }

  T _parse<T>(T Function() parser) {
    try {
      return parser();
    } on FormatException catch (error) {
      throw ApiException.invalidResponse(error.message);
    }
  }
}
