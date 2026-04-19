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

  static const _lastVersionCheckKey = 'last_version_check';

  /// Check R2 for a newer APK version. Non-blocking, fail-silent.
  /// Skipped on iOS — AltStore handles updates there.
  /// Set [force] to true to bypass the 24h rate limit (manual check button).
  Future<void> checkForApkUpdate({bool force = false}) async {
    // iOS uses AltStore for updates, not R2
    if (!Platform.isAndroid) {
      if (kDebugMode) debugPrint('[Updater] Skipping APK check (not Android)');
      return;
    }

    // Rate-limit to once per hour unless forced (manual button). Was 24h —
    // too conservative for a platform that deploys multiple times per day.
    // version.json has 60s cache-control at the CDN and the HTTP call is
    // 5s-timeout fail-silent, so hourly polling is cheap.
    if (!force) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final lastCheck = prefs.getString(_lastVersionCheckKey);
        if (lastCheck != null) {
          final lastTime = DateTime.tryParse(lastCheck);
          if (lastTime != null &&
              DateTime.now().difference(lastTime) < const Duration(hours: 1)) {
            if (kDebugMode) debugPrint('[Updater] Skipping version check (last check < 1h ago)');
            return;
          }
        }
      } catch (_) {
        // If prefs fail, proceed with check
      }
    }

    try {
      final cacheBuster = DateTime.now().millisecondsSinceEpoch;
      final response = await http
          .get(Uri.parse('${AppConstants.versionCheckUrl}?t=$cacheBuster'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        if (kDebugMode) debugPrint('[Updater] version.json fetch failed: ${response.statusCode}');
        return;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final remoteBuild = data['buildNumber'] as int? ?? data['build'] as int? ?? 0;
      final remoteVersion = data['version'] as String? ?? '';
      final url = data['url'] as String? ?? '';
      final required = data['forceUpdate'] as bool? ?? data['required'] as bool? ?? true;

      // Strip ABI offset from split-per-abi builds:
      // Flutter adds +1000 (armeabi), +2000 (arm64), +3000 (x86_64)
      // e.g., pubspec 50241 → arm64 APK reports 52241
      // We compare base build numbers: 52241 - 2000 = 50241
      final rawLocal = AppConstants.buildNumber;
      final abiOffset = ((rawLocal ~/ 1000) % 10) * 1000; // extracts 0/1000/2000/3000
      final localBuild = rawLocal - abiOffset;
      if (remoteBuild <= localBuild) {
        if (kDebugMode) debugPrint('[Updater] APK is current (local=$localBuild, remote=$remoteBuild)');
        // Record successful check even when current
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_lastVersionCheckKey, DateTime.now().toIso8601String());
        } catch (e) { if (kDebugMode) debugPrint('[Updater] Error: $e'); }
        return;
      }

      // Skip if user dismissed this build recently (unless required)
      if (!required && await _isDismissedRecently(remoteBuild)) {
        if (kDebugMode) debugPrint('[Updater] APK update $remoteBuild dismissed recently, skipping');
        return;
      }

      _apkUpdateAvailable = true;
      _apkUpdateRequired = required;
      _apkUpdateUrl = url;
      _apkUpdateVersion = remoteVersion;
      _remoteBuildNumber = remoteBuild;
      if (kDebugMode) debugPrint('[Updater] APK update available: $remoteVersion (build $remoteBuild), required=$required');

      // Record successful check timestamp
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_lastVersionCheckKey, DateTime.now().toIso8601String());
      } catch (e) { if (kDebugMode) debugPrint('[Updater] Error: $e'); }
    } catch (e) {
      if (kDebugMode) debugPrint('[Updater] APK version check failed: $e');
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
      if (kDebugMode) debugPrint('[Updater] Failed to save dismissal: $e');
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
