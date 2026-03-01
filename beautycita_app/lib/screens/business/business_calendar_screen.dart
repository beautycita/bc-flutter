import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/constants.dart';
import '../../providers/business_provider.dart';
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

class _BusinessCalendarScreenState
    extends ConsumerState<BusinessCalendarScreen> {
  final _timelineKey = GlobalKey<_HorizontalTimelineState>();
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
      (start: range.start.toUtc().toIso8601String(), end: range.end.toUtc().toIso8601String()),
    ));
    final blocksAsync = ref.watch(businessScheduleBlocksProvider(
      (start: range.start.toUtc().toIso8601String(), end: range.end.toUtc().toIso8601String()),
    ));
    final staffAsync = ref.watch(businessStaffProvider);
    final bizAsync = ref.watch(currentBusinessProvider);
    final ownerId = bizAsync.valueOrNull?['owner_id'] as String?;

    return Column(
      children: [
        // Summary card
        if (!_weekView)
          _SummaryCard(
            date: _selectedDate,
            apptsAsync: apptsAsync,
            staffAsync: staffAsync,
            ownerId: ownerId,
            onPickDate: _pickDate,
            onAddNew: () {
              final visibleTime = _timelineKey.currentState?.getVisibleDateTime();
              _showWalkinSheet(context, visibleTime);
            },
          ),

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
              : _HorizontalTimeline(
                  key: _timelineKey,
                  date: _selectedDate,
                  apptsAsync: apptsAsync,
                  blocksAsync: blocksAsync,
                  staffAsync: staffAsync,
                  staffFilter: _staffFilter,
                  ownerId: ownerId,
                  onAction: _handleAction,
                  onBlockTime: () => _showBlockTimeSheet(context),
                  onRefresh: _refresh,
                  onLongPressLane: (staffId, time) =>
                      _showQuickNoteSheet(context, staffId, time),
                ),
        ),
      ],
    );
  }

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

    showModalBottomSheet(
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _WalkinSheet(
        initialDateTime: time,
        onSaved: _refresh,
        preselectedStaffId: preselectedStaffId,
      ),
    );
  }

  void _showQuickNoteSheet(BuildContext context, String staffId, DateTime time) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _QuickNoteSheet(
        staffId: staffId,
        dateTime: time,
        onSaved: _refresh,
      ),
    );
  }

  void _showEditSheet(BuildContext context, Map<String, dynamic> appt) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _EditApptSheet(
        appointment: appt,
        onSaved: _refresh,
      ),
    );
  }

  void _showNotesSheet(BuildContext context, Map<String, dynamic> appt) {
    showModalBottomSheet(
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
// Summary card — appointment total, date, staff chips
// ---------------------------------------------------------------------------

class _SummaryCard extends StatelessWidget {
  final DateTime date;
  final AsyncValue<List<Map<String, dynamic>>> apptsAsync;
  final AsyncValue<List<Map<String, dynamic>>> staffAsync;
  final String? ownerId;
  final VoidCallback onPickDate;
  final VoidCallback onAddNew;

  const _SummaryCard({
    required this.date,
    required this.apptsAsync,
    required this.staffAsync,
    required this.ownerId,
    required this.onPickDate,
    required this.onAddNew,
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

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppConstants.paddingMD, AppConstants.paddingSM,
        AppConstants.paddingMD, 0,
      ),
      padding: const EdgeInsets.all(AppConstants.paddingMD),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Citas',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: colors.onSurface.withValues(alpha: 0.5),
                        )),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text('${appts.length}',
                            style: GoogleFonts.poppins(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF212121),
                            )),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: onPickDate,
                          child: Text(
                            'Hoy, ${date.day} ${_months[date.month - 1]} \u25BC',
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              color: colors.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: onAddNew,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text('Agregar',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    )),
                style: TextButton.styleFrom(
                  foregroundColor: colors.primary,
                ),
              ),
            ],
          ),
          if (allStaff.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                for (var i = 0; i < allStaff.length; i++)
                  _StaffChip(
                    name: allStaff[i].name,
                    count: allStaff[i].count,
                    color: _staffColor(i),
                  ),
              ],
            ),
          ],
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
  final VoidCallback onRefresh;
  final void Function(String staffId, DateTime time)? onLongPressLane;

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
    required this.onRefresh,
    this.onLongPressLane,
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
                    child: SizedBox(
                      width: _totalWidth,
                      child: Column(
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
                              onLongPress: widget.onLongPressLane == null
                                  ? null
                                  : (staffId, time) {
                                      // Replace hour/minute on the widget date
                                      final dt = DateTime(
                                        widget.date.year,
                                        widget.date.month,
                                        widget.date.day,
                                        time.hour,
                                        time.minute,
                                      );
                                      widget.onLongPressLane!(staffId, dt);
                                    },
                            ),
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
        // FAB for blocking time
        Positioned(
          right: AppConstants.paddingMD,
          bottom: AppConstants.paddingMD,
          child: FloatingActionButton.small(
            heroTag: 'blockTime',
            onPressed: widget.onBlockTime,
            child: const Icon(Icons.block_rounded, size: 20),
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
  final void Function(String staffId, DateTime time)? onLongPress;

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
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final staffColor = _staffColor(laneIndex);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPressStart: onLongPress == null
          ? null
          : (details) {
              final localX = details.localPosition.dx;
              final minutesSinceStart = (localX / hourWidth) * 60;
              final totalMinutes = minutesSinceStart.round();
              final hour = (startHour + totalMinutes ~/ 60).clamp(startHour, endHour - 1);
              final minute = ((totalMinutes % 60) ~/ 5) * 5;
              final now = DateTime.now();
              final time = DateTime(now.year, now.month, now.day, hour, minute);
              onLongPress!(lane.id, time);
            },
      child: Container(
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

    showModalBottomSheet(
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

    return Positioned(
      left: left,
      top: 4,
      height: laneHeight - 8,
      width: width,
      child: GestureDetector(
        onTap: () => _showApptActionSheet(context, appt, onAction),
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

  showModalBottomSheet(
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
      case 'pending': return const Color(0xFFF48FB1);   // Pastel pink
      case 'confirmed': return const Color(0xFFCE93D8); // Pastel purple
      case 'completed': return const Color(0xFFA5D6A7); // Pastel green
      default: return const Color(0xFFE0E0E0);
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
  bool get _isDateRange => _reason == 'vacation' || _reason == 'other';
  bool get _showTimes => _reason == 'lunch' || _reason == 'other';
  bool get _isSingleDate => _reason == 'day_off' || _reason == 'lunch';

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
    } catch (_) {}
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _customServiceCtrl.dispose();
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

      final data = <String, dynamic>{
        'business_id': biz['id'],
        'service_name': serviceName,
        'staff_id': _staffId,
        'starts_at': startsAt.toUtc().toIso8601String(),
        'ends_at': endsAt.toUtc().toIso8601String(),
        'price': price,
        'status': 'confirmed',
      };
      if (!_isOtherService) data['service_id'] = _serviceId;
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
// Quick Note Sheet — long-press to create a note pegged to time/staff
// ---------------------------------------------------------------------------

class _QuickNoteSheet extends ConsumerStatefulWidget {
  final String staffId;
  final DateTime dateTime;
  final VoidCallback onSaved;

  const _QuickNoteSheet({
    required this.staffId,
    required this.dateTime,
    required this.onSaved,
  });

  @override
  ConsumerState<_QuickNoteSheet> createState() => _QuickNoteSheetState();
}

class _QuickNoteSheetState extends ConsumerState<_QuickNoteSheet> {
  final _ctrl = TextEditingController();
  bool _saving = false;

  static const _months = [
    'Ene','Feb','Mar','Abr','May','Jun',
    'Jul','Ago','Sep','Oct','Nov','Dic',
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dt = widget.dateTime;
    final timeLabel =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    final dateLabel = '${dt.day} ${_months[dt.month - 1]}';

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20, 20, 20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.sticky_note_2_rounded,
                  size: 20, color: colors.primary),
              const SizedBox(width: 8),
              Text('Nota Rapida',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                  )),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.onSurface.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$dateLabel  $timeLabel',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SheetTextField(
            controller: _ctrl,
            label: 'Nota',
            hint: 'Ej: Cliente llama para confirmar, traer producto X...',
            icon: Icons.edit_note_rounded,
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          _SheetButton(
            label: 'Guardar Nota',
            saving: _saving,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) {
      ToastService.showWarning('Escribe algo');
      return;
    }
    setState(() => _saving = true);
    try {
      final biz = await ref.read(currentBusinessProvider.future);
      if (biz == null) throw Exception('No business');

      final startsAt = widget.dateTime;
      // Note block: 15 min duration, just a visual marker
      final endsAt = startsAt.add(const Duration(minutes: 15));

      await SupabaseClientService.client.from('staff_schedule_blocks').insert({
        'business_id': biz['id'],
        'staff_id': widget.staffId,
        'starts_at': startsAt.toUtc().toIso8601String(),
        'ends_at': endsAt.toUtc().toIso8601String(),
        'reason': 'note',
        'note': text,
      });

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
        value: value,
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
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;

  const _SheetTextField({
    required this.controller,
    required this.label,
    this.hint,
    required this.icon,
    this.maxLines = 1,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.sentences,
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
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
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
