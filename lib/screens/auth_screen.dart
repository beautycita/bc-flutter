import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../config/theme.dart';
import '../config/constants.dart';

/// Biometric authentication screen for BeautyCita
/// Handles both first-time registration and returning user login
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

    // Pulse animation for fingerprint icon
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Celebration animation for username reveal
    _celebrationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.elasticOut),
    );

    // Check registration status on mount
    Future.microtask(() => ref.read(authStateProvider.notifier).checkRegistration());
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _handleBiometricTap() async {
    final authNotifier = ref.read(authStateProvider.notifier);
    final authState = ref.read(authStateProvider);

    bool success = false;

    // Determine if this is registration or login
    if (authState.username == null) {
      // First-time registration
      success = await authNotifier.register();

      if (success && mounted) {
        final newUsername = ref.read(authStateProvider).username;
        setState(() {
          _generatedUsername = newUsername;
          _showCelebration = true;
        });

        // Auto-navigate after showing celebration
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            context.go('/home');
          }
        });
      }
    } else {
      // Returning user login
      success = await authNotifier.login();

      if (success && mounted) {
        // Navigate immediately on successful login
        context.go('/home');
      }
    }

    // Show error if authentication failed
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
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(BeautyCitaTheme.spaceLG),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BeautyCitaTheme.radiusMedium),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final isFirstTime = authState.username == null;

    // Listen to auth state changes for navigation
    ref.listen<AuthState>(authStateProvider, (previous, next) {
      if (next.isAuthenticated && !_showCelebration && mounted) {
        context.go('/home');
      }
    });

    return Scaffold(
      backgroundColor: BeautyCitaTheme.surfaceCream,
      body: SafeArea(
        child: Column(
          children: [
            // Top 40% - spacer for stretch zone
            const Spacer(flex: 2),

            // Bottom 60% - thumb zone content
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.screenPaddingHorizontal,
                ),
                child: _showCelebration
                    ? _buildCelebrationContent()
                    : _buildAuthContent(isFirstTime, authState.isLoading),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthContent(bool isFirstTime, bool isLoading) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Welcome text
        Text(
          isFirstTime ? '¡Bienvenida!' : '¡Hola de nuevo${ref.watch(authStateProvider).username != null ? ', ${ref.watch(authStateProvider).username}' : ''}!',
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                color: BeautyCitaTheme.primaryRose,
                fontSize: 36,
              ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: BeautyCitaTheme.spaceMD),

        // Subtitle
        Text(
          isFirstTime
              ? 'Usa tu huella o rostro para crear tu cuenta'
              : 'Toca para autenticarte',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: BeautyCitaTheme.textLight,
                fontSize: 16,
              ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: BeautyCitaTheme.spaceXXL * 1.5),

        // Fingerprint icon with pulse animation
        GestureDetector(
          onTap: isLoading ? null : _handleBiometricTap,
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: isLoading ? 1.0 : _pulseAnimation.value,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    color: BeautyCitaTheme.primaryRose.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isLoading
                        ? const CircularProgressIndicator(
                            color: BeautyCitaTheme.primaryRose,
                            strokeWidth: 3,
                          )
                        : Icon(
                            Icons.fingerprint,
                            size: 120,
                            color: BeautyCitaTheme.primaryRose,
                          ),
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: BeautyCitaTheme.spaceXL),

        // Hint text
        if (!isLoading)
          Text(
            'Toca la huella para continuar',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: BeautyCitaTheme.textLight,
                  fontSize: 14,
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
          // Success icon
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: BeautyCitaTheme.secondaryGold.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.celebration,
              size: 80,
              color: BeautyCitaTheme.secondaryGold,
            ),
          ),

          const SizedBox(height: BeautyCitaTheme.spaceXL),

          // Generated username message
          Text(
            '¡Tu nombre es',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: BeautyCitaTheme.textDark,
                ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: BeautyCitaTheme.spaceMD),

          Text(
            _generatedUsername ?? '',
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: BeautyCitaTheme.primaryRose,
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: BeautyCitaTheme.spaceMD),

          Text(
            '!',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: BeautyCitaTheme.textDark,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
