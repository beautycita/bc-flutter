import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/constants.dart';
import '../models/curate_result.dart';
import '../providers/contact_match_provider.dart';
import '../providers/profile_provider.dart';
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
    // Trigger contact match check (uses cached if permission already granted)
    Future.microtask(() => ref.read(contactMatchProvider.notifier).checkPermission());
    // Prompt for name if missing — invites use the name, not the username
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkNamePrompt());
  }

  void _checkNamePrompt() {
    final profile = ref.read(profileProvider);
    if (profile.fullName == null || profile.fullName!.trim().isEmpty) {
      _showNamePrompt();
    }
  }

  void _showNamePrompt() {
    final controller = TextEditingController();
    final palette = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tu nombre',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: palette.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Las invitaciones se envian con tu nombre. Agrega tu nombre para que el salon sepa quien les invito.',
              style: GoogleFonts.nunito(
                fontSize: 14,
                color: palette.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'Ej: Samantha Lopez',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Omitir'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      final name = controller.text.trim();
                      if (name.isNotEmpty) {
                        ref.read(profileProvider.notifier).updateFullName(name);
                      }
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: palette.primary,
                      foregroundColor: palette.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Guardar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
            nearbySalonsProvider((lat: _userLocation!.lat, lng: _userLocation!.lng, limit: 20, serviceQuery: null)),
          )
        : null;

    return Scaffold(
      backgroundColor: waGreen,
      appBar: AppBar(
        backgroundColor: waGreen,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: Theme.of(context).colorScheme.onPrimary, size: 24),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Estilistas cerca de ti',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onPrimary,
            fontSize: 17,
          ),
        ),
      ),
      body: Column(
        children: [
          // Subtitle
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.paddingLG,
            ),
            child: Text(
              'que aún no están en BeautyCita',
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7),
              ),
            ),
          ),
          const SizedBox(height: AppConstants.paddingSM),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.paddingMD,
            ),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              style: GoogleFonts.nunito(fontSize: 14, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.87)),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre...',
                hintStyle: GoogleFonts.nunito(
                    fontSize: 14, color: Colors.grey),
                prefixIcon:
                    const Icon(Icons.search, size: 20, color: Colors.grey),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
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
          const SizedBox(height: AppConstants.paddingMD),

          // Content area
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFECE5DD), // WhatsApp chat background
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(AppConstants.radiusLG),
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
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _userLocation == null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(AppConstants.paddingLG),
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
                                    color: Theme.of(context).colorScheme.onSurface,
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
                                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    );
                  }

                  return Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.paddingMD,
                      ),
                      children: [
                        // ── Contact matches section ──
                        _ContactMatchesSection(
                          invitedIds: _invitedIds,
                          onInvite: _handleContactInvite,
                        ),
                        // ── Nearby salons header ──
                        Padding(
                          padding: const EdgeInsets.only(
                            left: AppConstants.paddingSM,
                            top: AppConstants.paddingSM,
                            bottom: AppConstants.paddingSM,
                          ),
                          child: Text(
                            '${filtered.length} estilistas en tu zona',
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                        // ── Nearby salon cards ──
                        ...filtered.map((s) => _SalonCard(
                              salon: s,
                              invited: _invitedIds.contains(s.id),
                              onInvite: () => _handleInvite(s),
                            )),
                      ],
                    ),
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(color: waLightGreen),
                ),
                error: (e, _) => Center(
                  child: Padding(
                    padding:
                        const EdgeInsets.all(AppConstants.paddingLG),
                    child: Text(
                      'Error: $e',
                      style: GoogleFonts.nunito(
                        color: Theme.of(context).colorScheme.onSurface,
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
      // Point directly to salon-registro edge function — self-contained HTML
      // registration page that fetches all salon data server-side from the ref ID.
      final regUrl = Uri.https(
        'beautycita.com',
        '/registro',
        {'ref': salon.id},
      );
      final message = Uri.encodeComponent(
        'Hola! Queria hacer una cita contigo pero no te encontre '
        'en BeautyCita. Deberias estar ahi, te llegan mas clientes '
        'y es gratis: $regUrl '
        'Manana te busco en la app si no ando muy ocupada!',
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

  Future<void> _handleContactInvite(EnrichedMatch match) async {
    setState(() => _invitedIds.add(match.salonId));

    final phone = match.matchedPhone;
    final regUrl = Uri.https(
      'beautycita.com',
      '/registro',
      {'ref': match.salonId},
    );
    final message = Uri.encodeComponent(
      'Hola! Queria hacer una cita contigo pero no te encontre '
      'en BeautyCita. Deberias estar ahi, te llegan mas clientes '
      'y es gratis: $regUrl '
      'Manana te busco en la app si no ando muy ocupada!',
    );
    final waUrl = Uri.parse('https://wa.me/${phone.replaceAll('+', '')}?text=$message');
    launchUrl(waUrl, mode: LaunchMode.externalApplication);

    // Record interest signal
    SupabaseClientService.client.functions.invoke(
      'outreach-discovered-salon',
      body: {
        'action': 'invite',
        'discovered_salon_id': match.salonId,
      },
    );
  }
}

// ── Contact Matches Section ──

class _ContactMatchesSection extends ConsumerWidget {
  final Set<String> invitedIds;
  final Future<void> Function(EnrichedMatch) onInvite;

  const _ContactMatchesSection({
    required this.invitedIds,
    required this.onInvite,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchState = ref.watch(contactMatchProvider);

    // Only show discovered (unregistered) salons — those are the ones to invite
    final discoveredMatches = matchState.matches
        .where((m) => m.salonType == 'd' && !invitedIds.contains(m.salonId))
        .toList();

    // Idle state — show subtle CTA to enable contact matching
    if (matchState.step == ContactMatchStep.idle) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: Theme.of(context).colorScheme.onPrimary,
          borderRadius: BorderRadius.circular(AppConstants.radiusMD),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppConstants.radiusMD),
            onTap: () => ref.read(contactMatchProvider.notifier).requestAndScan(),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: waLightGreen.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.people_outline, color: waGreen, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tus salones favoritos',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          'Encuentra salones que ya conoces e invitalos',
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Scanning state
    if (matchState.step == ContactMatchStep.scanning ||
        matchState.step == ContactMatchStep.requesting) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.onPrimary,
            borderRadius: BorderRadius.circular(AppConstants.radiusMD),
          ),
          child: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: waLightGreen),
              ),
              const SizedBox(width: 12),
              Text(
                'Buscando salones que ya conoces...',
                style: GoogleFonts.nunito(fontSize: 13, color: Theme.of(context).colorScheme.onSurface),
              ),
            ],
          ),
        ),
      );
    }

    // Denied or error — don't show anything
    if (matchState.step == ContactMatchStep.denied ||
        matchState.step == ContactMatchStep.error) {
      return const SizedBox.shrink();
    }

    // Loaded but no discovered matches — nothing to show
    if (discoveredMatches.isEmpty) {
      return const SizedBox.shrink();
    }

    // Show matched salons
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppConstants.paddingSM,
            top: AppConstants.paddingMD,
            bottom: AppConstants.paddingSM,
          ),
          child: Text(
            'Ya te conocen pero aún no están aquí',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: waGreen,
            ),
          ),
        ),
        ...discoveredMatches.map((match) => _ContactMatchCard(
              match: match,
              invited: invitedIds.contains(match.salonId),
              onInvite: () => onInvite(match),
            )),
        const SizedBox(height: 8),
        Divider(color: Colors.grey.shade300, height: 1),
      ],
    );
  }
}

class _ContactMatchCard extends StatelessWidget {
  final EnrichedMatch match;
  final bool invited;
  final VoidCallback onInvite;

  const _ContactMatchCard({
    required this.match,
    required this.invited,
    required this.onInvite,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: invited ? waCardTint : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(
          color: waLightGreen.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Avatar
            ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: match.salonPhoto != null
                  ? Image.network(
                      match.salonPhoto!,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _defaultAvatar(),
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
                    match.salonName,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.person_outline, size: 13, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          match.contactName,
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (match.salonRating != null) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.star, size: 14, color: Theme.of(context).colorScheme.secondary),
                        const SizedBox(width: 2),
                        Text(
                          match.salonRating!.toStringAsFixed(1),
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Invite button
            ElevatedButton.icon(
              onPressed: invited ? null : onInvite,
              icon: Icon(invited ? Icons.check : Icons.chat, size: 16),
              label: Text(
                invited ? 'ENVIADO' : 'INVITAR',
                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: invited ? Colors.grey[300] : waLightGreen,
                foregroundColor: invited ? Colors.grey[600] : Theme.of(context).colorScheme.onPrimary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
        color: invited ? waCardTint : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
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
                      errorBuilder: (_, _, _) => _defaultAvatar(),
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
                      color: Theme.of(context).colorScheme.onSurface,
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
                            color: Theme.of(context).colorScheme.secondary),
                        const SizedBox(width: 2),
                        Text(
                          salon.rating!.toStringAsFixed(1),
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (salon.distanceKm != null)
                        Text(
                          '${salon.distanceKm!.toStringAsFixed(1)} km',
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface,
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
                foregroundColor: invited ? Colors.grey[600] : Theme.of(context).colorScheme.onPrimary,
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
  final String? generatedBio;

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
    this.generatedBio,
  });

  factory DiscoveredSalon.fromJson(Map<String, dynamic> json) {
    // Support both old and new column names for compatibility
    return DiscoveredSalon(
      id: json['id'] as String,
      name: _sanitizeLatin((json['business_name'] ?? json['name'] ?? '') as String),
      phone: json['phone'] as String?,
      whatsapp: json['whatsapp'] as String?,
      address: _sanitizeLatinNullable((json['location_address'] ?? json['address']) as String?),
      city: _sanitizeLatinNullable((json['location_city'] ?? json['city']) as String?),
      photoUrl: (json['feature_image_url'] ?? json['photo_url']) as String?,
      rating: ((json['rating_average'] ?? json['rating']) as num?)?.toDouble(),
      reviewsCount: (json['rating_count'] ?? json['reviews_count']) as int?,
      interestCount: json['interest_count'] as int? ?? 0,
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      generatedBio: json['generated_bio'] as String?,
    );
  }
}
