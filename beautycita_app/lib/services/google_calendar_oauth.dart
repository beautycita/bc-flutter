import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Native Google Calendar connect on mobile.
///
/// google_sign_in v7 is already in pubspec for Google account linking. This
/// extends that flow to grab a server auth code with the Calendar Events
/// scope, which the existing `google-calendar-connect` edge function exchanges
/// for an offline access_token + refresh_token. The user never leaves the
/// app — the Google account picker pops up natively.
class GoogleCalendarOAuth {
  static const _calendarScope = 'https://www.googleapis.com/auth/calendar.events';

  static String get _serverClientId =>
      dotenv.env['GOOGLE_OAUTH_CLIENT_ID'] ?? '';

  /// Result codes:
  /// - `null` server auth code → user cancelled or sign-in surfaces failed
  /// - non-null → caller should POST to google-calendar-connect connect action
  static Future<String?> requestServerAuthCode() async {
    final clientId = _serverClientId;
    if (clientId.isEmpty) {
      if (kDebugMode) {
        debugPrint('[CalendarOAuth] GOOGLE_OAUTH_CLIENT_ID not set in dotenv');
      }
      return null;
    }

    final googleSignIn = GoogleSignIn.instance;
    try {
      await googleSignIn.initialize(serverClientId: clientId);
    } catch (e) {
      if (kDebugMode) debugPrint('[CalendarOAuth] initialize failed: $e');
      // initialize is idempotent; ignore "already initialized" style errors
      // and proceed.
    }

    GoogleSignInAccount account;
    try {
      account = await googleSignIn.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      if (kDebugMode) debugPrint('[CalendarOAuth] authenticate error: $e');
      rethrow;
    }

    try {
      final serverAuth =
          await account.authorizationClient.authorizeServer([_calendarScope]);
      return serverAuth?.serverAuthCode;
    } catch (e) {
      if (kDebugMode) debugPrint('[CalendarOAuth] authorizeServer error: $e');
      rethrow;
    }
  }
}
