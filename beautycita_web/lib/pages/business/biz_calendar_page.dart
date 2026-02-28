import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:beautycita_core/supabase.dart';

import '../../config/breakpoints.dart';
import '../../providers/business_portal_provider.dart';

/// Calendar view mode.
enum CalendarView { day, week }

/// State providers for calendar UI.
final calendarViewProvider = StateProvider<CalendarView>((ref) => CalendarView.day);
final calendarDateProvider = StateProvider<DateTime>((ref) => DateTime.now());
final calendarStaffFilterProvider = StateProvider<String?>((ref) => null);
final selectedAppointmentProvider = StateProvider<Map<String, dynamic>?>((ref) => null);

/// Helper to get staff display name (supports first_name/last_name or name).
String _staffDisplayName(Map<String, dynamic> staff) {
  final first = staff['first_name'] as String? ?? '';
  final last = staff['last_name'] as String? ?? '';
  if (first.isNotEmpty) return '$first $last'.trim();
  return staff['name'] as String? ?? '';
}

/// Business calendar — multi-staff day/week views with appointment management.
class BizCalendarPage extends ConsumerWidget {
  const BizCalendarPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bizAsync = ref.watch(currentBusinessProvider);

    return bizAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (biz) {
        if (biz == null) return const Center(child: Text('Sin negocio'));
        return _CalendarContent(bizId: biz['id'] as String);
      },
    );
  }
}

class _CalendarContent extends ConsumerWidget {
  const _CalendarContent({required this.bizId});
  final String bizId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(calendarViewProvider);
    final date = ref.watch(calendarDateProvider);
    final selected = ref.watch(selectedAppointmentProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isDesktop = WebBreakpoints.isDesktop(width);
        final showDetail = selected != null && isDesktop;

        return Column(
          children: [
            _CalendarToolbar(date: date, view: view, bizId: bizId),
            if (view == CalendarView.day) ...[
              _DaySummaryCard(date: date),
              const _StaffFilterBar(),
            ],
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: view == CalendarView.day
                        ? _MultiStaffDayView(date: date, bizId: bizId)
                        : _WeekView(date: date),
                  ),
                  if (showDetail) ...[
                    VerticalDivider(width: 1, color: Theme.of(context).colorScheme.outlineVariant),
                    SizedBox(
                      width: 380,
                      child: _AppointmentDetail(appt: selected, bizId: bizId),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Toolbar ─────────────────────────────────────────────────────────────────

class _CalendarToolbar extends ConsumerWidget {
  const _CalendarToolbar({required this.date, required this.view, required this.bizId});
  final DateTime date;
  final CalendarView view;
  final String bizId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    String title;
    if (view == CalendarView.day) {
      final str = DateFormat('EEEE, d MMMM', 'es').format(date);
      title = str[0].toUpperCase() + str.substring(1);
    } else {
      final weekStart = date.subtract(Duration(days: date.weekday - 1));
      final weekEnd = weekStart.add(const Duration(days: 6));
      title = '${DateFormat('d MMM', 'es').format(weekStart)} - ${DateFormat('d MMM', 'es').format(weekEnd)}';
    }

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.outlineVariant)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              final delta = view == CalendarView.day ? const Duration(days: 1) : const Duration(days: 7);
              ref.read(calendarDateProvider.notifier).state = date.subtract(delta);
            },
            tooltip: 'Anterior',
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              final delta = view == CalendarView.day ? const Duration(days: 1) : const Duration(days: 7);
              ref.read(calendarDateProvider.notifier).state = date.add(delta);
            },
            tooltip: 'Siguiente',
          ),
          const SizedBox(width: 8),
          Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => ref.read(calendarDateProvider.notifier).state = DateTime.now(),
            child: const Text('Hoy'),
          ),
          const Spacer(),
          // Quick-add walk-in button
          ElevatedButton.icon(
            onPressed: () => _showWalkInDialog(context, ref,
                preSelectedStaffId: ref.read(calendarStaffFilterProvider)),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Walk-in'),
            style: ElevatedButton.styleFrom(visualDensity: VisualDensity.compact),
          ),
          const SizedBox(width: 12),
          SegmentedButton<CalendarView>(
            segments: const [
              ButtonSegment(value: CalendarView.day, label: Text('Dia')),
              ButtonSegment(value: CalendarView.week, label: Text('Semana')),
            ],
            selected: {view},
            onSelectionChanged: (v) => ref.read(calendarViewProvider.notifier).state = v.first,
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  void _showWalkInDialog(BuildContext context, WidgetRef ref, {String? preSelectedStaffId}) {
    showDialog(
      context: context,
      builder: (ctx) => _WalkInDialog(
        bizId: bizId,
        date: ref.read(calendarDateProvider),
        preSelectedStaffId: preSelectedStaffId,
      ),
    );
  }
}

// ── Walk-In Dialog ──────────────────────────────────────────────────────────

class _WalkInDialog extends ConsumerStatefulWidget {
  const _WalkInDialog({required this.bizId, required this.date, this.preSelectedStaffId});
  final String bizId;
  final DateTime date;
  final String? preSelectedStaffId;

  @override
  ConsumerState<_WalkInDialog> createState() => _WalkInDialogState();
}

class _WalkInDialogState extends ConsumerState<_WalkInDialog> {
  String? _selectedStaffId;
  String? _selectedServiceId;
  TimeOfDay _time = TimeOfDay.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedStaffId = widget.preSelectedStaffId;
  }

  @override
  Widget build(BuildContext context) {
    final staffAsync = ref.watch(businessStaffProvider);
    final servicesAsync = ref.watch(businessServicesProvider);

    return AlertDialog(
      title: const Text('Agregar Walk-in'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Staff picker
            staffAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text('Error cargando staff'),
              data: (staff) => DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Estilista'),
                value: _selectedStaffId,
                items: [
                  for (final s in staff)
                    DropdownMenuItem(
                      value: s['id'] as String,
                      child: Text(_staffDisplayName(s)),
                    ),
                ],
                onChanged: (v) => setState(() => _selectedStaffId = v),
              ),
            ),
            const SizedBox(height: 16),
            // Service picker
            servicesAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text('Error cargando servicios'),
              data: (services) => DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Servicio'),
                value: _selectedServiceId,
                items: [
                  for (final s in services.where((s) => s['is_active'] == true))
                    DropdownMenuItem(
                      value: s['id'] as String,
                      child: Text('${s['name']} (\$${(s['price'] as num?)?.toStringAsFixed(0) ?? '0'})'),
                    ),
                ],
                onChanged: (v) => setState(() => _selectedServiceId = v),
              ),
            ),
            const SizedBox(height: 16),
            // Time picker
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Hora'),
              trailing: TextButton(
                onPressed: () async {
                  final picked = await showTimePicker(context: context, initialTime: _time);
                  if (picked != null) setState(() => _time = picked);
                },
                child: Text('${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}'),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _selectedStaffId == null || _selectedServiceId == null || _saving
              ? null
              : _createWalkIn,
          child: _saving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Crear'),
        ),
      ],
    );
  }

  Future<void> _createWalkIn() async {
    setState(() => _saving = true);
    try {
      final servicesAsync = ref.read(businessServicesProvider);
      final services = servicesAsync.valueOrNull ?? [];
      final service = services.firstWhere(
        (s) => s['id'] == _selectedServiceId,
        orElse: () => <String, dynamic>{},
      );

      final staffAsync = ref.read(businessStaffProvider);
      final staffList = staffAsync.valueOrNull ?? [];
      final staff = staffList.firstWhere(
        (s) => s['id'] == _selectedStaffId,
        orElse: () => <String, dynamic>{},
      );

      final duration = (service['duration_minutes'] as num?)?.toInt() ?? 60;
      final startsAt = DateTime(
        widget.date.year, widget.date.month, widget.date.day,
        _time.hour, _time.minute,
      );
      final endsAt = startsAt.add(Duration(minutes: duration));

      await BCSupabase.client.from(BCTables.appointments).insert({
        'business_id': widget.bizId,
        'staff_id': _selectedStaffId,
        'service_id': _selectedServiceId,
        'service_name': service['name'] ?? 'Walk-in',
        'staff_name': _staffDisplayName(staff),
        'customer_name': 'Walk-in',
        'status': 'confirmed',
        'starts_at': startsAt.toIso8601String(),
        'ends_at': endsAt.toIso8601String(),
        'duration_minutes': duration,
        'price': (service['price'] as num?)?.toDouble() ?? 0,
        'notes': 'Walk-in',
      });

      ref.invalidate(businessAppointmentsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ── Staff filter bar ────────────────────────────────────────────────────────

class _StaffFilterBar extends ConsumerWidget {
  const _StaffFilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final staffAsync = ref.watch(businessStaffProvider);
    final selectedStaff = ref.watch(calendarStaffFilterProvider);

    return staffAsync.when(
      loading: () => const SizedBox(height: 48),
      error: (_, __) => const SizedBox(height: 48),
      data: (staff) {
        if (staff.isEmpty) return const SizedBox.shrink();
        return Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.5))),
          ),
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: const Text('Todos'),
                  selected: selectedStaff == null,
                  onSelected: (_) => ref.read(calendarStaffFilterProvider.notifier).state = null,
                ),
              ),
              for (final s in staff)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    avatar: CircleAvatar(
                      radius: 12,
                      backgroundColor: colors.primary.withValues(alpha: 0.12),
                      child: Text(
                        _staffDisplayName(s).isNotEmpty ? _staffDisplayName(s)[0].toUpperCase() : '?',
                        style: TextStyle(fontSize: 10, color: colors.primary, fontWeight: FontWeight.bold),
                      ),
                    ),
                    label: Text(_staffDisplayName(s)),
                    selected: selectedStaff == s['id'],
                    onSelected: (_) => ref.read(calendarStaffFilterProvider.notifier).state = s['id'] as String?,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ── Day Summary Card ────────────────────────────────────────────────────────

class _DaySummaryCard extends ConsumerWidget {
  const _DaySummaryCard({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dateStr = date.toIso8601String().split('T')[0];
    final range = (start: '${dateStr}T00:00:00', end: '${dateStr}T23:59:59');
    final apptsAsync = ref.watch(businessAppointmentsProvider(range));

    return apptsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (appts) {
        final activeAppts = appts.where((a) {
          final status = a['status'] as String? ?? '';
          return status != 'cancelled_customer' && status != 'cancelled_business';
        }).toList();
        final totalAppts = activeAppts.length;
        final pending = activeAppts.where((a) => a['status'] == 'pending').length;
        final revenue = activeAppts.fold<double>(0, (sum, a) => sum + ((a['price'] as num?)?.toDouble() ?? 0));

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: colors.primaryContainer.withValues(alpha: 0.15),
            border: Border(bottom: BorderSide(color: colors.outlineVariant)),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_today, size: 16, color: colors.primary),
              const SizedBox(width: 8),
              Text('$totalAppts citas', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
              if (pending > 0) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9800).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('$pending pendientes', style: const TextStyle(fontSize: 11, color: Color(0xFFFF9800), fontWeight: FontWeight.w600)),
                ),
              ],
              const Spacer(),
              Icon(Icons.payments_outlined, size: 16, color: colors.onSurface.withValues(alpha: 0.5)),
              const SizedBox(width: 4),
              Text('\$${revenue.toStringAsFixed(0)}', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600, color: colors.primary)),
              Text(' estimado', style: theme.textTheme.labelSmall?.copyWith(color: colors.onSurface.withValues(alpha: 0.5))),
            ],
          ),
        );
      },
    );
  }
}

// ── Multi-Staff Day View ────────────────────────────────────────────────────

class _MultiStaffDayView extends ConsumerWidget {
  const _MultiStaffDayView({required this.date, required this.bizId});
  final DateTime date;
  final String bizId;

  static const int _startHour = 7;
  static const int _endHour = 21;
  static const double _hourHeight = 64;
  static const double _timeGutterWidth = 56;
  static const double _minStaffColumnWidth = 180;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dateStr = date.toIso8601String().split('T')[0];
    final range = (start: '${dateStr}T00:00:00', end: '${dateStr}T23:59:59');
    final apptsAsync = ref.watch(businessAppointmentsProvider(range));
    final blocksAsync = ref.watch(businessScheduleBlocksProvider(range));
    final staffAsync = ref.watch(businessStaffProvider);
    final staffFilter = ref.watch(calendarStaffFilterProvider);

    return staffAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Error al cargar staff')),
      data: (allStaff) {
        final staff = staffFilter != null
            ? allStaff.where((s) => s['id'] == staffFilter).toList()
            : allStaff.where((s) => s['is_active'] == true).toList();

        if (staff.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.people_outlined, size: 48, color: colors.onSurface.withValues(alpha: 0.3)),
                const SizedBox(height: 12),
                Text('Sin staff activo', style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurface.withValues(alpha: 0.5))),
              ],
            ),
          );
        }

        return apptsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(child: Text('Error al cargar citas')),
          data: (appts) {
            // Group appointments by staff_id
            final byStaff = <String, List<Map<String, dynamic>>>{};
            for (final s in staff) {
              byStaff[s['id'] as String] = [];
            }
            for (final a in appts) {
              final sid = a['staff_id'] as String?;
              if (sid != null && byStaff.containsKey(sid)) {
                byStaff[sid]!.add(a);
              }
            }

            // Group schedule blocks by staff_id
            final blocks = blocksAsync.valueOrNull ?? [];
            final blocksByStaff = <String, List<Map<String, dynamic>>>{};
            for (final s in staff) {
              blocksByStaff[s['id'] as String] = [];
            }
            for (final b in blocks) {
              final sid = b['staff_id'] as String?;
              if (sid != null && blocksByStaff.containsKey(sid)) {
                blocksByStaff[sid]!.add(b);
              }
            }

            final totalHeight = (_endHour - _startHour) * _hourHeight;

            return Column(
              children: [
                // Staff header row (frozen)
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: colors.outlineVariant)),
                    color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
                  ),
                  child: Row(
                    children: [
                      SizedBox(width: _timeGutterWidth),
                      Expanded(
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            for (final s in staff)
                              SizedBox(
                                width: staff.length == 1
                                    ? null
                                    : _minStaffColumnWidth.clamp(0, double.infinity),
                                child: staff.length == 1
                                    ? _StaffColumnHeader(staff: s)
                                    : _StaffColumnHeader(staff: s),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Scrollable time grid with staff columns
                Expanded(
                  child: SingleChildScrollView(
                    child: SizedBox(
                      height: totalHeight,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Time gutter
                          SizedBox(
                            width: _timeGutterWidth,
                            height: totalHeight,
                            child: Stack(
                              children: [
                                for (var h = _startHour; h <= _endHour; h++)
                                  Positioned(
                                    top: (h - _startHour) * _hourHeight - 8,
                                    left: 0,
                                    right: 8,
                                    child: Text(
                                      '${h.toString().padLeft(2, '0')}:00',
                                      textAlign: TextAlign.right,
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: colors.onSurface.withValues(alpha: 0.4),
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          // Staff columns
                          Expanded(
                            child: Stack(
                              children: [
                                // Hour grid lines
                                for (var h = _startHour; h <= _endHour; h++)
                                  Positioned(
                                    top: (h - _startHour) * _hourHeight,
                                    left: 0,
                                    right: 0,
                                    child: Divider(height: 1, color: colors.outlineVariant.withValues(alpha: 0.3)),
                                  ),
                                // Half-hour grid lines (lighter)
                                for (var h = _startHour; h < _endHour; h++)
                                  Positioned(
                                    top: (h - _startHour) * _hourHeight + _hourHeight / 2,
                                    left: 0,
                                    right: 0,
                                    child: Divider(height: 1, color: colors.outlineVariant.withValues(alpha: 0.15)),
                                  ),
                                // Staff columns with appointments
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    for (var i = 0; i < staff.length; i++) ...[
                                      Expanded(
                                        child: SizedBox(
                                          height: totalHeight,
                                          child: Stack(
                                            children: [
                                              // Column divider
                                              if (i > 0)
                                                Positioned(
                                                  top: 0,
                                                  bottom: 0,
                                                  left: 0,
                                                  child: VerticalDivider(width: 1, color: colors.outlineVariant.withValues(alpha: 0.3)),
                                                ),
                                              // Schedule blocks (time-off, breaks)
                                              for (final block in blocksByStaff[staff[i]['id'] as String] ?? [])
                                                _positionedScheduleBlock(context, block),
                                              // Appointment blocks
                                              for (final appt in byStaff[staff[i]['id'] as String] ?? [])
                                                _positionedBlock(context, ref, appt),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                // Current time indicator
                                if (_isToday(date)) _currentTimeIndicator(context),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  Widget _currentTimeIndicator(BuildContext context) {
    final now = DateTime.now();
    final minutes = (now.hour - _startHour) * 60 + now.minute;
    if (minutes < 0 || minutes > (_endHour - _startHour) * 60) return const SizedBox.shrink();
    final top = minutes * _hourHeight / 60;

    return Positioned(
      top: top,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Container(
          height: 2,
          color: const Color(0xFFE53935),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Transform.translate(
              offset: const Offset(-4, 0),
              child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFE53935), shape: BoxShape.circle)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _positionedBlock(BuildContext context, WidgetRef ref, Map<String, dynamic> appt) {
    final startsAt = DateTime.tryParse(appt['starts_at'] as String? ?? '');
    if (startsAt == null) return const SizedBox.shrink();

    final duration = (appt['duration_minutes'] as num?)?.toInt() ?? 60;
    final startMinutes = (startsAt.hour - _startHour) * 60 + startsAt.minute;
    if (startMinutes < 0) return const SizedBox.shrink();

    final top = startMinutes * _hourHeight / 60;
    final height = (duration * _hourHeight / 60).clamp(24.0, double.infinity);

    final status = appt['status'] as String? ?? '';
    final color = _statusColor(status);
    final service = appt['service_name'] as String? ?? 'Cita';
    final customer = appt['customer_name'] as String? ?? '';
    final timeStr = DateFormat('HH:mm').format(startsAt);

    return Positioned(
      top: top,
      left: 4,
      right: 4,
      height: height,
      child: GestureDetector(
        onTap: () => ref.read(selectedAppointmentProvider.notifier).state = appt,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            margin: const EdgeInsets.only(bottom: 1),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border(left: BorderSide(color: color, width: 3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$timeStr $service',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (height > 30 && customer.isNotEmpty)
                  Text(
                    customer,
                    style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.7)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _positionedScheduleBlock(BuildContext context, Map<String, dynamic> block) {
    final startsAt = DateTime.tryParse(block['starts_at'] as String? ?? '');
    final endsAt = DateTime.tryParse(block['ends_at'] as String? ?? '');
    if (startsAt == null || endsAt == null) return const SizedBox.shrink();

    final startMinutes = (startsAt.hour - _startHour) * 60 + startsAt.minute;
    final endMinutes = (endsAt.hour - _startHour) * 60 + endsAt.minute;
    if (startMinutes < 0 && endMinutes < 0) return const SizedBox.shrink();

    final top = (startMinutes.clamp(0, (_endHour - _startHour) * 60)) * _hourHeight / 60;
    final bottom = (endMinutes.clamp(0, (_endHour - _startHour) * 60)) * _hourHeight / 60;
    final height = (bottom - top).clamp(8.0, double.infinity);

    final reason = block['reason'] as String? ?? '';
    final reasonLabel = switch (reason) {
      'lunch' => 'Descanso',
      'day_off' => 'Dia libre',
      'vacation' => 'Vacaciones',
      _ => reason.isNotEmpty ? reason : 'Bloqueado',
    };

    final colors = Theme.of(context).colorScheme;

    return Positioned(
      top: top,
      left: 2,
      right: 2,
      height: height,
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            color: colors.onSurface.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: colors.onSurface.withValues(alpha: 0.08)),
          ),
          alignment: Alignment.center,
          child: height > 20
              ? Text(
                  reasonLabel,
                  style: TextStyle(
                    fontSize: 10,
                    color: colors.onSurface.withValues(alpha: 0.35),
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              : null,
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    return switch (status) {
      'confirmed' => const Color(0xFF4CAF50),
      'pending' => const Color(0xFFFF9800),
      'completed' => const Color(0xFF2196F3),
      'cancelled_customer' || 'cancelled_business' => const Color(0xFFE53935),
      'no_show' => const Color(0xFF795548),
      _ => const Color(0xFF9E9E9E),
    };
  }
}

class _StaffColumnHeader extends StatelessWidget {
  const _StaffColumnHeader({required this.staff});
  final Map<String, dynamic> staff;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final name = _staffDisplayName(staff);
    final avatar = staff['avatar_url'] as String?;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: colors.primary.withValues(alpha: 0.12),
            backgroundImage: avatar != null ? NetworkImage(avatar) : null,
            child: avatar == null
                ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: TextStyle(fontSize: 11, color: colors.primary, fontWeight: FontWeight.bold))
                : null,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              name,
              style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Week View ───────────────────────────────────────────────────────────────

class _WeekView extends ConsumerWidget {
  const _WeekView({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final weekStart = date.subtract(Duration(days: date.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6, hours: 23, minutes: 59));
    final range = (start: weekStart.toIso8601String(), end: weekEnd.toIso8601String());
    final apptsAsync = ref.watch(businessAppointmentsProvider(range));
    final staffFilter = ref.watch(calendarStaffFilterProvider);
    final dayNames = ['Lun', 'Mar', 'Mie', 'Jue', 'Vie', 'Sab', 'Dom'];

    return apptsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Error')),
      data: (appts) {
        var filtered = appts;
        if (staffFilter != null) {
          filtered = appts.where((a) => a['staff_id'] == staffFilter).toList();
        }

        final byDay = <int, List<Map<String, dynamic>>>{};
        for (final a in filtered) {
          final dt = DateTime.tryParse(a['starts_at'] as String? ?? '');
          if (dt == null) continue;
          final dow = dt.weekday;
          byDay.putIfAbsent(dow, () => []).add(a);
        }

        return Column(
          children: [
            Container(
              height: 40,
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.outlineVariant))),
              child: Row(
                children: [
                  for (var i = 0; i < 7; i++)
                    Expanded(
                      child: Center(
                        child: Text(
                          '${dayNames[i]} ${weekStart.add(Duration(days: i)).day}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: _isToday(weekStart.add(Duration(days: i))) ? colors.primary : colors.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < 7; i++)
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: i < 6 ? Border(right: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.3))) : null,
                          color: _isToday(weekStart.add(Duration(days: i))) ? colors.primary.withValues(alpha: 0.04) : null,
                        ),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(4),
                          child: Column(
                            children: [
                              for (final a in (byDay[i + 1] ?? []))
                                _WeekApptChip(appt: a, ref: ref),
                              if ((byDay[i + 1] ?? []).isEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 40),
                                  child: Icon(Icons.remove, size: 16, color: colors.onSurface.withValues(alpha: 0.15)),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }
}

class _WeekApptChip extends StatelessWidget {
  const _WeekApptChip({required this.appt, required this.ref});
  final Map<String, dynamic> appt;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final status = appt['status'] as String? ?? '';
    final startsAt = DateTime.tryParse(appt['starts_at'] as String? ?? '');
    final timeStr = startsAt != null ? DateFormat('HH:mm').format(startsAt) : '';
    final service = appt['service_name'] as String? ?? '';
    final staffName = appt['staff_name'] as String? ?? '';

    final color = switch (status) {
      'confirmed' => const Color(0xFF4CAF50),
      'pending' => const Color(0xFFFF9800),
      'completed' => const Color(0xFF2196F3),
      'cancelled_customer' || 'cancelled_business' => const Color(0xFFE53935),
      'no_show' => const Color(0xFF795548),
      _ => const Color(0xFF9E9E9E),
    };

    return GestureDetector(
      onTap: () => ref.read(selectedAppointmentProvider.notifier).state = appt,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(4),
            border: Border(left: BorderSide(color: color, width: 2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(timeStr, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color, fontFamily: 'monospace')),
              Text(service, style: const TextStyle(fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
              if (staffName.isNotEmpty)
                Row(
                  children: [
                    Icon(Icons.person, size: 10, color: color.withValues(alpha: 0.5)),
                    const SizedBox(width: 2),
                    Flexible(
                      child: Text(staffName, style: TextStyle(fontSize: 9, color: color.withValues(alpha: 0.6)), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Appointment Detail Panel ────────────────────────────────────────────────

class _AppointmentDetail extends ConsumerStatefulWidget {
  const _AppointmentDetail({required this.appt, required this.bizId});
  final Map<String, dynamic> appt;
  final String bizId;

  @override
  ConsumerState<_AppointmentDetail> createState() => _AppointmentDetailState();
}

class _AppointmentDetailState extends ConsumerState<_AppointmentDetail> {
  bool _updating = false;
  late TextEditingController _notesCtrl;
  bool _notesChanged = false;
  bool _savingNotes = false;

  @override
  void initState() {
    super.initState();
    _notesCtrl = TextEditingController(text: widget.appt['notes'] as String? ?? '');
    _notesCtrl.addListener(() => _notesChanged = true);
  }

  @override
  void didUpdateWidget(covariant _AppointmentDetail old) {
    super.didUpdateWidget(old);
    if (old.appt['id'] != widget.appt['id']) {
      _notesCtrl.text = widget.appt['notes'] as String? ?? '';
      _notesChanged = false;
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveNotes() async {
    final id = widget.appt['id'] as String?;
    if (id == null) return;
    setState(() => _savingNotes = true);
    try {
      await BCSupabase.client
          .from(BCTables.appointments)
          .update({'notes': _notesCtrl.text.trim()})
          .eq('id', id);
      ref.invalidate(businessAppointmentsProvider);
      _notesChanged = false;
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Notas guardadas')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _savingNotes = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final appt = widget.appt;

    final status = appt['status'] as String? ?? '';
    final service = appt['service_name'] as String? ?? 'Servicio';
    final customer = appt['customer_name'] as String? ?? 'Cliente';
    final staff = appt['staff_name'] as String? ?? '';
    final price = (appt['price'] as num?)?.toDouble() ?? 0;
    final startsAt = DateTime.tryParse(appt['starts_at'] as String? ?? '');
    final duration = (appt['duration_minutes'] as num?)?.toInt() ?? 0;

    final statusLabel = switch (status) {
      'pending' => 'Pendiente',
      'confirmed' => 'Confirmada',
      'completed' => 'Completada',
      'cancelled_customer' => 'Cancelada (cliente)',
      'cancelled_business' => 'Cancelada (negocio)',
      'no_show' => 'No se presento',
      _ => status,
    };

    final statusColor = _statusColor(status);

    return Container(
      color: colors.surface,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.outlineVariant))),
            child: Row(
              children: [
                Expanded(child: Text('Detalle', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600))),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => ref.read(selectedAppointmentProvider.notifier).state = null,
                  tooltip: 'Cerrar',
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(service, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(statusLabel, style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 16),

                  _DetailRow(icon: Icons.person_outline, label: 'Cliente', value: customer),
                  if (staff.isNotEmpty) _DetailRow(icon: Icons.badge_outlined, label: 'Estilista', value: staff),
                  if (startsAt != null) _DetailRow(icon: Icons.access_time, label: 'Hora', value: DateFormat('HH:mm').format(startsAt)),
                  if (startsAt != null) _DetailRow(icon: Icons.calendar_today, label: 'Fecha', value: DateFormat('d MMM yyyy', 'es').format(startsAt)),
                  if (duration > 0) _DetailRow(icon: Icons.timer_outlined, label: 'Duracion', value: '$duration min'),
                  _DetailRow(icon: Icons.payments_outlined, label: 'Precio', value: '\$${price.toStringAsFixed(0)}'),
                  // Editable notes
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text('Notas', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
                      const Spacer(),
                      if (_notesChanged)
                        TextButton.icon(
                          onPressed: _savingNotes ? null : _saveNotes,
                          icon: _savingNotes
                              ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.save_outlined, size: 14),
                          label: const Text('Guardar'),
                          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _notesCtrl,
                    maxLines: 3,
                    style: theme.textTheme.bodySmall,
                    decoration: InputDecoration(
                      hintText: 'Agregar notas...',
                      hintStyle: theme.textTheme.bodySmall?.copyWith(color: colors.onSurface.withValues(alpha: 0.3)),
                      filled: true,
                      fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.3),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.all(10),
                    ),
                  ),

                  const SizedBox(height: 24),

                  if (_updating)
                    const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  else ...[
                    // Confirm
                    if (status == 'pending')
                      _ActionButton(
                        label: 'Confirmar',
                        icon: Icons.check,
                        color: const Color(0xFF4CAF50),
                        onPressed: () => _updateStatus('confirmed'),
                      ),
                    // Complete
                    if (status == 'confirmed')
                      _ActionButton(
                        label: 'Completar',
                        icon: Icons.done_all,
                        color: const Color(0xFF2196F3),
                        onPressed: () => _updateStatus('completed'),
                      ),
                    // No-show (with deposit context)
                    if (status == 'confirmed')
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _ActionButton(
                          label: 'No se presento',
                          icon: Icons.person_off_outlined,
                          color: const Color(0xFF795548),
                          onPressed: () => _confirmNoShow(context, price),
                          outlined: true,
                        ),
                      ),
                    // Cancel
                    if (status == 'pending' || status == 'confirmed')
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _ActionButton(
                          label: 'Cancelar',
                          icon: Icons.cancel_outlined,
                          color: colors.error,
                          onPressed: () => _confirmCancel(context),
                          outlined: true,
                        ),
                      ),
                    // Reschedule
                    if (status == 'pending' || status == 'confirmed')
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _ActionButton(
                          label: 'Reagendar',
                          icon: Icons.schedule,
                          color: colors.primary,
                          onPressed: () => _showReschedule(context),
                          outlined: true,
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateStatus(String newStatus) async {
    final id = widget.appt['id'] as String?;
    if (id == null) return;

    setState(() => _updating = true);
    try {
      await BCSupabase.client
          .from(BCTables.appointments)
          .update({'status': newStatus})
          .eq('id', id);
      ref.invalidate(businessAppointmentsProvider);
      ref.invalidate(businessStatsProvider);
      if (mounted) ref.read(selectedAppointmentProvider.notifier).state = null;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  void _confirmCancel(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar cita'),
        content: const Text('Esta seguro que desea cancelar esta cita?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('No')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () {
              Navigator.of(ctx).pop();
              _updateStatus('cancelled_business');
            },
            child: const Text('Si, cancelar'),
          ),
        ],
      ),
    );
  }

  void _confirmNoShow(BuildContext context, double price) {
    // Check if there's a deposit on this appointment
    final depositAmount = (widget.appt['deposit_amount'] as num?)?.toDouble() ?? 0;
    final hasDeposit = depositAmount > 0;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Marcar como no-show'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('El cliente no se presento a su cita.'),
            if (hasDeposit) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9800).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFF9800).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 18, color: Color(0xFFFF9800)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'El deposito de \$${depositAmount.toStringAsFixed(0)} sera retenido.',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF795548)),
            onPressed: () {
              Navigator.of(ctx).pop();
              _updateStatus('no_show');
            },
            child: const Text('Confirmar no-show'),
          ),
        ],
      ),
    );
  }

  void _showReschedule(BuildContext context) {
    final startsAt = DateTime.tryParse(widget.appt['starts_at'] as String? ?? '') ?? DateTime.now();
    showDialog(
      context: context,
      builder: (ctx) => _RescheduleDialog(
        appointmentId: widget.appt['id'] as String,
        initialDate: startsAt,
        duration: (widget.appt['duration_minutes'] as num?)?.toInt() ?? 60,
        onSaved: () {
          ref.invalidate(businessAppointmentsProvider);
          ref.read(selectedAppointmentProvider.notifier).state = null;
        },
      ),
    );
  }

  Color _statusColor(String status) {
    return switch (status) {
      'confirmed' => const Color(0xFF4CAF50),
      'pending' => const Color(0xFFFF9800),
      'completed' => const Color(0xFF2196F3),
      'cancelled_customer' || 'cancelled_business' => const Color(0xFFE53935),
      'no_show' => const Color(0xFF795548),
      _ => const Color(0xFF9E9E9E),
    };
  }
}

// ── Reschedule Dialog ───────────────────────────────────────────────────────

class _RescheduleDialog extends StatefulWidget {
  const _RescheduleDialog({
    required this.appointmentId,
    required this.initialDate,
    required this.duration,
    required this.onSaved,
  });
  final String appointmentId;
  final DateTime initialDate;
  final int duration;
  final VoidCallback onSaved;

  @override
  State<_RescheduleDialog> createState() => _RescheduleDialogState();
}

class _RescheduleDialogState extends State<_RescheduleDialog> {
  late DateTime _date;
  late TimeOfDay _time;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate;
    _time = TimeOfDay(hour: widget.initialDate.hour, minute: widget.initialDate.minute);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reagendar cita'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Fecha'),
            trailing: TextButton(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _date = picked);
              },
              child: Text(DateFormat('d MMM yyyy', 'es').format(_date)),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Hora'),
            trailing: TextButton(
              onPressed: () async {
                final picked = await showTimePicker(context: context, initialTime: _time);
                if (picked != null) setState(() => _time = picked);
              },
              child: Text('${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}'),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Guardar'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final newStart = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
      final newEnd = newStart.add(Duration(minutes: widget.duration));

      await BCSupabase.client.from(BCTables.appointments).update({
        'starts_at': newStart.toIso8601String(),
        'ends_at': newEnd.toIso8601String(),
      }).eq('id', widget.appointmentId);

      widget.onSaved();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ── Shared Widgets ──────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
    this.outlined = false,
  });
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    if (outlined) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 18, color: color),
          label: Text(label, style: TextStyle(color: color)),
          style: OutlinedButton.styleFrom(side: BorderSide(color: color.withValues(alpha: 0.3))),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colors.onSurface.withValues(alpha: 0.5)),
          const SizedBox(width: 10),
          SizedBox(
            width: 80,
            child: Text(label, style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurface.withValues(alpha: 0.5))),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
