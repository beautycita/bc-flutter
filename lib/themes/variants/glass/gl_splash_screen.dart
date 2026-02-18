import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../config/constants.dart';
import '../../../main.dart' show supabaseReady;
import '../../../providers/auth_provider.dart';
import 'gl_widgets.dart';

class GLSplashScreen extends ConsumerStatefulWidget {
  const GLSplashScreen({super.key});

  @override
  ConsumerState<GLSplashScreen> createState() => _GLSplashScreenState();
}

class _GLSplashScreenState extends ConsumerState<GLSplashScreen>
    with TickerProviderStateMixin {
  // Panel materializes from blur sigma=30 → 0 (the glass un-frosted reveal)
  late AnimationController _blurRevealController;
  late Animation<double> _blurReveal;

  // Scale + fade for the panel itself
  late AnimationController _entryController;
  late Animation<double> _panelScale;
  late Animation<double> _panelFade;

  // Content inside the panel fades in after reveal
  late Animation<double> _wordmarkFade;
  late Animation<Offset> _wordmarkSlide;
  late Animation<double> _taglineFade;

  // Neon accent line width
  late Animation<double> _lineWidth;

  @override
  void initState() {
    super.initState();

    _blurRevealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _blurReveal = Tween(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(parent: _blurRevealController, curve: Curves.easeOut),
    );

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );

    _panelScale = Tween(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOutBack),
      ),
    );

    _panelFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );

    _wordmarkFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.35, 0.65, curve: Curves.easeOut),
      ),
    );

    _wordmarkSlide = Tween(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.35, 0.65, curve: Curves.easeOutCubic),
      ),
    );

    _taglineFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.60, 0.85, curve: Curves.easeOut),
      ),
    );

    _lineWidth = Tween(begin: 0.0, end: 60.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.55, 0.80, curve: Curves.easeOut),
      ),
    );

    // Start blur reveal immediately, entry follows
    _blurRevealController.forward();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _entryController.forward();
    });

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
    _blurRevealController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = GlColors.of(context);
    return Scaffold(
      backgroundColor: c.bgDeep,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Aurora animated background
          const GlAuroraBackground(child: SizedBox.expand()),

          // Floating neon particles
          ...List.generate(
            20,
            (i) => GlFloatingParticle(key: ValueKey('sp$i'), index: i),
          ),

          // Centered panel
          Center(
            child: FadeTransition(
              opacity: _panelFade,
              child: ScaleTransition(
                scale: _panelScale,
                child: AnimatedBuilder(
                  animation: _blurReveal,
                  builder: (context, child) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        // Frosted glass panel base (constant backdrop blur)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                            child: Container(
                              width: 280,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 36,
                                vertical: 52,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  width: 1,
                                ),
                              ),
                              child: child,
                            ),
                          ),
                        ),

                        // Blur dissolve overlay: starts fully blurred, reveals to clear
                        if (_blurReveal.value > 0.5)
                          Positioned(
                            child: SizedBox(
                              width: 280,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(28),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(
                                    sigmaX: _blurReveal.value,
                                    sigmaY: _blurReveal.value,
                                  ),
                                  child: Container(
                                    height: 380,
                                    color: Colors.white.withValues(
                                      alpha: (_blurReveal.value / 30.0) * 0.1,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // "BC" neon gradient monogram
                      SlideTransition(
                        position: _wordmarkSlide,
                        child: FadeTransition(
                          opacity: _wordmarkFade,
                          child: ShaderMask(
                            shaderCallback: (bounds) =>
                                c.neonGradient.createShader(bounds),
                            child: Text(
                              'BC',
                              style: GoogleFonts.inter(
                                fontSize: 56,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                height: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // App name
                      FadeTransition(
                        opacity: _wordmarkFade,
                        child: Text(
                          AppConstants.appName,
                          style: GoogleFonts.inter(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: c.text,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Neon accent line — animates width from 0 → 60
                      AnimatedBuilder(
                        animation: _lineWidth,
                        builder: (context, _) {
                          return Container(
                            height: 2.5,
                            width: _lineWidth.value,
                            decoration: BoxDecoration(
                              gradient: c.neonGradient,
                              borderRadius: BorderRadius.circular(2),
                              boxShadow: [
                                BoxShadow(
                                  color: c.neonPink.withValues(alpha: 0.5),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 20),

                      // Tagline
                      FadeTransition(
                        opacity: _taglineFade,
                        child: Text(
                          AppConstants.tagline,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: c.text.withValues(alpha: 0.50),
                            letterSpacing: 0.3,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Neon dots loading indicator
                      FadeTransition(
                        opacity: _taglineFade,
                        child: const GlNeonDots(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
