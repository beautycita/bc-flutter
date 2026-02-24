import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/curate_result.dart' show LatLng;
import '../services/route_service.dart';

class RouteRequest {
  final LatLng origin;
  final LatLng destination;

  const RouteRequest({required this.origin, required this.destination});

  @override
  bool operator ==(Object other) =>
      other is RouteRequest &&
      other.origin.lat == origin.lat &&
      other.origin.lng == origin.lng &&
      other.destination.lat == destination.lat &&
      other.destination.lng == destination.lng;

  @override
  int get hashCode => Object.hash(origin.lat, origin.lng, destination.lat, destination.lng);
}

final routeProvider = FutureProvider.family<RouteData, RouteRequest>((ref, request) {
  return RouteService.getRoute(request.origin, request.destination);
});
