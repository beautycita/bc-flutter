import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:beautycita_core/supabase.dart';
import 'package:beautycita_core/theme.dart';

import '../../config/router.dart';
import '../../providers/auth_provider.dart';
import 'auth_layout.dart';

/// QR auth page — generates a session code, displays it, and polls for
/// authorization from the mobile app.
///
/// Since `qr_flutter` is not in the web pubspec, the code is displayed as
/// large text for manual entry.
class QrPage extends ConsumerStatefulWidget {
  const QrPage({super.key});

  @override
  ConsumerState<QrPage> createState() => _QrPageState();
}

class _QrPageState extends ConsumerState<QrPage> {
  String? _authCode;
  bool _isLoading = true;
  bool _isExpired = false;
  String? _error;
  Timer? _pollTimer;
  Timer? _expiryTimer;
  int _expiryCountdown = 300; // 5 minutes

  @override
  void initState() {
    super.initState();
    _createSession();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _expiryTimer?.cancel();
    super.dispose();
  }

  Future<void> _createSession() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _isExpired = false;
      _expiryCountdown = 300;
    });

    _pollTimer?.cancel();
    _expiryTimer?.cancel();

    if (!BCSupabase.isInitialized) {
      setState(() {
        _error = 'Servicio no disponible.';
        _isLoading = false;
      });
      return;
    }

    try {
      final response = await BCSupabase.client.functions.invoke(
        'qr-auth',
        body: {'action': 'create'},
      );
      final data = response.data as Map<String, dynamic>?;
      final code = data?['code'] as String?;

      if (code == null) {
        setState(() {
          _error = 'No se pudo generar el codigo.';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _authCode = code;
        _isLoading = false;
      });

      _startPolling(code);
      _startExpiryTimer();
    } catch (e) {
      setState(() {
        _error = 'Error al crear sesion QR.';
        _isLoading = false;
      });
    }
  }

  void _startPolling(String code) {
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!mounted || _isExpired) {
        timer.cancel();
        return;
      }
      try {
        final response = await BCSupabase.client.functions.invoke(
          'qr-auth',
          body: {'action': 'check', 'code': code},
        );
        final data = response.data as Map<String, dynamic>?;
        if (data?['authorized'] == true) {
          timer.cancel();
          _expiryTimer?.cancel();
          if (!mounted) return;
          // Navigate by role
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
      } catch (_) {
        // Silently retry on next tick
      }
    });
  }

  void _startExpiryTimer() {
    _expiryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _expiryCountdown--;
        if (_expiryCountdown <= 0) {
          _isExpired = true;
          timer.cancel();
          _pollTimer?.cancel();
        }
      });
    });
  }

  String _formatCountdown(int seconds) {
    final min = seconds ~/ 60;
    final sec = seconds % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AuthLayout(
      formContent: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Back button ──────────────────────────────────────────────────
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => context.go(WebRoutes.auth),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Volver'),
            ),
          ),
          const SizedBox(height: BCSpacing.md),

          // ── Heading ──────────────────────────────────────────────────────
          Text(
            'Iniciar con QR',
            style: theme.textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: BCSpacing.sm),
          Text(
            'Escanea este codigo con la app de BeautyCita',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: BCSpacing.xl),

          // ── Code display ─────────────────────────────────────────────────
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(BCSpacing.xl),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_error != null)
            Column(
              children: [
                Icon(Icons.error_outline, size: 48,
                    color: theme.colorScheme.error),
                const SizedBox(height: BCSpacing.md),
                Text(
                  _error!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: BCSpacing.md),
                ElevatedButton(
                  onPressed: _createSession,
                  child: const Text('Reintentar'),
                ),
              ],
            )
          else if (_isExpired)
            Column(
              children: [
                Icon(Icons.timer_off_outlined, size: 48,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                const SizedBox(height: BCSpacing.md),
                Text(
                  'El codigo expiro.',
                  style: theme.textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: BCSpacing.md),
                ElevatedButton(
                  onPressed: _createSession,
                  child: const Text('Generar nuevo codigo'),
                ),
              ],
            )
          else ...[
            // Auth code as large text (no qr_flutter available)
            Container(
              padding: const EdgeInsets.symmetric(
                vertical: BCSpacing.xl,
                horizontal: BCSpacing.lg,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(BCSpacing.radiusMd),
                border: Border.all(color: theme.colorScheme.outline),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.qr_code_2,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: BCSpacing.md),
                  SelectableText(
                    _authCode ?? '',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700,
                      letterSpacing: 8,
                      color: theme.colorScheme.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: BCSpacing.sm),
                  Text(
                    'Ingresa este codigo en la app',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: BCSpacing.md),

            // ── Expiry countdown ─────────────────────────────────────────
            Text(
              'Expira en ${_formatCountdown(_expiryCountdown)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: _expiryCountdown < 60
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ],

          const SizedBox(height: BCSpacing.xl),

          // ── Email login link ─────────────────────────────────────────────
          TextButton(
            onPressed: () => context.go(WebRoutes.auth),
            child: const Text('O inicia sesion con email'),
          ),
        ],
      ),
    );
  }
}
