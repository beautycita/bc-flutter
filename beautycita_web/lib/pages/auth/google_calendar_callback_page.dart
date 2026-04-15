import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:beautycita_core/supabase.dart';

import '../../config/router.dart';
import '../../config/web_theme.dart';

/// Handles the OAuth callback from Google Calendar.
/// Captures the authorization code from the URL, sends it to the
/// google-calendar-connect edge function, then redirects to calendar sync.
class GoogleCalendarCallbackPage extends StatefulWidget {
  const GoogleCalendarCallbackPage({super.key});

  @override
  State<GoogleCalendarCallbackPage> createState() =>
      _GoogleCalendarCallbackPageState();
}

class _GoogleCalendarCallbackPageState
    extends State<GoogleCalendarCallbackPage> {
  String _status = 'connecting';
  String? _error;

  @override
  void initState() {
    super.initState();
    _exchangeCode();
  }

  Future<void> _exchangeCode() async {
    final uri = Uri.base;
    final code = uri.queryParameters['code'];
    final error = uri.queryParameters['error'];

    if (error != null) {
      setState(() {
        _status = 'error';
        _error = error == 'access_denied'
            ? 'Acceso denegado. No se conecto Google Calendar.'
            : 'Error de Google: $error';
      });
      return;
    }

    if (code == null || code.isEmpty) {
      setState(() {
        _status = 'error';
        _error = 'No se recibio el codigo de autorizacion.';
      });
      return;
    }

    try {
      final response = await BCSupabase.client.functions.invoke(
        'google-calendar-connect',
        body: {'action': 'connect', 'code': code},
      );
      final data = response.data;

      if (data is Map && data['connected'] == true) {
        setState(() => _status = 'success');
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) context.go(WebRoutes.negocioCalendarSync);
      } else {
        setState(() {
          _status = 'error';
          _error = data is Map
              ? (data['error'] as String? ?? 'Error desconocido')
              : 'Respuesta inesperada del servidor';
        });
      }
    } catch (e) {
      setState(() {
        _status = 'error';
        _error = 'Error al conectar: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_status == 'connecting') ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                Text(
                  'Conectando Google Calendar...',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
              ] else if (_status == 'success') ...[
                const Icon(Icons.check_circle_outlined,
                    size: 64, color: Color(0xFF22C55E)),
                const SizedBox(height: 24),
                Text(
                  'Google Calendar conectado',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Redirigiendo al panel de calendario...',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: kWebTextSecondary,
                      ),
                ),
              ] else ...[
                const Icon(Icons.error_outline,
                    size: 64, color: Color(0xFFEF4444)),
                const SizedBox(height: 24),
                Text(
                  'Error al conectar',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _error ?? 'Error desconocido',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: kWebTextSecondary,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: () =>
                      context.go(WebRoutes.negocioCalendarSync),
                  child: const Text('Volver al calendario'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
