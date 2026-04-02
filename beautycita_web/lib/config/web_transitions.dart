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

  return AnimatedBuilder(
    animation: animation,
    builder: (context, _) {
      final isReverse = animation.status == AnimationStatus.reverse;

      if (isReverse) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      }

      final t = animation.value;

      final blackT = Curves.easeOutExpo.transform(
        (t / 0.60).clamp(0.0, 1.0),
      );
      final revealT = Curves.easeOutQuart.transform(
        ((t - 0.30) / 0.70).clamp(0.0, 1.0),
      );

      final blackR = blackT * maxRadius * 1.05;
      final revealR = revealT * maxRadius * 1.05;

      final pageScale = 0.96 + 0.04 * revealT;
      final pageOpacity = (revealT / 0.4).clamp(0.0, 1.0);

      return Stack(
        children: [
          ClipPath(
            clipper: _CircleClipper(center: focal, radius: blackR),
            child: const ColoredBox(
              color: Colors.black,
              child: SizedBox.expand(),
            ),
          ),
          if (blackT > 0.01 && blackT < 0.95)
            CustomPaint(
              size: size,
              painter: _CircleGlowPainter(
                center: focal,
                radius: blackR,
                opacity: (1.0 - blackT) * 0.3,
              ),
            ),
          ClipPath(
            clipper: _CircleClipper(center: focal, radius: revealR),
            child: Transform.scale(
              scale: pageScale,
              alignment: Alignment(
                (focal.dx / size.width) * 2 - 1,
                (focal.dy / size.height) * 2 - 1,
              ),
              child: Opacity(
                opacity: pageOpacity,
                child: child,
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _CircleGlowPainter extends CustomPainter {
  final Offset center;
  final double radius;
  final double opacity;
  _CircleGlowPainter({required this.center, required this.radius, required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity < 0.01) return;
    canvas.drawCircle(
      center, radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 30
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15)
        ..color = Color.fromRGBO(200, 162, 200, opacity), // lila #C8A2C8
    );
  }

  @override
  bool shouldRepaint(covariant _CircleGlowPainter old) =>
      old.radius != radius || old.opacity != opacity;
}

/// Main navigation transition
Route<T> gradientSweepRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 250),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: _doubleRadialBurst,
  );
}

/// Detail views
Route<T> radialBurstRoute<T>(Widget page, {Offset? origin}) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 250),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: _doubleRadialBurst,
  );
}

/// Tab/filter changes
Route<T> diagonalSlashRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 250),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: _doubleRadialBurst,
  );
}
