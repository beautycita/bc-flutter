import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/constants.dart';
import '../../providers/business_provider.dart';
import '../../services/supabase_client.dart';

class BusinessCalendarScreen extends ConsumerStatefulWidget {
  const BusinessCalendarScreen({super.key});

  @override
  ConsumerState<BusinessCalendarScreen> createState() =>
      _BusinessCalendarScreenState();
}

class _BusinessCalendarScreenState
    extends ConsumerState<BusinessCalendarScreen> {
  late DateTime _selectedDate;
  bool _weekView = false;
  String? _staffFilter; // null = all staff

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  DateTimeRange get _range {
    if (_weekView) {
      final start = _selectedDate.subtract(
          Duration(days: _selectedDate.weekday - 1));
      final end = DateTime(start.year, start.month, start.day + 6, 23, 59, 59);
      return DateTimeRange(start: start, end: end);
    }
    final start = DateTime(_selectedDate.year, _selectedDate.month,
        _selectedDate.day);
    final end = DateTime(_selectedDate.year, _selectedDate.month,
        _selectedDate.day, 23, 59, 59);
    return DateTimeRange(start: start, end: end);
  }

  @override
  Widget build(BuildContext context) {
    final range = _range;

    final apptsAsync = ref.watch(businessAppointmentsProvider(
      (start: range.start.toIso8601String(), end: range.end.toIso8601String()),
    ));
    final blocksAsync = ref.watch(businessScheduleBlocksProvider(
      (start: range.start.toIso8601String(), end: range.end.toIso8601String()),
    ));
    final staffAsync = ref.watch(businessStaffProvider);
    final bizAsync = ref.watch(currentBusinessProvider);
    final ownerId = bizAsync.valueOrNull?['owner_id'] as String?;

    return Column(
      children: [
        // Navigation bar
        _DateNavBar(
          selectedDate: _selectedDate,
          weekView: _weekView,
          range: range,
          onPrev: () => setState(() => _selectedDate = _selectedDate
              .subtract(Duration(days: _weekView ? 7 : 1))),
          onNext: () => setState(() => _selectedDate = _selectedDate
              .add(Duration(days: _weekView ? 7 : 1))),
          onPickDate: _pickDate,
          onToggleView: (v) => setState(() => _weekView = v),
        ),

        // Staff filter chips
        staffAsync.when(
          data: (staff) {
            final hasFilters = ownerId != null || staff.isNotEmpty;
            if (!hasFilters) return const SizedBox.shrink();
            return SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.paddingMD),
                children: [
                  _FilterChip(
                    label: 'Todos',
                    selected: _staffFilter == null,
                    onTap: () => setState(() => _staffFilter = null),
                  ),
                  if (ownerId != null)
                    _FilterChip(
                      label: 'Yo',
                      selected: _staffFilter == ownerId,
                      onTap: () =>
                          setState(() => _staffFilter = ownerId),
                    ),
                  for (final s in staff)
                    _FilterChip(
                      label: '${s['first_name'] ?? ''}',
                      selected: _staffFilter == s['id'],
                      onTap: () => setState(
                          () => _staffFilter = s['id'] as String),
                    ),
                ],
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (e, st) => const SizedBox.shrink(),
        ),

        const SizedBox(height: 4),

        // Timeline body
        Expanded(
          child: _weekView
              ? _WeekView(
                  range: range,
                  apptsAsync: apptsAsync,
                  onDayTap: (d) => setState(() {
                    _selectedDate = d;
                    _weekView = false;
                  }),
                )
              : _DayTimeline(
                  date: _selectedDate,
                  apptsAsync: apptsAsync,
                  blocksAsync: blocksAsync,
                  staffFilter: _staffFilter,
                  ownerId: ownerId,
                  onAction: _handleAction,
                  onBlockTime: () => _showBlockTimeSheet(context),
                  onAddWalkin: (hour) => _showWalkinSheet(context, hour),
                  onRefresh: _refresh,
                ),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  void _refresh() {
    final range = _range;
    ref.invalidate(businessAppointmentsProvider(
      (start: range.start.toIso8601String(), end: range.end.toIso8601String()),
    ));
    ref.invalidate(businessScheduleBlocksProvider(
      (start: range.start.toIso8601String(), end: range.end.toIso8601String()),
    ));
    ref.invalidate(businessStatsProvider);
  }

  Future<void> _handleAction(Map<String, dynamic> appt, String action) async {
    final id = appt['id'] as String;

    if (action == 'reschedule') {
      _showRescheduleSheet(context, appt);
      return;
    }

    if (action == 'no_show') {
      _showNoShowSheet(context, appt);
      return;
    }

    try {
      await SupabaseClientService.client
          .from('appointments')
          .update({'status': action}).eq('id', id);
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cita actualizada')),
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

  void _showBlockTimeSheet(BuildContext context) {
    final staffAsync = ref.read(businessStaffProvider);
    final staffList = staffAsync.valueOrNull ?? [];
    final biz = ref.read(currentBusinessProvider).valueOrNull;

    // Include owner as first staff option
    final allStaff = <Map<String, dynamic>>[];
    if (biz != null) {
      allStaff.add({
        'id': biz['owner_id'],
        'first_name': 'Yo',
        'last_name': '(Dueño)',
      });
    }
    allStaff.addAll(staffList);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _BlockTimeSheet(
        staffList: allStaff,
        onSaved: _refresh,
      ),
    );
  }

  void _showWalkinSheet(BuildContext context, int hour) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _WalkinSheet(
        date: _selectedDate,
        hour: hour,
        onSaved: _refresh,
      ),
    );
  }

  void _showRescheduleSheet(
      BuildContext context, Map<String, dynamic> appt) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _RescheduleSheet(
        appointment: appt,
        onSaved: _refresh,
      ),
    );
  }

  void _showNoShowSheet(BuildContext context, Map<String, dynamic> appt) {
    final deposit = (appt['deposit_amount'] as num?)?.toDouble() ?? 0;
    final price = (appt['price'] as num?)?.toDouble() ?? 0;

    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        final colors = Theme.of(ctx).colorScheme;
        return Padding(
          padding: const EdgeInsets.all(AppConstants.paddingLG),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Marcar No-Show',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                  )),
              const SizedBox(height: AppConstants.paddingMD),
              if (deposit > 0) ...[
                Text('Deposito cobrado: \$${deposit.toStringAsFixed(0)} MXN',
                    style: GoogleFonts.nunito(color: colors.onSurface)),
                Text('Total de la cita: \$${price.toStringAsFixed(0)} MXN',
                    style: GoogleFonts.nunito(color: colors.onSurface)),
                const SizedBox(height: AppConstants.paddingMD),
                Text('El deposito sera retenido conforme a tu politica.',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: colors.onSurface.withValues(alpha: 0.6),
                    )),
              ] else
                Text('No se cobro deposito para esta cita.',
                    style: GoogleFonts.nunito(color: colors.onSurface)),
              const SizedBox(height: AppConstants.paddingLG),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _handleAction(appt, 'no_show');
                },
                child: const Text('Confirmar No-Show'),
              ),
              const SizedBox(height: AppConstants.paddingSM),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Date navigation bar
// ---------------------------------------------------------------------------

class _DateNavBar extends StatelessWidget {
  final DateTime selectedDate;
  final bool weekView;
  final DateTimeRange range;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onPickDate;
  final ValueChanged<bool> onToggleView;

  const _DateNavBar({
    required this.selectedDate,
    required this.weekView,
    required this.range,
    required this.onPrev,
    required this.onNext,
    required this.onPickDate,
    required this.onToggleView,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingSM,
        vertical: AppConstants.paddingXS,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: onPrev,
          ),
          Expanded(
            child: GestureDetector(
              onTap: onPickDate,
              child: Text(
                weekView
                    ? '${_fmtShort(range.start)} - ${_fmtShort(range.end)}'
                    : _fmtFull(selectedDate),
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: onNext,
          ),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Dia')),
              ButtonSegment(value: true, label: Text('Sem')),
            ],
            selected: {weekView},
            onSelectionChanged: (v) => onToggleView(v.first),
            style: SegmentedButton.styleFrom(
              textStyle: GoogleFonts.nunito(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  static const _days = ['Lun', 'Mar', 'Mie', 'Jue', 'Vie', 'Sab', 'Dom'];
  static const _months = [
    'Ene','Feb','Mar','Abr','May','Jun',
    'Jul','Ago','Sep','Oct','Nov','Dic'
  ];

  String _fmtFull(DateTime d) =>
      '${_days[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]} ${d.year}';

  String _fmtShort(DateTime d) => '${d.day}/${d.month}';
}

// ---------------------------------------------------------------------------
// Staff filter chip
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
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: colors.primary.withValues(alpha: 0.15),
        checkmarkColor: colors.primary,
        labelStyle: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          color: selected ? colors.primary : colors.onSurface,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Day timeline view — the main interactive calendar
// ---------------------------------------------------------------------------

class _DayTimeline extends StatelessWidget {
  final DateTime date;
  final AsyncValue<List<Map<String, dynamic>>> apptsAsync;
  final AsyncValue<List<Map<String, dynamic>>> blocksAsync;
  final String? staffFilter;
  final String? ownerId;
  final Future<void> Function(Map<String, dynamic>, String) onAction;
  final VoidCallback onBlockTime;
  final ValueChanged<int> onAddWalkin;
  final VoidCallback onRefresh;

  const _DayTimeline({
    required this.date,
    required this.apptsAsync,
    required this.blocksAsync,
    required this.staffFilter,
    this.ownerId,
    required this.onAction,
    required this.onBlockTime,
    required this.onAddWalkin,
    required this.onRefresh,
  });

  static const _startHour = 8;
  static const _endHour = 21;
  static const _hourHeight = 80.0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () async => onRefresh(),
          child: ListView.builder(
            padding: const EdgeInsets.only(
              left: 50,
              right: AppConstants.paddingMD,
              bottom: 80,
            ),
            itemCount: _endHour - _startHour,
            itemBuilder: (context, index) {
              final hour = _startHour + index;
              return _HourRow(
                hour: hour,
                hourHeight: _hourHeight,
                appointments: _apptsForHour(hour),
                blocks: _blocksForHour(hour),
                onAction: onAction,
                onTapEmpty: () => onAddWalkin(hour),
              );
            },
          ),
        ),
        // Hour labels on the left
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: 46,
          child: IgnorePointer(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: _endHour - _startHour,
              itemBuilder: (context, index) {
                final hour = _startHour + index;
                return SizedBox(
                  height: _hourHeight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 0, left: 4),
                    child: Text(
                      '${hour.toString().padLeft(2, '0')}:00',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: colors.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        // FAB for blocking time
        Positioned(
          right: AppConstants.paddingMD,
          bottom: AppConstants.paddingMD,
          child: FloatingActionButton.small(
            heroTag: 'blockTime',
            onPressed: onBlockTime,
            child: const Icon(Icons.block_rounded, size: 20),
          ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _apptsForHour(int hour) {
    final appts = apptsAsync.valueOrNull ?? [];
    return appts.where((a) {
      final startsAt = a['starts_at'] as String?;
      if (startsAt == null) return false;
      final dt = DateTime.tryParse(startsAt);
      if (dt == null) return false;
      if (dt.hour != hour) return false;
      if (staffFilter != null) {
        final sid = a['staff_id'];
        if (staffFilter == ownerId) {
          // Owner filter: show owner's appts + unassigned
          if (sid != null && sid != staffFilter) return false;
        } else {
          if (sid != staffFilter) return false;
        }
      }
      return true;
    }).toList();
  }

  List<Map<String, dynamic>> _blocksForHour(int hour) {
    final blocks = blocksAsync.valueOrNull ?? [];
    return blocks.where((b) {
      final startsAt = DateTime.tryParse(b['starts_at'] as String? ?? '');
      final endsAt = DateTime.tryParse(b['ends_at'] as String? ?? '');
      if (startsAt == null || endsAt == null) return false;
      if (staffFilter != null) {
        final sid = b['staff_id'];
        if (staffFilter == ownerId) {
          if (sid != null && sid != staffFilter) return false;
        } else {
          if (sid != staffFilter) return false;
        }
      }
      return startsAt.hour <= hour && endsAt.hour > hour;
    }).toList();
  }
}

// ---------------------------------------------------------------------------
// Single hour row in the timeline
// ---------------------------------------------------------------------------

class _HourRow extends StatelessWidget {
  final int hour;
  final double hourHeight;
  final List<Map<String, dynamic>> appointments;
  final List<Map<String, dynamic>> blocks;
  final Future<void> Function(Map<String, dynamic>, String) onAction;
  final VoidCallback onTapEmpty;

  const _HourRow({
    required this.hour,
    required this.hourHeight,
    required this.appointments,
    required this.blocks,
    required this.onAction,
    required this.onTapEmpty,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hasBlocks = blocks.isNotEmpty;

    return GestureDetector(
      onTap: appointments.isEmpty && !hasBlocks ? onTapEmpty : null,
      child: Container(
        height: hourHeight,
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: colors.onSurface.withValues(alpha: 0.06),
            ),
          ),
        ),
        child: hasBlocks && appointments.isEmpty
            ? _BlockedIndicator(blocks: blocks)
            : appointments.isEmpty
                ? Center(
                    child: Icon(Icons.add_rounded,
                        size: 18,
                        color: colors.onSurface.withValues(alpha: 0.15)),
                  )
                : Column(
                    children: [
                      for (final appt in appointments)
                        Expanded(
                          child: _TimelineApptCard(
                            appointment: appt,
                            onAction: onAction,
                          ),
                        ),
                    ],
                  ),
      ),
    );
  }
}

class _BlockedIndicator extends StatelessWidget {
  final List<Map<String, dynamic>> blocks;
  const _BlockedIndicator({required this.blocks});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final reason = blocks.first['reason'] as String? ?? 'blocked';
    final reasonLabel = _reasonLabel(reason);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      decoration: BoxDecoration(
        color: colors.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colors.onSurface.withValues(alpha: 0.1),
          style: BorderStyle.solid,
        ),
      ),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.block_rounded,
                size: 14, color: colors.onSurface.withValues(alpha: 0.3)),
            const SizedBox(width: 4),
            Text(
              reasonLabel,
              style: GoogleFonts.nunito(
                fontSize: 12,
                color: colors.onSurface.withValues(alpha: 0.4),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _reasonLabel(String reason) {
    switch (reason) {
      case 'lunch': return 'Almuerzo';
      case 'day_off': return 'Dia libre';
      case 'vacation': return 'Vacaciones';
      default: return 'Bloqueado';
    }
  }
}

// ---------------------------------------------------------------------------
// Appointment card in timeline
// ---------------------------------------------------------------------------

class _TimelineApptCard extends StatelessWidget {
  final Map<String, dynamic> appointment;
  final Future<void> Function(Map<String, dynamic>, String) onAction;

  const _TimelineApptCard({
    required this.appointment,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final status = appointment['status'] as String? ?? 'pending';
    final service = appointment['service_name'] as String? ?? 'Servicio';
    final price = (appointment['price'] as num?)?.toDouble() ?? 0;
    final startsAt = appointment['starts_at'] as String?;
    final statusColor = _statusColor(status);

    String timeStr = '';
    if (startsAt != null) {
      final dt = DateTime.tryParse(startsAt);
      if (dt != null) {
        timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
    }

    return GestureDetector(
      onTap: () => _showActionSheet(context),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(color: statusColor, width: 3),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    service,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '$timeStr • \$${price.toStringAsFixed(0)} • ${_statusLabel(status)}',
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.more_vert_rounded,
                size: 18, color: colors.onSurface.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }

  void _showActionSheet(BuildContext context) {
    final status = appointment['status'] as String? ?? 'pending';
    final colors = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingMD),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (status == 'pending') ...[
                _ActionTile(
                  icon: Icons.check_circle_rounded,
                  label: 'Confirmar',
                  color: Colors.blue,
                  onTap: () {
                    Navigator.pop(ctx);
                    onAction(appointment, 'confirmed');
                  },
                ),
                _ActionTile(
                  icon: Icons.cancel_rounded,
                  label: 'Cancelar',
                  color: Colors.red,
                  onTap: () {
                    Navigator.pop(ctx);
                    onAction(appointment, 'cancelled_business');
                  },
                ),
              ],
              if (status == 'confirmed') ...[
                _ActionTile(
                  icon: Icons.done_all_rounded,
                  label: 'Completar',
                  color: Colors.green,
                  onTap: () {
                    Navigator.pop(ctx);
                    onAction(appointment, 'completed');
                  },
                ),
                _ActionTile(
                  icon: Icons.person_off_rounded,
                  label: 'No-Show',
                  color: Colors.orange,
                  onTap: () {
                    Navigator.pop(ctx);
                    onAction(appointment, 'no_show');
                  },
                ),
                _ActionTile(
                  icon: Icons.cancel_rounded,
                  label: 'Cancelar',
                  color: Colors.red,
                  onTap: () {
                    Navigator.pop(ctx);
                    onAction(appointment, 'cancelled_business');
                  },
                ),
              ],
              _ActionTile(
                icon: Icons.schedule_rounded,
                label: 'Reprogramar',
                color: colors.primary,
                onTap: () {
                  Navigator.pop(ctx);
                  onAction(appointment, 'reschedule');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'confirmed': return Colors.blue;
      case 'completed': return Colors.green;
      case 'cancelled_customer':
      case 'cancelled_business': return Colors.red;
      case 'no_show': return Colors.grey;
      default: return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending': return 'Pendiente';
      case 'confirmed': return 'Confirmada';
      case 'completed': return 'Completada';
      case 'cancelled_customer': return 'Canc. cliente';
      case 'cancelled_business': return 'Canc. negocio';
      case 'no_show': return 'No asistio';
      default: return status;
    }
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label,
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: color,
          )),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Week overview
// ---------------------------------------------------------------------------

class _WeekView extends StatelessWidget {
  final DateTimeRange range;
  final AsyncValue<List<Map<String, dynamic>>> apptsAsync;
  final ValueChanged<DateTime> onDayTap;

  const _WeekView({
    required this.range,
    required this.apptsAsync,
    required this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final appts = apptsAsync.valueOrNull ?? [];
    final now = DateTime.now();

    return Padding(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      child: Row(
        children: List.generate(7, (i) {
          final day = range.start.add(Duration(days: i));
          final dayAppts = appts.where((a) {
            final dt = DateTime.tryParse(a['starts_at'] as String? ?? '');
            return dt != null &&
                dt.year == day.year &&
                dt.month == day.month &&
                dt.day == day.day;
          }).toList();

          final isToday = day.year == now.year &&
              day.month == now.month &&
              day.day == now.day;

          return Expanded(
            child: GestureDetector(
              onTap: () => onDayTap(day),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isToday
                      ? colors.primary.withValues(alpha: 0.1)
                      : colors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: isToday
                      ? Border.all(color: colors.primary, width: 2)
                      : Border.all(
                          color: colors.onSurface.withValues(alpha: 0.08)),
                ),
                child: Column(
                  children: [
                    Text(
                      _dayName(day.weekday),
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isToday
                            ? colors.primary
                            : colors.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    Text(
                      '${day.day}',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isToday ? colors.primary : colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: dayAppts.isEmpty
                            ? colors.onSurface.withValues(alpha: 0.05)
                            : colors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${dayAppts.length}',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: dayAppts.isEmpty
                              ? colors.onSurface.withValues(alpha: 0.3)
                              : colors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Status dots
                    Expanded(
                      child: ListView(
                        physics: const NeverScrollableScrollPhysics(),
                        children: dayAppts.take(5).map((a) {
                          final status = a['status'] as String? ?? 'pending';
                          return Container(
                            height: 6,
                            margin: const EdgeInsets.only(bottom: 2),
                            decoration: BoxDecoration(
                              color: _dotColor(status),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  String _dayName(int weekday) {
    const names = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    return names[weekday - 1];
  }

  Color _dotColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'confirmed': return Colors.blue;
      case 'completed': return Colors.green;
      default: return Colors.grey;
    }
  }
}

// ---------------------------------------------------------------------------
// Block time bottom sheet
// ---------------------------------------------------------------------------

class _BlockTimeSheet extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> staffList;
  final VoidCallback onSaved;

  const _BlockTimeSheet({required this.staffList, required this.onSaved});

  @override
  ConsumerState<_BlockTimeSheet> createState() => _BlockTimeSheetState();
}

class _BlockTimeSheetState extends ConsumerState<_BlockTimeSheet> {
  String? _staffId; // null = whole salon
  DateTime _date = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 14, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 15, minute: 0);
  String _reason = 'lunch';
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppConstants.paddingLG,
        AppConstants.paddingLG,
        AppConstants.paddingLG,
        MediaQuery.of(context).viewInsets.bottom + AppConstants.paddingLG,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Bloquear Horario',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                )),
            const SizedBox(height: AppConstants.paddingMD),
            DropdownButtonFormField<String?>(
              initialValue: _staffId,
              decoration: const InputDecoration(labelText: 'Para quien'),
              items: [
                const DropdownMenuItem(
                    value: null, child: Text('Todo el salon')),
                for (final s in widget.staffList)
                  DropdownMenuItem(
                    value: s['id'] as String,
                    child: Text('${s['first_name']} ${s['last_name'] ?? ''}'.trim()),
                  ),
              ],
              onChanged: (v) => setState(() => _staffId = v),
            ),
            const SizedBox(height: AppConstants.paddingSM),
            DropdownButtonFormField<String>(
              initialValue: _reason,
              decoration: const InputDecoration(labelText: 'Motivo'),
              items: const [
                DropdownMenuItem(value: 'lunch', child: Text('Almuerzo')),
                DropdownMenuItem(value: 'day_off', child: Text('Dia libre')),
                DropdownMenuItem(value: 'vacation', child: Text('Vacaciones')),
                DropdownMenuItem(value: 'other', child: Text('Otro')),
              ],
              onChanged: (v) => setState(() => _reason = v ?? 'other'),
            ),
            const SizedBox(height: AppConstants.paddingSM),
            ListTile(
              title: const Text('Fecha'),
              trailing: Text('${_date.day}/${_date.month}/${_date.year}'),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2030),
                );
                if (d != null) setState(() => _date = d);
              },
            ),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    title: const Text('Desde'),
                    trailing: Text(_startTime.format(context)),
                    onTap: () async {
                      final t = await showTimePicker(
                        context: context,
                        initialTime: _startTime,
                      );
                      if (t != null) setState(() => _startTime = t);
                    },
                  ),
                ),
                Expanded(
                  child: ListTile(
                    title: const Text('Hasta'),
                    trailing: Text(_endTime.format(context)),
                    onTap: () async {
                      final t = await showTimePicker(
                        context: context,
                        initialTime: _endTime,
                      );
                      if (t != null) setState(() => _endTime = t);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.paddingLG),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Bloquear'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final biz = await ref.read(currentBusinessProvider.future);
      if (biz == null) throw Exception('No business');

      final startsAt = DateTime(_date.year, _date.month, _date.day,
          _startTime.hour, _startTime.minute);
      final endsAt = DateTime(_date.year, _date.month, _date.day,
          _endTime.hour, _endTime.minute);

      await SupabaseClientService.client
          .from('staff_schedule_blocks')
          .insert({
        'business_id': biz['id'],
        'staff_id': _staffId,
        'starts_at': startsAt.toIso8601String(),
        'ends_at': endsAt.toIso8601String(),
        'reason': _reason,
      });

      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ---------------------------------------------------------------------------
// Walk-in bottom sheet
// ---------------------------------------------------------------------------

class _WalkinSheet extends ConsumerStatefulWidget {
  final DateTime date;
  final int hour;
  final VoidCallback onSaved;

  const _WalkinSheet({
    required this.date,
    required this.hour,
    required this.onSaved,
  });

  @override
  ConsumerState<_WalkinSheet> createState() => _WalkinSheetState();
}

class _WalkinSheetState extends ConsumerState<_WalkinSheet> {
  String? _serviceId;
  String? _staffId;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final servicesAsync = ref.watch(businessServicesProvider);
    final staffAsync = ref.watch(businessStaffProvider);
    final bizAsync = ref.watch(currentBusinessProvider);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppConstants.paddingLG,
        AppConstants.paddingLG,
        AppConstants.paddingLG,
        MediaQuery.of(context).viewInsets.bottom + AppConstants.paddingLG,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Agregar Walk-in',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                )),
            Text(
              '${widget.date.day}/${widget.date.month} a las ${widget.hour.toString().padLeft(2, '0')}:00',
              style: GoogleFonts.nunito(
                fontSize: 14,
                color: colors.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: AppConstants.paddingMD),
            servicesAsync.when(
              data: (services) => DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Servicio'),
                items: services.map((s) {
                  return DropdownMenuItem(
                    value: s['id'] as String,
                    child: Text(
                      '${s['name']} (\$${(s['price'] as num?)?.toStringAsFixed(0) ?? '0'})',
                    ),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _serviceId = v),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, st) => Text('Error: $e'),
            ),
            const SizedBox(height: AppConstants.paddingSM),
            staffAsync.when(
              data: (staff) {
                // Include owner as first option
                final allStaff = <Map<String, dynamic>>[];
                final biz = bizAsync.valueOrNull;
                if (biz != null) {
                  allStaff.add({
                    'id': biz['owner_id'],
                    'first_name': 'Yo',
                    'last_name': '(Dueño)',
                  });
                }
                allStaff.addAll(staff);
                return DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Estilista'),
                  items: allStaff.map((s) {
                    return DropdownMenuItem(
                      value: s['id'] as String,
                      child: Text(
                          '${s['first_name']} ${s['last_name'] ?? ''}'.trim()),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _staffId = v),
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (e, st) => Text('Error: $e'),
            ),
            const SizedBox(height: AppConstants.paddingLG),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Agregar Cita'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_serviceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un servicio')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final biz = await ref.read(currentBusinessProvider.future);
      if (biz == null) throw Exception('No business');

      final services = await ref.read(businessServicesProvider.future);
      final service = services.firstWhere((s) => s['id'] == _serviceId);
      final duration = service['duration_minutes'] as int? ?? 60;
      final price = (service['price'] as num?)?.toDouble() ?? 0;

      final startsAt = DateTime(widget.date.year, widget.date.month,
          widget.date.day, widget.hour);
      final endsAt = startsAt.add(Duration(minutes: duration));

      await SupabaseClientService.client.from('appointments').insert({
        'business_id': biz['id'],
        'service_id': _serviceId,
        'service_name': service['name'],
        'staff_id': _staffId,
        'starts_at': startsAt.toIso8601String(),
        'ends_at': endsAt.toIso8601String(),
        'price': price,
        'status': 'confirmed',
      });

      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ---------------------------------------------------------------------------
// Reschedule bottom sheet
// ---------------------------------------------------------------------------

class _RescheduleSheet extends StatefulWidget {
  final Map<String, dynamic> appointment;
  final VoidCallback onSaved;

  const _RescheduleSheet({
    required this.appointment,
    required this.onSaved,
  });

  @override
  State<_RescheduleSheet> createState() => _RescheduleSheetState();
}

class _RescheduleSheetState extends State<_RescheduleSheet> {
  late DateTime _newDate;
  late TimeOfDay _newTime;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final startsAt =
        DateTime.tryParse(widget.appointment['starts_at'] as String? ?? '');
    _newDate = startsAt ?? DateTime.now();
    _newTime = startsAt != null
        ? TimeOfDay(hour: startsAt.hour, minute: startsAt.minute)
        : TimeOfDay.now();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppConstants.paddingLG,
        AppConstants.paddingLG,
        AppConstants.paddingLG,
        MediaQuery.of(context).viewInsets.bottom + AppConstants.paddingLG,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Reprogramar Cita',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              )),
          const SizedBox(height: AppConstants.paddingMD),
          ListTile(
            leading: const Icon(Icons.calendar_today_rounded),
            title: const Text('Nueva fecha'),
            trailing: Text('${_newDate.day}/${_newDate.month}/${_newDate.year}'),
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _newDate,
                firstDate: DateTime.now(),
                lastDate: DateTime(2030),
              );
              if (d != null) setState(() => _newDate = d);
            },
          ),
          ListTile(
            leading: const Icon(Icons.access_time_rounded),
            title: const Text('Nueva hora'),
            trailing: Text(_newTime.format(context)),
            onTap: () async {
              final t = await showTimePicker(
                context: context,
                initialTime: _newTime,
              );
              if (t != null) setState(() => _newTime = t);
            },
          ),
          const SizedBox(height: AppConstants.paddingLG),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Reprogramar'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final id = widget.appointment['id'] as String;
      final durationMins = widget.appointment['ends_at'] != null &&
              widget.appointment['starts_at'] != null
          ? DateTime.parse(widget.appointment['ends_at'] as String)
              .difference(
                  DateTime.parse(widget.appointment['starts_at'] as String))
              .inMinutes
          : 60;

      final newStart = DateTime(_newDate.year, _newDate.month, _newDate.day,
          _newTime.hour, _newTime.minute);
      final newEnd = newStart.add(Duration(minutes: durationMins));

      await SupabaseClientService.client
          .from('appointments')
          .update({
        'starts_at': newStart.toIso8601String(),
        'ends_at': newEnd.toIso8601String(),
      }).eq('id', id);

      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
