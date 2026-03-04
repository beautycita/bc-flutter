import 'dart:io';
import 'package:flutter/services.dart';

/// Detects OS-level screenshots via Android ContentObserver.
/// Streams screenshot image bytes to Dart when a new screenshot is taken.
class ScreenshotDetectorService {
  static const _methodChannel =
      MethodChannel('com.beautycita/screenshot_detector');
  static const _eventChannel =
      EventChannel('com.beautycita/screenshot_events');

  /// Stream of screenshot image bytes (fires when user takes a screenshot).
  static Stream<Uint8List> get onScreenshotTaken =>
      _eventChannel.receiveBroadcastStream().map((data) => data as Uint8List);

  /// Start listening for screenshots.
  static Future<void> startListening() async {
    if (!Platform.isAndroid) return;
    try {
      await _methodChannel.invokeMethod('startListening');
    } on PlatformException {
      // Ignore — platform channel not available
    }
  }

  /// Stop listening for screenshots.
  static Future<void> stopListening() async {
    if (!Platform.isAndroid) return;
    try {
      await _methodChannel.invokeMethod('stopListening');
    } on PlatformException {
      // Ignore
    }
  }
}
