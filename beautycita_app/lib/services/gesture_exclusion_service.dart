import 'dart:io';
import 'dart:ui';
import 'package:flutter/services.dart';

/// Manages Android system gesture exclusion rects so that edge swipes
/// reach Flutter's drawer gesture detector instead of triggering the
/// system back navigation.
///
/// Android caps total exclusion height to 200dp per edge.
class GestureExclusionService {
  static const _channel = MethodChannel('com.beautycita/gesture_exclusion');

  /// Sets exclusion rects (in physical pixels).
  static Future<bool> setRects(List<Rect> rects) async {
    if (!Platform.isAndroid) return false;
    try {
      final rectMaps = rects
          .map((r) => {
                'left': r.left.toInt(),
                'top': r.top.toInt(),
                'right': r.right.toInt(),
                'bottom': r.bottom.toInt(),
              })
          .toList();
      return await _channel
              .invokeMethod<bool>('setGestureExclusionRects', {'rects': rectMaps}) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  /// Clears all exclusion rects.
  static Future<bool> clearRects() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('clearGestureExclusionRects') ??
          false;
    } on PlatformException {
      return false;
    }
  }
}
