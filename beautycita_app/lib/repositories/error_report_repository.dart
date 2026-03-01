import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:beautycita/services/supabase_client.dart';
import 'package:beautycita/config/constants.dart';
import 'package:beautycita/models/error_report.dart';

class ErrorReportRepository {
  static Future<void> submit({
    required String errorMessage,
    String? errorDetails,
    String? screenName,
  }) async {
    if (!SupabaseClientService.isInitialized) return;

    final deviceInfo =
        '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';

    final report = ErrorReport(
      userId: SupabaseClientService.currentUserId,
      errorMessage: errorMessage,
      errorDetails: errorDetails,
      screenName: screenName,
      deviceInfo: deviceInfo,
      appVersion: AppConstants.version,
    );

    try {
      await SupabaseClientService.client
          .from('user_error_reports')
          .insert(report.toInsertMap());
    } catch (e) {
      debugPrint('[ErrorReportRepository] Submit failed: $e');
    }
  }
}
