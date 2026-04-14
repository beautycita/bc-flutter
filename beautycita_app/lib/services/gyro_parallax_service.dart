import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Provides smoothed gyroscope tilt data for parallax effects.
/// Singleton — one listener shared across all parallax widgets.
class GyroParallaxService {
  GyroParallaxService._();
  static final instance = GyroParallaxService._();

  StreamSubscription<GyroscopeEvent>? _sub;
  final _controller = StreamController<ParallaxOffset>.broadcast();

  double _x = 0;   // Current smoothed position
  double _y = 0;
  double _tx = 0;  // Target position (raw gyro integrated)
  double _ty = 0;
  int _listenerCount = 0;

  /// Smoothed parallax offset stream. Values range from -1.0 to 1.0.
  Stream<ParallaxOffset> get stream => _controller.stream;

  /// Current offset (for synchronous reads).
  ParallaxOffset get current => ParallaxOffset(_x, _y);

  /// Call when a widget starts listening. Starts the sensor if needed.
  void addListener() {
    _listenerCount++;
    if (_listenerCount == 1) _start();
  }

  /// Call when a widget stops listening. Stops the sensor when no listeners.
  void removeListener() {
    _listenerCount = max(0, _listenerCount - 1);
    if (_listenerCount == 0) _stop();
  }

  void _start() {
    _sub?.cancel();
    _sub = gyroscopeEventStream(
      samplingPeriod: const Duration(milliseconds: 16), // ~60fps
    ).listen((event) {
      // Gyro input feeds a target, then we lerp toward it smoothly.
      // This prevents snapping — the offset glides to the tilt position.
      const inputGain = 0.05;   // How much raw gyro moves the target
      const targetDecay = 0.96; // Target drifts back to center slowly
      const lerpSpeed = 0.08;   // How fast current position chases target (lower = smoother glide)

      _tx = (_tx * targetDecay + event.y * inputGain).clamp(-1.0, 1.0);
      _ty = (_ty * targetDecay - event.x * inputGain).clamp(-1.0, 1.0);

      // Smooth interpolation toward target — no snapping
      _x += (_tx - _x) * lerpSpeed;
      _y += (_ty - _y) * lerpSpeed;

      if (!_controller.isClosed) {
        _controller.add(ParallaxOffset(_x, _y));
      }
    }, onError: (e) {
      if (kDebugMode) debugPrint('[Gyro] Sensor error: $e');
    });
  }

  void _stop() {
    _sub?.cancel();
    _sub = null;
    _x = 0;
    _y = 0;
    _tx = 0;
    _ty = 0;
  }

  void dispose() {
    _stop();
    _controller.close();
  }
}

/// Normalized parallax offset. x = left/right tilt, y = forward/back tilt.
/// Values range from -1.0 to 1.0.
class ParallaxOffset {
  final double x;
  final double y;
  const ParallaxOffset(this.x, this.y);
  static const zero = ParallaxOffset(0, 0);
}
