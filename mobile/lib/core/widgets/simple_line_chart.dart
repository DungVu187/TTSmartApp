import 'dart:math' as math;

import 'package:flutter/material.dart';

class SimpleLineChart extends StatelessWidget {
  const SimpleLineChart({
    super.key,
    required this.values,
    required this.labels,
    this.height = 210,
  });

  final List<double> values;
  final List<String> labels;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _LineChartPainter(
          values: values,
          labels: labels,
          lineColor: theme.colorScheme.primary,
          fillColor: theme.colorScheme.primaryContainer,
          gridColor: theme.colorScheme.outlineVariant,
          labelColor: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  const _LineChartPainter({
    required this.values,
    required this.labels,
    required this.lineColor,
    required this.fillColor,
    required this.gridColor,
    required this.labelColor,
  });

  final List<double> values;
  final List<String> labels;
  final Color lineColor;
  final Color fillColor;
  final Color gridColor;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    const left = 8.0;
    const top = 10.0;
    const bottom = 28.0;
    final chartWidth = size.width - left * 2;
    final chartHeight = size.height - top - bottom;
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    for (var index = 0; index <= 3; index++) {
      final y = top + chartHeight * index / 3;
      canvas.drawLine(Offset(left, y), Offset(size.width - left, y), gridPaint);
    }

    final maxValue = values.reduce(math.max);
    final safeMax = maxValue <= 0 ? 1.0 : maxValue;
    final step = values.length == 1 ? 0.0 : chartWidth / (values.length - 1);
    final points = <Offset>[];
    for (var index = 0; index < values.length; index++) {
      points.add(
        Offset(
          left + step * index,
          top + chartHeight * (1 - values[index] / safeMax),
        ),
      );
    }

    final fillPath = Path()..moveTo(points.first.dx, top + chartHeight);
    for (final point in points) {
      fillPath.lineTo(point.dx, point.dy);
    }
    fillPath
      ..lineTo(points.last.dx, top + chartHeight)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()..color = fillColor.withValues(alpha: 0.55),
    );

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      linePath.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = lineColor
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final pointPaint = Paint()..color = lineColor;
    for (final point in points) {
      canvas.drawCircle(point, 3.5, pointPaint);
    }

    for (final index in _visibleLabelIndexes(labels.length)) {
      final painter = TextPainter(
        text: TextSpan(
          text: labels[index],
          style: TextStyle(color: labelColor, fontSize: 11),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final x = (left + step * index - painter.width / 2).clamp(
        0.0,
        size.width - painter.width,
      );
      painter.paint(canvas, Offset(x, size.height - painter.height));
    }
  }

  List<int> _visibleLabelIndexes(int length) {
    if (length <= 4) return List<int>.generate(length, (index) => index);
    return <int>[0, length ~/ 3, (length * 2) ~/ 3, length - 1];
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.labels != labels;
}
