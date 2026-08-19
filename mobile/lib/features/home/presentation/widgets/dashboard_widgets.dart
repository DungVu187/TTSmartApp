import 'package:flutter/material.dart';

import '../../../../core/models/time_range_preset.dart';
import '../../../../core/widgets/simple_line_chart.dart';
import '../../data/models/dashboard_models.dart';

class DashboardMetricCard extends StatelessWidget {
  const DashboardMetricCard({super.key, required this.metric, this.onTap});

  final DashboardMetric metric;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = _toneFor(metric.type);
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tone.foreground.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              _iconFor(metric.type),
              size: 19,
              color: tone.foreground,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metric.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: const Color(0xFF334155),
                    fontWeight: FontWeight.w800,
                    height: 1.12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  metric.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF64748B),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            metric.value,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: tone.foreground,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
    return Material(
      key: ValueKey<String>('dashboard-metric-${metric.type.name}'),
      color: tone.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: tone.foreground.withValues(alpha: 0.18)),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? content
          : InkWell(
              onTap: onTap,
              splashColor: tone.foreground.withValues(alpha: 0.08),
              highlightColor: Colors.transparent,
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              child: content,
            ),
    );
  }

  IconData _iconFor(DashboardMetricType type) => switch (type) {
    DashboardMetricType.orders => Icons.receipt_long_outlined,
    DashboardMetricType.concreteGrades => Icons.science_outlined,
    DashboardMetricType.mixerTrucks => Icons.local_shipping_outlined,
    DashboardMetricType.salesWithOrders => Icons.groups_outlined,
  };

  ({Color background, Color foreground}) _toneFor(DashboardMetricType type) =>
      switch (type) {
        DashboardMetricType.orders => (
          background: const Color(0xFFEAF8FC),
          foreground: const Color(0xFF1389AA),
        ),
        DashboardMetricType.concreteGrades => (
          background: const Color(0xFFECF9F1),
          foreground: const Color(0xFF16845B),
        ),
        DashboardMetricType.mixerTrucks => (
          background: const Color(0xFFFFF8E1),
          foreground: const Color(0xFFB76A00),
        ),
        DashboardMetricType.salesWithOrders => (
          background: const Color(0xFFFFEFF1),
          foreground: const Color(0xFFC43D4B),
        ),
      };
}

class ProductionChartCard extends StatelessWidget {
  const ProductionChartCard({super.key, required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const ValueKey<String>('dashboard-production-chart'),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD6DCE4)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            color: const Color(0xFFF1F3F5),
            child: Row(
              children: [
                const Icon(
                  Icons.pie_chart_rounded,
                  size: 18,
                  color: Color(0xFF0F3554),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Khối lượng đã trộn',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: const Color(0xFF183B56),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  snapshot.timeRange.label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 34,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFB8C7).withValues(alpha: 0.8),
                        border: Border.all(
                          color: const Color(0xFFFF5F7E),
                          width: 2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Tổng khối lượng: '
                        '${_formatVolume(snapshot.totalMixedVolume)} m³',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF111827),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SimpleLineChart(
                  values: snapshot.chartValues,
                  labels: snapshot.chartLabels,
                  height: 250,
                  lineColor: const Color(0xFFFF5F7E),
                  fillColor: const Color(0xFFFFB8C7),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatVolume(double value) {
  var text = value.toStringAsFixed(3);
  text = text.replaceFirst(RegExp(r'\.?0+$'), '');
  final parts = text.split('.');
  final integer = parts.first;
  final buffer = StringBuffer();
  for (var index = 0; index < integer.length; index++) {
    if (index > 0 && (integer.length - index) % 3 == 0) buffer.write('.');
    buffer.write(integer[index]);
  }
  if (parts.length == 1) return buffer.toString();
  return '${buffer.toString()},${parts.last}';
}
