import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// ═══════════════════════════════════════════════════════════════════════════
// BeautyCita Custom Transitions
//
// Double Radial Burst — page navigation (all routes)
// Standard Material — dialogs & bottom sheets (no custom transition)
// ═══════════════════════════════════════════════════════════════════════════

// ── DOUBLE RADIAL BURST ─────────────────────────────────────────────────
// Phase 1: Black circle expands from random focal point → covers screen
// Phase 2: From same point, new page circle expands → eats the black
//
// Duration: 800ms, gap between phases scales with screen diagonal

final math.Random _focalRng = math.Random();

Widget _doubleRadialBurstTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  final size = MediaQuery.of(context).size;
  final maxRadius = math.sqrt(size.width * size.width + size.height * size.height);

  // Random focal point (15%-85% of each axis), stable per route
  // Use animation hashCode as seed so it's consistent for the same route push
  final rng = math.Random(animation.hashCode);
  final focal = Offset(
    size.width * (0.15 + rng.nextDouble() * 0.7),
    size.height * (0.15 + rng.nextDouble() * 0.7),
  );

  // Gap scales with screen size: ~0.35 of the animation for the delay
  // Phase 1 (black mask): 0.0 → 0.65
  // Phase 2 (reveal):     0.35 → 1.0
  final blackRadius = CurvedAnimation(
    parent: animation,
    curve: const Interval(0.0, 0.65, curve: Curves.easeOutCubic),
  );
  final revealRadius = CurvedAnimation(
    parent: animation,
    curve: const Interval(0.35, 1.0, curve: Curves.easeOutCubic),
  );

  return AnimatedBuilder(
    animation: animation,
    builder: (context, _) {
      final blackR = blackRadius.value * maxRadius;
      final revealR = revealRadius.value * maxRadius;

      return Stack(
        children: [
          // Black mask expanding from focal point
          ClipPath(
            clipper: _CircleClipper(center: focal, radius: blackR),
            child: const ColoredBox(
              color: Colors.black,
              child: SizedBox.expand(),
            ),
          ),
          // New page expanding from same focal point, above the black
          ClipPath(
            clipper: _CircleClipper(center: focal, radius: revealR),
            child: child,
          ),
        ],
      );
    },
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

// ═══════════════════════════════════════════════════════════════════════════
// Page Builders for GoRouter
// ═══════════════════════════════════════════════════════════════════════════

/// Primary page transition — double radial burst
CustomTransitionPage<T> bcSweepPage<T>({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 1200),
    reverseTransitionDuration: const Duration(milliseconds: 850),
    transitionsBuilder: _doubleRadialBurstTransition,
  );
}

/// Alias — all page transitions use the same double radial burst now
CustomTransitionPage<T> bcBurstPage<T>({
  required LocalKey key,
  required Widget child,
}) => bcSweepPage(key: key, child: child);

/// Alias — all page transitions use the same double radial burst now
CustomTransitionPage<T> bcSlashPage<T>({
  required LocalKey key,
  required Widget child,
}) => bcSweepPage(key: key, child: child);

// ═══════════════════════════════════════════════════════════════════════════
// Dialogs & Bottom Sheets — standard Material (no custom transition)
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
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor,
    useRootNavigator: useRootNavigator,
    routeSettings: routeSettings,
    anchorPoint: anchorPoint,
    builder: builder,
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
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: backgroundColor,
    shape: shape,
    isScrollControlled: isScrollControlled,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    showDragHandle: showDragHandle,
    useRootNavigator: useRootNavigator,
    useSafeArea: useSafeArea,
    constraints: constraints,
    routeSettings: routeSettings,
    builder: builder,
  );
}

// Legacy aliases
Widget bcSweepStaggerTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) => _doubleRadialBurstTransition(context, animation, secondaryAnimation, child);

Widget bcDiagonalSlashTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) => _doubleRadialBurstTransition(context, animation, secondaryAnimation, child);

Widget bcRadialBurstTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) => _doubleRadialBurstTransition(context, animation, secondaryAnimation, child);

// ═══════════════════════════════════════════════════════════════════════════
// BcStaggeredList — drop-in ListView replacement with route-driven stagger
// ═══════════════════════════════════════════════════════════════════════════

class BcStaggeredList extends StatelessWidget {
  final List<Widget> children;
  final ScrollPhysics? physics;
  final EdgeInsetsGeometry? padding;
  final bool shrinkWrap;

  const BcStaggeredList({
    super.key,
    required this.children,
    this.physics,
    this.padding,
    this.shrinkWrap = false,
  });

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context);
    final animation = route?.animation;

    if (animation == null || animation.isCompleted) {
      return ListView(
        physics: physics,
        padding: padding,
        shrinkWrap: shrinkWrap,
        children: children,
      );
    }

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        if (animation.isCompleted) {
          return ListView(
            physics: physics,
            padding: padding,
            shrinkWrap: shrinkWrap,
            children: children,
          );
        }

        return ListView(
          physics: physics,
          padding: padding,
          shrinkWrap: shrinkWrap,
          children: [
            for (int i = 0; i < children.length; i++)
              _BcStaggerItem(
                animation: animation,
                index: i,
                child: children[i],
              ),
          ],
        );
      },
    );
  }
}

class _BcStaggerItem extends StatelessWidget {
  final Animation<double> animation;
  final int index;
  final Widget child;

  const _BcStaggerItem({
    required this.animation,
    required this.index,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final slot = index.clamp(0, 7);
    final start = 0.55 + slot * 0.04;
    final end = (start + 0.18).clamp(0.0, 1.0);

    final itemAnimation = CurvedAnimation(
      parent: animation,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );

    return FadeTransition(
      opacity: itemAnimation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(itemAnimation),
        child: child,
      ),
    );
  }
}
