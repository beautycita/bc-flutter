import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// ═══════════════════════════════════════════════════════════════════════════
// BeautyCita Custom Transitions
//
// Three transitions used throughout the app:
// 1. Sweep + Card Stagger — main navigation forward push
// 2. Radial Gradient Burst — detail views, dialogs, bottom sheets
// 3. Diagonal Gradient Fade — back navigation (pop)
// ═══════════════════════════════════════════════════════════════════════════

const _brandPink = Color(0xFFEC4899);
const _brandPurple = Color(0xFF9333EA);
const _brandBlue = Color(0xFF3B82F6);

// ── 1. SWEEP + CARD STAGGER ────────────────────────────────────────────────
// A gradient band sweeps left→right with a soft feathered edge.
// Behind it, content slides up in a staggered cascade.

Widget bcSweepStaggerTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  final screenW = MediaQuery.of(context).size.width;

  // The sweep band position: -bandWidth → screenW + bandWidth
  const bandWidth = 80.0;
  final sweepX = Tween<double>(
    begin: -bandWidth,
    end: screenW + bandWidth,
  ).animate(CurvedAnimation(
    parent: animation,
    curve: const Interval(0.0, 0.65, curve: Curves.easeInOut),
  ));

  // Content appears with a slight upward slide + fade, delayed after sweep starts
  final contentOpacity = CurvedAnimation(
    parent: animation,
    curve: const Interval(0.25, 0.80, curve: Curves.easeOut),
  );
  final contentSlide = Tween<Offset>(
    begin: const Offset(0, 0.04),
    end: Offset.zero,
  ).animate(CurvedAnimation(
    parent: animation,
    curve: const Interval(0.25, 0.85, curve: Curves.easeOutCubic),
  ));

  return AnimatedBuilder(
    animation: animation,
    builder: (context, _) {
      return Stack(
        children: [
          // Content behind the sweep — fades in with slide
          FadeTransition(
            opacity: contentOpacity,
            child: SlideTransition(
              position: contentSlide,
              child: child,
            ),
          ),
          // The gradient sweep band
          if (animation.value > 0.01 && animation.value < 0.90)
            Positioned(
              left: sweepX.value,
              top: 0,
              bottom: 0,
              child: Container(
                width: bandWidth,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.transparent,
                      _brandPink.withValues(alpha: 0.15),
                      _brandPink.withValues(alpha: 0.5),
                      _brandPurple.withValues(alpha: 0.8),
                      _brandBlue.withValues(alpha: 0.5),
                      _brandBlue.withValues(alpha: 0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

// ── 2. RADIAL GRADIENT BURST ───────────────────────────────────────────────
// Circular clip expands from center. Gradient glow on the edge.

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
      ClipPath(
        clipper: _CircleClipper(center: center, radius: radius),
        child: child,
      ),
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

// ── 3. DIAGONAL GRADIENT FADE ──────────────────────────────────────────────
// Angled gradient band sweeps diagonally. New content fades in behind it
// with a soft edge — no hard clip.

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

  final contentOpacity = CurvedAnimation(
    parent: animation,
    curve: const Interval(0.15, 0.75, curve: Curves.easeOut),
  );

  return AnimatedBuilder(
    animation: animation,
    builder: (context, _) {
      return Stack(
        children: [
          // Content fades in (no hard clip — soft reveal)
          FadeTransition(
            opacity: contentOpacity,
            child: child,
          ),
          // Diagonal gradient band sweeping across
          if (progress > 0.02 && progress < 0.95)
            CustomPaint(
              size: MediaQuery.of(context).size,
              painter: _DiagonalGradientBandPainter(progress: progress),
            ),
        ],
      );
    },
  );
}

class _DiagonalGradientBandPainter extends CustomPainter {
  final double progress;
  _DiagonalGradientBandPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    const bandWidth = 100.0;
    // The band sweeps from top-right to bottom-left
    // Progress 0 → band at top-right corner, progress 1 → band past bottom-left
    final totalTravel = size.width + size.height + bandWidth * 2;
    final offset = -bandWidth + totalTravel * progress;

    // The band runs perpendicular to the diagonal (top-right → bottom-left)
    // Angle: ~135° from horizontal
    const angle = -math.pi / 4; // 45° diagonal

    canvas.save();

    // Rotate canvas 45° and draw a vertical gradient band
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(angle);

    final bandRect = Rect.fromCenter(
      center: Offset(offset - totalTravel / 2, 0),
      width: bandWidth,
      height: size.width + size.height, // long enough to cover rotated canvas
    );

    // Opacity peaks in the middle of the animation
    final bandOpacity = (math.sin(progress * math.pi)).clamp(0.0, 1.0) * 0.7;

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.transparent,
          _brandPink.withValues(alpha: bandOpacity * 0.3),
          _brandPink.withValues(alpha: bandOpacity),
          _brandPurple.withValues(alpha: bandOpacity),
          _brandBlue.withValues(alpha: bandOpacity),
          _brandBlue.withValues(alpha: bandOpacity * 0.3),
          Colors.transparent,
        ],
      ).createShader(bandRect)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    canvas.drawRect(bandRect, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DiagonalGradientBandPainter old) =>
      old.progress != progress;
}

// ═══════════════════════════════════════════════════════════════════════════
// Page Builders for GoRouter
// ═══════════════════════════════════════════════════════════════════════════

/// Main navigation: sweep + stagger on push, diagonal gradient fade on pop
CustomTransitionPage<T> bcSweepPage<T>({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 550),
    reverseTransitionDuration: const Duration(milliseconds: 400),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (animation.status == AnimationStatus.reverse) {
        return bcDiagonalSlashTransition(
            context, animation, secondaryAnimation, child);
      }
      return bcSweepStaggerTransition(
          context, animation, secondaryAnimation, child);
    },
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

/// Tab/category switches: diagonal gradient fade
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

// ═══════════════════════════════════════════════════════════════════════════
// Radial Burst Wrappers for Dialogs & Bottom Sheets
// ═══════════════════════════════════════════════════════════════════════════

/// Shows a dialog with a radial burst animation expanding from screen center.
Future<T?> showBurstDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  String? barrierLabel,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
  Offset? anchorPoint,
}) {
  final size = MediaQuery.of(context).size;
  final maxRadius =
      math.sqrt(size.width * size.width + size.height * size.height);

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: barrierLabel ?? MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: barrierColor ?? Colors.black54,
    useRootNavigator: useRootNavigator,
    routeSettings: routeSettings,
    transitionDuration: const Duration(milliseconds: 500),
    pageBuilder: (ctx, animation, secondaryAnimation) => builder(ctx),
    transitionBuilder: (ctx, animation, secondaryAnimation, child) {
      final center = Offset(size.width / 2, size.height / 2);
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      final radius = curved.value * maxRadius;

      return Stack(
        children: [
          ClipPath(
            clipper: _CircleClipper(center: center, radius: radius),
            child: FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: const Interval(0.3, 1.0),
              ),
              child: child,
            ),
          ),
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
    },
  );
}

/// Shows a modal bottom sheet with a radial burst animation.
Future<T?> showBurstBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color? backgroundColor,
  ShapeBorder? shape,
  bool isScrollControlled = false,
  bool isDismissible = true,
  bool enableDrag = true,
  bool? showDragHandle,
  bool useRootNavigator = false,
  bool useSafeArea = false,
  BoxConstraints? constraints,
  RouteSettings? routeSettings,
}) {
  final size = MediaQuery.of(context).size;
  final maxRadius =
      math.sqrt(size.width * size.width + size.height * size.height);
  final center = Offset(size.width / 2, size.height);

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: isDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black54,
    useRootNavigator: useRootNavigator,
    routeSettings: routeSettings,
    transitionDuration: const Duration(milliseconds: 500),
    pageBuilder: (ctx, animation, secondaryAnimation) {
      final content = builder(ctx);
      return Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          color: backgroundColor ?? Theme.of(ctx).colorScheme.surface,
          shape: shape ??
              const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showDragHandle == true)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Container(
                      width: 32,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(ctx)
                            .colorScheme
                            .onSurfaceVariant
                            .withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                Flexible(child: content),
              ],
            ),
          ),
        ),
      );
    },
    transitionBuilder: (ctx, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      final radius = curved.value * maxRadius;

      return Stack(
        children: [
          ClipPath(
            clipper: _CircleClipper(center: center, radius: radius),
            child: child,
          ),
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
    },
  );
}
