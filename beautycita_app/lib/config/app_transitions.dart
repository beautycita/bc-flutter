import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
// Paper Shredder Transition — cancel actions
//
// Captures the current screen, zooms it out onto a 3D stage, then feeds it
// through a shredder bar. Two copies + two masks: intact above, strips below.
// Tap anywhere to skip. 1200ms duration.
// ═══════════════════════════════════════════════════════════════════════════

/// Call this to play the shredder effect on the current screen.
/// [onComplete] fires after the animation (or skip). Use it to pop/navigate.
/// Wrap your Scaffold in a RepaintBoundary with [shredderBoundaryKey] as key.
final GlobalKey shredderBoundaryKey = GlobalKey();

Future<void> showShredderTransition(
  BuildContext context, {
  VoidCallback? onComplete,
  int stripCount = 30,
}) async {
  // Capture the screen
  final boundary = shredderBoundaryKey.currentContext?.findRenderObject()
      as RenderRepaintBoundary?;
  if (boundary == null) {
    onComplete?.call();
    return;
  }

  final image = await boundary.toImage(pixelRatio: 2.0);

  if (!context.mounted) {
    onComplete?.call();
    return;
  }

  final overlay = Overlay.of(context);
  late OverlayEntry entry;

  entry = OverlayEntry(
    builder: (_) => _ShredderOverlay(
      image: image,
      stripCount: stripCount,
      onComplete: () {
        entry.remove();
        onComplete?.call();
      },
    ),
  );

  overlay.insert(entry);
}

class _ShredderOverlay extends StatefulWidget {
  final ui.Image image;
  final int stripCount;
  final VoidCallback onComplete;

  const _ShredderOverlay({
    required this.image,
    required this.stripCount,
    required this.onComplete,
  });

  @override
  State<_ShredderOverlay> createState() => _ShredderOverlayState();
}

class _ShredderOverlayState extends State<_ShredderOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onComplete();
        }
      });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _skip() {
    if (_controller.isAnimating) {
      _controller.value = 1.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _skip,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            size: MediaQuery.of(context).size,
            painter: _ShredderPainter(
              image: widget.image,
              progress: _controller.value,
              stripCount: widget.stripCount,
            ),
          );
        },
      ),
    );
  }
}

class _ShredderPainter extends CustomPainter {
  final ui.Image image;
  final double progress;
  final int stripCount;

  _ShredderPainter({
    required this.image,
    required this.progress,
    required this.stripCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Black background
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.black);

    // Off-screen light source for depth
    final lightPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(-w * 0.1, -h * 0.07),
        w * 1.2,
        [
          const Color(0x59403050), // rgba(60,50,70,0.35)
          const Color(0x261E1928), // rgba(30,25,40,0.15)
          const Color(0x00000000),
        ],
        [0.0, 0.4, 1.0],
      );
    canvas.drawRect(Offset.zero & size, lightPaint);

    // Stage margins
    const mx = 20.0, mt = 20.0, mb = 40.0;
    final pW = w - mx * 2;
    final pH = h - mt - mb;

    // Shredder bar position
    final barY = mt + pH * 0.68;
    const barH = 10.0;

    // Zoom out: 0 → 0.12
    final zt = (progress / 0.12).clamp(0.0, 1.0);
    final ez = 1.0 - math.pow(1.0 - zt, 3).toDouble();

    final curMx = mx * ez;
    final curMt = mt * ez;
    final curW = w - curMx * 2;
    final curH = pH * ez + h * (1 - ez);

    // Slide: 0.12 → 1.0
    final st = progress <= 0.12 ? 0.0 : ((progress - 0.12) / 0.88).clamp(0.0, 1.0);
    final ss = st * st * (3 - 2 * st); // smoothstep
    final slide = ss * (pH + curH * 0.2);
    final pY = curMt + slide;

    // Source rect for the full image
    final srcRect = Rect.fromLTWH(
      0, 0, image.width.toDouble(), image.height.toDouble(),
    );

    // ── TOP MASK: intact page above the bar ──
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, w, barY));

    // Draw full page
    final dstRect = Rect.fromLTWH(curMx, pY, curW, curH);
    canvas.drawImageRect(image, srcRect, dstRect, Paint()..filterQuality = FilterQuality.medium);

    // Roller distortion: stretch bottom of visible page toward bar
    if (st > 0.03) {
      final visBot = math.min(pY + curH, barY);
      const dz = 25.0;
      final dStart = visBot - dz;
      if (dStart > pY) {
        final fY = (dStart - pY) / curH;
        final fH = (visBot - dStart) / curH;
        final stretch = math.min(st * 8, 1.0) * 18;
        final distSrc = Rect.fromLTWH(
          0, fY * image.height, image.width.toDouble(), fH * image.height,
        );
        final distDst = Rect.fromLTWH(
          curMx, dStart, curW, (visBot - dStart) + stretch,
        );
        canvas.drawImageRect(image, distSrc, distDst, Paint()..filterQuality = FilterQuality.medium);
      }
    }
    canvas.restore();

    // ── BOTTOM MASK: shredded strips below the bar ──
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, barY + barH, w, h - barY - barH));

    if (st > 0.01) {
      final stripW = curW / stripCount;
      final srcStripW = image.width / stripCount;

      for (int i = 0; i < stripCount; i++) {
        final jitter = 1.0 + math.sin(i * 7.3 + i * i * 0.3) * 0.05;
        final gap = st * 1.5;
        final wobble = math.sin(i * 4.7 + st * 18) * (1 + st * 2.5);
        final dw = stripW - gap;
        final dx = curMx + i * stripW + gap / 2 + wobble;

        final sSrc = Rect.fromLTWH(
          i * srcStripW, 0, srcStripW, image.height.toDouble(),
        );
        final sDst = Rect.fromLTWH(
          dx, pY * jitter, dw, curH * jitter,
        );
        canvas.drawImageRect(image, sSrc, sDst, Paint()..filterQuality = FilterQuality.low);
      }
    }
    canvas.restore();

    // ── SHREDDER BAR ──
    // Shadow above
    final shAbove = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, barY - 10), Offset(0, barY),
        [const Color(0x00000000), const Color(0xB3000000)],
      );
    canvas.drawRect(Rect.fromLTWH(0, barY - 10, w, 10), shAbove);

    // Bar body
    final barPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, barY), Offset(0, barY + barH),
        [
          const Color(0xFF444444),
          const Color(0xFF666666),
          const Color(0xFF777777),
          const Color(0xFF666666),
          const Color(0xFF444444),
        ],
        [0, 0.3, 0.5, 0.7, 1],
      );
    canvas.drawRect(Rect.fromLTWH(0, barY, w, barH), barPaint);

    // Highlight
    canvas.drawRect(
      Rect.fromLTWH(0, barY + 3, w, 1.5),
      Paint()..color = const Color(0x4DC8C8C8),
    );

    // Roller dots
    final dotPaint = Paint()..color = const Color(0xCC5A5A5A);
    for (double x = 8; x < w; x += 12) {
      canvas.drawCircle(Offset(x, barY + barH / 2), 2, dotPaint);
    }

    // Shadow below
    final shBelow = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, barY + barH), Offset(0, barY + barH + 10),
        [const Color(0xB3000000), const Color(0x00000000)],
      );
    canvas.drawRect(Rect.fromLTWH(0, barY + barH, w, 10), shBelow);
  }

  @override
  bool shouldRepaint(covariant _ShredderPainter old) =>
      old.progress != progress;
}

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
