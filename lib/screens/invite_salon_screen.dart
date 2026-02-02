import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/theme.dart';
import '../services/supabase_client.dart';

// WhatsApp-inspired colors
const _waGreen = Color(0xFF075E54);
const _waLightGreen = Color(0xFF25D366);
const _waCardTint = Color(0xFFDCF8C6);

/// Provider that fetches nearby discovered salons.
final _nearbySalonsProvider =
    FutureProvider.family<List<_DiscoveredSalon>, ({double lat, double lng})>(
  (ref, coords) async {
    final response =
        await SupabaseClientService.client.functions.invoke(
      'outreach-discovered-salon',
      body: {
        'action': 'list',
        'lat': coords.lat,
        'lng': coords.lng,
        'radius_km': 50,
      },
    );

    final data = response.data as Map<String, dynamic>;
    final salons = (data['salons'] as List?) ?? [];
    return salons
        .map((s) => _DiscoveredSalon.fromJson(s as Map<String, dynamic>))
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

  // Default to Guadalajara center — will be replaced with user's actual location
  static const _defaultLat = 20.6597;
  static const _defaultLng = -103.3496;

  @override
  Widget build(BuildContext context) {
    final salonsAsync = ref.watch(
      _nearbySalonsProvider((lat: _defaultLat, lng: _defaultLng)),
    );

    return Scaffold(
      backgroundColor: _waGreen,
      appBar: AppBar(
        backgroundColor: _waGreen,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
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
              child: salonsAsync.when(
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
                  child: CircularProgressIndicator(color: _waLightGreen),
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

  Future<void> _handleInvite(_DiscoveredSalon salon) async {
    setState(() => _invitedIds.add(salon.id));

    // 1. Open WhatsApp with pre-filled message
    final phone = salon.whatsapp ?? salon.phone;
    if (phone != null) {
      final message = Uri.encodeComponent(
        'Hola! Soy clienta tuya y me encantaría poder reservar '
        'contigo desde BeautyCita. Es gratis para ti y te llegan '
        'clientes nuevos. Regístrate en 60 seg: '
        'https://beautycita.com/registro?ref=${salon.id}',
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
  final _DiscoveredSalon salon;
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
        color: invited ? _waCardTint : Colors.white,
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
                backgroundColor: invited ? Colors.grey[300] : _waLightGreen,
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
        color: _waGreen.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.store, color: _waGreen, size: 24),
    );
  }
}

class _DiscoveredSalon {
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

  const _DiscoveredSalon({
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

  factory _DiscoveredSalon.fromJson(Map<String, dynamic> json) {
    return _DiscoveredSalon(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      whatsapp: json['whatsapp'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      photoUrl: json['photo_url'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      reviewsCount: json['reviews_count'] as int?,
      interestCount: json['interest_count'] as int? ?? 0,
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
    );
  }
}
