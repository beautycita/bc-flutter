import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/constants.dart';
import '../../providers/admin_provider.dart';
import '../../services/supabase_client.dart';

class BookingsScreen extends ConsumerStatefulWidget {
  const BookingsScreen({super.key});

  @override
  ConsumerState<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends ConsumerState<BookingsScreen> {
  String? _statusFilter;

  static const _statuses = [
    null,
    'pending',
    'confirmed',
    'completed',
    'cancelled_customer',
    'no_show',
  ];
  static const _statusLabels = [
    'Todos',
    'Pendiente',
    'Confirmada',
    'Completada',
    'Cancelada',
    'No Show',
  ];

  List<Map<String, dynamic>> _filtered(List<Map<String, dynamic>> bookings) {
    if (_statusFilter == null) return bookings;
    return bookings
        .where((b) => b['status'] == _statusFilter)
        .toList();
  }

  Future<void> _changeStatus(
      Map<String, dynamic> booking, String newStatus) async {
    final id = booking['id'] as String;
    try {
      await SupabaseClientService.client
          .from('appointments')
          .update({'status': newStatus}).eq('id', id);
      ref.invalidate(adminBookingsProvider);
      ref.invalidate(adminDashStatsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cita actualizada: $newStatus')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookingsAsync = ref.watch(adminBookingsProvider);
    final colors = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Filter chips
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppConstants.paddingMD,
            AppConstants.paddingMD,
            AppConstants.paddingMD,
            AppConstants.paddingSM,
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(_statuses.length, (i) {
                final selected = _statusFilter == _statuses[i];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(
                      _statusLabels[i],
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                    selected: selected,
                    onSelected: (_) =>
                        setState(() => _statusFilter = _statuses[i]),
                  ),
                );
              }),
            ),
          ),
        ),

        // Bookings list
        Expanded(
          child: bookingsAsync.when(
            data: (bookings) {
              final filtered = _filtered(bookings);
              if (filtered.isEmpty) {
                return Center(
                  child: Text('Sin citas',
                      style: GoogleFonts.nunito(
                          color:
                              colors.onSurface.withValues(alpha: 0.5))),
                );
              }
              return RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(adminBookingsProvider),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.paddingMD),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final b = filtered[i];
                    final status = b['status'] as String? ?? 'pending';
                    return Card(
                      elevation: 0,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusMD),
                      ),
                      margin: const EdgeInsets.only(
                          bottom: AppConstants.paddingSM),
                      child: Padding(
                        padding:
                            const EdgeInsets.all(AppConstants.paddingSM),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        (b['created_at'] as String?)
                                                ?.split('T')[0] ??
                                            '',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: colors.onSurface,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      _statusChip(status),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  if (b['service_name'] != null)
                                    Text(
                                      b['service_name'] as String,
                                      style: GoogleFonts.nunito(
                                        fontSize: 13,
                                        color: colors.onSurface
                                            .withValues(alpha: 0.6),
                                      ),
                                    ),
                                  Row(
                                    children: [
                                      if (b['user_id'] != null)
                                        Text(
                                          'ID: ${(b['user_id'] as String).substring(0, 8)}...',
                                          style: GoogleFonts.nunito(
                                            fontSize: 11,
                                            color: colors.onSurface
                                                .withValues(alpha: 0.4),
                                          ),
                                        ),
                                      const Spacer(),
                                      if (b['price'] != null)
                                        Text(
                                          '\$${(b['price'] as num).toStringAsFixed(0)}',
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
                            PopupMenuButton<String>(
                              icon: Icon(Icons.more_vert,
                                  color: colors.onSurface
                                      .withValues(alpha: 0.4),
                                  size: 20),
                              onSelected: (v) => _changeStatus(b, v),
                              itemBuilder: (_) => [
                                for (final s in [
                                  'pending',
                                  'confirmed',
                                  'completed',
                                  'cancelled_customer',
                                  'cancelled_business',
                                  'no_show',
                                ])
                                  PopupMenuItem(
                                      value: s, child: Text(s)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text('Error: $e',
                  style: GoogleFonts.nunito(color: colors.error)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _statusChip(String status) {
    final color = switch (status) {
      'pending' => Colors.orange,
      'confirmed' => Colors.blue,
      'completed' => Colors.green,
      'cancelled_customer' || 'cancelled_business' => Colors.red,
      'no_show' => Colors.deepOrange,
      _ => Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppConstants.radiusXS),
      ),
      child: Text(
        status,
        style: GoogleFonts.nunito(
            fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
