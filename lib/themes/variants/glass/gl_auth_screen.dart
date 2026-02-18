import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../config/constants.dart';
import '../../../providers/auth_provider.dart';
import 'gl_widgets.dart';

class GLAuthScreen extends ConsumerStatefulWidget {
  const GLAuthScreen({super.key});

  @override
  ConsumerState<GLAuthScreen> createState() => _GLAuthScreenState();
}

class _GLAuthScreenState extends ConsumerState<GLAuthScreen>
    with TickerProviderStateMixin {
  // Entry: panel materializes from scale 0.85 + fade
  late AnimationController _entryController;
  late Animation<double> _panelScale;
  late Animation<double> _panelFade;
  late Animation<double> _contentFade;

  // Biometric button: breathing glow + pulse
  late AnimationController _breatheController;
  late Animation<double> _breathe;

  // Neon border rotation
  late AnimationController _borderController;

  bool _showCelebration = false;
  String? _generatedUsername;

  @override
  void initState() {
    super.initState();

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _panelScale = Tween(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _panelFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    _contentFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
      ),
    );

    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _breathe = Tween(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _breatheController, curve: Curves.easeInOut),
    );

    _borderController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _entryController.forward();
    Future.microtask(
        () => ref.read(authStateProvider.notifier).checkRegistration());
  }

  @override
  void dispose() {
    _entryController.dispose();
    _breatheController.dispose();
    _borderController.dispose();
    super.dispose();
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
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

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
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final c = GlColors.of(ctx);
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                margin: const EdgeInsets.all(16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                          width: 1,
                        ),
                      ),
                      child: SafeArea(
                        top: false,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Drag handle
                            Container(
                              width: 40,
                              height: 4,
                              margin: const EdgeInsets.only(bottom: 20),
                              decoration: BoxDecoration(
                                gradient: c.neonGradient,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            ShaderMask(
                              shaderCallback: (b) =>
                                  c.neonGradient.createShader(b),
                              child: Text(
                                'Inicio con Email',
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            _GlassInput(
                              controller: emailCtl,
                              label: 'Email',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 12),
                            _GlassInput(
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
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: Colors.red[400],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: TextButton(
                                    onPressed: () => Navigator.of(ctx).pop(),
                                    child: Text(
                                      'Cancelar',
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w600,
                                        color: c.text
                                            .withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: GlNeonButton(
                                    label: loading ? '...' : 'ENTRAR',
                                    height: 46,
                                    onTap: loading
                                        ? null
                                        : () => _submitEmail(
                                              emailCtl,
                                              passCtl,
                                              ctx,
                                              setSheetState,
                                              () => errorText,
                                              (v) => errorText = v,
                                              () => loading,
                                              (v) => loading = v,
                                            ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
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
        setError(ref.read(authStateProvider).error ?? 'Error al iniciar sesion');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = GlColors.of(context);
    final authState = ref.watch(authStateProvider);
    final isFirstTime = authState.username == null;

    ref.listen<AuthState>(authStateProvider, (previous, next) {
      if (next.isAuthenticated && !_showCelebration && mounted) {
        context.go('/home');
      }
    });

    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: c.bgDeep,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Full-screen aurora background
          const GlAuroraBackground(child: SizedBox.expand()),

          // 15-20 floating neon particles
          ...List.generate(
            18,
            (i) => GlFloatingParticle(key: ValueKey('p$i'), index: i + 40),
          ),

          // Single centered frosted glass panel
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: FadeTransition(
                  opacity: _panelFade,
                  child: ScaleTransition(
                    scale: _panelScale,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                              width: 1,
                            ),
                          ),
                          child: FadeTransition(
                            opacity: _contentFade,
                            child: _showCelebration
                                ? _buildCelebration(c)
                                : _buildPanelContent(c, isFirstTime, authState.isLoading),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanelContent(GlColors c, bool isFirstTime, bool isLoading) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 36, 28, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Neon gradient "BC" logo — long-press = email login
          GestureDetector(
            onLongPress: _showEmailLogin,
            child: ShaderMask(
              shaderCallback: (bounds) => c.neonGradient.createShader(bounds),
              child: Text(
                'BC',
                style: GoogleFonts.inter(
                  fontSize: 64,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.0,
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          Text(
            isFirstTime ? 'Bienvenida' : 'Hola de nuevo',
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: c.text,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 8),

          Text(
            isFirstTime
                ? 'Tu agente de belleza inteligente'
                : (ref.read(authStateProvider).username ?? ''),
            style: GoogleFonts.inter(
              fontSize: 14,
              color: c.text.withValues(alpha: 0.60),
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 36),

          // Rotating neon border fingerprint button
          GestureDetector(
            onTap: isLoading ? null : _handleBiometricTap,
            child: AnimatedBuilder(
              animation: _breathe,
              builder: (context, child) {
                return Transform.scale(
                  scale: isLoading ? 1.0 : _breathe.value,
                  child: child,
                );
              },
              child: SizedBox(
                width: 108,
                height: 108,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Glow aura behind the circle
                    AnimatedBuilder(
                      animation: _breatheController,
                      builder: (context, _) {
                        final glow = 0.15 + _breatheController.value * 0.25;
                        return Container(
                          width: 108,
                          height: 108,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: c.neonPink.withValues(alpha: glow),
                                blurRadius: 30,
                                spreadRadius: 4,
                              ),
                              BoxShadow(
                                color: c.neonCyan.withValues(alpha: glow * 0.5),
                                blurRadius: 50,
                                spreadRadius: 8,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    // Rotating neon gradient border
                    AnimatedBuilder(
                      animation: _borderController,
                      builder: (context, child) {
                        return CustomPaint(
                          painter: _NeonCircleBorderPainter(
                            progress: _borderController.value,
                          ),
                          child: child,
                        );
                      },
                      child: SizedBox(
                        width: 100,
                        height: 100,
                        child: ClipOval(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: Container(
                              color: c.bgDeep.withValues(alpha: 0.7),
                              alignment: Alignment.center,
                              child: isLoading
                                  ? const GlNeonDots()
                                  : Icon(
                                      Icons.fingerprint,
                                      size: 48,
                                      color: c.text,
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          Text(
            'Toca para comenzar',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: c.text.withValues(alpha: 0.45),
            ),
          ),

          const SizedBox(height: 28),

          // CONTINUAR — frosted neon border button
          GlNeonButton(
            label: 'CONTINUAR',
            onTap: isLoading ? null : _handleBiometricTap,
          ),

          const SizedBox(height: 20),

          // "o" divider
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 0.5,
                  color: c.text.withValues(alpha: 0.15),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'o',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: c.text.withValues(alpha: 0.35),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  height: 0.5,
                  color: c.text.withValues(alpha: 0.15),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Outline biometric button
          GestureDetector(
            onTap: isLoading ? null : _handleBiometricTap,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: c.neonPink.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ShaderMask(
                        shaderCallback: (b) => c.neonGradient.createShader(b),
                        child: const Icon(
                          Icons.fingerprint,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ShaderMask(
                        shaderCallback: (b) => c.neonGradient.createShader(b),
                        child: Text(
                          'Acceso biometrico',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
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

  Widget _buildCelebration(GlColors c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 48, 28, 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('\u{1F389}', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 24),
          Text(
            'Tu nombre es',
            style: GoogleFonts.inter(
              fontSize: 18,
              color: c.text.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          ShaderMask(
            shaderCallback: (bounds) => c.neonGradient.createShader(bounds),
            child: Text(
              _generatedUsername ?? '',
              style: GoogleFonts.inter(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Bienvenida a BeautyCita',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: c.text.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Neon Circle Border CustomPainter ─────────────────────────────────────────
class _NeonCircleBorderPainter extends CustomPainter {
  final double progress;
  const _NeonCircleBorderPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final startAngle = progress * 2 * math.pi;

    final gradient = SweepGradient(
      startAngle: startAngle,
      endAngle: startAngle + 2 * math.pi,
      colors: const [glNeonPink, glNeonPurple, glNeonCyan, glNeonPink],
    );

    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 3);

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_NeonCircleBorderPainter old) =>
      old.progress != progress;
}

// ─── GlassInput ───────────────────────────────────────────────────────────────
class _GlassInput extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onSubmitted;

  const _GlassInput({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.onSubmitted,
  });

  @override
  State<_GlassInput> createState() => _GlassInputState();
}

class _GlassInputState extends State<_GlassInput> {
  final _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _focused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = GlColors.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: _focused ? c.neonGradient : null,
        border: _focused
            ? null
            : Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 0.8,
              ),
      ),
      padding: EdgeInsets.all(_focused ? 1.0 : 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            obscureText: widget.obscureText,
            keyboardType: widget.keyboardType,
            onSubmitted: widget.onSubmitted,
            style: GoogleFonts.inter(color: c.text, fontSize: 15),
            decoration: InputDecoration(
              labelText: widget.label,
              labelStyle: TextStyle(
                color: _focused ? c.neonPink : c.text.withValues(alpha: 0.5),
                fontSize: 14,
                fontFamily: GoogleFonts.inter().fontFamily,
              ),
              prefixIcon: Icon(
                widget.icon,
                size: 20,
                color: _focused ? c.neonPink : c.text.withValues(alpha: 0.4),
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
