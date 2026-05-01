// 3D-depth hero with gyroscope-driven tilt — "balanced on a ball fulcrum".
//
// Wrap any container-style child with [Gyro3DHero] and the result reads as
// a physical, dimensional surface (not a flat sticker with a drop-shadow).
// Tilting the device rocks the card around its center; small angle range,
// damped spring response, perspective Matrix4 so the rotation feels 3D.
//
// Depth recipe (visible without motion):
//   - Inner top-edge highlight (light catching the front face)
//   - Inner bottom-edge inset shadow (the tile is thicker than it looks)
//   - Outer projected shadow that moves opposite the tilt axis (parallax)
//
// Themes: light theme uses bright cool highlights + deep brand-tinted
// shadows; dark theme uses pearl highlights + near-black shadows. Same
// gyroscope behavior; only the shading recipe changes.
//
// Performance: the accelerometer stream is sampled and ticker-driven —
// tilt state lives in a single `setState`; the shadow Container animates
// on the same frame so we never flash twice per tick.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

class Gyro3DHero extends StatefulWidget {
  const Gyro3DHero({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.maxTiltDegrees = 6.0,
    this.dampingPerFrame = 0.15,
    this.perspective = 0.0015,
  });

  final Widget child;
  final BorderRadius borderRadius;

  /// Maximum tilt in degrees in either axis. Keeps the rock subtle.
  final double maxTiltDegrees;

  /// Smoothing factor per accelerometer tick (0..1). Lower = more damping.
  final double dampingPerFrame;

  /// Matrix4 perspective entry. ~0.0015 reads as 3D without distortion.
  final double perspective;

  @override
  State<Gyro3DHero> createState() => _Gyro3DHeroState();
}

class _Gyro3DHeroState extends State<Gyro3DHero> {
  Stream<AccelerometerEvent>? _stream;
  // Smoothed gravity components in device frame: x = roll (left/right),
  // y = pitch (front/back). Range typically -9.81..+9.81 m/s².
  double _gx = 0;
  double _gy = 0;

  @override
  void initState() {
    super.initState();
    // 50Hz sampling is plenty for visual smoothing — anything faster just
    // burns battery without a perceptible difference.
    _stream = accelerometerEventStream(samplingPeriod: const Duration(milliseconds: 20));
    _stream!.listen(_onAccelerometer, onError: (_) {/* sensor not present */});
  }

  void _onAccelerometer(AccelerometerEvent e) {
    // Low-pass filter — exponential smoothing. The card eases toward the
    // current gravity vector instead of snapping to every micro-shake.
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
    // Map smoothed gravity to a tilt angle.
    //   gx ≈ +9.81 when device is rolled fully right → tilt right
    //   gy ≈ +9.81 when device is pitched face-up    → tilt back
    // Clamp to maxTilt so we never flip the card.
    final maxRad = widget.maxTiltDegrees * math.pi / 180.0;
    // Roll: rotateY (around vertical axis). Tilt right → top tilts away.
    final roll = (_gx / 9.81).clamp(-1.0, 1.0) * maxRad;
    // Pitch: rotateX (around horizontal axis). Pitch back → top tilts toward.
    final pitch = (_gy / 9.81).clamp(-1.0, 1.0) * maxRad;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Shadow offset moves opposite the tilt so the card looks like it's
    // lifting on the high side. ~14px max offset reads as parallax without
    // looking exaggerated.
    final shadowDx = -roll / maxRad * 14.0;
    final shadowDy = pitch / maxRad * 14.0 + 6.0; // baseline drop of 6px

    final highlightColor = isDark
        ? Colors.white.withValues(alpha: 0.18)
        : Colors.white.withValues(alpha: 0.55);
    final innerShadowColor = isDark
        ? Colors.black.withValues(alpha: 0.55)
        : Theme.of(context).colorScheme.primary.withValues(alpha: 0.30);
    final outerShadowColor = isDark
        ? Colors.black.withValues(alpha: 0.65)
        : Theme.of(context).colorScheme.primary.withValues(alpha: 0.32);

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, widget.perspective)
        ..rotateX(-pitch)
        ..rotateY(roll),
      child: Stack(
        children: [
          // Parallax-projected outer shadow.
          // The shadow Container sits behind the hero, slightly inset on
          // the sides, with the offset following the tilt — gives the
          // illusion that the card is lifting off the surface.
          Positioned(
            left: 6 + shadowDx,
            right: 6 - shadowDx,
            top: 4,
            bottom: -shadowDy,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: widget.borderRadius,
                  boxShadow: [
                    BoxShadow(
                      color: outerShadowColor,
                      blurRadius: 22,
                      spreadRadius: -2,
                      offset: Offset(shadowDx * 0.4, shadowDy),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // The hero itself — child + bevel overlay.
          ClipRRect(
            borderRadius: widget.borderRadius,
            child: Stack(
              children: [
                widget.child,
                // Bevel: top-edge highlight + bottom-edge inset shadow.
                // Painted on top of child so the gradient still shines
                // through. IgnorePointer because the hero might have taps.
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: widget.borderRadius,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            highlightColor,
                            Colors.transparent,
                            Colors.transparent,
                            innerShadowColor,
                          ],
                          stops: const [0.0, 0.18, 0.78, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
                // Hairline highlight stroke along the top edge — catches
                // the eye as a "front face" cue without a full border.
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: IgnorePointer(
                    child: Container(
                      height: 1.2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            highlightColor.withValues(alpha: 0.0),
                            highlightColor.withValues(alpha: 0.9),
                            highlightColor.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
