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

  double _x = 0;
  double _y = 0;
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
      // Integrate gyroscope angular velocity into position
      // Lower smoothing = more resistance to movement
      // Higher decay = slower, softer drift back to center
      const smoothing = 0.06;
      const decay = 0.94;

      _x = (_x * decay + event.y * smoothing).clamp(-1.0, 1.0);
      _y = (_y * decay - event.x * smoothing).clamp(-1.0, 1.0);

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
