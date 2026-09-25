import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/ui/app_ui.dart';
import '../../data/models/dashboard_models.dart';

const _cardShadow = [
  BoxShadow(color: Color(0x0D0F172A), blurRadius: 10, offset: Offset(0, 2)),
];

/// KPI card of Figma "02 Home": tinted icon tile, 20px value, 11px label.
class DashboardMetricCard extends StatelessWidget {
  const DashboardMetricCard({super.key, required this.metric, this.onTap});

  final DashboardMetric metric;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (fg, bg) = p.tone(_toneFor(metric.type));
    return DecoratedBox(
      key: ValueKey<String>('dashboard-metric-${metric.type.name}'),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border),
        boxShadow: _cardShadow,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_iconFor(metric.type), size: 18, color: fg),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        metric.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: p.text1,
                          fontSize: 20,
                          height: 24 / 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        // Last two words stay together when the label wraps
                        // ("Xe bồn / hoạt động", not "Xe bồn hoạt / động").
                        _keepLastWords(metric.label),
                        // A third line only with a larger system font; the
                        // grid cell grows for it (home_screen.dart).
                        maxLines:
                            MediaQuery.textScalerOf(context).scale(10) > 11.5
                            ? 3
                            : 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: p.text2,
                          fontSize: 12,
                          height: 15 / 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _keepLastWords(String label) {
    final last = label.lastIndexOf(' ');
    return last <= 0
        ? label
        : '${label.substring(0, last)} ${label.substring(last + 1)}';
  }

  static IconData _iconFor(DashboardMetricType type) => switch (type) {
    DashboardMetricType.orders => LucideIcons.clipboardList,
    DashboardMetricType.concreteGrades => LucideIcons.flaskConical,
    DashboardMetricType.mixerTrucks => LucideIcons.truck,
    DashboardMetricType.salesWithOrders => LucideIcons.users,
  };

  static AppTone _toneFor(DashboardMetricType type) => switch (type) {
    DashboardMetricType.orders => AppTone.info,
    DashboardMetricType.concreteGrades => AppTone.success,
    DashboardMetricType.mixerTrucks => AppTone.warning,
    DashboardMetricType.salesWithOrders => AppTone.danger,
  };
}

/// "Tổng khối lượng" + area chart of the mixed volume.
class ProductionChartCard extends StatelessWidget {
  const ProductionChartCard({super.key, required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      key: const ValueKey<String>('dashboard-production-chart'),
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 11),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border),
        boxShadow: _cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tổng khối lượng',
            style: TextStyle(
              color: p.text2,
              fontSize: 12,
              height: 15 / 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: formatDashboardVolume(snapshot.totalMixedVolume),
                  style: TextStyle(
                    color: p.text1,
                    fontSize: 22,
                    height: 27 / 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                TextSpan(
                  text: ' m³',
                  style: TextStyle(
                    color: p.text2,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          AreaTrendChart(
            values: snapshot.chartValues,
            labels: snapshot.chartLabels,
          ),
        ],
      ),
    );
  }
}

/// Smooth line over a fading area, 3 grid lines, a dot on the last point and
/// up to 7 x-axis labels (Figma chart of "02 Home").
class AreaTrendChart extends StatelessWidget {
  const AreaTrendChart({
    super.key,
    required this.values,
    required this.labels,
    this.height = 104,
  });

  final List<double> values;
  final List<String> labels;
  final double height;

  /// Indices that get an x-axis label, ~6 evenly spaced. Numeric labels are
  /// picked on round values: 24 hours → 00H 04H 08H 12H 16H 20H, 30 days →
  /// 01 05 10 15 20 25 30. Other labels: the first, every ~n/6th, the last.
  static List<int> labelIndices(List<String> labels) {
    final count = labels.length;
    if (count <= 0) return const [];
    if (count > 7) {
      final step = math.max(1, (count / 6).round());
      // Only plain hour / day numbers ("07H", "15"), not dates ("15/09").
      final single = RegExp(r'^\D*(\d{1,2})\D*$');
      final numbers = [
        for (final label in labels)
          int.tryParse(single.firstMatch(label)?.group(1) ?? ''),
      ];
      if (numbers.every((number) => number != null)) {
        final picked = <int>[
          for (var index = 0; index < count; index++)
            if (numbers[index]! % step == 0) index,
        ];
        // Days start at 01: keep the first one as the left anchor.
        if (picked.isEmpty || picked.first != 0) picked.insert(0, 0);
        if (picked.length >= 3) return picked;
      }
    }
    return _evenIndices(count);
  }

  static List<int> _evenIndices(int count) {
    if (count <= 7) return [for (var index = 0; index < count; index++) index];
    final step = math.max(1, (count / 6).round());
    final indices = <int>{0};
    for (var index = step - 1; index < count; index += step) {
      indices.add(index);
    }
    indices.add(count - 1);
    final sorted = indices.toList()..sort();
    // Drop a label that would sit right next to the last one.
    if (sorted.length > 2 && sorted.last - sorted[sorted.length - 2] < step) {
      sorted.removeAt(sorted.length - 2);
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (values.isEmpty) {
      return SizedBox(
        height: height + 20,
        child: Center(
          child: Text(
            'Chưa có dữ liệu trong khoảng thời gian này',
            style: TextStyle(color: p.text3, fontSize: 12),
          ),
        ),
      );
    }
    final indices = labelIndices(labels);
    return Column(
      children: [
        SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: _AreaTrendPainter(
              values: values,
              line: p.primary,
              grid: p.border,
              dotBorder: p.surface,
            ),
          ),
        ),
        const SizedBox(height: 8),
        MediaQuery.withClampedTextScaling(
          // Axis labels overlap if they grow with the system font.
          maxScaleFactor: 1.1,
          child: SizedBox(
            height: 17,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final style = TextStyle(
                  color: p.text3,
                  fontSize: 12,
                  height: 15 / 12,
                  fontWeight: FontWeight.w600,
                );
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (final index in indices)
                      if (index < labels.length)
                        _AxisLabel(
                          text: labels[index],
                          x: values.length == 1
                              ? 0
                              : width * index / (values.length - 1),
                          width: width,
                          style: style,
                        ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _AxisLabel extends StatelessWidget {
  const _AxisLabel({
    required this.text,
    required this.x,
    required this.width,
    required this.style,
  });

  final String text;
  final double x;
  final double width;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    const box = 36.0;
    final left = (x - box / 2)
        .clamp(0.0, math.max(0.0, width - box))
        .toDouble();
    final alignment = x < box / 2
        ? Alignment.centerLeft
        : x > width - box / 2
        ? Alignment.centerRight
        : Alignment.center;
    return Positioned(
      left: left,
      width: box,
      top: 0,
      bottom: 0,
      child: Align(
        alignment: alignment,
        child: Text(text, maxLines: 1, style: style),
      ),
    );
  }
}

class _AreaTrendPainter extends CustomPainter {
  _AreaTrendPainter({
    required this.values,
    required this.line,
    required this.grid,
    required this.dotBorder,
  });

  final List<double> values;
  final Color line;
  final Color grid;
  final Color dotBorder;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final fraction in const [24 / 104, 52 / 104, 80 / 104]) {
      final y = size.height * fraction;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    final maxValue = values.fold<double>(0, math.max);
    // Leave ~20% headroom above the highest point, like the Figma chart.
    final top = maxValue <= 0 ? 1.0 : maxValue * 1.25;
    Offset point(int index) {
      final x = values.length == 1
          ? size.width / 2
          : size.width * index / (values.length - 1);
      final y = size.height - (values[index] / top) * size.height * 0.92;
      return Offset(x, y);
    }

    final points = [
      for (var index = 0; index < values.length; index++) point(index),
    ];
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var index = 1; index < points.length; index++) {
      final previous = points[index - 1];
      final current = points[index];
      final midX = (previous.dx + current.dx) / 2;
      path.cubicTo(midX, previous.dy, midX, current.dy, current.dx, current.dy);
    }
    final area = Path.from(path)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [line.withValues(alpha: 0.32), line.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    final last = points.last;
    canvas.drawCircle(last, 4.5, Paint()..color = dotBorder);
    canvas.drawCircle(last, 3.2, Paint()..color = line);
  }

  @override
  bool shouldRepaint(_AreaTrendPainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.line != line ||
      oldDelegate.grid != grid;
}

/// Amber notice: "N trạm chưa thể truy cập…"; lists them when known.
class UnavailableStationNotice extends StatelessWidget {
  const UnavailableStationNotice({
    super.key,
    required this.count,
    this.stationNames = const [],
  });

  final int count;
  final List<String> stationNames;

  void _showStations(BuildContext context) {
    showAppSheet<void>(
      context: context,
      title: 'Trạm chưa truy cập được',
      builder: (_) => InsetCard(
        children: [
          for (final name in stationNames)
            NavRow(
              title: name,
              showChevron: false,
              leading: const IconTile(
                icon: LucideIcons.cloudOff,
                tone: AppTone.warning,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final canOpen = stationNames.isNotEmpty;
    return Material(
      key: const ValueKey<String>('dashboard-unavailable-stations'),
      color: p.warningBg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: canOpen ? () => _showStations(context) : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          child: Row(
            children: [
              Icon(LucideIcons.triangleAlert, size: 18, color: p.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$count trạm chưa thể truy cập nên chưa tính vào tổng hợp.',
                  style: TextStyle(
                    color: p.warning,
                    fontSize: 12,
                    height: 16 / 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (canOpen) ...[
                const SizedBox(width: 8),
                Icon(LucideIcons.chevronRight, size: 18, color: p.warning),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// "12.480" / "12.480,5" (Vietnamese grouping, up to 3 decimals).
String formatDashboardVolume(double value) {
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
