import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import '../config/constants.dart';
import '../main.dart' show supabaseReady;
import '../providers/auth_provider.dart';
import '../services/updater_service.dart';

/// Splash video hosted on Cloudflare R2 CDN.
const _splashVideoUrl = 'https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/video/splash_reveal.mp4';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  VideoPlayerController? _videoController;
  bool _videoReady = false;
  bool _authCheckDone = false;
  bool _splashDone = false;
  bool _navigated = false;

  // Fallback animation — always runs, hidden behind video if video loads
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

    // Try loading video in parallel
    _initVideo();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthAndNavigate();
    });
  }

  Future<void> _initVideo() async {
    try {
      // Check for cached video first
      final cacheDir = await getApplicationCacheDirectory();
      final cachedFile = File('${cacheDir.path}/splash_reveal.mp4');

      VideoPlayerController controller;

      if (cachedFile.existsSync() && cachedFile.lengthSync() > 100000) {
        controller = VideoPlayerController.file(cachedFile);
      } else {
        controller = VideoPlayerController.networkUrl(
          Uri.parse(_splashVideoUrl),
        );
        // Cache for next time (non-blocking)
        _cacheVideo(cachedFile);
      }

      _videoController = controller;

      await controller.initialize().timeout(
        const Duration(seconds: 4),
        onTimeout: () => throw Exception('timeout'),
      );

      if (!mounted) return;

      controller.addListener(_onVideoProgress);
      controller.play();
      setState(() => _videoReady = true);
    } catch (e) {
      if (kDebugMode) debugPrint('[Splash] Video failed: $e — using fallback');
      _startFallbackTimer();
    }
  }

  Future<void> _cacheVideo(File target) async {
    try {
      final response = await http.get(Uri.parse(_splashVideoUrl))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        await target.writeAsBytes(response.bodyBytes);
        if (kDebugMode) debugPrint('[Splash] Video cached for next launch');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Splash] Cache failed: $e');
    }
  }

  void _startFallbackTimer() {
    Future.delayed(const Duration(milliseconds: 3000), () {
      _splashDone = true;
      _tryNavigate();
    });
  }

  void _onVideoProgress() {
    final controller = _videoController;
    if (controller == null) return;
    if (controller.value.isCompleted) {
      _splashDone = true;
      _tryNavigate();
    }
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
    _videoController?.removeListener(_onVideoProgress);
    _videoController?.dispose();
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
          // Layer 1: Fallback animated splash (always present)
          _buildFallbackSplash(isDark),

          // Layer 2: Video on top (covers fallback when ready)
          if (_videoReady && _videoController != null)
            _buildVideoSplash(_videoController!),
        ],
      ),
    );
  }

  Widget _buildVideoSplash(VideoPlayerController controller) {
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: controller.value.size.width,
        height: controller.value.size.height,
        child: VideoPlayer(controller),
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
                // Brand icon
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

                // Brand name with shimmer
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

                // Tagline
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
