import 'package:flutter/material.dart';
import '../services/gyro_parallax_service.dart';

/// Wraps a child widget with gyroscope-driven parallax movement.
/// The child shifts opposite to phone tilt, creating a depth effect.
///
/// [intensity] controls how far the content shifts (in logical pixels).
/// Default 8.0 is subtle. Use 12-16 for more dramatic effect.
///
/// [perspectiveScale] adds slight scale variation with tilt (0.0 = none).
///
/// Usage:
/// ```dart
/// ParallaxTilt(
///   intensity: 10,
///   child: Image.asset('photo.jpg'),
/// )
/// ```
class ParallaxTilt extends StatefulWidget {
  final Widget child;
  final double intensity;
  final double perspectiveScale;

  const ParallaxTilt({
    super.key,
    required this.child,
    this.intensity = 8.0,
    this.perspectiveScale = 0.02,
  });

  @override
  State<ParallaxTilt> createState() => _ParallaxTiltState();
}

class _ParallaxTiltState extends State<ParallaxTilt> {
  final _gyro = GyroParallaxService.instance;
  ParallaxOffset _offset = ParallaxOffset.zero;

  @override
  void initState() {
    super.initState();
    _gyro.addListener();
    _gyro.stream.listen((offset) {
      if (mounted) setState(() => _offset = offset);
    });
  }

  @override
  void dispose() {
    _gyro.removeListener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dx = _offset.x * widget.intensity;
    final dy = _offset.y * widget.intensity;
    final scale = 1.0 + (_offset.x.abs() + _offset.y.abs()) * widget.perspectiveScale;

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..translate(dx, dy)
        ..scale(scale),
      child: widget.child,
    );
  }
}

/// A variant that applies parallax to the child's position within a larger
/// container, creating the illusion the image is behind a window.
/// The child should be slightly oversized (e.g., 110% of container).
class ParallaxWindow extends StatefulWidget {
  final Widget child;
  final double intensity;

  const ParallaxWindow({
    super.key,
    required this.child,
    this.intensity = 12.0,
  });

  @override
  State<ParallaxWindow> createState() => _ParallaxWindowState();
}

class _ParallaxWindowState extends State<ParallaxWindow> {
  final _gyro = GyroParallaxService.instance;
  ParallaxOffset _offset = ParallaxOffset.zero;

  @override
  void initState() {
    super.initState();
    _gyro.addListener();
    _gyro.stream.listen((offset) {
      if (mounted) setState(() => _offset = offset);
    });
  }

  @override
  void dispose() {
    _gyro.removeListener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dx = _offset.x * widget.intensity;
    final dy = _offset.y * widget.intensity;

    return ClipRect(
      child: Transform.translate(
        offset: Offset(dx, dy),
        child: widget.child,
      ),
    );
  }
}
