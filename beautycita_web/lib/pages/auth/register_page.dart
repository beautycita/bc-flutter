import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:beautycita_core/theme.dart';

import '../../config/router.dart';
import '../../providers/auth_provider.dart';
import 'auth_layout.dart';

/// Registration page — name, email, password + OAuth.
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _acceptedTerms = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Acepta los terminos para continuar.')),
      );
      return;
    }
    final notifier = ref.read(authProvider.notifier);
    final success = await notifier.signUpWithEmail(
      _emailController.text.trim(),
      _passwordController.text,
      _nameController.text.trim(),
    );
    if (success && mounted) {
      // Navigate to verify phone after registration
      context.go(WebRoutes.verify);
    }
  }

  /// Simple password strength: 0 = weak, 1 = medium, 2 = strong.
  int _passwordStrength(String password) {
    if (password.length < 8) return 0;
    int score = 0;
    if (password.length >= 10) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) score++;
    if (score <= 1) return 0;
    if (score <= 2) return 1;
    return 2;
  }

  Color _strengthColor(int strength) {
    switch (strength) {
      case 0:
        return Colors.red;
      case 1:
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  String _strengthLabel(int strength) {
    switch (strength) {
      case 0:
        return 'Debil';
      case 1:
        return 'Media';
      default:
        return 'Fuerte';
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);

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
                  'Crear cuenta',
                  style: theme.textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: BCSpacing.xl),

                // ── Name ───────────────────────────────────────────────────
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Ingresa tu nombre';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: BCSpacing.md),

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
                  autofillHints: const [AutofillHints.newPassword],
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
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Ingresa una contrasena';
                    if (v.length < 8) {
                      return 'Minimo 8 caracteres';
                    }
                    return null;
                  },
                ),

                // ── Strength indicator ─────────────────────────────────────
                if (_passwordController.text.isNotEmpty) ...[
                  const SizedBox(height: BCSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: (_passwordStrength(
                                      _passwordController.text) +
                                  1) /
                              3,
                          backgroundColor: theme.colorScheme.outlineVariant,
                          color: _strengthColor(
                              _passwordStrength(_passwordController.text)),
                          minHeight: 4,
                        ),
                      ),
                      const SizedBox(width: BCSpacing.sm),
                      Text(
                        _strengthLabel(
                            _passwordStrength(_passwordController.text)),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _strengthColor(
                              _passwordStrength(_passwordController.text)),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: BCSpacing.md),

                // ── Terms checkbox ─────────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _acceptedTerms,
                      onChanged: (v) =>
                          setState(() => _acceptedTerms = v ?? false),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _acceptedTerms = !_acceptedTerms),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            'Acepto los terminos y condiciones de uso',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: BCSpacing.lg),

                // ── Register button ────────────────────────────────────────
                ElevatedButton(
                  onPressed: authState.isLoading ? null : _handleRegister,
                  child: const Text('Crear cuenta'),
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

                // ── Google ─────────────────────────────────────────────────
                OutlinedButton.icon(
                  onPressed: authState.isLoading
                      ? null
                      : () =>
                          ref.read(authProvider.notifier).signInWithGoogle(),
                  icon: const Icon(Icons.g_mobiledata, size: 24),
                  label: const Text('Google'),
                ),
                const SizedBox(height: BCSpacing.sm),

                // ── Apple ──────────────────────────────────────────────────
                OutlinedButton.icon(
                  onPressed: authState.isLoading
                      ? null
                      : () =>
                          ref.read(authProvider.notifier).signInWithApple(),
                  icon: const Icon(Icons.apple, size: 22),
                  label: const Text('Apple'),
                ),
                const SizedBox(height: BCSpacing.lg),

                // ── Login link ─────────────────────────────────────────────
                TextButton(
                  onPressed: () => context.go(WebRoutes.auth),
                  child: const Text('Ya tienes cuenta? Inicia sesion'),
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
