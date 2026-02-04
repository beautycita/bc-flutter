import 'package:beautycita/services/supabase_client.dart';

class QrAuthService {
  Future<bool> authorizeSession(String code) async {
    try {
      final response = await SupabaseClientService.client.functions.invoke(
        'qr-auth',
        body: {'action': 'authorize', 'code': code},
      );
      return response.status == 200;
    } catch (e) {
      return false;
    }
  }
}
