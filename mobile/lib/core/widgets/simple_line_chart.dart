import 'dart:math' as math;

import 'package:flutter/material.dart';

@visibleForTesting
class LineChartAxisScale {
  const LineChartAxisScale({
    required this.maximum,
    required this.step,
    required this.divisions,
  });

  final double maximum;
  final double step;
  final int divisions;
}

@visibleForTesting
LineChartAxisScale calculateLineChartAxisScale(
  Iterable<double> values, {
  int targetDivisions = 8,
}) {
  final safeTargetDivisions = targetDivisions.clamp(4, 10);
  var maximumValue = 0.0;
  for (final value in values) {
    if (value.isFinite && value > maximumValue) maximumValue = value;
  }
  if (maximumValue <= 0) {
    return const LineChartAxisScale(maximum: 1, step: 0.2, divisions: 5);
  }

  final step = _niceCeiling(maximumValue / safeTargetDivisions);
  final maximum = (maximumValue / step).ceil() * step;
  return LineChartAxisScale(
    maximum: maximum,
    step: step,
    divisions: (maximum / step).round(),
  );
}

double _niceCeiling(double value) {
  final magnitude = math
      .pow(10, (math.log(value) / math.ln10).floor())
      .toDouble();
  final normalized = value / magnitude;
  final nice = normalized <= 1
      ? 1.0
      : normalized <= 2
      ? 2.0
      : normalized <= 2.5
      ? 2.5
      : normalized <= 5
      ? 5.0
      : 10.0;
  return nice * magnitude;
}

class SimpleLineChart extends StatelessWidget {
  const SimpleLineChart({
    super.key,
    required this.values,
    required this.labels,
    this.height = 250,
    this.lineColor,
    this.fillColor,
  });

  final List<double> values;
  final List<String> labels;
  final double height;
  final Color? lineColor;
  final Color? fillColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final pointCount = math.min(values.length, labels.length);
        final pointSpacing = pointCount > 18 ? 34.0 : 44.0;
        final contentWidth = math.max(
          availableWidth,
          62 + math.max(0, pointCount - 1) * pointSpacing,
        );
        return SizedBox(
          height: height,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: contentWidth,
              height: height,
              child: CustomPaint(
                painter: _LineChartPainter(
                  values: values,
                  labels: labels,
                  lineColor: lineColor ?? theme.colorScheme.primary,
                  fillColor: fillColor ?? theme.colorScheme.primaryContainer,
                  gridColor: const Color(0xFFD8DEE6),
                  labelColor: const Color(0xFF5B6472),
                ),
              ),
            ),
          ),
        );
      },
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
    final pointCount = math.min(values.length, labels.length);
    if (pointCount == 0) return;

    const left = 50.0;
    const right = 10.0;
    const top = 8.0;
    const bottom = 28.0;
    final chartWidth = size.width - left - right;
    final chartHeight = size.height - top - bottom;
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    final visibleValues = values.take(pointCount).toList(growable: false);
    final axisScale = calculateLineChartAxisScale(visibleValues);
    final axisMax = axisScale.maximum;

    for (var index = 0; index <= axisScale.divisions; index++) {
      final y = top + chartHeight * index / axisScale.divisions;
      canvas.drawLine(
        Offset(left, y),
        Offset(size.width - right, y),
        gridPaint,
      );
      _paintText(
        canvas,
        _formatAxisValue(axisScale.step * (axisScale.divisions - index)),
        Offset(left - 6, y),
        alignRight: true,
        centerVertically: true,
      );
    }

    final horizontalStep = pointCount == 1
        ? 0.0
        : chartWidth / (pointCount - 1);
    final points = <Offset>[];
    for (var index = 0; index < pointCount; index++) {
      final x = left + horizontalStep * index;
      canvas.drawLine(Offset(x, top), Offset(x, top + chartHeight), gridPaint);
      final normalizedValue = visibleValues[index].clamp(0, axisMax).toDouble();
      points.add(
        Offset(x, top + chartHeight * (1 - normalizedValue / axisMax)),
      );
    }

    final linePath = _smoothPath(points, top, top + chartHeight);
    final fillPath = Path.from(linePath)
      ..lineTo(points.last.dx, top + chartHeight)
      ..lineTo(points.first.dx, top + chartHeight)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()..color = fillColor.withValues(alpha: 0.72),
    );
    canvas.drawPath(
      linePath,
      Paint()
        ..color = lineColor
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final pointFill = Paint()..color = lineColor;
    final pointBorder = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    for (final point in points) {
      canvas
        ..drawCircle(point, 3.2, pointFill)
        ..drawCircle(point, 3.2, pointBorder);
    }

    for (var index = 0; index < pointCount; index++) {
      _paintText(
        canvas,
        _displayLabel(labels[index]),
        Offset(left + horizontalStep * index, size.height - 3),
        centerHorizontally: true,
        alignBottom: true,
      );
    }
  }

  Path _smoothPath(List<Offset> points, double minY, double maxY) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    if (points.length == 1) return path;
    for (var index = 0; index < points.length - 1; index++) {
      final previous = index == 0 ? points[index] : points[index - 1];
      final current = points[index];
      final next = points[index + 1];
      final afterNext = index + 2 < points.length ? points[index + 2] : next;
      final control1 = Offset(
        current.dx + (next.dx - previous.dx) / 6,
        (current.dy + (next.dy - previous.dy) / 6).clamp(minY, maxY).toDouble(),
      );
      final control2 = Offset(
        next.dx - (afterNext.dx - current.dx) / 6,
        (next.dy - (afterNext.dy - current.dy) / 6)
            .clamp(minY, maxY)
            .toDouble(),
      );
      path.cubicTo(
        control1.dx,
        control1.dy,
        control2.dx,
        control2.dy,
        next.dx,
        next.dy,
      );
    }
    return path;
  }

  String _formatAxisValue(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(value < 1 ? 2 : 1);
  }

  String _displayLabel(String value) =>
      value.replaceFirst(RegExp(r'^0(?=\dH$)'), '');

  void _paintText(
    Canvas canvas,
    String text,
    Offset anchor, {
    bool alignRight = false,
    bool centerHorizontally = false,
    bool centerVertically = false,
    bool alignBottom = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: labelColor, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    var dx = anchor.dx;
    var dy = anchor.dy;
    if (alignRight) dx -= painter.width;
    if (centerHorizontally) dx -= painter.width / 2;
    if (centerVertically) dy -= painter.height / 2;
    if (alignBottom) dy -= painter.height;
    painter.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.labels != labels ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.fillColor != fillColor ||
      oldDelegate.gridColor != gridColor ||
      oldDelegate.labelColor != labelColor;
}
