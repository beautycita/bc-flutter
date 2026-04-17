import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:beautycita/config/app_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:beautycita/config/constants.dart';
import 'package:beautycita/models/booking.dart';
import 'package:beautycita/models/curate_result.dart' show LatLng;
import 'package:beautycita/providers/booking_detail_provider.dart';
import 'package:beautycita/providers/booking_provider.dart'
    show bookingRepositoryProvider, userBookingsProvider, upcomingBookingsProvider;
import 'package:beautycita/providers/profile_provider.dart';
import 'package:beautycita/providers/route_provider.dart';
import 'package:beautycita/providers/feature_toggle_provider.dart';
import 'package:beautycita/providers/uber_provider.dart';
import 'package:beautycita/services/location_service.dart';
import 'package:beautycita_core/supabase.dart';
import 'package:beautycita/services/supabase_client.dart';
import 'package:beautycita/services/toast_service.dart';
import 'package:beautycita/widgets/route_map_widget.dart';
import 'package:beautycita/widgets/location_picker_sheet.dart';

// ── Business location fetcher ───────────────────────────────────────────────

final _businessLocationProvider =
    FutureProvider.family<LatLng?, String>((ref, businessId) async {
  final biz = await SupabaseClientService.client
      .from(BCTables.businesses)
      .select('lat, lng')
      .eq('id', businessId)
      .maybeSingle();
  if (biz == null) return null;
  final lat = (biz['lat'] as num?)?.toDouble();
  final lng = (biz['lng'] as num?)?.toDouble();
  if (lat == null || lng == null) return null;
  return LatLng(lat: lat, lng: lng);
});

// ── Screen ───────────────────────────────────────────────────────────────────

class BookingDetailScreen extends ConsumerStatefulWidget {
  final String bookingId;
  const BookingDetailScreen({super.key, required this.bookingId});

  @override
  ConsumerState<BookingDetailScreen> createState() =>
      _BookingDetailScreenState();
}

class _BookingDetailScreenState extends ConsumerState<BookingDetailScreen> {
  bool _isCancelling = false;
  bool _isUpdatingTransport = false;
  final GlobalKey _receiptKey = GlobalKey();

  // Origin for route: starts null, initialized from profile or GPS on first
  // build when business location is available.
  LatLng? _origin;
  String? _originAddress;
  bool _originResolved = false;

  // ── Helpers ──

  String _formatDate(DateTime dt) {
    final formatter = DateFormat("EEEE d 'de' MMMM, HH:mm", 'es');
    final formatted = formatter.format(dt);
    return formatted[0].toUpperCase() + formatted.substring(1);
  }

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

  bool _canCancel(String status) =>
      status == 'pending' || status == 'confirmed';

  // ── Origin resolution ──

  Future<void> _resolveOriginIfNeeded() async {
    if (_originResolved) return;
    _originResolved = true;

    final profile = ref.read(profileProvider);

    if (profile.homeLat != null && profile.homeLng != null) {
      setState(() {
        _origin = LatLng(lat: profile.homeLat!, lng: profile.homeLng!);
        _originAddress = profile.homeAddress ?? 'Mi casa';
      });
      return;
    }

    // Fall back to GPS
    final gps = await LocationService.getCurrentLocation();
    if (mounted && gps != null) {
      setState(() {
        _origin = gps;
        _originAddress = 'Ubicacion actual';
      });
    }
  }

  // ── Actions ──

  Future<void> _pickOrigin() async {
    final result = await showLocationPicker(
      context: context,
      ref: ref,
      title: 'Punto de partida',
      currentAddress: _originAddress,
    );
    if (result != null && mounted) {
      setState(() {
        _origin = LatLng(lat: result.lat, lng: result.lng);
        _originAddress = result.address;
      });
    }
  }

  Future<void> _updateTransportMode(Booking booking, String mode) async {
    if (_isUpdatingTransport || booking.transportMode == mode) return;
    setState(() => _isUpdatingTransport = true);
    try {
      await SupabaseClientService.client
          .from(BCTables.appointments)
          .update({'transport_mode': mode})
          .eq('id', booking.id);
      ref.invalidate(bookingDetailProvider(widget.bookingId));
    } catch (e, stack) {
      ToastService.showErrorWithDetails(ToastService.friendlyError(e), e, stack);
    } finally {
      if (mounted) setState(() => _isUpdatingTransport = false);
    }
  }

  Future<void> _openMapsNavigation(LatLng destination) async {
    final url =
        'https://www.google.com/maps/dir/?api=1&destination=${destination.lat},${destination.lng}';
    Share.share(url);
  }

  void _shareRoute(Booking booking, LatLng? destination) {
    final dest = destination;
    String text =
        'Mi cita de ${booking.serviceName} en ${booking.providerName ?? 'el salon'}\n'
        'Fecha: ${_formatDate(booking.scheduledAt)}';
    if (dest != null) {
      text +=
          '\nComo llegar: https://www.google.com/maps/dir/?api=1&destination=${dest.lat},${dest.lng}';
    }
    Share.share(text);
  }

  Future<void> _openUberToSalon(Booking booking) async {
    try {
      final biz = await SupabaseClientService.client
          .from(BCTables.businesses)
          .select('name, address, lat, lng')
          .eq('id', booking.businessId)
          .maybeSingle();
      if (biz == null || !mounted) return;
      final uberService = ref.read(uberServiceProvider);
      final lat = (biz['lat'] as num?)?.toDouble();
      final lng = (biz['lng'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        await uberService.openRideToSalon(
          salonLat: lat,
          salonLng: lng,
          salonName:
              biz['name'] as String? ?? booking.providerName ?? 'Salon',
          salonAddress: biz['address'] as String?,
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[BookingDetail] Failed to open Uber to salon: $e');
    }
  }

  Future<void> _openUberFromSalon(Booking booking) async {
    try {
      final biz = await SupabaseClientService.client
          .from(BCTables.businesses)
          .select('name, lat, lng')
          .eq('id', booking.businessId)
          .maybeSingle();
      if (biz == null || !mounted) return;
      final uberService = ref.read(uberServiceProvider);
      final lat = (biz['lat'] as num?)?.toDouble();
      final lng = (biz['lng'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        await uberService.openRideHome(
          salonLat: lat,
          salonLng: lng,
          salonName:
              biz['name'] as String? ?? booking.providerName ?? 'Salon',
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[BookingDetail] Failed to open Uber from salon: $e');
    }
  }

  Future<void> _editNotes(Booking booking) async {
    final controller = TextEditingController(text: booking.notes ?? '');
    final colorScheme = Theme.of(context).colorScheme;

    await showBurstBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppConstants.radiusXL)),
      ),
      builder: (ctx) {
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
                'Notas de la cita',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: AppConstants.paddingSM),
              TextField(
                controller: controller,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Agrega notas para tu cita...',
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppConstants.radiusSM),
                  ),
                  filled: true,
                  fillColor: Theme.of(ctx).colorScheme.surface,
                ),
              ),
              const SizedBox(height: AppConstants.paddingMD),
              SizedBox(
                width: double.infinity,
                height: AppConstants.minTouchHeight,
                child: ElevatedButton(
                  onPressed: () async {
                    final repo = ref.read(bookingRepositoryProvider);
                    await repo.updateNotes(
                        widget.bookingId, controller.text.trim());
                    ref.invalidate(
                        bookingDetailProvider(widget.bookingId));
                    ref.invalidate(userBookingsProvider);
                    if (ctx.mounted) Navigator.pop(ctx);
                    ToastService.showSuccess('Notas actualizadas');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusLG),
                    ),
                  ),
                  child: Text(
                    'Guardar',
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
  }

  Future<void> _cancelBooking(Booking booking) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppConstants.radiusXL)),
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
                        color: Theme.of(ctx)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
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

    if (confirmed != true || !mounted) return;

    setState(() => _isCancelling = true);

    try {
      final repo = ref.read(bookingRepositoryProvider);
      final result = await repo.cancelBooking(booking.id);

      // Send cancel notification (fire-and-forget)
      SupabaseClientService.client.functions
          .invoke('cancel-notification', body: {'appointment_id': booking.id})
          .ignore();

      ref.invalidate(bookingDetailProvider(widget.bookingId));
      ref.invalidate(userBookingsProvider);
      ref.invalidate(upcomingBookingsProvider);

      if (result.refundAmount > 0) {
        ToastService.showSuccess(
          'Cita cancelada — \$${result.refundAmount.toStringAsFixed(0)} reembolsado a tu saldo'
          '${result.depositForfeited > 0 ? ' (deposito de \$${result.depositForfeited.toStringAsFixed(0)} no reembolsable)' : ''}',
        );
      } else if (result.depositForfeited > 0) {
        ToastService.showWarning('Cita cancelada — deposito de \$${result.depositForfeited.toStringAsFixed(0)} no reembolsable');
      } else {
        ToastService.showSuccess('Cita cancelada');
      }
      if (mounted) {
        await showShredderTransition(context, onComplete: () {
          if (mounted) {
            _showCancellationConfirm(booking);
          }
        });
      }
    } catch (e, stack) {
      ToastService.showErrorWithDetails(ToastService.friendlyError(e), e, stack);
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  void _showCancellationConfirm(Booking booking) {
    final ref8 = booking.id.length >= 8
        ? booking.id.substring(0, 8).toUpperCase()
        : booking.id.toUpperCase();
    final dateStr = _formatDate(booking.scheduledAt);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusLG),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingLG),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.cancel_rounded,
                  size: 36,
                  color: Colors.red.shade400,
                ),
              ),
              const SizedBox(height: AppConstants.paddingMD),
              Text(
                'Cita Cancelada',
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Colors.red.shade600,
                    ),
              ),
              const SizedBox(height: AppConstants.paddingMD),
              _confirmRow(ctx, 'Referencia', ref8),
              _confirmRow(ctx, 'Servicio', booking.serviceName),
              if (booking.providerName != null)
                _confirmRow(ctx, 'Salon', booking.providerName!),
              _confirmRow(ctx, 'Fecha original', dateStr),
              const SizedBox(height: AppConstants.paddingMD),
              Row(
                children: [
                  Icon(Icons.chat_bubble_outline,
                      size: 16,
                      color: Theme.of(ctx)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.4)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Enviamos confirmacion por WhatsApp',
                      style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                            color: Theme.of(ctx)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5),
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.paddingLG),
              SizedBox(
                width: double.infinity,
                height: AppConstants.minTouchHeight,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop(); // close dialog
                    if (mounted) context.pop(); // pop booking detail
                  },
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusLG),
                    ),
                  ),
                  child: const Text(
                    'Cerrar',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _confirmRow(BuildContext ctx, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                    color: Theme.of(ctx)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final bookingAsync = ref.watch(bookingDetailProvider(widget.bookingId));
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Detalle de Cita'),
      ),
      body: bookingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.paddingLG),
            child: Text(
              'Error al cargar cita: $err',
              style: textTheme.bodyLarge?.copyWith(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (booking) {
          if (booking == null) {
            return Center(
              child: Text(
                'Cita no encontrada',
                style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.5)),
              ),
            );
          }

          // Watch business location; kick off origin resolution once available.
          final bizLocationAsync =
              ref.watch(_businessLocationProvider(booking.businessId));

          bizLocationAsync.whenData((bizLoc) {
            if (bizLoc != null) {
              _resolveOriginIfNeeded();
            }
          });

          final origin = _origin;
          final bizLocation = bizLocationAsync.valueOrNull;

          // Build route request only when both origin and destination are ready.
          final routeAsync = (origin != null && bizLocation != null)
              ? ref.watch(routeProvider(RouteRequest(
                  origin: origin,
                  destination: bizLocation,
                )))
              : null;

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.screenPaddingHorizontal,
                    vertical: AppConstants.paddingMD,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Service Info Card
                      _buildServiceInfoCard(booking, textTheme),
                      const SizedBox(height: AppConstants.paddingMD),

                      // 2. Date + Status
                      _buildDateRow(booking, textTheme),
                      const SizedBox(height: AppConstants.paddingSM),
                      _buildStatusChip(booking.status, textTheme),
                      const SizedBox(height: AppConstants.paddingMD),

                      // 3. Route Map
                      _buildRouteSection(
                        booking: booking,
                        bizLocationAsync: bizLocationAsync,
                        routeAsync: routeAsync,
                        origin: origin,
                        bizLocation: bizLocation,
                        textTheme: textTheme,
                      ),
                      const SizedBox(height: AppConstants.paddingMD),

                      // 4. Transport Picker
                      _buildTransportPicker(booking),
                      const SizedBox(height: AppConstants.paddingMD),

                      // 5. Action Buttons
                      _buildActionButtons(
                          booking: booking, bizLocation: bizLocation),
                      const SizedBox(height: AppConstants.paddingMD),

                      // 5b. Receipt download for completed bookings
                      if (booking.status == 'completed')
                        _buildReceiptButton(booking),
                      if (booking.status == 'completed')
                        const SizedBox(height: AppConstants.paddingMD),

                      // 6. Origin Editor
                      _buildOriginEditor(textTheme),
                      const SizedBox(height: AppConstants.paddingMD),

                      // 7. Notes
                      _buildNotesSection(booking, textTheme),
                      const SizedBox(height: AppConstants.paddingLG),
                    ],
                  ),
                ),
              ),

              // 8. Bottom bar: Cancel
              if (_canCancel(booking.status))
                _buildBottomActions(booking, textTheme),
            ],
          );
        },
      ),
    );
  }

  // ── Sections ──

  Widget _buildServiceInfoCard(Booking booking, TextTheme textTheme) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(color: Theme.of(context).dividerColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            booking.providerName ?? 'Proveedor',
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppConstants.paddingXS),
          Text(
            booking.serviceName,
            style: textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: AppConstants.paddingSM),
          Row(
            children: [
              if (booking.price != null) ...[
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
                const SizedBox(width: AppConstants.paddingMD),
              ],
              Icon(
                Icons.timer_outlined,
                size: AppConstants.iconSizeSM,
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(width: AppConstants.paddingXS),
              Text(
                '${booking.durationMinutes} min',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateRow(Booking booking, TextTheme textTheme) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(
          Icons.calendar_today_rounded,
          size: AppConstants.iconSizeMD,
          color: colorScheme.primary,
        ),
        const SizedBox(width: AppConstants.paddingSM),
        Expanded(
          child: Text(
            _formatDate(booking.scheduledAt),
            style: textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
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
        style: textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildRouteSection({
    required Booking booking,
    required AsyncValue<LatLng?> bizLocationAsync,
    required AsyncValue<dynamic>? routeAsync,
    required LatLng? origin,
    required LatLng? bizLocation,
    required TextTheme textTheme,
  }) {
    final screenHeight = MediaQuery.of(context).size.height;
    final mapHeight = screenHeight * 0.40;
    final colorScheme = Theme.of(context).colorScheme;

    // Business location still loading
    if (bizLocationAsync is AsyncLoading) {
      return _buildMapPlaceholder(
        mapHeight,
        child: const CircularProgressIndicator(),
      );
    }

    // Business location error or unavailable
    if (bizLocationAsync is AsyncError || bizLocation == null) {
      return _buildMapPlaceholder(
        mapHeight,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined,
                size: AppConstants.iconSizeLG,
                color: colorScheme.onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: AppConstants.paddingSM),
            Text(
              'Mapa no disponible',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      );
    }

    // Origin not yet resolved
    if (origin == null) {
      return _buildMapPlaceholder(
        mapHeight,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(height: AppConstants.paddingSM),
            Text(
              'Obteniendo tu ubicacion...',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    // Route loading
    if (routeAsync == null || routeAsync is AsyncLoading) {
      return _buildMapPlaceholder(
        mapHeight,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(height: AppConstants.paddingSM),
            Text(
              'Calculando ruta...',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    // Route error
    if (routeAsync is AsyncError) {
      return _buildMapPlaceholder(
        mapHeight,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.route_outlined,
                size: AppConstants.iconSizeLG,
                color: colorScheme.onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: AppConstants.paddingSM),
            Text(
              'No se pudo calcular la ruta',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      );
    }

    // Success — render map
    final routeData = (routeAsync as AsyncData).value;
    return RouteMapWidget(
      routeData: routeData,
      origin: origin,
      destination: bizLocation,
      height: mapHeight,
    );
  }

  Widget _buildMapPlaceholder(double height, {required Widget child}) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor, width: 1),
      ),
      child: Center(child: child),
    );
  }

  Widget _buildTransportPicker(Booking booking) {
    final colorScheme = Theme.of(context).colorScheme;
    final current = booking.transportMode;

    final uberEnabled = ref.watch(featureTogglesProvider).isEnabled('enable_uber_integration');
    final modes = [
      (id: 'car', icon: Icons.directions_car_rounded, label: 'Mi auto'),
      if (uberEnabled)
        (id: 'uber', icon: Icons.local_taxi_rounded, label: 'Uber'),
      (id: 'transit', icon: Icons.directions_bus_rounded, label: 'Transporte'),
    ];

    return Row(
      children: modes.map((mode) {
        final isSelected = current == mode.id;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: mode.id != 'transit' ? AppConstants.paddingXS : 0,
            ),
            child: GestureDetector(
              onTap: _isUpdatingTransport
                  ? null
                  : () => _updateTransportMode(booking, mode.id),
              child: AnimatedContainer(
                duration: AppConstants.shortAnimation,
                padding: const EdgeInsets.symmetric(
                  vertical: AppConstants.paddingSM + 2,
                  horizontal: AppConstants.paddingXS,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.surface,
                  borderRadius:
                      BorderRadius.circular(AppConstants.radiusFull),
                  border: Border.all(
                    color: isSelected
                        ? colorScheme.primary
                        : Theme.of(context).dividerColor,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      mode.icon,
                      size: AppConstants.iconSizeSM,
                      color: isSelected ? colorScheme.onPrimary : colorScheme.primary,
                    ),
                    const SizedBox(width: AppConstants.paddingXS),
                    Flexible(
                      child: Text(
                        mode.label,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: isSelected
                                  ? colorScheme.onPrimary
                                  : colorScheme.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActionButtons({
    required Booking booking,
    required LatLng? bizLocation,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final mode = booking.transportMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Uber-specific buttons
        if (mode == 'uber') ...[
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  color: Theme.of(context).colorScheme.onSurface,
                  icon: Icons.arrow_forward_rounded,
                  label: 'Pedir Uber',
                  onTap: () => _openUberToSalon(booking),
                ),
              ),
              const SizedBox(width: AppConstants.paddingSM),
              Expanded(
                child: _actionButton(
                  color: Theme.of(context).colorScheme.onSurface,
                  icon: Icons.arrow_back_rounded,
                  label: 'Uber de regreso',
                  onTap: () => _openUberFromSalon(booking),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.paddingSM),
        ],

        // Car / Transit: open in Maps
        if (mode == 'car' || mode == 'transit') ...[
          _actionButton(
            color: colorScheme.primary,
            icon: Icons.map_rounded,
            label: 'Abrir en Maps',
            onTap: bizLocation != null
                ? () => _openMapsNavigation(bizLocation)
                : null,
          ),
          const SizedBox(height: AppConstants.paddingSM),
        ],

        // All modes: share route
        _actionButton(
          color: colorScheme.secondary,
          icon: Icons.share_rounded,
          label: 'Compartir ruta',
          onTap: () => _shareRoute(booking, bizLocation),
        ),
      ],
    );
  }

  Widget _actionButton({
    required Color color,
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: onTap != null ? color : color.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(AppConstants.radiusLG),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusLG),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppConstants.paddingSM + 2,
            horizontal: AppConstants.paddingMD,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: AppConstants.iconSizeSM, color: Theme.of(context).colorScheme.onPrimary),
              const SizedBox(width: AppConstants.paddingXS),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptButton(Booking booking) {
    return _actionButton(
      color: Colors.teal.shade600,
      icon: Icons.receipt_long_outlined,
      label: 'Descargar Recibo',
      onTap: () => _generateAndShareReceipt(booking),
    );
  }

  Future<void> _generateAndShareReceipt(Booking booking) async {
    // Show receipt in an overlay, capture, then dismiss
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        left: -2000,
        top: -2000,
        child: RepaintBoundary(
          key: _receiptKey,
          child: _ReceiptWidget(booking: booking),
        ),
      ),
    );
    overlay.insert(entry);

    // Wait for a frame to render
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      final boundary = _receiptKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('No se pudo capturar el recibo');

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('No se pudo convertir a PNG');

      final tempDir = await getTemporaryDirectory();
      final file = File(
          '${tempDir.path}/recibo_${booking.id.substring(0, 8)}.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Recibo de ${booking.serviceName} - BeautyCita',
      );
    } catch (e, stack) {
      ToastService.showErrorWithDetails(
          'No se pudo generar el recibo', e, stack);
    } finally {
      entry.remove();
    }
  }

  Widget _buildOriginEditor(TextTheme textTheme) {
    final colorScheme = Theme.of(context).colorScheme;
    final address = _originAddress ?? 'Seleccionar punto de partida';

    return GestureDetector(
      onTap: _pickOrigin,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.paddingMD,
          vertical: AppConstants.paddingSM + 2,
        ),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(AppConstants.radiusMD),
          border:
              Border.all(color: Theme.of(context).dividerColor, width: 1),
        ),
        child: Row(
          children: [
            Icon(
              Icons.trip_origin_rounded,
              size: AppConstants.iconSizeSM,
              color: Colors.blue,
            ),
            const SizedBox(width: AppConstants.paddingSM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Desde',
                    style: textTheme.labelSmall?.copyWith(
                      color:
                          colorScheme.onSurface.withValues(alpha: 0.45),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    address,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.edit_rounded,
              size: AppConstants.iconSizeSM,
              color: colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesSection(Booking booking, TextTheme textTheme) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(color: Theme.of(context).dividerColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Notas',
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              GestureDetector(
                onTap: () => _editNotes(booking),
                child: Icon(
                  Icons.edit_rounded,
                  size: AppConstants.iconSizeSM,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.paddingXS),
          Text(
            booking.notes?.isNotEmpty == true
                ? booking.notes!
                : 'Sin notas',
            style: textTheme.bodyMedium?.copyWith(
              color: booking.notes?.isNotEmpty == true
                  ? colorScheme.onSurface
                  : colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions(Booking booking, TextTheme textTheme) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppConstants.screenPaddingHorizontal,
        AppConstants.paddingSM,
        AppConstants.screenPaddingHorizontal,
        MediaQuery.of(context).padding.bottom + AppConstants.paddingSM,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_canCancel(booking.status))
            Expanded(
              child: TextButton.icon(
                onPressed:
                    _isCancelling ? null : () => _cancelBooking(booking),
                icon: _isCancelling
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.red,
                        ),
                      )
                    : Icon(Icons.cancel_outlined,
                        color: Colors.red.shade600),
                label: Text(
                  _isCancelling ? 'Cancelando...' : 'Cancelar Cita',
                  style: TextStyle(color: Colors.red.shade600),
                ),
                style: TextButton.styleFrom(
                  minimumSize:
                      const Size(0, AppConstants.minTouchHeight),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Receipt Widget — rendered off-screen, captured as image, shared as PNG
// ═══════════════════════════════════════════════════════════════════════════

class _ReceiptWidget extends StatelessWidget {
  final Booking booking;
  const _ReceiptWidget({required this.booking});

  @override
  Widget build(BuildContext context) {
    final refNumber = booking.id.length >= 8
        ? booking.id.substring(0, 8).toUpperCase()
        : booking.id.toUpperCase();
    final dateFormatter = DateFormat("d 'de' MMMM yyyy, HH:mm", 'es');
    final dateStr = dateFormatter.format(booking.scheduledAt);

    final price = booking.price ?? 0;
    final hasWithholding = (booking.ivaWithheld ?? 0) > 0 ||
        (booking.isrWithheld ?? 0) > 0;
    final subtotal = price / 1.16; // IVA 16%
    final iva = price - subtotal;

    String paymentLabel;
    switch (booking.paymentStatus) {
      case 'paid':
        paymentLabel = 'Tarjeta (pagado)';
      case 'pending':
        paymentLabel = 'Pendiente';
      default:
        paymentLabel = booking.paymentStatus ?? 'No especificado';
    }

    return Material(
      color: Theme.of(context).colorScheme.onPrimary,
      child: SizedBox(
        width: 380,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Logo area
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFec4899), Color(0xFF9333ea)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    'BC',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Recibo de Servicio',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1a1a1a),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Ref: $refNumber',
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  color: const Color(0xFF999999),
                  letterSpacing: 1,
                ),
              ),

              const SizedBox(height: 20),
              const Divider(color: Color(0xFFEEEEEE)),
              const SizedBox(height: 12),

              // Salon
              _receiptRow('Salon', booking.providerName ?? 'Proveedor'),
              const SizedBox(height: 8),
              _receiptRow('Servicio', booking.serviceName),
              const SizedBox(height: 8),
              _receiptRow('Fecha', dateStr),
              const SizedBox(height: 8),
              _receiptRow('Duracion', '${booking.durationMinutes} min'),
              const SizedBox(height: 8),
              _receiptRow('Metodo de pago', paymentLabel),

              const SizedBox(height: 16),
              const Divider(color: Color(0xFFEEEEEE)),
              const SizedBox(height: 12),

              // Price breakdown
              _receiptRow('Subtotal',
                  '\$${subtotal.toStringAsFixed(2)} MXN'),
              const SizedBox(height: 6),
              _receiptRow('IVA (16%)',
                  '\$${iva.toStringAsFixed(2)} MXN'),
              if (hasWithholding) ...[
                const SizedBox(height: 6),
                _receiptRow('IVA retenido',
                    '-\$${(booking.ivaWithheld ?? 0).toStringAsFixed(2)} MXN'),
                const SizedBox(height: 6),
                _receiptRow('ISR retenido',
                    '-\$${(booking.isrWithheld ?? 0).toStringAsFixed(2)} MXN'),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1a1a1a),
                    ),
                  ),
                  Text(
                    '\$${price.toStringAsFixed(2)} MXN',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1a1a1a),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              const Divider(color: Color(0xFFEEEEEE)),
              const SizedBox(height: 16),

              // Footer
              Text(
                'BeautyCita S.A. de C.V.',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF999999),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'beautycita.com',
                style: GoogleFonts.nunito(
                  fontSize: 10,
                  color: const Color(0xFFBBBBBB),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _receiptRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          flex: 2,
          child: Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 13,
              color: const Color(0xFF666666),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          flex: 3,
          child: Text(
            value,
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1a1a1a),
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
