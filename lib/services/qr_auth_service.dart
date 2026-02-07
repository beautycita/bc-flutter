import 'package:beautycita/services/supabase_client.dart';

/// Result of a QR auth operation
sealed class QrAuthResult {
  const QrAuthResult();
}

class QrAuthSuccess extends QrAuthResult {
  const QrAuthSuccess();
}

class QrAuthError extends QrAuthResult {
  final String message;
  final String code;
  const QrAuthError(this.message, {this.code = 'unknown'});
}

class QrAuthService {
  /// Authorize a QR session from webapp (APK scanned the QR)
  Future<QrAuthResult> authorizeSession(String code, String sessionId) async {
    if (!SupabaseClientService.isInitialized) {
      return const QrAuthError(
        'Sin conexion al servidor',
        code: 'not_initialized',
      );
    }

    if (!SupabaseClientService.isAuthenticated) {
      return const QrAuthError(
        'Sesion no activa. Reinicia la app.',
        code: 'not_authenticated',
      );
    }

    try {
      final response = await SupabaseClientService.client.functions.invoke(
        'qr-auth',
        body: {
          'action': 'authorize',
          'code': code,
          'session_id': sessionId,
        },
      );

      if (response.status == 200) {
        // Notify the web via Realtime Broadcast
        try {
          final channel = SupabaseClientService.client.channel('qr_auth_$sessionId');
          await channel.subscribe();
          await channel.sendBroadcastMessage(
            event: 'session_authorized',
            payload: {'session_id': sessionId},
          );
          await Future.delayed(const Duration(milliseconds: 500));
          await SupabaseClientService.client.removeChannel(channel);
        } catch (_) {
          // Broadcast is best-effort; DB update is the source of truth
        }
        return const QrAuthSuccess();
      }

      // Parse error from response
      final data = response.data;
      if (data is Map<String, dynamic> && data['error'] != null) {
        final error = data['error'] as String;
        if (error.contains('expired')) {
          return const QrAuthError(
            'Codigo expirado. Genera uno nuevo en la web.',
            code: 'expired',
          );
        }
        if (error.contains('not found')) {
          return const QrAuthError(
            'Codigo no encontrado. Verifica e intenta de nuevo.',
            code: 'not_found',
          );
        }
        return QrAuthError(error, code: 'server_error');
      }

      return QrAuthError(
        'Error del servidor (${response.status})',
        code: 'http_${response.status}',
      );
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('SocketException') || msg.contains('ClientException')) {
        return const QrAuthError(
          'Sin conexion a internet',
          code: 'network',
        );
      }
      if (msg.contains('TimeoutException')) {
        return const QrAuthError(
          'Tiempo de espera agotado. Intenta de nuevo.',
          code: 'timeout',
        );
      }
      return QrAuthError('Error: $msg', code: 'exception');
    }
  }
}
