import 'package:beautycita/services/supabase_client.dart';

class QrAuthService {
  /// Authorize a QR session from webapp (APK scanned the QR)
  Future<bool> authorizeSession(String code, String sessionId) async {
    try {
      final response = await SupabaseClientService.client.functions.invoke(
        'qr-auth',
        body: {
          'action': 'authorize',
          'code': code,
          'session_id': sessionId,
        },
      );
      return response.status == 200;
    } catch (e) {
      return false;
    }
  }
}
