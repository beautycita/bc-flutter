import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:beautycita/config/constants.dart';
import 'package:beautycita/config/theme_extension.dart';
import 'package:beautycita/models/booking.dart';
import 'package:beautycita/providers/booking_provider.dart';
import 'package:beautycita/services/supabase_client.dart';
import 'package:go_router/go_router.dart';
import 'package:beautycita/services/toast_service.dart';

/// Disputes for the current user, keyed by appointment_id.
final userDisputesProvider =
    FutureProvider<Map<String, Map<String, dynamic>>>((ref) async {
  final userId = SupabaseClientService.currentUserId;
  if (userId == null) return {};
  final response = await SupabaseClientService.client
      .from('disputes')
      .select()
      .eq('user_id', userId)
      .order('created_at', ascending: false);
  final list = (response as List).cast<Map<String, dynamic>>();
  // Key by appointment_id for quick lookup
  final map = <String, Map<String, dynamic>>{};
  for (final d in list) {
    final apptId = d['appointment_id'] as String?;
    if (apptId != null && !map.containsKey(apptId)) {
      map[apptId] = d;
    }
  }
  return map;
});

/// Filter tabs for the user's bookings list.
enum _BookingTab { proximas, pasadas, canceladas }

class MyBookingsScreen extends ConsumerStatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  ConsumerState<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends ConsumerState<MyBookingsScreen> {
  _BookingTab _activeTab = _BookingTab.proximas;

  /// Return label text for each tab.
  String _tabLabel(_BookingTab tab) {
    switch (tab) {
      case _BookingTab.proximas:
        return 'Próximas';
      case _BookingTab.pasadas:
        return 'Pasadas';
      case _BookingTab.canceladas:
        return 'Canceladas';
    }
  }

  bool _isCancelled(String status) =>
      status == 'cancelled_customer' || status == 'cancelled_business';

  /// Filter bookings client-side based on the active tab.
  List<Booking> _filterBookings(List<Booking> bookings) {
    final now = DateTime.now();

    switch (_activeTab) {
      case _BookingTab.proximas:
        return bookings
            .where((b) =>
                !_isCancelled(b.status) &&
                b.scheduledAt.isAfter(now))
            .toList()
          ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
      case _BookingTab.pasadas:
        return bookings
            .where((b) =>
                !_isCancelled(b.status) &&
                (b.scheduledAt.isBefore(now) || b.status == 'completed'))
            .toList()
          ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
      case _BookingTab.canceladas:
        return bookings
            .where((b) => _isCancelled(b.status))
            .toList()
          ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
    }
  }

  /// Format a DateTime in Spanish, e.g. "Lunes 3 de febrero, 14:00".
  String _formatDate(DateTime dt) {
    final formatter = DateFormat("EEEE d 'de' MMMM, HH:mm", 'es');
    final formatted = formatter.format(dt);
    // Capitalize the first letter (day name).
    return formatted[0].toUpperCase() + formatted.substring(1);
  }

  /// Color for a status chip.
  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.amber.shade700;
      case 'confirmed':
        return Colors.green.shade600;
      case 'completed':
        return Colors.blue.shade600;
      case 'cancelled_customer':
      case 'cancelled_business':
        return Colors.red.shade600;
      case 'no_show':
        return Colors.grey.shade600;
      default:
        return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);
    }
  }

  /// Display label for a status.
  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Pendiente';
      case 'confirmed':
        return 'Confirmada';
      case 'completed':
        return 'Completada';
      case 'cancelled_customer':
        return 'Cancelada';
      case 'cancelled_business':
        return 'Cancelada por salon';
      case 'no_show':
        return 'No asistio';
      default:
        return status;
    }
  }

  /// Empty-state message per tab.
  String _emptyMessage() {
    switch (_activeTab) {
      case _BookingTab.proximas:
        return 'No tienes citas próximas';
      case _BookingTab.pasadas:
        return 'No tienes citas pasadas';
      case _BookingTab.canceladas:
        return 'No tienes citas canceladas';
    }
  }

  /// Show a confirmation bottom sheet before cancelling.
  Future<void> _cancelBooking(Booking booking) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppConstants.radiusXL)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.paddingLG,
              AppConstants.paddingMD,
              AppConstants.paddingLG,
              AppConstants.paddingLG,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppConstants.paddingMD),
                Icon(
                  Icons.cancel_outlined,
                  size: AppConstants.iconSizeXL,
                  color: Colors.red.shade400,
                ),
                const SizedBox(height: AppConstants.paddingSM),
                Text(
                  'Cancelar esta cita?',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: AppConstants.paddingXS),
                Text(
                  'Se cancelara tu cita de ${booking.serviceName}.'
                  '${booking.transportMode == 'uber' ? ' Tambien se cancelaran tus viajes de Uber.' : ''}',
                  style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppConstants.paddingLG),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: OutlinedButton.styleFrom(
                          minimumSize:
                              const Size(0, AppConstants.minTouchHeight),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                AppConstants.radiusLG),
                          ),
                        ),
                        child: const Text('No, mantener'),
                      ),
                    ),
                    const SizedBox(width: AppConstants.paddingSM),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade500,
                          minimumSize:
                              const Size(0, AppConstants.minTouchHeight),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                AppConstants.radiusLG),
                          ),
                        ),
                        child: const Text(
                          'Si, cancelar',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed == true) {
      try {
        final repo = ref.read(bookingRepositoryProvider);
        await repo.cancelBooking(booking.id);

        // Refresh data.
        ref.invalidate(userBookingsProvider);
        ref.invalidate(upcomingBookingsProvider);

        ToastService.showSuccess(AppConstants.successBookingCancelled);
      } catch (e, stack) {
        ToastService.showErrorWithDetails(ToastService.friendlyError(e), e, stack);
      }
    }
  }

  /// Open a dispute filing bottom sheet for a completed booking.
  Future<void> _openDispute(Booking booking) async {
    final reasonCtrl = TextEditingController();
    String selectedReason = 'Servicio de mala calidad';

    final reasons = [
      'Servicio de mala calidad',
      'Servicio no realizado',
      'Cobro incorrecto',
      'Tiempo de espera excesivo',
      'Otro',
    ];

    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppConstants.radiusXL)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                AppConstants.paddingLG,
                AppConstants.paddingMD,
                AppConstants.paddingLG,
                MediaQuery.of(ctx).viewInsets.bottom + AppConstants.paddingLG,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppConstants.paddingMD),
                  Text(
                    'Reportar problema',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    booking.serviceName,
                    style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(ctx)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5),
                        ),
                  ),
                  const SizedBox(height: AppConstants.paddingMD),
                  Text('Razon',
                      style: Theme.of(ctx).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          )),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: reasons.map((r) {
                      final isSelected = r == selectedReason;
                      return ChoiceChip(
                        label: Text(r),
                        selected: isSelected,
                        onSelected: (_) =>
                            setSheetState(() => selectedReason = r),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppConstants.paddingMD),
                  Text('Detalles (opcional)',
                      style: Theme.of(ctx).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          )),
                  const SizedBox(height: 8),
                  TextField(
                    controller: reasonCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Describe el problema...',
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusMD),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppConstants.paddingLG),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade700,
                        minimumSize:
                            const Size(0, AppConstants.minTouchHeight),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppConstants.radiusLG),
                        ),
                      ),
                      child: const Text(
                        'Enviar reporte',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (submitted == true) {
      try {
        final userId = SupabaseClientService.currentUserId;
        if (userId == null) throw Exception('No autenticado');

        final reason = selectedReason +
            (reasonCtrl.text.trim().isNotEmpty
                ? ': ${reasonCtrl.text.trim()}'
                : '');

        await SupabaseClientService.client.from('disputes').insert({
          'appointment_id': booking.id,
          'user_id': userId,
          'business_id': booking.businessId,
          'reason': reason,
          'status': 'open',
        });

        ToastService.showSuccess('Reporte enviado. Te contactaremos pronto.');
      } catch (e, stack) {
        ToastService.showErrorWithDetails(ToastService.friendlyError(e), e, stack);
      }
    }

    reasonCtrl.dispose();
  }

  /// Show the salon's offer and let the client accept or reject.
  Future<void> _showDisputeOffer(Map<String, dynamic> dispute) async {
    final salonOffer = dispute['salon_offer'] as String? ?? '';
    final salonOfferAmount = dispute['salon_offer_amount'] as num?;
    final salonResponse = dispute['salon_response'] as String? ?? '';
    final disputeId = dispute['id'] as String;

    final offerLabel = switch (salonOffer) {
      'full_refund' => 'Reembolso total',
      'partial_refund' => 'Reembolso parcial',
      'denied' => 'Reembolso negado',
      _ => salonOffer,
    };
    final offerColor = switch (salonOffer) {
      'full_refund' => Colors.green,
      'partial_refund' => Colors.orange,
      'denied' => Colors.red,
      _ => Colors.grey,
    };

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppConstants.radiusXL)),
      ),
      builder: (ctx) {
        bool saving = false;
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                AppConstants.paddingLG,
                AppConstants.paddingMD,
                AppConstants.paddingLG,
                MediaQuery.of(ctx).viewInsets.bottom + AppConstants.paddingLG,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppConstants.paddingMD),
                  Text(
                    'Respuesta del salon',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: AppConstants.paddingMD),

                  // Offer type
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: offerColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                      border: Border.all(color: offerColor.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.local_offer_rounded,
                                size: 18, color: offerColor),
                            const SizedBox(width: 6),
                            Text(offerLabel,
                                style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: offerColor)),
                          ],
                        ),
                        if (salonOffer == 'partial_refund' &&
                            salonOfferAmount != null) ...[
                          const SizedBox(height: 6),
                          Text(
                              '\$${salonOfferAmount.toStringAsFixed(0)} MXN',
                              style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800)),
                        ],
                        if (salonResponse.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(salonResponse,
                              style: GoogleFonts.nunito(fontSize: 14)),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: AppConstants.paddingLG),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: saving
                              ? null
                              : () async {
                                  setSheetState(() => saving = true);
                                  try {
                                    await _rejectOffer(disputeId);
                                    if (ctx.mounted) Navigator.pop(ctx);
                                  } catch (e, stack) {
                                    ToastService.showErrorWithDetails(ToastService.friendlyError(e), e, stack);
                                  } finally {
                                    if (ctx.mounted) {
                                      setSheetState(() => saving = false);
                                    }
                                  }
                                },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.shade600,
                            side: BorderSide(color: Colors.red.shade300),
                            minimumSize:
                                const Size(0, AppConstants.minTouchHeight),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  AppConstants.radiusLG),
                            ),
                          ),
                          child: const Text('Rechazar y escalar',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(width: AppConstants.paddingSM),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: saving
                              ? null
                              : () async {
                                  setSheetState(() => saving = true);
                                  try {
                                    await _acceptOffer(
                                        disputeId, salonOffer, salonOfferAmount);
                                    if (ctx.mounted) Navigator.pop(ctx);
                                  } catch (e, stack) {
                                    ToastService.showErrorWithDetails(ToastService.friendlyError(e), e, stack);
                                  } finally {
                                    if (ctx.mounted) {
                                      setSheetState(() => saving = false);
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            minimumSize:
                                const Size(0, AppConstants.minTouchHeight),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  AppConstants.radiusLG),
                            ),
                          ),
                          child: Text(
                            salonOffer == 'denied'
                                ? 'Aceptar decision'
                                : 'Aceptar oferta',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Show resolution result for a completed dispute.
  void _showDisputeResult(Map<String, dynamic> dispute) {
    final resolution = dispute['resolution'] as String?;
    final resolutionNotes = dispute['resolution_notes'] as String?;
    final refundAmount = dispute['refund_amount'] as num?;
    final refundStatus = dispute['refund_status'] as String?;
    final resolvedAt = dispute['resolved_at'] as String?;
    final salonOffer = dispute['salon_offer'] as String?;
    final salonResponse = dispute['salon_response'] as String?;
    final salonOfferAmount = dispute['salon_offer_amount'] as num?;
    final status = dispute['status'] as String?;

    // Translate
    final (String resLabel, Color resColor, IconData resIcon) = switch (resolution) {
      'favor_client' => ('A favor tuyo', Colors.green, Icons.check_circle_rounded),
      'favor_provider' => ('A favor del salon', Colors.blue, Icons.store_rounded),
      'favor_both' => ('A favor de ambos', Colors.teal, Icons.handshake_rounded),
      'dismissed' => ('Descartada', Colors.grey, Icons.cancel_outlined),
      _ => ('Resuelta', Colors.green, Icons.check_circle_rounded),
    };

    final offerLabel = switch (salonOffer) {
      'full_refund' => 'Reembolso total',
      'partial_refund' => 'Reembolso parcial',
      'denied' => 'Reembolso negado',
      _ => null,
    };

    final refundStatusLabel = switch (refundStatus) {
      'pending' => 'Pendiente',
      'processed' => 'Procesado',
      'failed' => 'Fallido',
      _ => null,
    };

    String? resolvedDate;
    if (resolvedAt != null) {
      final dt = DateTime.tryParse(resolvedAt)?.toLocal();
      if (dt != null) {
        resolvedDate = '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
    }

    // Summary text
    String summary;
    if (resolution == 'favor_client') {
      if (refundAmount != null && refundAmount > 0) {
        summary = 'Tu disputa se resolvio a tu favor. Se proceso un reembolso de \$${refundAmount.toStringAsFixed(0)} MXN.';
      } else {
        summary = 'Tu disputa se resolvio a tu favor.';
      }
    } else if (resolution == 'favor_provider') {
      summary = 'La disputa se resolvio a favor del salon. No se proceso reembolso.';
    } else if (resolution == 'favor_both') {
      summary = 'La disputa se resolvio a favor de ambas partes.';
    } else if (resolution == 'dismissed') {
      summary = 'La disputa fue descartada.';
    } else if (status == 'rejected') {
      summary = 'La disputa fue rechazada.';
    } else {
      summary = 'La disputa fue resuelta.';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppConstants.radiusXL)),
      ),
      builder: (ctx) {
        final colors = Theme.of(ctx).colorScheme;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            AppConstants.paddingLG,
            AppConstants.paddingMD,
            AppConstants.paddingLG,
            MediaQuery.of(ctx).viewInsets.bottom + AppConstants.paddingLG,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppConstants.paddingMD),
              Text(
                'Resultado de la disputa',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: AppConstants.paddingMD),

              // Resolution header card
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: resColor.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: resColor.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: resColor.withValues(alpha: 0.08),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                      ),
                      child: Row(
                        children: [
                          Icon(resIcon, size: 18, color: resColor),
                          const SizedBox(width: 8),
                          Text(resLabel,
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: resColor,
                              )),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(summary,
                              style: GoogleFonts.nunito(
                                fontSize: 14,
                                color: colors.onSurface.withValues(alpha: 0.8),
                                height: 1.4,
                              )),
                          if (refundAmount != null && refundAmount > 0) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Icon(Icons.payments_rounded, size: 16,
                                    color: colors.onSurface.withValues(alpha: 0.4)),
                                const SizedBox(width: 6),
                                Text('\$${refundAmount.toStringAsFixed(0)} MXN',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    )),
                                if (refundStatusLabel != null) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: refundStatus == 'processed'
                                          ? Colors.green.withValues(alpha: 0.1)
                                          : refundStatus == 'failed'
                                              ? Colors.red.withValues(alpha: 0.1)
                                              : Colors.orange.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(refundStatusLabel,
                                        style: GoogleFonts.poppins(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: refundStatus == 'processed'
                                              ? Colors.green
                                              : refundStatus == 'failed'
                                                  ? Colors.red
                                                  : Colors.orange,
                                        )),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Salon's offer if applicable
              if (salonOffer != null && offerLabel != null) ...[
                const SizedBox(height: AppConstants.paddingMD),
                Text('Oferta del salon',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: colors.onSurface.withValues(alpha: 0.4),
                    )),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.onSurface.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(8),
                    border: Border(
                      left: BorderSide(
                          color: Colors.blue.withValues(alpha: 0.4), width: 3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(offerLabel +
                              (salonOfferAmount != null
                                  ? '  •  \$${salonOfferAmount.toStringAsFixed(0)} MXN'
                                  : ''),
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue,
                          )),
                      if (salonResponse != null && salonResponse.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(salonResponse,
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              color: colors.onSurface.withValues(alpha: 0.6),
                            )),
                      ],
                    ],
                  ),
                ),
              ],

              // Admin notes
              if (resolutionNotes != null && resolutionNotes.isNotEmpty) ...[
                const SizedBox(height: AppConstants.paddingMD),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.onSurface.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(8),
                    border: Border(
                      left: BorderSide(
                          color: Colors.deepPurple.withValues(alpha: 0.4), width: 3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Notas del administrador',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.deepPurple.withValues(alpha: 0.6),
                          )),
                      const SizedBox(height: 2),
                      Text(resolutionNotes,
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            color: colors.onSurface.withValues(alpha: 0.7),
                          )),
                    ],
                  ),
                ),
              ],

              // Resolved date
              if (resolvedDate != null) ...[
                const SizedBox(height: AppConstants.paddingSM),
                Row(
                  children: [
                    Icon(Icons.access_time_rounded, size: 12,
                        color: colors.onSurface.withValues(alpha: 0.3)),
                    const SizedBox(width: 4),
                    Text('Resuelto: $resolvedDate',
                        style: GoogleFonts.nunito(
                          fontSize: 11,
                          color: colors.onSurface.withValues(alpha: 0.4),
                        )),
                  ],
                ),
              ],

              const SizedBox(height: AppConstants.paddingLG),

              // Close button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, AppConstants.minTouchHeight),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusLG),
                    ),
                  ),
                  child: const Text('Cerrar'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _acceptOffer(
      String disputeId, String salonOffer, num? offerAmount) async {
    final now = DateTime.now().toIso8601String();
    final updateData = <String, dynamic>{
      'client_accepted': true,
      'client_responded_at': now,
      'status': 'resolved',
      'resolved_at': now,
    };

    if (salonOffer == 'partial_refund' && offerAmount != null) {
      updateData['refund_amount'] = offerAmount.toDouble();
      updateData['refund_status'] = 'pending';
      updateData['resolution'] = 'favor_client';
    } else if (salonOffer == 'denied') {
      updateData['resolution'] = 'favor_provider';
    } else {
      updateData['resolution'] = 'favor_client';
    }

    await SupabaseClientService.client
        .from('disputes')
        .update(updateData)
        .eq('id', disputeId);

    // If a refund is pending, process the actual Stripe refund (fire-and-forget)
    if (salonOffer == 'partial_refund' || salonOffer == 'full_refund') {
      SupabaseClientService.client.functions.invoke(
        'process-dispute-refund',
        body: {'dispute_id': disputeId},
      ).then((_) {
        debugPrint('Dispute refund processed for $disputeId');
      }).catchError((e) {
        debugPrint('Dispute refund failed for $disputeId: $e');
      });
    }

    ref.invalidate(userDisputesProvider);
    ref.invalidate(userBookingsProvider);

    ToastService.showSuccess('Oferta aceptada. Disputa resuelta.');
  }

  Future<void> _rejectOffer(String disputeId) async {
    final now = DateTime.now().toIso8601String();
    await SupabaseClientService.client.from('disputes').update({
      'client_accepted': false,
      'client_responded_at': now,
      'status': 'escalated',
      'escalated_at': now,
    }).eq('id', disputeId);

    // Notify admins
    final admins = await SupabaseClientService.client
        .from('profiles')
        .select('id')
        .inFilter('role', ['admin', 'superadmin']);
    for (final admin in (admins as List)) {
      await SupabaseClientService.client.from('notifications').insert({
        'user_id': admin['id'] as String,
        'title': 'Disputa escalada',
        'body': 'Cliente rechazo oferta del salon. Requiere tu atencion.',
        'channel': 'in_app',
      });
    }

    ref.invalidate(userDisputesProvider);
    ref.invalidate(userBookingsProvider);

    ToastService.showWarning('Disputa escalada a administracion. Te contactaremos pronto.');
  }

  @override
  Widget build(BuildContext context) {
    final bookingsAsync = ref.watch(userBookingsProvider);
    final disputesAsync = ref.watch(userDisputesProvider);
    final disputes = disputesAsync.valueOrNull ?? {};
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(),
      body: Column(
        children: [
          // -- Filter Chips --
          _buildFilterChips(textTheme),

          // -- Booking List --
          Expanded(
            child: bookingsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppConstants.paddingLG),
                  child: Text(
                    'Error al cargar citas: $err',
                    style: textTheme.bodyLarge?.copyWith(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              data: (allBookings) {
                final filtered = _filterBookings(allBookings);

                if (filtered.isEmpty) {
                  return _buildEmptyState(textTheme);
                }

                return RefreshIndicator(
                  color: colorScheme.primary,
                  onRefresh: () async {
                    ref.invalidate(userBookingsProvider);
                    ref.invalidate(userDisputesProvider);
                    await ref.read(userBookingsProvider.future);
                  },
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.screenPaddingHorizontal,
                      vertical: AppConstants.paddingMD,
                    ),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppConstants.paddingSM),
                    itemBuilder: (context, index) {
                      return _buildBookingCard(
                          filtered[index], textTheme, disputes);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(TextTheme textTheme) {
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<BCThemeExtension>()!;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.screenPaddingHorizontal,
        vertical: AppConstants.paddingSM,
      ),
      child: Row(
        children: _BookingTab.values.map((tab) {
          final isSelected = tab == _activeTab;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.paddingXS,
              ),
              child: GestureDetector(
                onTap: () => setState(() => _activeTab = tab),
                child: Container(
                  height: AppConstants.minTouchHeight - 8,
                  decoration: BoxDecoration(
                    gradient: ext.goldGradientDirectional(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius:
                        BorderRadius.circular(AppConstants.radiusMD),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: colorScheme.primary
                                  .withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(1.5),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.surface,
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusMD - 1.5),
                    ),
                    child: Text(
                      _tabLabel(tab),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelLarge?.copyWith(
                        color: isSelected
                            ? Colors.white
                            : colorScheme.onSurface,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState(TextTheme textTheme) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: AppConstants.iconSizeXXL,
              color: colorScheme.onSurface.withValues(alpha: 0.2),
            ),
            const SizedBox(height: AppConstants.paddingMD),
            Text(
              _emptyMessage(),
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingCard(Booking booking, TextTheme textTheme,
      Map<String, Map<String, dynamic>> disputes) {
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<BCThemeExtension>()!;
    final canCancel =
        booking.status == 'pending' || booking.status == 'confirmed';
    final dispute = disputes[booking.id];
    final disputeStatus = dispute?['status'] as String?;
    final hasActiveDispute = dispute != null && disputeStatus != 'resolved' && disputeStatus != 'rejected';
    final hasResolvedDispute = dispute != null && (disputeStatus == 'resolved' || disputeStatus == 'rejected');
    final hasSalonOffer = disputeStatus == 'salon_responded';

    return GestureDetector(
      onTap: () => context.push('/appointment/${booking.id}'),
      child: Container(
      decoration: BoxDecoration(
        gradient: ext.goldGradientDirectional(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Container(
      margin: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD - 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: provider name + status chip
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    booking.providerName ?? 'Proveedor',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppConstants.paddingSM),
                _buildStatusChip(booking.status, textTheme),
              ],
            ),

            const SizedBox(height: AppConstants.paddingXS),

            // Service name
            Text(
              booking.serviceName,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: AppConstants.paddingSM),

            // Date formatted in Spanish
            Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: AppConstants.iconSizeSM,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: AppConstants.paddingXS),
                Expanded(
                  child: Text(
                    _formatDate(booking.scheduledAt),
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            // Price if available
            if (booking.price != null) ...[
              const SizedBox(height: AppConstants.paddingXS),
              Row(
                children: [
                  Icon(
                    Icons.attach_money_rounded,
                    size: AppConstants.iconSizeSM,
                    color: colorScheme.primary,
                  ),
                  Text(
                    '\$${booking.price!.toStringAsFixed(0)} MXN',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],

            // Resolved dispute badge
            if (hasResolvedDispute) ...[
              const SizedBox(height: AppConstants.paddingSM),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (disputeStatus == 'resolved' ? Colors.green : Colors.red)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      disputeStatus == 'resolved'
                          ? Icons.check_circle_rounded
                          : Icons.block_rounded,
                      size: 14,
                      color: disputeStatus == 'resolved' ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      disputeStatus == 'resolved'
                          ? 'Disputa resuelta'
                          : 'Disputa rechazada',
                      style: textTheme.labelSmall?.copyWith(
                        color: disputeStatus == 'resolved' ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Active dispute badge
            if (hasActiveDispute) ...[
              const SizedBox(height: AppConstants.paddingSM),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (hasSalonOffer ? Colors.blue : Colors.orange)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      hasSalonOffer ? Icons.local_offer_rounded : Icons.gavel_rounded,
                      size: 14,
                      color: hasSalonOffer ? Colors.blue : Colors.orange,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      hasSalonOffer
                          ? 'El salon respondio - revisa la oferta'
                          : disputeStatus == 'escalated'
                              ? 'Disputa escalada - en revision'
                              : 'Disputa abierta',
                      style: textTheme.labelSmall?.copyWith(
                        color: hasSalonOffer ? Colors.blue : Colors.orange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Cancel button for pending / confirmed
            if (canCancel) ...[
              const SizedBox(height: AppConstants.paddingSM),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _cancelBooking(booking),
                  icon: const Icon(
                    Icons.cancel_outlined,
                    size: AppConstants.iconSizeSM,
                  ),
                  label: const Text('Cancelar'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red.shade600,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.paddingSM,
                    ),
                    minimumSize: const Size(0, AppConstants.minTouchHeight - 16),
                  ),
                ),
              ),
            ],

            // Dispute actions for completed bookings
            if (booking.status == 'completed') ...[
              const SizedBox(height: AppConstants.paddingSM),
              Align(
                alignment: Alignment.centerRight,
                child: hasSalonOffer
                    ? TextButton.icon(
                        onPressed: () => _showDisputeOffer(dispute!),
                        icon: Icon(
                          Icons.visibility_rounded,
                          size: AppConstants.iconSizeSM,
                          color: Colors.blue.shade700,
                        ),
                        label: Text('Ver oferta',
                            style: TextStyle(
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.w700)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppConstants.paddingSM,
                          ),
                          minimumSize:
                              const Size(0, AppConstants.minTouchHeight - 16),
                        ),
                      )
                    : hasResolvedDispute
                        ? TextButton.icon(
                            onPressed: () => _showDisputeResult(dispute!),
                            icon: Icon(
                              Icons.info_outline_rounded,
                              size: AppConstants.iconSizeSM,
                              color: Colors.green.shade700,
                            ),
                            label: Text('Ver resultado',
                                style: TextStyle(
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.w700)),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppConstants.paddingSM,
                              ),
                              minimumSize: const Size(
                                  0, AppConstants.minTouchHeight - 16),
                            ),
                          )
                        : dispute == null
                            ? TextButton.icon(
                                onPressed: () => _openDispute(booking),
                                icon: Icon(
                                  Icons.flag_outlined,
                                  size: AppConstants.iconSizeSM,
                                  color: Colors.orange.shade700,
                                ),
                                label: Text('Reportar problema',
                                    style: TextStyle(
                                        color: Colors.orange.shade700)),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppConstants.paddingSM,
                                  ),
                                  minimumSize: const Size(
                                      0, AppConstants.minTouchHeight - 16),
                                ),
                              )
                            : const SizedBox.shrink(),
              ),
            ],
          ],
        ),
      ),
      ),
    ),
    );
  }

  Widget _buildStatusChip(String status, TextTheme textTheme) {
    final color = _statusColor(status);
    final label = _statusLabel(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingSM + 4,
        vertical: AppConstants.paddingXS,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppConstants.radiusFull),
      ),
      child: Text(
        label,
        style: textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
