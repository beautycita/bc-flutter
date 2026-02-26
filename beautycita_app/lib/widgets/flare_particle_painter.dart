import 'dart:math';
import 'package:flutter/material.dart';

class FlareParticlePainter extends CustomPainter {
  final double progress;
  final Color accentColor;
  final List<_Particle> _particles;

  FlareParticlePainter({
    required this.progress,
    required this.accentColor,
    required int particleCount,
    required int seed,
  }) : _particles = _generateParticles(particleCount, seed);

  static List<_Particle> _generateParticles(int count, int seed) {
    final rng = Random(seed);
    return List.generate(count, (_) {
      return _Particle(
        angle: rng.nextDouble() * 2 * pi,
        speed: 40.0 + rng.nextDouble() * 60.0,
        size: 2.0 + rng.nextDouble() * 4.0,
        delay: rng.nextDouble() * 0.3,
      );
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0 || progress >= 1.0) return;

    final center = Offset(size.width / 2, size.height / 2);

    for (final p in _particles) {
      final adjustedProgress = ((progress - p.delay) / (1.0 - p.delay)).clamp(0.0, 1.0);
      if (adjustedProgress <= 0.0) continue;

      final opacity = (1.0 - adjustedProgress).clamp(0.0, 1.0);
      final distance = adjustedProgress * p.speed;

      final dx = center.dx + cos(p.angle) * distance;
      final dy = center.dy + sin(p.angle) * distance;

      final color = Color.lerp(Colors.white, accentColor, adjustedProgress)!
          .withValues(alpha: opacity);

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      final currentSize = p.size * (1.0 - adjustedProgress * 0.5);
      canvas.drawCircle(Offset(dx, dy), currentSize, paint);
    }
  }

  @override
  bool shouldRepaint(FlareParticlePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _Particle {
  final double angle;
  final double speed;
  final double size;
  final double delay;

  const _Particle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.delay,
  });
}
