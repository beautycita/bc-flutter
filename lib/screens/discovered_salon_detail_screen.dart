import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/theme.dart';
import '../services/supabase_client.dart';
import 'invite_salon_screen.dart' show DiscoveredSalon, waGreen, waLightGreen;

/// WhatsApp chat background color
const _waChatBg = Color(0xFFECE5DD);

/// Strip non-standard-Latin characters (keeps Latin letters, digits, punctuation, spaces)
String _sanitize(String text) {
  // Keep: Basic Latin, Latin-1 Supplement, Latin Extended-A/B, common punctuation, digits, spaces
  return text.replaceAll(RegExp(r'[^\u0000-\u024F\u1E00-\u1EFF\u2000-\u206F\u2070-\u209F\u20A0-\u20CF\u2100-\u214F\s]'), '').trim();
}

class DiscoveredSalonDetailScreen extends StatefulWidget {
  final DiscoveredSalon salon;

  const DiscoveredSalonDetailScreen({super.key, required this.salon});

  @override
  State<DiscoveredSalonDetailScreen> createState() => _DiscoveredSalonDetailScreenState();
}

class _DiscoveredSalonDetailScreenState extends State<DiscoveredSalonDetailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _breathingController;
  late Animation<double> _breathingAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _breathingAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(
        parent: _breathingController,
        curve: Curves.easeInOut,
      ),
    );
    _glowAnimation = Tween<double>(begin: 0.3, end: 0.6).animate(
      CurvedAnimation(
        parent: _breathingController,
        curve: Curves.easeInOut,
      ),
    );
    _breathingController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _breathingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _waChatBg,
      appBar: AppBar(
        backgroundColor: waGreen,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _sanitize(widget.salon.name),
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
            // Hero section with extended green background to prevent clipping
            Stack(
              clipBehavior: Clip.none,
              children: [
                // Green background that extends down
                Container(
                  width: double.infinity,
                  color: waGreen,
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 80),
                  child: Column(
                    children: [
                      // Avatar with shadow - not clipped
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 3,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(55),
                            child: widget.salon.photoUrl != null
                                ? Image.network(
                                    widget.salon.photoUrl!,
                                    width: 104,
                                    height: 104,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => _defaultAvatar(),
                                  )
                                : _defaultAvatar(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      // Name
                      Text(
                        _sanitize(widget.salon.name),
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      // Rating + reviews + distance row with pill background
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.salon.rating != null) ...[
                              const Icon(Icons.star, size: 18, color: BeautyCitaTheme.secondaryGold),
                              const SizedBox(width: 4),
                              Text(
                                widget.salon.rating!.toStringAsFixed(1),
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              if (widget.salon.reviewsCount != null) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '(${_formatReviewCount(widget.salon.reviewsCount!)})',
                                  style: GoogleFonts.nunito(
                                    fontSize: 13,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                              if (widget.salon.distanceKm != null)
                                Container(
                                  width: 1,
                                  height: 16,
                                  margin: const EdgeInsets.symmetric(horizontal: 12),
                                  color: Colors.white38,
                                ),
                            ],
                            if (widget.salon.distanceKm != null) ...[
                              const Icon(Icons.location_on_outlined, size: 16, color: Colors.white70),
                              const SizedBox(width: 4),
                              Text(
                                '${widget.salon.distanceKm!.toStringAsFixed(1)} km',
                                style: GoogleFonts.nunito(
                                  fontSize: 13,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Curved transition overlay
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: _waChatBg,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(BeautyCitaTheme.radiusLarge),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Content cards with shadows
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  // Location card
                  if (widget.salon.address != null || widget.salon.city != null)
                    _InfoCard(
                      icon: Icons.storefront_rounded,
                      title: 'Ubicacion',
                      child: Text(
                        _sanitize([widget.salon.address, widget.salon.city].where((s) => s != null).join(', ')),
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          color: BeautyCitaTheme.textDark,
                        ),
                      ),
                    ),

                  const SizedBox(height: 14),

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

                  const SizedBox(height: 14),

                  // Invite pitch card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(BeautyCitaTheme.radiusMedium),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: BeautyCitaTheme.primaryRose.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.send_rounded, size: 20, color: BeautyCitaTheme.primaryRose),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Invitalo a unirse',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: BeautyCitaTheme.textDark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Este estilista aun no acepta reservas por BeautyCita. '
                          'Mandales un mensaje y diles que quieres agendar con ellos desde la app. '
                          'Es gratis para ambos.',
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            color: BeautyCitaTheme.textLight,
                            height: 1.55,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Breathing INVITAR button - subtle glow
                  AnimatedBuilder(
                    animation: _breathingAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _breathingAnimation.value,
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(BeautyCitaTheme.radiusMedium),
                            boxShadow: [
                              BoxShadow(
                                color: waGreen.withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: () => _handleInvite(),
                            icon: const Icon(Icons.chat, size: 22),
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
                              elevation: 4,
                              shadowColor: waGreen,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(BeautyCitaTheme.radiusMedium),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  if (widget.salon.interestCount > 0) ...[
                    const SizedBox(height: 14),
                    Center(
                      child: Text(
                        '${widget.salon.interestCount} clientes esperando que se registre',
                        style: GoogleFonts.nunito(
                          fontSize: 13,
                          color: BeautyCitaTheme.textLight,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 28),
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
      width: 104,
      height: 104,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.store, color: Colors.white, size: 48),
    );
  }

  String _buildNarrative() {
    // Build an engaging, unique description based on available data
    final rating = widget.salon.rating;
    final reviews = widget.salon.reviewsCount;

    if (rating != null && reviews != null && reviews > 50) {
      if (rating >= 4.5) {
        return 'Uno de los favoritos de la zona con clientas muy satisfechas. '
               'Sus resenas hablan de atencion personalizada y resultados que superan expectativas.';
      } else if (rating >= 4.0) {
        return 'Estilista con buena reputacion entre sus clientas. '
               'Conocido por su profesionalismo y trato amable.';
      }
    }

    if (rating != null && rating >= 4.5) {
      return 'Altamente recomendado por quienes lo han visitado. '
             'Un profesional que se toma el tiempo para entender lo que buscas.';
    }

    if (rating != null && rating >= 4.0) {
      return 'Estilista confiable con clientas recurrentes. '
             'Ofrece un servicio consistente y de calidad.';
    }

    if (reviews != null && reviews > 20) {
      return 'Con una base de clientas establecida en la zona. '
             'Invitalo a BeautyCita para que puedas reservar facilmente.';
    }

    return 'Descubierto en tu zona. Aun no sabemos mucho de este estilista, '
           'pero podria ser justo lo que buscas. Invitalo a unirse.';
  }

  String _formatReviewCount(int count) {
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return count.toString();
  }

  void _handleInvite() {
    final phone = widget.salon.whatsapp ?? widget.salon.phone;
    if (phone != null) {
      final message = Uri.encodeComponent(
        'Hola! Soy clienta tuya y me encantaria poder reservar '
        'contigo desde BeautyCita. Es gratis para ti y te llegan '
        'clientes nuevos. Registrate en 60 seg: '
        'https://beautycita.com/salon/${widget.salon.id}',
      );
      final waUrl = Uri.parse('https://wa.me/${phone.replaceAll('+', '')}?text=$message');
      launchUrl(waUrl, mode: LaunchMode.externalApplication);
    }

    // Record interest signal (fire and forget)
    SupabaseClientService.client.functions.invoke(
      'outreach-discovered-salon',
      body: {
        'action': 'invite',
        'discovered_salon_id': widget.salon.id,
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(BeautyCitaTheme.radiusMedium),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: waGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: waGreen),
              ),
              const SizedBox(width: 12),
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
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
