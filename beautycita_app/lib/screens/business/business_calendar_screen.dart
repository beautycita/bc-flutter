import 'dart:math' as math;
import 'package:beautycita/config/app_transitions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/constants.dart';
import '../../providers/business_provider.dart';
import 'package:go_router/go_router.dart';
import '../../services/supabase_client.dart';
import '../../services/toast_service.dart';

/// Returns true if the business owner already has a staff record in the list.
bool _ownerHasStaffRecord(String? ownerId, List<Map<String, dynamic>> staff) {
  if (ownerId == null) return false;
  return staff.any((s) => s['user_id'] == ownerId);
}

class BusinessCalendarScreen extends ConsumerStatefulWidget {
  const BusinessCalendarScreen({super.key});

  @override
  ConsumerState<BusinessCalendarScreen> createState() =>
      _BusinessCalendarScreenState();
}

enum _CalView { day, month }

class _BusinessCalendarScreenState
    extends ConsumerState<BusinessCalendarScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _timelineKey = GlobalKey<_HorizontalTimelineState>();
  late DateTime _selectedDate;
  String? _staffFilter; // null = all staff
  _CalView _view = _CalView.day;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    // Allow landscape on calendar screen
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    // Re-lock to portrait when leaving calendar
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  DateTimeRange get _range {
    final start = DateTime(_selectedDate.year, _selectedDate.month,
        _selectedDate.day);
    final end = DateTime(_selectedDate.year, _selectedDate.month,
        _selectedDate.day, 23, 59, 59);
    return DateTimeRange(start: start, end: end);
  }

  DateTimeRange get _monthRange {
    final start = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final end = DateTime(_selectedDate.year, _selectedDate.month + 1, 0, 23, 59, 59);
    return DateTimeRange(start: start, end: end);
  }

  /// Rolling 7-day window: yesterday + today (pos 1) + next 5 days
  DateTimeRange get _weekRange {
    final start = _selectedDate.subtract(const Duration(days: 1));
    final end = DateTime(start.year, start.month, start.day + 6, 23, 59, 59);
    return DateTimeRange(start: start, end: end);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required by AutomaticKeepAliveClientMixin
    final range = _range;
    final colors = Theme.of(context).colorScheme;

    final apptsAsync = ref.watch(businessAppointmentsProvider(
      (start: range.start.toUtc().toIso8601String(), end: range.end.toUtc().toIso8601String()),
    ));
    final blocksAsync = ref.watch(businessScheduleBlocksProvider(
      (start: range.start.toUtc().toIso8601String(), end: range.end.toUtc().toIso8601String()),
    ));
    // Week data for the compact strip
    final weekRange = _weekRange;
    final weekApptsAsync = ref.watch(businessAppointmentsProvider(
      (start: weekRange.start.toUtc().toIso8601String(), end: weekRange.end.toUtc().toIso8601String()),
    ));
    // Month data for month view
    final monthRange = _monthRange;
    final monthApptsAsync = ref.watch(businessAppointmentsProvider(
      (start: monthRange.start.toUtc().toIso8601String(), end: monthRange.end.toUtc().toIso8601String()),
    ));
    final staffAsync = ref.watch(businessStaffProvider);
    final staffServicesAsync = ref.watch(allStaffServicesProvider);
    final bizAsync = ref.watch(currentBusinessProvider);
    final ownerId = bizAsync.valueOrNull?['owner_id'] as String?;

    return Column(
      children: [
        // Summary card (day view only)
        if (_view == _CalView.day)
          _SummaryCard(
              date: _selectedDate,
              apptsAsync: apptsAsync,
              staffAsync: staffAsync,
              ownerId: ownerId,
              onPickDate: _pickDate,
            ),

        // View toggle + navigation bar
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.paddingSM,
            vertical: AppConstants.paddingXS,
          ),
          child: Row(
            children: [
              // View toggle
              Container(
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ViewToggle(
                      label: 'Dia',
                      icon: Icons.view_day_rounded,
                      selected: _view == _CalView.day,
                      onTap: () => setState(() => _view = _CalView.day),
                    ),
                    _ViewToggle(
                      label: 'Mes',
                      icon: Icons.calendar_month_rounded,
                      selected: _view == _CalView.month,
                      onTap: () => setState(() => _view = _CalView.month),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              // Prev
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () => setState(() {
                  if (_view == _CalView.day) {
                    _selectedDate = _selectedDate.subtract(const Duration(days: 1));
                  } else {
                    _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1, 1);
                  }
                }),
              ),
              // Date label
              Expanded(
                child: GestureDetector(
                  onTap: _pickDate,
                  child: Text(
                    _view == _CalView.day
                        ? _fmtFullDate(_selectedDate)
                        : _fmtMonth(_selectedDate),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface,
                    ),
                  ),
                ),
              ),
              // Next
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: () => setState(() {
                  if (_view == _CalView.day) {
                    _selectedDate = _selectedDate.add(const Duration(days: 1));
                  } else {
                    _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1, 1);
                  }
                }),
              ),
            ],
          ),
        ),

        // Staff filter chips (day view only)
        if (_view == _CalView.day)
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
                    if (ownerId != null && !_ownerHasStaffRecord(ownerId, staff))
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

        if (_view == _CalView.day) const SizedBox(height: 4),

        // Body
        Expanded(
          child: _view == _CalView.month
              ? _MonthGrid(
                  selectedDate: _selectedDate,
                  monthApptsAsync: monthApptsAsync,
                  onDayTap: (d) => setState(() {
                    _selectedDate = d;
                    _view = _CalView.day;
                  }),
                )
              : Column(
                  children: [
                    Expanded(
                      child: _HorizontalTimeline(
                        key: _timelineKey,
                        date: _selectedDate,
                        apptsAsync: apptsAsync,
                        blocksAsync: blocksAsync,
                        staffAsync: staffAsync,
                        staffFilter: _staffFilter,
                        ownerId: ownerId,
                        onAction: _handleAction,
                        onBlockTime: () => _showBlockTimeSheet(context),
                        onAddNew: () {
                          final visibleTime = _timelineKey.currentState?.getVisibleDateTime();
                          _showWalkinSheet(context, visibleTime);
                        },
                        onRefresh: _refresh,
                        staffServicesMap: staffServicesAsync.valueOrNull ?? const {},
                      ),
                    ),
                    // Compact week strip at bottom
                    _CompactWeekStrip(
                      weekRange: weekRange,
                      selectedDate: _selectedDate,
                      weekApptsAsync: weekApptsAsync,
                      onDayTap: (d) => setState(() => _selectedDate = d),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  static const _days = ['Lun', 'Mar', 'Mie', 'Jue', 'Vie', 'Sab', 'Dom'];
  static const _months = [
    'Ene','Feb','Mar','Abr','May','Jun',
    'Jul','Ago','Sep','Oct','Nov','Dic',
  ];

  String _fmtFullDate(DateTime d) =>
      '${_days[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]} ${d.year}';

  String _fmtMonth(DateTime d) => '${_months[d.month - 1]} ${d.year}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2026),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  void _refresh() {
    final range = _range;
    ref.invalidate(businessAppointmentsProvider(
      (start: range.start.toUtc().toIso8601String(), end: range.end.toUtc().toIso8601String()),
    ));
    ref.invalidate(businessScheduleBlocksProvider(
      (start: range.start.toUtc().toIso8601String(), end: range.end.toUtc().toIso8601String()),
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
    if (action == 'edit') {
      _showEditSheet(context, appt);
      return;
    }
    if (action == 'notes') {
      _showNotesSheet(context, appt);
      return;
    }

    try {
      await SupabaseClientService.client
          .from('appointments')
          .update({'status': action}).eq('id', id);
      _refresh();
      ToastService.showSuccess('Cita actualizada');
      if (action == 'cancelled_business' && mounted) {
        await showShredderTransition(context);
      }
    } catch (e, stack) {
      ToastService.showErrorWithDetails(ToastService.friendlyError(e), e, stack);
    }
  }

  void _showBlockTimeSheet(BuildContext context) {
    final staffAsync = ref.read(businessStaffProvider);
    final staffList = staffAsync.valueOrNull ?? [];
    final biz = ref.read(currentBusinessProvider).valueOrNull;

    // Include owner as first staff option (only if not already a staff member)
    final allStaff = <Map<String, dynamic>>[];
    final blockOwnerId = biz?['owner_id'] as String?;
    if (biz != null && !_ownerHasStaffRecord(blockOwnerId, staffList)) {
      allStaff.add({
        'id': biz['owner_id'],
        'first_name': 'Yo',
        'last_name': '(Dueño)',
      });
    }
    allStaff.addAll(staffList);

    showBurstBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _BlockTimeSheet(
        staffList: allStaff,
        onSaved: _refresh,
      ),
    );
  }

  void _showWalkinSheet(BuildContext context, DateTime? initialTime,
      {String? preselectedStaffId}) {
    final time = initialTime ??
        DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day,
            DateTime.now().hour);
    showBurstBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _WalkinSheet(
        initialDateTime: time,
        onSaved: _refresh,
        preselectedStaffId: preselectedStaffId,
      ),
    );
  }


  void _showEditSheet(BuildContext context, Map<String, dynamic> appt) {
    showBurstBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _EditApptSheet(
        appointment: appt,
        onSaved: _refresh,
      ),
    );
  }

  void _showNotesSheet(BuildContext context, Map<String, dynamic> appt) {
    showBurstBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _NotesSheet(
        appointment: appt,
        onSaved: _refresh,
      ),
    );
  }

  void _showRescheduleSheet(
      BuildContext context, Map<String, dynamic> appt) {
    showBurstBottomSheet(
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

    showBurstBottomSheet(
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

class _ViewToggle extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ViewToggle({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? colors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16,
                color: selected ? Colors.white : colors.onSurface.withValues(alpha: 0.6)),
            const SizedBox(width: 4),
            Text(label, style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : colors.onSurface.withValues(alpha: 0.6),
            )),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Month grid view
// ---------------------------------------------------------------------------

class _MonthGrid extends StatelessWidget {
  final DateTime selectedDate;
  final AsyncValue<List<Map<String, dynamic>>> monthApptsAsync;
  final ValueChanged<DateTime> onDayTap;

  const _MonthGrid({
    required this.selectedDate,
    required this.monthApptsAsync,
    required this.onDayTap,
  });

  static const _dayHeaders = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final appts = monthApptsAsync.valueOrNull ?? [];
    final today = DateTime.now();

    // Build appointment count per day-of-month
    final countByDay = <int, int>{};
    for (final a in appts) {
      final s = DateTime.tryParse(a['starts_at'] as String? ?? '')?.toLocal();
      if (s != null) countByDay[s.day] = (countByDay[s.day] ?? 0) + 1;
    }

    final firstOfMonth = DateTime(selectedDate.year, selectedDate.month, 1);
    final daysInMonth = DateTime(selectedDate.year, selectedDate.month + 1, 0).day;
    // Monday = 1, Sunday = 7. We want Monday as first column.
    final startWeekday = firstOfMonth.weekday; // 1=Mon ... 7=Sun
    final leadingBlanks = startWeekday - 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingMD),
      child: Column(
        children: [
          // Day-of-week headers
          Row(
            children: _dayHeaders.map((d) => Expanded(
              child: Center(
                child: Text(d, style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface.withValues(alpha: 0.4),
                )),
              ),
            )).toList(),
          ),
          const SizedBox(height: 4),
          // Calendar grid
          Expanded(
            child: GridView.builder(
              physics: const ClampingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1.0,
              ),
              itemCount: leadingBlanks + daysInMonth,
              itemBuilder: (ctx, idx) {
                if (idx < leadingBlanks) return const SizedBox.shrink();
                final day = idx - leadingBlanks + 1;
                final date = DateTime(selectedDate.year, selectedDate.month, day);
                final isToday = date.year == today.year &&
                    date.month == today.month &&
                    date.day == today.day;
                final count = countByDay[day] ?? 0;

                return GestureDetector(
                  onTap: () => onDayTap(date),
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isToday
                          ? colors.primary.withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: isToday
                          ? Border.all(color: colors.primary, width: 1.5)
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('$day', style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                          color: isToday ? colors.primary : colors.onSurface,
                        )),
                        if (count > 0) ...[
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('$count', style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: colors.primary,
                            )),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
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
// Summary card — appointment total, date, staff chips
// ---------------------------------------------------------------------------

class _SummaryCard extends StatelessWidget {
  final DateTime date;
  final AsyncValue<List<Map<String, dynamic>>> apptsAsync;
  final AsyncValue<List<Map<String, dynamic>>> staffAsync;
  final String? ownerId;
  final VoidCallback onPickDate;

  const _SummaryCard({
    required this.date,
    required this.apptsAsync,
    required this.staffAsync,
    required this.ownerId,
    required this.onPickDate,
  });

  static const _months = [
    'Ene','Feb','Mar','Abr','May','Jun',
    'Jul','Ago','Sep','Oct','Nov','Dic',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final appts = apptsAsync.valueOrNull ?? [];
    final staff = staffAsync.valueOrNull ?? [];

    // Build staff list with owner first (skip if owner already has a staff record)
    final allStaff = <_StaffInfo>[];
    if (ownerId != null && !_ownerHasStaffRecord(ownerId, staff)) {
      allStaff.add(_StaffInfo(id: ownerId!, name: 'Yo'));
    }
    for (final s in staff) {
      allStaff.add(_StaffInfo(
        id: s['id'] as String,
        name: s['first_name'] as String? ?? '?',
      ));
    }

    // Count per staff
    for (final si in allStaff) {
      si.count = appts.where((a) {
        final sid = a['staff_id'] as String?;
        if (si.id == ownerId) return sid == null || sid == ownerId;
        return sid == si.id;
      }).length;
    }

    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Container(
      margin: EdgeInsets.fromLTRB(
        AppConstants.paddingMD, isLandscape ? 4 : AppConstants.paddingSM,
        AppConstants.paddingMD, 0,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: AppConstants.paddingMD,
        vertical: isLandscape ? 6 : AppConstants.paddingMD,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        boxShadow: [
          BoxShadow(
            color: colors.onSurface.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Count
          Text('${appts.length}',
              style: GoogleFonts.poppins(
                fontSize: isLandscape ? 20 : 28,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF212121),
              )),
          const SizedBox(width: 6),
          // Date label
          Expanded(
            child: GestureDetector(
              onTap: onPickDate,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(isLandscape ? 'Citas' : 'Total Citas',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: colors.onSurface.withValues(alpha: 0.5),
                      )),
                  Text(
                    '${date.day} ${_months[date.month - 1]} \u25BC',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: colors.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Staff chips (portrait only)
          if (!isLandscape && allStaff.isNotEmpty)
            Expanded(
              child: Wrap(
                spacing: 12,
                runSpacing: 4,
                alignment: WrapAlignment.end,
                children: [
                  for (var i = 0; i < allStaff.length; i++)
                    _StaffChip(
                      name: allStaff[i].name,
                      count: allStaff[i].count,
                      color: _staffColor(i),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StaffInfo {
  final String id;
  final String name;
  int count = 0;
  _StaffInfo({required this.id, required this.name});
}

class _StaffChip extends StatelessWidget {
  final String name;
  final int count;
  final Color color;

  const _StaffChip({
    required this.name,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$name:$count',
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF616161),
          ),
        ),
      ],
    );
  }
}

// Staff color palette — high-contrast, distinct hues
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

Color _statusAccent(String status) {
  switch (status) {
    case 'pending': return const Color(0xFFFFA726);
    case 'confirmed': return const Color(0xFF66BB6A);
    case 'completed': return const Color(0xFF42A5F5);
    case 'no_show': return const Color(0xFFBDBDBD);
    case 'cancelled_business':
    case 'cancelled_customer':
      return const Color(0xFFEF5350);
    default: return const Color(0xFFE0E0E0);
  }
}

// ---------------------------------------------------------------------------
// Horizontal Gantt-style timeline
// ---------------------------------------------------------------------------

class _HorizontalTimeline extends StatefulWidget {
  final DateTime date;
  final AsyncValue<List<Map<String, dynamic>>> apptsAsync;
  final AsyncValue<List<Map<String, dynamic>>> blocksAsync;
  final AsyncValue<List<Map<String, dynamic>>> staffAsync;
  final String? staffFilter;
  final String? ownerId;
  final Future<void> Function(Map<String, dynamic>, String) onAction;
  final VoidCallback onBlockTime;
  final VoidCallback onAddNew;
  final VoidCallback onRefresh;
  final Map<String, Set<String>> staffServicesMap;

  const _HorizontalTimeline({
    super.key,
    required this.date,
    required this.apptsAsync,
    required this.blocksAsync,
    required this.staffAsync,
    required this.staffFilter,
    this.ownerId,
    required this.onAction,
    required this.onBlockTime,
    required this.onAddNew,
    required this.onRefresh,
    this.staffServicesMap = const {},
  });

  @override
  State<_HorizontalTimeline> createState() => _HorizontalTimelineState();
}

class _HorizontalTimelineState extends State<_HorizontalTimeline> {
  static const _startHour = 8;
  static const _endHour = 21;
  static const _hourWidth = 120.0;
  static const _laneHeight = 70.0;
  static const _labelRowHeight = 24.0;
  static const _staffColumnWidth = 60.0;
  static const _totalWidth = (_endHour - _startHour) * _hourWidth;

  late ScrollController _scrollController;

  // ── Drag state ──
  Map<String, dynamic>? _dragAppt;
  Offset? _dragPos; // position relative to timeline area
  String? _dragTargetStaffId;
  DateTime? _dragTargetTime;
  bool _dragValid = false;
  bool _isDragging = false;
  final GlobalKey _timelineAreaKey = GlobalKey();

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

  void _scrollToNow() {
    final now = DateTime.now();
    final isToday = now.year == widget.date.year &&
        now.month == widget.date.month &&
        now.day == widget.date.day;

    double targetOffset;
    if (isToday && now.hour >= _startHour && now.hour < _endHour) {
      final minutesSinceStart = (now.hour - _startHour) * 60 + now.minute;
      targetOffset = (minutesSinceStart / 60.0) * _hourWidth - 40;
    } else {
      targetOffset = 0;
    }
    targetOffset = targetOffset.clamp(
        0, math.max(0, _totalWidth - (MediaQuery.of(context).size.width - _staffColumnWidth)));

    if (_scrollController.hasClients) {
      _scrollController.jumpTo(targetOffset);
    }
  }

  /// Returns the date+time currently visible at the center of the viewport.
  DateTime getVisibleDateTime() {
    if (!_scrollController.hasClients) {
      return DateTime(widget.date.year, widget.date.month, widget.date.day,
          DateTime.now().hour);
    }
    final viewportWidth =
        MediaQuery.of(context).size.width - _staffColumnWidth;
    final centerX = _scrollController.offset + viewportWidth / 2;
    final minutesSinceStart = (centerX / _hourWidth) * 60;
    final totalMinutes = minutesSinceStart.round();
    final hour =
        (_startHour + totalMinutes ~/ 60).clamp(_startHour, _endHour - 1);
    final minute = (totalMinutes % 60).clamp(0, 59);
    return DateTime(
        widget.date.year, widget.date.month, widget.date.day, hour, minute);
  }

  @override
  void didUpdateWidget(_HorizontalTimeline old) {
    super.didUpdateWidget(old);
    if (old.date != widget.date) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToNow());
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

  /// Convert Y offset within timeline to lane index.
  int _yToLaneIndex(double y, int laneCount) {
    final adjusted = y - _labelRowHeight;
    if (adjusted < 0) return 0;
    return (adjusted / _laneHeight).floor().clamp(0, laneCount - 1);
  }

  bool _canStaffDoService(String staffId, String? serviceId, Map<String, Set<String>> staffServices) {
    if (serviceId == null) return true;
    if (staffServices.isEmpty) return true;
    final services = staffServices[staffId];
    if (services == null) return false;
    return services.contains(serviceId);
  }

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

  Future<void> _executeReschedule(Map<String, dynamic> appt, DateTime newStart, String newStaffId, List<Map<String, dynamic>> allStaff) async {
    final id = appt['id'] as String?;
    if (id == null) return;

    final duration = (appt['duration_minutes'] as num?)?.toInt() ?? 60;
    final newEnd = newStart.add(Duration(minutes: duration));

    final updateData = <String, dynamic>{
      'starts_at': newStart.toUtc().toIso8601String(),
      'ends_at': newEnd.toUtc().toIso8601String(),
    };

    final oldStaffId = appt['staff_id'] as String?;
    if (newStaffId != oldStaffId) {
      updateData['staff_id'] = newStaffId;
      final staffMember = allStaff.firstWhere(
        (s) => s['id'] == newStaffId,
        orElse: () => <String, dynamic>{},
      );
      final firstName = staffMember['first_name'] as String? ?? '';
      final lastName = staffMember['last_name'] as String? ?? '';
      updateData['staff_name'] = '$firstName $lastName'.trim();
    }

    try {
      await SupabaseClientService.client
          .from('appointments')
          .update(updateData)
          .eq('id', id);

      widget.onRefresh();

      if (mounted) {
        ToastService.showSuccess('Cita reagendada');
      }

      // Fire-and-forget: send reschedule notification
      _sendRescheduleNotification(id);
    } catch (e) {
      if (mounted) {
        ToastService.showError('Error al reagendar: $e');
      }
    }
  }

  Future<void> _sendRescheduleNotification(String appointmentId) async {
    try {
      await SupabaseClientService.client.functions.invoke(
        'reschedule-notification',
        body: {'appointment_id': appointmentId},
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[Reschedule] Notification error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final appts = widget.apptsAsync.valueOrNull ?? [];
    final blocks = widget.blocksAsync.valueOrNull ?? [];
    final staff = widget.staffAsync.valueOrNull ?? [];

    // Build staff lanes (skip owner if already a staff member)
    final lanes = <_LaneData>[];
    if (widget.ownerId != null && !_ownerHasStaffRecord(widget.ownerId, staff)) {
      lanes.add(_LaneData(id: widget.ownerId!, name: 'Yo'));
    }
    for (final s in staff) {
      lanes.add(_LaneData(
        id: s['id'] as String,
        name: s['first_name'] as String? ?? '?',
      ));
    }

    // Apply staff filter
    final visibleLanes = widget.staffFilter != null
        ? lanes.where((l) {
            if (widget.staffFilter == widget.ownerId) {
              return l.id == widget.ownerId;
            }
            return l.id == widget.staffFilter;
          }).toList()
        : lanes;

    if (visibleLanes.isEmpty && lanes.isEmpty) {
      // No staff at all — show single lane
      lanes.add(_LaneData(id: widget.ownerId ?? '', name: 'Yo'));
    }

    final effectiveLanes = visibleLanes.isEmpty ? lanes : visibleLanes;

    // Assign appointments and blocks to lanes
    for (final lane in effectiveLanes) {
      lane.appts = appts.where((a) {
        final sid = a['staff_id'] as String?;
        if (lane.id == widget.ownerId) return sid == null || sid == widget.ownerId;
        return sid == lane.id;
      }).toList();

      lane.blocks = blocks.where((b) {
        final sid = b['staff_id'] as String?;
        if (sid == null) return true; // Salon-wide block
        if (lane.id == widget.ownerId) return sid == widget.ownerId;
        return sid == lane.id;
      }).toList();
    }

    // Now-line position
    final now = DateTime.now();
    final isToday = now.year == widget.date.year &&
        now.month == widget.date.month &&
        now.day == widget.date.day;
    double? nowLineX;
    if (isToday && now.hour >= _startHour && now.hour < _endHour) {
      final minutesSinceStart = (now.hour - _startHour) * 60 + now.minute;
      nowLineX = (minutesSinceStart / 60.0) * _hourWidth;
    }

    // Pre-compute lane color indices
    final laneColorIndices = <int>[];
    for (var i = 0; i < effectiveLanes.length; i++) {
      final idx = lanes.indexOf(effectiveLanes[i]);
      laneColorIndices.add(idx >= 0 ? idx : i);
    }

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () async => widget.onRefresh(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fixed staff name column
                SizedBox(
                  width: _staffColumnWidth,
                  child: Column(
                    children: [
                      SizedBox(height: _labelRowHeight),
                      for (var i = 0; i < effectiveLanes.length; i++)
                        Container(
                          height: _laneHeight,
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.only(left: 6),
                          child: Text(
                            effectiveLanes[i].name,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _staffColor(laneColorIndices[i]),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
                // Scrollable timeline
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    physics: _isDragging ? const NeverScrollableScrollPhysics() : null,
                    child: SizedBox(
                      key: _timelineAreaKey,
                      width: _totalWidth,
                      child: Stack(
                        children: [
                          Column(
                            children: [
                              // Hour labels
                              SizedBox(
                                height: _labelRowHeight,
                                child: Row(
                                  children: List.generate(
                                    _endHour - _startHour,
                                    (i) {
                                      final hour = _startHour + i;
                                      return SizedBox(
                                        width: _hourWidth,
                                        child: Text(
                                          '${hour > 12 ? hour - 12 : hour}${hour >= 12 ? 'PM' : 'AM'}',
                                          style: GoogleFonts.poppins(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                            color: colors.onSurface.withValues(alpha: 0.4),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              // Staff lanes
                              for (var i = 0; i < effectiveLanes.length; i++)
                                _StaffLane(
                                  lane: effectiveLanes[i],
                                  laneIndex: laneColorIndices[i],
                                  laneHeight: _laneHeight,
                                  hourWidth: _hourWidth,
                                  startHour: _startHour,
                                  endHour: _endHour,
                                  totalWidth: _totalWidth,
                                  nowLineX: nowLineX,
                                  onAction: widget.onAction,
                                  onRefresh: widget.onRefresh,
                                  isDragSource: _isDragging && _dragAppt?['staff_id'] == effectiveLanes[i].id,
                                  dragApptId: _dragAppt?['id'] as String?,
                                  onApptDragStart: (appt, globalPos) {
                                    final renderBox = _timelineAreaKey.currentContext?.findRenderObject() as RenderBox?;
                                    if (renderBox == null) return;
                                    final localPos = renderBox.globalToLocal(globalPos);
                                    setState(() {
                                      _dragAppt = appt;
                                      _dragPos = localPos;
                                      _isDragging = true;
                                      _dragTargetStaffId = effectiveLanes[i].id;
                                      _dragTargetTime = _xToTime(localPos.dx);
                                      _dragValid = true;
                                    });
                                  },
                                  onApptDragUpdate: (globalPos) {
                                    final renderBox = _timelineAreaKey.currentContext?.findRenderObject() as RenderBox?;
                                    if (renderBox == null || _dragAppt == null) return;
                                    final localPos = renderBox.globalToLocal(globalPos);
                                    final laneIdx = _yToLaneIndex(localPos.dy, effectiveLanes.length);
                                    final targetLane = effectiveLanes[laneIdx];
                                    final targetTime = _xToTime(localPos.dx);
                                    final duration = (_dragAppt!['duration_minutes'] as num?)?.toInt() ?? 60;
                                    final targetEnd = targetTime.add(Duration(minutes: duration));
                                    final serviceId = _dragAppt!['service_id'] as String?;

                                    final canDo = _canStaffDoService(targetLane.id, serviceId, widget.staffServicesMap);
                                    final noCollision = !_hasCollision(targetLane.id, targetTime, targetEnd, _dragAppt!['id'] as String, appts);

                                    setState(() {
                                      _dragPos = localPos;
                                      _dragTargetStaffId = targetLane.id;
                                      _dragTargetTime = targetTime;
                                      _dragValid = canDo && noCollision;
                                    });
                                  },
                                  onApptDragEnd: () async {
                                    if (_dragAppt != null && _dragValid && _dragTargetTime != null && _dragTargetStaffId != null) {
                                      await _executeReschedule(_dragAppt!, _dragTargetTime!, _dragTargetStaffId!, staff);
                                    } else if (_dragAppt != null && !_dragValid) {
                                      ToastService.showWarning('No se puede mover aqui');
                                    }
                                    if (!mounted) return;
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
                              final laneIdx = _yToLaneIndex(_dragPos!.dy, effectiveLanes.length);
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
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: borderColor,
                                      ),
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
          ),
        ),
        // Viewport center marker — subtle tick showing where "Add" time comes from
        Positioned(
          left: _staffColumnWidth +
              (MediaQuery.of(context).size.width - _staffColumnWidth) / 2 - 5,
          top: 0,
          child: IgnorePointer(
            child: CustomPaint(
              size: const Size(10, 6),
              painter: _CenterTickPainter(
                color: colors.primary.withValues(alpha: 0.25),
              ),
            ),
          ),
        ),
        // Action FABs
        Positioned(
          right: AppConstants.paddingMD,
          bottom: AppConstants.paddingMD,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Add appointment
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton.small(
                    heroTag: 'addAppt',
                    onPressed: widget.onAddNew,
                    child: const Icon(Icons.add_rounded, size: 20),
                  ),
                  const SizedBox(height: 2),
                  Text('Cita',
                      style: GoogleFonts.nunito(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface.withValues(alpha: 0.5),
                      )),
                ],
              ),
              const SizedBox(width: 12),
              // Block time
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton.small(
                    heroTag: 'blockTime',
                    onPressed: widget.onBlockTime,
                    child: const Icon(Icons.block_rounded, size: 20),
                  ),
                  const SizedBox(height: 2),
                  Text('Tiempo',
                      style: GoogleFonts.nunito(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface.withValues(alpha: 0.5),
                      )),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LaneData {
  final String id;
  final String name;
  List<Map<String, dynamic>> appts = const [];
  List<Map<String, dynamic>> blocks = const [];
  _LaneData({required this.id, required this.name});
}

// ---------------------------------------------------------------------------
// Staff lane — a single row in the Gantt chart
// ---------------------------------------------------------------------------

class _StaffLane extends StatelessWidget {
  final _LaneData lane;
  final int laneIndex;
  final double laneHeight;
  final double hourWidth;
  final int startHour;
  final int endHour;
  final double totalWidth;
  final double? nowLineX;
  final Future<void> Function(Map<String, dynamic>, String) onAction;
  final VoidCallback onRefresh;
  final bool isDragSource;
  final String? dragApptId;
  final void Function(Map<String, dynamic> appt, Offset globalPos)? onApptDragStart;
  final void Function(Offset globalPos)? onApptDragUpdate;
  final VoidCallback? onApptDragEnd;

  const _StaffLane({
    required this.lane,
    required this.laneIndex,
    required this.laneHeight,
    required this.hourWidth,
    required this.startHour,
    required this.endHour,
    required this.totalWidth,
    required this.nowLineX,
    required this.onAction,
    required this.onRefresh,
    this.isDragSource = false,
    this.dragApptId,
    this.onApptDragStart,
    this.onApptDragUpdate,
    this.onApptDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final staffColor = _staffColor(laneIndex);

    return Container(
        height: laneHeight,
        width: totalWidth,
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: colors.onSurface.withValues(alpha: 0.06),
            ),
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
                child: Container(
                  width: 1,
                  color: colors.onSurface.withValues(alpha: 0.04),
                ),
              ),

            // Schedule blocks (lunch/breaks)
            for (final block in lane.blocks)
              _buildBlock(context, block, colors),

            // Appointment blocks
            for (final appt in lane.appts)
              _buildApptBlock(context, appt, staffColor),

            // Now-line
            if (nowLineX != null)
              Positioned(
                left: nowLineX!,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 2,
                  color: const Color(0xFFFFB300),
                ),
              ),
            if (nowLineX != null)
              Positioned(
                left: nowLineX! - 4,
                top: 0,
                child: CustomPaint(
                  size: const Size(10, 6),
                  painter: _NowTrianglePainter(),
                ),
              ),
          ],
        ),
      );
  }

  double _timeToX(DateTime dt) {
    final minutesSinceStart = (dt.hour - startHour) * 60 + dt.minute;
    return (minutesSinceStart / 60.0) * hourWidth;
  }

  Widget _buildBlock(
      BuildContext context, Map<String, dynamic> block, ColorScheme colors) {
    final startsAt = DateTime.tryParse(block['starts_at'] as String? ?? '')?.toLocal();
    final endsAt = DateTime.tryParse(block['ends_at'] as String? ?? '')?.toLocal();
    if (startsAt == null || endsAt == null) return const SizedBox.shrink();

    final left = _timeToX(startsAt).clamp(0.0, totalWidth);
    final right = _timeToX(endsAt).clamp(0.0, totalWidth);
    final width = (right - left).clamp(20.0, totalWidth);

    final reason = block['reason'] as String? ?? 'blocked';
    final isNote = reason == 'note';
    final noteText = block['note'] as String? ?? '';
    final label = isNote ? noteText : _reasonLabel(reason);

    if (isNote) {
      return Positioned(
        left: left,
        top: 4,
        height: laneHeight - 8,
        width: width,
        child: GestureDetector(
          onTap: () => _showNoteDetail(context, block),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFFF9C4), // pale yellow sticky-note
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: const Color(0xFFFFD54F), width: 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                const Icon(Icons.sticky_note_2_rounded,
                    size: 10, color: Color(0xFFF9A825)),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.nunito(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF5D4037),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

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
        child: Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 10,
            fontStyle: FontStyle.italic,
            color: colors.onSurface.withValues(alpha: 0.35),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  void _showNoteDetail(BuildContext context, Map<String, dynamic> block) {
    final noteText = block['note'] as String? ?? '';
    final startsAt = DateTime.tryParse(block['starts_at'] as String? ?? '')?.toLocal();
    final blockId = block['id'] as String?;
    final colors = Theme.of(context).colorScheme;

    showBurstBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.sticky_note_2_rounded,
                    size: 20, color: Color(0xFFF9A825)),
                const SizedBox(width: 8),
                Text('Nota',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface,
                    )),
                const Spacer(),
                if (startsAt != null)
                  Text(
                    '${startsAt.hour.toString().padLeft(2, '0')}:${startsAt.minute.toString().padLeft(2, '0')}',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: colors.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF9C4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFD54F)),
              ),
              child: Text(
                noteText,
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  color: const Color(0xFF5D4037),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (blockId != null)
              TextButton.icon(
                onPressed: () async {
                  await SupabaseClientService.client
                      .from('staff_schedule_blocks')
                      .delete()
                      .eq('id', blockId);
                  onRefresh();
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Eliminar nota'),
                style: TextButton.styleFrom(
                  foregroundColor: colors.error,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildApptBlock(
      BuildContext context, Map<String, dynamic> appt, Color staffColor) {
    final startsAt =
        DateTime.tryParse(appt['starts_at'] as String? ?? '')?.toLocal();
    final endsAt =
        DateTime.tryParse(appt['ends_at'] as String? ?? '')?.toLocal();
    if (startsAt == null) return const SizedBox.shrink();

    final effectiveEnd = endsAt ?? startsAt.add(const Duration(minutes: 60));
    final left = _timeToX(startsAt).clamp(0.0, totalWidth);
    final right = _timeToX(effectiveEnd).clamp(0.0, totalWidth);
    final width = math.max(right - left, 30.0);

    final service = appt['service_name'] as String? ?? 'Servicio';
    final status = appt['status'] as String? ?? 'pending';
    final hasNotes = (appt['notes'] as String?)?.isNotEmpty == true;
    final accent = _statusAccent(status);
    final isBeingDragged = isDragSource && dragApptId == appt['id'];

    return Positioned(
      left: left,
      top: 4,
      height: laneHeight - 8,
      width: width,
      child: GestureDetector(
        onTap: () => _showApptActionSheet(context, appt, onAction),
        onLongPressStart: onApptDragStart != null
            ? (details) => onApptDragStart!(appt, details.globalPosition)
            : null,
        onLongPressMoveUpdate: onApptDragUpdate != null
            ? (details) => onApptDragUpdate!(details.globalPosition)
            : null,
        onLongPressEnd: onApptDragEnd != null
            ? (_) => onApptDragEnd!()
            : null,
        onLongPressCancel: onApptDragEnd != null
            ? () => onApptDragEnd!()
            : null,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: isBeingDragged ? 0.3 : 1.0,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: accent, width: 3)),
                color: staffColor.withValues(alpha: 0.9),
              ),
              padding:
                  const EdgeInsets.only(left: 5, right: 6, top: 3, bottom: 3),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        service,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (width > 60)
                        Text(
                          '${startsAt.hour.toString().padLeft(2, '0')}:${startsAt.minute.toString().padLeft(2, '0')}'
                          '${endsAt != null ? ' - ${endsAt.hour.toString().padLeft(2, '0')}:${endsAt.minute.toString().padLeft(2, '0')}' : ''}',
                          style: GoogleFonts.nunito(
                            fontSize: 9,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                    ],
                  ),
                  // Notes flag
                  if (hasNotes)
                    const Positioned(
                      top: 0,
                      right: 0,
                      child: Icon(Icons.sticky_note_2,
                          size: 12, color: Colors.white70),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _reasonLabel(String reason) {
    switch (reason) {
      case 'lunch': return 'Almuerzo';
      case 'day_off': return 'Dia libre';
      case 'vacation': return 'Vacaciones';
      case 'note': return 'Nota';
      default: return 'Bloqueado';
    }
  }
}

// Now-line triangle indicator
class _NowTrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFFFB300);
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

/// Subtle downward tick at the viewport center — shows where "Add" time is taken from
class _CenterTickPainter extends CustomPainter {
  final Color color;
  _CenterTickPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CenterTickPainter old) => old.color != color;
}

// ---------------------------------------------------------------------------
// Standalone action sheet for appointment blocks
// ---------------------------------------------------------------------------

void _showApptActionSheet(
  BuildContext context,
  Map<String, dynamic> appointment,
  Future<void> Function(Map<String, dynamic>, String) onAction,
) {
  final status = appointment['status'] as String? ?? 'pending';
  final service = appointment['service_name'] as String? ?? 'Servicio';
  final startsAt =
      DateTime.tryParse(appointment['starts_at'] as String? ?? '')?.toLocal();
  final notes = appointment['notes'] as String?;

  showBurstBottomSheet(
    context: context,
    builder: (ctx) {
      final colors = Theme.of(ctx).colorScheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingMD),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with appointment info
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _statusAccent(status),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(service,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: colors.onSurface,
                            )),
                        if (startsAt != null)
                          Text(
                            '${startsAt.hour.toString().padLeft(2, '0')}:${startsAt.minute.toString().padLeft(2, '0')} - ${_statusLabel(status)}',
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              color: colors.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (notes != null && notes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.sticky_note_2,
                          size: 14, color: Color(0xFFFF8F00)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(notes,
                            style: GoogleFonts.nunito(
                                fontSize: 12, color: const Color(0xFF5D4037)),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              const Divider(height: 1),

              // Status-specific actions
              if (status == 'pending') ...[
                _ActionTile(
                  icon: Icons.check_circle_rounded,
                  label: 'Confirmar',
                  color: const Color(0xFF66BB6A),
                  onTap: () {
                    Navigator.pop(ctx);
                    onAction(appointment, 'confirmed');
                  },
                ),
                _ActionTile(
                  icon: Icons.cancel_rounded,
                  label: 'Cancelar',
                  color: const Color(0xFFEF5350),
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
                  color: const Color(0xFF66BB6A),
                  onTap: () {
                    Navigator.pop(ctx);
                    onAction(appointment, 'completed');
                  },
                ),
                _ActionTile(
                  icon: Icons.person_off_rounded,
                  label: 'No-Show',
                  color: const Color(0xFFBDBDBD),
                  onTap: () {
                    Navigator.pop(ctx);
                    onAction(appointment, 'no_show');
                  },
                ),
                _ActionTile(
                  icon: Icons.cancel_rounded,
                  label: 'Cancelar',
                  color: const Color(0xFFEF5350),
                  onTap: () {
                    Navigator.pop(ctx);
                    onAction(appointment, 'cancelled_business');
                  },
                ),
              ],

              // Reschedule (pending + confirmed only)
              if (status == 'pending' || status == 'confirmed')
                _ActionTile(
                  icon: Icons.schedule_rounded,
                  label: 'Reprogramar',
                  color: colors.primary,
                  onTap: () {
                    Navigator.pop(ctx);
                    onAction(appointment, 'reschedule');
                  },
                ),

              // Portfolio capture (confirmed + completed)
              if (status == 'confirmed' || status == 'completed')
                _ActionTile(
                  icon: Icons.camera_alt_rounded,
                  label: 'Portafolio',
                  color: const Color(0xFF7C3AED),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push('/business/portfolio-capture?staffId=${appointment['staff_id']}');
                  },
                ),

              // Universal actions — all statuses
              _ActionTile(
                icon: Icons.edit_rounded,
                label: 'Editar',
                color: const Color(0xFF1E88E5),
                onTap: () {
                  Navigator.pop(ctx);
                  onAction(appointment, 'edit');
                },
              ),
              _ActionTile(
                icon: Icons.sticky_note_2_outlined,
                label: notes != null && notes.isNotEmpty
                    ? 'Editar nota'
                    : 'Agregar nota',
                color: const Color(0xFFFF8F00),
                onTap: () {
                  Navigator.pop(ctx);
                  onAction(appointment, 'notes');
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

String _statusLabel(String status) {
  switch (status) {
    case 'pending': return 'Pendiente';
    case 'confirmed': return 'Confirmada';
    case 'completed': return 'Completada';
    case 'no_show': return 'No-Show';
    case 'cancelled_business': return 'Cancelada';
    case 'cancelled_customer': return 'Cancelada por cliente';
    default: return status;
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
// Compact week strip (bottom of day view)
// ---------------------------------------------------------------------------

class _CompactWeekStrip extends StatelessWidget {
  final DateTimeRange weekRange;
  final DateTime selectedDate;
  final AsyncValue<List<Map<String, dynamic>>> weekApptsAsync;
  final ValueChanged<DateTime> onDayTap;

  const _CompactWeekStrip({
    required this.weekRange,
    required this.selectedDate,
    required this.weekApptsAsync,
    required this.onDayTap,
  });

  static const _dayLetters = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final appts = weekApptsAsync.valueOrNull ?? [];
    final now = DateTime.now();
    // weekRange.start is yesterday (selectedDate - 1)

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: colors.onSurface.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: Row(
        children: List.generate(7, (i) {
          final day = weekRange.start.add(Duration(days: i));
          final dayCount = appts.where((a) {
            final dt = DateTime.tryParse(a['starts_at'] as String? ?? '');
            return dt != null &&
                dt.year == day.year &&
                dt.month == day.month &&
                dt.day == day.day;
          }).length;

          final isToday = day.year == now.year &&
              day.month == now.month &&
              day.day == now.day;
          final isSelected = day.year == selectedDate.year &&
              day.month == selectedDate.month &&
              day.day == selectedDate.day;

          return Expanded(
            child: GestureDetector(
              onTap: () => onDayTap(day),
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
                          ? Border.all(
                              color: colors.primary.withValues(alpha: 0.3))
                          : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _dayLetters[day.weekday - 1],
                      style: GoogleFonts.poppins(
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
                      style: GoogleFonts.poppins(
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? colors.primary
                              : colors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$dayCount',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? Colors.white
                                : colors.primary,
                          ),
                        ),
                      )
                    else
                      const SizedBox(height: 14),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
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
  late String? _staffId;
  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 14, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 15, minute: 0);
  String _reason = 'day_off';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _staffId = widget.staffList.isNotEmpty
        ? widget.staffList.first['id'] as String?
        : null;
  }

  static const _months = [
    'Ene','Feb','Mar','Abr','May','Jun',
    'Jul','Ago','Sep','Oct','Nov','Dic',
  ];

  bool get _isFullDay => _reason == 'vacation' || _reason == 'day_off';
  bool get _showTimes => _reason == 'lunch' || _reason == 'other';

  String _fmtDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20, 20, 20,
        MediaQuery.of(context).viewInsets.bottom + 20,
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
            const SizedBox(height: 16),

            // Staff
            _SheetDropdown<String?>(
              label: 'Empleado',
              icon: Icons.person_rounded,
              value: _staffId,
              hint: 'Seleccionar empleado',
              items: [
                for (final s in widget.staffList)
                  DropdownMenuItem<String?>(
                    value: s['id'] as String,
                    child: Text(
                      '${s['first_name']} ${s['last_name'] ?? ''}'.trim(),
                      style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _staffId = v),
            ),
            const SizedBox(height: 12),

            // Reason
            _SheetDropdown<String>(
              label: 'Motivo',
              icon: Icons.event_busy_rounded,
              value: _reason,
              items: [
                DropdownMenuItem(
                  value: 'lunch',
                  child: Text('Almuerzo',
                      style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600)),
                ),
                DropdownMenuItem(
                  value: 'day_off',
                  child: Text('Dia libre',
                      style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600)),
                ),
                DropdownMenuItem(
                  value: 'vacation',
                  child: Text('Vacaciones',
                      style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600)),
                ),
                DropdownMenuItem(
                  value: 'other',
                  child: Text('Otro',
                      style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ],
              onChanged: (v) => setState(() {
                _reason = v ?? 'other';
                // Sync dates if switching to full-day mode
                if (_isFullDay && _toDate.isBefore(_fromDate)) {
                  _toDate = _fromDate;
                }
              }),
            ),
            const SizedBox(height: 12),

            // ── Lunch: time pickers only (today) ──
            if (_reason == 'lunch') ...[
              Row(
                children: [
                  Expanded(
                    child: _PickerTile(
                      icon: Icons.access_time_rounded,
                      label: _startTime.format(context),
                      onTap: () async {
                        final t = await showTimePicker(
                          context: context,
                          initialTime: _startTime,
                        );
                        if (t != null) {
                          setState(() {
                            _startTime = t;
                            _endTime = TimeOfDay(
                              hour: (t.hour + 1) % 24,
                              minute: t.minute,
                            );
                          });
                        }
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(Icons.arrow_forward_rounded,
                        size: 16, color: colors.onSurface.withValues(alpha: 0.3)),
                  ),
                  Expanded(
                    child: _PickerTile(
                      icon: Icons.access_time_rounded,
                      label: _endTime.format(context),
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
            ],

            // ── Day off: single date (full day) ──
            if (_reason == 'day_off') ...[
              _PickerTile(
                icon: Icons.calendar_today_rounded,
                label: _fmtDate(_fromDate),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _fromDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2030),
                  );
                  if (d != null) {
                    setState(() {
                      _fromDate = d;
                      _toDate = d;
                    });
                  }
                },
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 4),
                child: Text(
                  'Bloqueo de dia completo',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: colors.onSurface.withValues(alpha: 0.4),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],

            // ── Vacation: date range (full days) ──
            if (_reason == 'vacation') ...[
              Row(
                children: [
                  Expanded(
                    child: _PickerTile(
                      icon: Icons.calendar_today_rounded,
                      label: _fmtDate(_fromDate),
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _fromDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2030),
                        );
                        if (d != null) {
                          setState(() {
                            _fromDate = d;
                            if (_toDate.isBefore(_fromDate)) _toDate = _fromDate;
                          });
                        }
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(Icons.arrow_forward_rounded,
                        size: 16, color: colors.onSurface.withValues(alpha: 0.3)),
                  ),
                  Expanded(
                    child: _PickerTile(
                      icon: Icons.event_rounded,
                      label: _fmtDate(_toDate),
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _toDate.isBefore(_fromDate) ? _fromDate : _toDate,
                          firstDate: _fromDate,
                          lastDate: DateTime(2030),
                        );
                        if (d != null) setState(() => _toDate = d);
                      },
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 4),
                child: Text(
                  'Dias completos bloqueados',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: colors.onSurface.withValues(alpha: 0.4),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],

            // ── Other: date range + time pickers ──
            if (_reason == 'other') ...[
              Row(
                children: [
                  Expanded(
                    child: _PickerTile(
                      icon: Icons.calendar_today_rounded,
                      label: _fmtDate(_fromDate),
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _fromDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2030),
                        );
                        if (d != null) {
                          setState(() {
                            _fromDate = d;
                            if (_toDate.isBefore(_fromDate)) _toDate = _fromDate;
                          });
                        }
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(Icons.arrow_forward_rounded,
                        size: 16, color: colors.onSurface.withValues(alpha: 0.3)),
                  ),
                  Expanded(
                    child: _PickerTile(
                      icon: Icons.event_rounded,
                      label: _fmtDate(_toDate),
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _toDate.isBefore(_fromDate) ? _fromDate : _toDate,
                          firstDate: _fromDate,
                          lastDate: DateTime(2030),
                        );
                        if (d != null) setState(() => _toDate = d);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _PickerTile(
                      icon: Icons.access_time_rounded,
                      label: _startTime.format(context),
                      onTap: () async {
                        final t = await showTimePicker(
                          context: context,
                          initialTime: _startTime,
                        );
                        if (t != null) setState(() => _startTime = t);
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(Icons.arrow_forward_rounded,
                        size: 16, color: colors.onSurface.withValues(alpha: 0.3)),
                  ),
                  Expanded(
                    child: _PickerTile(
                      icon: Icons.access_time_rounded,
                      label: _endTime.format(context),
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
            ],

            const SizedBox(height: 20),
            _SheetButton(
              label: 'Bloquear',
              saving: _saving,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_staffId == null) {
      ToastService.showWarning('Selecciona un empleado');
      return;
    }
    setState(() => _saving = true);
    try {
      final biz = await ref.read(currentBusinessProvider.future);
      if (biz == null) throw Exception('No business');

      // Generate one block per day in the date range
      final rows = <Map<String, dynamic>>[];
      var current = _fromDate;
      while (!current.isAfter(_toDate)) {
        final startsAt = !_showTimes
            ? DateTime(current.year, current.month, current.day, 0, 0)
            : DateTime(current.year, current.month, current.day,
                _startTime.hour, _startTime.minute);
        final endsAt = !_showTimes
            ? DateTime(current.year, current.month, current.day, 23, 59, 59)
            : DateTime(current.year, current.month, current.day,
                _endTime.hour, _endTime.minute);

        rows.add({
          'business_id': biz['id'],
          'staff_id': _staffId,
          'starts_at': startsAt.toUtc().toIso8601String(),
          'ends_at': endsAt.toUtc().toIso8601String(),
          'reason': _reason,
        });
        current = current.add(const Duration(days: 1));
      }

      await SupabaseClientService.client
          .from('staff_schedule_blocks')
          .insert(rows);

      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e, stack) {
      ToastService.showErrorWithDetails(ToastService.friendlyError(e), e, stack);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ---------------------------------------------------------------------------
// Walk-in bottom sheet
// ---------------------------------------------------------------------------

class _WalkinSheet extends ConsumerStatefulWidget {
  final DateTime initialDateTime;
  final VoidCallback onSaved;
  final String? preselectedStaffId;

  const _WalkinSheet({
    required this.initialDateTime,
    required this.onSaved,
    this.preselectedStaffId,
  });

  @override
  ConsumerState<_WalkinSheet> createState() => _WalkinSheetState();
}

class _WalkinSheetState extends ConsumerState<_WalkinSheet> {
  late DateTime _date;
  late TimeOfDay _time;
  String? _serviceId;
  String? _staffId;
  final _notesCtrl = TextEditingController();
  final _customServiceCtrl = TextEditingController();
  final _customerNameCtrl = TextEditingController();
  bool _saving = false;
  bool _isOtherService = false;
  int _customDuration = 60;
  List<String> _popularOtherNames = [];

  @override
  void initState() {
    super.initState();
    _date = widget.initialDateTime;
    _time = TimeOfDay(
      hour: widget.initialDateTime.hour,
      minute: (widget.initialDateTime.minute ~/ 5) * 5, // round to 5 min
    );
    _staffId = widget.preselectedStaffId;
    _loadPopularOtherNames();
  }

  Future<void> _loadPopularOtherNames() async {
    try {
      final biz = await ref.read(currentBusinessProvider.future);
      if (biz == null) return;
      final rows = await SupabaseClientService.client
          .from('appointments')
          .select('service_name')
          .eq('business_id', biz['id'])
          .isFilter('service_id', null)
          .not('service_name', 'is', null)
          .order('created_at', ascending: false)
          .limit(50);
      final counts = <String, int>{};
      for (final r in rows) {
        final name = (r['service_name'] as String?)?.trim() ?? '';
        if (name.isNotEmpty) counts[name] = (counts[name] ?? 0) + 1;
      }
      final sorted = counts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      if (mounted) {
        setState(() {
          _popularOtherNames = sorted.take(8).map((e) => e.key).toList();
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Calendar] Failed to load popular service names: $e');
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _customServiceCtrl.dispose();
    _customerNameCtrl.dispose();
    super.dispose();
  }

  static const _months = [
    'Ene','Feb','Mar','Abr','May','Jun',
    'Jul','Ago','Sep','Oct','Nov','Dic',
  ];

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
            Text('Agregar Cita',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                )),
            const SizedBox(height: AppConstants.paddingMD),

            // SAT compliance nudge
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFED7AA)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.account_balance_outlined, size: 18, color: Color(0xFFEA580C)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Registra todos tus clientes',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF9A3412),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'BeautyCita reporta tus ingresos al SAT mensualmente. '
                          'Los clientes atendidos fuera de BeautyCita no aparecen en tu reporte — '
                          'esto puede causar discrepancias con el SAT.\n\n'
                          'Recuerda: muebles, herramientas, gasolina y todo lo que compras '
                          'para tu negocio es 100% deducible. Registrar todo tu ingreso '
                          'te permite aprovechar al maximo tus deducciones.',
                          style: GoogleFonts.nunito(
                            fontSize: 11,
                            color: const Color(0xFFB45309),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Customer name (optional — for walk-ins without an account)
            _SheetTextField(
              controller: _customerNameCtrl,
              label: 'Nombre del cliente (opcional)',
              hint: 'Ej: Maria Garcia',
              icon: Icons.person_outline_rounded,
              maxLines: 1,
            ),
            const SizedBox(height: 12),

            // Date + Time row
            Row(
              children: [
                Expanded(
                  child: _PickerTile(
                    icon: Icons.calendar_today_rounded,
                    label: '${_date.day} ${_months[_date.month - 1]}',
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime(2026),
                        lastDate: DateTime(2030),
                      );
                      if (d != null) setState(() => _date = d);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PickerTile(
                    icon: Icons.access_time_rounded,
                    label: _time.format(context),
                    onTap: () async {
                      final t = await showTimePicker(
                        context: context,
                        initialTime: _time,
                      );
                      if (t != null) setState(() => _time = t);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.paddingSM),

            // Service dropdown
            servicesAsync.when(
              data: (services) => _SheetDropdown<String>(
                label: 'Servicio',
                icon: Icons.content_cut_rounded,
                value: _isOtherService ? '__other__' : _serviceId,
                hint: 'Selecciona servicio',
                items: [
                  ...services.map((s) {
                    return DropdownMenuItem(
                      value: s['id'] as String,
                      child: Text(
                        '${s['name']} (\$${(s['price'] as num?)?.toStringAsFixed(0) ?? '0'})',
                        style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    );
                  }),
                  DropdownMenuItem(
                    value: '__other__',
                    child: Text(
                      'Otro...',
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
                onChanged: (v) {
                  setState(() {
                    if (v == '__other__') {
                      _isOtherService = true;
                      _serviceId = null;
                    } else {
                      _isOtherService = false;
                      _serviceId = v;
                      _customServiceCtrl.clear();
                    }
                  });
                },
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, st) => Text('Error: $e'),
            ),

            // Custom service name + duration when "Otro" selected
            if (_isOtherService) ...[
              const SizedBox(height: 8),
              _SheetTextField(
                controller: _customServiceCtrl,
                label: 'Nombre del servicio',
                hint: 'Ej: Trenza, Tinte, Unas...',
                icon: Icons.edit_rounded,
                maxLines: 1,
              ),
              if (_popularOtherNames.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: _popularOtherNames.map((name) {
                    final selected = _customServiceCtrl.text.trim() == name;
                    return GestureDetector(
                      onTap: () => setState(() {
                        _customServiceCtrl.text = name;
                        _customServiceCtrl.selection = TextSelection.fromPosition(
                          TextPosition(offset: name.length),
                        );
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: selected
                              ? colors.primary.withValues(alpha: 0.15)
                              : colors.onSurface.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(16),
                          border: selected
                              ? Border.all(color: colors.primary.withValues(alpha: 0.4))
                              : null,
                        ),
                        child: Text(
                          name,
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                            color: selected ? colors.primary : colors.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 8),
              _SheetDropdown<int>(
                label: 'Duracion',
                icon: Icons.timer_outlined,
                value: _customDuration,
                hint: 'Duracion',
                items: [30, 45, 60, 90, 120].map((m) {
                  return DropdownMenuItem(
                    value: m,
                    child: Text(
                      '$m min',
                      style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _customDuration = v);
                },
              ),
            ],
            const SizedBox(height: 12),

            // Staff dropdown
            staffAsync.when(
              data: (staff) {
                final allStaff = <Map<String, dynamic>>[];
                final biz = bizAsync.valueOrNull;
                final wiOwnerId = biz?['owner_id'] as String?;
                if (biz != null && !_ownerHasStaffRecord(wiOwnerId, staff)) {
                  allStaff.add({
                    'id': biz['owner_id'],
                    'first_name': 'Yo',
                    'last_name': '(Dueno)',
                  });
                }
                allStaff.addAll(staff);
                return _SheetDropdown<String>(
                  label: 'Estilista',
                  icon: Icons.person_rounded,
                  value: _staffId,
                  hint: 'Selecciona estilista',
                  items: allStaff.map((s) {
                    return DropdownMenuItem(
                      value: s['id'] as String,
                      child: Text(
                        '${s['first_name']} ${s['last_name'] ?? ''}'.trim(),
                        style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _staffId = v),
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (e, st) => Text('Error: $e'),
            ),
            const SizedBox(height: 12),

            // Notes
            _SheetTextField(
              controller: _notesCtrl,
              label: 'Notas (opcional)',
              hint: 'Ej: Walk-in, pago en efectivo...',
              icon: Icons.sticky_note_2_outlined,
              maxLines: 2,
            ),

            const SizedBox(height: 20),
            _SheetButton(
              label: 'Agregar Cita',
              saving: _saving,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_isOtherService && _serviceId == null) {
      ToastService.showWarning('Selecciona un servicio');
      return;
    }
    if (_isOtherService && _customServiceCtrl.text.trim().isEmpty) {
      ToastService.showWarning('Escribe el nombre del servicio');
      return;
    }
    setState(() => _saving = true);
    try {
      final biz = await ref.read(currentBusinessProvider.future);
      if (biz == null) throw Exception('No business');

      int duration;
      double price;
      String serviceName;

      if (_isOtherService) {
        duration = _customDuration;
        price = 0;
        serviceName = _customServiceCtrl.text.trim();
      } else {
        final services = await ref.read(businessServicesProvider.future);
        final service = services.firstWhere((s) => s['id'] == _serviceId);
        duration = service['duration_minutes'] as int? ?? 60;
        price = (service['price'] as num?)?.toDouble() ?? 0;
        serviceName = service['name'] as String;
      }

      final startsAt = DateTime(
          _date.year, _date.month, _date.day, _time.hour, _time.minute);
      final endsAt = startsAt.add(Duration(minutes: duration));

      // Prevent past date walk-ins (15 min grace period)
      if (startsAt.isBefore(DateTime.now().subtract(const Duration(minutes: 15)))) {
        ToastService.showWarning('No puedes crear citas en el pasado');
        return;
      }

      // Check for overlapping appointments on the same staff member
      if (_staffId != null) {
        final conflicts = await SupabaseClientService.client
            .from('appointments')
            .select('id')
            .eq('staff_id', _staffId!)
            .not('status', 'in', '(cancelled_customer,cancelled_business)')
            .lt('starts_at', endsAt.toUtc().toIso8601String())
            .gt('ends_at', startsAt.toUtc().toIso8601String());
        if ((conflicts as List).isNotEmpty) {
          ToastService.showWarning('Este horario ya tiene una cita programada');
          return;
        }
      }

      final data = <String, dynamic>{
        'business_id': biz['id'],
        'service_name': serviceName,
        'staff_id': _staffId,
        'starts_at': startsAt.toUtc().toIso8601String(),
        'ends_at': endsAt.toUtc().toIso8601String(),
        'price': price,
        'status': 'confirmed',
        'payment_method': 'cash_direct',
        'payment_status': 'paid',
      };
      if (!_isOtherService) data['service_id'] = _serviceId;
      final customerName = _customerNameCtrl.text.trim();
      if (customerName.isNotEmpty) data['customer_name'] = customerName;
      final notes = _notesCtrl.text.trim();
      if (notes.isNotEmpty) data['notes'] = notes;

      await SupabaseClientService.client.from('appointments').insert(data);

      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e, stack) {
      ToastService.showErrorWithDetails(ToastService.friendlyError(e), e, stack);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// Reusable picker tile for date/time selection
class _PickerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PickerTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: colors.onSurface.withValues(alpha: 0.15)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: colors.primary),
            const SizedBox(width: 8),
            Text(label,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: colors.onSurface,
                )),
          ],
        ),
      ),
    );
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
        DateTime.tryParse(widget.appointment['starts_at'] as String? ?? '')?.toLocal();
    _newDate = startsAt ?? DateTime.now();
    _newTime = startsAt != null
        ? TimeOfDay(hour: startsAt.hour, minute: startsAt.minute)
        : TimeOfDay.now();
  }

  static const _months = [
    'Ene','Feb','Mar','Abr','May','Jun',
    'Jul','Ago','Sep','Oct','Nov','Dic',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20, 20, 20,
        MediaQuery.of(context).viewInsets.bottom + 20,
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
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _PickerTile(
                  icon: Icons.calendar_today_rounded,
                  label: '${_newDate.day} ${_months[_newDate.month - 1]}',
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _newDate,
                      firstDate: DateTime(2026),
                      lastDate: DateTime(2030),
                    );
                    if (d != null) setState(() => _newDate = d);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PickerTile(
                  icon: Icons.access_time_rounded,
                  label: _newTime.format(context),
                  onTap: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: _newTime,
                    );
                    if (t != null) setState(() => _newTime = t);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SheetButton(
            label: 'Reprogramar',
            saving: _saving,
            onPressed: _saving ? null : _save,
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
        'starts_at': newStart.toUtc().toIso8601String(),
        'ends_at': newEnd.toUtc().toIso8601String(),
      }).eq('id', id);

      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e, stack) {
      ToastService.showErrorWithDetails(ToastService.friendlyError(e), e, stack);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ---------------------------------------------------------------------------
// Edit Appointment Sheet — change staff assignment + notes on any appointment
// ---------------------------------------------------------------------------
class _EditApptSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> appointment;
  final VoidCallback onSaved;
  const _EditApptSheet({
    required this.appointment,
    required this.onSaved,
  });

  @override
  ConsumerState<_EditApptSheet> createState() => _EditApptSheetState();
}

class _EditApptSheetState extends ConsumerState<_EditApptSheet> {
  String? _selectedStaffId;
  late TextEditingController _notesCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedStaffId = widget.appointment['staff_id'] as String?;
    _notesCtrl = TextEditingController(
      text: widget.appointment['notes'] as String? ?? '',
    );
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final staffAsync = ref.watch(businessStaffProvider);
    final bizAsync = ref.watch(currentBusinessProvider);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20, 20, 20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Editar Cita',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              )),
          const SizedBox(height: 16),
          // Staff picker
          staffAsync.when(
            data: (staff) {
              final allStaff = <Map<String, dynamic>>[];
              final biz = bizAsync.valueOrNull;
              final editOwnerId = biz?['owner_id'] as String?;
              if (biz != null && !_ownerHasStaffRecord(editOwnerId, staff)) {
                allStaff.add({
                  'id': biz['owner_id'],
                  'first_name': 'Yo',
                  'last_name': '(Dueno)',
                });
              }
              allStaff.addAll(staff);
              return _SheetDropdown<String>(
                label: 'Empleado asignado',
                icon: Icons.person_rounded,
                value: allStaff.any((s) => s['id'] == _selectedStaffId)
                    ? _selectedStaffId
                    : null,
                hint: 'Seleccionar',
                items: allStaff
                    .map((s) => DropdownMenuItem<String>(
                          value: s['id'] as String,
                          child: Text(
                            '${s['first_name']} ${s['last_name'] ?? ''}'.trim(),
                            style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedStaffId = v),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
          ),
          const SizedBox(height: 12),
          // Notes
          _SheetTextField(
            controller: _notesCtrl,
            label: 'Notas',
            hint: 'Observaciones, cambios...',
            icon: Icons.note_rounded,
            maxLines: 3,
          ),
          const SizedBox(height: 20),
          _SheetButton(
            label: 'Guardar cambios',
            saving: _saving,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final id = widget.appointment['id'] as String;
      final updates = <String, dynamic>{};
      if (_selectedStaffId != null &&
          _selectedStaffId != widget.appointment['staff_id']) {
        updates['staff_id'] = _selectedStaffId;
      }
      final newNotes = _notesCtrl.text.trim();
      if (newNotes != (widget.appointment['notes'] as String? ?? '')) {
        updates['notes'] = newNotes.isEmpty ? null : newNotes;
      }
      if (updates.isNotEmpty) {
        await SupabaseClientService.client
            .from('appointments')
            .update(updates)
            .eq('id', id);
      }
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e, stack) {
      ToastService.showErrorWithDetails(ToastService.friendlyError(e), e, stack);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ---------------------------------------------------------------------------
// Notes Sheet — inline note editing for appointments
// ---------------------------------------------------------------------------
class _NotesSheet extends StatefulWidget {
  final Map<String, dynamic> appointment;
  final VoidCallback onSaved;
  const _NotesSheet({required this.appointment, required this.onSaved});

  @override
  State<_NotesSheet> createState() => _NotesSheetState();
}

class _NotesSheetState extends State<_NotesSheet> {
  late TextEditingController _ctrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: widget.appointment['notes'] as String? ?? '',
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20, 20, 20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Nota',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              )),
          const SizedBox(height: 16),
          _SheetTextField(
            controller: _ctrl,
            label: 'Nota',
            hint: 'Escribe una nota...',
            icon: Icons.sticky_note_2_outlined,
            maxLines: 4,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if ((widget.appointment['notes'] as String?)?.isNotEmpty == true)
                TextButton(
                  onPressed: _saving
                      ? null
                      : () {
                          _ctrl.clear();
                          _save();
                        },
                  child: Text('Borrar',
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.error,
                      )),
                ),
              const Spacer(),
              SizedBox(
                width: 140,
                child: _SheetButton(
                  label: 'Guardar',
                  saving: _saving,
                  onPressed: _saving ? null : _save,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final id = widget.appointment['id'] as String;
      final notes = _ctrl.text.trim();
      await SupabaseClientService.client
          .from('appointments')
          .update({'notes': notes.isEmpty ? null : notes}).eq('id', id);
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e, stack) {
      ToastService.showErrorWithDetails(ToastService.friendlyError(e), e, stack);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ===========================================================================
// Reusable styled sheet widgets — consistent across all bottom sheets
// ===========================================================================

/// Styled dropdown with container, border, shadow, prefix icon
class _SheetDropdown<T> extends StatelessWidget {
  final String label;
  final IconData icon;
  final T? value;
  final String? hint;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _SheetDropdown({
    required this.label,
    required this.icon,
    this.value,
    this.hint,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.primary.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonFormField<T>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: colors.onSurface.withValues(alpha: 0.5),
          ),
          hintText: hint,
          hintStyle: GoogleFonts.nunito(
            fontSize: 14,
            color: colors.onSurface.withValues(alpha: 0.35),
          ),
          prefixIcon: Icon(icon, size: 20, color: colors.primary.withValues(alpha: 0.6)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
        items: items,
        onChanged: onChanged,
        dropdownColor: Colors.white,
        icon: Icon(Icons.keyboard_arrow_down_rounded,
            size: 20, color: colors.onSurface.withValues(alpha: 0.4)),
      ),
    );
  }
}

/// Styled text field with container, border, shadow, prefix icon
class _SheetTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData icon;
  final int maxLines;
  const _SheetTextField({
    required this.controller,
    required this.label,
    this.hint,
    required this.icon,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.primary.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        textCapitalization: TextCapitalization.sentences,
        style: GoogleFonts.nunito(fontSize: 14, color: const Color(0xFF212121)),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: colors.onSurface.withValues(alpha: 0.5),
          ),
          hintText: hint,
          hintStyle: GoogleFonts.nunito(
            fontSize: 14,
            color: colors.onSurface.withValues(alpha: 0.35),
          ),
          prefixIcon: Icon(icon, size: 20, color: colors.primary.withValues(alpha: 0.6)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }
}

/// Styled gradient button for sheet actions
class _SheetButton extends StatelessWidget {
  final String label;
  final bool saving;
  final VoidCallback? onPressed;

  const _SheetButton({
    required this.label,
    this.saving = false,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final enabled = onPressed != null && !saving;
    return AnimatedOpacity(
      opacity: enabled ? 1.0 : 0.5,
      duration: const Duration(milliseconds: 200),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: enabled
              ? LinearGradient(
                  colors: [colors.primary, const Color(0xFF990033)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          color: enabled ? null : const Color(0xFFE0E0E0),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        label,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: enabled ? Colors.white : const Color(0xFF9E9E9E),
                          letterSpacing: 0.3,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
