import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Animated abstract city map background for the home screen header.
///
/// Renders a stylized top-down city view with:
/// - Faint road grid (major + minor roads, one curve, one diagonal)
/// - Subtle city blocks between major roads
/// - 12 pulsing salon-beacon dots at intersections
/// - 2 trace dots that travel along roads ("finding your salon")
class AnimatedCityMap extends StatefulWidget {
  const AnimatedCityMap({super.key});

  @override
  State<AnimatedCityMap> createState() => _AnimatedCityMapState();
}

class _AnimatedCityMapState extends State<AnimatedCityMap>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _CityMapPainter(animation: _controller),
        size: Size.infinite,
      ),
    );
  }
}

/// Beacon: a salon marker at a road intersection.
class _Beacon {
  final double x, y, phase;
  const _Beacon(this.x, this.y, this.phase);
}

class _CityMapPainter extends CustomPainter {
  final Animation<double> animation;

  _CityMapPainter({required this.animation}) : super(repaint: animation);

  // ── Road layout (normalized 0.0–1.0) ──

  static const _majorH = [0.22, 0.50, 0.78];
  static const _majorV = [0.15, 0.40, 0.65, 0.88];

  static const _minorH = [0.08, 0.36, 0.64, 0.92];
  static const _minorV = [0.05, 0.28, 0.52, 0.76, 0.96];

  // ── Salon beacons (positioned at/near intersections) ──

  static const _beacons = [
    _Beacon(0.15, 0.22, 0.00),
    _Beacon(0.40, 0.50, 0.15),
    _Beacon(0.65, 0.22, 0.30),
    _Beacon(0.88, 0.78, 0.45),
    _Beacon(0.15, 0.78, 0.60),
    _Beacon(0.52, 0.64, 0.75),
    _Beacon(0.40, 0.22, 0.10),
    _Beacon(0.65, 0.50, 0.50),
    _Beacon(0.28, 0.36, 0.85),
    _Beacon(0.76, 0.36, 0.40),
    _Beacon(0.88, 0.50, 0.20),
    _Beacon(0.40, 0.78, 0.65),
  ];

  // ── Trace paths (animated dots traveling along roads) ──

  static const _trace1 = [
    Offset(0.02, 0.50),
    Offset(0.40, 0.50),
    Offset(0.40, 0.22),
    Offset(0.65, 0.22),
    Offset(0.65, 0.50),
    Offset(0.98, 0.50),
  ];

  static const _trace2 = [
    Offset(0.88, 0.05),
    Offset(0.88, 0.50),
    Offset(0.52, 0.50),
    Offset(0.52, 0.78),
    Offset(0.15, 0.78),
    Offset(0.15, 0.50),
  ];

  // ── Static paints (reused across frames) ──

  static final _majorRoadPaint = Paint()
    ..color = const Color(0x14FFFFFF)
    ..strokeWidth = 1.5
    ..style = PaintingStyle.stroke;

  static final _minorRoadPaint = Paint()
    ..color = const Color(0x0AFFFFFF)
    ..strokeWidth = 0.8
    ..style = PaintingStyle.stroke;

  static final _curvePaint = Paint()
    ..color = const Color(0x0DFFFFFF)
    ..strokeWidth = 1.2
    ..style = PaintingStyle.stroke;

  static final _blockPaint = Paint()
    ..color = const Color(0x04FFFFFF)
    ..style = PaintingStyle.fill;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final w = size.width;
    final h = size.height;
    final t = animation.value;

    _paintBlocks(canvas, w, h);
    _paintRoads(canvas, w, h);
    _paintBeacons(canvas, w, h, t);
    _paintTrace(canvas, w, h, t, _trace1, 0.0);
    _paintTrace(canvas, w, h, t, _trace2, 0.33);
  }

  void _paintBlocks(Canvas canvas, double w, double h) {
    for (int i = 0; i < _majorV.length - 1; i++) {
      for (int j = 0; j < _majorH.length - 1; j++) {
        if ((i + j) % 2 == 0) {
          canvas.drawRRect(
            RRect.fromLTRBR(
              _majorV[i] * w + 3,
              _majorH[j] * h + 3,
              _majorV[i + 1] * w - 3,
              _majorH[j + 1] * h - 3,
              const Radius.circular(2),
            ),
            _blockPaint,
          );
        }
      }
    }
  }

  void _paintRoads(Canvas canvas, double w, double h) {
    // Major roads
    for (final y in _majorH) {
      canvas.drawLine(Offset(0, y * h), Offset(w, y * h), _majorRoadPaint);
    }
    for (final x in _majorV) {
      canvas.drawLine(Offset(x * w, 0), Offset(x * w, h), _majorRoadPaint);
    }

    // Minor roads
    for (final y in _minorH) {
      canvas.drawLine(Offset(0, y * h), Offset(w, y * h), _minorRoadPaint);
    }
    for (final x in _minorV) {
      canvas.drawLine(Offset(x * w, 0), Offset(x * w, h), _minorRoadPaint);
    }

    // Curved road (coastal / organic feel)
    final curve = Path()
      ..moveTo(0, h * 0.15)
      ..quadraticBezierTo(w * 0.4, h * 0.30, w, h * 0.12);
    canvas.drawPath(curve, _curvePaint);

    // Diagonal shortcut
    canvas.drawLine(Offset(w * 0.28, 0), Offset(w * 0.52, h), _minorRoadPaint);
  }

  void _paintBeacons(Canvas canvas, double w, double h, double t) {
    for (final b in _beacons) {
      final phase = (t + b.phase) % 1.0;
      final pulse = (math.sin(phase * math.pi * 2) + 1) / 2; // 0→1

      final center = Offset(b.x * w, b.y * h);

      // Outer glow
      canvas.drawCircle(
        center,
        3.5 + pulse * 3.0,
        Paint()..color = Color.fromRGBO(255, 255, 255, 0.04 + pulse * 0.08),
      );

      // Inner dot
      canvas.drawCircle(
        center,
        1.5 + pulse * 1.0,
        Paint()..color = Color.fromRGBO(255, 255, 255, 0.12 + pulse * 0.28),
      );
    }
  }

  void _paintTrace(
    Canvas canvas,
    double w,
    double h,
    double t,
    List<Offset> waypoints,
    double offset,
  ) {
    final segs = waypoints.length - 1;
    final p = ((t + offset) * 1.2) % 1.0;
    final along = p * segs;
    final seg = along.floor().clamp(0, segs - 1);
    final segT = along - seg;

    final from = waypoints[seg];
    final to = waypoints[(seg + 1).clamp(0, segs)];

    final pos = Offset(
      (from.dx + (to.dx - from.dx) * segT) * w,
      (from.dy + (to.dy - from.dy) * segT) * h,
    );

    // Soft glow
    canvas.drawCircle(
      pos,
      4.0,
      Paint()..color = const Color.fromRGBO(255, 255, 255, 0.15),
    );

    // Bright core
    canvas.drawCircle(
      pos,
      2.0,
      Paint()..color = const Color.fromRGBO(255, 255, 255, 0.45),
    );
  }

  @override
  bool shouldRepaint(_CityMapPainter old) => true;
}
