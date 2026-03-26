import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// ═══════════════════════════════════════════════════════════════════════════
// BeautyCita Custom Transitions
//
// Two transitions:
// 1. Soft Gradient Band — primary (all page navigation, push & pop)
// 2. Radial Gradient Burst — dialogs & bottom sheets
// ═══════════════════════════════════════════════════════════════════════════

const _brandPink = Color(0xFFEC4899);
const _brandPurple = Color(0xFF9333EA);
const _brandBlue = Color(0xFF3B82F6);

// ── 1. SOFT GRADIENT BAND ──────────────────────────────────────────────────
// A gradient band sweeps left→right with soft feathered edges.
// Content fades in with a slight upward slide behind it.

Widget bcSweepStaggerTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  final screenW = MediaQuery.of(context).size.width;

  const bandWidth = 80.0;
  final sweepX = Tween<double>(
    begin: -bandWidth,
    end: screenW + bandWidth,
  ).animate(CurvedAnimation(
    parent: animation,
    curve: const Interval(0.0, 0.65, curve: Curves.easeInOut),
  ));

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
          FadeTransition(
            opacity: contentOpacity,
            child: SlideTransition(
              position: contentSlide,
              child: child,
            ),
          ),
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

// ═══════════════════════════════════════════════════════════════════════════
// Page Builders for GoRouter
// ═══════════════════════════════════════════════════════════════════════════

/// Primary page transition — soft gradient band (push and pop)
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

// Keep bcSlashPage as alias → same as sweep (no diagonal)
CustomTransitionPage<T> bcSlashPage<T>({
  required LocalKey key,
  required Widget child,
}) => bcSweepPage(key: key, child: child);

// ═══════════════════════════════════════════════════════════════════════════
// Radial Burst Wrappers for Dialogs & Bottom Sheets
// ═══════════════════════════════════════════════════════════════════════════

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

// Legacy alias — diagonal slash removed, maps to sweep
Widget bcDiagonalSlashTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) => bcSweepStaggerTransition(context, animation, secondaryAnimation, child);
