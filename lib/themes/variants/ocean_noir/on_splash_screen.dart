import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../config/constants.dart';
import '../../../main.dart' show supabaseReady;
import '../../../providers/auth_provider.dart';
import 'on_widgets.dart';

class ONSplashScreen extends ConsumerStatefulWidget {
  const ONSplashScreen({super.key});

  @override
  ConsumerState<ONSplashScreen> createState() => _ONSplashScreenState();
}

class _ONSplashScreenState extends ConsumerState<ONSplashScreen>
    with TickerProviderStateMixin {
  static const _target = 'BEAUTYCITA';
  static const _glyphSet =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%&*<>[]{}|';

  // Per-letter resolved state
  final List<String> _displayChars = List.filled(_target.length, ' ');
  final List<bool> _resolved = List.filled(_target.length, false);

  // Status text cycling
  String _statusText = 'CONECTANDO...';
  bool _statusVisible = true;
  Timer? _statusBlinkTimer;

  // Whether letters have started resolving
  bool _started = false;

  // Background scan line
  late AnimationController _bgScanCtrl;

  // Letter glitch timers
  final List<Timer?> _glitchTimers = List.filled(_target.length, null);

  @override
  void initState() {
    super.initState();

    _bgScanCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Brief pause, then start assembling letters
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) _startLetterAssembly();

      // Start navigation logic in parallel
      _checkAuthAndNavigate();
    });
  }

  void _startLetterAssembly() {
    if (!mounted) return;
    setState(() => _started = true);

    // Stagger each letter
    for (int i = 0; i < _target.length; i++) {
      final delay = Duration(milliseconds: 120 + i * 80);
      final resolveAfter = Duration(milliseconds: 280 + i * 80);

      Future.delayed(delay, () {
        if (!mounted) return;
        _startGlitching(i);
      });

      Future.delayed(resolveAfter, () {
        if (!mounted) return;
        _glitchTimers[i]?.cancel();
        setState(() {
          _displayChars[i] = _target[i];
          _resolved[i] = true;
        });
      });
    }

    // After all letters resolve, update status and start blink
    final allResolvedAt =
        Duration(milliseconds: 280 + (_target.length - 1) * 80 + 200);
    Future.delayed(allResolvedAt, () {
      if (!mounted) return;
      setState(() => _statusText = 'VERIFICANDO...');
      _startStatusBlink();
    });
  }

  void _startGlitching(int idx) {
    final rng = math.Random(idx * 31 + 7);
    _glitchTimers[idx] = Timer.periodic(
      const Duration(milliseconds: 55),
      (_) {
        if (!mounted || _resolved[idx]) return;
        setState(() {
          _displayChars[idx] = _glyphSet[rng.nextInt(_glyphSet.length)];
        });
      },
    );
  }

  void _startStatusBlink() {
    _statusBlinkTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) {
        if (!mounted) return;
        setState(() => _statusVisible = !_statusVisible);
      },
    );
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
    _bgScanCtrl.dispose();
    _statusBlinkTimer?.cancel();
    for (final t in _glitchTimers) {
      t?.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = ONColors.of(context);
    return Scaffold(
      backgroundColor: c.surface0,
      body: Stack(
        children: [
          // ── Scan line background overlay ──────────────────────────────
          Positioned.fill(
            child: CustomPaint(painter: _HorizontalScanLinePainter()),
          ),

          // ── Vertical background scan sweep ────────────────────────────
          AnimatedBuilder(
            animation: _bgScanCtrl,
            builder: (context, _) {
              final size = MediaQuery.of(context).size;
              final y = _bgScanCtrl.value * size.height;
              return Positioned(
                top: y,
                left: 0,
                right: 0,
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        c.cyan.withValues(alpha: 0.0),
                        c.cyan.withValues(alpha: 0.12),
                        c.cyan.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // ── Center content ────────────────────────────────────────────
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // HUD corner frame around wordmark
                ONHudFrame(
                  bracketSize: 28,
                  bracketThickness: 1.5,
                  color: c.cyan.withValues(alpha: 0.5),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 18),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(_target.length, (i) {
                      final char = _started
                          ? _displayChars[i]
                          : ' ';
                      final isResolved = _resolved[i];
                      return Text(
                        char,
                        style: GoogleFonts.rajdhani(
                          fontSize: 44,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.0,
                          color: isResolved
                              ? c.cyan
                              : c.cyan.withValues(alpha: 0.55),
                          shadows: isResolved
                              ? [
                                  Shadow(
                                    color:
                                        c.cyan.withValues(alpha: 0.7),
                                    blurRadius: 18,
                                  ),
                                ]
                              : null,
                        ),
                      );
                    }),
                  ),
                ),

                const SizedBox(height: 24),

                // Thin cyan line that expands
                _ExpandingLine(),

                const SizedBox(height: 20),

                // Status text — blinking after resolve
                AnimatedOpacity(
                  opacity: _statusVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 150),
                  child: Text(
                    '> $_statusText',
                    style: GoogleFonts.firaCode(
                      fontSize: 12,
                      color: c.cyan.withValues(alpha: 0.55),
                      letterSpacing: 1.5,
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Data dots loading indicator
                const ONDataDots(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Horizontal scan line background painter ──────────────────────────────────

class _HorizontalScanLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.018)
      ..strokeWidth = 1.0;
    for (double y = 0; y < size.height; y += 2) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_HorizontalScanLinePainter old) => false;
}

// ─── Expanding cyan line ──────────────────────────────────────────────────────

class _ExpandingLine extends StatefulWidget {
  @override
  State<_ExpandingLine> createState() => _ExpandingLineState();
}

class _ExpandingLineState extends State<_ExpandingLine>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
    _anim = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = ONColors.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        return Container(
          height: 1,
          width: screenWidth * 0.55 * _anim.value,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                c.cyan.withValues(alpha: 0.0),
                c.cyan,
                c.cyan.withValues(alpha: 0.0),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: c.cyan.withValues(alpha: 0.5),
                blurRadius: 6,
              ),
            ],
          ),
        );
      },
    );
  }
}
