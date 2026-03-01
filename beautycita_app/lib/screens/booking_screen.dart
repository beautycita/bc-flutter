import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:beautycita/config/constants.dart';
import 'package:beautycita/models/provider.dart' as models;
import 'package:beautycita/providers/provider_provider.dart';
import 'package:beautycita/providers/booking_provider.dart';
import 'package:beautycita/providers/payment_methods_provider.dart';
import 'package:beautycita/services/toast_service.dart';

class BookingScreen extends ConsumerStatefulWidget {
  final String providerId;
  final String? serviceId;

  const BookingScreen({
    super.key,
    required this.providerId,
    this.serviceId,
  });

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  DateTime _selectedDate = DateTime.now();
  String? _selectedTime;
  final TextEditingController _notesController = TextEditingController();
  bool _isSubmitting = false;
  String _selectedPaymentMethod = 'card'; // 'card', 'oxxo', 'bitcoin'

  /// Generate the next 14 days starting from today.
  List<DateTime> get _availableDates {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return List.generate(14, (i) => today.add(Duration(days: i)));
  }

  /// Generate time slots from 09:00 to 19:00 in 30-minute increments.
  List<String> get _timeSlots {
    final slots = <String>[];
    for (int hour = 9; hour <= 19; hour++) {
      slots.add('${hour.toString().padLeft(2, '0')}:00');
      if (hour < 19) {
        slots.add('${hour.toString().padLeft(2, '0')}:30');
      }
    }
    return slots;
  }

  /// Day-of-week abbreviations in Spanish.
  String _dayAbbr(int weekday) {
    const days = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    return days[weekday - 1];
  }

  /// Month abbreviations in Spanish.
  String _monthAbbr(int month) {
    const months = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
    ];
    return months[month - 1];
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isToday(DateTime date) {
    return _isSameDay(date, DateTime.now());
  }

  /// Combine selected date and time into a single DateTime.
  DateTime? get _scheduledAt {
    if (_selectedTime == null) return null;
    final parts = _selectedTime!.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      hour,
      minute,
    );
  }

  /// Find the matching service from the provider's service list.
  models.ProviderService? _findService(List<models.ProviderService> services) {
    if (widget.serviceId == null) return services.isNotEmpty ? services.first : null;
    try {
      return services.firstWhere((s) => s.id == widget.serviceId);
    } catch (_) {
      return services.isNotEmpty ? services.first : null;
    }
  }

  Future<void> _confirmBooking(models.ProviderService? service) async {
    if (_scheduledAt == null) {
      ToastService.showWarning('Selecciona una fecha y hora para tu cita');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final repo = ref.read(bookingRepositoryProvider);
      await repo.createBooking(
        providerId: widget.providerId,
        providerServiceId: service?.id,
        serviceName: service?.serviceName ?? 'Servicio',
        category: service?.category ?? '',
        scheduledAt: _scheduledAt!,
        durationMinutes: service?.durationMinutes ?? 60,
        price: service?.priceMin,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );

      // Invalidate bookings cache so the list refreshes.
      ref.invalidate(userBookingsProvider);
      ref.invalidate(upcomingBookingsProvider);

      ToastService.showSuccess(AppConstants.successBookingCreated);
      if (mounted) {
        context.go('/my-bookings');
      }
    } catch (e, stack) {
      ToastService.showErrorWithDetails(ToastService.friendlyError(e), e, stack);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final providerAsync = ref.watch(providerDetailProvider(widget.providerId));
    final servicesAsync = ref.watch(
      providerServicesProvider((widget.providerId, null)),
    );
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Reservar Cita'),
      ),
      body: providerAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.paddingLG),
            child: Text(
              'Error al cargar proveedor: $err',
              style: textTheme.bodyLarge?.copyWith(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (provider) {
          if (provider == null) {
            return Center(
              child: Text(
                'Proveedor no encontrado',
                style: textTheme.bodyLarge,
              ),
            );
          }

          return servicesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(
              child: Text('Error al cargar servicios: $err'),
            ),
            data: (services) {
              final service = _findService(services);
              return _buildContent(provider, service, textTheme);
            },
          );
        },
      ),
    );
  }

  Widget _buildContent(
    models.Provider provider,
    models.ProviderService? service,
    TextTheme textTheme,
  ) {
    final priceText = service != null && service.priceMin != null
        ? '\$${service.priceMin!.toStringAsFixed(0)} MXN'
        : 'Precio por confirmar';
    final durationText = service != null
        ? '${service.durationMinutes} min'
        : '60 min';

    return Column(
      children: [
        // Scrollable content
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.screenPaddingHorizontal,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppConstants.paddingMD),

                // -- Provider & Service Info --
                _buildProviderCard(provider, service, textTheme, priceText, durationText),

                const SizedBox(height: AppConstants.paddingLG),

                // -- Date Picker Section --
                Text(
                  'Selecciona una fecha',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppConstants.paddingSM),
                _buildDateChips(textTheme),

                const SizedBox(height: AppConstants.paddingLG),

                // -- Time Slot Section --
                Text(
                  'Selecciona un horario',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppConstants.paddingSM),
                _buildTimeGrid(textTheme),

                const SizedBox(height: AppConstants.paddingLG),

                // -- Notes Field --
                Text(
                  'Notas (opcional)',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppConstants.paddingSM),
                TextField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Indicaciones especiales, alergias, etc.',
                  ),
                ),

                const SizedBox(height: AppConstants.paddingLG),

                // -- Payment Method Section --
                Text(
                  'Metodo de pago',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppConstants.paddingSM),
                _buildPaymentMethods(textTheme),

                const SizedBox(height: AppConstants.paddingLG),
              ],
            ),
          ),
        ),

        // -- Bottom Price & Confirm Button --
        _buildBottomBar(textTheme, priceText, service),
      ],
    );
  }

  Widget _buildProviderCard(
    models.Provider provider,
    models.ProviderService? service,
    TextTheme textTheme,
    String priceText,
    String durationText,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
      ),
      child: Row(
        children: [
          // Provider avatar
          Container(
            width: AppConstants.avatarSizeLG,
            height: AppConstants.avatarSizeLG,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppConstants.radiusSM),
            ),
            child: Icon(
              Icons.store_rounded,
              color: colorScheme.primary,
              size: AppConstants.iconSizeLG,
            ),
          ),
          const SizedBox(width: AppConstants.paddingMD),
          // Provider details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider.name,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppConstants.paddingXS),
                Text(
                  service?.serviceName ?? 'Servicio general',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppConstants.paddingXS),
                Row(
                  children: [
                    Icon(
                      Icons.attach_money_rounded,
                      size: AppConstants.iconSizeSM,
                      color: colorScheme.primary,
                    ),
                    Text(
                      priceText,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: AppConstants.paddingMD),
                    Icon(
                      Icons.schedule_rounded,
                      size: AppConstants.iconSizeSM,
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: AppConstants.paddingXS),
                    Text(
                      durationText,
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateChips(TextTheme textTheme) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _availableDates.length,
        separatorBuilder: (_, __) =>
            const SizedBox(width: AppConstants.paddingSM),
        itemBuilder: (context, index) {
          final date = _availableDates[index];
          final isSelected = _isSameDay(date, _selectedDate);
          final isToday = _isToday(date);

          return GestureDetector(
            onTap: () => setState(() => _selectedDate = date),
            child: AnimatedContainer(
              duration: AppConstants.shortAnimation,
              width: 64,
              decoration: BoxDecoration(
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.surface,
                borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                border: isToday && !isSelected
                    ? Border.all(
                        color: colorScheme.primary,
                        width: 2,
                      )
                    : null,
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: colorScheme.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _dayAbbr(date.weekday),
                    style: textTheme.labelSmall?.copyWith(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.8)
                          : colorScheme.onSurface.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppConstants.paddingXS),
                  Text(
                    '${date.day}',
                    style: textTheme.headlineSmall?.copyWith(
                      color: isSelected
                          ? Colors.white
                          : colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    _monthAbbr(date.month),
                    style: textTheme.labelSmall?.copyWith(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.8)
                          : colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimeGrid(TextTheme textTheme) {
    final colorScheme = Theme.of(context).colorScheme;

    return Wrap(
      spacing: AppConstants.paddingSM,
      runSpacing: AppConstants.paddingSM,
      children: _timeSlots.map((slot) {
        final isSelected = slot == _selectedTime;

        return GestureDetector(
          onTap: () => setState(() => _selectedTime = slot),
          child: AnimatedContainer(
            duration: AppConstants.shortAnimation,
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.paddingMD,
              vertical: AppConstants.paddingSM + 2,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.surface,
              borderRadius: BorderRadius.circular(AppConstants.radiusSM),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              slot,
              style: textTheme.bodyMedium?.copyWith(
                color: isSelected ? Colors.white : colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPaymentMethods(TextTheme textTheme) {
    final pm = ref.watch(paymentMethodsProvider);
    final defaultCard = pm.cards.isNotEmpty ? pm.cards.first : null;

    return Column(
      children: [
        // Card option (default)
        _PaymentOptionTile(
          icon: Icons.credit_card_rounded,
          iconColor: const Color(0xFF1A73E8),
          label: defaultCard != null
              ? '${defaultCard.displayBrand} ****${defaultCard.last4}'
              : 'Tarjeta de credito/debito',
          subtitle: defaultCard != null ? 'Predeterminado' : 'Agregar tarjeta al pagar',
          selected: _selectedPaymentMethod == 'card',
          onTap: () => setState(() => _selectedPaymentMethod = 'card'),
        ),
        const SizedBox(height: 8),
        // OXXO
        _PaymentOptionTile(
          icon: Icons.store_rounded,
          iconColor: const Color(0xFFCC0000),
          label: 'Pago en efectivo',
          subtitle: 'OXXO, 7-Eleven',
          selected: _selectedPaymentMethod == 'oxxo',
          onTap: () => setState(() => _selectedPaymentMethod = 'oxxo'),
        ),
        const SizedBox(height: 8),
        // Bitcoin
        _PaymentOptionTile(
          icon: Icons.currency_bitcoin_rounded,
          iconColor: const Color(0xFFF7931A),
          label: 'Bitcoin',
          subtitle: 'Pago con criptomoneda',
          selected: _selectedPaymentMethod == 'bitcoin',
          onTap: () => setState(() => _selectedPaymentMethod = 'bitcoin'),
        ),
      ],
    );
  }

  Widget _buildBottomBar(
    TextTheme textTheme,
    String priceText,
    models.ProviderService? service,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.only(
        left: AppConstants.screenPaddingHorizontal,
        right: AppConstants.screenPaddingHorizontal,
        top: AppConstants.paddingMD,
        bottom: MediaQuery.of(context).padding.bottom + AppConstants.paddingMD,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Price row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                priceText,
                style: textTheme.titleLarge?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.paddingSM),

          // Confirm button
          SizedBox(
            width: double.infinity,
            height: AppConstants.minTouchHeight,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : () => _confirmBooking(service),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusLG),
                ),
                elevation: AppConstants.elevationMedium,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Confirmar Reservación',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentOptionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _PaymentOptionTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppConstants.shortAnimation,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primary.withValues(alpha: 0.06)
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(AppConstants.radiusSM),
          border: Border.all(
            color: selected
                ? colorScheme.primary
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected
                  ? colorScheme.primary
                  : colorScheme.onSurface.withValues(alpha: 0.2),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
