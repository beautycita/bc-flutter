import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart' as ll;

import 'package:beautycita/config/constants.dart';
import 'package:beautycita/config/routes.dart';
import 'package:beautycita/providers/admin_provider.dart';
import 'package:beautycita/providers/rp_provider.dart';
import 'package:beautycita/services/location_service.dart';
import 'package:beautycita/services/toast_service.dart';
import 'package:beautycita/models/curate_result.dart' show LatLng;

class RPShellScreen extends ConsumerStatefulWidget {
  const RPShellScreen({super.key});

  @override
  ConsumerState<RPShellScreen> createState() => _RPShellScreenState();
}

class _RPShellScreenState extends ConsumerState<RPShellScreen> {
  int _tabIndex = 0;
  LatLng? _currentLocation;
  bool _locationLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    final loc = await LocationService.getCurrentLocation();
    if (mounted) {
      setState(() {
        _currentLocation = loc;
        _locationLoading = false;
      });
    }
  }

  // ── Pin color by rp_status ──
  static Color _statusColor(String? status, Map<String, dynamic> salon) {
    switch (status) {
      case 'onboarding_complete':
        return const Color(0xFF4CAF50);
      case 'visited':
        final interest = salon['interest_level'];
        if (interest == null || interest == 0) return const Color(0xFF9E9E9E);
        return const Color(0xFFFF9800);
      case 'assigned':
      default:
        return const Color(0xFF2196F3);
    }
  }

  // ── Haversine distance in km ──
  static double _haversineKm(
      double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLng = (lng2 - lng1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLng / 2) *
            sin(dLng / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  @override
  Widget build(BuildContext context) {
    final isRpAsync = ref.watch(isRpProvider);

    return isRpAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text('Error: $e')),
      ),
      data: (isRp) {
        if (!isRp) {
          return Scaffold(
            appBar: AppBar(title: const Text('Acceso restringido')),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: AppConstants.paddingMD),
                  Text('Acceso restringido',
                      style: GoogleFonts.poppins(
                          fontSize: 20, fontWeight: FontWeight.w600)),
                  const SizedBox(height: AppConstants.paddingSM),
                  Text('Solo para personal de Relaciones Publicas.',
                      style: GoogleFonts.nunito(fontSize: 14)),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text('Relaciones Publicas',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            leading: IconButton(
              icon: const Icon(Icons.home_rounded),
              onPressed: () => context.go('/home'),
            ),
          ),
          body: _tabIndex == 0 ? _buildMapTab() : _buildListTab(),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _tabIndex,
            onTap: (i) => setState(() => _tabIndex = i),
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Mapa'),
              BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Lista'),
            ],
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  TAB 1: Map View
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildMapTab() {
    final salonsAsync = ref.watch(rpAssignedSalonsProvider);

    if (_locationLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final centerLat = _currentLocation?.lat ?? 20.6;
    final centerLng = _currentLocation?.lng ?? -103.3;

    return salonsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error cargando salones: $e')),
      data: (salons) {
        final markers = <Marker>[
          // RP current location — blue dot
          Marker(
            point: ll.LatLng(centerLat, centerLng),
            width: 24,
            height: 24,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.blue.shade700,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withValues(alpha: 0.4),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
          // Salon pins
          for (final salon in salons)
            if (salon['latitude'] != null && salon['longitude'] != null)
              Marker(
                point: ll.LatLng(
                  (salon['latitude'] as num).toDouble(),
                  (salon['longitude'] as num).toDouble(),
                ),
                width: 20,
                height: 20,
                child: GestureDetector(
                  onTap: () =>
                      context.push(AppRoutes.rpCentro, extra: salon),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _statusColor(salon['rp_status'], salon),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ),
        ];

        return FlutterMap(
          options: MapOptions(
            initialCenter: ll.LatLng(centerLat, centerLng),
            initialZoom: 13,
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.beautycita.app',
            ),
            MarkerLayer(markers: markers),
          ],
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  TAB 2: List View
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildListTab() {
    final salonsAsync = ref.watch(rpAssignedSalonsProvider);

    return salonsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (salons) {
        final unvisited = <Map<String, dynamic>>[];
        final followUp = <Map<String, dynamic>>[];
        final complete = <Map<String, dynamic>>[];

        for (final s in salons) {
          final status = s['rp_status'] as String?;
          if (status == 'onboarding_complete') {
            complete.add(s);
          } else if (status == 'visited') {
            followUp.add(s);
          } else {
            unvisited.add(s);
          }
        }

        if (salons.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.assignment_outlined,
                    size: 64, color: Colors.grey.shade400),
                const SizedBox(height: AppConstants.paddingMD),
                Text('No tienes salones asignados',
                    style: GoogleFonts.poppins(
                        fontSize: 16, color: Colors.grey.shade600)),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.screenPaddingHorizontal,
            vertical: AppConstants.paddingMD,
          ),
          children: [
            if (unvisited.isNotEmpty)
              _buildSection(
                  'Sin Visitar', const Color(0xFF2196F3), unvisited),
            if (followUp.isNotEmpty)
              _buildSection('Visitados — Seguimiento',
                  const Color(0xFFFF9800), followUp),
            if (complete.isNotEmpty)
              _buildSection('Onboarding Completo',
                  const Color(0xFF4CAF50), complete),
          ],
        );
      },
    );
  }

  Widget _buildSection(
      String title, Color color, List<Map<String, dynamic>> salons) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
              top: AppConstants.paddingMD,
              bottom: AppConstants.paddingSM),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: AppConstants.paddingSM),
              Text(title,
                  style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: color)),
              const SizedBox(width: AppConstants.paddingSM),
              Text('(${salons.length})',
                  style:
                      GoogleFonts.nunito(fontSize: 14, color: Colors.grey)),
            ],
          ),
        ),
        ...salons.map((s) => _buildSalonCard(s, color)),
      ],
    );
  }

  Widget _buildSalonCard(Map<String, dynamic> salon, Color statusColor) {
    final rating = salon['rating_average'] as num?;
    final ratingCount = salon['rating_count'] as num?;

    return Card(
      margin: const EdgeInsets.only(bottom: AppConstants.paddingSM),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusSM),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppConstants.radiusSM),
        onTap: () => context.push(AppRoutes.rpCentro, extra: salon),
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingMD),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                    color: statusColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: AppConstants.paddingSM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      salon['business_name'] ?? 'Sin nombre',
                      style: GoogleFonts.poppins(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [salon['location_city'], salon['location_state']]
                          .where((e) => e != null)
                          .join(', '),
                      style: GoogleFonts.nunito(
                          fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              if (rating != null && rating > 0) ...[
                Icon(Icons.star_rounded,
                    size: 16, color: Colors.amber.shade600),
                const SizedBox(width: 2),
                Text(
                  rating.toStringAsFixed(1),
                  style: GoogleFonts.nunito(
                      fontSize: 13, fontWeight: FontWeight.w700),
                ),
                if (ratingCount != null)
                  Text(' ($ratingCount)',
                      style: GoogleFonts.nunito(
                          fontSize: 11, color: Colors.grey)),
              ],
              const SizedBox(width: AppConstants.paddingXS),
              const Icon(Icons.chevron_right_rounded, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  Nearby Unvisited
  // ══════════════════════════════════════════════════════════════════════════

  void _showNearbyUnvisited(Map<String, dynamic> salon) {
    final salonsAsync = ref.read(rpAssignedSalonsProvider);
    final salons = salonsAsync.valueOrNull ?? [];

    final salonLat = (salon['latitude'] as num?)?.toDouble();
    final salonLng = (salon['longitude'] as num?)?.toDouble();
    if (salonLat == null || salonLng == null) {
      ToastService.showWarning('Este salon no tiene coordenadas.');
      return;
    }

    final unvisited = salons
        .where((s) =>
            s['rp_status'] == 'assigned' &&
            s['id'] != salon['id'] &&
            s['latitude'] != null &&
            s['longitude'] != null)
        .toList();

    if (unvisited.isEmpty) {
      ToastService.showSuccess('No hay salones sin visitar cercanos.');
      return;
    }

    final withDistance = unvisited.map((s) {
      final d = _haversineKm(
        salonLat,
        salonLng,
        (s['latitude'] as num).toDouble(),
        (s['longitude'] as num).toDouble(),
      );
      return MapEntry(s, d);
    }).toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    final top5 = withDistance.take(5).toList();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppConstants.radiusLG)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingLG),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(
                      bottom: AppConstants.paddingMD),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text('Salones cercanos sin visitar',
                  style: GoogleFonts.poppins(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: AppConstants.paddingSM),
              ...top5.map((entry) {
                final s = entry.key;
                final km = entry.value;
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Color(0xFF2196F3),
                      shape: BoxShape.circle,
                    ),
                  ),
                  title: Text(s['business_name'] ?? 'Sin nombre',
                      style: GoogleFonts.poppins(
                          fontSize: 14, fontWeight: FontWeight.w500)),
                  subtitle: Text(
                    [s['location_city'], s['location_state']]
                        .where((e) => e != null)
                        .join(', '),
                    style: GoogleFonts.nunito(fontSize: 12),
                  ),
                  trailing: Text(
                    km < 1
                        ? '${(km * 1000).round()} m'
                        : '${km.toStringAsFixed(1)} km',
                    style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.primary),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push(AppRoutes.rpCentro, extra: s);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
