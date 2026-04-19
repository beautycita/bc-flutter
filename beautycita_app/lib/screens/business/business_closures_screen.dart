import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita/config/fonts.dart';
import 'package:intl/intl.dart';
import '../../providers/business_provider.dart';
import 'package:beautycita_core/supabase.dart';
import '../../services/supabase_client.dart';
import '../../services/toast_service.dart';
import 'business_shell_screen.dart' show businessTabProvider;

// Staff member entry for closure picker: null id = whole salon
class _StaffOption {
  final String? id;
  final String name;
  const _StaffOption({this.id, required this.name});
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final businessClosuresProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, bizId) async {
  final data = await SupabaseClientService.client
      .from(BCTables.businessClosures)
      .select('*, staff:staff_id(id, first_name, last_name)')
      .eq('business_id', bizId)
      .gte('closure_date', DateTime.now().subtract(const Duration(days: 30)).toIso8601String().substring(0, 10))
      .order('closure_date');
  return (data as List).cast<Map<String, dynamic>>();
});

// ---------------------------------------------------------------------------
// Mexican Holiday helpers
// ---------------------------------------------------------------------------

class _MexicanHoliday {
  final String name;
  final DateTime date;
  final bool isMovable; // puente-eligible movable holidays

  const _MexicanHoliday({
    required this.name,
    required this.date,
    this.isMovable = false,
  });
}

/// Compute Easter Sunday for a given year using the Anonymous Gregorian algorithm.
DateTime _easterSunday(int year) {
  final a = year % 19;
  final b = year ~/ 100;
  final c = year % 100;
  final d = b ~/ 4;
  final e = b % 4;
  final f = (b + 8) ~/ 25;
  final g = (b - f + 1) ~/ 3;
  final h = (19 * a + b - d - g + 15) % 30;
  final i = c ~/ 4;
  final k = c % 4;
  final l = (32 + 2 * e + 2 * i - h - k) % 7;
  final m = (a + 11 * h + 22 * l) ~/ 451;
  final month = (h + l - 7 * m + 114) ~/ 31;
  final day = ((h + l - 7 * m + 114) % 31) + 1;
  return DateTime(year, month, day);
}

/// Nth weekday of a month (e.g., 1st Monday of Feb, 3rd Monday of Mar).
DateTime _nthWeekdayOfMonth(int year, int month, int weekday, int n) {
  var d = DateTime(year, month, 1);
  // Advance to first occurrence of weekday
  while (d.weekday != weekday) {
    d = d.add(const Duration(days: 1));
  }
  // Advance to nth occurrence
  d = d.add(Duration(days: 7 * (n - 1)));
  return d;
}

/// Returns all Mexican holidays for the given year.
List<_MexicanHoliday> _mexicanHolidays(int year) {
  final easter = _easterSunday(year);
  final juevesSanto = easter.subtract(const Duration(days: 3));
  final viernesSanto = easter.subtract(const Duration(days: 2));

  return [
    _MexicanHoliday(name: 'Ano Nuevo', date: DateTime(year, 1, 1)),
    _MexicanHoliday(
      name: 'Dia de la Constitucion',
      date: _nthWeekdayOfMonth(year, 2, DateTime.monday, 1),
      isMovable: true,
    ),
    _MexicanHoliday(
      name: 'Natalicio de Benito Juarez',
      date: _nthWeekdayOfMonth(year, 3, DateTime.monday, 3),
      isMovable: true,
    ),
    _MexicanHoliday(name: 'Jueves Santo', date: juevesSanto),
    _MexicanHoliday(name: 'Viernes Santo', date: viernesSanto),
    _MexicanHoliday(name: 'Dia del Trabajo', date: DateTime(year, 5, 1)),
    _MexicanHoliday(name: 'Dia de las Madres', date: DateTime(year, 5, 10)),
    _MexicanHoliday(name: 'Dia de la Independencia', date: DateTime(year, 9, 16)),
    _MexicanHoliday(
      name: 'Dia de la Raza',
      date: _nthWeekdayOfMonth(year, 10, DateTime.monday, 2),
      isMovable: true,
    ),
    _MexicanHoliday(name: 'Dia de Muertos', date: DateTime(year, 11, 2)),
    _MexicanHoliday(
      name: 'Revolucion Mexicana',
      date: _nthWeekdayOfMonth(year, 11, DateTime.monday, 3),
      isMovable: true,
    ),
    _MexicanHoliday(name: 'Dia de la Virgen de Guadalupe', date: DateTime(year, 12, 12)),
    _MexicanHoliday(name: 'Navidad', date: DateTime(year, 12, 25)),
    _MexicanHoliday(name: 'Fin de Ano', date: DateTime(year, 12, 31)),
  ];
}

/// Check if a holiday on Tuesday has a "puente" (bridge) opportunity on Monday.
bool _hasPuente(_MexicanHoliday h) {
  return h.date.weekday == DateTime.tuesday;
}

String _dateKey(DateTime d) => d.toIso8601String().substring(0, 10);

// ---------------------------------------------------------------------------
// Screen — shows as a section in Business Settings or standalone
// ---------------------------------------------------------------------------

class BusinessClosuresSection extends ConsumerStatefulWidget {
  const BusinessClosuresSection({super.key});

  @override
  ConsumerState<BusinessClosuresSection> createState() => _BusinessClosuresSectionState();
}

class _BusinessClosuresSectionState extends ConsumerState<BusinessClosuresSection> {
  final _dateFmt = DateFormat('EEEE d MMM yyyy', 'es');
  final _shortDateFmt = DateFormat('d \'de\' MMMM', 'es');
  bool _holidaysExpanded = true;
  bool _vacationExpanded = false;

  // Staff selector — null means whole salon
  _StaffOption _selectedStaff = const _StaffOption(id: null, name: 'Todo el salon');

  // Vacation state
  DateTime? _vacStart;
  DateTime? _vacEnd;
  final _vacReasonCtrl = TextEditingController(text: 'Vacaciones');
  bool _vacLoading = false;

  @override
  void dispose() {
    _vacReasonCtrl.dispose();
    super.dispose();
  }

  // ------ Conflict checker (shared) ------

  /// Returns count of conflicting appointments on a given date.
  /// When a specific staff member is selected, only counts their appointments.
  Future<int> _countConflicts(String bizId, String dateStr) async {
    try {
      var query = SupabaseClientService.client
          .from(BCTables.appointments)
          .select('id')
          .eq('business_id', bizId)
          .gte('starts_at', '${dateStr}T00:00:00')
          .lte('starts_at', '${dateStr}T23:59:59')
          .inFilter('status', ['pending', 'confirmed']);
      if (_selectedStaff.id != null) {
        query = query.eq('staff_id', _selectedStaff.id!);
      }
      final conflicts = await query;
      return (conflicts as List).length;
    } catch (e) {
      debugPrint('Conflict check error: $e');
      return 0;
    }
  }

  /// Show conflict warning. Returns true if user resolves or force-proceeds.
  /// Offers to open the calendar so the salon owner can drag-and-drop reschedule.
  Future<bool> _confirmConflicts(int count) async {
    if (count == 0) return true;
    final staffLabel = _selectedStaff.id != null ? _selectedStaff.name : 'el salon';
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Citas por reagendar', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text(
          '$staffLabel tiene $count cita(s) confirmada(s) ese dia. '
          'Reagendalas en el calendario antes de cerrar.',
          style: GoogleFonts.nunito(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, 'calendar'),
            icon: const Icon(Icons.calendar_month, size: 18),
            label: const Text('Abrir calendario'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'force'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Cerrar de todos modos'),
          ),
        ],
      ),
    );
    if (result == 'calendar') {
      // Navigate to calendar tab (index 1) so they can reschedule
      ref.read(businessTabProvider.notifier).state = 1;
      ToastService.showInfo('Reagenda las citas y vuelve a intentar el cierre');
      return false;
    }
    return result == 'force';
  }

  // ------ Holiday toggle ------

  Future<void> _toggleHoliday(
    String bizId,
    _MexicanHoliday holiday,
    bool shouldClose,
    List<Map<String, dynamic>> closures,
  ) async {
    final dateStr = _dateKey(holiday.date);

    if (shouldClose) {
      // Check conflicts first
      final conflicts = await _countConflicts(bizId, dateStr);
      if (!mounted) return;
      if (!await _confirmConflicts(conflicts)) return;

      try {
        await SupabaseClientService.client.from(BCTables.businessClosures).insert({
          'business_id': bizId,
          'closure_date': dateStr,
          'reason': holiday.name,
          'all_day': true,
          if (_selectedStaff.id != null) 'staff_id': _selectedStaff.id,
        });
        ref.invalidate(businessClosuresProvider(bizId));
        ToastService.showSuccess('${holiday.name} — Cerrado');
      } catch (e) {
        if (e.toString().contains('duplicate') || e.toString().contains('unique')) {
          ToastService.showWarning('Ya existe un cierre para esa fecha');
        } else {
          ToastService.showError('Error: $e');
        }
      }
    } else {
      // Find the closure row and delete it
      final match = closures.where((c) => c['closure_date'] == dateStr).toList();
      if (match.isNotEmpty) {
        try {
          await SupabaseClientService.client
              .from(BCTables.businessClosures)
              .delete()
              .eq('id', match.first['id'] as String);
          ref.invalidate(businessClosuresProvider(bizId));
          ToastService.showSuccess('${holiday.name} — Abierto');
        } catch (e) {
          ToastService.showError('Error: $e');
        }
      }
    }
  }

  // ------ Vacation range insert ------

  Future<void> _addVacationRange(String bizId) async {
    if (_vacStart == null || _vacEnd == null) {
      ToastService.showWarning('Selecciona fecha de inicio y fin');
      return;
    }
    if (_vacEnd!.isBefore(_vacStart!)) {
      ToastService.showWarning('La fecha de fin no puede ser antes del inicio');
      return;
    }

    final reason = _vacReasonCtrl.text.trim().isEmpty ? 'Vacaciones' : _vacReasonCtrl.text.trim();
    final days = _vacEnd!.difference(_vacStart!).inDays + 1;

    if (days > 60) {
      ToastService.showWarning('Maximo 60 dias de vacaciones a la vez');
      return;
    }

    // Check for conflicts across the range
    int totalConflicts = 0;
    for (var i = 0; i < days; i++) {
      final d = _vacStart!.add(Duration(days: i));
      totalConflicts += await _countConflicts(bizId, _dateKey(d));
    }
    if (!mounted) return;
    if (totalConflicts > 0) {
      final staffLabel = _selectedStaff.id != null ? _selectedStaff.name : 'el salon';
      final result = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Citas por reagendar', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
          content: Text(
            '$staffLabel tiene $totalConflicts cita(s) confirmada(s) en ese rango. '
            'Reagendalas en el calendario antes de cerrar.',
            style: GoogleFonts.nunito(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, 'calendar'),
              icon: const Icon(Icons.calendar_month, size: 18),
              label: const Text('Abrir calendario'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'force'),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Cerrar de todos modos'),
            ),
          ],
        ),
      );
      if (result == 'calendar') {
        ref.read(businessTabProvider.notifier).state = 1;
        ToastService.showInfo('Reagenda las citas y vuelve a intentar el cierre');
        return;
      }
      if (result != 'force' || !mounted) return;
    }

    setState(() => _vacLoading = true);

    try {
      // Batch insert — one row per day
      final rows = <Map<String, dynamic>>[];
      for (var i = 0; i < days; i++) {
        final d = _vacStart!.add(Duration(days: i));
        rows.add({
          'business_id': bizId,
          'closure_date': _dateKey(d),
          'reason': reason,
          'all_day': true,
          if (_selectedStaff.id != null) 'staff_id': _selectedStaff.id,
        });
      }
      await SupabaseClientService.client.from(BCTables.businessClosures).upsert(rows);
      ref.invalidate(businessClosuresProvider(bizId));
      ToastService.showSuccess('$days dias de vacaciones agregados');
      setState(() {
        _vacStart = null;
        _vacEnd = null;
        _vacReasonCtrl.text = 'Vacaciones';
        _vacationExpanded = false;
      });
    } catch (e) {
      ToastService.showError('Error: $e');
    } finally {
      if (mounted) setState(() => _vacLoading = false);
    }
  }

  // ------ Manual one-off closure (original) ------

  Future<void> _addClosure(String bizId) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      locale: const Locale('es', 'MX'),
    );
    if (picked == null || !mounted) return;

    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        String r = '';
        return AlertDialog(
          title: Text('Razon del cierre', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
          content: TextField(
            autofocus: true,
            onChanged: (v) => r = v,
            decoration: InputDecoration(
              hintText: 'Mantenimiento, dia personal...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, r), child: const Text('Agregar')),
          ],
        );
      },
    );
    if (reason == null || !mounted) return;

    try {
      final dateStr = _dateKey(picked);
      final conflicts = await _countConflicts(bizId, dateStr);
      if (!mounted) return;
      if (!await _confirmConflicts(conflicts)) return;

      await SupabaseClientService.client.from(BCTables.businessClosures).insert({
        'business_id': bizId,
        'closure_date': dateStr,
        'reason': reason.trim().isEmpty ? null : reason.trim(),
        'all_day': true,
        if (_selectedStaff.id != null) 'staff_id': _selectedStaff.id,
      });
      ref.invalidate(businessClosuresProvider(bizId));
      ToastService.showSuccess('Cierre agregado');
    } catch (e) {
      if (e.toString().contains('duplicate') || e.toString().contains('unique')) {
        ToastService.showWarning('Ya existe un cierre para esa fecha');
      } else {
        ToastService.showError('Error: $e');
      }
    }
  }

  Future<void> _deleteClosure(String bizId, String closureId) async {
    try {
      await SupabaseClientService.client.from(BCTables.businessClosures).delete().eq('id', closureId);
      ref.invalidate(businessClosuresProvider(bizId));
      ToastService.showSuccess('Cierre eliminado');
    } catch (e) {
      ToastService.showError('Error: $e');
    }
  }

  // ------ Date picker helpers ------

  Future<void> _pickVacStart() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _vacStart ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      locale: const Locale('es', 'MX'),
    );
    if (picked != null && mounted) {
      setState(() {
        _vacStart = picked;
        // Auto-set end to start + 14 days
        _vacEnd = picked.add(const Duration(days: 13));
      });
    }
  }

  Future<void> _pickVacEnd() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _vacEnd ?? (_vacStart ?? now).add(const Duration(days: 13)),
      firstDate: _vacStart ?? now,
      lastDate: now.add(const Duration(days: 365)),
      locale: const Locale('es', 'MX'),
    );
    if (picked != null && mounted) {
      setState(() => _vacEnd = picked);
    }
  }

  // ------ BUILD ------

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bizAsync = ref.watch(currentBusinessProvider);

    return bizAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (biz) {
        if (biz == null) return const SizedBox.shrink();
        final bizId = biz['id'] as String;
        final closuresAsync = ref.watch(businessClosuresProvider(bizId));

        return closuresAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (e, _) => Text('Error: $e', style: GoogleFonts.nunito(color: colors.error)),
          data: (closures) {
            // Build staff options from the staff provider
            final staffAsync = ref.watch(businessStaffProvider);
            final staffList = staffAsync.valueOrNull ?? [];
            final staffOptions = <_StaffOption>[
              const _StaffOption(id: null, name: 'Todo el salon'),
              ...staffList.map((s) => _StaffOption(
                id: s['id'] as String,
                name: '${s['first_name'] ?? ''} ${s['last_name'] ?? ''}'.trim(),
              )),
            ];

            // Filter closures based on selected staff
            final filteredClosures = _selectedStaff.id == null
                ? closures.where((c) => c['staff_id'] == null).toList()
                : closures.where((c) => c['staff_id'] == _selectedStaff.id).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Staff picker
                if (staffList.length > 1) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: colors.outline.withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: _selectedStaff.id,
                        isExpanded: true,
                        icon: Icon(Icons.person, size: 20, color: colors.primary),
                        style: GoogleFonts.poppins(fontSize: 14, color: colors.onSurface),
                        items: staffOptions.map((opt) => DropdownMenuItem<String?>(
                          value: opt.id,
                          child: Row(
                            children: [
                              Icon(
                                opt.id == null ? Icons.store : Icons.person_outline,
                                size: 18,
                                color: opt.id == null ? colors.primary : colors.onSurface.withValues(alpha: 0.6),
                              ),
                              const SizedBox(width: 8),
                              Text(opt.name),
                            ],
                          ),
                        )).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedStaff = staffOptions.firstWhere((o) => o.id == val);
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ============================================================
                // SECTION 1: Dias Festivos
                // ============================================================
                _buildHolidaysSection(bizId, filteredClosures, colors),

                const SizedBox(height: 16),

                // ============================================================
                // SECTION 2: Vacaciones
                // ============================================================
                _buildVacationSection(bizId, colors),

                const SizedBox(height: 16),

                // ============================================================
                // SECTION 3: Cierres Programados (existing closures list)
                // ============================================================
                _buildScheduledClosuresSection(bizId, filteredClosures, colors),
              ],
            );
          },
        );
      },
    );
  }

  // -----------------------------------------------------------------------
  // SECTION 1: Dias Festivos
  // -----------------------------------------------------------------------

  Widget _buildHolidaysSection(
    String bizId,
    List<Map<String, dynamic>> closures,
    ColorScheme colors,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final year = now.year;

    // Get holidays for current year; for past holidays, also show next year's
    final holidays = _mexicanHolidays(year);
    // Add next year holidays for any that have already passed
    final nextYearHolidays = _mexicanHolidays(year + 1);

    // Merge: current year holidays (future + recent past for context), next year for past ones
    final displayHolidays = <_MexicanHoliday>[];
    for (final h in holidays) {
      displayHolidays.add(h);
    }
    // Add next year's versions of holidays that have already passed this year
    for (final h in nextYearHolidays) {
      final thisYearVersion = holidays.where((th) => th.name == h.name).firstOrNull;
      if (thisYearVersion != null && thisYearVersion.date.isBefore(today)) {
        displayHolidays.add(h);
      }
    }

    // Remove duplicates and sort by date
    displayHolidays.sort((a, b) => a.date.compareTo(b.date));

    // Build a set of closure dates for quick lookup
    final closureDates = <String>{};
    for (final c in closures) {
      closureDates.add(c['closure_date'] as String? ?? '');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _holidaysExpanded = !_holidaysExpanded),
          borderRadius: BorderRadius.circular(10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.flag, size: 20, color: colors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Dias Festivos',
                  style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
              Icon(
                _holidaysExpanded ? Icons.expand_less : Icons.expand_more,
                color: colors.onSurface.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
        if (_holidaysExpanded) ...[
          const SizedBox(height: 8),
          ...displayHolidays.map((h) {
            final dateStr = _dateKey(h.date);
            final isPast = h.date.isBefore(today);
            final isClosed = closureDates.contains(dateStr);
            final showPuente = _hasPuente(h) && !isPast;

            return Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isPast
                      ? colors.surfaceContainerHighest.withValues(alpha: 0.2)
                      : isClosed
                          ? Colors.red.withValues(alpha: 0.04)
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 90,
                      child: Text(
                        _shortDateFmt.format(h.date),
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isPast
                              ? colors.onSurface.withValues(alpha: 0.3)
                              : colors.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            h.name,
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isPast
                                  ? colors.onSurface.withValues(alpha: 0.3)
                                  : colors.onSurface,
                            ),
                          ),
                          if (showPuente)
                            Text(
                              'Puente disponible',
                              style: GoogleFonts.nunito(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                color: colors.primary.withValues(alpha: 0.7),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (isClosed && isPast)
                      Text(
                        'Cerrado',
                        style: GoogleFonts.nunito(
                          fontSize: 11,
                          color: colors.onSurface.withValues(alpha: 0.3),
                        ),
                      )
                    else
                      Switch(
                        value: isClosed,
                        activeTrackColor: colors.primary,
                        onChanged: isPast
                            ? null
                            : (val) => _toggleHoliday(bizId, h, val, closures),
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  // -----------------------------------------------------------------------
  // SECTION 2: Vacaciones
  // -----------------------------------------------------------------------

  Widget _buildVacationSection(String bizId, ColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _vacationExpanded = !_vacationExpanded),
          borderRadius: BorderRadius.circular(10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.beach_access, size: 20, color: Colors.orange),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Vacaciones',
                  style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
              Icon(
                _vacationExpanded ? Icons.expand_less : Icons.expand_more,
                color: colors.onSurface.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
        if (_vacationExpanded) ...[
          const SizedBox(height: 12),
          // Desde
          _buildDateRow(
            label: 'Desde',
            date: _vacStart,
            onTap: _pickVacStart,
            colors: colors,
          ),
          const SizedBox(height: 8),
          // Hasta
          _buildDateRow(
            label: 'Hasta',
            date: _vacEnd,
            onTap: _pickVacEnd,
            colors: colors,
          ),
          if (_vacStart != null && _vacEnd != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                '${_vacEnd!.difference(_vacStart!).inDays + 1} dias',
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  color: colors.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          // Reason
          TextField(
            controller: _vacReasonCtrl,
            style: GoogleFonts.nunito(fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Razon',
              labelStyle: GoogleFonts.nunito(fontSize: 13),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 12),
          // Agregar button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _vacLoading ? null : () => _addVacationRange(bizId),
              icon: _vacLoading
                  ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: colors.onPrimary))
                  : const Icon(Icons.add, size: 18),
              label: Text(
                'Agregar vacaciones',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: colors.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDateRow({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
    required ColorScheme colors,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: colors.outline.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Text(label, style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600, color: colors.onSurface.withValues(alpha: 0.6))),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                date != null ? _dateFmt.format(date) : 'Seleccionar fecha',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  color: date != null ? colors.onSurface : colors.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ),
            Icon(Icons.calendar_today, size: 18, color: colors.primary),
          ],
        ),
      ),
    );
  }

  // -----------------------------------------------------------------------
  // SECTION 3: Cierres Programados
  // -----------------------------------------------------------------------

  Widget _buildScheduledClosuresSection(
    String bizId,
    List<Map<String, dynamic>> closures,
    ColorScheme colors,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.event_busy, size: 20, color: Colors.red),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Cierres Programados',
                style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              icon: Icon(Icons.add_circle_outline, color: colors.primary),
              onPressed: () => _addClosure(bizId),
              tooltip: 'Agregar cierre',
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (closures.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Sin cierres programados. Agrega dias festivos o vacaciones.',
              style: GoogleFonts.nunito(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.5)),
            ),
          )
        else
          Column(
            children: closures.map((c) {
              final dateStr = c['closure_date'] as String? ?? '';
              final dt = DateTime.tryParse(dateStr);
              final reason = c['reason'] as String? ?? '';
              final staffData = c['staff'] as Map<String, dynamic>?;
              final staffName = staffData != null
                  ? '${staffData['first_name'] ?? ''} ${staffData['last_name'] ?? ''}'.trim()
                  : null;
              final today = DateTime.now();
              final isPast = dt != null && dt.isBefore(DateTime(today.year, today.month, today.day));
              final formatted = dt != null ? _dateFmt.format(dt) : dateStr;

              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isPast ? colors.surfaceContainerHighest.withValues(alpha: 0.3) : Colors.red.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isPast ? colors.outline.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.event_busy, size: 16, color: isPast ? colors.onSurface.withValues(alpha: 0.3) : Colors.red),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${formatted[0].toUpperCase()}${formatted.substring(1)}',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isPast ? colors.onSurface.withValues(alpha: 0.4) : colors.onSurface,
                            ),
                          ),
                          if (reason.isNotEmpty)
                            Text(reason, style: GoogleFonts.nunito(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.5))),
                          if (staffName != null)
                            Text(staffName, style: GoogleFonts.nunito(fontSize: 11, fontStyle: FontStyle.italic, color: colors.primary.withValues(alpha: 0.7))),
                        ],
                      ),
                    ),
                    if (!isPast)
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        color: Colors.red.withValues(alpha: 0.5),
                        onPressed: () => _deleteClosure(bizId, c['id'] as String),
                        tooltip: 'Eliminar',
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}
