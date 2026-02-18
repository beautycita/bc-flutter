import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../config/constants.dart';
import '../../../providers/auth_provider.dart';
import 'cb_widgets.dart';

// ─── CBAuthScreen ──────────────────────────────────────────────────────────────
class CBAuthScreen extends ConsumerStatefulWidget {
  const CBAuthScreen({super.key});

  @override
  ConsumerState<CBAuthScreen> createState() => _CBAuthScreenState();
}

class _CBAuthScreenState extends ConsumerState<CBAuthScreen>
    with TickerProviderStateMixin {
  // Entry animation
  late AnimationController _entryCtrl;
  late Animation<double> _contentFade;
  late Animation<double> _contentSlide;

  // Fingerprint breathing animation
  late AnimationController _breathCtrl;
  late Animation<double> _breathScale;

  // Celebration animation
  late AnimationController _celebrationCtrl;
  late Animation<double> _celebrationScale;
  late Animation<double> _celebrationFade;

  bool _showCelebration = false;
  String? _generatedUsername;

  @override
  void initState() {
    super.initState();

    // Entry: content fades + rises gently
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _contentFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryCtrl,
        curve: const Interval(0.20, 0.70, curve: Curves.easeOut),
      ),
    );
    _contentSlide = Tween(begin: 18.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _entryCtrl,
        curve: const Interval(0.20, 0.75, curve: Curves.easeOutCubic),
      ),
    );

    // Breathing pulse on fingerprint
    _breathCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);
    _breathScale = Tween(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _breathCtrl, curve: Curves.easeInOut),
    );

    // Celebration scale-in
    _celebrationCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _celebrationScale = Tween(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _celebrationCtrl, curve: Curves.easeOutBack),
    );
    _celebrationFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _celebrationCtrl, curve: Curves.easeOut),
    );

    _entryCtrl.forward();

    Future.microtask(
      () => ref.read(authStateProvider.notifier).checkRegistration(),
    );
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _breathCtrl.dispose();
    _celebrationCtrl.dispose();
    super.dispose();
  }

  // ─── Email login sheet ────────────────────────────────────────────────────

  void _showEmailLogin() {
    final emailCtl = TextEditingController();
    final passCtl = TextEditingController();
    String? errorText;
    bool loading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final c = CBColors.of(ctx);
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            return Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                decoration: BoxDecoration(
                  color: c.card,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: c.pink.withValues(alpha: 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Drag handle
                    Container(
                      width: 32,
                      height: 3,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: c.pink.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    Text(
                      'Inicio con Email',
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: c.text,
                      ),
                    ),

                    const SizedBox(height: 24),

                    TextField(
                      controller: emailCtl,
                      keyboardType: TextInputType.emailAddress,
                      style: GoogleFonts.nunitoSans(color: c.text),
                      decoration: _inputDecoration('Email', Icons.email_outlined, c),
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: passCtl,
                      obscureText: true,
                      style: GoogleFonts.nunitoSans(color: c.text),
                      decoration:
                          _inputDecoration('Contrasena', Icons.lock_outline, c),
                      onSubmitted: (_) => _submitEmail(
                          emailCtl, passCtl, ctx, setSheet,
                          () => errorText, (v) => errorText = v,
                          () => loading, (v) => loading = v),
                    ),

                    if (errorText != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        errorText!,
                        style: GoogleFonts.nunitoSans(
                          fontSize: 13,
                          color: Colors.red.shade400,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],

                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: Text(
                              'Cancelar',
                              style: GoogleFonts.nunitoSans(
                                fontWeight: FontWeight.w600,
                                color: c.text.withValues(alpha: 0.35),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: CBSoftButton(
                            label: loading ? '...' : 'ENTRAR',
                            height: 46,
                            onTap: loading
                                ? null
                                : () => _submitEmail(
                                      emailCtl, passCtl, ctx, setSheet,
                                      () => errorText, (v) => errorText = v,
                                      () => loading, (v) => loading = v,
                                    ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon, CBColors c) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.nunitoSans(
        color: c.pink.withValues(alpha: 0.65),
        fontSize: 14,
      ),
      prefixIcon: Icon(icon, size: 20, color: c.pink.withValues(alpha: 0.50)),
      filled: true,
      fillColor: c.bg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.pink.withValues(alpha: 0.15)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.pink.withValues(alpha: 0.15)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.pink, width: 1.5),
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
        setError(
            ref.read(authStateProvider).error ?? 'Error al iniciar sesion');
      });
    }
  }

  void _handleBiometricTap() async {
    final notifier = ref.read(authStateProvider.notifier);
    final authState = ref.read(authStateProvider);
    bool success = false;

    if (authState.username == null) {
      success = await notifier.register();
      if (success && mounted) {
        final newUsername = ref.read(authStateProvider).username;
        setState(() {
          _generatedUsername = newUsername;
          _showCelebration = true;
        });
        _celebrationCtrl.forward();
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) context.go('/home');
        });
      }
    } else {
      success = await notifier.login();
      if (success && mounted) context.go('/home');
    }

    if (!success && mounted) {
      final error = ref.read(authStateProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error ?? AppConstants.errorAuth,
            style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w600),
          ),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = CBColors.of(context);
    final size = MediaQuery.of(context).size;
    final authState = ref.watch(authStateProvider);
    final isFirstTime = authState.username == null;

    ref.listen<AuthState>(authStateProvider, (previous, next) {
      if (next.isAuthenticated && !_showCelebration && mounted) {
        context.go('/home');
      }
    });

    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        children: [
          // ── Animated watercolor wash blobs ─────────────────────────────
          Positioned(
            top: -size.height * 0.12,
            left: -size.width * 0.25,
            child: CBWatercolorBlob(
              color: c.pink.withValues(alpha: 0.10),
              size: size.width * 0.80,
              driftAmplitude: 14,
              durationSeconds: 12,
              seed: 1,
            ),
          ),
          Positioned(
            top: size.height * 0.25,
            right: -size.width * 0.30,
            child: CBWatercolorBlob(
              color: c.lavender.withValues(alpha: 0.13),
              size: size.width * 0.70,
              driftAmplitude: 10,
              durationSeconds: 10,
              seed: 2,
            ),
          ),
          Positioned(
            bottom: -size.height * 0.10,
            left: -size.width * 0.20,
            child: CBWatercolorBlob(
              color: c.peach.withValues(alpha: 0.12),
              size: size.width * 0.65,
              driftAmplitude: 8,
              durationSeconds: 14,
              seed: 3,
            ),
          ),
          Positioned(
            top: size.height * 0.50,
            left: size.width * 0.30,
            child: CBWatercolorBlob(
              color: c.pink.withValues(alpha: 0.07),
              size: size.width * 0.55,
              driftAmplitude: 16,
              durationSeconds: 9,
              seed: 4,
            ),
          ),

          // ── Falling petals ─────────────────────────────────────────────
          ...List.generate(18, (i) => CBFloatingPetal(
            index: i,
            screenWidth: size.width,
            screenHeight: size.height,
          )),

          // ── Content — no container, elements float freely ──────────────
          SafeArea(
            child: AnimatedBuilder(
              animation: _entryCtrl,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _contentSlide.value),
                  child: Opacity(
                    opacity: _contentFade.value,
                    child: child,
                  ),
                );
              },
              child: _showCelebration
                  ? _buildCelebration(c)
                  : _buildMainContent(c, isFirstTime, authState.isLoading),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(CBColors c, bool isFirstTime, bool isLoading) {
    return Column(
      children: [
        const Spacer(flex: 2),

        // Brand name — clean typography, no logo
        Text(
          'BeautyCita',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: c.text,
            letterSpacing: 0.5,
          ),
        ),

        const SizedBox(height: 8),

        // Thin pink gradient line
        const CBAccentLine(width: 40, height: 1),

        const SizedBox(height: 32),

        // Welcome text
        GestureDetector(
          onLongPress: _showEmailLogin,
          child: Text(
            isFirstTime ? 'Bienvenida' : 'Hola de nuevo',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 22,
              color: c.text.withValues(alpha: 0.70),
            ),
          ),
        ),

        const SizedBox(height: 8),

        Text(
          isFirstTime
              ? 'Tu agente de belleza personal'
              : 'Autenticate para continuar',
          style: GoogleFonts.nunitoSans(
            fontSize: 14,
            color: c.pink.withValues(alpha: 0.50),
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 48),

        // Fingerprint button — minimal circle, breathing animation
        GestureDetector(
          onTap: isLoading ? null : _handleBiometricTap,
          child: AnimatedBuilder(
            animation: _breathCtrl,
            builder: (context, child) {
              return Transform.scale(
                scale: isLoading ? 1.0 : _breathScale.value,
                child: child,
              );
            },
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.bg,
                border: Border.all(
                  color: c.pink.withValues(alpha: 0.20),
                  width: 1.0,
                ),
              ),
              child: Center(
                child: isLoading
                    ? const CBLoadingDots()
                    : Icon(
                        Icons.fingerprint,
                        size: 56,
                        color: c.pink.withValues(alpha: 0.40),
                      ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        Text(
          'Toca para comenzar',
          style: GoogleFonts.nunitoSans(
            fontSize: 13,
            color: c.pink.withValues(alpha: 0.35),
          ),
        ),

        const Spacer(flex: 3),

        // Bottom: minimal email link
        GestureDetector(
          onLongPress: _showEmailLogin,
          onTap: _showEmailLogin,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 32),
            child: Text(
              'o inicia con email',
              style: GoogleFonts.nunitoSans(
                fontSize: 12,
                color: c.pink.withValues(alpha: 0.25),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCelebration(CBColors c) {
    return FadeTransition(
      opacity: _celebrationFade,
      child: ScaleTransition(
        scale: _celebrationScale,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Scatter petals visual (static decorative dots)
            SizedBox(
              height: 80,
              child: Stack(
                alignment: Alignment.center,
                children: List.generate(8, (i) {
                  final angle = (i / 8) * math.pi * 2;
                  final r = 36.0;
                  return Positioned(
                    left: 40 + math.cos(angle) * r,
                    top: 40 + math.sin(angle) * r - 12,
                    child: Container(
                      width: 5,
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: (i % 2 == 0 ? c.pink : c.lavender)
                            .withValues(alpha: 0.55),
                      ),
                    ),
                  );
                }),
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Tu nombre es',
              style: GoogleFonts.nunitoSans(
                fontSize: 15,
                color: c.text.withValues(alpha: 0.50),
              ),
            ),

            const SizedBox(height: 12),

            Text(
              _generatedUsername ?? '',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: c.pink,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
