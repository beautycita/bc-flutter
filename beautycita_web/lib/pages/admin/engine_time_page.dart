import 'package:beautycita_core/supabase.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/breakpoints.dart';
import '../../config/router.dart';
import '../../providers/admin_engine_provider.dart';

/// Engine time inference rules page — `/app/admin/engine/time`
///
/// Matrix grid: rows = service types, columns = day-of-week.
/// Each cell shows booking window. Click cell to edit.
class EngineTimePage extends ConsumerStatefulWidget {
  const EngineTimePage({super.key});

  @override
  ConsumerState<EngineTimePage> createState() => _EngineTimePageState();
}

class _EngineTimePageState extends ConsumerState<EngineTimePage> {
  // Local edits map: ruleId -> edited rule
  final Map<String, TimeInferenceRule> _edits = {};
  bool _saving = false;

  static const _dayLabels = ['Lun', 'Mar', 'Mie', 'Jue', 'Vie', 'Sab', 'Dom'];

  void _editCell(TimeInferenceRule rule) async {
    final result = await showDialog<TimeInferenceRule>(
      context: context,
      builder: (ctx) => _CellEditDialog(rule: _edits[rule.id] ?? rule),
    );
    if (result != null) {
      setState(() {
        _edits[result.id] = result;
      });
    }
  }

  Future<void> _saveAll(List<TimeInferenceRule> rules) async {
    if (!BCSupabase.isInitialized || _edits.isEmpty) return;

    setState(() => _saving = true);
    try {
      for (final entry in _edits.entries) {
        final rule = entry.value;
        await BCSupabase.client
            .from('time_inference_rules')
            .update({
              'start_hour': rule.startHour,
              'end_hour': rule.endHour,
              'buffer_minutes': rule.bufferMinutes,
            })
            .eq('id', rule.id);
      }

      _edits.clear();
      ref.invalidate(timeInferenceRulesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reglas guardadas')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rulesAsync = ref.watch(timeInferenceRulesProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isMobile = WebBreakpoints.isMobile(width);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Breadcrumb(isMobile: isMobile),
            const Divider(height: 1),
            // Header with save button
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16.0 : 24.0,
                vertical: 12,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reglas de inferencia de tiempo',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Click en una celda para editar la ventana de reserva',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.5),
                                  ),
                        ),
                      ],
                    ),
                  ),
                  if (_edits.isNotEmpty)
                    rulesAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (rules) => ElevatedButton.icon(
                        onPressed: _saving ? null : () => _saveAll(rules),
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            : const Icon(Icons.save, size: 18),
                        label: Text(_saving
                            ? 'Guardando...'
                            : 'Guardar todo (${_edits.length})'),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: rulesAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(strokeWidth: 2)),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (rules) {
                  if (rules.isEmpty) {
                    return _emptyState(context);
                  }
                  return _buildMatrix(context, rules, isMobile);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _emptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.schedule,
            size: 48,
            color: colors.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 12),
          Text(
            'Sin reglas de tiempo configuradas',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatrix(
    BuildContext context,
    List<TimeInferenceRule> rules,
    bool isMobile,
  ) {
    // Group rules by service type
    final grouped = <String, List<TimeInferenceRule>>{};
    for (final rule in rules) {
      grouped.putIfAbsent(rule.serviceType, () => []).add(rule);
    }
    final serviceTypes = grouped.keys.toList()..sort();

    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final cellWidth = isMobile ? 80.0 : 110.0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 8 : 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                SizedBox(
                  width: isMobile ? 100 : 160,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      'Servicio',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ),
                for (final day in _dayLabels)
                  SizedBox(
                    width: cellWidth,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        day,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Divider(color: colors.outlineVariant, height: 1),
            // Data rows
            for (final sType in serviceTypes)
              _MatrixRow(
                serviceType: sType,
                rules: grouped[sType]!,
                edits: _edits,
                cellWidth: cellWidth,
                labelWidth: isMobile ? 100.0 : 160.0,
                onEditCell: _editCell,
              ),
          ],
        ),
      ),
    );
  }
}

// ── Breadcrumb ─────────────────────────────────────────────────────────────

class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({required this.isMobile});
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16.0 : 24.0,
        vertical: 12,
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => context.go(WebRoutes.adminEngine),
            child: Text(
              'Motor',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.primary,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Icon(
              Icons.chevron_right,
              size: 18,
              color: colors.onSurface.withValues(alpha: 0.4),
            ),
          ),
          Text(
            'Reglas de tiempo',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Matrix row ─────────────────────────────────────────────────────────────

class _MatrixRow extends StatelessWidget {
  const _MatrixRow({
    required this.serviceType,
    required this.rules,
    required this.edits,
    required this.cellWidth,
    required this.labelWidth,
    required this.onEditCell,
  });

  final String serviceType;
  final List<TimeInferenceRule> rules;
  final Map<String, TimeInferenceRule> edits;
  final double cellWidth;
  final double labelWidth;
  final ValueChanged<TimeInferenceRule> onEditCell;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    // Index rules by day of week
    final byDay = <int, TimeInferenceRule>{};
    for (final r in rules) {
      byDay[r.dayOfWeek] = r;
    }

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colors.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: labelWidth,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                serviceType,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          for (var day = 0; day < 7; day++)
            SizedBox(
              width: cellWidth,
              child: byDay.containsKey(day)
                  ? _TimeCell(
                      rule: edits[byDay[day]!.id] ?? byDay[day]!,
                      isEdited: edits.containsKey(byDay[day]!.id),
                      onTap: () => onEditCell(byDay[day]!),
                    )
                  : const Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        '--',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
            ),
        ],
      ),
    );
  }
}

// ── Time cell ──────────────────────────────────────────────────────────────

class _TimeCell extends StatefulWidget {
  const _TimeCell({
    required this.rule,
    required this.isEdited,
    required this.onTap,
  });

  final TimeInferenceRule rule;
  final bool isEdited;
  final VoidCallback onTap;

  @override
  State<_TimeCell> createState() => _TimeCellState();
}

class _TimeCellState extends State<_TimeCell> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final timeText =
        '${widget.rule.startHour.toString().padLeft(2, '0')}:00-${widget.rule.endHour.toString().padLeft(2, '0')}:00';

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.all(2),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isEdited
                ? colors.primary.withValues(alpha: 0.08)
                : _hovering
                    ? colors.primary.withValues(alpha: 0.04)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: widget.isEdited
                ? Border.all(
                    color: colors.primary.withValues(alpha: 0.3),
                  )
                : null,
          ),
          child: Column(
            children: [
              Text(
                timeText,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: widget.isEdited ? colors.primary : null,
                ),
              ),
              Text(
                '+${widget.rule.bufferMinutes}m',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 10,
                  color: colors.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Cell edit dialog ───────────────────────────────────────────────────────

class _CellEditDialog extends StatefulWidget {
  const _CellEditDialog({required this.rule});
  final TimeInferenceRule rule;

  @override
  State<_CellEditDialog> createState() => _CellEditDialogState();
}

class _CellEditDialogState extends State<_CellEditDialog> {
  late int _startHour;
  late int _endHour;
  late int _bufferMinutes;

  static const _dayLabels = [
    'Lunes',
    'Martes',
    'Miercoles',
    'Jueves',
    'Viernes',
    'Sabado',
    'Domingo'
  ];

  @override
  void initState() {
    super.initState();
    _startHour = widget.rule.startHour;
    _endHour = widget.rule.endHour;
    _bufferMinutes = widget.rule.bufferMinutes;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(
        '${widget.rule.serviceType} — ${_dayLabels[widget.rule.dayOfWeek]}',
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Start hour
            Row(
              children: [
                SizedBox(
                  width: 120,
                  child: Text('Hora inicio:',
                      style: theme.textTheme.bodyMedium),
                ),
                Expanded(
                  child: Slider(
                    value: _startHour.toDouble(),
                    min: 0,
                    max: 23,
                    divisions: 23,
                    label: '${_startHour.toString().padLeft(2, '0')}:00',
                    onChanged: (v) =>
                        setState(() => _startHour = v.round()),
                  ),
                ),
                SizedBox(
                  width: 50,
                  child: Text(
                    '${_startHour.toString().padLeft(2, '0')}:00',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // End hour
            Row(
              children: [
                SizedBox(
                  width: 120,
                  child: Text('Hora fin:',
                      style: theme.textTheme.bodyMedium),
                ),
                Expanded(
                  child: Slider(
                    value: _endHour.toDouble(),
                    min: 0,
                    max: 23,
                    divisions: 23,
                    label: '${_endHour.toString().padLeft(2, '0')}:00',
                    onChanged: (v) =>
                        setState(() => _endHour = v.round()),
                  ),
                ),
                SizedBox(
                  width: 50,
                  child: Text(
                    '${_endHour.toString().padLeft(2, '0')}:00',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Buffer minutes
            Row(
              children: [
                SizedBox(
                  width: 120,
                  child: Text('Buffer:',
                      style: theme.textTheme.bodyMedium),
                ),
                Expanded(
                  child: Slider(
                    value: _bufferMinutes.toDouble(),
                    min: 0,
                    max: 120,
                    divisions: 24,
                    label: '${_bufferMinutes}min',
                    onChanged: (v) =>
                        setState(() => _bufferMinutes = v.round()),
                  ),
                ),
                SizedBox(
                  width: 50,
                  child: Text(
                    '${_bufferMinutes}min',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
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
          onPressed: () {
            Navigator.of(context).pop(
              widget.rule.copyWith(
                startHour: _startHour,
                endHour: _endHour,
                bufferMinutes: _bufferMinutes,
              ),
            );
          },
          child: const Text('Aplicar'),
        ),
      ],
    );
  }
}
