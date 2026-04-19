import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:beautycita/config/fonts.dart';

/// A simple, self-contained trend chart (line or bar) with no external dependencies.
/// Uses CustomPainter for maximum performance and zero package bloat.
class TrendChart extends StatelessWidget {
  final List<TrendPoint> data;
  final String title;
  final TrendChartType type;
  final Color? color;
  final double height;
  final bool showLabels;
  final String? valuePrefix;
  final String? valueSuffix;

  const TrendChart({
    super.key,
    required this.data,
    this.title = '',
    this.type = TrendChartType.line,
    this.color,
    this.height = 180,
    this.showLabels = true,
    this.valuePrefix,
    this.valueSuffix,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final chartColor = color ?? colors.primary;

    if (data.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text('Sin datos', style: GoogleFonts.nunito(color: colors.onSurface.withValues(alpha: 0.4))),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty)
          Text(title, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: colors.onSurface)),
        if (title.isNotEmpty) const SizedBox(height: 8),
        SizedBox(
          height: height,
          child: CustomPaint(
            size: Size.infinite,
            painter: _TrendPainter(
              data: data,
              type: type,
              color: chartColor,
              showLabels: showLabels,
              valuePrefix: valuePrefix ?? '',
              valueSuffix: valueSuffix ?? '',
              textColor: colors.onSurface.withValues(alpha: 0.5),
              gridColor: colors.onSurface.withValues(alpha: 0.08),
            ),
          ),
        ),
      ],
    );
  }
}

enum TrendChartType { line, bar }

class TrendPoint {
  final String label;
  final double value;
  const TrendPoint(this.label, this.value);
}

class _TrendPainter extends CustomPainter {
  final List<TrendPoint> data;
  final TrendChartType type;
  final Color color;
  final bool showLabels;
  final String valuePrefix;
  final String valueSuffix;
  final Color textColor;
  final Color gridColor;

  _TrendPainter({
    required this.data,
    required this.type,
    required this.color,
    required this.showLabels,
    required this.valuePrefix,
    required this.valueSuffix,
    required this.textColor,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final bottomPadding = showLabels ? 24.0 : 8.0;
    final topPadding = 16.0;
    final leftPadding = 8.0;
    final rightPadding = 8.0;

    final chartW = size.width - leftPadding - rightPadding;
    final chartH = size.height - bottomPadding - topPadding;
    final maxVal = data.map((d) => d.value).reduce(math.max);
    final minVal = 0.0;
    final range = maxVal - minVal;
    final effectiveRange = range == 0 ? 1.0 : range;

    // Grid lines (3 horizontal)
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5;
    for (int i = 0; i <= 3; i++) {
      final y = topPadding + chartH * (1 - i / 3);
      canvas.drawLine(Offset(leftPadding, y), Offset(size.width - rightPadding, y), gridPaint);
    }

    // Data
    if (type == TrendChartType.bar) {
      _paintBars(canvas, size, chartW, chartH, topPadding, bottomPadding, leftPadding, effectiveRange, minVal);
    } else {
      _paintLine(canvas, size, chartW, chartH, topPadding, bottomPadding, leftPadding, effectiveRange, minVal);
    }

    // Labels
    if (showLabels && data.length <= 15) {
      final labelStyle = TextStyle(color: textColor, fontSize: 9, fontFamily: 'NunitoSans');
      for (int i = 0; i < data.length; i++) {
        final x = leftPadding + (chartW / (data.length - (type == TrendChartType.bar ? 0 : 1))) * i;
        final tp = TextPainter(
          text: TextSpan(text: data[i].label, style: labelStyle),
          textDirection: ui.TextDirection.ltr,
        )..layout();
        final labelX = type == TrendChartType.bar
            ? x + (chartW / data.length - tp.width) / 2
            : x - tp.width / 2;
        tp.paint(canvas, Offset(labelX.clamp(0, size.width - tp.width), size.height - bottomPadding + 4));
      }
    }
  }

  void _paintBars(Canvas canvas, Size size, double chartW, double chartH,
      double topPad, double bottomPad, double leftPad, double range, double minVal) {
    final barWidth = (chartW / data.length) * 0.65;
    final barGap = (chartW / data.length - barWidth) / 2;

    for (int i = 0; i < data.length; i++) {
      final x = leftPad + (chartW / data.length) * i + barGap;
      final normalized = (data[i].value - minVal) / range;
      final barH = chartH * normalized;
      final y = topPad + chartH - barH;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barH),
        const Radius.circular(3),
      );

      // Gradient fill
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color, color.withValues(alpha: 0.4)],
        ).createShader(Rect.fromLTWH(x, y, barWidth, barH));

      canvas.drawRRect(rect, paint);
    }
  }

  void _paintLine(Canvas canvas, Size size, double chartW, double chartH,
      double topPad, double bottomPad, double leftPad, double range, double minVal) {
    if (data.length < 2) return;

    final points = <Offset>[];
    for (int i = 0; i < data.length; i++) {
      final x = leftPad + (chartW / (data.length - 1)) * i;
      final normalized = (data[i].value - minVal) / range;
      final y = topPad + chartH * (1 - normalized);
      points.add(Offset(x, y));
    }

    // Fill under curve
    final fillPath = Path()
      ..moveTo(points.first.dx, topPad + chartH);
    for (final p in points) {
      fillPath.lineTo(p.dx, p.dy);
    }
    fillPath.lineTo(points.last.dx, topPad + chartH);
    fillPath.close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0.02)],
        ).createShader(Rect.fromLTWH(leftPad, topPad, chartW, chartH)),
    );

    // Line
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      linePath.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(linePath, linePaint);

    // Dots
    final dotPaint = Paint()..color = color;
    final dotBgPaint = Paint()..color = Colors.white;
    for (final p in points) {
      canvas.drawCircle(p, 4, dotBgPaint);
      canvas.drawCircle(p, 2.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) =>
      old.data != data || old.type != type || old.color != color;
}
