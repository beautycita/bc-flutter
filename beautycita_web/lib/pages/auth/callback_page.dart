import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:beautycita_core/supabase.dart';
import 'package:beautycita_core/theme.dart';

import '../../config/router.dart';
import '../../providers/auth_provider.dart';

/// OAuth callback page — processes the redirect after Google/Apple sign-in.
///
/// Supabase handles token exchange via the URL hash. This page waits for
/// the auth state to settle, then navigates by role.
class CallbackPage extends ConsumerStatefulWidget {
  const CallbackPage({super.key});

  @override
  ConsumerState<CallbackPage> createState() => _CallbackPageState();
}

class _CallbackPageState extends ConsumerState<CallbackPage> {
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _processCallback();
  }

  Future<void> _processCallback() async {
    // Give Supabase a moment to process the URL hash tokens
    await Future<void>.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    if (!BCSupabase.isInitialized) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Servicio no disponible.';
      });
      return;
    }

    final user = BCSupabase.client.auth.currentUser;
    if (user == null) {
      // Wait a bit more for the auth state change
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!mounted) return;

      final retryUser = BCSupabase.client.auth.currentUser;
      if (retryUser == null) {
        setState(() {
          _hasError = true;
          _errorMessage = 'No se pudo completar la autenticacion.';
        });
        return;
      }
    }

    // Auth successful — navigate by role
    final notifier = ref.read(authProvider.notifier);
    final role = await notifier.getUserRole();
    if (!mounted) return;

    switch (role) {
      case 'admin':
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
    final theme = Theme.of(context);

    if (_hasError) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: BCSpacing.md),
              Text(
                _errorMessage ?? 'Error de autenticacion',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: BCSpacing.lg),
              ElevatedButton(
                onPressed: () => context.go(WebRoutes.auth),
                child: const Text('Intentar de nuevo'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: BCSpacing.lg),
            Text(
              'Autenticando...',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
