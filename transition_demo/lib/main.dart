import 'dart:math' as math;
import 'package:flutter/material.dart';

void main() => runApp(const TransitionDemoApp());

class TransitionDemoApp extends StatelessWidget {
  const TransitionDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFFEC4899),
          secondary: const Color(0xFF9333EA),
          tertiary: const Color(0xFF3B82F6),
        ),
      ),
      home: const PageA(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Double Radial Burst Transition
//
// 1st circle: expands from random point, masks screen to BLACK
// 2nd circle: 100ms behind, expands from same point, REVEALS new page
// ═══════════════════════════════════════════════════════════════════════════

class DoubleRadialBurstRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  DoubleRadialBurstRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 600),
          reverseTransitionDuration: const Duration(milliseconds: 500),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final size = MediaQuery.of(context).size;
            final maxRadius = math.sqrt(
                size.width * size.width + size.height * size.height);

            // Random focal point (computed once per route via _seed)
            final rng = math.Random(animation.hashCode);
            final focal = Offset(
              size.width * (0.15 + rng.nextDouble() * 0.7),
              size.height * (0.15 + rng.nextDouble() * 0.7),
            );

            // 1st circle: mask to black (leads)
            final maskRadius = CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 0.75, curve: Curves.easeOutCubic),
            );

            // 2nd circle: reveal new page (trails by ~15%)
            final revealRadius = CurvedAnimation(
              parent: animation,
              curve: const Interval(0.15, 0.90, curve: Curves.easeOutCubic),
            );

            return AnimatedBuilder(
              animation: animation,
              builder: (context, _) {
                final maskR = maskRadius.value * maxRadius;
                final revealR = revealRadius.value * maxRadius;

                return Stack(
                  children: [
                    // Layer 1: Black mask circle expanding over old page
                    ClipPath(
                      clipper: _CircleClipper(center: focal, radius: maskR),
                      child: Container(color: Colors.black),
                    ),

                    // Layer 2: New page revealed by second circle
                    ClipPath(
                      clipper: _CircleClipper(center: focal, radius: revealR),
                      child: child,
                    ),
                  ],
                );
              },
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
// Demo Pages
// ═══════════════════════════════════════════════════════════════════════════

class PageA extends StatelessWidget {
  const PageA({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.spa_rounded, size: 80, color: Color(0xFFEC4899)),
            const SizedBox(height: 24),
            Text(
              'Page A',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap anywhere to navigate',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white54,
                  ),
            ),
            const SizedBox(height: 40),
            // Fake cards to see the stagger effect
            for (int i = 0; i < 3; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 6),
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFEC4899).withValues(alpha: 0.3),
                        const Color(0xFF9333EA).withValues(alpha: 0.3),
                      ],
                    ),
                    border: Border.all(
                        color: const Color(0xFFEC4899).withValues(alpha: 0.5)),
                  ),
                  child: Center(
                    child: Text('Card ${i + 1}',
                        style: const TextStyle(color: Colors.white70)),
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFEC4899),
        onPressed: () {
          Navigator.of(context).push(
            DoubleRadialBurstRoute(page: const PageB()),
          );
        },
        child: const Icon(Icons.arrow_forward_rounded),
      ),
    );
  }
}

class PageB extends StatelessWidget {
  const PageB({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f0f23),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome_rounded,
                size: 80, color: Color(0xFF3B82F6)),
            const SizedBox(height: 24),
            Text(
              'Page B',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap back or FAB to return',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white54,
                  ),
            ),
            const SizedBox(height: 40),
            for (int i = 0; i < 3; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 6),
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF3B82F6).withValues(alpha: 0.3),
                        const Color(0xFF9333EA).withValues(alpha: 0.3),
                      ],
                    ),
                    border: Border.all(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.5)),
                  ),
                  child: Center(
                    child: Text('Result ${i + 1}',
                        style: const TextStyle(color: Colors.white70)),
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF3B82F6),
        onPressed: () => Navigator.of(context).pop(),
        child: const Icon(Icons.arrow_back_rounded),
      ),
    );
  }
}
