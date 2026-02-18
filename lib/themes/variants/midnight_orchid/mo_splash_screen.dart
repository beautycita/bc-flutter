import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../config/constants.dart';
import '../../../main.dart' show supabaseReady;
import '../../../providers/auth_provider.dart';
import 'mo_widgets.dart';

class MOSplashScreen extends ConsumerStatefulWidget {
  const MOSplashScreen({super.key});

  @override
  ConsumerState<MOSplashScreen> createState() => _MOSplashScreenState();
}

class _MOSplashScreenState extends ConsumerState<MOSplashScreen>
    with TickerProviderStateMixin {
  // Wordmark bloom-in
  late AnimationController _wordmarkCtrl;
  late Animation<double> _wordmarkFade;
  late Animation<double> _wordmarkScale;
  late Animation<double> _taglineFade;

  // Expanding glow rings (3 concentric, different speeds)
  late AnimationController _ring1Ctrl;
  late AnimationController _ring2Ctrl;
  late AnimationController _ring3Ctrl;
  late Animation<double> _ring1Anim;
  late Animation<double> _ring2Anim;
  late Animation<double> _ring3Anim;

  // Central bloom glow that expands from center
  late AnimationController _bloomCtrl;
  late Animation<double> _bloomRadius;
  late Animation<double> _bloomOpacity;

  @override
  void initState() {
    super.initState();

    // Wordmark
    _wordmarkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _wordmarkFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _wordmarkCtrl,
        curve: const Interval(0.15, 0.55, curve: Curves.easeOut),
      ),
    );
    _wordmarkScale = Tween(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _wordmarkCtrl,
        curve: const Interval(0.15, 0.60, curve: Curves.easeOutCubic),
      ),
    );
    _taglineFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _wordmarkCtrl,
        curve: const Interval(0.60, 0.90, curve: Curves.easeOut),
      ),
    );

    // Glow rings — 3 loops at slightly different speeds (bioluminescent feel)
    _ring1Ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
    _ring2Ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
    _ring3Ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();

    _ring1Anim = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ring1Ctrl, curve: Curves.easeOut),
    );
    _ring2Anim = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ring2Ctrl, curve: Curves.easeOut),
    );
    _ring3Anim = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ring3Ctrl, curve: Curves.easeOut),
    );

    // Central bloom glow
    _bloomCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _bloomRadius = Tween(begin: 40.0, end: 70.0).animate(
      CurvedAnimation(parent: _bloomCtrl, curve: Curves.easeInOut),
    );
    _bloomOpacity = Tween(begin: 0.10, end: 0.28).animate(
      CurvedAnimation(parent: _bloomCtrl, curve: Curves.easeInOut),
    );

    _wordmarkCtrl.forward();

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
    _wordmarkCtrl.dispose();
    _ring1Ctrl.dispose();
    _ring2Ctrl.dispose();
    _ring3Ctrl.dispose();
    _bloomCtrl.dispose();
    super.dispose();
  }

  Widget _buildExpandingRing(Color ringColor, Animation<double> anim, double maxRadius, double peakOpacity) {
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) {
        final t = anim.value;
        final radius = maxRadius * t;
        final opacity = (1.0 - t) * peakOpacity;
        return Container(
          width: radius * 2,
          height: radius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: ringColor.withValues(alpha: opacity),
              width: 1.5,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = MOColors.of(context);
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: c.surface,
      body: Stack(
        children: [
          // ── Floating pollen particles ───────────────────────────────────────
          const MOFloatingParticles(count: 18, seedOffset: 0),

          // ── Ambient deep glow — bottom ──────────────────────────────────────
          Positioned(
            bottom: -80,
            left: screenSize.width * 0.1,
            right: screenSize.width * 0.1,
            child: AnimatedBuilder(
              animation: _bloomCtrl,
              builder: (_, __) => Container(
                height: 200,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      c.orchidPurple.withValues(alpha: _bloomOpacity.value * 0.5),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Center: rings + bloom + wordmark ───────────────────────────────
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // All rings + bloom + wordmark stacked in a fixed-size box
                SizedBox(
                  width: 320,
                  height: 320,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Ring 3 — slowest, largest
                      _buildExpandingRing(c.orchidPurple, _ring3Anim, 150, 0.10),
                      // Ring 2 — medium
                      _buildExpandingRing(c.orchidPurple, _ring2Anim, 118, 0.14),
                      // Ring 1 — fastest, smallest
                      _buildExpandingRing(c.orchidPurple, _ring1Anim, 88, 0.20),

                      // Central bioluminescent bloom glow
                      AnimatedBuilder(
                        animation: _bloomCtrl,
                        builder: (_, __) => Container(
                          width: _bloomRadius.value * 2,
                          height: _bloomRadius.value * 2,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                c.orchidPink.withValues(alpha: _bloomOpacity.value),
                                c.orchidPurple.withValues(alpha: _bloomOpacity.value * 0.4),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.5, 1.0],
                            ),
                          ),
                        ),
                      ),

                      // Wordmark — fades in with scale
                      FadeTransition(
                        opacity: _wordmarkFade,
                        child: ScaleTransition(
                          scale: _wordmarkScale,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Orchid glow behind the wordmark
                              Container(
                                decoration: BoxDecoration(
                                  boxShadow: [
                                    BoxShadow(
                                      color: c.orchidPurple.withValues(alpha: 0.45),
                                      blurRadius: 32,
                                      spreadRadius: 6,
                                    ),
                                    BoxShadow(
                                      color: c.orchidPink.withValues(alpha: 0.20),
                                      blurRadius: 56,
                                      spreadRadius: 10,
                                    ),
                                  ],
                                ),
                                child: ShaderMask(
                                  shaderCallback: (bounds) =>
                                      c.orchidGradient.createShader(bounds),
                                  child: Text(
                                    AppConstants.appName,
                                    style: GoogleFonts.quicksand(
                                      fontSize: 44,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Orchid accent line
                FadeTransition(
                  opacity: _wordmarkFade,
                  child: Container(
                    height: 2,
                    width: 110,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          c.orchidPurple.withValues(alpha: 0.0),
                          c.orchidPink,
                          c.orchidPurple.withValues(alpha: 0.0),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // Tagline
                FadeTransition(
                  opacity: _taglineFade,
                  child: Text(
                    AppConstants.tagline,
                    style: GoogleFonts.quicksand(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: c.orchidPurple.withValues(alpha: 0.65),
                      letterSpacing: 0.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),

          // ── Ambient glow — top right ──────────────────────────────────────
          Positioned(
            top: -60,
            right: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    c.orchidPink.withValues(alpha: 0.10),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
