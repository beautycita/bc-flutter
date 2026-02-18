import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../config/constants.dart';
import '../../../providers/auth_provider.dart';
import 'on_widgets.dart';

class ONAuthScreen extends ConsumerStatefulWidget {
  const ONAuthScreen({super.key});

  @override
  ConsumerState<ONAuthScreen> createState() => _ONAuthScreenState();
}

class _ONAuthScreenState extends ConsumerState<ONAuthScreen>
    with TickerProviderStateMixin {
  // Boot sequence state
  _BootPhase _phase = _BootPhase.initializing;

  // Which lines are visible in the boot log
  final List<_BootLine> _lines = [];

  // Fingerprint frame glow pulsing
  late AnimationController _fpPulseCtrl;
  late Animation<double> _fpPulseAnim;

  // Cursor blink (for label below fingerprint frame)
  bool _labelVisible = false;
  Timer? _labelBlinkTimer;

  // Scan on tap
  late AnimationController _scanCtrl;
  late Animation<double> _scanAnim;
  bool _scanning = false;

  // Result text
  String? _resultText;
  Color? _resultColor;

  bool _showCelebration = false;
  String? _generatedUsername;

  // Full scan single-shot controller
  late AnimationController _singleScanCtrl;

  @override
  void initState() {
    super.initState();

    _fpPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _fpPulseAnim = Tween(begin: 0.25, end: 0.75).animate(
      CurvedAnimation(parent: _fpPulseCtrl, curve: Curves.easeInOut),
    );

    _scanCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scanAnim = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanCtrl, curve: Curves.linear),
    );

    _singleScanCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Check registration first, then start boot sequence
    Future.microtask(() async {
      await ref.read(authStateProvider.notifier).checkRegistration();
      if (mounted) _runBootSequence();
    });

    ref.listenManual<AuthState>(authStateProvider, (previous, next) {
      if (next.isAuthenticated && !_showCelebration && mounted) {
        context.go('/home');
      }
    });
  }

  @override
  void dispose() {
    _fpPulseCtrl.dispose();
    _scanCtrl.dispose();
    _singleScanCtrl.dispose();
    _labelBlinkTimer?.cancel();
    super.dispose();
  }

  // ─── Boot sequence ────────────────────────────────────────────────────────

  Future<void> _runBootSequence() async {
    if (!mounted) return;
    final c = ONColors.of(context);

    // t=0: INITIALIZING SYSTEM...
    await _addBootLine('INITIALIZING SYSTEM...', c.cyan.withValues(alpha: 0.7));
    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;
    // t=800ms: BEAUTYCITA v1.0
    await _addBootLine('BEAUTYCITA  v1.0', c.text);
    await Future.delayed(const Duration(milliseconds: 400));

    if (!mounted) return;
    // t=1200ms: BIOMETRIC MODULE: READY
    await _addBootLine('BIOMETRIC MODULE: READY', c.green);
    await Future.delayed(const Duration(milliseconds: 400));

    if (!mounted) return;

    // t=1600ms: Show fingerprint frame, start blinking label
    setState(() => _phase = _BootPhase.ready);
    _startLabelBlink();
  }

  Future<void> _addBootLine(String text, Color color) async {
    if (!mounted) return;
    setState(() {
      _lines.add(_BootLine(text: '', targetText: text, color: color));
    });
    // Type it out
    final idx = _lines.length - 1;
    for (int i = 0; i <= text.length; i++) {
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 28));
      if (!mounted) return;
      setState(() {
        _lines[idx] = _BootLine(
          text: text.substring(0, i),
          targetText: text,
          color: color,
        );
      });
    }
  }

  void _startLabelBlink() {
    _labelBlinkTimer = Timer.periodic(
      const Duration(milliseconds: 600),
      (_) {
        if (!mounted) return;
        setState(() => _labelVisible = !_labelVisible);
      },
    );
  }

  // ─── Auth actions ─────────────────────────────────────────────────────────

  void _handleBiometricTap() async {
    if (_scanning) return;
    final c = ONColors.of(context);

    // Run scan animation
    setState(() => _scanning = true);
    _singleScanCtrl.reset();
    await _singleScanCtrl.forward();

    final authNotifier = ref.read(authStateProvider.notifier);
    final authState = ref.read(authStateProvider);

    if (authState.username == null) {
      // Register
      final ok = await authNotifier.register();
      if (!mounted) return;
      if (ok) {
        final newUsername = ref.read(authStateProvider).username;
        await _showResult('ACCESO AUTORIZADO', c.green);
        if (mounted) {
          setState(() {
            _generatedUsername = newUsername;
            _showCelebration = true;
            _phase = _BootPhase.celebration;
          });
          // Type out username assignment in boot log
          await _addBootLine('GENERANDO PERFIL...', c.cyan.withValues(alpha: 0.7));
          await _addBootLine('NOMBRE ASIGNADO: ${newUsername ?? ''}', c.green);
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) context.go('/home');
        }
      } else {
        final err = ref.read(authStateProvider).error ?? AppConstants.errorAuth;
        await _showResult('ERROR: $err', c.red);
      }
    } else {
      // Login
      final ok = await authNotifier.login();
      if (!mounted) return;
      if (ok) {
        await _showResult('ACCESO AUTORIZADO', c.green);
        if (mounted) context.go('/home');
      } else {
        final err = ref.read(authStateProvider).error ?? AppConstants.errorAuth;
        await _showResult('ERROR: $err', c.red);
      }
    }

    if (mounted) setState(() => _scanning = false);
  }

  Future<void> _showResult(String text, Color color) async {
    if (!mounted) return;
    setState(() {
      _resultText = '';
      _resultColor = color;
    });
    for (int i = 0; i <= text.length; i++) {
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 30));
      if (!mounted) return;
      setState(() => _resultText = text.substring(0, i));
    }
    await Future.delayed(const Duration(milliseconds: 600));
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
        final c = ONColors.of(ctx);
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: c.surface1,
                  border: Border.all(
                    color: c.cyan.withValues(alpha: 0.3),
                    width: 1.0,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Terminal header
                    Row(
                      children: [
                        Container(
                            width: 8,
                            height: 8,
                            color: c.cyan.withValues(alpha: 0.6)),
                        const SizedBox(width: 8),
                        Text(
                          '> AUTENTICACION_EMAIL',
                          style: GoogleFonts.firaCode(
                            fontSize: 10,
                            color: c.cyan.withValues(alpha: 0.6),
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Inicio con Email',
                      style: GoogleFonts.rajdhani(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: c.text,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _TerminalTextField(
                      controller: emailCtl,
                      label: 'EMAIL',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    _TerminalTextField(
                      controller: passCtl,
                      label: 'PASSWORD',
                      obscureText: true,
                      onSubmitted: (_) => _submitEmail(
                        emailCtl, passCtl, ctx, setSheetState,
                        () => loading, (v) => loading = v,
                        () => errorText, (v) => errorText = v,
                      ),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        '! $errorText',
                        style: GoogleFonts.firaCode(
                          fontSize: 11,
                          color: c.red,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.of(ctx).pop(),
                            child: ClipPath(
                              clipper: const ONAngularClipper(clipSize: 8),
                              child: Container(
                                height: 46,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: c.cyan.withValues(alpha: 0.2),
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'CANCELAR',
                                  style: GoogleFonts.rajdhani(
                                    fontWeight: FontWeight.w600,
                                    color: c.text.withValues(alpha: 0.4),
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ONAngularButton(
                            label: loading ? '...' : 'ENTRAR',
                            height: 46,
                            onTap: loading
                                ? null
                                : () => _submitEmail(
                                      emailCtl, passCtl, ctx, setSheetState,
                                      () => loading, (v) => loading = v,
                                      () => errorText, (v) => errorText = v,
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
    bool Function() getLoading,
    void Function(bool) setLoading,
    String? Function() getError,
    void Function(String?) setError,
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

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = ONColors.of(context);
    final authState = ref.watch(authStateProvider);
    final isFirstTime = authState.username == null;

    return Scaffold(
      backgroundColor: c.surface0,
      body: Stack(
        children: [
          // Scan-line overlay (horizontal lines at 2px interval, white 2% opacity)
          Positioned.fill(child: _ScanLineOverlay()),

          SafeArea(
            child: Column(
              children: [
                // ── Boot log area ─────────────────────────────────────────
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding:
                        const EdgeInsets.fromLTRB(24, 20, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        for (final line in _lines)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '> ',
                                  style: GoogleFonts.firaCode(
                                    fontSize: 12,
                                    color: c.cyan.withValues(alpha: 0.4),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    line.text,
                                    style: GoogleFonts.firaCode(
                                      fontSize: 12,
                                      color: line.color,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Result text
                        if (_resultText != null && _resultText!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Text(
                                  '> ',
                                  style: GoogleFonts.firaCode(
                                    fontSize: 12,
                                    color: (_resultColor ?? c.green).withValues(alpha: 0.5),
                                  ),
                                ),
                                Text(
                                  _resultText!,
                                  style: GoogleFonts.firaCode(
                                    fontSize: 12,
                                    color: _resultColor ?? c.green,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),

                // ── Fingerprint HUD frame area ─────────────────────────────
                if (_phase == _BootPhase.ready ||
                    _phase == _BootPhase.celebration)
                  Expanded(
                    flex: 3,
                    child: Center(
                      child: _phase == _BootPhase.celebration
                          ? _buildCelebration(c)
                          : _buildFingerprintArea(isFirstTime, authState, c),
                    ),
                  )
                else
                  Expanded(
                    flex: 3,
                    child: Center(
                      child: authState.isLoading
                          ? const ONDataDots()
                          : const SizedBox.shrink(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFingerprintArea(bool isFirstTime, AuthState authState, ONColors c) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // HUD frame with fingerprint inside
        GestureDetector(
          onTap: authState.isLoading ? null : _handleBiometricTap,
          onLongPress: _showEmailLogin,
          child: ONHudFrame(
            bracketSize: 24,
            bracketThickness: 2.0,
            color: c.cyan,
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                children: [
                  // Fingerprint icon
                  Center(
                    child: AnimatedBuilder(
                      animation: _fpPulseAnim,
                      builder: (context, _) {
                        return Icon(
                          Icons.fingerprint,
                          size: 80,
                          color:
                              c.cyan.withValues(alpha: _fpPulseAnim.value),
                        );
                      },
                    ),
                  ),

                  // Scan line on tap
                  if (_scanning)
                    AnimatedBuilder(
                      animation: _singleScanCtrl,
                      builder: (context, _) {
                        return Positioned(
                          top: _singleScanCtrl.value * 120,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 2,
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
                                  color: c.cyan.withValues(alpha: 0.7),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                  // Loading dots
                  if (authState.isLoading)
                    const Center(child: ONDataDots()),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Blinking label
        AnimatedOpacity(
          opacity: _labelVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: Column(
            children: [
              Text(
                isFirstTime
                    ? 'ESCANEAR HUELLA'
                    : 'TOCA PARA CONTINUAR',
                style: GoogleFonts.rajdhani(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: c.cyan,
                  letterSpacing: 2.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isFirstTime
                    ? '// Primer acceso: registro biometrico'
                    : '// Mantén presionado para email',
                style: GoogleFonts.firaCode(
                  fontSize: 10,
                  color: c.cyan.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCelebration(ONColors c) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ONHudFrame(
          bracketSize: 24,
          bracketThickness: 2.0,
          color: c.green,
          padding: const EdgeInsets.all(24),
          child: Container(
            width: 80,
            height: 80,
            color: c.green.withValues(alpha: 0.08),
            alignment: Alignment.center,
            child: Text(
              '\u2713',
              style: TextStyle(
                fontSize: 48,
                color: c.green,
                shadows: [
                  Shadow(
                    color: c.green.withValues(alpha: 0.8),
                    blurRadius: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'NOMBRE ASIGNADO:',
          style: GoogleFonts.firaCode(
            fontSize: 11,
            color: c.green.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _generatedUsername ?? '',
          style: GoogleFonts.rajdhani(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: c.cyan,
            letterSpacing: 2.0,
            shadows: [
              Shadow(
                color: c.cyan.withValues(alpha: 0.7),
                blurRadius: 16,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Boot phase enum ──────────────────────────────────────────────────────────

enum _BootPhase { initializing, ready, celebration }

// ─── Boot line model ──────────────────────────────────────────────────────────

class _BootLine {
  final String text;
  final String targetText;
  final Color color;
  const _BootLine({
    required this.text,
    required this.targetText,
    required this.color,
  });
}

// ─── Scan line background overlay ─────────────────────────────────────────────

class _ScanLineOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ScanLinePainter(),
      size: Size.infinite,
    );
  }
}

class _ScanLinePainter extends CustomPainter {
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
  bool shouldRepaint(_ScanLinePainter old) => false;
}

// ─── Terminal text field ──────────────────────────────────────────────────────

class _TerminalTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final TextInputType? keyboardType;
  final void Function(String)? onSubmitted;

  const _TerminalTextField({
    required this.controller,
    required this.label,
    this.obscureText = false,
    this.keyboardType,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final c = ONColors.of(context);
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: GoogleFonts.firaCode(color: c.text, fontSize: 13),
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.firaCode(
          color: c.cyan.withValues(alpha: 0.6),
          fontSize: 10,
          letterSpacing: 1.5,
        ),
        filled: true,
        fillColor: c.surface0,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(0),
          borderSide: BorderSide(color: c.cyan.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(0),
          borderSide: BorderSide(color: c.cyan.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(0),
          borderSide: BorderSide(color: c.cyan, width: 1.0),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }
}
