import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';

/// OTA updater — checks R2 version.json for newer APK builds.
/// Android only. iOS uses AltStore for updates.
class UpdaterService {
  static final UpdaterService _instance = UpdaterService._();
  static UpdaterService get instance => _instance;
  UpdaterService._();

  // ── APK update state ──
  bool _apkUpdateAvailable = false;
  bool _apkUpdateRequired = false;
  String _apkUpdateUrl = '';
  String _apkUpdateVersion = '';
  int _remoteBuildNumber = 0;

  bool get apkUpdateAvailable => _apkUpdateAvailable;
  bool get apkUpdateRequired => _apkUpdateRequired;
  String get apkUpdateUrl => _apkUpdateUrl;
  String get apkUpdateVersion => _apkUpdateVersion;
  int get apkRemoteBuild => _remoteBuildNumber;

  /// Check R2 for a newer APK version. Non-blocking, fail-silent.
  /// Skipped on iOS — AltStore handles updates there.
  Future<void> checkForApkUpdate() async {
    // iOS uses AltStore for updates, not R2
    if (!Platform.isAndroid) {
      debugPrint('[Updater] Skipping APK check (not Android)');
      return;
    }

    try {
      final response = await http
          .get(Uri.parse(AppConstants.versionCheckUrl))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        debugPrint('[Updater] version.json fetch failed: ${response.statusCode}');
        return;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final remoteBuild = data['buildNumber'] as int? ?? data['build'] as int? ?? 0;
      final remoteVersion = data['version'] as String? ?? '';
      final url = data['url'] as String? ?? '';
      final required = data['forceUpdate'] as bool? ?? data['required'] as bool? ?? true;

      final localBase = AppConstants.baseBuildNumber;
      if (remoteBuild <= localBase) {
        debugPrint('[Updater] APK is current (local=$localBase [raw=${AppConstants.buildNumber}], remote=$remoteBuild)');
        return;
      }

      // Skip if user dismissed this build recently (unless required)
      if (!required && await _isDismissedRecently(remoteBuild)) {
        debugPrint('[Updater] APK update $remoteBuild dismissed recently, skipping');
        return;
      }

      _apkUpdateAvailable = true;
      _apkUpdateRequired = required;
      _apkUpdateUrl = url;
      _apkUpdateVersion = remoteVersion;
      _remoteBuildNumber = remoteBuild;
      debugPrint('[Updater] APK update available: $remoteVersion (build $remoteBuild), required=$required');
    } catch (e) {
      debugPrint('[Updater] APK version check failed: $e');
    }
  }

  /// Record that the user dismissed the update dialog for this build.
  Future<void> dismissApkUpdate() async {
    _apkUpdateAvailable = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(AppConstants.keyUpdateDismissedBuild, _remoteBuildNumber);
      await prefs.setString(
          AppConstants.keyUpdateDismissedAt, DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('[Updater] Failed to save dismissal: $e');
    }
  }

  Future<bool> _isDismissedRecently(int remoteBuild) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dismissedBuild =
          prefs.getInt(AppConstants.keyUpdateDismissedBuild) ?? 0;
      if (dismissedBuild != remoteBuild) return false;

      final dismissedAtStr =
          prefs.getString(AppConstants.keyUpdateDismissedAt);
      if (dismissedAtStr == null) return false;

      final dismissedAt = DateTime.tryParse(dismissedAtStr);
      if (dismissedAt == null) return false;

      return DateTime.now().difference(dismissedAt) <
          AppConstants.updateDismissCooldown;
    } catch (_) {
      return false;
    }
  }
}
