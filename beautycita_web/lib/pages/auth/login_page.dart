import 'package:flutter/material.dart';

/// Desktop split-layout login placeholder.
///
/// Left half: brand panel (deep rose background).
/// Right half: login form placeholder.
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  static const _brandColor = Color(0xFF660033);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Row(
        children: [
          // ── Left: brand panel ───────────────────────────────────────────
          Expanded(
            child: Container(
              color: _brandColor,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'BeautyCita',
                      style: theme.textTheme.displayMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Tu agente inteligente de belleza',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Right: login form placeholder ───────────────────────────────
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 48,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Iniciar sesion',
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Login form coming soon',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
