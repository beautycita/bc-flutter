import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:beautycita_core/supabase.dart';
import 'package:beautycita_core/theme.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;
import 'package:url_launcher/url_launcher.dart';

import '../../config/router.dart';
import '../../providers/auth_provider.dart';
import 'auth_layout.dart';

/// QR auth page — generates a session code, displays a scannable QR code,
/// listens for Realtime Broadcast from mobile, and polls as fallback.
class QrPage extends ConsumerStatefulWidget {
  const QrPage({super.key});

  @override
  ConsumerState<QrPage> createState() => _QrPageState();
}

class _QrPageState extends ConsumerState<QrPage> {
  String? _authCode;
  String? _sessionId;
  String? _verifyToken;
  bool _isLoading = true;
  bool _isExpired = false;
  bool _isSigningIn = false;
  String? _error;
  Timer? _pollTimer;
  Timer? _expiryTimer;
  RealtimeChannel? _broadcastChannel;
  int _expiryCountdown = 300; // 5 minutes

  static const _apkUrl =
      'https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/apk/beautycita.apk';

  @override
  void initState() {
    super.initState();
    _createSession();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _expiryTimer?.cancel();
    _cleanupBroadcast();
    super.dispose();
  }

  void _cleanupBroadcast() {
    if (_broadcastChannel != null) {
      BCSupabase.client.removeChannel(_broadcastChannel!);
      _broadcastChannel = null;
    }
  }

  Future<void> _createSession() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _isExpired = false;
      _isSigningIn = false;
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
      final sessionId = data?['session_id'] as String?;
      final verifyToken = data?['verify_token'] as String?;

      if (code == null) {
        setState(() {
          _error = 'No se pudo generar el codigo.';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _authCode = code;
        _sessionId = sessionId;
        _verifyToken = verifyToken;
        _isLoading = false;
      });

      _subscribeBroadcast(sessionId!);
      _startPolling(code);
      _startExpiryTimer();
    } catch (e) {
      setState(() {
        _error = 'Error al crear sesion QR.';
        _isLoading = false;
      });
    }
  }

  /// Subscribe to Realtime Broadcast for instant notification from mobile.
  void _subscribeBroadcast(String sessionId) {
    _cleanupBroadcast();
    _broadcastChannel = BCSupabase.client.channel('qr_auth_$sessionId');
    _broadcastChannel!
        .onBroadcast(
          event: 'session_authorized',
          callback: (payload) {
            if (!mounted || _isExpired || _isSigningIn) return;
            _pollTimer?.cancel();
            _expiryTimer?.cancel();
            _completeSignIn(sessionId);
          },
        )
        .subscribe();
  }

  void _startPolling(String code) {
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!mounted || _isExpired || _isSigningIn) {
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
          final sessionId = data?['session_id'] as String? ?? _sessionId;
          if (sessionId != null && mounted) {
            await _completeSignIn(sessionId);
          }
        }
      } catch (_) {
        // Silently retry on next tick
      }
    });
  }

  /// Call verify to get the OTP, then sign in with it.
  Future<void> _completeSignIn(String sessionId) async {
    if (!mounted) return;
    setState(() => _isSigningIn = true);

    try {
      final response = await BCSupabase.client.functions.invoke(
        'qr-auth',
        body: {'action': 'verify', 'session_id': sessionId, 'verify_token': _verifyToken},
      );
      final data = response.data as Map<String, dynamic>?;
      final accessToken = data?['access_token'] as String?;
      final refreshToken = data?['refresh_token'] as String?;

      if (accessToken == null || refreshToken == null) {
        setState(() {
          _error = data?['error'] as String? ?? 'Error al verificar sesion.';
          _isSigningIn = false;
        });
        return;
      }

      // Set the session directly using server-verified tokens
      await BCSupabase.client.auth.setSession(refreshToken);

      if (!mounted) return;

      // Update auth provider state with the signed-in user
      final user = BCSupabase.client.auth.currentUser;
      if (user != null) {
        ref.read(authProvider.notifier).setUser(user);
      }

      // Navigate by role
      final role = await ref.read(authProvider.notifier).getUserRole();
      if (!mounted) return;
      context.go(routeForRole(role));
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error al iniciar sesion: $e';
          _isSigningIn = false;
        });
      }
    }
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

  /// Build the QR URI for the mobile scanner
  String get _qrData {
    final code = _authCode ?? '';
    final session = _sessionId ?? '';
    return 'beautycita://auth/qr?code=$code&session=$session';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return AuthLayout(
      formContent: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Back button
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => context.go(WebRoutes.auth),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Volver'),
            ),
          ),
          const SizedBox(height: BCSpacing.md),

          // ── Heading
          Text(
            'Iniciar con QR',
            style: theme.textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: BCSpacing.lg),

          // ── Step-by-step instructions
          Container(
            padding: const EdgeInsets.all(BCSpacing.md),
            decoration: BoxDecoration(
              color: colors.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(BCSpacing.radiusSm),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StepRow(number: '1', text: 'Abre la app de BeautyCita en tu celular'),
                const SizedBox(height: BCSpacing.xs),
                _StepRow(number: '2', text: 'Ve a Ajustes > Vincular con la Web'),
                const SizedBox(height: BCSpacing.xs),
                _StepRow(number: '3', text: 'Escanea el QR o ingresa el codigo'),
              ],
            ),
          ),
          const SizedBox(height: BCSpacing.lg),

          // ── Content
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(BCSpacing.xl),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_isSigningIn)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(BCSpacing.xl),
                child: Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: BCSpacing.md),
                    Text(
                      'Iniciando sesion...',
                      style: theme.textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            )
          else if (_error != null)
            Column(
              children: [
                Icon(Icons.error_outline, size: 48, color: colors.error),
                const SizedBox(height: BCSpacing.md),
                Text(
                  _error!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.error,
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
                Icon(Icons.timer_off_outlined,
                    size: 48,
                    color: colors.onSurface.withValues(alpha: 0.4)),
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
            // QR code + manual code display
            Container(
              padding: const EdgeInsets.symmetric(
                vertical: BCSpacing.lg,
                horizontal: BCSpacing.lg,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(BCSpacing.radiusMd),
                border: Border.all(color: colors.outline),
              ),
              child: Column(
                children: [
                  // QR code image
                  QrImageView(
                    data: _qrData,
                    version: QrVersions.auto,
                    size: 240,
                    eyeStyle: QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: colors.primary,
                    ),
                    dataModuleStyle: QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: colors.onSurface,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: BCSpacing.lg),
                  // Divider with "o ingresa el codigo"
                  Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: colors.onSurface.withValues(alpha: 0.2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: BCSpacing.sm),
                        child: Text(
                          'o ingresa el codigo',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: colors.onSurface.withValues(alpha: 0.2),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: BCSpacing.md),
                  // Auth code as text
                  SelectableText(
                    _authCode ?? '',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700,
                      letterSpacing: 6,
                      color: colors.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: BCSpacing.md),

            // ── Expiry countdown
            Text(
              'Expira en ${_formatCountdown(_expiryCountdown)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: _expiryCountdown < 60
                    ? colors.error
                    : colors.onSurface.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ],

          const SizedBox(height: BCSpacing.lg),

          // ── Download app link
          TextButton.icon(
            onPressed: () => launchUrl(Uri.parse(_apkUrl)),
            icon: Icon(Icons.download_rounded, size: 18, color: colors.primary),
            label: Text(
              'No tienes la app? Descargala aqui',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.primary,
              ),
            ),
          ),

          const SizedBox(height: BCSpacing.sm),

          // ── Email login link
          TextButton(
            onPressed: () => context.go(WebRoutes.auth),
            child: const Text('O inicia sesion con email'),
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.number, required this.text});
  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: colors.primary,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: BCSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
