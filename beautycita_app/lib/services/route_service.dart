import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/curate_result.dart' show LatLng;

class RouteData {
  final List<LatLng> polylinePoints;
  final double durationMinutes;
  final double distanceKm;

  const RouteData({
    required this.polylinePoints,
    required this.durationMinutes,
    required this.distanceKm,
  });
}

class RouteService {
  static Future<RouteData> getRoute(LatLng origin, LatLng destination) async {
    // Use OSRM public demo server
    // URL format: /route/v1/driving/{lng1},{lat1};{lng2},{lat2}?overview=full&geometries=geojson
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '${origin.lng},${origin.lat};${destination.lng},${destination.lat}'
      '?overview=full&geometries=geojson',
    );

    final response = await http.get(url);
    if (response.statusCode != 200) {
      throw Exception('OSRM routing failed: ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final routes = json['routes'] as List;
    if (routes.isEmpty) throw Exception('No route found');

    final route = routes[0] as Map<String, dynamic>;
    final durationSec = (route['duration'] as num).toDouble();
    final distanceM = (route['distance'] as num).toDouble();

    // Parse GeoJSON coordinates
    final geometry = route['geometry'] as Map<String, dynamic>;
    final coordinates = geometry['coordinates'] as List;
    final points = coordinates.map((coord) {
      final c = coord as List;
      return LatLng(lat: (c[1] as num).toDouble(), lng: (c[0] as num).toDouble());
    }).toList();

    return RouteData(
      polylinePoints: points,
      durationMinutes: durationSec / 60,
      distanceKm: distanceM / 1000,
    );
  }
}
