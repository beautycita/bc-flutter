import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../config/constants.dart';
import '../config/theme_extension.dart';
import '../services/supabase_client.dart';
import '../services/toast_service.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _celebrationAnimation;

  bool _showCelebration = false;
  String? _generatedUsername;

  // Registration flow state
  int _regStep = 0; // 0=info, 1=otp, 2=biometric
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _otpFocusNode = FocusNode();
  bool _otpSending = false;
  bool _otpVerifying = false;
  bool _phoneVerified = false;
  String? _regError;
  String? _otpChannel;

  // Triple-tap detection
  int _tapCount = 0;
  DateTime _lastTapTime = DateTime(0);
  final _fingerprintKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _celebrationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.elasticOut),
    );

    _otpController.addListener(_onOtpChanged);

    Future.microtask(
        () => ref.read(authStateProvider.notifier).checkRegistration());
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _otpController.removeListener(_onOtpChanged);
    _otpController.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  void _onOtpChanged() {
    setState(() {});
    if (_otpController.text.length == 6 && !_otpVerifying) {
      _otpVerifying = true;
      Future.microtask(() => _verifyOtp());
    }
  }

  String get _formattedPhone => '+52${_phoneController.text.trim()}';

  void _handlePointerDown(PointerDownEvent event) {
    final fpBox =
        _fingerprintKey.currentContext?.findRenderObject() as RenderBox?;
    if (fpBox != null) {
      final fpPos = fpBox.localToGlobal(Offset.zero);
      final fpRect = fpPos & fpBox.size;
      if (fpRect.contains(event.position)) return;
    }

    final now = DateTime.now();
    if (now.difference(_lastTapTime) > const Duration(milliseconds: 500)) {
      _tapCount = 0;
    }
    _tapCount++;
    _lastTapTime = now;
    if (_tapCount >= 3) {
      _tapCount = 0;
      _showEmailAuth();
    }
  }

  void _showEmailAuth() {
    final emailCtl = TextEditingController();
    final passCtl = TextEditingController();
    String? errorText;
    bool loading = false;
    bool isRegisterMode = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final primary = theme.colorScheme.primary;
        final onSurface = theme.colorScheme.onSurface;
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            Future<void> submit() async {
              if (emailCtl.text.trim().isEmpty ||
                  passCtl.text.trim().isEmpty) return;
              setSheetState(() {
                loading = true;
                errorText = null;
              });
              final notifier = ref.read(authStateProvider.notifier);
              final ok = isRegisterMode
                  ? await notifier.signUpWithEmail(
                      emailCtl.text.trim(), passCtl.text.trim())
                  : await notifier.signInWithEmail(
                      emailCtl.text.trim(), passCtl.text.trim());
              if (ok && mounted) {
                Navigator.of(ctx).pop();
                context.go('/home');
              } else {
                setSheetState(() {
                  loading = false;
                  errorText = ref.read(authStateProvider).error ??
                      (isRegisterMode
                          ? 'Error al crear cuenta'
                          : 'Error al iniciar sesion');
                });
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppConstants.radiusLG),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Text(
                      isRegisterMode ? 'Crear Cuenta' : 'Inicio con Email',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: onSurface,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: emailCtl,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: const Icon(Icons.email_outlined, size: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passCtl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline, size: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                      onSubmitted: (_) => submit(),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        errorText!,
                        style: GoogleFonts.nunito(
                          fontSize: 13,
                          color: Colors.red[700],
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
                              style: GoogleFonts.nunito(
                                fontWeight: FontWeight.w600,
                                color: onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: loading ? null : () => submit(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                    AppConstants.radiusSM),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: loading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    isRegisterMode ? 'Registrar' : 'Entrar',
                                    style: GoogleFonts.nunito(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () {
                        setSheetState(() {
                          isRegisterMode = !isRegisterMode;
                          errorText = null;
                        });
                      },
                      child: Text(
                        isRegisterMode
                            ? 'Ya tienes cuenta? Inicia sesion'
                            : 'No tienes cuenta? Crea una',
                        style: GoogleFonts.nunito(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: primary,
                        ),
                      ),
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

  // ── Registration flow: Send OTP ───────────────────────────────────
  Future<void> _sendOtp() async {
    final name = _nameController.text.trim();
    final digits = _phoneController.text.trim();
    if (name.length < 2) {
      setState(() => _regError = 'Ingresa tu nombre');
      return;
    }
    if (digits.length != 10) {
      setState(() => _regError = 'Ingresa 10 digitos');
      return;
    }

    setState(() {
      _otpSending = true;
      _regError = null;
    });

    try {
      // We need a Supabase session first for the phone-verify edge function
      // But we don't have one yet during registration...
      // Use the salon-registro endpoint instead for unauthenticated OTP
      final res = await SupabaseClientService.client.functions.invoke(
        'salon-registro',
        body: {'action': 'send_otp', 'phone': _formattedPhone},
      );
      final data = res.data as Map<String, dynamic>?;
      if (data == null || data['sent'] != true) {
        throw Exception(data?['error'] ?? 'No se pudo enviar el codigo');
      }
      _otpChannel = data['channel'] as String?;
      setState(() {
        _otpSending = false;
        _regStep = 1;
      });
    } catch (e) {
      setState(() {
        _otpSending = false;
        _regError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  // ── Registration flow: Verify OTP ─────────────────────────────────
  Future<void> _verifyOtp() async {
    final code = _otpController.text.trim();
    if (code.length != 6) {
      setState(() {
        _regError = 'Ingresa los 6 digitos';
        _otpVerifying = false;
      });
      return;
    }

    setState(() => _regError = null);

    try {
      final res = await SupabaseClientService.client.functions.invoke(
        'salon-registro',
        body: {
          'action': 'verify_otp',
          'phone': _formattedPhone,
          'code': code,
        },
      );
      final data = res.data as Map<String, dynamic>?;
      if (data == null || data['verified'] != true) {
        throw Exception(data?['error'] ?? 'Codigo incorrecto');
      }

      setState(() {
        _phoneVerified = true;
        _regStep = 2;
        _otpVerifying = false;
      });
    } catch (e) {
      setState(() {
        _regError = e.toString().replaceFirst('Exception: ', '');
        _otpVerifying = false;
        _otpController.clear();
      });
    }
  }

  // ── Registration flow: Biometric + account creation ───────────────
  void _handleBiometricTap() async {
    final authNotifier = ref.read(authStateProvider.notifier);
    final authState = ref.read(authStateProvider);

    bool success = false;

    if (authState.username == null) {
      // New user: pass collected name + phone
      success = await authNotifier.register(
        fullName: _nameController.text.trim(),
        phone: _phoneVerified ? _formattedPhone : null,
      );

      if (success && mounted) {
        // Check for discovered salon match
        if (_phoneVerified) {
          final profileNotifier = ref.read(profileProvider.notifier);
          await profileNotifier.load(); // Reload profile with new data
          // Trigger discovered salon check
          final digits = _phoneController.text.trim();
          if (digits.length == 10) {
            try {
              final last10 = digits;
              final match = await SupabaseClientService.client
                  .from('discovered_salons')
                  .select()
                  .or('phone.ilike.%$last10,whatsapp.ilike.%$last10')
                  .neq('status', 'registered')
                  .limit(1)
                  .maybeSingle();

              if (match != null && mounted) {
                context.go('/discovered-salon-confirm', extra: match);
                return;
              }
            } catch (e) {
              debugPrint('Discovered salon check error: $e');
            }
          }
        }

        final newUsername = ref.read(authStateProvider).username;
        setState(() {
          _generatedUsername = newUsername;
          _showCelebration = true;
        });

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            context.go('/home');
          }
        });
      }
    } else {
      success = await authNotifier.login();

      if (success && mounted) {
        context.go('/home');
      }
    }

    if (!success && mounted) {
      final error = ref.read(authStateProvider).error;
      _showErrorSnackBar(error ?? AppConstants.errorAuth);
    }
  }

  void _showErrorSnackBar(String message) {
    ToastService.showError(message);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final isFirstTime = authState.username == null;
    final primary = Theme.of(context).colorScheme.primary;
    final secondary = Theme.of(context).colorScheme.secondary;

    ref.listen<AuthState>(authStateProvider, (previous, next) {
      if (next.isAuthenticated && !_showCelebration && mounted) {
        context.go('/home');
      }
    });

    return Scaffold(
      body: SizedBox.expand(
        child: Listener(
          onPointerDown: _handlePointerDown,
          child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFFF8F0), Color(0xFFFFF0F5), Color(0xFFFFF8F0)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
          child: Stack(
            children: [
              // Decorative circles
              Positioned(
                top: -40,
                left: -50,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primary.withValues(alpha: 0.04),
                  ),
                ),
              ),
              Positioned(
                bottom: 40,
                right: -30,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: secondary.withValues(alpha: 0.05),
                  ),
                ),
              ),

              // Content
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: _showCelebration
                      ? _buildCelebrationContent()
                      : isFirstTime
                          ? _buildRegistrationFlow(authState.isLoading)
                          : _buildLoginContent(authState.isLoading),
                ),
              ),
            ],
          ),
        ),
        ),
        ),
      ),
    );
  }

  // ── Returning user: just fingerprint ──────────────────────────────
  Widget _buildLoginContent(bool isLoading) {
    final primary = Theme.of(context).colorScheme.primary;
    final onSurfaceLight = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);
    final username = ref.watch(authStateProvider).username;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Hola de nuevo${username != null ? ', $username' : ''}!',
          style: GoogleFonts.poppins(
            fontSize: 38,
            fontWeight: FontWeight.w700,
            color: primary,
            height: 1.1,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Toca para autenticarte',
          style: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: onSurfaceLight,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 36),
        _buildFingerprintButton(isLoading),
        const SizedBox(height: 28),
        if (!isLoading)
          Text(
            'Toca la huella para continuar',
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: onSurfaceLight,
            ),
            textAlign: TextAlign.center,
          ),
      ],
    );
  }

  // ── New user: info → OTP → biometric ──────────────────────────────
  Widget _buildRegistrationFlow(bool isLoading) {
    final primary = Theme.of(context).colorScheme.primary;
    final onSurfaceLight = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _regStep == 0
          ? _buildInfoStep(primary, onSurfaceLight)
          : _regStep == 1
              ? _buildOtpStep(primary, onSurfaceLight)
              : _buildBiometricStep(primary, onSurfaceLight, isLoading),
    );
  }

  // ── Step 0: Name + Phone ──────────────────────────────────────────
  Widget _buildInfoStep(Color primary, Color onSurfaceLight) {
    final bcTheme = Theme.of(context).extension<BCThemeExtension>()!;

    return Column(
      key: const ValueKey('info'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Bienvenida!',
          style: GoogleFonts.poppins(
            fontSize: 34,
            fontWeight: FontWeight.w700,
            color: primary,
            height: 1.1,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Cuentanos sobre ti',
          style: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: onSurfaceLight,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),

        // Name field
        TextField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          style: GoogleFonts.nunito(fontSize: 16),
          decoration: InputDecoration(
            labelText: 'Tu nombre',
            labelStyle: GoogleFonts.nunito(color: onSurfaceLight),
            prefixIcon: Icon(Icons.person_outline, size: 20, color: primary),
            filled: true,
            fillColor: const Color(0xFFF5F0F3),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusMD),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusMD),
              borderSide: BorderSide(color: primary, width: 1.5),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        const SizedBox(height: 16),

        // Phone field
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          style: GoogleFonts.nunito(fontSize: 16),
          decoration: InputDecoration(
            prefixText: '+52 ',
            prefixStyle: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: primary,
            ),
            labelText: 'Tu celular',
            labelStyle: GoogleFonts.nunito(color: onSurfaceLight),
            prefixIcon: Icon(Icons.phone_outlined, size: 20, color: primary),
            filled: true,
            fillColor: const Color(0xFFF5F0F3),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusMD),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusMD),
              borderSide: BorderSide(color: primary, width: 1.5),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        const SizedBox(height: 8),

        if (_regError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _regError!,
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: Colors.red.shade700,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),

        const SizedBox(height: 16),

        // Verify button
        GestureDetector(
          onTap: _otpSending ? null : _sendOtp,
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              gradient: !_otpSending
                  ? bcTheme.goldGradientDirectional()
                  : const LinearGradient(
                      colors: [Color(0xFFCCCCCC), Color(0xFFAAAAAA)],
                    ),
              borderRadius: BorderRadius.circular(AppConstants.radiusMD),
              boxShadow: !_otpSending
                  ? [
                      BoxShadow(
                        color: const Color(0xFFB8860B).withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: _otpSending
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    'Verificar numero',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Te enviaremos un codigo por WhatsApp o SMS',
          style: GoogleFonts.nunito(
            fontSize: 12,
            color: onSurfaceLight,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // ── Step 1: OTP Verification ──────────────────────────────────────
  Widget _buildOtpStep(Color primary, Color onSurfaceLight) {
    final otp = _otpController.text;
    final channelText = _otpChannel == 'whatsapp' ? 'WhatsApp' : 'SMS';

    return Column(
      key: const ValueKey('otp'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.sms_outlined, size: 48, color: primary),
        const SizedBox(height: 16),
        Text(
          'Ingresa el codigo',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: primary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Enviamos un codigo de 6 digitos a $_formattedPhone por $channelText',
          style: GoogleFonts.nunito(
            fontSize: 14,
            color: onSurfaceLight,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),

        // OTP visual boxes
        GestureDetector(
          onTap: () => _otpFocusNode.requestFocus(),
          child: Stack(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (i) {
                  final hasDigit = i < otp.length;
                  final isCurrent = i == otp.length && _otpFocusNode.hasFocus;
                  return Container(
                    width: 44,
                    height: 54,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F0F3),
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusMD),
                      border: Border.all(
                        color: isCurrent
                            ? primary
                            : hasDigit
                                ? primary.withValues(alpha: 0.3)
                                : Colors.transparent,
                        width: isCurrent ? 1.5 : 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: hasDigit
                        ? Text(
                            otp[i],
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: primary,
                            ),
                          )
                        : isCurrent
                            ? Container(width: 2, height: 24, color: primary)
                            : null,
                  );
                }),
              ),
              Positioned.fill(
                child: Opacity(
                  opacity: 0,
                  child: TextField(
                    controller: _otpController,
                    focusNode: _otpFocusNode,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    decoration: const InputDecoration(
                      counterText: '',
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        if (_regError != null) ...[
          const SizedBox(height: 12),
          Text(
            _regError!,
            style: GoogleFonts.nunito(
              fontSize: 13,
              color: Colors.red.shade700,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],

        const SizedBox(height: 24),
        TextButton(
          onPressed: _otpSending
              ? null
              : () {
                  _otpController.clear();
                  _sendOtp();
                },
          child: Text(
            'Reenviar codigo',
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: primary,
            ),
          ),
        ),
        TextButton(
          onPressed: () {
            setState(() {
              _regStep = 0;
              _regError = null;
              _otpController.clear();
              _otpVerifying = false;
            });
          },
          child: Text(
            'Cambiar numero',
            style: GoogleFonts.nunito(
              fontSize: 13,
              color: onSurfaceLight,
            ),
          ),
        ),
      ],
    );
  }

  // ── Step 2: Biometric ─────────────────────────────────────────────
  Widget _buildBiometricStep(
      Color primary, Color onSurfaceLight, bool isLoading) {
    return Column(
      key: const ValueKey('biometric'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Numero verificado!',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: primary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Registra tu huella para entrar rapido',
          style: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: onSurfaceLight,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 36),
        _buildFingerprintButton(isLoading),
        const SizedBox(height: 28),
        if (!isLoading)
          Text(
            'Toca la huella para completar',
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: onSurfaceLight,
            ),
            textAlign: TextAlign.center,
          ),
      ],
    );
  }

  Widget _buildFingerprintButton(bool isLoading) {
    final primary = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      key: _fingerprintKey,
      onTap: isLoading ? null : _handleBiometricTap,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: isLoading ? 1.0 : _pulseAnimation.value,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    primary.withValues(alpha: 0.1),
                    primary.withValues(alpha: 0.06),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: primary.withValues(alpha: 0.15),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: primary.withValues(alpha: 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Center(
                child: isLoading
                    ? CircularProgressIndicator(
                        color: primary,
                        strokeWidth: 3,
                      )
                    : Icon(
                        Icons.fingerprint,
                        size: 56,
                        color: primary,
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCelebrationContent() {
    final primary = Theme.of(context).colorScheme.primary;
    final secondary = Theme.of(context).colorScheme.secondary;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return ScaleTransition(
      scale: _celebrationAnimation,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  secondary.withValues(alpha: 0.15),
                  secondary.withValues(alpha: 0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Center(
              child: Text(
                '\u{1F389}',
                style: TextStyle(fontSize: 56),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Bienvenida,',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _nameController.text.trim().isNotEmpty
                ? _nameController.text.trim()
                : _generatedUsername ?? '',
            style: GoogleFonts.poppins(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              color: primary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
