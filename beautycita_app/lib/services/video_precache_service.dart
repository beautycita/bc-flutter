import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Precaches category background videos from R2 to local storage.
/// Call once after home screen loads. Non-blocking, runs in background.
class VideoPrecacheService {
  VideoPrecacheService._();
  static final instance = VideoPrecacheService._();

  bool _started = false;

  static const _r2Base = 'https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/video/';

  /// All category background videos used in booking flow.
  static const _videos = [
    'curlySelfie.mp4',   // nails
    'hairTreat.mp4',     // hair
    'twinMakeup.mp4',    // lashes_brows
    'makeupArtist.mp4',  // makeup
    'spaTreat.mp4',      // facial, body_spa
    'happyPort.mp4',     // specialized
    'cutOff.mp4',        // barberia
    'bcApp.mp4',         // default
    'bcStartup.mp4',     // hero
  ];

  /// Start precaching all videos. Safe to call multiple times — only runs once.
  Future<void> precacheAll() async {
    if (_started) return;
    _started = true;

    try {
      final cacheDir = await getApplicationCacheDirectory();

      for (final video in _videos) {
        final file = File('${cacheDir.path}/bg_$video');
        if (file.existsSync() && file.lengthSync() > 100000) {
          if (kDebugMode) debugPrint('[VideoCache] $video already cached');
          continue;
        }

        try {
          final resp = await http.get(Uri.parse('$_r2Base$video'))
              .timeout(const Duration(seconds: 20));
          if (resp.statusCode == 200) {
            await file.writeAsBytes(resp.bodyBytes);
            if (kDebugMode) debugPrint('[VideoCache] Cached $video (${(resp.bodyBytes.length / 1024 / 1024).toStringAsFixed(1)}MB)');
          }
        } catch (e) {
          if (kDebugMode) debugPrint('[VideoCache] Failed $video: $e');
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[VideoCache] Precache failed: $e');
    }
  }

  /// Get cached file path for a video. Returns null if not cached.
  Future<File?> getCached(String filename) async {
    try {
      final cacheDir = await getApplicationCacheDirectory();
      final file = File('${cacheDir.path}/bg_$filename');
      if (file.existsSync() && file.lengthSync() > 100000) return file;
    } catch (e) {
      if (kDebugMode) debugPrint('[VideoPrecacheService.getCached] error: $e');
    }
    return null;
  }
}
