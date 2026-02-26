import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/curate_result.dart';

class LocationService {
  static Position? _lastPosition;
  static DateTime? _lastFetchedAt;
  static const _cacheDuration = Duration(minutes: 1);

  /// Get the user's current location. Requests permission if needed.
  /// Returns cached position if less than 1 minute old.
  /// Returns null if location cannot be obtained.
  static Future<LatLng?> getCurrentLocation() async {
    // Return cached position if fresh enough
    if (_lastPosition != null && _lastFetchedAt != null) {
      if (DateTime.now().difference(_lastFetchedAt!) < _cacheDuration) {
        return LatLng(lat: _lastPosition!.latitude, lng: _lastPosition!.longitude);
      }
    }

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('LocationService: Location services disabled');
        return _cachedOrNull();
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('LocationService: Permission denied');
          return _cachedOrNull();
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('LocationService: Permission permanently denied');
        return _cachedOrNull();
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      _lastPosition = position;
      _lastFetchedAt = DateTime.now();
      debugPrint('LocationService: ${position.latitude}, ${position.longitude}');
      return LatLng(lat: position.latitude, lng: position.longitude);
    } catch (e) {
      debugPrint('LocationService: Error getting location ($e)');
      return _cachedOrNull();
    }
  }

  static LatLng? _cachedOrNull() {
    if (_lastPosition != null) {
      return LatLng(lat: _lastPosition!.latitude, lng: _lastPosition!.longitude);
    }
    return null;
  }

  /// Check if location permission is granted without requesting.
  static Future<bool> hasPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }
}
