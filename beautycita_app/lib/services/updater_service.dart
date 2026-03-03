import 'package:flutter/foundation.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

/// Silent OTA updater via Shorebird.
///
/// Checks for patches on app launch, downloads in background.
/// Patch activates on next cold start. Temporary — remove when on Play Store.
class UpdaterService {
  static final UpdaterService _instance = UpdaterService._();
  static UpdaterService get instance => _instance;
  UpdaterService._();

  final _updater = ShorebirdUpdater();

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
      // Silent failure — OTA is best-effort
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
}
