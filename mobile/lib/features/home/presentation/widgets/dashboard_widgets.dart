import 'package:flutter/material.dart';

import '../../../../core/models/time_range_preset.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_time_format.dart';
import '../../../../core/widgets/simple_line_chart.dart';
import '../../data/models/dashboard_models.dart';

class DashboardMetricCard extends StatelessWidget {
  const DashboardMetricCard({super.key, required this.metric});

  final DashboardMetric metric;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = _toneFor(metric.type, theme.colorScheme);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: tone.background,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(_iconFor(metric.type), color: tone.foreground),
            ),
            const Spacer(),
            Text(
              metric.value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              metric.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              metric.caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(DashboardMetricType type) => switch (type) {
    DashboardMetricType.orders => Icons.receipt_long_outlined,
    DashboardMetricType.concreteGrades => Icons.science_outlined,
    DashboardMetricType.mixerTrucks => Icons.local_shipping_outlined,
    DashboardMetricType.salesWithOrders => Icons.groups_outlined,
  };

  ({Color background, Color foreground}) _toneFor(
    DashboardMetricType type,
    ColorScheme colors,
  ) => switch (type) {
    DashboardMetricType.orders => (
      background: colors.primaryContainer,
      foreground: colors.onPrimaryContainer,
    ),
    DashboardMetricType.concreteGrades => (
      background: const Color(0xFFDDF4EC),
      foreground: AppColors.success,
    ),
    DashboardMetricType.mixerTrucks => (
      background: const Color(0xFFFFEBC8),
      foreground: AppColors.warning,
    ),
    DashboardMetricType.salesWithOrders => (
      background: const Color(0xFFFBE0E3),
      foreground: AppColors.danger,
    ),
  };
}

class ProductionChartCard extends StatelessWidget {
  const ProductionChartCard({super.key, required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Khối lượng đã trộn',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_formatVolume(snapshot.totalMixedVolume)} m³',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    snapshot.timeRange.label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SimpleLineChart(
              values: snapshot.chartValues,
              labels: snapshot.chartLabels,
            ),
          ],
        ),
      ),
    );
  }

  String _formatVolume(double value) {
    final digits = value.round().toString();
    final buffer = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) buffer.write('.');
      buffer.write(digits[index]);
    }
    return buffer.toString();
  }
}

class StationOverviewCard extends StatelessWidget {
  const StationOverviewCard({super.key, required this.station});

  final StationOverview station;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = _stationTone(station.health);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: tone.background,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.factory_outlined, color: tone.foreground),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        station.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StationStatusBadge(health: station.health),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  '${station.orderCount} đơn · '
                  '${station.mixedVolume.round()} m³ · '
                  '${station.activeVehicles} xe hoạt động',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (station.alertCount > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${station.alertCount} cảnh báo cần kiểm tra',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  ({Color background, Color foreground}) _stationTone(StationHealth health) =>
      switch (health) {
        StationHealth.stable => (
          background: const Color(0xFFDDF4EC),
          foreground: AppColors.success,
        ),
        StationHealth.attention => (
          background: const Color(0xFFFFEBC8),
          foreground: AppColors.warning,
        ),
        StationHealth.offline => (
          background: const Color(0xFFFBE0E3),
          foreground: AppColors.danger,
        ),
      };
}

class _StationStatusBadge extends StatelessWidget {
  const _StationStatusBadge({required this.health});

  final StationHealth health;

  @override
  Widget build(BuildContext context) {
    final (label, color, background) = switch (health) {
      StationHealth.stable => (
        'Ổn định',
        AppColors.success,
        const Color(0xFFDDF4EC),
      ),
      StationHealth.attention => (
        'Chú ý',
        AppColors.warning,
        const Color(0xFFFFEBC8),
      ),
      StationHealth.offline => (
        'Ngoại tuyến',
        AppColors.danger,
        const Color(0xFFFBE0E3),
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class DashboardActivityTile extends StatelessWidget {
  const DashboardActivityTile({super.key, required this.activity});

  final DashboardActivity activity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: theme.colorScheme.secondaryContainer,
            foregroundColor: theme.colorScheme.onSecondaryContainer,
            child: Icon(_activityIcon(activity.type), size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  activity.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatTime(activity.occurredAt),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  IconData _activityIcon(DashboardActivityType type) => switch (type) {
    DashboardActivityType.order => Icons.receipt_long_outlined,
    DashboardActivityType.station => Icons.factory_outlined,
    DashboardActivityType.report => Icons.query_stats_outlined,
    DashboardActivityType.alert => Icons.warning_amber_outlined,
  };

  String _formatTime(DateTime value) {
    final formatted = formatLocalDateTime(value);
    return formatted.substring(formatted.length - 5);
  }
}

class QuickActionButton extends StatelessWidget {
  const QuickActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
