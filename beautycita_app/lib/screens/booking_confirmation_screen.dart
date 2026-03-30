import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/constants.dart';
import '../config/theme_extension.dart';
import '../models/booking.dart';
import '../providers/booking_detail_provider.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Booking Confirmation Screen
//
// Shown after a successful booking. Displays summary, salon address,
// calendar/Uber actions, and receipt reference.
// ═══════════════════════════════════════════════════════════════════════════

class BookingConfirmationScreen extends ConsumerStatefulWidget {
  final String bookingId;
  const BookingConfirmationScreen({super.key, required this.bookingId});

  @override
  ConsumerState<BookingConfirmationScreen> createState() =>
      _BookingConfirmationScreenState();
}

class _BookingConfirmationScreenState
    extends ConsumerState<BookingConfirmationScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _checkController;
  late final Animation<double> _checkScale;
  late final Animation<double> _checkFade;

  @override
  void initState() {
    super.initState();
    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _checkScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _checkController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );
    _checkFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _checkController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );
    _checkController.forward();
  }

  @override
  void dispose() {
    _checkController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime dt) {
    final formatter = DateFormat("EEEE d 'de' MMMM, HH:mm", 'es');
    final formatted = formatter.format(dt);
    return formatted[0].toUpperCase() + formatted.substring(1);
  }

  String _paymentLabel(String? method) {
    switch (method) {
      case 'card':
        return 'Tarjeta';
      case 'oxxo':
        return 'OXXO';
      case 'cash':
      case 'cash_direct':
        return 'Efectivo';
      default:
        return method ?? 'No especificado';
    }
  }

  Future<void> _addToCalendar(Booking booking) async {
    // Use system calendar intent
    final start = booking.scheduledAt;
    final end = booking.endsAt ?? start.add(Duration(minutes: booking.durationMinutes));
    final title = '${booking.serviceName} - ${booking.providerName ?? "BeautyCita"}';

    // Try Google Calendar intent, fallback to generic calendar URI
    final uri = Uri.parse(
      'https://www.google.com/calendar/event?action=TEMPLATE'
      '&text=${Uri.encodeComponent(title)}'
      '&dates=${_calendarDate(start)}/${_calendarDate(end)}'
      '&details=${Uri.encodeComponent("Reservado con BeautyCita\nRef: ${booking.id.substring(0, 8).toUpperCase()}")}',
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _calendarDate(DateTime dt) {
    final utc = dt.toUtc();
    return '${utc.year}${utc.month.toString().padLeft(2, '0')}'
        '${utc.day.toString().padLeft(2, '0')}T'
        '${utc.hour.toString().padLeft(2, '0')}'
        '${utc.minute.toString().padLeft(2, '0')}00Z';
  }

  Future<void> _openUber(Booking booking) async {
    // Deep link to Uber with salon as destination
    final uri = Uri.parse(
      'uber://?action=setPickup&pickup=my_location',
    );
    final webUri = Uri.parse('https://m.uber.com/ul/');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (await canLaunchUrl(webUri)) {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookingAsync = ref.watch(bookingDetailProvider(widget.bookingId));
    final palette = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<BCThemeExtension>()!;

    return Scaffold(
      backgroundColor: palette.surface,
      body: bookingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.paddingLG),
            child: Text(
              'Error al cargar: $err',
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (booking) {
          if (booking == null) {
            return Center(
              child: Text(
                'Cita no encontrada',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: palette.onSurface.withValues(alpha: 0.5),
                    ),
              ),
            );
          }

          final refNumber = booking.id.length >= 8
              ? booking.id.substring(0, 8).toUpperCase()
              : booking.id.toUpperCase();

          return SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.screenPaddingHorizontal,
                vertical: AppConstants.paddingLG,
              ),
              child: Column(
                children: [
                  const SizedBox(height: AppConstants.paddingXL),

                  // -- Animated checkmark --
                  AnimatedBuilder(
                    animation: _checkController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _checkFade.value,
                        child: Transform.scale(
                          scale: _checkScale.value,
                          child: child,
                        ),
                      );
                    },
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withValues(alpha: 0.2),
                            blurRadius: 20,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.check_circle_rounded,
                        size: 64,
                        color: Colors.green.shade600,
                      ),
                    ),
                  ),

                  const SizedBox(height: AppConstants.paddingMD),

                  // -- Header --
                  Text(
                    'Cita Confirmada!',
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: palette.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ref: $refNumber',
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: palette.onSurface.withValues(alpha: 0.4),
                      letterSpacing: 1.5,
                    ),
                  ),

                  const SizedBox(height: AppConstants.paddingLG),

                  // -- Summary Card --
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppConstants.paddingMD),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusMD),
                      border: Border.all(
                          color: ext.cardBorderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _detailRow(
                          Icons.content_cut_outlined,
                          palette.primary,
                          'Servicio',
                          booking.serviceName,
                        ),
                        _divider(),
                        _detailRow(
                          Icons.store_outlined,
                          palette.secondary,
                          'Salon',
                          booking.providerName ?? 'Proveedor',
                        ),
                        _divider(),
                        _detailRow(
                          Icons.schedule_outlined,
                          Colors.blue.shade600,
                          'Fecha y hora',
                          _formatDate(booking.scheduledAt),
                        ),
                        _divider(),
                        _detailRow(
                          Icons.timer_outlined,
                          Colors.teal.shade600,
                          'Duracion',
                          '${booking.durationMinutes} min',
                        ),
                        if (booking.price != null) ...[
                          _divider(),
                          _detailRow(
                            Icons.payments_outlined,
                            Colors.green.shade600,
                            'Precio',
                            '\$${booking.price!.toStringAsFixed(0)} MXN',
                          ),
                        ],
                        _divider(),
                        _detailRow(
                          Icons.credit_card_outlined,
                          Colors.purple.shade600,
                          'Metodo de pago',
                          _paymentLabel(booking.paymentMethod),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppConstants.paddingMD),

                  // -- Location placeholder --
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppConstants.paddingMD),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusMD),
                      border: Border.all(
                          color: ext.cardBorderColor),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: palette.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.location_on_outlined,
                            color: palette.primary,
                            size: AppConstants.iconSizeMD,
                          ),
                        ),
                        const SizedBox(width: AppConstants.paddingSM),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                booking.providerName ?? 'Salon',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Ver ubicacion en el detalle de la cita',
                                style: GoogleFonts.nunito(
                                  fontSize: 12,
                                  color: palette.onSurface
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppConstants.paddingLG),

                  // -- Action buttons --
                  _gradientButton(
                    icon: Icons.calendar_month_rounded,
                    label: 'Agregar al Calendario',
                    gradient: ext.primaryGradient,
                    onTap: () => _addToCalendar(booking),
                  ),

                  if (booking.transportMode == 'uber') ...[
                    const SizedBox(height: AppConstants.paddingSM),
                    _solidButton(
                      icon: Icons.local_taxi_rounded,
                      label: 'Programar Uber',
                      color: Colors.black,
                      onTap: () => _openUber(booking),
                    ),
                  ],

                  const SizedBox(height: AppConstants.paddingSM),

                  // View booking detail
                  _outlineButton(
                    icon: Icons.map_outlined,
                    label: 'Ver Detalle y Ruta',
                    onTap: () =>
                        context.push('/appointment/${booking.id}'),
                  ),

                  const SizedBox(height: AppConstants.paddingLG),

                  // -- Volver al inicio --
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      context.go('/home');
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: AppConstants.paddingMD),
                      decoration: BoxDecoration(
                        gradient: ext.goldGradientDirectional(),
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusLG),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFD4AF37)
                                .withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'VOLVER AL INICIO',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: const Color(0xFF1A1400),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: AppConstants.paddingXL),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Helpers ──

  Widget _detailRow(
      IconData icon, Color iconColor, String label, String value) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(vertical: AppConstants.paddingSM - 2),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: AppConstants.iconSizeSM, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: const Color(0xFFAAAAAA),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1a1a1a),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => const Divider(
        height: 12,
        thickness: 1,
        color: Color(0xFFF5F0EB),
      );

  Widget _gradientButton({
    required IconData icon,
    required String label,
    required LinearGradient gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(AppConstants.radiusLG),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _solidButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppConstants.radiusLG),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _outlineButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final palette = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppConstants.radiusLG),
          border: Border.all(color: palette.primary, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: palette.primary),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: palette.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
