import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:beautycita/config/constants.dart';
import 'package:beautycita/models/booking.dart';
import 'package:beautycita/models/curate_result.dart' show LatLng;
import 'package:beautycita/providers/booking_detail_provider.dart';
import 'package:beautycita/providers/booking_flow_provider.dart'
    show bookingRepositoryProvider;
import 'package:beautycita/providers/booking_provider.dart'
    show userBookingsProvider, upcomingBookingsProvider;
import 'package:beautycita/providers/profile_provider.dart';
import 'package:beautycita/providers/route_provider.dart';
import 'package:beautycita/providers/uber_provider.dart';
import 'package:beautycita/services/location_service.dart';
import 'package:beautycita/services/supabase_client.dart';
import 'package:beautycita/services/toast_service.dart';
import 'package:beautycita/widgets/route_map_widget.dart';
import 'package:beautycita/widgets/location_picker_sheet.dart';

// ── Business location fetcher ───────────────────────────────────────────────

final _businessLocationProvider =
    FutureProvider.family<LatLng?, String>((ref, businessId) async {
  final biz = await SupabaseClientService.client
      .from('businesses')
      .select('latitude, longitude')
      .eq('id', businessId)
      .maybeSingle();
  if (biz == null) return null;
  final lat = (biz['latitude'] as num?)?.toDouble();
  final lng = (biz['longitude'] as num?)?.toDouble();
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
          .from('bookings')
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
          .from('businesses')
          .select('name, address, latitude, longitude')
          .eq('id', booking.businessId)
          .maybeSingle();
      if (biz == null || !mounted) return;
      final uberService = ref.read(uberServiceProvider);
      final lat = (biz['latitude'] as num?)?.toDouble();
      final lng = (biz['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        await uberService.openRideToSalon(
          salonLat: lat,
          salonLng: lng,
          salonName:
              biz['name'] as String? ?? booking.providerName ?? 'Salon',
          salonAddress: biz['address'] as String?,
        );
      }
    } catch (_) {}
  }

  Future<void> _openUberFromSalon(Booking booking) async {
    try {
      final biz = await SupabaseClientService.client
          .from('businesses')
          .select('name, latitude, longitude')
          .eq('id', booking.businessId)
          .maybeSingle();
      if (biz == null || !mounted) return;
      final uberService = ref.read(uberServiceProvider);
      final lat = (biz['latitude'] as num?)?.toDouble();
      final lng = (biz['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        await uberService.openRideHome(
          salonLat: lat,
          salonLng: lng,
          salonName:
              biz['name'] as String? ?? booking.providerName ?? 'Salon',
        );
      }
    } catch (_) {}
  }

  Future<void> _editNotes(Booking booking) async {
    final controller = TextEditingController(text: booking.notes ?? '');
    final colorScheme = Theme.of(context).colorScheme;

    await showModalBottomSheet(
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
                    color: Colors.grey.shade300,
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
                  child: const Text(
                    'Guardar',
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

    if (confirmed != true || !mounted) return;

    setState(() => _isCancelling = true);

    try {
      final repo = ref.read(bookingRepositoryProvider);
      await repo.cancelBooking(booking.id);

      ref.invalidate(bookingDetailProvider(widget.bookingId));
      ref.invalidate(userBookingsProvider);
      ref.invalidate(upcomingBookingsProvider);

      ToastService.showSuccess('Cita cancelada');
      if (mounted) {
        context.pop();
      }
    } catch (e, stack) {
      ToastService.showErrorWithDetails(ToastService.friendlyError(e), e, stack);
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
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
            color: Colors.black.withValues(alpha: 0.04),
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

    final modes = [
      (id: 'car', icon: Icons.directions_car_rounded, label: 'Mi auto'),
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
                      color: isSelected ? Colors.white : colorScheme.primary,
                    ),
                    const SizedBox(width: AppConstants.paddingXS),
                    Flexible(
                      child: Text(
                        mode.label,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: isSelected
                                  ? Colors.white
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
                  color: Colors.black,
                  icon: Icons.arrow_forward_rounded,
                  label: 'Pedir Uber',
                  onTap: () => _openUberToSalon(booking),
                ),
              ),
              const SizedBox(width: AppConstants.paddingSM),
              Expanded(
                child: _actionButton(
                  color: Colors.black,
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
                  size: AppConstants.iconSizeSM, color: Colors.white),
              const SizedBox(width: AppConstants.paddingXS),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
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
            color: Colors.black.withValues(alpha: 0.06),
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
