import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:beautycita_core/supabase.dart';

import '../../config/breakpoints.dart';
import '../../providers/business_portal_provider.dart';
import '../../providers/demo_providers.dart';

/// State providers for calendar UI.
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

/// Business calendar — horizontal Gantt-style day view with compact week strip.
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
    final date = ref.watch(calendarDateProvider);
    final selected = ref.watch(selectedAppointmentProvider);

    // Rolling 7-day window: yesterday + today (pos 1) + next 5 days
    final weekStart = date.subtract(const Duration(days: 1));
    final weekEnd = DateTime(weekStart.year, weekStart.month, weekStart.day + 6, 23, 59, 59);
    final weekRange = (start: weekStart.toIso8601String(), end: weekEnd.toIso8601String());
    final weekApptsAsync = ref.watch(businessAppointmentsProvider(weekRange));

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isDesktop = WebBreakpoints.isDesktop(width);
        final showDetail = selected != null && isDesktop;

        return Column(
          children: [
            _CalendarToolbar(date: date, bizId: bizId),
            _DaySummaryCard(date: date),
            const _StaffFilterBar(),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: _HorizontalDayView(date: date, bizId: bizId),
                        ),
                        _CompactWeekStrip(
                          weekStart: weekStart,
                          selectedDate: date,
                          weekApptsAsync: weekApptsAsync,
                          onDayTap: (d) => ref.read(calendarDateProvider.notifier).state = d,
                        ),
                      ],
                    ),
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
  const _CalendarToolbar({required this.date, required this.bizId});
  final DateTime date;
  final String bizId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDemo = ref.watch(isDemoProvider);

    final str = DateFormat('EEEE, d MMMM', 'es').format(date);
    final title = str[0].toUpperCase() + str.substring(1);

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
              ref.read(calendarDateProvider.notifier).state = date.subtract(const Duration(days: 1));
            },
            tooltip: 'Anterior',
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              ref.read(calendarDateProvider.notifier).state = date.add(const Duration(days: 1));
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
          // Quick-add walk-in button — hidden in demo
          if (!isDemo)
            ElevatedButton.icon(
              onPressed: () => _showWalkInDialog(context, ref),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Walk-in'),
              style: ElevatedButton.styleFrom(visualDensity: VisualDensity.compact),
            ),
        ],
      ),
    );
  }

  void _showWalkInDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => _WalkInDialog(
        bizId: bizId,
        date: ref.read(calendarDateProvider),
        preSelectedStaffId: ref.read(calendarStaffFilterProvider),
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
              for (var i = 0; i < staff.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    avatar: CircleAvatar(
                      radius: 12,
                      backgroundColor: _staffColor(i).withValues(alpha: 0.15),
                      child: Text(
                        _staffDisplayName(staff[i]).isNotEmpty ? _staffDisplayName(staff[i])[0].toUpperCase() : '?',
                        style: TextStyle(fontSize: 10, color: _staffColor(i), fontWeight: FontWeight.bold),
                      ),
                    ),
                    label: Text(_staffDisplayName(staff[i])),
                    selected: selectedStaff == staff[i]['id'],
                    onSelected: (_) => ref.read(calendarStaffFilterProvider.notifier).state = staff[i]['id'] as String?,
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

// ── Staff colors ────────────────────────────────────────────────────────────

const _kStaffColors = [
  Color(0xFFE53935), // Vivid red
  Color(0xFF1E88E5), // Bold blue
  Color(0xFF43A047), // Forest green
  Color(0xFFFF8F00), // Rich amber
  Color(0xFF8E24AA), // Deep purple
  Color(0xFF00ACC1), // Teal cyan
  Color(0xFFD81B60), // Hot pink
  Color(0xFF5D4037), // Espresso brown
];

Color _staffColor(int index) => _kStaffColors[index % _kStaffColors.length];

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

// ── Horizontal Gantt Day View ───────────────────────────────────────────────

class _HorizontalDayView extends ConsumerStatefulWidget {
  const _HorizontalDayView({required this.date, required this.bizId});
  final DateTime date;
  final String bizId;

  @override
  ConsumerState<_HorizontalDayView> createState() => _HorizontalDayViewState();
}

class _HorizontalDayViewState extends ConsumerState<_HorizontalDayView> {
  static const _startHour = 7;
  static const _endHour = 21;
  static const _hourWidth = 120.0;
  static const _laneHeight = 70.0;
  static const _labelRowHeight = 28.0;
  static const _staffColumnWidth = 80.0;
  static const _totalWidth = (_endHour - _startHour) * _hourWidth;

  late ScrollController _scrollController;

  // ── Drag state ──
  Map<String, dynamic>? _dragAppt;
  Offset? _dragPos; // position relative to timeline area
  String? _dragTargetStaffId;
  DateTime? _dragTargetTime;
  bool _dragValid = false;
  bool _isDragging = false;
  final GlobalKey _timelineKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToNow());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_HorizontalDayView old) {
    super.didUpdateWidget(old);
    if (old.date != widget.date) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToNow());
    }
  }

  void _scrollToNow() {
    final now = DateTime.now();
    final isToday = now.year == widget.date.year &&
        now.month == widget.date.month &&
        now.day == widget.date.day;

    double targetOffset;
    if (isToday && now.hour >= _startHour && now.hour < _endHour) {
      final minutesSinceStart = (now.hour - _startHour) * 60 + now.minute;
      targetOffset = (minutesSinceStart / 60.0) * _hourWidth - 60;
    } else {
      // Scroll to 9 AM by default
      targetOffset = (9 - _startHour) * _hourWidth.toDouble();
    }

    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      _scrollController.jumpTo(targetOffset.clamp(0, maxScroll));
    }
  }

  /// Convert X offset within timeline to DateTime, snapped to 5-min grid.
  DateTime _xToTime(double x) {
    final minutesSinceStart = (x / _hourWidth) * 60;
    final snapped = (minutesSinceStart / 5).round() * 5;
    final hour = (_startHour + snapped ~/ 60).clamp(_startHour, _endHour - 1);
    final minute = (snapped % 60).clamp(0, 55);
    return DateTime(widget.date.year, widget.date.month, widget.date.day, hour, minute);
  }

  /// Convert Y offset within timeline to lane index (accounting for label row).
  int _yToLaneIndex(double y, int laneCount) {
    final adjusted = y - _labelRowHeight;
    if (adjusted < 0) return 0;
    return (adjusted / _laneHeight).floor().clamp(0, laneCount - 1);
  }

  /// Check if staff can perform this service.
  bool _canStaffDoService(String staffId, String? serviceId, Map<String, Set<String>> staffServices) {
    if (serviceId == null) return true; // walk-in with no service
    if (staffServices.isEmpty) return true; // no data loaded yet, allow
    final services = staffServices[staffId];
    if (services == null) return false;
    return services.contains(serviceId);
  }

  /// Check for time overlap with existing appointments.
  bool _hasCollision(String staffId, DateTime newStart, DateTime newEnd, String excludeId, List<Map<String, dynamic>> appts) {
    for (final a in appts) {
      if (a['id'] == excludeId) continue;
      if (a['staff_id'] != staffId) continue;
      final aStart = DateTime.tryParse(a['starts_at'] as String? ?? '')?.toLocal();
      final aEnd = DateTime.tryParse(a['ends_at'] as String? ?? '')?.toLocal();
      if (aStart == null || aEnd == null) continue;
      if (newStart.isBefore(aEnd) && newEnd.isAfter(aStart)) return true;
    }
    return false;
  }

  /// Execute the reschedule after a valid drop.
  Future<void> _executeReschedule(Map<String, dynamic> appt, DateTime newStart, String newStaffId, List<Map<String, dynamic>> allStaff) async {
    final id = appt['id'] as String?;
    if (id == null) return;

    final duration = (appt['duration_minutes'] as num?)?.toInt() ?? 60;
    final newEnd = newStart.add(Duration(minutes: duration));

    final updateData = <String, dynamic>{
      'starts_at': newStart.toIso8601String(),
      'ends_at': newEnd.toIso8601String(),
    };

    // If staff changed, update staff fields
    final oldStaffId = appt['staff_id'] as String?;
    if (newStaffId != oldStaffId) {
      updateData['staff_id'] = newStaffId;
      final staffMember = allStaff.firstWhere(
        (s) => s['id'] == newStaffId,
        orElse: () => <String, dynamic>{},
      );
      updateData['staff_name'] = _staffDisplayName(staffMember);
    }

    try {
      await BCSupabase.client
          .from(BCTables.appointments)
          .update(updateData)
          .eq('id', id);

      ref.invalidate(businessAppointmentsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cita reagendada'), duration: Duration(seconds: 2)),
        );
      }

      // Fire-and-forget: send reschedule notification
      _sendRescheduleNotification(id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al reagendar: $e')));
      }
    }
  }

  Future<void> _sendRescheduleNotification(String appointmentId) async {
    try {
      await BCSupabase.client.functions.invoke(
        'reschedule-notification',
        body: {'appointment_id': appointmentId},
      );
    } catch (e) {
      debugPrint('[Reschedule] Notification error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dateStr = widget.date.toIso8601String().split('T')[0];
    final range = (start: '${dateStr}T00:00:00', end: '${dateStr}T23:59:59');
    final apptsAsync = ref.watch(businessAppointmentsProvider(range));
    final blocksAsync = ref.watch(businessScheduleBlocksProvider(range));
    final staffAsync = ref.watch(businessStaffProvider);
    final staffFilter = ref.watch(calendarStaffFilterProvider);
    final staffServicesAsync = ref.watch(allStaffServicesProvider);

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

        final isDemo = ref.watch(isDemoProvider);
        final staffServices = staffServicesAsync.valueOrNull ?? <String, Set<String>>{};

        return apptsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(child: Text('Error al cargar citas')),
          data: (appts) {
            final blocks = blocksAsync.valueOrNull ?? [];

            // Build lane data
            final lanes = <_LaneData>[];
            for (var i = 0; i < staff.length; i++) {
              final sid = staff[i]['id'] as String;
              final globalIndex = allStaff.indexWhere((s) => s['id'] == sid);
              lanes.add(_LaneData(
                id: sid,
                name: _staffDisplayName(staff[i]),
                colorIndex: globalIndex >= 0 ? globalIndex : i,
                appts: appts.where((a) => a['staff_id'] == sid).toList(),
                blocks: blocks.where((b) => b['staff_id'] == sid).toList(),
              ));
            }

            // Now-line
            final now = DateTime.now();
            final isToday = now.year == widget.date.year &&
                now.month == widget.date.month &&
                now.day == widget.date.day;
            double? nowLineX;
            if (isToday && now.hour >= _startHour && now.hour < _endHour) {
              final minutesSinceStart = (now.hour - _startHour) * 60 + now.minute;
              nowLineX = (minutesSinceStart / 60.0) * _hourWidth;
            }

            return SingleChildScrollView(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fixed staff name column
                  SizedBox(
                    width: _staffColumnWidth,
                    child: Column(
                      children: [
                        SizedBox(height: _labelRowHeight),
                        for (var li = 0; li < lanes.length; li++)
                          Container(
                            height: _laneHeight,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 8),
                            decoration: _isDragging && _dragTargetStaffId == lanes[li].id
                                ? BoxDecoration(
                                    color: (_dragValid ? const Color(0xFF4CAF50) : const Color(0xFFE53935))
                                        .withValues(alpha: 0.08),
                                  )
                                : null,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: _staffColor(lanes[li].colorIndex).withValues(alpha: 0.15),
                                  child: Text(
                                    lanes[li].name.isNotEmpty ? lanes[li].name[0].toUpperCase() : '?',
                                    style: TextStyle(fontSize: 10, color: _staffColor(lanes[li].colorIndex), fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  lanes[li].name.split(' ').first,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _staffColor(lanes[li].colorIndex),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Scrollable horizontal timeline
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      scrollDirection: Axis.horizontal,
                      physics: _isDragging ? const NeverScrollableScrollPhysics() : null,
                      child: SizedBox(
                        key: _timelineKey,
                        width: _totalWidth,
                        child: Stack(
                          children: [
                            Column(
                              children: [
                                // Hour labels row
                                SizedBox(
                                  height: _labelRowHeight,
                                  child: Row(
                                    children: List.generate(
                                      _endHour - _startHour,
                                      (i) {
                                        final hour = _startHour + i;
                                        return SizedBox(
                                          width: _hourWidth,
                                          child: Align(
                                            alignment: Alignment.bottomLeft,
                                            child: Padding(
                                              padding: const EdgeInsets.only(left: 2, bottom: 4),
                                              child: Text(
                                                '${hour > 12 ? hour - 12 : hour}${hour >= 12 ? 'PM' : 'AM'}',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w500,
                                                  color: colors.onSurface.withValues(alpha: 0.4),
                                                  fontFamily: 'monospace',
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                // Staff lanes
                                for (final lane in lanes)
                                  _StaffLane(
                                    lane: lane,
                                    laneHeight: _laneHeight,
                                    hourWidth: _hourWidth,
                                    startHour: _startHour,
                                    endHour: _endHour,
                                    totalWidth: _totalWidth,
                                    nowLineX: nowLineX,
                                    onTapAppt: (appt) => ref.read(selectedAppointmentProvider.notifier).state = appt,
                                    isDragSource: _isDragging && _dragAppt?['staff_id'] == lane.id,
                                    dragApptId: _dragAppt?['id'] as String?,
                                    enableDrag: !isDemo,
                                    onDragStart: (appt, globalPos) {
                                      final renderBox = _timelineKey.currentContext?.findRenderObject() as RenderBox?;
                                      if (renderBox == null) return;
                                      final localPos = renderBox.globalToLocal(globalPos);
                                      setState(() {
                                        _dragAppt = appt;
                                        _dragPos = localPos;
                                        _isDragging = true;
                                        _dragTargetStaffId = lane.id;
                                        _dragTargetTime = _xToTime(localPos.dx);
                                        _dragValid = true;
                                      });
                                    },
                                    onDragUpdate: (globalPos) {
                                      final renderBox = _timelineKey.currentContext?.findRenderObject() as RenderBox?;
                                      if (renderBox == null || _dragAppt == null) return;
                                      final localPos = renderBox.globalToLocal(globalPos);
                                      final laneIdx = _yToLaneIndex(localPos.dy, lanes.length);
                                      final targetLane = lanes[laneIdx];
                                      final targetTime = _xToTime(localPos.dx);
                                      final duration = (_dragAppt!['duration_minutes'] as num?)?.toInt() ?? 60;
                                      final targetEnd = targetTime.add(Duration(minutes: duration));
                                      final serviceId = _dragAppt!['service_id'] as String?;

                                      final canDo = _canStaffDoService(targetLane.id, serviceId, staffServices);
                                      final noCollision = !_hasCollision(targetLane.id, targetTime, targetEnd, _dragAppt!['id'] as String, appts);

                                      setState(() {
                                        _dragPos = localPos;
                                        _dragTargetStaffId = targetLane.id;
                                        _dragTargetTime = targetTime;
                                        _dragValid = canDo && noCollision;
                                      });
                                    },
                                    onDragEnd: () {
                                      if (_dragAppt != null && _dragValid && _dragTargetTime != null && _dragTargetStaffId != null) {
                                        _executeReschedule(_dragAppt!, _dragTargetTime!, _dragTargetStaffId!, allStaff);
                                      } else if (_dragAppt != null && !_dragValid) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('No se puede mover aqui'),
                                            duration: Duration(seconds: 2),
                                            backgroundColor: Color(0xFFE53935),
                                          ),
                                        );
                                      }
                                      setState(() {
                                        _dragAppt = null;
                                        _dragPos = null;
                                        _dragTargetStaffId = null;
                                        _dragTargetTime = null;
                                        _dragValid = false;
                                        _isDragging = false;
                                      });
                                    },
                                  ),
                              ],
                            ),
                            // Ghost block during drag
                            if (_isDragging && _dragPos != null && _dragAppt != null) ...[
                              () {
                                final duration = (_dragAppt!['duration_minutes'] as num?)?.toInt() ?? 60;
                                final laneIdx = _yToLaneIndex(_dragPos!.dy, lanes.length);
                                final snapTime = _xToTime(_dragPos!.dx);
                                final snapMinutes = (snapTime.hour - _startHour) * 60 + snapTime.minute;
                                final snapX = (snapMinutes / 60.0) * _hourWidth;
                                final ghostWidth = (duration / 60.0) * _hourWidth;
                                final ghostTop = _labelRowHeight + laneIdx * _laneHeight + 4;
                                final service = _dragAppt!['service_name'] as String? ?? '';
                                final borderColor = _dragValid ? const Color(0xFF4CAF50) : const Color(0xFFE53935);

                                return Positioned(
                                  left: snapX,
                                  top: ghostTop,
                                  height: _laneHeight - 8,
                                  width: ghostWidth.clamp(30.0, _totalWidth - snapX),
                                  child: IgnorePointer(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: borderColor.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: borderColor, width: 2),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      child: Text(
                                        service,
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: borderColor),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                );
                              }(),
                            ],
                          ],
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
  }
}

class _LaneData {
  final String id;
  final String name;
  final int colorIndex;
  final List<Map<String, dynamic>> appts;
  final List<Map<String, dynamic>> blocks;

  _LaneData({
    required this.id,
    required this.name,
    required this.colorIndex,
    required this.appts,
    required this.blocks,
  });
}

// ── Staff Lane (horizontal Gantt row) ───────────────────────────────────────

class _StaffLane extends StatelessWidget {
  final _LaneData lane;
  final double laneHeight;
  final double hourWidth;
  final int startHour;
  final int endHour;
  final double totalWidth;
  final double? nowLineX;
  final ValueChanged<Map<String, dynamic>> onTapAppt;
  final bool isDragSource;
  final String? dragApptId;
  final bool enableDrag;
  final void Function(Map<String, dynamic> appt, Offset globalPos)? onDragStart;
  final void Function(Offset globalPos)? onDragUpdate;
  final VoidCallback? onDragEnd;

  const _StaffLane({
    required this.lane,
    required this.laneHeight,
    required this.hourWidth,
    required this.startHour,
    required this.endHour,
    required this.totalWidth,
    required this.nowLineX,
    required this.onTapAppt,
    this.isDragSource = false,
    this.dragApptId,
    this.enableDrag = false,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
  });

  double _timeToX(DateTime dt) {
    final minutesSinceStart = (dt.hour - startHour) * 60 + dt.minute;
    return (minutesSinceStart / 60.0) * hourWidth;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final staffColor = _staffColor(lane.colorIndex);

    return Container(
      height: laneHeight,
      width: totalWidth,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colors.onSurface.withValues(alpha: 0.06)),
        ),
      ),
      child: Stack(
        children: [
          // Hour grid lines
          for (var h = 0; h < endHour - startHour; h++)
            Positioned(
              left: h * hourWidth,
              top: 0,
              bottom: 0,
              child: Container(width: 1, color: colors.onSurface.withValues(alpha: 0.04)),
            ),

          // Schedule blocks (lunch/breaks)
          for (final block in lane.blocks)
            _buildScheduleBlock(context, block, colors),

          // Appointment blocks
          for (final appt in lane.appts)
            _buildApptBlock(context, appt, staffColor),

          // Now-line
          if (nowLineX != null) ...[
            Positioned(
              left: nowLineX!,
              top: 0,
              bottom: 0,
              child: Container(width: 2, color: const Color(0xFFE53935)),
            ),
            Positioned(
              left: nowLineX! - 4,
              top: 0,
              child: CustomPaint(
                size: const Size(10, 6),
                painter: _NowTrianglePainter(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScheduleBlock(BuildContext context, Map<String, dynamic> block, ColorScheme colors) {
    final startsAt = DateTime.tryParse(block['starts_at'] as String? ?? '')?.toLocal();
    final endsAt = DateTime.tryParse(block['ends_at'] as String? ?? '')?.toLocal();
    if (startsAt == null || endsAt == null) return const SizedBox.shrink();

    final left = _timeToX(startsAt).clamp(0.0, totalWidth);
    final right = _timeToX(endsAt).clamp(0.0, totalWidth);
    final width = (right - left).clamp(20.0, totalWidth);

    final reason = block['reason'] as String? ?? 'blocked';
    final label = switch (reason) {
      'lunch' => 'Descanso',
      'day_off' => 'Dia libre',
      'vacation' => 'Vacaciones',
      _ => reason.isNotEmpty ? reason : 'Bloqueado',
    };

    return Positioned(
      left: left,
      top: 4,
      height: laneHeight - 8,
      width: width,
      child: Container(
        decoration: BoxDecoration(
          color: colors.onSurface.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: width > 40
            ? Text(
                label,
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
    );
  }

  Widget _buildApptBlock(BuildContext context, Map<String, dynamic> appt, Color staffColor) {
    final startsAt = DateTime.tryParse(appt['starts_at'] as String? ?? '')?.toLocal();
    final endsAt = DateTime.tryParse(appt['ends_at'] as String? ?? '')?.toLocal();
    if (startsAt == null) return const SizedBox.shrink();

    final effectiveEnd = endsAt ?? startsAt.add(const Duration(minutes: 60));
    final left = _timeToX(startsAt).clamp(0.0, totalWidth);
    final right = _timeToX(effectiveEnd).clamp(0.0, totalWidth);
    final width = math.max(right - left, 30.0);

    final service = appt['service_name'] as String? ?? 'Servicio';
    final status = appt['status'] as String? ?? 'pending';
    final customer = appt['customer_name'] as String? ?? '';
    final accent = _statusColor(status);
    final isBeingDragged = isDragSource && dragApptId == appt['id'];

    return Positioned(
      left: left,
      top: 4,
      height: laneHeight - 8,
      width: width,
      child: GestureDetector(
        onTap: () => onTapAppt(appt),
        onLongPressStart: enableDrag && onDragStart != null
            ? (details) => onDragStart!(appt, details.globalPosition)
            : null,
        onLongPressMoveUpdate: enableDrag && onDragUpdate != null
            ? (details) => onDragUpdate!(details.globalPosition)
            : null,
        onLongPressEnd: enableDrag && onDragEnd != null
            ? (_) => onDragEnd!()
            : null,
        onLongPressCancel: enableDrag && onDragEnd != null
            ? () => onDragEnd!()
            : null,
        child: MouseRegion(
          cursor: enableDrag ? SystemMouseCursors.grab : SystemMouseCursors.click,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 150),
            opacity: isBeingDragged ? 0.3 : 1.0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: accent, width: 3)),
                  color: staffColor.withValues(alpha: 0.85),
                ),
                padding: const EdgeInsets.only(left: 5, right: 6, top: 3, bottom: 3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      service,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (width > 60)
                      Text(
                        '${startsAt.hour.toString().padLeft(2, '0')}:${startsAt.minute.toString().padLeft(2, '0')}'
                        '${endsAt != null ? ' - ${endsAt.hour.toString().padLeft(2, '0')}:${endsAt.minute.toString().padLeft(2, '0')}' : ''}',
                        style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: 0.85)),
                      ),
                    if (width > 80 && customer.isNotEmpty)
                      Text(
                        customer,
                        style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: 0.7)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Now-line triangle ───────────────────────────────────────────────────────

class _NowTrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFE53935);
    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Compact Week Strip (bottom) ─────────────────────────────────────────────

class _CompactWeekStrip extends ConsumerWidget {
  const _CompactWeekStrip({
    required this.weekStart,
    required this.selectedDate,
    required this.weekApptsAsync,
    required this.onDayTap,
  });

  final DateTime weekStart;
  final DateTime selectedDate;
  final AsyncValue<List<Map<String, dynamic>>> weekApptsAsync;
  final ValueChanged<DateTime> onDayTap;

  static const _dayNames = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final appts = weekApptsAsync.valueOrNull ?? [];
    final now = DateTime.now();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: Row(
        children: List.generate(7, (i) {
          final day = weekStart.add(Duration(days: i));
          final dayCount = appts.where((a) {
            final dt = DateTime.tryParse(a['starts_at'] as String? ?? '');
            return dt != null && dt.year == day.year && dt.month == day.month && dt.day == day.day;
          }).length;

          final isToday = day.year == now.year && day.month == now.month && day.day == now.day;
          final isSelected = day.year == selectedDate.year &&
              day.month == selectedDate.month &&
              day.day == selectedDate.day;

          return Expanded(
            child: GestureDetector(
              onTap: () => onDayTap(day),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colors.primary.withValues(alpha: 0.12)
                        : isToday
                            ? colors.primary.withValues(alpha: 0.04)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: isSelected
                        ? Border.all(color: colors.primary, width: 1.5)
                        : isToday
                            ? Border.all(color: colors.primary.withValues(alpha: 0.3))
                            : null,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _dayNames[day.weekday - 1],
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? colors.primary
                              : colors.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? colors.primary
                              : isToday
                                  ? colors.primary
                                  : colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (dayCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? colors.primary
                                : colors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$dayCount',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? Colors.white : colors.primary,
                            ),
                          ),
                        )
                      else
                        const SizedBox(height: 14),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
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
    final isDemo = ref.watch(isDemoProvider);
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

    final statusClr = _statusColor(status);

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
                      color: statusClr.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(statusLabel, style: TextStyle(fontSize: 12, color: statusClr, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 16),

                  _DetailRow(icon: Icons.person_outline, label: 'Cliente', value: customer),
                  if (staff.isNotEmpty) _DetailRow(icon: Icons.badge_outlined, label: 'Estilista', value: staff),
                  if (startsAt != null) _DetailRow(icon: Icons.access_time, label: 'Hora', value: DateFormat('HH:mm').format(startsAt)),
                  if (startsAt != null) _DetailRow(icon: Icons.calendar_today, label: 'Fecha', value: DateFormat('d MMM yyyy', 'es').format(startsAt)),
                  if (duration > 0) _DetailRow(icon: Icons.timer_outlined, label: 'Duracion', value: '$duration min'),
                  _DetailRow(icon: Icons.payments_outlined, label: 'Precio', value: '\$${price.toStringAsFixed(0)}'),

                  if (!isDemo) ...[
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
                      if (status == 'pending')
                        _ActionButton(
                          label: 'Confirmar',
                          icon: Icons.check,
                          color: const Color(0xFF4CAF50),
                          onPressed: () => _updateStatus('confirmed'),
                        ),
                      if (status == 'confirmed')
                        _ActionButton(
                          label: 'Completar',
                          icon: Icons.done_all,
                          color: const Color(0xFF2196F3),
                          onPressed: () => _updateStatus('completed'),
                        ),
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
