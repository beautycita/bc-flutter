import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'supabase_client.dart';

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

/// Calls Google Places API through the places-proxy edge function
/// to avoid API key restrictions on direct device HTTP calls.
class PlacesService {
  PlacesService();

  /// Search for places via the places-proxy edge function.
  Future<List<PlacePrediction>> searchPlaces(
    String query, {
    double? lat,
    double? lng,
  }) async {
    if (query.trim().isEmpty) return [];

    try {
      final client = SupabaseClientService.client;
      final body = <String, dynamic>{
        'action': 'autocomplete',
        'input': query.trim(),
      };
      if (lat != null && lng != null) {
        body['lat'] = lat;
        body['lng'] = lng;
      }

      final response = await client.functions.invoke(
        'places-proxy',
        body: body,
      );

      if (response.status != 200) {
        debugPrint('[PlacesService] status=${response.status}');
        return [];
      }

      final raw = response.data;
      final data = raw is String
          ? jsonDecode(raw) as Map<String, dynamic>
          : raw as Map<String, dynamic>;

      final predictions = data['predictions'] as List? ?? [];
      return predictions.map((p) {
        final m = p as Map<String, dynamic>;
        return PlacePrediction(
          placeId: m['place_id'] as String? ?? '',
          mainText: m['main_text'] as String? ?? '',
          secondaryText: m['secondary_text'] as String? ?? '',
          fullText: m['description'] as String? ?? '',
        );
      }).toList();
    } catch (e) {
      debugPrint('[PlacesService] searchPlaces error: $e');
      return [];
    }
  }

  /// Get place details (coordinates + address) via the places-proxy edge function.
  Future<PlaceLocation?> getPlaceDetails(String placeId) async {
    if (placeId.isEmpty) return null;

    try {
      final client = SupabaseClientService.client;
      final response = await client.functions.invoke(
        'places-proxy',
        body: {
          'action': 'details',
          'place_id': placeId,
        },
      );

      if (response.status != 200) {
        debugPrint('[PlacesService] details status=${response.status}');
        return null;
      }

      final raw = response.data;
      final data = raw is String
          ? jsonDecode(raw) as Map<String, dynamic>
          : raw as Map<String, dynamic>;

      if (data['lat'] == null || data['lng'] == null) {
        debugPrint('[PlacesService] details missing lat/lng: $data');
        return null;
      }

      return PlaceLocation(
        lat: (data['lat'] as num).toDouble(),
        lng: (data['lng'] as num).toDouble(),
        address: data['address'] as String? ?? '',
      );
    } catch (e) {
      debugPrint('[PlacesService] getPlaceDetails error: $e');
      return null;
    }
  }
}
