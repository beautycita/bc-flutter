import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/theme.dart';
import '../services/supabase_client.dart';
import 'invite_salon_screen.dart' show DiscoveredSalon, waGreen, waLightGreen;

/// Strip non-standard-Latin characters (keeps Latin letters, digits, punctuation, spaces)
String _sanitize(String text) {
  // Keep: Basic Latin, Latin-1 Supplement, Latin Extended-A/B, common punctuation, digits, spaces
  return text.replaceAll(RegExp(r'[^\u0000-\u024F\u1E00-\u1EFF\u2000-\u206F\u2070-\u209F\u20A0-\u20CF\u2100-\u214F\s]'), '').trim();
}

class DiscoveredSalonDetailScreen extends StatelessWidget {
  final DiscoveredSalon salon;

  const DiscoveredSalonDetailScreen({super.key, required this.salon});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFECE5DD),
      appBar: AppBar(
        backgroundColor: waGreen,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _sanitize(salon.name),
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontSize: 17,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Hero section
            Container(
              width: double.infinity,
              color: waGreen,
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Column(
                children: [
                  // Avatar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(50),
                    child: salon.photoUrl != null
                        ? Image.network(
                            salon.photoUrl!,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _defaultAvatar(),
                          )
                        : _defaultAvatar(),
                  ),
                  const SizedBox(height: 16),
                  // Name
                  Text(
                    _sanitize(salon.name),
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  // Rating + reviews + distance row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (salon.rating != null) ...[
                        const Icon(Icons.star, size: 18, color: BeautyCitaTheme.secondaryGold),
                        const SizedBox(width: 4),
                        Text(
                          salon.rating!.toStringAsFixed(1),
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        if (salon.reviewsCount != null) ...[
                          const SizedBox(width: 4),
                          Text(
                            '(${_formatReviewCount(salon.reviewsCount!)})',
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                        const SizedBox(width: 16),
                      ],
                      if (salon.distanceKm != null) ...[
                        const Icon(Icons.location_on_outlined, size: 16, color: Colors.white70),
                        const SizedBox(width: 2),
                        Text(
                          '${salon.distanceKm!.toStringAsFixed(1)} km',
                          style: GoogleFonts.nunito(
                            fontSize: 13,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Content cards
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Location card
                  if (salon.address != null || salon.city != null)
                    _InfoCard(
                      icon: Icons.storefront_rounded,
                      title: 'Ubicacion',
                      child: Text(
                        _sanitize([salon.address, salon.city].where((s) => s != null).join(', ')),
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          color: BeautyCitaTheme.textDark,
                        ),
                      ),
                    ),

                  const SizedBox(height: 12),

                  // About card with narrative
                  _InfoCard(
                    icon: Icons.info_outline_rounded,
                    title: 'Acerca de este estilista',
                    child: Text(
                      _buildNarrative(),
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        color: BeautyCitaTheme.textDark,
                        height: 1.5,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // BC pitch card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: waLightGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(BeautyCitaTheme.radiusMedium),
                      border: Border.all(color: waLightGreen.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.favorite_rounded, size: 18, color: waGreen),
                            const SizedBox(width: 8),
                            Text(
                              'Ayudanos a traerlos',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: waGreen,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Nos encantaria tener a este estilista en la red de BeautyCita '
                          'para organizar sus citas y promover su servicio a mas personas. '
                          'Enviale una invitacion por WhatsApp para que se registre gratis.',
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            color: BeautyCitaTheme.textDark,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // INVITAR button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _handleInvite(),
                      icon: const Icon(Icons.chat, size: 20),
                      label: Text(
                        'INVITAR POR WHATSAPP',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: waLightGreen,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(BeautyCitaTheme.radiusMedium),
                        ),
                      ),
                    ),
                  ),

                  if (salon.interestCount > 0) ...[
                    const SizedBox(height: 12),
                    Text(
                      '${salon.interestCount} personas han pedido que se una',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        color: BeautyCitaTheme.textLight,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _defaultAvatar() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.store, color: Colors.white, size: 48),
    );
  }

  String _buildNarrative() {
    final parts = <String>[];

    // Rating narrative
    if (salon.rating != null && salon.reviewsCount != null) {
      final ratingDesc = salon.rating! >= 4.5
          ? 'excelente'
          : salon.rating! >= 4.0
              ? 'muy buena'
              : 'buena';
      parts.add(
        'Tiene una calificacion $ratingDesc de '
        '${salon.rating!.toStringAsFixed(1)} estrellas '
        'con ${_formatReviewCount(salon.reviewsCount!)} resenas.',
      );
    } else if (salon.rating != null) {
      parts.add(
        'Tiene una calificacion de ${salon.rating!.toStringAsFixed(1)} estrellas.',
      );
    }

    // Location narrative
    if (salon.address != null) {
      parts.add('Su salon se encuentra en ${salon.address}.');
    } else if (salon.city != null) {
      parts.add('Se encuentra en ${salon.city}.');
    }

    // Distance narrative
    if (salon.distanceKm != null) {
      if (salon.distanceKm! < 5) {
        parts.add('Esta muy cerca de ti, a solo ${salon.distanceKm!.toStringAsFixed(1)} km.');
      } else {
        parts.add('Esta a ${salon.distanceKm!.toStringAsFixed(1)} km de tu ubicacion.');
      }
    }

    if (parts.isEmpty) {
      parts.add('Este es un estilista en tu zona que aun no esta en BeautyCita.');
    }

    return parts.join(' ');
  }

  String _formatReviewCount(int count) {
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return count.toString();
  }

  void _handleInvite() {
    final phone = salon.whatsapp ?? salon.phone;
    if (phone != null) {
      final message = Uri.encodeComponent(
        'Hola! Soy clienta tuya y me encantaria poder reservar '
        'contigo desde BeautyCita. Es gratis para ti y te llegan '
        'clientes nuevos. Registrate en 60 seg: '
        'https://beautycita.com/supabase/functions/v1/salon-registro?ref=${salon.id}',
      );
      final waUrl = Uri.parse('https://wa.me/${phone.replaceAll('+', '')}?text=$message');
      launchUrl(waUrl, mode: LaunchMode.externalApplication);
    }

    // Record interest signal (fire and forget)
    SupabaseClientService.client.functions.invoke(
      'outreach-discovered-salon',
      body: {
        'action': 'invite',
        'discovered_salon_id': salon.id,
      },
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(BeautyCitaTheme.radiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: waGreen),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: BeautyCitaTheme.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
