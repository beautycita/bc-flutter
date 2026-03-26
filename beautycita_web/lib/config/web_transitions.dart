import 'dart:math' as math;
import 'package:flutter/material.dart';

// ============================================================================
// Web Page Transitions — Double Radial Burst
//
// Phase 1: Black circle expands from tap point → covers screen
// Phase 2: From same point, new page circle expands → eats the black
// Both push and pop always expand (never contracts).
// ============================================================================

/// Global tap position tracker. Wrap your app root in this widget.
Offset _lastTapPosition = const Offset(0, 0);
bool _hasTapPosition = false;

class BcWebTapTracker extends StatelessWidget {
  final Widget child;
  const BcWebTapTracker({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) {
        _lastTapPosition = event.position;
        _hasTapPosition = true;
      },
      behavior: HitTestBehavior.translucent,
      child: child,
    );
  }
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

Widget _doubleRadialBurst(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  final size = MediaQuery.of(context).size;
  final maxRadius = math.sqrt(size.width * size.width + size.height * size.height);

  final focal = _hasTapPosition
      ? _lastTapPosition
      : Offset(size.width / 2, size.height / 2);

  final isReverse = animation.status == AnimationStatus.reverse;

  return AnimatedBuilder(
    animation: animation,
    builder: (context, _) {
      final rawT = animation.value;
      final t = isReverse ? 1.0 - rawT : rawT;

      final blackT = Curves.easeOutCubic.transform(
        (t / 0.65).clamp(0.0, 1.0),
      );
      final revealT = Curves.easeOutCubic.transform(
        ((t - 0.35) / 0.65).clamp(0.0, 1.0),
      );

      final blackR = blackT * maxRadius;
      final revealR = revealT * maxRadius;

      return Stack(
        children: [
          ClipPath(
            clipper: _CircleClipper(center: focal, radius: blackR),
            child: const ColoredBox(
              color: Colors.black,
              child: SizedBox.expand(),
            ),
          ),
          ClipPath(
            clipper: _CircleClipper(center: focal, radius: revealR),
            child: child,
          ),
        ],
      );
    },
  );
}

/// Main navigation transition
Route<T> gradientSweepRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 1200),
    reverseTransitionDuration: const Duration(milliseconds: 850),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: _doubleRadialBurst,
  );
}

/// Detail views
Route<T> radialBurstRoute<T>(Widget page, {Offset? origin}) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 1200),
    reverseTransitionDuration: const Duration(milliseconds: 850),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: _doubleRadialBurst,
  );
}

/// Tab/filter changes
Route<T> diagonalSlashRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 1200),
    reverseTransitionDuration: const Duration(milliseconds: 850),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: _doubleRadialBurst,
  );
}
