import 'dart:math';
import 'package:flutter/material.dart';

/// A lightweight particle rain overlay that renders soft, slow-falling particles
/// at a slight angle. Designed to be barely noticeable ambient atmosphere.
class ParticleRain extends StatefulWidget {
  /// Number of particles on screen.
  final int particleCount;

  const ParticleRain({super.key, this.particleCount = 45});

  @override
  State<ParticleRain> createState() => _ParticleRainState();
}

class _ParticleRainState extends State<ParticleRain>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_Particle> _particles;
  final _random = Random();
  Duration _lastTime = Duration.zero;

  @override
  void initState() {
    super.initState();
    _particles = List.generate(widget.particleCount, (_) => _randomParticle(randomY: true));
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1), // loops forever
    )..addListener(_tick)..repeat();
  }

  _Particle _randomParticle({required bool randomY}) {
    return _Particle(
      x: _random.nextDouble(), // 0..1 normalized
      y: randomY ? _random.nextDouble() : -_random.nextDouble() * 0.1, // start above screen if not random
      radius: 2.0 + _random.nextDouble() * 3.0, // 2-5px
      opacity: 0.05 + _random.nextDouble() * 0.10, // 0.05-0.15
      speed: 30.0 + _random.nextDouble() * 30.0, // 30-60 px/s
    );
  }

  void _tick() {
    final now = _controller.lastElapsedDuration ?? Duration.zero;
    if (_lastTime == Duration.zero) {
      _lastTime = now;
      return;
    }
    final dt = (now - _lastTime).inMicroseconds / 1000000.0;
    _lastTime = now;

    // Clamp dt to avoid huge jumps if the app was suspended
    final clampedDt = dt.clamp(0.0, 0.1);

    final size = context.size;
    if (size == null || size.height == 0) return;

    for (int i = 0; i < _particles.length; i++) {
      final p = _particles[i];
      // Move down + slight drift right (~25% of downward speed)
      final dy = p.speed * clampedDt / size.height;
      final dx = p.speed * 0.25 * clampedDt / size.width;
      p.y += dy;
      p.x += dx;

      // Reset if below screen or off right edge
      if (p.y > 1.0 || p.x > 1.0) {
        _particles[i] = _randomParticle(randomY: false);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              painter: _ParticleRainPainter(
                particles: _particles,
                color: Theme.of(context).colorScheme.primary,
              ),
              size: Size.infinite,
            );
          },
        ),
      ),
    );
  }
}

class _Particle {
  double x; // 0..1 normalized
  double y; // 0..1 normalized
  final double radius;
  final double opacity;
  final double speed; // px per second (absolute)

  _Particle({
    required this.x,
    required this.y,
    required this.radius,
    required this.opacity,
    required this.speed,
  });
}

class _ParticleRainPainter extends CustomPainter {
  final List<_Particle> particles;
  final Color color;

  _ParticleRainPainter({required this.particles, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      paint.color = color.withValues(alpha: p.opacity);
      canvas.drawCircle(
        Offset(p.x * size.width, p.y * size.height),
        p.radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticleRainPainter oldDelegate) => true;
}
