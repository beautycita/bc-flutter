import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:beautycita_core/theme.dart';

import '../../config/router.dart';
import '../../providers/auth_provider.dart';
import 'auth_layout.dart';

/// Password reset page — sends a reset link to the user's email.
class ForgotPage extends ConsumerStatefulWidget {
  const ForgotPage({super.key});

  @override
  ConsumerState<ForgotPage> createState() => _ForgotPageState();
}

class _ForgotPageState extends ConsumerState<ForgotPage> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleReset() async {
    if (!_formKey.currentState!.validate()) return;
    final notifier = ref.read(authProvider.notifier);
    final success =
        await notifier.resetPassword(_emailController.text.trim());
    if (success && mounted) {
      setState(() => _emailSent = true);
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
      formContent: _emailSent ? _successContent(theme) : _formContent(theme, authState),
    );
  }

  Widget _formContent(ThemeData theme, AuthState authState) {
    return Stack(
      children: [
        Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Back button ──────────────────────────────────────────────
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => context.go(WebRoutes.auth),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Volver'),
                ),
              ),
              const SizedBox(height: BCSpacing.md),

              // ── Heading ──────────────────────────────────────────────────
              Text(
                'Recuperar contrasena',
                style: theme.textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: BCSpacing.sm),
              Text(
                'Ingresa tu email y te enviaremos un enlace para restablecer tu contrasena.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: BCSpacing.xl),

              // ── Email ────────────────────────────────────────────────────
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
                onFieldSubmitted: (_) => _handleReset(),
              ),
              const SizedBox(height: BCSpacing.lg),

              // ── Send button ──────────────────────────────────────────────
              ElevatedButton(
                onPressed: authState.isLoading ? null : _handleReset,
                child: const Text('Enviar enlace'),
              ),
              const SizedBox(height: BCSpacing.md),

              // ── Login link ───────────────────────────────────────────────
              TextButton(
                onPressed: () => context.go(WebRoutes.auth),
                child: const Text('Volver al inicio de sesion'),
              ),
            ],
          ),
        ),

        // ── Loading overlay ────────────────────────────────────────────────
        if (authState.isLoading)
          Positioned.fill(
            child: Container(
              color: Colors.white.withValues(alpha: 0.6),
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }

  Widget _successContent(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.check_circle_outline,
          size: 72,
          color: roseGoldPalette.success,
        ),
        const SizedBox(height: BCSpacing.lg),
        Text(
          'Revisa tu email',
          style: theme.textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: BCSpacing.md),
        Text(
          'Enviamos un enlace a ${_emailController.text.trim()} para restablecer tu contrasena.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: BCSpacing.xl),
        ElevatedButton(
          onPressed: () => context.go(WebRoutes.auth),
          child: const Text('Volver al inicio de sesion'),
        ),
      ],
    );
  }
}
