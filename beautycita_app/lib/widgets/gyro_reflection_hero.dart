// GyroReflectionHero — gyroscope-driven specular reflection on a flat hero.
//
// The wrapped child is NOT rotated, scaled, or otherwise transformed. Only
// a soft radial highlight (like sunlight glinting off a glossy tile) is
// painted on top of the surface, and that highlight's center moves with
// the device gyroscope. Tilt the phone left → reflection slides right.
// Tilt forward → reflection slides toward the bottom.
//
// Damped sampling so the highlight glides smoothly instead of jumping.
// Works in light and dark themes — the highlight color stays white-ish
// because real specular highlights are bright regardless of the surface
// color underneath.

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

class GyroReflectionHero extends StatefulWidget {
  const GyroReflectionHero({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.dampingPerFrame = 0.12,
    this.highlightAlpha = 0.32,
    this.highlightRadius = 0.55,
  });

  final Widget child;
  final BorderRadius borderRadius;

  /// Smoothing factor per accelerometer tick (0..1). Lower = more damping.
  final double dampingPerFrame;

  /// Peak alpha of the specular highlight at its center.
  final double highlightAlpha;

  /// Radial gradient radius as a fraction of the longest hero dimension.
  /// 0.55 = highlight just over half the card's width — soft pool, not a dot.
  final double highlightRadius;

  @override
  State<GyroReflectionHero> createState() => _GyroReflectionHeroState();
}

class _GyroReflectionHeroState extends State<GyroReflectionHero> {
  // Smoothed gravity components in the device frame.
  // x: positive when device is rolled to the right.
  // y: positive when the top of the device is pitched away from the user.
  double _gx = 0;
  double _gy = 0;

  @override
  void initState() {
    super.initState();
    accelerometerEventStream(samplingPeriod: const Duration(milliseconds: 20))
        .listen(_onAccelerometer, onError: (_) {/* sensor not present */});
  }

  void _onAccelerometer(AccelerometerEvent e) {
    final k = widget.dampingPerFrame;
    final newGx = _gx + (e.x - _gx) * k;
    final newGy = _gy + (e.y - _gy) * k;
    if (!mounted) return;
    setState(() {
      _gx = newGx;
      _gy = newGy;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Map gravity (-9.81..9.81) into a normalized -1..1 axis.
    final nx = (_gx / 9.81).clamp(-1.0, 1.0);
    final ny = (_gy / 9.81).clamp(-1.0, 1.0);

    // Highlight center as Alignment(-1..1, -1..1).
    // Tilting the device right (gx > 0) → reflection slides LEFT, like a
    // real glint that stays anchored to the off-screen "light source".
    // We use a softer multiplier so the reflection doesn't snap to the
    // edges — it should always read as "on" the card.
    final ax = (-nx * 0.85).clamp(-1.0, 1.0);
    final ay = (-ny * 0.85).clamp(-1.0, 1.0);

    // StackFit.passthrough so the parent's horizontal constraint passes
    // to the AnimatedContainer child — otherwise Stack defaults to .loose
    // and the child wraps to its column's intrinsic width (about a quarter
    // of the screen instead of the original full-width hero).
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          widget.child,
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: widget.borderRadius,
                  gradient: RadialGradient(
                    center: Alignment(ax, ay),
                    radius: widget.highlightRadius,
                    colors: [
                      Colors.white.withValues(alpha: widget.highlightAlpha),
                      Colors.white.withValues(alpha: widget.highlightAlpha * 0.5),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                    stops: const [0.0, 0.35, 1.0],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
