import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/theme.dart';
import '../models/curate_result.dart';
import '../services/location_service.dart';
import '../services/supabase_client.dart';

// WhatsApp-inspired colors
const waGreen = Color(0xFF075E54);
const waLightGreen = Color(0xFF25D366);
const waCardTint = Color(0xFFDCF8C6);

/// Provider that fetches nearby discovered salons.
final nearbySalonsProvider =
    FutureProvider.family<List<DiscoveredSalon>, ({double lat, double lng, int limit, String? serviceQuery})>(
  (ref, params) async {
    final body = <String, dynamic>{
      'action': 'list',
      'lat': params.lat,
      'lng': params.lng,
      'radius_km': 50,
      'limit': params.limit,
    };
    if (params.serviceQuery != null && params.serviceQuery!.isNotEmpty) {
      body['service_query'] = params.serviceQuery;
    }

    final response =
        await SupabaseClientService.client.functions.invoke(
      'outreach-discovered-salon',
      body: body,
    );

    final data = response.data as Map<String, dynamic>;
    final salons = (data['salons'] as List?) ?? [];
    return salons
        .map((s) => DiscoveredSalon.fromJson(s as Map<String, dynamic>))
        .toList();
  },
);

class InviteSalonScreen extends ConsumerStatefulWidget {
  const InviteSalonScreen({super.key});

  @override
  ConsumerState<InviteSalonScreen> createState() =>
      _InviteSalonScreenState();
}

class _InviteSalonScreenState extends ConsumerState<InviteSalonScreen> {
  String _searchQuery = '';
  final Set<String> _invitedIds = {};
  LatLng? _userLocation;
  bool _locationLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  Future<void> _fetchLocation() async {
    final location = await LocationService.getCurrentLocation();
    if (!mounted) return;
    setState(() {
      _userLocation = location;
      _locationLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final salonsAsync = _userLocation != null
        ? ref.watch(
            nearbySalonsProvider((lat: _userLocation!.lat, lng: _userLocation!.lng, limit: 50, serviceQuery: null)),
          )
        : null;

    return Scaffold(
      backgroundColor: waGreen,
      appBar: AppBar(
        backgroundColor: waGreen,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Estilistas cerca de ti',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontSize: 17,
          ),
        ),
      ),
      body: Column(
        children: [
          // Subtitle
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: BeautyCitaTheme.spaceLG,
            ),
            child: Text(
              'que aún no están en BeautyCita',
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: Colors.white70,
              ),
            ),
          ),
          const SizedBox(height: BeautyCitaTheme.spaceSM),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: BeautyCitaTheme.spaceMD,
            ),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              style: GoogleFonts.nunito(fontSize: 14, color: Colors.black87),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre...',
                hintStyle: GoogleFonts.nunito(
                    fontSize: 14, color: Colors.grey),
                prefixIcon:
                    const Icon(Icons.search, size: 20, color: Colors.grey),
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: BeautyCitaTheme.spaceMD),

          // Content area
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFECE5DD), // WhatsApp chat background
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(BeautyCitaTheme.radiusLarge),
                ),
              ),
              child: _locationLoading
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: waLightGreen),
                          const SizedBox(height: 16),
                          Text(
                            'Obteniendo tu ubicacion...',
                            style: GoogleFonts.nunito(
                              fontSize: 14,
                              color: BeautyCitaTheme.textLight,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _userLocation == null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(BeautyCitaTheme.spaceLG),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.location_off_rounded,
                                    size: 48, color: waGreen),
                                const SizedBox(height: 16),
                                Text(
                                  'Activa el GPS para ver estilistas cerca de ti',
                                  style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: BeautyCitaTheme.textDark,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    setState(() => _locationLoading = true);
                                    _fetchLocation();
                                  },
                                  icon: const Icon(Icons.refresh, size: 18),
                                  label: const Text('Reintentar'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: waLightGreen,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : salonsAsync!.when(
                data: (salons) {
                  final filtered = _searchQuery.isEmpty
                      ? salons
                      : salons
                          .where((s) => s.name
                              .toLowerCase()
                              .contains(_searchQuery.toLowerCase()))
                          .toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        'No se encontraron estilistas',
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          color: BeautyCitaTheme.textLight,
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: [
                      // Count header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          BeautyCitaTheme.spaceLG,
                          BeautyCitaTheme.spaceMD,
                          BeautyCitaTheme.spaceLG,
                          BeautyCitaTheme.spaceSM,
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${filtered.length} estilistas en tu zona',
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              color: BeautyCitaTheme.textLight,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: BeautyCitaTheme.spaceMD,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (context, i) => _SalonCard(
                            salon: filtered[i],
                            invited: _invitedIds.contains(filtered[i].id),
                            onInvite: () => _handleInvite(filtered[i]),
                          ),
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(color: waLightGreen),
                ),
                error: (e, _) => Center(
                  child: Padding(
                    padding:
                        const EdgeInsets.all(BeautyCitaTheme.spaceLG),
                    child: Text(
                      'Error: $e',
                      style: GoogleFonts.nunito(
                        color: BeautyCitaTheme.textLight,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleInvite(DiscoveredSalon salon) async {
    setState(() => _invitedIds.add(salon.id));

    // 1. Open WhatsApp with pre-filled message
    final phone = salon.whatsapp ?? salon.phone;
    if (phone != null) {
      final message = Uri.encodeComponent(
        'Hola! Soy clienta tuya y me encantaría poder reservar '
        'contigo desde BeautyCita. Es gratis para ti y te llegan '
        'clientes nuevos. Registrate en 60 seg: '
        'https://beautycita.com/salon/${salon.id}',
      );
      final waUrl = Uri.parse('https://wa.me/${phone.replaceAll('+', '')}?text=$message');
      launchUrl(waUrl, mode: LaunchMode.externalApplication);
    }

    // 2. Record interest signal (fire and forget)
    SupabaseClientService.client.functions.invoke(
      'outreach-discovered-salon',
      body: {
        'action': 'invite',
        'discovered_salon_id': salon.id,
      },
    );
  }
}

class _SalonCard extends StatelessWidget {
  final DiscoveredSalon salon;
  final bool invited;
  final VoidCallback onInvite;

  const _SalonCard({
    required this.salon,
    required this.invited,
    required this.onInvite,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: invited ? waCardTint : Colors.white,
        borderRadius: BorderRadius.circular(BeautyCitaTheme.radiusMedium),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Photo / avatar
            ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: salon.photoUrl != null
                  ? Image.network(
                      salon.photoUrl!,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _defaultAvatar(),
                    )
                  : _defaultAvatar(),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    salon.name,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: BeautyCitaTheme.textDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (salon.rating != null) ...[
                        Icon(Icons.star,
                            size: 14,
                            color: BeautyCitaTheme.secondaryGold),
                        const SizedBox(width: 2),
                        Text(
                          salon.rating!.toStringAsFixed(1),
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: BeautyCitaTheme.textDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (salon.distanceKm != null)
                        Text(
                          '${salon.distanceKm!.toStringAsFixed(1)} km',
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            color: BeautyCitaTheme.textLight,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Invite button
            ElevatedButton.icon(
              onPressed: invited ? null : onInvite,
              icon: Icon(
                invited ? Icons.check : Icons.chat,
                size: 16,
              ),
              label: Text(
                invited ? 'ENVIADO' : 'INVITAR',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: invited ? Colors.grey[300] : waLightGreen,
                foregroundColor: invited ? Colors.grey[600] : Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                minimumSize: const Size(0, 36),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _defaultAvatar() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: waGreen.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.store, color: waGreen, size: 24),
    );
  }
}

/// Strip non-Latin characters from scraped data
String _sanitizeLatin(String text) {
  return text.replaceAll(
    RegExp(r'[^\u0000-\u024F\u1E00-\u1EFF\u2000-\u206F\u2070-\u209F\u20A0-\u20CF\u2100-\u214F\s]'),
    '',
  ).trim();
}

String? _sanitizeLatinNullable(String? text) => text != null ? _sanitizeLatin(text) : null;

class DiscoveredSalon {
  final String id;
  final String name;
  final String? phone;
  final String? whatsapp;
  final String? address;
  final String? city;
  final String? photoUrl;
  final double? rating;
  final int? reviewsCount;
  final int interestCount;
  final double? distanceKm;

  const DiscoveredSalon({
    required this.id,
    required this.name,
    this.phone,
    this.whatsapp,
    this.address,
    this.city,
    this.photoUrl,
    this.rating,
    this.reviewsCount,
    required this.interestCount,
    this.distanceKm,
  });

  factory DiscoveredSalon.fromJson(Map<String, dynamic> json) {
    return DiscoveredSalon(
      id: json['id'] as String,
      name: _sanitizeLatin(json['name'] as String),
      phone: json['phone'] as String?,
      whatsapp: json['whatsapp'] as String?,
      address: _sanitizeLatinNullable(json['address'] as String?),
      city: _sanitizeLatinNullable(json['city'] as String?),
      photoUrl: json['photo_url'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      reviewsCount: json['reviews_count'] as int?,
      interestCount: json['interest_count'] as int? ?? 0,
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
    );
  }
}
