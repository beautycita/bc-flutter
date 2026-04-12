import 'package:flutter/material.dart';
import 'package:beautycita/config/app_transitions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../config/constants.dart';
import '../../config/theme_extension.dart';
import '../../providers/admin_provider.dart';
import '../../services/supabase_client.dart';

// ---------------------------------------------------------------------------
// Date range filter enum
// ---------------------------------------------------------------------------

enum _DateRange { all, thisWeek, thisMonth, custom }

class BookingsScreen extends ConsumerStatefulWidget {
  const BookingsScreen({super.key});

  @override
  ConsumerState<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends ConsumerState<BookingsScreen> {
  _DateRange _dateRange = _DateRange.all;
  DateTimeRange? _customRange;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filterBookings(List<Map<String, dynamic>> bookings) {
    var filtered = bookings;

    // Date range filter
    if (_dateRange != _DateRange.all) {
      final now = DateTime.now();
      DateTime start;
      DateTime end = now;

      switch (_dateRange) {
        case _DateRange.thisWeek:
          start = now.subtract(Duration(days: now.weekday - 1));
          start = DateTime(start.year, start.month, start.day);
        case _DateRange.thisMonth:
          start = DateTime(now.year, now.month, 1);
        case _DateRange.custom:
          if (_customRange != null) {
            start = _customRange!.start;
            end = _customRange!.end.add(const Duration(days: 1));
          } else {
            start = DateTime(2000);
          }
        case _DateRange.all:
          start = DateTime(2000);
      }

      filtered = filtered.where((b) {
        final startsAt = b['starts_at'] as String?;
        if (startsAt == null) return false;
        final dt = DateTime.tryParse(startsAt);
        if (dt == null) return false;
        return !dt.isBefore(start) && dt.isBefore(end);
      }).toList();
    }

    // Search filter
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((b) {
        final salonName = ((b['businesses'] as Map?)?['name'] as String? ?? '').toLowerCase();
        final customerName = (b['customer_name'] as String? ?? '').toLowerCase();
        final serviceName = (b['service_name'] as String? ?? '').toLowerCase();
        return salonName.contains(q) || customerName.contains(q) || serviceName.contains(q);
      }).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final bookingsAsync = ref.watch(adminBookingsProvider);
    final colors = Theme.of(context).colorScheme;

    return bookingsAsync.when(
      data: (bookings) {
        final filtered = _filterBookings(bookings);

        int pending = 0, confirmed = 0, completed = 0, cancelled = 0, noShow = 0;
        for (final b in filtered) {
          final s = b['status'] as String? ?? 'pending';
          switch (s) {
            case 'pending':
              pending++;
            case 'confirmed':
              confirmed++;
            case 'completed':
              completed++;
            case 'cancelled_customer' || 'cancelled_business':
              cancelled++;
            case 'no_show':
              noShow++;
          }
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(adminBookingsProvider),
          child: ListView(
            padding: const EdgeInsets.all(AppConstants.paddingMD),
            children: [
              // Search bar
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).shadowColor.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: GoogleFonts.nunito(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Buscar por salon, cliente o servicio...',
                    hintStyle: GoogleFonts.nunito(fontSize: 13, color: const Color(0xFF9E9E9E)),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingMD, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: AppConstants.paddingSM),

              // Date range chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'Todas',
                      selected: _dateRange == _DateRange.all,
                      onTap: () => setState(() => _dateRange = _DateRange.all),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Esta Semana',
                      selected: _dateRange == _DateRange.thisWeek,
                      onTap: () => setState(() => _dateRange = _DateRange.thisWeek),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Este Mes',
                      selected: _dateRange == _DateRange.thisMonth,
                      onTap: () => setState(() => _dateRange = _DateRange.thisMonth),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: _customRange != null && _dateRange == _DateRange.custom
                          ? '${DateFormat('dd/MM').format(_customRange!.start)} - ${DateFormat('dd/MM').format(_customRange!.end)}'
                          : 'Personalizado',
                      selected: _dateRange == _DateRange.custom,
                      onTap: () async {
                        final range = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2024),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                          initialDateRange: _customRange,
                          locale: const Locale('es', 'MX'),
                        );
                        if (range != null) {
                          setState(() {
                            _customRange = range;
                            _dateRange = _DateRange.custom;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppConstants.paddingSM),

              // Result count
              Text(
                '${filtered.length} citas${_dateRange != _DateRange.all || _searchQuery.isNotEmpty ? ' (filtradas de ${bookings.length})' : ''}',
                style: GoogleFonts.nunito(fontSize: 12, color: const Color(0xFF757575)),
              ),
              const SizedBox(height: AppConstants.paddingSM),

              // Status grid
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: AppConstants.paddingSM,
                crossAxisSpacing: AppConstants.paddingSM,
                childAspectRatio: 1.8,
                children: [
                  _StatusChip(
                    label: 'Total',
                    count: filtered.length,
                    icon: Icons.calendar_month,
                    color: colors.primary,
                    onTap: () => _showBookings(context, 'Todas las Citas', filtered),
                  ),
                  _StatusChip(
                    label: 'Pendiente',
                    count: pending,
                    icon: Icons.hourglass_empty,
                    color: Theme.of(context).extension<BCThemeExtension>()!.warningColor,
                    onTap: () => _showBookings(context, 'Pendientes',
                        filtered.where((b) => b['status'] == 'pending').toList()),
                  ),
                  _StatusChip(
                    label: 'Confirmada',
                    count: confirmed,
                    icon: Icons.check_circle_outline,
                    color: Colors.blue,
                    onTap: () => _showBookings(context, 'Confirmadas',
                        filtered.where((b) => b['status'] == 'confirmed').toList()),
                  ),
                  _StatusChip(
                    label: 'Completada',
                    count: completed,
                    icon: Icons.done_all,
                    color: Theme.of(context).extension<BCThemeExtension>()!.successColor,
                    onTap: () => _showBookings(context, 'Completadas',
                        filtered.where((b) => b['status'] == 'completed').toList()),
                  ),
                  _StatusChip(
                    label: 'Cancelada',
                    count: cancelled,
                    icon: Icons.cancel_outlined,
                    color: Theme.of(context).colorScheme.error,
                    onTap: () => _showBookings(
                        context,
                        'Canceladas',
                        filtered
                            .where((b) =>
                                b['status'] == 'cancelled_customer' ||
                                b['status'] == 'cancelled_business')
                            .toList()),
                  ),
                  _StatusChip(
                    label: 'No Show',
                    count: noShow,
                    icon: Icons.person_off_outlined,
                    color: Colors.deepOrange,
                    onTap: () => _showBookings(context, 'No Show',
                        filtered.where((b) => b['status'] == 'no_show').toList()),
                  ),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child:
            Text('Error: $e', style: GoogleFonts.nunito(color: colors.error)),
      ),
    );
  }

  void _showBookings(BuildContext context, String title,
      List<Map<String, dynamic>> bookings) {
    final colors = Theme.of(context).colorScheme;

    showBurstBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppConstants.radiusMD)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (_, scrollCtrl) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.onSurface.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppConstants.paddingMD, vertical: AppConstants.paddingSM),
                  child: Row(
                    children: [
                      Text(title,
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: colors.onSurface,
                          )),
                      const Spacer(),
                      Text('${bookings.length}',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: colors.primary,
                          )),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: bookings.isEmpty
                      ? Center(
                          child: Text('Sin citas',
                              style: GoogleFonts.nunito(
                                  color: colors.onSurface
                                      .withValues(alpha: 0.5))))
                      : ListView.separated(
                          controller: scrollCtrl,
                          padding: const EdgeInsets.all(AppConstants.paddingMD),
                          itemCount: bookings.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, i) =>
                              _BookingTile(booking: bookings[i]),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Filter chip
// ---------------------------------------------------------------------------

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? colors.primary : colors.surface,
          borderRadius: BorderRadius.circular(AppConstants.radiusFull),
          border: Border.all(
            color: selected ? colors.primary : const Color(0xFFE0E0E0),
            width: 1,
          ),
          boxShadow: selected
              ? [BoxShadow(color: colors.primary.withValues(alpha: 0.2), blurRadius: 4, offset: const Offset(0, 1))]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Theme.of(context).colorScheme.onPrimary : const Color(0xFF616161),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status chip tile
// ---------------------------------------------------------------------------

class _StatusChip extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _StatusChip({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(AppConstants.radiusMD),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppConstants.radiusMD),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).shadowColor.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(AppConstants.paddingSM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 20),
                  const Spacer(),
                  Text(
                    '$count',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: colors.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  color: colors.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Booking tile inside the popup — tappable for detail
// ---------------------------------------------------------------------------

class _BookingTile extends StatelessWidget {
  final Map<String, dynamic> booking;

  const _BookingTile({required this.booking});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final status = booking['status'] as String? ?? 'pending';
    final serviceName = booking['service_name'] as String? ?? 'Servicio';
    final price = booking['price'] as num?;
    final startsAt = booking['starts_at'] as String?;
    final businessName =
        (booking['businesses'] as Map?)?['name'] as String? ?? '';

    String dateStr = '';
    if (startsAt != null) {
      final dt = DateTime.tryParse(startsAt)?.toLocal();
      if (dt != null) {
        dateStr =
            '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
    }

    return GestureDetector(
      onTap: () => _showBookingDetail(context, booking),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppConstants.radiusMD),
          border: Border.all(
            color: colors.onSurface.withValues(alpha: 0.08),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          serviceName,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colors.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _statusBadge(context, status),
                    ],
                  ),
                  if (businessName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      businessName,
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        color: colors.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (dateStr.isNotEmpty)
                        Text(
                          dateStr,
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            color: colors.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                      const Spacer(),
                      if (price != null)
                        Text(
                          '\$${price.toStringAsFixed(0)}',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: colors.primary,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 18, color: colors.onSurface.withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(BuildContext context, String status) {
    final ext = Theme.of(context).extension<BCThemeExtension>()!;
    final color = switch (status) {
      'pending' => ext.warningColor,
      'confirmed' => Colors.blue,
      'completed' => ext.successColor,
      'cancelled_customer' || 'cancelled_business' => Theme.of(context).colorScheme.error,
      'no_show' => Colors.deepOrange,
      _ => Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
    };
    final label = switch (status) {
      'pending' => 'Pendiente',
      'confirmed' => 'Confirmada',
      'completed' => 'Completada',
      'cancelled_customer' => 'Cancelada',
      'cancelled_business' => 'Cancelada',
      'no_show' => 'No Show',
      _ => status,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppConstants.radiusXS),
      ),
      child: Text(
        label,
        style: GoogleFonts.nunito(
            fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  void _showBookingDetail(BuildContext context, Map<String, dynamic> booking) {
    final colors = Theme.of(context).colorScheme;
    final status = booking['status'] as String? ?? 'pending';
    final serviceName = booking['service_name'] as String? ?? 'Servicio';
    final price = booking['price'] as num?;
    final startsAt = booking['starts_at'] as String?;
    final businessName = (booking['businesses'] as Map?)?['name'] as String? ?? 'Desconocido';
    final customerName = booking['customer_name'] as String? ?? booking['customer_username'] as String? ?? 'Desconocido';
    final staffName = booking['staff_name'] as String?;
    final paymentStatus = booking['payment_status'] as String?;
    final paymentMethod = booking['payment_method'] as String?;
    final transportMode = booking['transport_mode'] as String?;
    final bookingId = booking['id']?.toString() ?? '';

    String dateStr = '';
    if (startsAt != null) {
      final dt = DateTime.tryParse(startsAt)?.toLocal();
      if (dt != null) {
        dateStr = DateFormat('dd/MM/yyyy HH:mm').format(dt);
      }
    }

    final canCancel = status == 'pending' || status == 'confirmed';
    final canRefund = status == 'completed';

    showBurstBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: colors.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              Row(
                children: [
                  Expanded(
                    child: Text('Detalle de Cita',
                        style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: colors.onSurface)),
                  ),
                  _statusBadge(context, status),
                ],
              ),
              const SizedBox(height: 16),

              _DetailRow(label: 'Servicio', value: serviceName),
              if (price != null) _DetailRow(label: 'Precio', value: '\$${price.toStringAsFixed(2)}'),
              if (staffName != null && staffName.isNotEmpty) _DetailRow(label: 'Estilista', value: staffName),
              _DetailRow(label: 'Fecha/Hora', value: dateStr.isNotEmpty ? dateStr : 'Sin fecha'),
              const Divider(height: 20),
              _DetailRow(label: 'Cliente', value: customerName),
              _DetailRow(label: 'Salon', value: businessName),
              const Divider(height: 20),
              if (paymentStatus != null) _DetailRow(label: 'Estado de Pago', value: _paymentStatusLabel(paymentStatus)),
              if (paymentMethod != null) _DetailRow(label: 'Metodo de Pago', value: _paymentMethodLabel(paymentMethod)),
              if (transportMode != null && transportMode.isNotEmpty)
                _DetailRow(label: 'Transporte', value: _transportLabel(transportMode)),

              if (canCancel || canRefund) ...[
                const SizedBox(height: 20),
                Row(
                  children: [
                    if (canCancel)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _confirmAction(
                            ctx,
                            title: 'Cancelar Cita',
                            message: 'Esta accion cancelara la cita. Continuar?',
                            onConfirm: () => _cancelBooking(ctx, bookingId),
                          ),
                          icon: const Icon(Icons.cancel_outlined, size: 18),
                          label: Text('Cancelar', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Theme.of(context).colorScheme.error,
                            side: BorderSide(color: Theme.of(context).colorScheme.error),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    if (canCancel && canRefund) const SizedBox(width: 12),
                    if (canRefund)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _confirmAction(
                            ctx,
                            title: 'Reembolsar',
                            message: 'Se procesara el reembolso de esta cita. Continuar?',
                            onConfirm: () => _refundBooking(ctx, bookingId),
                          ),
                          icon: const Icon(Icons.undo, size: 18),
                          label: Text('Reembolsar', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFF59E0B),
                            side: const BorderSide(color: Color(0xFFF59E0B)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                  ],
                ),
              ],

              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  String _paymentStatusLabel(String status) {
    return switch (status) {
      'succeeded' => 'Pagado',
      'pending' => 'Pendiente',
      'failed' => 'Fallido',
      'refunded' => 'Reembolsado',
      _ => status,
    };
  }

  String _paymentMethodLabel(String method) {
    return switch (method) {
      'card' => 'Tarjeta',
      'cash' => 'Efectivo',
      'transfer' => 'Transferencia',
      _ => method,
    };
  }

  String _transportLabel(String mode) {
    return switch (mode) {
      'car' => 'Auto propio',
      'uber' => 'Uber',
      'public_transit' => 'Transporte publico',
      'walk' => 'Caminando',
      _ => mode,
    };
  }

  void _confirmAction(
    BuildContext context, {
    required String title,
    required String message,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text(message, style: GoogleFonts.nunito(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('No', style: GoogleFonts.poppins(fontSize: 13)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            child: Text('Si', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelBooking(BuildContext context, String bookingId) async {
    try {
      await SupabaseClientService.client
          .from('appointments')
          .update({'status': 'cancelled_business'})
          .eq('id', bookingId);
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cita cancelada'), duration: Duration(seconds: 2)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), duration: const Duration(seconds: 3)),
        );
      }
    }
  }

  Future<void> _refundBooking(BuildContext context, String bookingId) async {
    try {
      await SupabaseClientService.client
          .from('appointments')
          .update({
            'status': 'refunded',
            'payment_status': 'refunded',
          })
          .eq('id', bookingId);
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reembolso procesado'), duration: Duration(seconds: 2)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), duration: const Duration(seconds: 3)),
        );
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Detail row for bottom sheet
// ---------------------------------------------------------------------------

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.nunito(fontSize: 13, color: const Color(0xFF757575))),
          Flexible(
            child: Text(value,
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF212121)),
                textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}
