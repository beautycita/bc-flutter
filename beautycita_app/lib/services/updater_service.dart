import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import '../config/constants.dart';

/// Two-tier OTA updater:
///   Tier 1 (Shorebird): Silent Dart-only patches — downloads in background, applies on next cold start.
///   Tier 2 (APK):       Full binary update — checks version.json on R2, prompts user to download.
class UpdaterService {
  static final UpdaterService _instance = UpdaterService._();
  static UpdaterService get instance => _instance;
  UpdaterService._();

  final _updater = ShorebirdUpdater();

  // ── Tier 2: APK update state ──
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

  // ── Tier 1: Shorebird patches (unchanged) ──

  /// Check for and silently apply any available patch.
  /// Fire-and-forget — call without await during splash.
  Future<void> checkAndUpdate() async {
    try {
      final status = await _updater.checkForUpdate();
      if (status == UpdateStatus.outdated) {
        debugPrint('[Updater] Patch available, downloading...');
        await _updater.update();
        debugPrint('[Updater] Patch downloaded. Will apply on next restart.');
      } else {
        debugPrint('[Updater] App is up to date (status: $status)');
      }
    } catch (e) {
      debugPrint('[Updater] Update check failed: $e');
    }
  }

  /// Get currently installed patch number, if any.
  Future<int?> currentPatchNumber() async {
    try {
      final patch = await _updater.readCurrentPatch();
      return patch?.number;
    } catch (_) {
      return null;
    }
  }

  // ── Tier 2: Full APK update ──

  /// Check R2 for a newer APK version. Non-blocking, fail-silent.
  /// Fire-and-forget — call without await during splash.
  Future<void> checkForApkUpdate() async {
    try {
      final response = await http
          .get(Uri.parse(AppConstants.versionCheckUrl))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        debugPrint('[Updater] version.json fetch failed: ${response.statusCode}');
        return;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final remoteBuild = data['build'] as int? ?? 0;
      final remoteVersion = data['version'] as String? ?? '';
      final url = data['url'] as String? ?? '';
      final required = data['required'] as bool? ?? true;

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
