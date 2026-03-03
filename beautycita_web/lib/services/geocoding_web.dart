/// Nominatim (OpenStreetMap) geocoding for city/address lookup.
///
/// Free, no API key required. Used when browser geolocation is denied
/// so the user can manually enter a city to search near.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

/// A geocoded place result.
typedef GeoPlace = ({double lat, double lng, String displayName});

const _baseUrl = 'https://nominatim.openstreetmap.org/search';
const _userAgent = 'BeautyCita-Web/1.0';

/// Return up to [limit] geocoded suggestions for [query].
///
/// Returns an empty list on network error or no results.
Future<List<GeoPlace>> geocodeSuggestions(String query,
    {int limit = 5}) async {
  if (query.trim().length < 2) return [];

  final uri = Uri.parse(_baseUrl).replace(queryParameters: {
    'q': query.trim(),
    'format': 'json',
    'limit': '$limit',
    'accept-language': 'es',
  });

  try {
    final response = await http
        .get(uri, headers: {'User-Agent': _userAgent})
        .timeout(const Duration(seconds: 5));

    if (response.statusCode != 200) return [];

    final List<dynamic> data = json.decode(response.body);
    return data.map<GeoPlace>((item) {
      return (
        lat: double.parse(item['lat'] as String),
        lng: double.parse(item['lon'] as String),
        displayName: item['display_name'] as String,
      );
    }).toList();
  } catch (_) {
    return [];
  }
}

/// Geocode a single query, returning the top result or null.
Future<GeoPlace?> geocodeCity(String query) async {
  final results = await geocodeSuggestions(query, limit: 1);
  return results.isEmpty ? null : results.first;
}
