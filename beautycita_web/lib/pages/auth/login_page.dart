import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:beautycita_core/theme.dart';

import '../../config/router.dart';
import '../../providers/auth_provider.dart';
import 'auth_layout.dart';

/// Login page — email/password + Google/Apple OAuth.
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

  Future<void> _navigateByRole(AuthNotifier notifier) async {
    final role = await notifier.getUserRole();
    if (!mounted) return;
    switch (role) {
      case 'admin' || 'superadmin':
        context.go(WebRoutes.admin);
      case 'stylist':
      case 'business':
        context.go(WebRoutes.negocio);
      default:
        context.go(WebRoutes.reservar);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);

    // Show error snackbar
    ref.listen<AuthState>(authProvider, (prev, next) {
      if (next.errorMessage != null && next.errorMessage != prev?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: theme.colorScheme.error,
          ),
        );
      }
    });

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
                      padding:
                          const EdgeInsets.symmetric(horizontal: BCSpacing.md),
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
}
