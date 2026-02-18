import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../config/constants.dart';
import '../../../providers/auth_provider.dart';
import 'el_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ELAuthScreen — Art Deco Structured Elegance
//
// Full-screen dark green bg (#0A1A0A)
// Art deco frame drawn with CustomPaint around content (16px from edges)
// Diamond-shaped fingerprint container (100px, rotated 45°, gold border)
// Breathing animation + emerald glow
// Celebration: concentric diamond pattern expands outward
// ─────────────────────────────────────────────────────────────────────────────

class ELAuthScreen extends ConsumerStatefulWidget {
  const ELAuthScreen({super.key});

  @override
  ConsumerState<ELAuthScreen> createState() => _ELAuthScreenState();
}

class _ELAuthScreenState extends ConsumerState<ELAuthScreen>
    with TickerProviderStateMixin {
  // Entry animation
  late AnimationController _entryCtrl;
  late Animation<double> _contentFade;
  late Animation<double> _contentSlideY;
  late Animation<double> _frameDraw;

  // Pulse on fingerprint container
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  // Background deco pattern slow rotation
  late AnimationController _bgCtrl;
  late Animation<double> _bgAngle;

  // Celebration concentric diamonds
  late AnimationController _celebCtrl;
  late Animation<double> _celebExpand;
  late Animation<double> _celebFade;
  late Animation<double> _usernameFade;

  bool _showCelebration = false;
  String? _generatedUsername;

  @override
  void initState() {
    super.initState();

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _frameDraw = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryCtrl, curve: const Interval(0.0, 0.5, curve: Curves.easeOut)),
    );
    _contentFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryCtrl, curve: const Interval(0.3, 0.8, curve: Curves.easeOut)),
    );
    _contentSlideY = Tween(begin: 0.04, end: 0.0).animate(
      CurvedAnimation(parent: _entryCtrl, curve: const Interval(0.3, 0.85, curve: Curves.easeOutCubic)),
    );

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulse = Tween(begin: 1.0, end: 1.05)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();
    _bgAngle = Tween(begin: 0.0, end: math.pi * 2)
        .animate(CurvedAnimation(parent: _bgCtrl, curve: Curves.linear));

    _celebCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _celebExpand = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _celebCtrl, curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic)),
    );
    _celebFade = Tween(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _celebCtrl, curve: const Interval(0.6, 1.0, curve: Curves.easeIn)),
    );
    _usernameFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _celebCtrl, curve: const Interval(0.3, 0.7, curve: Curves.easeOut)),
    );

    _entryCtrl.forward();

    Future.microtask(
        () => ref.read(authStateProvider.notifier).checkRegistration());
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _pulseCtrl.dispose();
    _bgCtrl.dispose();
    _celebCtrl.dispose();
    super.dispose();
  }

  // ─── Email login bottom sheet ─────────────────────────────────────────────

  void _showEmailLogin() {
    final emailCtl = TextEditingController();
    final passCtl = TextEditingController();
    String? errorText;
    bool loading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final c = ELColors.of(ctx);
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: c.surface,
                border: Border.all(color: c.gold.withValues(alpha: 0.3), width: 1),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Deco drag handle
                  Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(width: 20, height: 1, color: c.gold.withValues(alpha: 0.3)),
                        const SizedBox(width: 6),
                        Transform.rotate(
                          angle: math.pi / 4,
                          child: Container(
                            width: 5,
                            height: 5,
                            color: c.gold.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(width: 20, height: 1, color: c.gold.withValues(alpha: 0.3)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'INICIO CON EMAIL',
                          style: GoogleFonts.cinzel(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: c.gold,
                            letterSpacing: 2.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        _DecoTextField(
                          controller: emailCtl,
                          label: 'Email',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 12),
                        _DecoTextField(
                          controller: passCtl,
                          label: 'Password',
                          icon: Icons.lock_outline,
                          obscureText: true,
                          onSubmitted: (_) => _submitEmail(emailCtl, passCtl, ctx, setSheet,
                              () => errorText, (v) => errorText = v, () => loading, (v) => loading = v),
                        ),
                        if (errorText != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            errorText!,
                            style: GoogleFonts.raleway(fontSize: 13, color: Colors.red[400]),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => Navigator.of(ctx).pop(),
                                child: Container(
                                  height: 46,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: c.gold.withValues(alpha: 0.25),
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Cancelar',
                                    style: GoogleFonts.raleway(
                                      color: c.text.withValues(alpha: 0.45),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ELGeometricButton(
                                label: loading ? '...' : 'ENTRAR',
                                height: 46,
                                onTap: loading
                                    ? null
                                    : () => _submitEmail(emailCtl, passCtl, ctx, setSheet,
                                        () => errorText, (v) => errorText = v,
                                        () => loading, (v) => loading = v),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _submitEmail(
    TextEditingController emailCtl,
    TextEditingController passCtl,
    BuildContext ctx,
    StateSetter setSheet,
    String? Function() getError,
    void Function(String?) setError,
    bool Function() getLoading,
    void Function(bool) setLoading,
  ) async {
    if (emailCtl.text.trim().isEmpty || passCtl.text.trim().isEmpty) return;
    setSheet(() {
      setLoading(true);
      setError(null);
    });
    final ok = await ref
        .read(authStateProvider.notifier)
        .signInWithEmail(emailCtl.text.trim(), passCtl.text.trim());
    if (ok && mounted) {
      Navigator.of(ctx).pop();
      context.go('/home');
    } else {
      setSheet(() {
        setLoading(false);
        setError(ref.read(authStateProvider).error ?? 'Error al iniciar sesion');
      });
    }
  }

  // ─── Biometric tap ────────────────────────────────────────────────────────

  void _handleBiometricTap() async {
    final authNotifier = ref.read(authStateProvider.notifier);
    final authState = ref.read(authStateProvider);
    bool success = false;

    if (authState.username == null) {
      success = await authNotifier.register();
      if (success && mounted) {
        final newUsername = ref.read(authStateProvider).username;
        setState(() {
          _generatedUsername = newUsername;
          _showCelebration = true;
        });
        _celebCtrl.forward();
        await Future.delayed(const Duration(milliseconds: 2000));
        if (mounted) context.go('/home');
      }
    } else {
      success = await authNotifier.login();
      if (success && mounted) context.go('/home');
    }

    if (!success && mounted) {
      final error = ref.read(authStateProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error ?? AppConstants.errorAuth,
            style: GoogleFonts.raleway(fontWeight: FontWeight.w600),
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = ELColors.of(context);
    final authState = ref.watch(authStateProvider);
    final isFirstTime = authState.username == null;

    ref.listen<AuthState>(authStateProvider, (previous, next) {
      if (next.isAuthenticated && !_showCelebration && mounted) {
        context.go('/home');
      }
    });

    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: c.bg,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // ── Slow-rotating background deco pattern ──────────────────────
          AnimatedBuilder(
            animation: _bgAngle,
            builder: (context, _) => Positioned(
              top: -80,
              left: -80,
              child: Transform.rotate(
                angle: _bgAngle.value * 0.05,
                child: CustomPaint(
                  size: Size(screenSize.width * 0.7, screenSize.width * 0.7),
                  painter: _BGDecoPainter(),
                ),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _bgAngle,
            builder: (context, _) => Positioned(
              bottom: -60,
              right: -60,
              child: Transform.rotate(
                angle: -_bgAngle.value * 0.04,
                child: CustomPaint(
                  size: Size(screenSize.width * 0.5, screenSize.width * 0.5),
                  painter: _BGDecoPainter(),
                ),
              ),
            ),
          ),

          // ── Full-screen art deco frame ─────────────────────────────────
          AnimatedBuilder(
            animation: _frameDraw,
            builder: (context, _) => Positioned.fill(
              child: CustomPaint(
                painter: _FullScreenFramePainter(progress: _frameDraw.value),
              ),
            ),
          ),

          // ── Main content ───────────────────────────────────────────────
          SafeArea(
            child: _showCelebration
                ? _buildCelebration(context, screenSize)
                : FadeTransition(
                    opacity: _contentFade,
                    child: SlideTransition(
                      position: _contentSlideY.drive(
                        Tween(begin: const Offset(0, 0.04), end: Offset.zero),
                      ),
                      child: _buildContent(context, isFirstTime, authState),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool isFirstTime, AuthState authState) {
    final c = ELColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        children: [
          const Spacer(flex: 2),

          // ── Top deco ornament ──────────────────────────────────────────
          CustomPaint(
            size: const Size(40, 20),
            painter: _TopOrnamentPainter(),
          ),
          const SizedBox(height: 24),

          // ── "BC" monogram ───────────────────────────────────────────────
          GestureDetector(
            onLongPress: _showEmailLogin,
            child: Text(
              'BC',
              style: GoogleFonts.cinzel(
                fontSize: 52,
                fontWeight: FontWeight.w700,
                color: c.gold,
                letterSpacing: 8.0,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Greeting ────────────────────────────────────────────────────
          Text(
            isFirstTime ? 'BIENVENIDA' : 'HOLA DE NUEVO',
            style: GoogleFonts.cinzel(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: c.text,
              letterSpacing: 4.0,
            ),
          ),
          const SizedBox(height: 10),

          // ── Three-diamond divider ────────────────────────────────────────
          const ELGoldAccent(),
          const SizedBox(height: 8),

          // ── Subtitle ─────────────────────────────────────────────────────
          Text(
            isFirstTime
                ? 'Tu experiencia exclusiva comienza aqui'
                : authState.username ?? '',
            style: GoogleFonts.raleway(
              fontSize: 14,
              color: c.emerald.withValues(alpha: 0.7),
              letterSpacing: 0.4,
            ),
            textAlign: TextAlign.center,
          ),

          const Spacer(flex: 2),

          // ── Diamond-shaped fingerprint container ─────────────────────────
          GestureDetector(
            onTap: authState.isLoading ? null : _handleBiometricTap,
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, child) => Transform.scale(
                scale: authState.isLoading ? 1.0 : _pulse.value,
                child: child,
              ),
              child: SizedBox(
                width: 140,
                height: 140,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer glow ring
                    Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: c.emerald.withValues(alpha: 0.10),
                            blurRadius: 24,
                            spreadRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    // Diamond container (100px rotated 45°)
                    Transform.rotate(
                      angle: math.pi / 4,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: c.surface,
                          border: Border.all(color: c.gold, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: c.emerald.withValues(alpha: 0.10),
                              blurRadius: 24,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Fingerprint icon (counter-rotated to stay upright)
                    authState.isLoading
                        ? const ELGeometricDots()
                        : Icon(
                            Icons.fingerprint,
                            size: 50,
                            color: c.emerald.withValues(alpha: 0.9),
                          ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          Text(
            'TOCA PARA CONTINUAR',
            style: GoogleFonts.raleway(
              fontSize: 11,
              color: c.gold.withValues(alpha: 0.5),
              letterSpacing: 2.5,
              fontWeight: FontWeight.w500,
            ),
          ),

          const Spacer(flex: 2),

          // ── CTA button ───────────────────────────────────────────────────
          ELGeometricButton(
            label: 'CONTINUAR',
            onTap: authState.isLoading ? null : _handleBiometricTap,
          ),

          const SizedBox(height: 20),

          // ── Email login hint ─────────────────────────────────────────────
          GestureDetector(
            onTap: _showEmailLogin,
            child: Text(
              'Iniciar sesion con email',
              style: GoogleFonts.raleway(
                fontSize: 12,
                color: c.gold.withValues(alpha: 0.3),
                letterSpacing: 0.5,
                decoration: TextDecoration.underline,
                decorationColor: c.gold.withValues(alpha: 0.2),
              ),
            ),
          ),

          const Spacer(flex: 1),
        ],
      ),
    );
  }

  Widget _buildCelebration(BuildContext context, Size screenSize) {
    final c = ELColors.of(context);
    return Stack(
      alignment: Alignment.center,
      children: [
        // Concentric diamonds expanding outward
        AnimatedBuilder(
          animation: _celebCtrl,
          builder: (context, _) => CustomPaint(
            size: Size(screenSize.width, screenSize.height),
            painter: _CelebrationPainter(
              expand: _celebExpand.value,
              fade: _celebFade.value,
              screenSize: screenSize,
            ),
          ),
        ),

        // Username reveal
        FadeTransition(
          opacity: _usernameFade,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '\u2726',
                  style: TextStyle(fontSize: 40, color: c.gold.withValues(alpha: 0.9)),
                ),
                const SizedBox(height: 16),
                const ELGoldAccent(),
                const SizedBox(height: 16),
                Text(
                  'Tu nombre es',
                  style: GoogleFonts.raleway(
                    fontSize: 14,
                    color: c.text.withValues(alpha: 0.55),
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _generatedUsername ?? '',
                  style: GoogleFonts.cinzel(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: c.gold,
                    letterSpacing: 2.0,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Helper Widgets ───────────────────────────────────────────────────────────

class _DecoTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onSubmitted;

  const _DecoTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final c = ELColors.of(context);
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      onSubmitted: onSubmitted,
      style: GoogleFonts.raleway(color: c.text),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: c.gold.withValues(alpha: 0.6)),
        prefixIcon: Icon(icon, size: 20, color: c.gold.withValues(alpha: 0.6)),
        filled: true,
        fillColor: c.surface2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: c.gold.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: c.gold.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: c.gold, width: 1),
        ),
      ),
    );
  }
}

// ─── CustomPainters ───────────────────────────────────────────────────────────

/// Full-screen deco frame drawn progressively (progress 0→1).
class _FullScreenFramePainter extends CustomPainter {
  final double progress;
  const _FullScreenFramePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    const margin = 16.0;
    const c = 20.0; // corner cut size

    final outer = Paint()
      ..color = elGold.withValues(alpha: 0.4 * progress)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    final innerLine = Paint()
      ..color = elGold.withValues(alpha: 0.15 * progress)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    final r = Rect.fromLTRB(margin, margin, size.width - margin, size.height - margin);

    // Draw outer octagonal frame partially based on progress
    _drawPartialOctagon(canvas, r, c, outer, progress);

    // Inner frame (4px inset)
    const innerMargin = 20.0;
    final ri = Rect.fromLTRB(innerMargin, innerMargin, size.width - innerMargin, size.height - innerMargin);
    _drawPartialOctagon(canvas, ri, c * 0.7, innerLine, (progress - 0.2).clamp(0.0, 1.0));

    // Corner ornaments: L-shapes with small diamond
    if (progress > 0.4) {
      final ornPaint = Paint()
        ..color = elGold.withValues(alpha: 0.6 * ((progress - 0.4) / 0.6).clamp(0.0, 1.0))
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      const ornLen = 18.0;
      // TL
      canvas.drawLine(Offset(r.left, r.top + c), Offset(r.left, r.top + c + ornLen), ornPaint);
      canvas.drawLine(Offset(r.left + c, r.top), Offset(r.left + c + ornLen, r.top), ornPaint);
      // TR
      canvas.drawLine(Offset(r.right, r.top + c), Offset(r.right, r.top + c + ornLen), ornPaint);
      canvas.drawLine(Offset(r.right - c, r.top), Offset(r.right - c - ornLen, r.top), ornPaint);
      // BL
      canvas.drawLine(Offset(r.left, r.bottom - c), Offset(r.left, r.bottom - c - ornLen), ornPaint);
      canvas.drawLine(Offset(r.left + c, r.bottom), Offset(r.left + c + ornLen, r.bottom), ornPaint);
      // BR
      canvas.drawLine(Offset(r.right, r.bottom - c), Offset(r.right, r.bottom - c - ornLen), ornPaint);
      canvas.drawLine(Offset(r.right - c, r.bottom), Offset(r.right - c - ornLen, r.bottom), ornPaint);
    }
  }

  void _drawPartialOctagon(Canvas canvas, Rect r, double c, Paint paint, double t) {
    if (t <= 0) return;
    final segments = [
      [Offset(r.left + c, r.top), Offset(r.right - c, r.top)],
      [Offset(r.right - c, r.top), Offset(r.right, r.top + c)],
      [Offset(r.right, r.top + c), Offset(r.right, r.bottom - c)],
      [Offset(r.right, r.bottom - c), Offset(r.right - c, r.bottom)],
      [Offset(r.right - c, r.bottom), Offset(r.left + c, r.bottom)],
      [Offset(r.left + c, r.bottom), Offset(r.left, r.bottom - c)],
      [Offset(r.left, r.bottom - c), Offset(r.left, r.top + c)],
      [Offset(r.left, r.top + c), Offset(r.left + c, r.top)],
    ];

    double totalLen = 0;
    for (final s in segments) {
      totalLen += (s[1] - s[0]).distance;
    }
    double drawn = totalLen * t;

    for (final s in segments) {
      final segLen = (s[1] - s[0]).distance;
      if (drawn <= 0) break;
      if (drawn >= segLen) {
        canvas.drawLine(s[0], s[1], paint);
        drawn -= segLen;
      } else {
        final frac = drawn / segLen;
        canvas.drawLine(
          s[0],
          Offset(s[0].dx + (s[1].dx - s[0].dx) * frac, s[0].dy + (s[1].dy - s[0].dy) * frac),
          paint,
        );
        drawn = 0;
      }
    }
  }

  @override
  bool shouldRepaint(_FullScreenFramePainter old) => old.progress != progress;
}

/// Background subtle deco pattern (concentric rotated squares).
class _BGDecoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = elGold.withValues(alpha: 0.04)
      ..strokeWidth = 0.75
      ..style = PaintingStyle.stroke;

    final cx = size.width / 2;
    final cy = size.height / 2;

    for (int i = 1; i <= 5; i++) {
      final r = i * 40.0;
      final angle = math.pi / 4;
      final corners = List.generate(4, (j) {
        final a = angle + math.pi / 2 * j;
        return Offset(cx + r * math.cos(a), cy + r * math.sin(a));
      });
      for (int j = 0; j < 4; j++) {
        canvas.drawLine(corners[j], corners[(j + 1) % 4], paint);
      }
    }
  }

  @override
  bool shouldRepaint(_BGDecoPainter old) => false;
}

/// Top ornament — small chevron/sunburst pattern.
class _TopOrnamentPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = elGold.withValues(alpha: 0.55)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final cx = size.width / 2;
    final cy = size.height / 2;

    // Chevron pointing up
    canvas.drawLine(Offset(cx - 20, cy + 6), Offset(cx, cy - 6), paint);
    canvas.drawLine(Offset(cx, cy - 6), Offset(cx + 20, cy + 6), paint);
    // Second smaller chevron
    final paint2 = Paint()
      ..color = elGold.withValues(alpha: 0.3)
      ..strokeWidth = 0.75
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(cx - 14, cy + 10), Offset(cx, cy - 2), paint2);
    canvas.drawLine(Offset(cx, cy - 2), Offset(cx + 14, cy + 10), paint2);
    // Center diamond dot
    final dotPaint = Paint()
      ..color = elGold.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;
    canvas.save();
    canvas.translate(cx, cy - 6);
    canvas.rotate(math.pi / 4);
    canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: 4, height: 4), dotPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TopOrnamentPainter old) => false;
}

/// Concentric diamonds expanding outward for celebration.
class _CelebrationPainter extends CustomPainter {
  final double expand;
  final double fade;
  final Size screenSize;

  const _CelebrationPainter({
    required this.expand,
    required this.fade,
    required this.screenSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final maxR = math.max(size.width, size.height) * 0.8;

    for (int i = 0; i < 6; i++) {
      final delay = i * 0.12;
      final t = ((expand - delay) / (1.0 - delay)).clamp(0.0, 1.0);
      if (t <= 0) continue;

      final r = t * maxR * (0.15 + i * 0.15);
      final alpha = (1.0 - t) * fade * (i % 2 == 0 ? 0.5 : 0.3);
      if (alpha <= 0) continue;

      final paint = Paint()
        ..color = elGold.withValues(alpha: alpha)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;

      // Diamond shape (square rotated 45°)
      final corners = [
        Offset(cx, cy - r),
        Offset(cx + r, cy),
        Offset(cx, cy + r),
        Offset(cx - r, cy),
      ];
      for (int j = 0; j < 4; j++) {
        canvas.drawLine(corners[j], corners[(j + 1) % 4], paint);
      }
    }
  }

  @override
  bool shouldRepaint(_CelebrationPainter old) =>
      old.expand != expand || old.fade != fade;
}
