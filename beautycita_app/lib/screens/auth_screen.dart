import 'dart:io';
import 'package:beautycita/config/app_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:beautycita/config/fonts.dart';
import '../providers/auth_provider.dart';
import '../config/constants.dart';
import '../services/biometric_preferences.dart';
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
  bool _registering = false;
  String? _generatedUsername;

  // Triple-tap detection for hidden email auth
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
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _handlePointerDown(PointerDownEvent event) {
    // Ignore taps on the fingerprint button itself
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

    showBurstBottomSheet(
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
              if (loading) return; // Prevent double-submit
              if (emailCtl.text.trim().isEmpty ||
                  passCtl.text.trim().isEmpty) {
                return;
              }
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
              if (ok && ctx.mounted) {
                Navigator.of(ctx).pop();
                if (mounted) context.go('/home');
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
                  color: Theme.of(ctx).colorScheme.surface,
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
                        color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.2),
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
                              foregroundColor: Theme.of(context).colorScheme.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                    AppConstants.radiusSM),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: loading
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Theme.of(context).colorScheme.onPrimary,
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

  void _handleBiometricTap() async {
    // Prevent double-tap duplicate accounts
    if (_registering) return;
    _registering = true;

    try {
      // Per-device toggle: if user disabled biometric login on this device
      // (Security screen), skip the biometric prompt and open email login.
      final biometricEnabled = await ref
          .read(biometricPreferencesProvider)
          .isEnabled();
      if (!biometricEnabled) {
        if (mounted) _showEmailAuth();
        return;
      }

      final authNotifier = ref.read(authStateProvider.notifier);
      final authState = ref.read(authStateProvider);

      bool success = false;

      if (authState.username == null) {
        // New user: biometric -> anonymous account -> auto-generated username
        success = await authNotifier.register();

        if (success && mounted) {
          // Google One Tap -- capture email as discovered_email metadata.
          // Skip on iOS: Google Sign-In SDK crashes without proper iOS OAuth config.
          if (!Platform.isIOS) {
            final linked = await authNotifier.captureGoogleEmail();
            if (mounted && linked) {
              ToastService.showSuccess('Google vinculado');
            }
          }

          // Show celebration screen with username for 3 seconds
          if (mounted) {
            final username = ref.read(authStateProvider).username;
            setState(() {
              _generatedUsername = username;
              _showCelebration = true;
            });
            await Future.delayed(const Duration(seconds: 3));
            if (mounted) {
              context.go('/home');
            }
          }
        }
      } else {
        // Returning user: biometric -> login
        success = await authNotifier.login();

        if (success && mounted) {
          context.go('/home');
        }
      }

      if (!success && mounted) {
        final error = ref.read(authStateProvider).error;
        ToastService.showError(error ?? AppConstants.errorAuth);
      }
    } finally {
      _registering = false;
    }
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
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: Theme.of(context).brightness == Brightness.dark
                    ? [
                        Theme.of(context).scaffoldBackgroundColor,
                        Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                        Theme.of(context).scaffoldBackgroundColor,
                      ]
                    : const [Color(0xFFFFF8F0), Color(0xFFFFF0F5), Color(0xFFFFF8F0)],
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
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: _showCelebration
                          ? _buildCelebrationContent()
                          : _buildAuthContent(isFirstTime, authState.isLoading),
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

  Widget _buildAuthContent(bool isFirstTime, bool isLoading) {
    final primary = Theme.of(context).colorScheme.primary;
    final onSurfaceLight =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);
    final username = ref.watch(authStateProvider).username;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          isFirstTime
              ? 'Bienvenida!'
              : 'Hola de nuevo${username != null ? ', $username' : ''}!',
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
          isFirstTime
              ? 'Usa tu huella o rostro para crear tu cuenta'
              : 'Toca para autenticarte',
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
            'Tu nombre es',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _generatedUsername ?? '',
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
