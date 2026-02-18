import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../config/constants.dart';
import '../../../main.dart' show supabaseReady;
import '../../../providers/auth_provider.dart';
import 'bg_widgets.dart';

class BGSplashScreen extends ConsumerStatefulWidget {
  const BGSplashScreen({super.key});

  @override
  ConsumerState<BGSplashScreen> createState() => _BGSplashScreenState();
}

class _BGSplashScreenState extends ConsumerState<BGSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _wordmarkFade;
  late Animation<double> _wordmarkScale;
  late Animation<double> _lineWidth;
  late Animation<double> _taglineFade;
  late Animation<double> _ringScale;
  late Animation<double> _ringOpacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );

    // Outer ring pulse before wordmark appears
    _ringScale = Tween(begin: 0.6, end: 1.4).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );
    _ringOpacity = Tween(begin: 0.5, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    _wordmarkFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.18, 0.48, curve: Curves.easeOut),
      ),
    );
    _wordmarkScale = Tween(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.18, 0.48, curve: Curves.easeOutBack),
      ),
    );
    _lineWidth = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.48, 0.68, curve: Curves.easeOut),
      ),
    );
    _taglineFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.68, 0.88, curve: Curves.easeOut),
      ),
    );

    _controller.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthAndNavigate();
    });
  }

  Future<void> _checkAuthAndNavigate() async {
    await supabaseReady.future;
    try {
      await ref.read(authStateProvider.notifier).checkRegistration();
    } catch (_) {}
    await Future.delayed(AppConstants.splashDuration);
    if (!mounted) return;
    final authState = ref.read(authStateProvider);
    if (authState.isAuthenticated) {
      context.go('/home');
    } else {
      context.go('/auth');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = BGColors.of(context);
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: c.surface0,
      body: Stack(
        children: [
          // Gold particle field (25 particles)
          ...List.generate(25, (i) => _GoldParticle(index: i)),

          // Expanding ring (pre-wordmark reveal)
          Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return Transform.scale(
                  scale: _ringScale.value,
                  child: Opacity(
                    opacity: _ringOpacity.value,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: c.goldMid.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Center content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Wordmark with shimmer
                FadeTransition(
                  opacity: _wordmarkFade,
                  child: ScaleTransition(
                    scale: _wordmarkScale,
                    child: BGGoldShimmer(
                      child: Text(
                        AppConstants.appName,
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 44,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Gold expanding line
                AnimatedBuilder(
                  animation: _lineWidth,
                  builder: (context, _) {
                    return Container(
                      height: 1,
                      width: screenWidth * 0.55 * _lineWidth.value,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            c.goldMid.withValues(alpha: 0.0),
                            c.goldMid,
                            c.goldMid.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 20),

                // Tagline
                FadeTransition(
                  opacity: _taglineFade,
                  child: Text(
                    AppConstants.tagline.toUpperCase(),
                    style: GoogleFonts.lato(
                      fontSize: 12,
                      fontWeight: FontWeight.w300,
                      color: c.goldMid.withValues(alpha: 0.75),
                      letterSpacing: 3.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A single gold particle drifting slowly.
class _GoldParticle extends StatefulWidget {
  final int index;
  const _GoldParticle({required this.index});

  @override
  State<_GoldParticle> createState() => _GoldParticleState();
}

class _GoldParticleState extends State<_GoldParticle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late double _startX;
  late double _startY;
  late double _size;
  late double _opacity;

  @override
  void initState() {
    super.initState();
    final rng = math.Random(widget.index * 42);
    _startX = rng.nextDouble();
    _startY = rng.nextDouble();
    _size = 1.5 + rng.nextDouble() * 2.5;
    _opacity = 0.15 + rng.nextDouble() * 0.35;

    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 4000 + rng.nextInt(4000)),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = BGColors.of(context);
    final size = MediaQuery.of(context).size;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final drift = _controller.value * 0.03;
        return Positioned(
          left: (_startX + drift) * size.width,
          top: (_startY - drift * 0.5) * size.height,
          child: Container(
            width: _size,
            height: _size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.goldLight.withValues(
                  alpha: _opacity * (0.5 + _controller.value * 0.5)),
            ),
          ),
        );
      },
    );
  }
}
