import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../config/theme.dart';
import '../config/constants.dart';
import '../services/supabase_client.dart';

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

    Future.microtask(
        () => ref.read(authStateProvider.notifier).checkRegistration());
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
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
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(BeautyCitaTheme.radiusLarge),
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
                      'Inicio con Email',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: BeautyCitaTheme.textDark,
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
                      onSubmitted: (_) async {
                        if (emailCtl.text.trim().isEmpty ||
                            passCtl.text.trim().isEmpty) return;
                        setSheetState(() {
                          loading = true;
                          errorText = null;
                        });
                        final ok = await ref
                            .read(authStateProvider.notifier)
                            .signInWithEmail(
                                emailCtl.text.trim(), passCtl.text.trim());
                        if (ok && mounted) {
                          Navigator.of(ctx).pop();
                          context.go('/home');
                        } else {
                          setSheetState(() {
                            loading = false;
                            errorText =
                                ref.read(authStateProvider).error ??
                                    'Error al iniciar sesion';
                          });
                        }
                      },
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
                                color: BeautyCitaTheme.textLight,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: loading
                                ? null
                                : () async {
                                    if (emailCtl.text.trim().isEmpty ||
                                        passCtl.text.trim().isEmpty) return;
                                    setSheetState(() {
                                      loading = true;
                                      errorText = null;
                                    });
                                    final ok = await ref
                                        .read(authStateProvider.notifier)
                                        .signInWithEmail(emailCtl.text.trim(),
                                            passCtl.text.trim());
                                    if (ok && mounted) {
                                      Navigator.of(ctx).pop();
                                      context.go('/home');
                                    } else {
                                      setSheetState(() {
                                        loading = false;
                                        errorText = ref
                                                .read(authStateProvider)
                                                .error ??
                                            'Error al iniciar sesion';
                                      });
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: BeautyCitaTheme.primaryRose,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(BeautyCitaTheme.radiusSmall),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
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
                                    'Entrar',
                                    style: GoogleFonts.nunito(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(BeautyCitaTheme.spaceLG),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final isFirstTime = authState.username == null;

    ref.listen<AuthState>(authStateProvider, (previous, next) {
      if (next.isAuthenticated && !_showCelebration && mounted) {
        context.go('/home');
      }
    });

    return Scaffold(
      body: SizedBox.expand(
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
                    color:
                        BeautyCitaTheme.primaryRose.withValues(alpha: 0.04),
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
                    color:
                        BeautyCitaTheme.secondaryGold.withValues(alpha: 0.05),
                  ),
                ),
              ),

              // Content
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: _showCelebration
                      ? _buildCelebrationContent()
                      : _buildAuthContent(
                          isFirstTime, authState.isLoading),
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildAuthContent(bool isFirstTime, bool isLoading) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Welcome text (long-press to reveal email login)
        GestureDetector(
          onLongPress: _showEmailLogin,
          child: Text(
            isFirstTime
                ? 'Bienvenida!'
                : 'Hola de nuevo${ref.watch(authStateProvider).username != null ? ', ${ref.watch(authStateProvider).username}' : ''}!',
            style: GoogleFonts.poppins(
              fontSize: 38,
              fontWeight: FontWeight.w700,
              color: BeautyCitaTheme.primaryRose,
              height: 1.1,
            ),
            textAlign: TextAlign.center,
          ),
        ),

        const SizedBox(height: 12),

        Text(
          isFirstTime
              ? 'Usa tu huella o rostro para crear tu cuenta'
              : 'Toca para autenticarte',
          style: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: BeautyCitaTheme.textLight,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 36),

        // Fingerprint button
        GestureDetector(
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
                        BeautyCitaTheme.primaryRose.withValues(alpha: 0.1),
                        BeautyCitaTheme.primaryRose.withValues(alpha: 0.06),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: BeautyCitaTheme.primaryRose.withValues(alpha: 0.15),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: BeautyCitaTheme.primaryRose.withValues(alpha: 0.12),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Center(
                    child: isLoading
                        ? const CircularProgressIndicator(
                            color: BeautyCitaTheme.primaryRose,
                            strokeWidth: 3,
                          )
                        : const Icon(
                            Icons.fingerprint,
                            size: 56,
                            color: BeautyCitaTheme.primaryRose,
                          ),
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 28),

        if (!isLoading)
          Text(
            'Toca la huella para continuar',
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: BeautyCitaTheme.textLight,
            ),
            textAlign: TextAlign.center,
          ),
      ],
    );
  }

  Widget _buildCelebrationContent() {
    return ScaleTransition(
      scale: _celebrationAnimation,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Celebration emoji
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  BeautyCitaTheme.secondaryGold.withValues(alpha: 0.15),
                  BeautyCitaTheme.secondaryGold.withValues(alpha: 0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Center(
              child: Text(
                '\u{1F389}', // party popper
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
              color: BeautyCitaTheme.textDark,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 8),

          Text(
            _generatedUsername ?? '',
            style: GoogleFonts.poppins(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              color: BeautyCitaTheme.primaryRose,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
