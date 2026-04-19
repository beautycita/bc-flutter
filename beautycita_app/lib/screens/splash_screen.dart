import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:beautycita/config/fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../config/constants.dart';
import '../main.dart' show supabaseReady;
import '../providers/auth_provider.dart';
import '../services/updater_service.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  bool _authCheckDone = false;
  bool _splashDone = false;
  bool _navigated = false;

  late AnimationController _fadeController;
  late AnimationController _shimmerController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOutBack),
    );
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _fadeController.forward();

    _startFallbackTimer();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthAndNavigate();
    });
  }

  void _startFallbackTimer() {
    Future.delayed(const Duration(milliseconds: 3000), () {
      _splashDone = true;
      _tryNavigate();
    });
  }

  Future<void> _checkAuthAndNavigate() async {
    await supabaseReady.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () => debugPrint('[SPLASH] Supabase init timed out after 15s'),
    );

    final info = await PackageInfo.fromPlatform();
    AppConstants.version = info.version;
    AppConstants.buildNumber = int.tryParse(info.buildNumber) ?? 0;

    UpdaterService.instance.checkForApkUpdate();

    try {
      await ref.read(authStateProvider.notifier).checkRegistration();
    } catch (e) {
      if (kDebugMode) debugPrint('[SplashScreen] checkRegistration failed: $e');
    }

    _authCheckDone = true;
    _tryNavigate();
  }

  void _tryNavigate() {
    if (_navigated || !_authCheckDone || !_splashDone) return;
    _navigated = true;
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
    _fadeController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: const Color(0xFFDADADA),
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildFallbackSplash(isDark),
        ],
      ),
    );
  }

  Widget _buildFallbackSplash(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF121218), const Color(0xFF1A1020), const Color(0xFF121218)]
              : [const Color(0xFFFFF8F0), const Color(0xFFFFF0F5), const Color(0xFFFFF8F0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF9333ea).withValues(alpha: 0.35),
                        blurRadius: 32,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset(
                      'assets/images/app_icon.png',
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                AnimatedBuilder(
                  animation: _shimmerController,
                  builder: (context, child) {
                    final offset = -2.0 * _shimmerController.value;
                    return ShaderMask(
                      blendMode: BlendMode.srcIn,
                      shaderCallback: (bounds) {
                        return LinearGradient(
                          begin: Alignment(offset, 0),
                          end: Alignment(offset + 2.0, 0),
                          colors: const [
                            Color(0xFFec4899),
                            Color(0xFF9333ea),
                            Color(0xFF3b82f6),
                            Color(0xFFec4899),
                          ],
                          stops: const [0.0, 0.33, 0.66, 1.0],
                          tileMode: TileMode.repeated,
                        ).createShader(bounds);
                      },
                      child: child!,
                    );
                  },
                  child: Text(
                    AppConstants.appName,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 44,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1.0,
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                Text(
                  AppConstants.tagline,
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 17,
                    fontWeight: FontWeight.w300,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.25),
                    letterSpacing: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
