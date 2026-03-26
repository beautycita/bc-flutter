import 'dart:math' as math;
import 'package:flutter/material.dart';

// ============================================================================
// Web Page Transitions — Double Radial Burst
//
// Phase 1: Black circle expands from random focal point → covers screen
// Phase 2: From same point, new page circle expands → eats the black
// ============================================================================

final math.Random _focalRng = math.Random();

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

  final rng = math.Random(animation.hashCode);
  final focal = Offset(
    size.width * (0.15 + rng.nextDouble() * 0.7),
    size.height * (0.15 + rng.nextDouble() * 0.7),
  );

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
    transitionDuration: const Duration(milliseconds: 800),
    reverseTransitionDuration: const Duration(milliseconds: 600),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: _doubleRadialBurst,
  );
}

/// Detail views
Route<T> radialBurstRoute<T>(Widget page, {Offset? origin}) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 800),
    reverseTransitionDuration: const Duration(milliseconds: 600),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: _doubleRadialBurst,
  );
}

/// Tab/filter changes
Route<T> diagonalSlashRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 800),
    reverseTransitionDuration: const Duration(milliseconds: 600),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: _doubleRadialBurst,
  );
}
