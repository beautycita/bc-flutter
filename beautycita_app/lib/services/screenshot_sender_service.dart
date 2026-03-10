import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:beautycita/services/supabase_client.dart';

/// Sends an annotated screenshot to BC via the send-screenshot edge function.
class ScreenshotSenderService {
  /// Send annotated screenshot to BC's WhatsApp.
  /// Returns true if sent successfully.
  static Future<bool> sendToBC(Uint8List imageBytes, {String? caption}) async {
    try {
      final client = SupabaseClientService.client;
      final base64Image = base64Encode(imageBytes);

      final response = await client.functions.invoke(
        'send-screenshot',
        body: {
          'image': base64Image,
          'caption': ?caption,
        },
      ).timeout(const Duration(seconds: 30));

      if (response.status == 200) {
        final data = response.data;
        if (data is Map) {
          return data['sent'] == true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('[ScreenshotSender] Error: $e');
      return false;
    }
  }
}
