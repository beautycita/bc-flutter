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
  final screenSize = MediaQuery.of(context).size;
  final cs = Theme.of(context).colorScheme;
  final brandColors = [cs.primary, cs.secondary, cs.tertiary];

  final sweepProgress = CurvedAnimation(
    parent: animation,
    curve: const Interval(0.0, 0.65, curve: Curves.easeInOutCubic),
  );

  final contentOpacity = CurvedAnimation(
    parent: animation,
    curve: const Interval(0.20, 0.85, curve: Curves.easeOut),
  );
  final contentSlide = Tween<Offset>(
    begin: const Offset(0, 0.05),
    end: Offset.zero,
  ).animate(CurvedAnimation(
    parent: animation,
    curve: const Interval(0.20, 0.85, curve: Curves.easeOutCubic),
  ));

  return AnimatedBuilder(
    animation: animation,
    builder: (context, _) {
      final t = sweepProgress.value;
      return Stack(
        children: [
          ClipPath(
            clipper: _DiagonalRevealClipper(progress: t, size: screenSize),
            child: SlideTransition(
              position: contentSlide,
              child: FadeTransition(
                opacity: contentOpacity,
                child: child,
              ),
            ),
          ),
          if (animation.value > 0.01 && animation.value < 0.99)
            CustomPaint(
              size: screenSize,
              painter: _DiagonalBandPainter(
                progress: t,
                screenSize: screenSize,
                colors: brandColors,
              ),
            ),
        ],
      );
    },
  );
}

class _DiagonalRevealClipper extends CustomClipper<Path> {
  final double progress;
  final Size size;
  _DiagonalRevealClipper({required this.progress, required this.size});

  @override
  Path getClip(Size size) {
    final diagonal = math.sqrt(size.width * size.width + size.height * size.height);
    final angle = math.atan2(size.width, size.height);
    const bandHalf = 60.0;
    final travel = progress * (diagonal + bandHalf * 2) - bandHalf;
    final dx = math.sin(angle);
    final dy = math.cos(angle);
    final cx = travel * dx;
    final cy = travel * dy;
    final px = -dy;
    final py = dx;
    final extend = diagonal;
    final x1 = cx + px * extend;
    final y1 = cy + py * extend;
    final x2 = cx - px * extend;
    final y2 = cy - py * extend;
    final path = Path();
    path.moveTo(x1, y1);
    path.lineTo(x2, y2);
    path.lineTo(x2 - dx * diagonal * 2, y2 - dy * diagonal * 2);
    path.lineTo(x1 - dx * diagonal * 2, y1 - dy * diagonal * 2);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant _DiagonalRevealClipper old) => old.progress != progress;
}

class _DiagonalBandPainter extends CustomPainter {
  final double progress;
  final Size screenSize;
  final List<Color> colors;
  _DiagonalBandPainter({required this.progress, required this.screenSize, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final diagonal = math.sqrt(size.width * size.width + size.height * size.height);
    final angle = math.atan2(size.width, size.height);
    const bandHalf = 60.0;
    final travel = progress * (diagonal + bandHalf * 2) - bandHalf;
    final cx = travel * math.sin(angle);
    final cy = travel * math.cos(angle);
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(angle);
    final bandRect = Rect.fromCenter(center: Offset.zero, width: bandHalf * 2, height: diagonal * 2);
    final edgeFade = (1.0 - (progress * 2 - 1).abs()).clamp(0.0, 1.0);
    final alpha = 0.7 * edgeFade;
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.transparent,
          colors[0].withValues(alpha: alpha * 0.3),
          colors[0].withValues(alpha: alpha * 0.7),
          colors[1].withValues(alpha: alpha),
          colors[2].withValues(alpha: alpha * 0.7),
          colors[2].withValues(alpha: alpha * 0.3),
          Colors.transparent,
        ],
      ).createShader(bandRect)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawRect(bandRect, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DiagonalBandPainter old) => old.progress != progress;
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
    transitionDuration: const Duration(milliseconds: 650),
    reverseTransitionDuration: const Duration(milliseconds: 450),
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
