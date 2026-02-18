import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../config/constants.dart';
import '../../../main.dart' show supabaseReady;
import '../../../providers/auth_provider.dart';
import 'cb_widgets.dart';

// ─── CBSplashScreen ────────────────────────────────────────────────────────────
class CBSplashScreen extends ConsumerStatefulWidget {
  const CBSplashScreen({super.key});

  @override
  ConsumerState<CBSplashScreen> createState() => _CBSplashScreenState();
}

class _CBSplashScreenState extends ConsumerState<CBSplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainCtrl;

  // Staggered reveal animations
  late Animation<double> _blobFade;
  late Animation<double> _wordmarkFade;
  late Animation<double> _wordmarkScale;
  late Animation<double> _lineFade;
  late Animation<double> _lineWidth; // 0→1 fraction of target width
  late Animation<double> _petalsFade;

  @override
  void initState() {
    super.initState();

    _mainCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );

    // Watercolor blobs appear first
    _blobFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainCtrl,
        curve: const Interval(0.0, 0.30, curve: Curves.easeOut),
      ),
    );

    // Wordmark fades + scales in gently
    _wordmarkFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainCtrl,
        curve: const Interval(0.22, 0.55, curve: Curves.easeOut),
      ),
    );
    _wordmarkScale = Tween(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainCtrl,
        curve: const Interval(0.22, 0.55, curve: Curves.easeOutCubic),
      ),
    );

    // Pink line expands below wordmark
    _lineFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainCtrl,
        curve: const Interval(0.52, 0.68, curve: Curves.easeOut),
      ),
    );
    _lineWidth = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainCtrl,
        curve: const Interval(0.52, 0.72, curve: Curves.easeOut),
      ),
    );

    // Petals fade in last
    _petalsFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainCtrl,
        curve: const Interval(0.65, 0.90, curve: Curves.easeOut),
      ),
    );

    _mainCtrl.forward();

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
    _mainCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = CBColors.of(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        children: [
          // ── Animated watercolor blobs ─────────────────────────────────
          AnimatedBuilder(
            animation: _blobFade,
            builder: (context, _) {
              return Opacity(
                opacity: _blobFade.value,
                child: Stack(
                  children: [
                    Positioned(
                      top: -size.height * 0.10,
                      left: -size.width * 0.22,
                      child: CBWatercolorBlob(
                        color: c.pink.withValues(alpha: 0.09),
                        size: size.width * 0.75,
                        driftAmplitude: 12,
                        durationSeconds: 11,
                        seed: 10,
                      ),
                    ),
                    Positioned(
                      top: size.height * 0.30,
                      right: -size.width * 0.28,
                      child: CBWatercolorBlob(
                        color: c.lavender.withValues(alpha: 0.11),
                        size: size.width * 0.68,
                        driftAmplitude: 10,
                        durationSeconds: 13,
                        seed: 11,
                      ),
                    ),
                    Positioned(
                      bottom: -size.height * 0.08,
                      left: size.width * 0.10,
                      child: CBWatercolorBlob(
                        color: c.peach.withValues(alpha: 0.10),
                        size: size.width * 0.60,
                        driftAmplitude: 8,
                        durationSeconds: 9,
                        seed: 12,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // ── Floating petals ───────────────────────────────────────────
          AnimatedBuilder(
            animation: _petalsFade,
            builder: (context, child) {
              return Opacity(opacity: _petalsFade.value, child: child);
            },
            child: Stack(
              children: List.generate(
                14,
                (i) => CBFloatingPetal(
                  index: i + 50,
                  screenWidth: size.width,
                  screenHeight: size.height,
                ),
              ),
            ),
          ),

          // ── Center content ─────────────────────────────────────────────
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Wordmark
                FadeTransition(
                  opacity: _wordmarkFade,
                  child: ScaleTransition(
                    scale: _wordmarkScale,
                    child: Text(
                      AppConstants.appName,
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 42,
                        fontWeight: FontWeight.w700,
                        color: c.text,
                        letterSpacing: 1.0,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Expanding pink accent line
                FadeTransition(
                  opacity: _lineFade,
                  child: AnimatedBuilder(
                    animation: _lineWidth,
                    builder: (context, _) {
                      return Container(
                        height: 1.5,
                        width: 80 * _lineWidth.value,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              c.pink.withValues(alpha: 0.0),
                              c.pink,
                              c.pink.withValues(alpha: 0.0),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      );
                    },
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
