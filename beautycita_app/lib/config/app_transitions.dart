import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// ═══════════════════════════════════════════════════════════════════════════
// BeautyCita Custom Transitions
//
// Three transitions used throughout the app:
// 1. Sweep + Card Stagger — main navigation (settings → sub-page)
// 2. Radial Gradient Burst — opening detail views, modals
// 3. Diagonal Slash — tab switches, category changes
// ═══════════════════════════════════════════════════════════════════════════

const _brandPink = Color(0xFFEC4899);
const _brandPurple = Color(0xFF9333EA);
const _brandBlue = Color(0xFF3B82F6);
const _brandGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [_brandPink, _brandPurple, _brandBlue],
);

// ── 1. SWEEP + CARD STAGGER ────────────────────────────────────────────────
// Gradient line sweeps left→right revealing new page.
// After sweep completes (~60% of animation), content fades+slides up.

Widget bcSweepStaggerTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  // Sweep occupies 0.0-0.6, content stagger occupies 0.4-1.0 (overlaps)
  final sweepProgress = CurvedAnimation(
    parent: animation,
    curve: const Interval(0.0, 0.6, curve: Curves.easeInOut),
  );
  final contentFade = CurvedAnimation(
    parent: animation,
    curve: const Interval(0.35, 0.85, curve: Curves.easeOut),
  );
  final contentSlide = Tween<Offset>(
    begin: const Offset(0, 0.03),
    end: Offset.zero,
  ).animate(CurvedAnimation(
    parent: animation,
    curve: const Interval(0.35, 0.85, curve: Curves.easeOut),
  ));

  return Stack(
    children: [
      // New page clips in behind the sweep line
      ClipRect(
        clipper: _HorizontalClipClipper(sweepProgress.value),
        child: FadeTransition(
          opacity: contentFade,
          child: SlideTransition(
            position: contentSlide,
            child: child,
          ),
        ),
      ),
      // The gradient sweep line
      if (sweepProgress.value > 0.01 && sweepProgress.value < 0.99)
        Positioned(
          left: MediaQuery.of(context).size.width * sweepProgress.value - 3,
          top: 0,
          bottom: 0,
          child: Container(
            width: 5,
            decoration: BoxDecoration(
              gradient: _brandGradient,
              boxShadow: [
                BoxShadow(
                  color: _brandPurple.withValues(alpha: 0.6),
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: _brandPink.withValues(alpha: 0.3),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
        ),
    ],
  );
}

class _HorizontalClipClipper extends CustomClipper<Rect> {
  final double progress;
  _HorizontalClipClipper(this.progress);

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(0, 0, size.width * progress.clamp(0.0, 1.0), size.height);

  @override
  bool shouldReclip(covariant _HorizontalClipClipper old) =>
      old.progress != progress;
}

// ── 2. RADIAL GRADIENT BURST ───────────────────────────────────────────────
// Circular clip expands from center (or tap point). Glow on the edge.
// Used for: detail views, modals, expanding cards.

Widget bcRadialBurstTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  final size = MediaQuery.of(context).size;
  final maxRadius = math.sqrt(size.width * size.width + size.height * size.height);
  final radius = CurvedAnimation(
    parent: animation,
    curve: Curves.easeOutCubic,
  ).value * maxRadius;

  final center = Offset(size.width / 2, size.height / 2);

  return Stack(
    children: [
      // Clip the new page in a circle
      ClipPath(
        clipper: _CircleClipper(center: center, radius: radius),
        child: child,
      ),
      // Gradient glow ring on the expanding edge
      if (animation.value > 0.01 && animation.value < 0.85)
        CustomPaint(
          size: size,
          painter: _RadialGlowPainter(
            center: center,
            radius: radius,
            opacity: (1.0 - animation.value).clamp(0.0, 0.6),
          ),
        ),
    ],
  );
}

class _CircleClipper extends CustomClipper<Path> {
  final Offset center;
  final double radius;
  _CircleClipper({required this.center, required this.radius});

  @override
  Path getClip(Size size) =>
      Path()..addOval(Rect.fromCircle(center: center, radius: radius));

  @override
  bool shouldReclip(covariant _CircleClipper old) =>
      old.radius != radius || old.center != center;
}

class _RadialGlowPainter extends CustomPainter {
  final Offset center;
  final double radius;
  final double opacity;
  _RadialGlowPainter({required this.center, required this.radius, required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    if (radius < 1) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..shader = SweepGradient(
        center: Alignment.center,
        colors: [
          _brandPink.withValues(alpha: opacity),
          _brandPurple.withValues(alpha: opacity),
          _brandBlue.withValues(alpha: opacity),
          _brandPink.withValues(alpha: opacity),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _RadialGlowPainter old) =>
      old.radius != radius || old.opacity != opacity;
}

// ── 3. DIAGONAL SLASH ──────────────────────────────────────────────────────
// Angled gradient line cuts diagonally across, revealing new content.
// Used for: tab switches, category transitions, filter changes.

Widget bcDiagonalSlashTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  final progress = CurvedAnimation(
    parent: animation,
    curve: Curves.easeInOutCubic,
  ).value;

  return Stack(
    children: [
      // New page clips in with diagonal edge
      ClipPath(
        clipper: _DiagonalClipper(progress),
        child: child,
      ),
      // The gradient slash line
      if (progress > 0.02 && progress < 0.98)
        CustomPaint(
          size: MediaQuery.of(context).size,
          painter: _DiagonalSlashPainter(progress: progress),
        ),
    ],
  );
}

class _DiagonalClipper extends CustomClipper<Path> {
  final double progress;
  _DiagonalClipper(this.progress);

  @override
  Path getClip(Size size) {
    // Diagonal from top-right to bottom-left, sweeping left-to-right
    final offset = size.width * progress * 1.4; // 1.4 to account for angle
    return Path()
      ..moveTo(offset - size.height * 0.15, 0)
      ..lineTo(offset + size.width * 0.1, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(offset - size.height * 0.15 - size.width * 0.1, size.height)
      ..lineTo(offset - size.height * 0.15, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant _DiagonalClipper old) => old.progress != progress;
}

class _DiagonalSlashPainter extends CustomPainter {
  final double progress;
  _DiagonalSlashPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final offset = size.width * progress * 1.4;
    final paint = Paint()
      ..strokeWidth = 4
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_brandPink, _brandPurple, _brandBlue],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final path = Path()
      ..moveTo(offset - size.height * 0.15, 0)
      ..lineTo(offset - size.height * 0.15 - size.width * 0.1, size.height);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _DiagonalSlashPainter old) => old.progress != progress;
}

// ═══════════════════════════════════════════════════════════════════════════
// Page Builders for GoRouter
// ═══════════════════════════════════════════════════════════════════════════

/// Main navigation: sweep + stagger
CustomTransitionPage<T> bcSweepPage<T>({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 550),
    reverseTransitionDuration: const Duration(milliseconds: 400),
    transitionsBuilder: bcSweepStaggerTransition,
  );
}

/// Detail views: radial burst
CustomTransitionPage<T> bcBurstPage<T>({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 600),
    reverseTransitionDuration: const Duration(milliseconds: 400),
    transitionsBuilder: bcRadialBurstTransition,
  );
}

/// Tab/category switches: diagonal slash
CustomTransitionPage<T> bcSlashPage<T>({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 450),
    reverseTransitionDuration: const Duration(milliseconds: 350),
    transitionsBuilder: bcDiagonalSlashTransition,
  );
}
