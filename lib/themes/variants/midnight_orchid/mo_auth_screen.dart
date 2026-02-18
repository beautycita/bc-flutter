import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../config/constants.dart';
import '../../../providers/auth_provider.dart';
import 'mo_widgets.dart';

class MOAuthScreen extends ConsumerStatefulWidget {
  const MOAuthScreen({super.key});

  @override
  ConsumerState<MOAuthScreen> createState() => _MOAuthScreenState();
}

class _MOAuthScreenState extends ConsumerState<MOAuthScreen>
    with TickerProviderStateMixin {
  // Entry animation
  late AnimationController _entryCtrl;
  late Animation<double> _contentFade;
  late Animation<Offset> _contentSlide;

  // Biometric breathing animation
  late AnimationController _bioCtrl;
  late Animation<double> _bioScale;
  late Animation<double> _bioPulse;

  // Celebration bloom
  late AnimationController _bloomCtrl;
  late Animation<double> _bloomRing1;
  late Animation<double> _bloomRing2;
  late Animation<double> _bloomRing3;
  late Animation<double> _usernameFade;

  // Background large blob animations (15-20 slow pulsing blobs)
  late List<AnimationController> _blobControllers;

  bool _showCelebration = false;
  String? _generatedUsername;

  static const _blobCount = 16;

  @override
  void initState() {
    super.initState();

    // Entry
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _contentFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut),
    );
    _contentSlide = Tween(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));

    // Biometric
    _bioCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _bioScale = Tween(begin: 1.0, end: 1.07).animate(
      CurvedAnimation(parent: _bioCtrl, curve: Curves.easeInOut),
    );
    _bioPulse = Tween(begin: 0.05, end: 0.25).animate(
      CurvedAnimation(parent: _bioCtrl, curve: Curves.easeInOut),
    );

    // Bloom celebration
    _bloomCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _bloomRing1 = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _bloomCtrl,
          curve: const Interval(0.0, 0.7, curve: Curves.easeOut)),
    );
    _bloomRing2 = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _bloomCtrl,
          curve: const Interval(0.15, 0.85, curve: Curves.easeOut)),
    );
    _bloomRing3 = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _bloomCtrl,
          curve: const Interval(0.3, 1.0, curve: Curves.easeOut)),
    );
    _usernameFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _bloomCtrl,
          curve: const Interval(0.5, 1.0, curve: Curves.easeOut)),
    );

    // Background large blobs — each with its own timing so they desync
    _blobControllers = List.generate(_blobCount, (i) {
      final ctrl = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 5000 + (i * 400) % 3000),
      )..repeat(reverse: true);
      return ctrl;
    });

    _entryCtrl.forward();

    Future.microtask(
        () => ref.read(authStateProvider.notifier).checkRegistration());
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _bioCtrl.dispose();
    _bloomCtrl.dispose();
    for (final c in _blobControllers) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Email login bottom sheet ─────────────────────────────────────────────────
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
        final c = MOColors.of(ctx);
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: ClipPath(
                clipper: _OrganicSheetClipper(),
                child: Container(
                  color: c.card,
                  padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Orchid gradient handle bar
                      Container(
                        width: 48,
                        height: 5,
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          gradient: c.orchidGradient,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      Text(
                        'Inicio con Email',
                        style: GoogleFonts.quicksand(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: c.text,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _MOTextField(
                        controller: emailCtl,
                        label: 'Email',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 12),
                      _MOTextField(
                        controller: passCtl,
                        label: 'Password',
                        icon: Icons.lock_outline,
                        obscureText: true,
                        onSubmitted: (_) => _submitEmail(
                          emailCtl, passCtl, ctx, setSheet,
                          () => errorText, (v) => errorText = v,
                          () => loading, (v) => loading = v,
                        ),
                      ),
                      if (errorText != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          errorText!,
                          style: GoogleFonts.quicksand(
                              fontSize: 13, color: Colors.red[400]),
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
                                style: GoogleFonts.quicksand(
                                  fontWeight: FontWeight.w600,
                                  color: c.text.withValues(alpha: 0.45),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: MOOrchidButton(
                              label: loading ? '...' : 'ENTRAR',
                              height: 48,
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
                      const SizedBox(height: 8),
                    ],
                  ),
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

  void _handleBiometricTap() async {
    final notifier = ref.read(authStateProvider.notifier);
    final state = ref.read(authStateProvider);
    bool success = false;

    if (state.username == null) {
      success = await notifier.register();
      if (success && mounted) {
        final newUsername = ref.read(authStateProvider).username;
        setState(() {
          _generatedUsername = newUsername;
          _showCelebration = true;
        });
        _bloomCtrl.forward();
        Future.delayed(const Duration(milliseconds: 2200), () {
          if (mounted) context.go('/home');
        });
      }
    } else {
      success = await notifier.login();
      if (success && mounted) context.go('/home');
    }

    if (!success && mounted) {
      final error = ref.read(authStateProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          error ?? AppConstants.errorAuth,
          style: GoogleFonts.quicksand(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = MOColors.of(context);
    final authState = ref.watch(authStateProvider);
    final isFirstTime = authState.username == null;

    ref.listen<AuthState>(authStateProvider, (_, next) {
      if (next.isAuthenticated && !_showCelebration && mounted) {
        context.go('/home');
      }
    });

    return Scaffold(
      backgroundColor: c.surface,
      body: SizedBox.expand(
        child: Stack(
          children: [
            // ── Large slow-pulsing background blobs ──────────────────────────
            ..._buildBackgroundBlobs(context),

            // ── Floating pollen particles ─────────────────────────────────────
            const MOFloatingParticles(count: 22, seedOffset: 50),

            // ── Free-floating center content (NO card container) ──────────────
            if (_showCelebration)
              _buildCelebration(context)
            else
              FadeTransition(
                opacity: _contentFade,
                child: SlideTransition(
                  position: _contentSlide,
                  child: _buildMainContent(context, isFirstTime, authState.isLoading),
                ),
              ),

            // ── Bottom area: "o inicia con email" ─────────────────────────────
            if (!_showCelebration)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Center(
                      child: GestureDetector(
                        onLongPress: _showEmailLogin,
                        child: Text(
                          'o inicia con email',
                          style: GoogleFonts.quicksand(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: c.orchidPurple.withValues(alpha: 0.45),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Large background blobs ──────────────────────────────────────────────────
  List<Widget> _buildBackgroundBlobs(BuildContext context) {
    final c = MOColors.of(context);
    final size = MediaQuery.of(context).size;
    final rng = math.Random(42);

    return List.generate(_blobCount, (i) {
      final blobSize = 30.0 + rng.nextDouble() * 50;
      final left = rng.nextDouble() * size.width;
      final top = rng.nextDouble() * size.height;
      final opacity = 0.03 + rng.nextDouble() * 0.03;
      final isOrchidPink = rng.nextBool();
      final color = isOrchidPink ? c.orchidPink : c.orchidPurple;
      final ctrl = _blobControllers[i];

      return AnimatedBuilder(
        animation: ctrl,
        builder: (_, __) {
          final scale = 0.85 + ctrl.value * 0.30;
          return Positioned(
            left: left - blobSize / 2,
            top: top - blobSize / 2,
            child: Transform.scale(
              scale: scale,
              child: Container(
                width: blobSize,
                height: blobSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: opacity),
                ),
              ),
            ),
          );
        },
      );
    });
  }

  // ── Main free-floating content ──────────────────────────────────────────────
  Widget _buildMainContent(BuildContext context, bool isFirstTime, bool isLoading) {
    final c = MOColors.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // BC monogram with orchid glow
        Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: c.orchidPurple.withValues(alpha: 0.50),
                blurRadius: 36,
                spreadRadius: 4,
              ),
              BoxShadow(
                color: c.orchidPink.withValues(alpha: 0.25),
                blurRadius: 60,
                spreadRadius: 8,
              ),
            ],
          ),
          child: ShaderMask(
            shaderCallback: (bounds) => c.orchidGradient.createShader(bounds),
            child: Text(
              'BC',
              style: GoogleFonts.quicksand(
                fontSize: 48,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Welcome text
        GestureDetector(
          onLongPress: _showEmailLogin,
          child: Text(
            isFirstTime ? 'Bienvenida' : 'Hola de nuevo',
            style: GoogleFonts.quicksand(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: c.text,
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Subtitle
        Text(
          isFirstTime
              ? 'Tu jardin de belleza te espera'
              : (ref.read(authStateProvider).username ?? ''),
          style: GoogleFonts.quicksand(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: c.orchidPink.withValues(alpha: 0.60),
          ),
        ),

        const SizedBox(height: 48),

        // ── Fingerprint button: double ring with breathing glow ────────────
        GestureDetector(
          onTap: isLoading ? null : _handleBiometricTap,
          child: AnimatedBuilder(
            animation: _bioCtrl,
            builder: (_, __) {
              return Transform.scale(
                scale: isLoading ? 1.0 : _bioScale.value,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outermost ambient glow
                    Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            c.orchidPurple.withValues(
                                alpha: isLoading
                                    ? 0.03
                                    : _bioPulse.value * 0.5),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    // Outer ring
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: c.orchidPink.withValues(
                              alpha: isLoading ? 0.08 : _bioPulse.value),
                          width: 1.5,
                        ),
                      ),
                    ),
                    // Inner ring / button
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: SweepGradient(
                          colors: [
                            c.orchidDeep,
                            c.card,
                            c.orchidDeep,
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                        border: Border.all(
                          color: c.orchidPink.withValues(
                              alpha: isLoading ? 0.15 : _bioPulse.value * 0.7),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: c.orchidPink.withValues(
                                alpha: isLoading
                                    ? 0.04
                                    : _bioPulse.value * 0.6),
                            blurRadius: 28,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Center(
                        child: isLoading
                            ? const MOLoadingDots()
                            : ShaderMask(
                                shaderCallback: (bounds) =>
                                    c.orchidGradient.createShader(bounds),
                                child: const Icon(
                                  Icons.fingerprint,
                                  size: 46,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 16),

        // Instruction text
        Text(
          isFirstTime
              ? 'Toca para comenzar'
              : 'Toca para autenticarte',
          style: GoogleFonts.quicksand(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: c.text.withValues(alpha: 0.40),
          ),
        ),
      ],
    );
  }

  // ── Orchid bloom celebration ─────────────────────────────────────────────────
  Widget _buildCelebration(BuildContext context) {
    final c = MOColors.of(context);
    final size = MediaQuery.of(context).size;
    return Stack(
      children: [
        // Expanding bloom rings from center
        Center(
          child: AnimatedBuilder(
            animation: _bloomCtrl,
            builder: (_, __) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  _buildBloomRing(c, _bloomRing1, size.width * 0.9, 0.18),
                  _buildBloomRing(c, _bloomRing2, size.width * 0.65, 0.25),
                  _buildBloomRing(c, _bloomRing3, size.width * 0.45, 0.35),
                ],
              );
            },
          ),
        ),
        // Floating content
        Center(
          child: FadeTransition(
            opacity: _usernameFade,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Orchid blossom emoji
                Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: c.orchidPink.withValues(alpha: 0.35),
                        blurRadius: 32,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: const Text(
                    '\u{1F338}',
                    style: TextStyle(fontSize: 64),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Tu nombre es',
                  style: GoogleFonts.quicksand(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: c.text.withValues(alpha: 0.65),
                  ),
                ),
                const SizedBox(height: 8),
                ShaderMask(
                  shaderCallback: (bounds) =>
                      c.orchidGradient.createShader(bounds),
                  child: Text(
                    _generatedUsername ?? '',
                    style: GoogleFonts.quicksand(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBloomRing(MOColors c, Animation<double> anim, double maxDiameter, double opacity) {
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) {
        final t = anim.value;
        final diameter = maxDiameter * t;
        final ringOpacity = (1.0 - t) * opacity;
        return Container(
          width: diameter,
          height: diameter,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: c.orchidPink.withValues(alpha: ringOpacity),
              width: 1.5,
            ),
            gradient: RadialGradient(
              colors: [
                c.orchidPurple.withValues(alpha: ringOpacity * 0.3),
                Colors.transparent,
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Organic rounded top clipper for the email sheet ──────────────────────────
class _OrganicSheetClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    const r = 36.0;
    final path = Path();
    path.moveTo(r, 0);
    path.quadraticBezierTo(size.width / 2, -6, size.width - r, 0);
    path.quadraticBezierTo(size.width, 0, size.width, r);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.lineTo(0, r);
    path.quadraticBezierTo(0, 0, r, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_OrganicSheetClipper _) => false;
}

// ─── Themed text field ─────────────────────────────────────────────────────────
class _MOTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onSubmitted;

  const _MOTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final c = MOColors.of(context);
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      onSubmitted: onSubmitted,
      style: GoogleFonts.quicksand(color: c.text, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.quicksand(
          color: c.orchidPurple.withValues(alpha: 0.7),
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(icon, size: 20, color: c.orchidPurple.withValues(alpha: 0.7)),
        filled: true,
        fillColor: c.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: c.orchidDeep, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: c.orchidPurple, width: 1.5),
        ),
      ),
    );
  }
}
