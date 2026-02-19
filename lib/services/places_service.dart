import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class PlacePrediction {
  final String placeId;
  final String mainText;
  final String secondaryText;
  final String fullText;

  const PlacePrediction({
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
    required this.fullText,
  });
}

class PlaceLocation {
  final double lat;
  final double lng;
  final String address;

  const PlaceLocation({
    required this.lat,
    required this.lng,
    required this.address,
  });
}

/// Calls Google Places API (New) directly from the device using the
/// Android-restricted API key with X-Android-Package/Cert headers.
class PlacesService {
  final String apiKey;
  final String packageName;
  final String sha1Cert;

  static const _debugSha1 = '3BB7776E83D63854B9ACEA059ED3D8B20E04CBD1';
  static const _releaseSha1 = 'E87B10F536D9486A2155FDA0E788E5C6050DA47E';

  PlacesService({
    required this.apiKey,
    this.packageName = 'com.beautycita',
    this.sha1Cert = kReleaseMode ? _releaseSha1 : _debugSha1,
  });

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': apiKey,
        'X-Android-Package': packageName,
        'X-Android-Cert': sha1Cert,
      };

  /// Search for places using Places API (New) Autocomplete.
  Future<List<PlacePrediction>> searchPlaces(
    String query, {
    double? lat,
    double? lng,
  }) async {
    if (query.trim().isEmpty) return [];

    debugPrint('[PlacesService] searchPlaces: "$query"');

    try {
      final body = <String, dynamic>{
        'input': query.trim(),
        'languageCode': 'es',
        'includedRegionCodes': ['MX'],
      };

      if (lat != null && lng != null) {
        body['locationBias'] = {
          'circle': {
            'center': {'latitude': lat, 'longitude': lng},
            'radius': 50000.0,
          },
        };
      }

      final response = await http.post(
        Uri.parse('https://places.googleapis.com/v1/places:autocomplete'),
        headers: _headers,
        body: jsonEncode(body),
      );

      debugPrint('[PlacesService] status=${response.statusCode}');

      if (response.statusCode != 200) {
        debugPrint('[PlacesService] error: ${response.body}');
        return [];
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final suggestions = data['suggestions'] as List? ?? [];
      debugPrint('[PlacesService] got ${suggestions.length} suggestions');

      return suggestions
          .where((s) =>
              (s as Map<String, dynamic>).containsKey('placePrediction'))
          .map((s) {
        final pp = (s as Map<String, dynamic>)['placePrediction']
            as Map<String, dynamic>;
        final sf = (pp['structuredFormat'] ?? {}) as Map<String, dynamic>;
        final mainText =
            ((sf['mainText'] ?? {}) as Map<String, dynamic>)['text']
                    as String? ??
                '';
        final secondaryText =
            ((sf['secondaryText'] ?? {}) as Map<String, dynamic>)['text']
                    as String? ??
                '';
        final fullText =
            ((pp['text'] ?? {}) as Map<String, dynamic>)['text']
                    as String? ??
                '';

        return PlacePrediction(
          placeId: pp['placeId'] as String? ?? '',
          mainText: mainText,
          secondaryText: secondaryText,
          fullText: fullText,
        );
      }).toList();
    } catch (e) {
      debugPrint('[PlacesService] searchPlaces error: $e');
      return [];
    }
  }

  /// Get place details (coordinates + address) using Places API (New).
  Future<PlaceLocation?> getPlaceDetails(String placeId) async {
    if (placeId.isEmpty) return null;

    try {
      final uri =
          Uri.parse('https://places.googleapis.com/v1/places/$placeId');

      final headers = {
        'X-Goog-Api-Key': apiKey,
        'X-Goog-FieldMask': 'location,formattedAddress',
        'X-Android-Package': packageName,
        'X-Android-Cert': sha1Cert,
      };

      final response = await http.get(uri, headers: headers);

      if (response.statusCode != 200) {
        debugPrint('[PlacesService] details error: ${response.body}');
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final location = data['location'] as Map<String, dynamic>?;

      if (location == null) {
        debugPrint('[PlacesService] details missing location: $data');
        return null;
      }

      return PlaceLocation(
        lat: (location['latitude'] as num).toDouble(),
        lng: (location['longitude'] as num).toDouble(),
        address: data['formattedAddress'] as String? ?? '',
      );
    } catch (e) {
      debugPrint('[PlacesService] getPlaceDetails error: $e');
      return null;
    }
  }
}
