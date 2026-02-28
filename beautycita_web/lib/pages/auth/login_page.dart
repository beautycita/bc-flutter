import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:beautycita_core/supabase.dart';
import 'package:beautycita_core/theme.dart';

import '../../config/router.dart';
import '../../providers/auth_provider.dart';
import 'auth_layout.dart';

/// Login page — email/password + Google/Apple OAuth.
/// Handles offline/error states when Supabase is unreachable.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _retrying = false;
  bool _initializing = true;

  @override
  void initState() {
    super.initState();
    _waitForInit();
  }

  Future<void> _waitForInit() async {
    if (BCSupabase.isInitialized) {
      if (mounted) setState(() => _initializing = false);
      return;
    }
    await BCSupabase.initialize();
    if (!mounted) return;
    setState(() => _initializing = false);
    // If a session was restored, navigate to the right place
    if (BCSupabase.isAuthenticated) {
      _navigateByRole(ref.read(authProvider.notifier));
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    final notifier = ref.read(authProvider.notifier);
    final success = await notifier.signInWithEmail(
      _emailController.text.trim(),
      _passwordController.text,
    );
    if (success && mounted) {
      await _navigateByRole(notifier);
    }
  }

  Future<void> _handleRetry() async {
    setState(() {
      _retrying = true;
      _initializing = true;
    });
    await BCSupabase.initialize(force: true);
    if (!mounted) return;
    setState(() {
      _retrying = false;
      _initializing = false;
    });
    if (BCSupabase.isAuthenticated) {
      _navigateByRole(ref.read(authProvider.notifier));
    }
  }

  Future<void> _navigateByRole(AuthNotifier notifier) async {
    if (!mounted) return;
    final role = await notifier.getUserRole();
    if (!mounted) return;
    context.go(routeForRole(role));
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);

    // Show error snackbar
    ref.listen<AuthState>(authProvider, (prev, next) {
      if (next.errorMessage != null &&
          next.errorMessage != prev?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: theme.colorScheme.error,
          ),
        );
      }
    });

    // Still waiting for Supabase init — show loading
    if (_initializing) {
      return AuthLayout(
        formContent: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: BCSpacing.md),
            Text(
              'Conectando...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      );
    }

    // If Supabase failed to initialize, show error state with retry
    if (BCSupabase.initFailed) {
      return AuthLayout(
        formContent: _buildOfflineError(theme),
      );
    }

    return AuthLayout(
      formContent: Stack(
        children: [
          Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Heading ────────────────────────────────────────────────
                Text(
                  'Iniciar sesion',
                  style: theme.textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: BCSpacing.xl),

                // ── Email ──────────────────────────────────────────────────
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Ingresa tu email';
                    }
                    if (!v.contains('@') || !v.contains('.')) {
                      return 'Email invalido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: BCSpacing.md),

                // ── Password ───────────────────────────────────────────────
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  autofillHints: const [AutofillHints.password],
                  decoration: InputDecoration(
                    labelText: 'Contrasena',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Ingresa tu contrasena';
                    return null;
                  },
                  onFieldSubmitted: (_) => _handleLogin(),
                ),
                const SizedBox(height: BCSpacing.lg),

                // ── Sign in button ─────────────────────────────────────────
                ElevatedButton(
                  onPressed: authState.isLoading ? null : _handleLogin,
                  child: const Text('Entrar'),
                ),
                const SizedBox(height: BCSpacing.lg),

                // ── Divider ────────────────────────────────────────────────
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: BCSpacing.md),
                      child: Text(
                        'o continua con',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: BCSpacing.md),

                // ── Google button ──────────────────────────────────────────
                OutlinedButton.icon(
                  onPressed: authState.isLoading
                      ? null
                      : () =>
                          ref.read(authProvider.notifier).signInWithGoogle(),
                  icon: const Icon(Icons.g_mobiledata, size: 24),
                  label: const Text('Google'),
                ),
                const SizedBox(height: BCSpacing.sm),

                // ── Apple button ───────────────────────────────────────────
                OutlinedButton.icon(
                  onPressed: authState.isLoading
                      ? null
                      : () =>
                          ref.read(authProvider.notifier).signInWithApple(),
                  icon: const Icon(Icons.apple, size: 22),
                  label: const Text('Apple'),
                ),
                const SizedBox(height: BCSpacing.lg),

                // ── Forgot password ────────────────────────────────────────
                TextButton(
                  onPressed: () => context.go(WebRoutes.forgot),
                  child: const Text('Olvidaste tu contrasena?'),
                ),

                // ── Register link ──────────────────────────────────────────
                TextButton(
                  onPressed: () => context.go(WebRoutes.register),
                  child: const Text('No tienes cuenta? Registrate'),
                ),

                // ── QR login link ──────────────────────────────────────────
                TextButton(
                  onPressed: () => context.go(WebRoutes.qr),
                  child: const Text('Iniciar con QR'),
                ),
              ],
            ),
          ),

          // ── Loading overlay ──────────────────────────────────────────────
          if (authState.isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.white.withValues(alpha: 0.6),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  /// Error UI when Supabase initialization failed (offline, timed out, etc.)
  Widget _buildOfflineError(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          Icons.cloud_off_outlined,
          size: 64,
          color: theme.colorScheme.error.withValues(alpha: 0.7),
        ),
        const SizedBox(height: BCSpacing.lg),
        Text(
          'No se pudo conectar al servidor',
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: BCSpacing.sm),
        Text(
          BCSupabase.initError ?? 'Error desconocido',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: BCSpacing.xl),
        ElevatedButton.icon(
          onPressed: _retrying ? null : _handleRetry,
          icon: _retrying
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh),
          label: Text(_retrying ? 'Conectando...' : 'Reintentar'),
        ),
        const SizedBox(height: BCSpacing.lg),
        TextButton(
          onPressed: () => context.go(WebRoutes.home),
          child: const Text('Volver al inicio'),
        ),
      ],
    );
  }
}
