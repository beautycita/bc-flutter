import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:beautycita_core/supabase.dart';
import 'package:beautycita_core/theme.dart';

import '../../config/router.dart';
import '../../providers/auth_provider.dart';
import 'auth_layout.dart';

/// Phone verification page — sends OTP via edge function, then verifies.
class VerifyPage extends ConsumerStatefulWidget {
  const VerifyPage({super.key});

  @override
  ConsumerState<VerifyPage> createState() => _VerifyPageState();
}

class _VerifyPageState extends ConsumerState<VerifyPage> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _codeSent = false;
  bool _isLoading = false;
  String? _error;
  int _resendCountdown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _resendCountdown = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _resendCountdown--;
        if (_resendCountdown <= 0) t.cancel();
      });
    });
  }

  Future<void> _sendCode() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty || phone.length < 10) {
      setState(() => _error = 'Ingresa un numero valido de 10 digitos.');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      if (!BCSupabase.isInitialized) {
        setState(() {
          _error = 'Servicio no disponible.';
          _isLoading = false;
        });
        return;
      }
      await BCSupabase.client.functions.invoke(
        'phone-verify',
        body: {
          'action': 'send-code',
          'phone': '+52$phone',
        },
      );
      setState(() {
        _codeSent = true;
        _isLoading = false;
      });
      _startResendTimer();
    } catch (e) {
      setState(() {
        _error = 'No se pudo enviar el codigo. Intenta de nuevo.';
        _isLoading = false;
      });
    }
  }

  Future<void> _verifyCode() async {
    final code = _otpController.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Ingresa el codigo de 6 digitos.');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      if (!BCSupabase.isInitialized) {
        setState(() {
          _error = 'Servicio no disponible.';
          _isLoading = false;
        });
        return;
      }
      final response = await BCSupabase.client.functions.invoke(
        'phone-verify',
        body: {
          'action': 'verify-code',
          'phone': '+52${_phoneController.text.trim()}',
          'code': code,
        },
      );
      final data = response.data as Map<String, dynamic>?;
      if (data?['verified'] == true) {
        if (!mounted) return;
        // Navigate by role after verification
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
      } else {
        setState(() {
          _error = 'Codigo incorrecto. Intenta de nuevo.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error al verificar. Intenta de nuevo.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AuthLayout(
      formContent: Stack(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Back button ────────────────────────────────────────────
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => context.go(WebRoutes.auth),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Volver'),
                ),
              ),
              const SizedBox(height: BCSpacing.md),

              // ── Heading ───────────────────────────────────────────────
              Text(
                'Verifica tu telefono',
                style: theme.textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: BCSpacing.sm),
              Text(
                'Te enviaremos un codigo por SMS.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: BCSpacing.xl),

              // ── Phone input ───────────────────────────────────────────
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                enabled: !_codeSent,
                decoration: const InputDecoration(
                  labelText: 'Numero de telefono',
                  prefixIcon: Icon(Icons.phone_outlined),
                  prefixText: '+52 ',
                  hintText: '3221234567',
                ),
              ),
              const SizedBox(height: BCSpacing.md),

              if (!_codeSent) ...[
                // ── Send code button ──────────────────────────────────────
                ElevatedButton(
                  onPressed: _isLoading ? null : _sendCode,
                  child: const Text('Enviar codigo'),
                ),
              ],

              if (_codeSent) ...[
                // ── OTP input ─────────────────────────────────────────────
                TextFormField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    letterSpacing: 12,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Codigo de 6 digitos',
                    prefixIcon: Icon(Icons.pin_outlined),
                  ),
                  onFieldSubmitted: (_) => _verifyCode(),
                ),
                const SizedBox(height: BCSpacing.md),

                // ── Verify button ─────────────────────────────────────────
                ElevatedButton(
                  onPressed: _isLoading ? null : _verifyCode,
                  child: const Text('Verificar'),
                ),
                const SizedBox(height: BCSpacing.md),

                // ── Resend ────────────────────────────────────────────────
                if (_resendCountdown > 0)
                  Text(
                    'Reenviar en $_resendCountdown s',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    textAlign: TextAlign.center,
                  )
                else
                  TextButton(
                    onPressed: _isLoading ? null : _sendCode,
                    child: const Text('Reenviar codigo'),
                  ),
              ],

              // ── Error ─────────────────────────────────────────────────
              if (_error != null) ...[
                const SizedBox(height: BCSpacing.md),
                Text(
                  _error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),

          // ── Loading overlay ────────────────────────────────────────────
          if (_isLoading)
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
