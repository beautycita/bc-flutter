import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../models/curate_result.dart' show LatLng;
import '../services/route_service.dart';

class RouteMapWidget extends StatelessWidget {
  final RouteData routeData;
  final LatLng origin;
  final LatLng destination;
  final double height;

  const RouteMapWidget({
    super.key,
    required this.routeData,
    required this.origin,
    required this.destination,
    this.height = 300,
  });

  ll.LatLng _convert(LatLng p) => ll.LatLng(p.lat, p.lng);

  String _formatDuration(double minutes) {
    final rounded = minutes.round();
    if (rounded < 60) return '$rounded min';
    final h = rounded ~/ 60;
    final m = rounded % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  String _formatDistance(double km) {
    if (km < 1) return '${(km * 1000).round()} m';
    return '${km.toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    final llPoints = routeData.polylinePoints.map(_convert).toList();
    final llOrigin = _convert(origin);
    final llDestination = _convert(destination);

    final bounds = LatLngBounds.fromPoints([
      ...llPoints,
      llOrigin,
      llDestination,
    ]);

    final durationLabel = _formatDuration(routeData.durationMinutes);
    final distanceLabel = _formatDistance(routeData.distanceKm);

    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCameraFit: CameraFit.bounds(
                  bounds: bounds,
                  padding: const EdgeInsets.all(50),
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.beautycita.app',
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: llPoints,
                      color: const Color(0xFF660033),
                      strokeWidth: 4,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: llOrigin,
                      width: 20,
                      height: 20,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                    Marker(
                      point: llDestination,
                      width: 20,
                      height: 20,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF660033),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  '$durationLabel · $distanceLabel',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF660033),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
