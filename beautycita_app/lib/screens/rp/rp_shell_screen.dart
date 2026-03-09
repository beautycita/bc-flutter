import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:url_launcher/url_launcher.dart';

import 'package:beautycita/config/constants.dart';
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
        // Gray if no interest
        final interest = salon['interest_level'];
        if (interest == null || interest == 0) return const Color(0xFF9E9E9E);
        return const Color(0xFFFF9800);
      case 'assigned':
      default:
        return const Color(0xFF2196F3);
    }
  }

  static String _statusLabel(String? status) {
    switch (status) {
      case 'onboarding_complete':
        return 'Onboarding Completo';
      case 'visited':
        return 'Visitado';
      case 'assigned':
        return 'Sin Visitar';
      default:
        return status ?? 'Desconocido';
    }
  }

  // ── Haversine distance in km ──
  static double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLng = (lng2 - lng1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
            sin(dLng / 2) * sin(dLng / 2);
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
                  Icon(Icons.lock_outline, size: 64,
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
                  onTap: () => _showSalonDetailSheet(salon),
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
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
        // Group salons
        final unvisited = <Map<String, dynamic>>[];
        final followUp = <Map<String, dynamic>>[];
        final complete = <Map<String, dynamic>>[];
        final noInterest = <Map<String, dynamic>>[];

        for (final s in salons) {
          final status = s['rp_status'] as String?;
          if (status == 'onboarding_complete') {
            complete.add(s);
          } else if (status == 'visited') {
            noInterest.add(s);
          } else {
            unvisited.add(s);
          }
        }

        // We'll separate visited into follow-up vs no-interest later via visits
        // For now, use a simple heuristic: visited salons are in "followUp" if they
        // aren't gray (no interest). Since we don't have interest_level on
        // discovered_salons directly, all 'visited' go to follow-up by default.
        // The admin pipeline sets rp_status, and interest is tracked per visit.
        // Move all visited to followUp for now — the detail sheet shows full history.
        followUp.addAll(noInterest);
        noInterest.clear();

        if (salons.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.assignment_outlined, size: 64,
                    color: Colors.grey.shade400),
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
              _buildSection('Sin Visitar', const Color(0xFF2196F3), unvisited),
            if (followUp.isNotEmpty)
              _buildSection('Visitados — Seguimiento', const Color(0xFFFF9800), followUp),
            if (complete.isNotEmpty)
              _buildSection('Onboarding Completo', const Color(0xFF4CAF50), complete),
            if (noInterest.isNotEmpty)
              _buildSection('Sin Interes', const Color(0xFF9E9E9E), noInterest),
          ],
        );
      },
    );
  }

  Widget _buildSection(String title, Color color, List<Map<String, dynamic>> salons) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: AppConstants.paddingMD, bottom: AppConstants.paddingSM),
          child: Row(
            children: [
              Container(
                width: 12, height: 12,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: AppConstants.paddingSM),
              Text(title,
                  style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.w600, color: color)),
              const SizedBox(width: AppConstants.paddingSM),
              Text('(${salons.length})',
                  style: GoogleFonts.nunito(fontSize: 14, color: Colors.grey)),
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
        onTap: () => _showSalonDetailSheet(salon),
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingMD),
          child: Row(
            children: [
              Container(
                width: 10, height: 10,
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
  //  Bottom Sheet: Salon Detail
  // ══════════════════════════════════════════════════════════════════════════

  void _showSalonDetailSheet(Map<String, dynamic> salon) {
    final salonId = salon['id'] as String;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppConstants.radiusLG)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(AppConstants.paddingLG),
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: AppConstants.paddingMD),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Text(
                salon['business_name'] ?? 'Sin nombre',
                style: GoogleFonts.poppins(
                    fontSize: 22, fontWeight: FontWeight.w700),
              ),
              if (salon['location_address'] != null) ...[
                const SizedBox(height: 4),
                Text(
                  salon['location_address'],
                  style: GoogleFonts.nunito(
                      fontSize: 14, color: Colors.grey.shade600),
                ),
              ],

              const SizedBox(height: AppConstants.paddingMD),

              // Info section
              _buildInfoSection(salon),

              const SizedBox(height: AppConstants.paddingMD),

              // Links
              _buildLinksSection(salon),

              const SizedBox(height: AppConstants.paddingMD),

              // Phone / WhatsApp
              _buildPhoneSection(salon),

              const SizedBox(height: AppConstants.paddingMD),

              // Visit history
              _buildVisitHistory(salonId),

              const SizedBox(height: AppConstants.paddingLG),

              // Action buttons
              _buildActionButtons(salon),

              const SizedBox(height: AppConstants.paddingMD),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection(Map<String, dynamic> salon) {
    final rating = salon['rating_average'] as num?;
    final ratingCount = salon['rating_count'] as num?;
    final categories = salon['categories'];
    final hours = salon['working_hours'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (rating != null && rating > 0)
          Row(
            children: [
              ...List.generate(5, (i) => Icon(
                i < rating.round() ? Icons.star_rounded : Icons.star_border_rounded,
                size: 18,
                color: Colors.amber.shade600,
              )),
              const SizedBox(width: AppConstants.paddingXS),
              Text(rating.toStringAsFixed(1),
                  style: GoogleFonts.nunito(
                      fontSize: 14, fontWeight: FontWeight.w700)),
              if (ratingCount != null)
                Text(' ($ratingCount resenas)',
                    style: GoogleFonts.nunito(
                        fontSize: 13, color: Colors.grey.shade600)),
            ],
          ),
        if (categories != null) ...[
          const SizedBox(height: AppConstants.paddingSM),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: (categories is List ? categories : [categories])
                .map<Widget>((c) => Chip(
                      label: Text(c.toString(),
                          style: GoogleFonts.nunito(fontSize: 12)),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ))
                .toList(),
          ),
        ],
        if (hours != null) ...[
          const SizedBox(height: AppConstants.paddingSM),
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Expanded(
                child: Text(hours.toString(),
                    style: GoogleFonts.nunito(
                        fontSize: 13, color: Colors.grey.shade600)),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildLinksSection(Map<String, dynamic> salon) {
    final website = salon['website'] as String?;
    final facebook = salon['facebook_url'] as String?;
    final instagram = salon['instagram_url'] as String?;

    if (website == null && facebook == null && instagram == null) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        if (website != null)
          _linkChip(Icons.language_rounded, 'Web', website),
        if (facebook != null)
          _linkChip(Icons.facebook_rounded, 'Facebook', facebook),
        if (instagram != null)
          _linkChip(Icons.camera_alt_rounded, 'Instagram', instagram),
      ],
    );
  }

  Widget _linkChip(IconData icon, String label, String url) {
    return ActionChip(
      avatar: Icon(icon, size: 16),
      label: Text(label, style: GoogleFonts.nunito(fontSize: 12)),
      onPressed: () => launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildPhoneSection(Map<String, dynamic> salon) {
    final phone = salon['phone'] as String?;
    final whatsapp = salon['whatsapp'] as String?;

    if (phone == null && whatsapp == null) return const SizedBox.shrink();

    return Row(
      children: [
        if (phone != null)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => launchUrl(Uri.parse('tel:$phone')),
              icon: const Icon(Icons.phone_rounded, size: 18),
              label: Text(phone, style: GoogleFonts.nunito(fontSize: 13)),
            ),
          ),
        if (phone != null && whatsapp != null)
          const SizedBox(width: AppConstants.paddingSM),
        if (whatsapp != null)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => launchUrl(
                Uri.parse('https://wa.me/$whatsapp'),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.message_rounded, size: 18),
              label: Text('WhatsApp', style: GoogleFonts.nunito(fontSize: 13)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF25D366),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildVisitHistory(String salonId) {
    final visitsAsync = ref.watch(rpVisitsForSalonProvider(salonId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Historial de visitas',
            style: GoogleFonts.poppins(
                fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: AppConstants.paddingSM),
        visitsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(8),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (e, _) => Text('Error: $e'),
          data: (visits) {
            if (visits.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('Sin visitas registradas.',
                    style: GoogleFonts.nunito(
                        fontSize: 13, color: Colors.grey.shade500)),
              );
            }

            return Column(
              children: visits.map((v) {
                final date = v['visited_at'] as String?;
                final verbal = v['verbal_contact'] == true;
                final interest = v['interest_level'] as int?;
                final notes = v['notes'] as String?;
                final onboarding = v['onboarding_complete'] == true;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(AppConstants.paddingSM),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(AppConstants.radiusXS),
                    border: Border(
                      left: BorderSide(
                        color: onboarding
                            ? const Color(0xFF4CAF50)
                            : verbal
                                ? const Color(0xFFFF9800)
                                : const Color(0xFF2196F3),
                        width: 3,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (date != null)
                            Text(
                              _formatDate(date),
                              style: GoogleFonts.nunito(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey.shade600),
                            ),
                          const Spacer(),
                          if (verbal)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('Contacto verbal',
                                  style: GoogleFonts.nunito(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.orange.shade700)),
                            ),
                          if (onboarding) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('Onboarding',
                                  style: GoogleFonts.nunito(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.green.shade700)),
                            ),
                          ],
                        ],
                      ),
                      if (interest != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text('Interes: ',
                                style: GoogleFonts.nunito(fontSize: 12)),
                            ...List.generate(5, (i) => Icon(
                              i < interest
                                  ? Icons.circle
                                  : Icons.circle_outlined,
                              size: 10,
                              color: i < interest
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey.shade300,
                            )),
                            Text(' $interest/5',
                                style: GoogleFonts.nunito(
                                    fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ],
                      if (notes != null && notes.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(notes,
                            style: GoogleFonts.nunito(
                                fontSize: 12, color: Colors.grey.shade700)),
                      ],
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoDate;
    }
  }

  Widget _buildActionButtons(Map<String, dynamic> salon) {
    final lat = (salon['latitude'] as num?)?.toDouble();
    final lng = (salon['longitude'] as num?)?.toDouble();
    final name = salon['business_name'] ?? '';

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: lat != null && lng != null
                    ? () => launchUrl(
                          Uri.parse(
                              'geo:$lat,$lng?q=$lat,$lng(${Uri.encodeComponent(name)})'),
                          mode: LaunchMode.externalApplication,
                        )
                    : null,
                icon: const Icon(Icons.navigation_rounded, size: 18),
                label: const Text('Navegar'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      vertical: AppConstants.paddingSM),
                ),
              ),
            ),
            const SizedBox(width: AppConstants.paddingSM),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showNearbyUnvisited(salon),
                icon: const Icon(Icons.near_me_rounded, size: 18),
                label: const Text('Cercanos'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      vertical: AppConstants.paddingSM),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppConstants.paddingSM),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _showLogVisitDialog(salon),
            icon: const Icon(Icons.edit_note_rounded),
            label: const Text('Registrar Visita'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                  vertical: AppConstants.paddingSM + 2),
            ),
          ),
        ),
      ],
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

    // Calculate distances and sort
    final withDistance = unvisited.map((s) {
      final d = _haversineKm(
        salonLat, salonLng,
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
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: AppConstants.paddingMD),
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
                    width: 10, height: 10,
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
                    // Close the current detail sheet too, then open new one
                    Navigator.pop(context);
                    _showSalonDetailSheet(s);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  Log Visit Dialog
  // ══════════════════════════════════════════════════════════════════════════

  void _showLogVisitDialog(Map<String, dynamic> salon) {
    bool verbalContact = false;
    bool onboardingComplete = false;
    int interestLevel = 0;
    final notesController = TextEditingController();
    bool submitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Registrar visita',
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w600)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(salon['business_name'] ?? '',
                    style: GoogleFonts.nunito(
                        fontSize: 14, color: Colors.grey.shade600)),
                const SizedBox(height: AppConstants.paddingMD),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Contacto verbal con administrador?',
                      style: GoogleFonts.nunito(fontSize: 14)),
                  value: verbalContact,
                  onChanged: (v) => setDialogState(() {
                    verbalContact = v;
                    if (!v) onboardingComplete = false;
                  }),
                ),
                if (verbalContact)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Onboarding completo?',
                        style: GoogleFonts.nunito(fontSize: 14)),
                    value: onboardingComplete,
                    onChanged: (v) =>
                        setDialogState(() => onboardingComplete = v ?? false),
                  ),
                if (!onboardingComplete) ...[
                  const SizedBox(height: AppConstants.paddingSM),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Nivel de interes',
                          style: GoogleFonts.nunito(fontSize: 14)),
                      Text('$interestLevel',
                          style: GoogleFonts.poppins(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  Slider(
                    value: interestLevel.toDouble(),
                    min: 0,
                    max: 5,
                    divisions: 5,
                    label: '$interestLevel',
                    onChanged: (v) =>
                        setDialogState(() => interestLevel = v.round()),
                  ),
                ],
                const SizedBox(height: AppConstants.paddingSM),
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Notas (opcional)',
                    hintStyle: GoogleFonts.nunito(fontSize: 14),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: submitting
                  ? null
                  : () async {
                      setDialogState(() => submitting = true);
                      try {
                        final salonId = salon['id'] as String;
                        final assignmentId =
                            await getActiveAssignmentId(salonId);
                        if (assignmentId == null) {
                          ToastService.showError(
                              'No se encontro asignacion activa.');
                          setDialogState(() => submitting = false);
                          return;
                        }

                        await rpLogVisit(
                          assignmentId: assignmentId,
                          salonId: salonId,
                          verbalContact: verbalContact,
                          onboardingComplete: onboardingComplete,
                          interestLevel:
                              onboardingComplete ? null : interestLevel,
                          notes: notesController.text.trim().isEmpty
                              ? null
                              : notesController.text.trim(),
                        );

                        ref.invalidate(rpAssignedSalonsProvider);
                        ref.invalidate(rpVisitsForSalonProvider(salonId));

                        ToastService.showSuccess('Visita registrada.');
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) Navigator.pop(context);
                      } catch (e) {
                        ToastService.showError('Error: $e');
                        setDialogState(() => submitting = false);
                      }
                    },
              child: submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child:
                          CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
