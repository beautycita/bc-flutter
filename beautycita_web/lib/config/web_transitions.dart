import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

// ============================================================================
// Web Page Transitions
//
// Three custom PageRouteBuilder transitions for the BeautyCita web app:
// 1. GradientSweepTransition - main navigation
// 2. RadialBurstTransition - detail views, modals
// 3. DiagonalSlashTransition - tab/filter changes
// ============================================================================

// ── Brand colors used in transition gradients ──────────────────────────────

const _kPrimary = Color(0xFFEC4899);
const _kSecondary = Color(0xFF9333EA);
const _kTertiary = Color(0xFF3B82F6);

// ════════════════════════════════════════════════════════════════════════════
// 1. GRADIENT SWEEP TRANSITION
// ════════════════════════════════════════════════════════════════════════════

/// Thin gradient line sweeps left-to-right. Behind it, the new page clips in.
/// After sweep completes, content cards stagger in with slide + fade.
///
/// Total duration: 600ms sweep + 400ms stagger = 1000ms
/// Use for: main navigation (settings -> sub-page, portal switching)
Route<T> gradientSweepRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 1000),
    reverseTransitionDuration: const Duration(milliseconds: 600),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // Phase 1: sweep (0.0 -> 0.6)
      final sweepProgress = CurvedAnimation(
        parent: animation,
        curve: const Interval(0.0, 0.6, curve: Curves.easeInOutCubic),
      );

      // Phase 2: content fade-in (0.6 -> 1.0)
      final contentProgress = CurvedAnimation(
        parent: animation,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
      );

      return AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          return Stack(
            children: [
              // Clipped new page behind the sweep line
              ClipRect(
                clipper: _HorizontalClipClipper(sweepProgress.value),
                child: Opacity(
                  opacity: contentProgress.value.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(0, 12 * (1 - contentProgress.value)),
                    child: child,
                  ),
                ),
              ),

              // Gradient sweep line overlay
              if (sweepProgress.value > 0.0 && sweepProgress.value < 1.0)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _GradientSweepLinePainter(
                      progress: sweepProgress.value,
                    ),
                  ),
                ),
            ],
          );
        },
      );
    },
  );
}

/// Clips content horizontally from left, revealing width proportional to [progress].
class _HorizontalClipClipper extends CustomClipper<Rect> {
  final double progress;
  _HorizontalClipClipper(this.progress);

  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(0, 0, size.width * progress, size.height);
  }

  @override
  bool shouldReclip(_HorizontalClipClipper oldClipper) =>
      oldClipper.progress != progress;
}

/// Paints a thin vertical gradient line at the sweep edge.
class _GradientSweepLinePainter extends CustomPainter {
  final double progress;
  _GradientSweepLinePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width * progress;
    const lineWidth = 4.0;

    final paint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(x - lineWidth, 0),
        Offset(x + lineWidth, size.height),
        [_kPrimary, _kSecondary, _kTertiary],
        [0.0, 0.5, 1.0],
      )
      ..style = PaintingStyle.fill;

    // Thin gradient line
    canvas.drawRect(
      Rect.fromLTWH(x - lineWidth / 2, 0, lineWidth, size.height),
      paint,
    );

    // Soft glow around the line
    final glowPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(x - 20, 0),
        Offset(x + 20, 0),
        [
          _kPrimary.withValues(alpha: 0),
          _kSecondary.withValues(alpha: 0.15),
          _kTertiary.withValues(alpha: 0),
        ],
        [0.0, 0.5, 1.0],
      )
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(x - 20, 0, 40, size.height),
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(_GradientSweepLinePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ════════════════════════════════════════════════════════════════════════════
// 2. RADIAL BURST TRANSITION
// ════════════════════════════════════════════════════════════════════════════

/// Circular clip path expands from a center point (tap position or screen center).
/// Gradient glow around the expanding circle edge.
///
/// Duration: 700ms with Curves.easeOutCubic
/// Use for: opening detail views, modals, expanding cards
Route<T> radialBurstRoute<T>(Widget page, {Offset? origin}) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 700),
    reverseTransitionDuration: const Duration(milliseconds: 500),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );

      return AnimatedBuilder(
        animation: curved,
        builder: (context, _) {
          final size = MediaQuery.of(context).size;
          final center = origin ?? Offset(size.width / 2, size.height / 2);

          // Max radius: distance from center to farthest corner
          final maxRadius = math.sqrt(
            math.pow(math.max(center.dx, size.width - center.dx), 2) +
                math.pow(math.max(center.dy, size.height - center.dy), 2),
          );

          final currentRadius = maxRadius * curved.value;

          return Stack(
            children: [
              // Clipped new page expanding from center
              ClipPath(
                clipper: _CircleClipper(center: center, radius: currentRadius),
                child: child,
              ),

              // Gradient glow ring at the edge
              if (curved.value > 0.0 && curved.value < 1.0)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _RadialGlowPainter(
                      center: center,
                      radius: currentRadius,
                      opacity: (1.0 - curved.value).clamp(0.0, 0.6),
                    ),
                  ),
                ),
            ],
          );
        },
      );
    },
  );
}

/// Clips to a circle centered at [center] with given [radius].
class _CircleClipper extends CustomClipper<Path> {
  final Offset center;
  final double radius;
  _CircleClipper({required this.center, required this.radius});

  @override
  Path getClip(Size size) {
    return Path()..addOval(Rect.fromCircle(center: center, radius: radius));
  }

  @override
  bool shouldReclip(_CircleClipper oldClipper) =>
      oldClipper.radius != radius || oldClipper.center != center;
}

/// Paints a gradient glow ring at the expanding circle edge.
class _RadialGlowPainter extends CustomPainter {
  final Offset center;
  final double radius;
  final double opacity;

  _RadialGlowPainter({
    required this.center,
    required this.radius,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (radius <= 0 || opacity <= 0) return;

    const glowWidth = 30.0;
    final innerRadius = math.max(0.0, radius - glowWidth);

    final paint = Paint()
      ..shader = ui.Gradient.radial(
        center,
        radius,
        [
          _kPrimary.withValues(alpha: 0),
          _kPrimary.withValues(alpha: opacity * 0.4),
          _kSecondary.withValues(alpha: opacity * 0.6),
          _kTertiary.withValues(alpha: opacity * 0.3),
          _kTertiary.withValues(alpha: 0),
        ],
        [
          innerRadius / radius,
          (innerRadius + glowWidth * 0.3) / radius,
          (innerRadius + glowWidth * 0.5) / radius,
          (innerRadius + glowWidth * 0.8) / radius,
          1.0,
        ],
      )
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_RadialGlowPainter oldDelegate) =>
      oldDelegate.radius != radius ||
      oldDelegate.opacity != opacity ||
      oldDelegate.center != center;
}

// ════════════════════════════════════════════════════════════════════════════
// 3. DIAGONAL SLASH TRANSITION
// ════════════════════════════════════════════════════════════════════════════

/// Angled clip sweeps diagonally across the screen.
/// Thin gradient line on the slash edge.
///
/// Duration: 550ms with Curves.easeInOutCubic
/// Use for: tab switches, filter changes, category transitions
Route<T> diagonalSlashRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 550),
    reverseTransitionDuration: const Duration(milliseconds: 400),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOutCubic,
      );

      return AnimatedBuilder(
        animation: curved,
        builder: (context, _) {
          return Stack(
            children: [
              // Diagonally clipped new page
              ClipPath(
                clipper: _DiagonalSlashClipper(progress: curved.value),
                child: child,
              ),

              // Gradient line on the slash edge
              if (curved.value > 0.0 && curved.value < 1.0)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _DiagonalSlashLinePainter(
                      progress: curved.value,
                    ),
                  ),
                ),
            ],
          );
        },
      );
    },
  );
}

/// Clips with an angled diagonal that sweeps from top-left to bottom-right.
/// The slash angle is ~30 degrees for a clean visual.
class _DiagonalSlashClipper extends CustomClipper<Path> {
  final double progress;
  _DiagonalSlashClipper({required this.progress});

  @override
  Path getClip(Size size) {
    // The slash moves from left to right. At progress=0 nothing is visible,
    // at progress=1 everything is visible.
    // The "skew" is how far the diagonal extends horizontally.
    final skew = size.height * 0.35;
    // Total travel distance includes the skew overshoot
    final totalWidth = size.width + skew;
    final currentX = totalWidth * progress;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(currentX, 0)
      ..lineTo(currentX - skew, size.height)
      ..lineTo(0, size.height)
      ..close();

    return path;
  }

  @override
  bool shouldReclip(_DiagonalSlashClipper oldClipper) =>
      oldClipper.progress != progress;
}

/// Paints a thin gradient line along the diagonal slash edge.
class _DiagonalSlashLinePainter extends CustomPainter {
  final double progress;
  _DiagonalSlashLinePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final skew = size.height * 0.35;
    final totalWidth = size.width + skew;
    final currentX = totalWidth * progress;

    // The slash line goes from (currentX, 0) to (currentX - skew, height)
    final topPoint = Offset(currentX, 0);
    final bottomPoint = Offset(currentX - skew, size.height);

    // Draw the gradient line along the slash
    const lineWidth = 3.0;

    // Calculate perpendicular offset for line width
    final dx = bottomPoint.dx - topPoint.dx;
    final dy = bottomPoint.dy - topPoint.dy;
    final length = math.sqrt(dx * dx + dy * dy);
    final nx = -dy / length * lineWidth;
    final ny = dx / length * lineWidth;

    final path = Path()
      ..moveTo(topPoint.dx - nx, topPoint.dy - ny)
      ..lineTo(topPoint.dx + nx, topPoint.dy + ny)
      ..lineTo(bottomPoint.dx + nx, bottomPoint.dy + ny)
      ..lineTo(bottomPoint.dx - nx, bottomPoint.dy - ny)
      ..close();

    final paint = Paint()
      ..shader = ui.Gradient.linear(
        topPoint,
        bottomPoint,
        [_kPrimary, _kSecondary, _kTertiary],
        [0.0, 0.5, 1.0],
      )
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);

    // Soft glow
    const glowWidth = 16.0;
    final glowNx = -dy / length * glowWidth;
    final glowNy = dx / length * glowWidth;

    final glowPath = Path()
      ..moveTo(topPoint.dx - glowNx, topPoint.dy - glowNy)
      ..lineTo(topPoint.dx + glowNx, topPoint.dy + glowNy)
      ..lineTo(bottomPoint.dx + glowNx, bottomPoint.dy + glowNy)
      ..lineTo(bottomPoint.dx - glowNx, bottomPoint.dy - glowNy)
      ..close();

    final glowPaint = Paint()
      ..shader = ui.Gradient.linear(
        topPoint,
        bottomPoint,
        [
          _kPrimary.withValues(alpha: 0.1),
          _kSecondary.withValues(alpha: 0.15),
          _kTertiary.withValues(alpha: 0.1),
        ],
        [0.0, 0.5, 1.0],
      )
      ..style = PaintingStyle.fill;

    canvas.drawPath(glowPath, glowPaint);
  }

  @override
  bool shouldRepaint(_DiagonalSlashLinePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
