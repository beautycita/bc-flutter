import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:beautycita/config/theme.dart';
import 'package:beautycita/config/constants.dart';
import 'package:beautycita/models/booking.dart';
import 'package:beautycita/models/uber_ride.dart';
import 'package:beautycita/providers/booking_detail_provider.dart';
import 'package:beautycita/providers/booking_flow_provider.dart'
    show bookingRepositoryProvider, uberServiceProvider;
import 'package:beautycita/providers/booking_provider.dart'
    show userBookingsProvider, upcomingBookingsProvider;
import 'package:beautycita/services/location_service.dart';
import 'package:beautycita/widgets/location_picker_sheet.dart';

class BookingDetailScreen extends ConsumerStatefulWidget {
  final String bookingId;
  const BookingDetailScreen({super.key, required this.bookingId});

  @override
  ConsumerState<BookingDetailScreen> createState() =>
      _BookingDetailScreenState();
}

class _BookingDetailScreenState extends ConsumerState<BookingDetailScreen> {
  bool _isCancelling = false;
  bool _isAddingUber = false;

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
        return BeautyCitaTheme.textLight;
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

  String _transportLabel(String? mode) {
    switch (mode) {
      case 'uber':
        return 'Uber';
      case 'car':
        return 'Auto propio';
      case 'transit':
        return 'Transporte publico';
      default:
        return 'No especificado';
    }
  }

  IconData _transportIcon(String? mode) {
    switch (mode) {
      case 'uber':
        return Icons.local_taxi_rounded;
      case 'car':
        return Icons.directions_car_rounded;
      case 'transit':
        return Icons.directions_bus_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  Color _uberStatusColor(String status) {
    switch (status) {
      case 'scheduled':
        return Colors.blue.shade600;
      case 'requested':
        return Colors.orange.shade600;
      case 'accepted':
        return Colors.green.shade600;
      case 'arriving':
        return Colors.teal.shade600;
      case 'in_progress':
        return Colors.indigo.shade600;
      case 'completed':
        return Colors.grey.shade600;
      case 'cancelled':
        return Colors.red.shade600;
      default:
        return BeautyCitaTheme.textLight;
    }
  }

  bool _canCancel(String status) =>
      status == 'pending' || status == 'confirmed';

  bool _canAddUber(Booking booking) {
    if (booking.transportMode == 'uber') return false;
    if (!_canCancel(booking.status)) return false;
    final minutesUntil =
        booking.scheduledAt.difference(DateTime.now()).inMinutes;
    return minutesUntil >= 30;
  }

  // ── Actions ──

  Future<void> _editNotes(Booking booking) async {
    final controller = TextEditingController(text: booking.notes ?? '');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppConstants.radiusXL)),
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
              const SizedBox(height: BeautyCitaTheme.spaceMD),
              Text(
                'Notas de la cita',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: BeautyCitaTheme.spaceSM),
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
                  fillColor: BeautyCitaTheme.surfaceCream,
                ),
              ),
              const SizedBox(height: BeautyCitaTheme.spaceMD),
              SizedBox(
                width: double.infinity,
                height: AppConstants.minTouchHeight,
                child: ElevatedButton(
                  onPressed: () async {
                    final repo = ref.read(bookingRepositoryProvider);
                    await repo.updateNotes(
                        widget.bookingId, controller.text.trim());
                    ref.invalidate(bookingDetailProvider(widget.bookingId));
                    ref.invalidate(userBookingsProvider);
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Notas actualizadas'),
                          backgroundColor: Colors.green.shade600,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BeautyCitaTheme.primaryRose,
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
                const SizedBox(height: BeautyCitaTheme.spaceMD),
                Icon(
                  Icons.cancel_outlined,
                  size: AppConstants.iconSizeXL,
                  color: Colors.red.shade400,
                ),
                const SizedBox(height: BeautyCitaTheme.spaceSM),
                Text(
                  'Cancelar esta cita?',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: BeautyCitaTheme.spaceXS),
                Text(
                  'Se cancelara tu cita de ${booking.serviceName}.'
                  '${booking.transportMode == 'uber' ? ' Tambien se cancelaran tus viajes de Uber.' : ''}',
                  style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                        color: BeautyCitaTheme.textLight,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: BeautyCitaTheme.spaceLG),
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
                    const SizedBox(width: BeautyCitaTheme.spaceSM),
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

      if (booking.transportMode == 'uber') {
        final uberService = ref.read(uberServiceProvider);
        await uberService.cancelRides(appointmentId: booking.id);
      }

      ref.invalidate(bookingDetailProvider(widget.bookingId));
      ref.invalidate(userBookingsProvider);
      ref.invalidate(upcomingBookingsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Cita cancelada'),
            backgroundColor: Colors.green.shade600,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cancelar: $e'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  Future<void> _addUber(Booking booking) async {
    setState(() => _isAddingUber = true);

    try {
      final location = await LocationService.getCurrentLocation();
      if (location == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('No se pudo obtener tu ubicacion'),
              backgroundColor: Colors.red.shade600,
            ),
          );
        }
        return;
      }

      final uberService = ref.read(uberServiceProvider);
      // Get fare estimate for preview
      final estimate = await uberService.getFareEstimate(
        startLat: location.lat,
        startLng: location.lng,
        endLat: 0, // We need salon coords — fall back to booking business
        endLng: 0,
      );

      if (!mounted) return;

      // Show confirmation sheet
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
                  const SizedBox(height: BeautyCitaTheme.spaceMD),
                  const Icon(
                    Icons.local_taxi_rounded,
                    size: AppConstants.iconSizeXL,
                    color: BeautyCitaTheme.primaryRose,
                  ),
                  const SizedBox(height: BeautyCitaTheme.spaceSM),
                  Text(
                    'Agregar Uber?',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: BeautyCitaTheme.spaceXS),
                  Text(
                    estimate != null
                        ? 'Estimado: \$${estimate.fareMin.toStringAsFixed(0)}-\$${estimate.fareMax.toStringAsFixed(0)} ${estimate.currency} (ida y vuelta)'
                        : 'Se programaran viajes de ida y vuelta',
                    style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                          color: BeautyCitaTheme.textLight,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: BeautyCitaTheme.spaceLG),
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
                          child: const Text('No'),
                        ),
                      ),
                      const SizedBox(width: BeautyCitaTheme.spaceSM),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: BeautyCitaTheme.primaryRose,
                            minimumSize:
                                const Size(0, AppConstants.minTouchHeight),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  AppConstants.radiusLG),
                            ),
                          ),
                          child: const Text(
                            'Agregar',
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

      // Schedule rides
      final result = await uberService.scheduleRides(
        appointmentId: booking.id,
        pickupLat: location.lat,
        pickupLng: location.lng,
        salonLat: 0, // The edge function resolves salon coords from appointment
        salonLng: 0,
        appointmentAt: booking.scheduledAt.toUtc().toIso8601String(),
        durationMinutes: booking.durationMinutes,
      );

      if (!result.scheduled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'No se pudo programar Uber: ${result.reason ?? "error desconocido"}'),
              backgroundColor: Colors.red.shade600,
            ),
          );
        }
        return;
      }

      // Update transport mode
      final repo = ref.read(bookingRepositoryProvider);
      await repo.updateTransportMode(booking.id, 'uber');

      ref.invalidate(bookingDetailProvider(widget.bookingId));
      ref.invalidate(uberRidesProvider(widget.bookingId));
      ref.invalidate(userBookingsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Uber agregado exitosamente'),
            backgroundColor: Colors.green.shade600,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al agregar Uber: $e'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAddingUber = false);
    }
  }

  Future<void> _editRideLocation(UberRide ride) async {
    final uberService = ref.read(uberServiceProvider);
    final isReturn = ride.leg == 'return';
    final title =
        isReturn ? 'Cambiar destino de regreso' : 'Cambiar punto de recogida';
    final currentAddress = isReturn ? ride.dropoffAddress : ride.pickupAddress;
    final successMsg = isReturn
        ? 'Destino de regreso actualizado'
        : 'Punto de recogida actualizado';

    final location = await showLocationPicker(
      context: context,
      ref: ref,
      title: title,
      currentAddress: currentAddress,
      showUberPlaces: true,
    );

    if (location == null || !mounted) return;

    final bool success;
    if (isReturn) {
      success = await uberService.updateReturnDestination(
        appointmentId: ride.appointmentId,
        lat: location.lat,
        lng: location.lng,
        address: location.address,
      );
    } else {
      success = await uberService.updatePickupLocation(
        appointmentId: ride.appointmentId,
        lat: location.lat,
        lng: location.lng,
        address: location.address,
      );
    }

    ref.invalidate(uberRidesProvider(widget.bookingId));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? successMsg : 'Error al actualizar'),
          backgroundColor:
              success ? Colors.green.shade600 : Colors.red.shade600,
        ),
      );
    }
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final bookingAsync = ref.watch(bookingDetailProvider(widget.bookingId));
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: BeautyCitaTheme.backgroundWhite,
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
                style: textTheme.bodyLarge
                    ?.copyWith(color: BeautyCitaTheme.textLight),
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.screenPaddingHorizontal,
                    vertical: BeautyCitaTheme.spaceMD,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildServiceInfoCard(booking, textTheme),
                      const SizedBox(height: BeautyCitaTheme.spaceMD),
                      _buildDateRow(booking, textTheme),
                      const SizedBox(height: BeautyCitaTheme.spaceSM),
                      _buildStatusChip(booking.status, textTheme),
                      const SizedBox(height: BeautyCitaTheme.spaceMD),
                      _buildNotesSection(booking, textTheme),
                      const SizedBox(height: BeautyCitaTheme.spaceMD),
                      _buildTransportSection(booking, textTheme),
                      if (booking.transportMode == 'uber') ...[
                        const SizedBox(height: BeautyCitaTheme.spaceMD),
                        _buildUberRidesSection(textTheme),
                      ],
                      const SizedBox(height: BeautyCitaTheme.spaceLG),
                    ],
                  ),
                ),
              ),
              if (_canCancel(booking.status) || _canAddUber(booking))
                _buildBottomActions(booking, textTheme),
            ],
          );
        },
      ),
    );
  }

  // ── Sections ──

  Widget _buildServiceInfoCard(Booking booking, TextTheme textTheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      decoration: BoxDecoration(
        color: BeautyCitaTheme.surfaceCream,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(
          color: BeautyCitaTheme.dividerLight,
          width: 1,
        ),
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
          const SizedBox(height: BeautyCitaTheme.spaceXS),
          Text(
            booking.serviceName,
            style: textTheme.bodyLarge?.copyWith(
              color: BeautyCitaTheme.textLight,
            ),
          ),
          const SizedBox(height: BeautyCitaTheme.spaceSM),
          Row(
            children: [
              if (booking.price != null) ...[
                Icon(
                  Icons.attach_money_rounded,
                  size: AppConstants.iconSizeSM,
                  color: BeautyCitaTheme.primaryRose,
                ),
                Text(
                  '\$${booking.price!.toStringAsFixed(0)} MXN',
                  style: textTheme.bodyMedium?.copyWith(
                    color: BeautyCitaTheme.primaryRose,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: BeautyCitaTheme.spaceMD),
              ],
              Icon(
                Icons.timer_outlined,
                size: AppConstants.iconSizeSM,
                color: BeautyCitaTheme.textLight,
              ),
              const SizedBox(width: BeautyCitaTheme.spaceXS),
              Text(
                '${booking.durationMinutes} min',
                style: textTheme.bodyMedium?.copyWith(
                  color: BeautyCitaTheme.textLight,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateRow(Booking booking, TextTheme textTheme) {
    return Row(
      children: [
        const Icon(
          Icons.calendar_today_rounded,
          size: AppConstants.iconSizeMD,
          color: BeautyCitaTheme.primaryRose,
        ),
        const SizedBox(width: BeautyCitaTheme.spaceSM),
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

  Widget _buildNotesSection(Booking booking, TextTheme textTheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      decoration: BoxDecoration(
        color: BeautyCitaTheme.surfaceCream,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(
          color: BeautyCitaTheme.dividerLight,
          width: 1,
        ),
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
                child: const Icon(
                  Icons.edit_rounded,
                  size: AppConstants.iconSizeSM,
                  color: BeautyCitaTheme.primaryRose,
                ),
              ),
            ],
          ),
          const SizedBox(height: BeautyCitaTheme.spaceXS),
          Text(
            booking.notes?.isNotEmpty == true
                ? booking.notes!
                : 'Sin notas',
            style: textTheme.bodyMedium?.copyWith(
              color: booking.notes?.isNotEmpty == true
                  ? BeautyCitaTheme.textDark
                  : BeautyCitaTheme.textLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransportSection(Booking booking, TextTheme textTheme) {
    return Row(
      children: [
        Icon(
          _transportIcon(booking.transportMode),
          size: AppConstants.iconSizeMD,
          color: BeautyCitaTheme.primaryRose,
        ),
        const SizedBox(width: BeautyCitaTheme.spaceSM),
        Text(
          _transportLabel(booking.transportMode),
          style: textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildUberRidesSection(TextTheme textTheme) {
    final ridesAsync = ref.watch(uberRidesProvider(widget.bookingId));

    return ridesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppConstants.paddingMD),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (rides) {
        if (rides.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Viajes Uber',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: BeautyCitaTheme.spaceSM),
            ...rides.map((ride) => _buildUberRideCard(ride, textTheme)),
          ],
        );
      },
    );
  }

  /// Extract street name from a full address (first part before the comma).
  String _shortAddress(String? address) {
    if (address == null || address.isEmpty) return 'Sin direccion';
    final parts = address.split(',');
    return parts.first.trim();
  }

  Widget _buildUberRideCard(UberRide ride, TextTheme textTheme) {
    final isReturn = ride.leg == 'return';
    final legLabel = isReturn ? 'Regreso' : 'Ida';
    final statusColor = _uberStatusColor(ride.status);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: BeautyCitaTheme.spaceSM),
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      decoration: BoxDecoration(
        color: BeautyCitaTheme.surfaceCream,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(
          color: BeautyCitaTheme.dividerLight,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: leg label + status chip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                legLabel,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.paddingSM,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius:
                      BorderRadius.circular(AppConstants.radiusFull),
                ),
                child: Text(
                  ride.statusLabel,
                  style: textTheme.labelSmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: BeautyCitaTheme.spaceSM),

          // Pickup address
          Row(
            children: [
              Icon(
                Icons.trip_origin_rounded,
                size: AppConstants.iconSizeSM,
                color: Colors.green.shade600,
              ),
              const SizedBox(width: BeautyCitaTheme.spaceXS),
              Expanded(
                child: Text(
                  _shortAddress(ride.pickupAddress),
                  style: textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          // Dotted connector
          Padding(
            padding: const EdgeInsets.only(left: 7),
            child: Column(
              children: [
                for (int i = 0; i < 2; i++)
                  Container(
                    width: 2,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 1),
                    color: BeautyCitaTheme.dividerLight,
                  ),
              ],
            ),
          ),

          // Dropoff address
          Row(
            children: [
              Icon(
                Icons.location_on_rounded,
                size: AppConstants.iconSizeSM,
                color: Colors.red.shade500,
              ),
              const SizedBox(width: BeautyCitaTheme.spaceXS),
              Expanded(
                child: Text(
                  _shortAddress(ride.dropoffAddress),
                  style: textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: BeautyCitaTheme.spaceSM),

          // Time + fare row
          Row(
            children: [
              if (ride.scheduledPickupAt != null) ...[
                const Icon(
                  Icons.schedule_rounded,
                  size: AppConstants.iconSizeSM,
                  color: BeautyCitaTheme.textLight,
                ),
                const SizedBox(width: BeautyCitaTheme.spaceXS),
                Text(
                  DateFormat('HH:mm').format(ride.scheduledPickupAt!),
                  style: textTheme.bodyMedium,
                ),
              ],
              if (ride.scheduledPickupAt != null &&
                  ride.estimatedFareMin != null)
                const SizedBox(width: BeautyCitaTheme.spaceMD),
              if (ride.estimatedFareMin != null &&
                  ride.estimatedFareMax != null) ...[
                Icon(
                  Icons.attach_money_rounded,
                  size: AppConstants.iconSizeSM,
                  color: BeautyCitaTheme.primaryRose,
                ),
                Text(
                  '\$${ride.estimatedFareMin!.toStringAsFixed(0)}-\$${ride.estimatedFareMax!.toStringAsFixed(0)} ${ride.currency}',
                  style: textTheme.bodyMedium?.copyWith(
                    color: BeautyCitaTheme.primaryRose,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),

          if (ride.isActive) ...[
            const SizedBox(height: BeautyCitaTheme.spaceSM),
            GestureDetector(
              onTap: () => _editRideLocation(ride),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.edit_location_alt_rounded,
                    size: AppConstants.iconSizeSM,
                    color: BeautyCitaTheme.primaryRose,
                  ),
                  const SizedBox(width: BeautyCitaTheme.spaceXS),
                  Text(
                    isReturn ? 'Cambiar destino' : 'Cambiar recogida',
                    style: textTheme.bodySmall?.copyWith(
                      color: BeautyCitaTheme.primaryRose,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
        color: BeautyCitaTheme.backgroundWhite,
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
          if (_canAddUber(booking))
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isAddingUber ? null : () => _addUber(booking),
                icon: _isAddingUber
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.local_taxi_rounded),
                label: Text(_isAddingUber ? 'Agregando...' : 'Agregar Uber'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, AppConstants.minTouchHeight),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppConstants.radiusLG),
                  ),
                  side: const BorderSide(color: BeautyCitaTheme.primaryRose),
                  foregroundColor: BeautyCitaTheme.primaryRose,
                ),
              ),
            ),
          if (_canAddUber(booking) && _canCancel(booking.status))
            const SizedBox(width: BeautyCitaTheme.spaceSM),
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
                  minimumSize: const Size(0, AppConstants.minTouchHeight),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
