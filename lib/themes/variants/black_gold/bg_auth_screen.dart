import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../config/constants.dart';
import '../../../providers/auth_provider.dart';
import 'bg_widgets.dart';

class BGAuthScreen extends ConsumerStatefulWidget {
  const BGAuthScreen({super.key});

  @override
  ConsumerState<BGAuthScreen> createState() => _BGAuthScreenState();
}

class _BGAuthScreenState extends ConsumerState<BGAuthScreen>
    with TickerProviderStateMixin {
  late AnimationController _entryController;
  late AnimationController _pulseController;
  late AnimationController _celebrationController;

  late Animation<double> _contentFade;
  late Animation<double> _contentSlide;
  late Animation<double> _pulse;
  late Animation<double> _celebrationScale;
  late Animation<double> _celebrationFade;

  bool _showCelebration = false;
  String? _generatedUsername;

  @override
  void initState() {
    super.initState();

    // Entry animation: content fades + slides up from bottom
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _contentFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    _contentSlide = Tween(begin: 40.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    // Breathing glow on fingerprint
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulse = Tween(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Celebration burst
    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _celebrationScale = Tween(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
          parent: _celebrationController, curve: Curves.easeOutBack),
    );
    _celebrationFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _celebrationController,
          curve: const Interval(0.0, 0.5, curve: Curves.easeOut)),
    );

    _entryController.forward();

    Future.microtask(
        () => ref.read(authStateProvider.notifier).checkRegistration());
  }

  @override
  void dispose() {
    _entryController.dispose();
    _pulseController.dispose();
    _celebrationController.dispose();
    super.dispose();
  }

  // ── Auth logic ─────────────────────────────────────────────────────────────

  void _showEmailLogin() {
    final c = BGColors.of(context);
    final emailCtl = TextEditingController();
    final passCtl = TextEditingController();
    String? errorText;
    bool loading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                decoration: BoxDecoration(
                  color: c.surface1,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: c.goldMid.withValues(alpha: 0.25),
                    width: 0.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: c.goldMid.withValues(alpha: 0.08),
                      blurRadius: 32,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Drag handle
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: c.goldMid.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    BGGoldShimmer(
                      child: Text(
                        'Inicio con Email',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Acceso de administrador y profesionales',
                      style: GoogleFonts.lato(
                        fontSize: 13,
                        color: c.goldMid.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Email field
                    _BGEmailField(
                      controller: emailCtl,
                      label: 'Email',
                      icon: Icons.email_outlined,
                    ),
                    const SizedBox(height: 12),
                    // Password field
                    _BGEmailField(
                      controller: passCtl,
                      label: 'Password',
                      icon: Icons.lock_outline,
                      obscureText: true,
                      onSubmitted: (_) => _submitEmail(
                        emailCtl, passCtl, ctx, setSheetState,
                        () => errorText, (v) => errorText = v,
                        () => loading, (v) => loading = v,
                      ),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        errorText!,
                        style: GoogleFonts.lato(
                          fontSize: 13,
                          color: Colors.red[400],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.of(ctx).pop(),
                            child: Container(
                              height: 50,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(25),
                                border: Border.all(
                                  color: c.goldMid.withValues(alpha: 0.25),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Cancelar',
                                style: GoogleFonts.lato(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.5),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: BGGoldButton(
                            label: loading ? '...' : 'ENTRAR',
                            height: 50,
                            onTap: loading
                                ? null
                                : () => _submitEmail(
                                      emailCtl, passCtl, ctx, setSheetState,
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

  void _submitEmail(
    TextEditingController emailCtl,
    TextEditingController passCtl,
    BuildContext ctx,
    StateSetter setSheetState,
    String? Function() getError,
    void Function(String?) setError,
    bool Function() getLoading,
    void Function(bool) setLoading,
  ) async {
    if (emailCtl.text.trim().isEmpty || passCtl.text.trim().isEmpty) return;
    setSheetState(() {
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
      setSheetState(() {
        setLoading(false);
        setError(
            ref.read(authStateProvider).error ?? 'Error al iniciar sesion');
      });
    }
  }

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
        _celebrationController.forward();
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) context.go('/home');
        });
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
            style: GoogleFonts.lato(fontWeight: FontWeight.w600),
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = BGColors.of(context);
    final authState = ref.watch(authStateProvider);
    final isFirstTime = authState.username == null;

    ref.listen<AuthState>(authStateProvider, (previous, next) {
      if (next.isAuthenticated && !_showCelebration && mounted) {
        context.go('/home');
      }
    });

    return Scaffold(
      backgroundColor: c.surface0,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // ── Full-screen particle field ──────────────────────────────────
          ...List.generate(30, (i) => _GoldParticle(index: i)),

          // ── Main content ────────────────────────────────────────────────
          _showCelebration
              ? _buildCelebrationOverlay()
              : _buildMainContent(isFirstTime, authState.isLoading),
        ],
      ),
    );
  }

  Widget _buildMainContent(bool isFirstTime, bool isLoading) {
    final c = BGColors.of(context);
    return SafeArea(
      child: AnimatedBuilder(
        animation: _entryController,
        builder: (context, child) {
          return Opacity(
            opacity: _contentFade.value,
            child: Transform.translate(
              offset: Offset(0, _contentSlide.value),
              child: child,
            ),
          );
        },
        child: Column(
          children: [
            const Spacer(flex: 2),

            // ── Monogram ─────────────────────────────────────────────────
            BGGoldShimmer(
              child: Text(
                'BC',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 52,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -1,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Welcome text (long-press to open email login) ─────────────
            GestureDetector(
              onLongPress: _showEmailLogin,
              child: Text(
                isFirstTime ? 'Bienvenida' : 'Hola de nuevo',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Gold divider line ─────────────────────────────────────────
            SizedBox(
              width: 120,
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      c.goldMid.withValues(alpha: 0.0),
                      c.goldMid,
                      c.goldMid.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),

            const Spacer(flex: 1),

            // ── Fingerprint button with breathing glow ────────────────────
            GestureDetector(
              onTap: isLoading ? null : _handleBiometricTap,
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (context, child) {
                  final glowRadius = 20.0 + (_pulse.value - 1.0) * 80;
                  return Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c.surface1,
                      border: Border.all(
                        color: c.goldMid.withValues(
                            alpha: 0.4 + (_pulse.value - 1.0) * 4),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              c.goldMid.withValues(alpha: 0.15 + (_pulse.value - 1.0) * 1.5),
                          blurRadius: glowRadius,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: isLoading
                          ? const BGGoldDots()
                          : Icon(
                              Icons.fingerprint,
                              size: 54,
                              color: c.goldMid.withValues(alpha: 0.9),
                            ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            // ── Tap label ─────────────────────────────────────────────────
            Text(
              isFirstTime ? 'Toca para comenzar' : 'Toca para entrar',
              style: GoogleFonts.lato(
                fontSize: 15,
                color: Colors.white.withValues(alpha: 0.45),
                letterSpacing: 0.5,
              ),
            ),

            const Spacer(flex: 2),

            // ── Email fallback hint ───────────────────────────────────────
            GestureDetector(
              onTap: _showEmailLogin,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 36),
                child: Text(
                  'o inicia con email',
                  style: GoogleFonts.lato(
                    fontSize: 13,
                    color: c.goldMid.withValues(alpha: 0.35),
                    decoration: TextDecoration.underline,
                    decorationColor: c.goldMid.withValues(alpha: 0.25),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCelebrationOverlay() {
    final c = BGColors.of(context);
    return Center(
      child: AnimatedBuilder(
        animation: _celebrationController,
        builder: (context, child) {
          return Opacity(
            opacity: _celebrationFade.value,
            child: Transform.scale(
              scale: _celebrationScale.value,
              child: child,
            ),
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Particle burst visual cue
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    c.goldLight.withValues(alpha: 0.4),
                    c.goldMid.withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Center(
                child: BGGoldShimmer(
                  child: Text(
                    'BC',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 42,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Tu nombre es',
              style: GoogleFonts.lato(
                fontSize: 16,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 10),
            BGGoldShimmer(
              child: Text(
                _generatedUsername ?? '',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 38,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Bienvenida a BeautyCita',
              style: GoogleFonts.lato(
                fontSize: 14,
                color: c.goldMid.withValues(alpha: 0.6),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Email field helper ───────────────────────────────────────────────────────

class _BGEmailField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscureText;
  final ValueChanged<String>? onSubmitted;

  const _BGEmailField({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscureText = false,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final c = BGColors.of(context);
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType:
          obscureText ? TextInputType.visiblePassword : TextInputType.emailAddress,
      style: GoogleFonts.lato(color: Colors.white),
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: c.goldMid.withValues(alpha: 0.7)),
        prefixIcon:
            Icon(icon, size: 20, color: c.goldMid.withValues(alpha: 0.7)),
        filled: true,
        fillColor: c.surface4,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.goldMid, width: 1),
        ),
      ),
    );
  }
}

// ─── Gold particle (identical to splash screen implementation) ────────────────

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
    final rng = math.Random(widget.index * 37 + 11);
    _startX = rng.nextDouble();
    _startY = rng.nextDouble();
    _size = 1.0 + rng.nextDouble() * 2.5;
    _opacity = 0.08 + rng.nextDouble() * 0.22;

    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 3500 + rng.nextInt(4500)),
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
        final drift = _controller.value * 0.025;
        return Positioned(
          left: (_startX + drift) * size.width,
          top: (_startY - drift * 0.4) * size.height,
          child: Container(
            width: _size,
            height: _size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.goldLight
                  .withValues(alpha: _opacity * (0.4 + _controller.value * 0.6)),
            ),
          ),
        );
      },
    );
  }
}
