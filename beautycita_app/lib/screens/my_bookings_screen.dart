import 'package:flutter/foundation.dart';
import 'package:beautycita/config/app_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:beautycita/config/constants.dart';
import 'package:beautycita/config/theme_extension.dart';
import 'package:beautycita/models/booking.dart';
import 'package:beautycita/providers/booking_provider.dart';
import 'package:beautycita/providers/booking_flow_provider.dart'
    show bookingFlowProvider;
import 'package:beautycita_core/supabase.dart';
import 'package:beautycita/services/supabase_client.dart';
import 'package:go_router/go_router.dart';
import '../widgets/empty_state.dart';
import 'package:beautycita/services/toast_service.dart';
import 'package:beautycita/providers/order_provider.dart';
import 'package:beautycita_core/models.dart' show Order;

/// Disputes for the current user, keyed by appointment_id OR order_id.
final userDisputesProvider =
    FutureProvider<Map<String, Map<String, dynamic>>>((ref) async {
  final userId = SupabaseClientService.currentUserId;
  if (userId == null) return {};
  final response = await SupabaseClientService.client
      .from(BCTables.disputes)
      .select()
      .eq('user_id', userId)
      .order('created_at', ascending: false);
  final list = (response as List).cast<Map<String, dynamic>>();
  // Key by appointment_id or order_id for quick lookup
  final map = <String, Map<String, dynamic>>{};
  for (final d in list) {
    final apptId = d['appointment_id'] as String?;
    final orderId = d['order_id'] as String?;
    if (apptId != null && !map.containsKey(apptId)) {
      map[apptId] = d;
    }
    if (orderId != null && !map.containsKey(orderId)) {
      map[orderId] = d;
    }
  }
  return map;
});

/// Filter tabs for the user's bookings list.
enum _BookingTab { proximas, pasadas, canceladas, pedidos }

class MyBookingsScreen extends ConsumerStatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  ConsumerState<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends ConsumerState<MyBookingsScreen>
    with SingleTickerProviderStateMixin {
  _BookingTab _activeTab = _BookingTab.proximas;

  late final AnimationController _entryController;
  late final List<Animation<double>> _fadeAnims;
  late final List<Animation<Offset>> _slideAnims;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    const count = 2; // filter chips, booking list
    _fadeAnims = List.generate(count, (i) {
      final start = i * 0.12;
      final end = (start + 0.4).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _entryController,
        curve: Interval(start, end, curve: Curves.easeOut),
      );
    });
    _slideAnims = List.generate(count, (i) {
      final start = i * 0.12;
      final end = (start + 0.4).clamp(0.0, 1.0);
      return Tween<Offset>(
        begin: const Offset(0, 0.05),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _entryController,
        curve: Interval(start, end, curve: Curves.easeOut),
      ));
    });
    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  Widget _animated(int index, Widget child) {
    return FadeTransition(
      opacity: _fadeAnims[index],
      child: SlideTransition(
        position: _slideAnims[index],
        child: child,
      ),
    );
  }

  /// Return label text for each tab.
  String _tabLabel(_BookingTab tab) {
    switch (tab) {
      case _BookingTab.proximas:
        return 'Próximas';
      case _BookingTab.pasadas:
        return 'Pasadas';
      case _BookingTab.canceladas:
        return 'Canceladas';
      case _BookingTab.pedidos:
        return 'Pedidos';
    }
  }

  String? _cancellingBookingId;

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
      case _BookingTab.pedidos:
        return []; // Orders are handled separately, not through this filter
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
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<BCThemeExtension>()!;
    switch (status) {
      case 'pending':
        return Colors.amber.shade700;
      case 'confirmed':
        return ext.successColor;
      case 'completed':
        return Colors.blue.shade600;
      case 'cancelled_customer':
      case 'cancelled_business':
        return cs.error;
      case 'no_show':
        return cs.onSurface.withValues(alpha: 0.5);
      default:
        return cs.onSurface.withValues(alpha: 0.5);
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
      case _BookingTab.pedidos:
        return 'No tienes pedidos';
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
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppConstants.paddingMD),
                Icon(
                  Icons.cancel_outlined,
                  size: AppConstants.iconSizeXL,
                  color: Theme.of(context).colorScheme.error,
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
                          backgroundColor: Theme.of(context).colorScheme.error,
                          minimumSize:
                              const Size(0, AppConstants.minTouchHeight),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                AppConstants.radiusLG),
                          ),
                        ),
                        child: Text(
                          'Si, cancelar',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
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
      setState(() => _cancellingBookingId = booking.id);
      try {
        final repo = ref.read(bookingRepositoryProvider);
        final result = await repo.cancelBooking(booking.id);

        // Send cancel notification (fire-and-forget)
        SupabaseClientService.client.functions
            .invoke('cancel-notification', body: {'appointment_id': booking.id})
            .ignore();

        // Refresh data.
        ref.invalidate(userBookingsProvider);
        ref.invalidate(upcomingBookingsProvider);

        if (result.refundAmount > 0) {
          ToastService.showSuccess(
            'Cita cancelada — \$${result.refundAmount.toStringAsFixed(0)} a tu saldo'
            '${result.depositForfeited > 0 ? ' (deposito no reembolsable)' : ''}',
          );
        } else {
          ToastService.showSuccess(AppConstants.successBookingCancelled);
        }
        if (mounted) {
          await showShredderTransition(context);
        }
      } catch (e, stack) {
        ToastService.showErrorWithDetails(ToastService.friendlyError(e), e, stack);
      } finally {
        if (mounted) {
          setState(() => _cancellingBookingId = null);
        }
      }
    }
  }

  /// Rebook: pre-fill booking flow with same service and navigate.
  void _rebookBooking(Booking booking) {
    final notifier = ref.read(bookingFlowProvider.notifier);
    notifier.rebookFrom(booking);
    context.push('/book');
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
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
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
                        backgroundColor: Theme.of(context).extension<BCThemeExtension>()!.warningColor,
                        minimumSize:
                            const Size(0, AppConstants.minTouchHeight),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppConstants.radiusLG),
                        ),
                      ),
                      child: Text(
                        'Enviar reporte',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
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
      // Prompt user to add photo evidence before submitting
      final shouldContinue = await _promptForDisputePhotos();
      if (!shouldContinue) return;

      try {
        final userId = SupabaseClientService.currentUserId;
        if (userId == null) throw Exception('No autenticado');

        final reason = selectedReason +
            (reasonCtrl.text.trim().isNotEmpty
                ? ': ${reasonCtrl.text.trim()}'
                : '');

        await SupabaseClientService.client.from(BCTables.disputes).insert({
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

  /// Prompt user to add photos as evidence before submitting a dispute.
  /// Returns true to continue with submission, false to cancel (go back to add photos).
  Future<bool> _promptForDisputePhotos() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Evidencia fotografica'),
        content: const Text(
          'Quieres agregar fotos como evidencia? '
          'Las fotos ayudan a resolver tu caso mas rapido.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Enviar sin fotos',
              style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).extension<BCThemeExtension>()!.warningColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Agregar fotos', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
          ),
        ],
      ),
    );
    // true = send without photos, false/null = go back to add photos
    return result == true;
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
    final ext = Theme.of(context).extension<BCThemeExtension>()!;
    final offerColor = switch (salonOffer) {
      'full_refund' => ext.successColor,
      'partial_refund' => ext.warningColor,
      'denied' => Theme.of(context).colorScheme.error,
      _ => Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
    };

    await showBurstBottomSheet(
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
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
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
                            Icon(Icons.local_offer_outlined,
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
                            foregroundColor: Theme.of(context).colorScheme.error,
                            side: BorderSide(color: Theme.of(context).colorScheme.error.withValues(alpha: 0.5)),
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
                            backgroundColor: Theme.of(context).extension<BCThemeExtension>()!.successColor,
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
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary,
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
    final resExt = Theme.of(context).extension<BCThemeExtension>()!;
    final resCs = Theme.of(context).colorScheme;
    final (String resLabel, Color resColor, IconData resIcon) = switch (resolution) {
      'favor_client' => ('A favor tuyo', resExt.successColor, Icons.check_circle_outlined),
      'favor_provider' => ('A favor del salon', Colors.blue, Icons.store_outlined),
      'favor_both' => ('A favor de ambos', Colors.teal, Icons.handshake_outlined),
      'dismissed' => ('Descartada', resCs.onSurface.withValues(alpha: 0.4), Icons.cancel_outlined),
      _ => ('Resuelta', resExt.successColor, Icons.check_circle_outlined),
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

    showBurstBottomSheet(
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
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
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
                                Icon(Icons.payments_outlined, size: 16,
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
                                              ? resExt.successColor
                                              : refundStatus == 'failed'
                                                  ? resCs.error
                                                  : resExt.warningColor,
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
                    Icon(Icons.access_time_outlined, size: 12,
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
        .from(BCTables.disputes)
        .update(updateData)
        .eq('id', disputeId);

    // If a refund is pending, process the actual Stripe refund (fire-and-forget)
    if (salonOffer == 'partial_refund' || salonOffer == 'full_refund') {
      SupabaseClientService.client.functions.invoke(
        'process-dispute-refund',
        body: {'dispute_id': disputeId},
      ).then((_) {
        if (kDebugMode) debugPrint('Dispute refund processed for $disputeId');
      }).catchError((e) {
        if (kDebugMode) debugPrint('Dispute refund failed for $disputeId: $e');
      });
    }

    ref.invalidate(userDisputesProvider);
    ref.invalidate(userBookingsProvider);

    ToastService.showSuccess('Oferta aceptada. Disputa resuelta.');
  }

  Future<void> _rejectOffer(String disputeId) async {
    final now = DateTime.now().toIso8601String();
    await SupabaseClientService.client.from(BCTables.disputes).update({
      'client_accepted': false,
      'client_responded_at': now,
      'status': 'escalated',
      'escalated_at': now,
    }).eq('id', disputeId);

    // Notify admins
    final admins = await SupabaseClientService.client
        .from(BCTables.profiles)
        .select('id')
        .inFilter('role', ['admin', 'superadmin']);
    for (final admin in (admins as List)) {
      await SupabaseClientService.client.from(BCTables.notifications).insert({
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

  // ---------------------------------------------------------------------------
  // Orders tab (Pedidos)
  // ---------------------------------------------------------------------------

  Widget _buildOrdersContent(
    TextTheme textTheme,
    ColorScheme colorScheme,
    Map<String, Map<String, dynamic>> disputes,
  ) {
    final ordersAsync = ref.watch(buyerOrdersProvider);
    return ordersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingLG),
          child: Text(
            'Error al cargar pedidos: $err',
            style: textTheme.bodyLarge?.copyWith(color: colorScheme.error),
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (orders) {
        if (orders.isEmpty) return _buildEmptyState(textTheme);

        return RefreshIndicator(
          color: colorScheme.primary,
          onRefresh: () async {
            ref.invalidate(buyerOrdersProvider);
            ref.invalidate(userDisputesProvider);
            await ref.read(buyerOrdersProvider.future);
          },
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.screenPaddingHorizontal,
              vertical: AppConstants.paddingMD,
            ),
            itemCount: orders.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppConstants.paddingSM),
            itemBuilder: (context, index) => _buildOrderCard(orders[index], textTheme, disputes),
          ),
        );
      },
    );
  }

  Widget _buildOrderCard(Order order, TextTheme textTheme, Map<String, Map<String, dynamic>> disputes) {
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<BCThemeExtension>()!;
    final dispute = disputes[order.id];
    final hasDispute = dispute != null;
    final canDispute = order.isDelivered && !hasDispute;
    final formatter = DateFormat("d MMM yyyy", 'es');

    Color statusColor;
    String statusLabel;
    switch (order.status) {
      case 'paid':
        statusColor = Colors.amber.shade700;
        statusLabel = 'Pendiente envio';
      case 'shipped':
        statusColor = Colors.blue.shade600;
        statusLabel = 'Enviado';
      case 'delivered':
        statusColor = ext.successColor;
        statusLabel = 'Entregado';
      case 'refunded':
        statusColor = colorScheme.error;
        statusLabel = 'Reembolsado';
      case 'cancelled':
        statusColor = colorScheme.error;
        statusLabel = 'Cancelado';
      default:
        statusColor = colorScheme.onSurface.withValues(alpha: 0.5);
        statusLabel = order.status;
    }

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusLG),
        border: Border.all(color: ext.cardBorderColor),
      ),
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shopping_bag_outlined, size: 20, color: colorScheme.primary),
              const SizedBox(width: AppConstants.paddingXS),
              Expanded(
                child: Text(
                  order.productName,
                  style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppConstants.radiusSM),
                ),
                child: Text(
                  statusLabel,
                  style: textTheme.labelSmall?.copyWith(color: statusColor, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.paddingXS),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '\$${order.totalAmount.toStringAsFixed(2)} MXN',
                style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                formatter.format(order.createdAt),
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          if (order.trackingNumber != null) ...[
            const SizedBox(height: AppConstants.paddingXS),
            Text(
              'Guia: ${order.trackingNumber}',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
          if (order.isShippingUrgent && order.isPaid) ...[
            const SizedBox(height: AppConstants.paddingXS),
            Text(
              'Envio vence en ${order.shippingDeadlineDaysLeft} dias',
              style: textTheme.bodySmall?.copyWith(color: Colors.orange.shade700, fontWeight: FontWeight.w600),
            ),
          ],
          if (hasDispute) ...[
            const SizedBox(height: AppConstants.paddingSM),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppConstants.radiusSM),
              ),
              child: Text(
                'Disputa: ${dispute['status'] == 'resolved' ? 'Resuelta' : 'En proceso'}',
                style: textTheme.labelSmall?.copyWith(color: colorScheme.error),
              ),
            ),
          ],
          if (canDispute) ...[
            const SizedBox(height: AppConstants.paddingSM),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openOrderDispute(order),
                icon: const Icon(Icons.gavel, size: 16),
                label: const Text('Disputar pedido'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.error,
                  side: BorderSide(color: colorScheme.error.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusLG),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openOrderDispute(Order order) async {
    final reasons = [
      'Producto danado',
      'Producto incorrecto',
      'No recibi el producto',
      'Calidad diferente a la descripcion',
      'Otro',
    ];

    String? selectedReason;
    final detailsCtl = TextEditingController();

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppConstants.radiusXL)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheetState) {
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppConstants.paddingLG,
                AppConstants.paddingMD,
                AppConstants.paddingLG,
                MediaQuery.of(ctx).viewInsets.bottom + AppConstants.paddingLG,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppConstants.paddingMD),
                  Icon(Icons.gavel, size: AppConstants.iconSizeXL, color: Theme.of(ctx).colorScheme.error),
                  const SizedBox(height: AppConstants.paddingSM),
                  Text('Disputar pedido', style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: AppConstants.paddingXS),
                  Text(
                    order.productName,
                    style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: AppConstants.paddingMD),
                  ...reasons.map((r) => RadioListTile<String>(
                    value: r,
                    groupValue: selectedReason,
                    onChanged: (v) => setSheetState(() => selectedReason = v),
                    title: Text(r, style: Theme.of(ctx).textTheme.bodyMedium),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  )),
                  const SizedBox(height: AppConstants.paddingSM),
                  TextField(
                    controller: detailsCtl,
                    maxLines: 3,
                    maxLength: 500,
                    decoration: InputDecoration(
                      hintText: 'Detalles adicionales (opcional)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMD)),
                    ),
                  ),
                  const SizedBox(height: AppConstants.paddingMD),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: selectedReason == null
                          ? null
                          : () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(ctx).colorScheme.error,
                        foregroundColor: Theme.of(ctx).colorScheme.onError,
                        minimumSize: const Size(0, AppConstants.minTouchHeight),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppConstants.radiusLG),
                        ),
                      ),
                      child: const Text('Enviar disputa'),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );

    if (confirmed != true || selectedReason == null) return;

    final userId = SupabaseClientService.currentUserId;
    if (userId == null) return;

    try {
      await SupabaseClientService.client.from(BCTables.disputes).insert({
        'order_id': order.id,
        'user_id': userId,
        'business_id': order.businessId,
        'reason': selectedReason,
        'client_evidence': detailsCtl.text.trim().isEmpty ? null : detailsCtl.text.trim(),
        'status': 'open',
        'refund_amount': order.totalAmount,
        'refund_status': 'pending',
      });

      ref.invalidate(userDisputesProvider);
      ref.invalidate(buyerOrdersProvider);
      ToastService.showSuccess('Disputa enviada. Te notificaremos cuando haya una resolucion.');
    } catch (e) {
      if (kDebugMode) debugPrint('Order dispute failed: $e');
      ToastService.showError('Error al enviar disputa. Intenta de nuevo.');
    }
    detailsCtl.dispose();
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
          _animated(0, _buildFilterChips(textTheme)),

          // -- Content: bookings or orders depending on tab --
          Expanded(
            child: _animated(1, _activeTab == _BookingTab.pedidos
              ? _buildOrdersContent(textTheme, colorScheme, disputes)
              : bookingsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppConstants.paddingLG),
                  child: Text(
                    'Error al cargar citas: $err',
                    style: textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.error),
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
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppConstants.paddingSM),
                    itemBuilder: (context, index) {
                      return _buildBookingCard(
                          filtered[index], textTheme, disputes);
                    },
                  ),
                );
              },
            )),
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
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: AppConstants.minTouchHeight - 8,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.surface,
                    borderRadius:
                        BorderRadius.circular(AppConstants.radiusXL),
                    border: isSelected
                        ? null
                        : Border.all(color: ext.cardBorderColor),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: colorScheme.primary
                                  .withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    _tabLabel(tab),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelLarge?.copyWith(
                      color: isSelected
                          ? colorScheme.onPrimary
                          : colorScheme.onSurface,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
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
    return EmptyState(
      icon: Icons.calendar_today_outlined,
      message: _emptyMessage(),
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
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(color: ext.cardBorderColor),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.02),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
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
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppConstants.paddingSM),
                _buildStatusChip(booking.status, textTheme),
              ],
            ),

            Divider(height: 20, thickness: 1, color: ext.cardBorderColor),

            // Service info row: IconBox + label/value
            _buildInfoRow(
              icon: Icons.content_cut_outlined,
              iconColor: colorScheme.primary,
              label: 'SERVICIO',
              value: booking.serviceName,
            ),

            Divider(height: 16, thickness: 1, color: ext.cardBorderColor),

            // Date info row
            _buildInfoRow(
              icon: Icons.schedule_outlined,
              iconColor: colorScheme.secondary,
              label: 'FECHA Y HORA',
              value: _formatDate(booking.scheduledAt),
            ),

            // Price info row
            if (booking.price != null) ...[
              Divider(height: 16, thickness: 1, color: ext.cardBorderColor),
              _buildInfoRow(
                icon: Icons.payments_outlined,
                iconColor: ext.successColor,
                label: 'PRECIO',
                value: '\$${booking.price!.toStringAsFixed(0)} MXN',
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
                          ? Icons.check_circle_outlined
                          : Icons.block_outlined,
                      size: 14,
                      color: disputeStatus == 'resolved' ? ext.successColor : colorScheme.error,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      disputeStatus == 'resolved'
                          ? 'Disputa resuelta'
                          : 'Disputa rechazada',
                      style: textTheme.labelSmall?.copyWith(
                        color: disputeStatus == 'resolved' ? ext.successColor : colorScheme.error,
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
                      hasSalonOffer ? Icons.local_offer_outlined : Icons.gavel_outlined,
                      size: 14,
                      color: hasSalonOffer ? Colors.blue : ext.warningColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      hasSalonOffer
                          ? 'El salon respondio - revisa la oferta'
                          : disputeStatus == 'escalated'
                              ? 'Disputa escalada - en revision'
                              : 'Disputa abierta',
                      style: textTheme.labelSmall?.copyWith(
                        color: hasSalonOffer ? Colors.blue : ext.warningColor,
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
                child: _cancellingBookingId == booking.id
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : TextButton.icon(
                  onPressed: () => _cancelBooking(booking),
                  icon: const Icon(
                    Icons.cancel_outlined,
                    size: AppConstants.iconSizeSM,
                  ),
                  label: const Text('Cancelar'),
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.error,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.paddingSM,
                    ),
                    minimumSize: const Size(0, AppConstants.minTouchHeight - 16),
                  ),
                ),
              ),
            ],

            // Rebook button for completed bookings
            if (booking.status == 'completed') ...[
              const SizedBox(height: AppConstants.paddingSM),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _rebookBooking(booking),
                  icon: Icon(
                    Icons.replay_rounded,
                    size: AppConstants.iconSizeSM,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  label: Text(
                    'Reservar Otra Vez',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    minimumSize:
                        const Size(0, AppConstants.minTouchHeight - 8),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusLG),
                    ),
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
                          Icons.visibility_outlined,
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
                            onPressed: () => _showDisputeResult(dispute),
                            icon: Icon(
                              Icons.info_outlined,
                              size: AppConstants.iconSizeSM,
                              color: ext.successColor,
                            ),
                            label: Text('Ver resultado',
                                style: TextStyle(
                                    color: ext.successColor,
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
                                  color: ext.warningColor,
                                ),
                                label: Text('Reportar problema',
                                    style: TextStyle(
                                        color: ext.warningColor)),
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
    );
  }

  /// Build an info row following the approved IconBox pattern.
  Widget _buildInfoRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    Widget? trailing,
  }) {
    return Row(
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
                label,
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        ?trailing,
      ],
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
