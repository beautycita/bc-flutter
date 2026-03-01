import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/constants.dart';
import '../../providers/admin_provider.dart';
import '../../services/supabase_client.dart';
import '../../services/toast_service.dart';

class TimeRulesScreen extends ConsumerStatefulWidget {
  const TimeRulesScreen({super.key});

  @override
  ConsumerState<TimeRulesScreen> createState() => _TimeRulesScreenState();
}

class _TimeRulesScreenState extends ConsumerState<TimeRulesScreen> {
  String? _expandedId;

  static const _dayLabels = [
    'Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'
  ];

  String _dayRange(int start, int end) {
    if (start == 0 && end == 6) return 'Cualquier';
    if (start == end) return _dayLabels[start];
    return '${_dayLabels[start]}-${_dayLabels[end]}';
  }

  String _hourRange(int start, int end) {
    return '${start}:00 - ${end}:00';
  }

  @override
  Widget build(BuildContext context) {
    final rulesAsync = ref.watch(timeInferenceRulesProvider);
    final colors = Theme.of(context).colorScheme;

    return rulesAsync.when(
      data: (rules) {
        if (rules.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.schedule_outlined,
                    size: 48, color: colors.onSurface.withValues(alpha: 0.3)),
                const SizedBox(height: 12),
                Text(
                  'Sin reglas de tiempo configuradas',
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    color: colors.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Las reglas determinan como el motor\ninfiere la ventana de tiempo ideal.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: colors.onSurface.withValues(alpha: 0.35),
                  ),
                ),
              ],
            ),
          );
        }
        return _buildList(rules);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 48, color: colors.onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Error cargando reglas:\n$e',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                    color: colors.onSurface.withValues(alpha: 0.5)),
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => ref.invalidate(timeInferenceRulesProvider),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<TimeInferenceRule> rules) {
    final colors = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      children: [
        // Header row
        Padding(
          padding: const EdgeInsets.only(
            bottom: AppConstants.paddingSM,
            left: AppConstants.paddingMD,
            right: AppConstants.paddingMD,
          ),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text('Horas',
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface.withValues(alpha: 0.5))),
              ),
              Expanded(
                flex: 2,
                child: Text('Días',
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface.withValues(alpha: 0.5))),
              ),
              Expanded(
                flex: 3,
                child: Text('Ventana',
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface.withValues(alpha: 0.5))),
              ),
              SizedBox(
                width: 50,
                child: Text('Pico',
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface.withValues(alpha: 0.5))),
              ),
            ],
          ),
        ),
        ...rules.map((rule) => _buildRuleCard(rule)),
      ],
    );
  }

  Widget _buildRuleCard(TimeInferenceRule rule) {
    final isExpanded = _expandedId == rule.id;
    final colors = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusSM),
        side: BorderSide(
          color: colors.onSurface.withValues(alpha: 0.08),
        ),
      ),
      shadowColor: Colors.black.withValues(alpha: 0.08),
      surfaceTintColor: Colors.transparent,
      margin: const EdgeInsets.only(bottom: 4),
      child: Column(
        children: [
          // Summary row
          InkWell(
            onTap: () => setState(() {
              _expandedId = isExpanded ? null : rule.id;
            }),
            borderRadius: BorderRadius.circular(AppConstants.radiusSM),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.paddingMD,
                vertical: AppConstants.paddingSM + 2,
              ),
              child: Row(
                children: [
                  // Active indicator
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: rule.isActive ? Colors.green : Colors.grey,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      _hourRange(rule.hourStart, rule.hourEnd),
                      style: GoogleFonts.nunito(
                          fontSize: 13, color: colors.onSurface),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      _dayRange(rule.dayStart, rule.dayEnd),
                      style: GoogleFonts.nunito(
                          fontSize: 13, color: colors.onSurface),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      rule.description ?? '-',
                      style: GoogleFonts.nunito(
                          fontSize: 13, color: colors.onSurface),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(
                    width: 50,
                    child: Text(
                      rule.peakHour != null
                          ? '${rule.peakHour}:00'
                          : 'ASAP',
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.primary,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: colors.onSurface.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
          ),

          // Expanded editor
          if (isExpanded)
            _RuleEditor(
              rule: rule,
              onSaved: () {
                ref.invalidate(timeInferenceRulesProvider);
                setState(() => _expandedId = null);
              },
            ),
        ],
      ),
    );
  }
}

class _RuleEditor extends StatefulWidget {
  final TimeInferenceRule rule;
  final VoidCallback onSaved;

  const _RuleEditor({required this.rule, required this.onSaved});

  @override
  State<_RuleEditor> createState() => _RuleEditorState();
}

class _RuleEditorState extends State<_RuleEditor> {
  late int _hourStart;
  late int _hourEnd;
  late int _dayStart;
  late int _dayEnd;
  late String _description;
  late int _offsetDaysMin;
  late int _offsetDaysMax;
  late int _preferredHourStart;
  late int _preferredHourEnd;
  late int? _peakHour;
  late bool _isActive;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.rule;
    _hourStart = r.hourStart;
    _hourEnd = r.hourEnd;
    _dayStart = r.dayStart;
    _dayEnd = r.dayEnd;
    _description = r.description ?? '';
    _offsetDaysMin = r.offsetDaysMin;
    _offsetDaysMax = r.offsetDaysMax;
    _preferredHourStart = r.preferredHourStart;
    _preferredHourEnd = r.preferredHourEnd;
    _peakHour = r.peakHour;
    _isActive = r.isActive;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await SupabaseClientService.client
          .from('time_inference_rules')
          .update({
            'hour_start': _hourStart,
            'hour_end': _hourEnd,
            'day_of_week_start': _dayStart,
            'day_of_week_end': _dayEnd,
            'window_description': _description.isEmpty ? 'Sin nombre' : _description,
            'window_offset_days_min': _offsetDaysMin,
            'window_offset_days_max': _offsetDaysMax,
            'preferred_hour_start': _preferredHourStart,
            'preferred_hour_end': _preferredHourEnd,
            'preference_peak_hour': _peakHour ?? 11,
            'is_active': _isActive,
          }).eq('id', widget.rule.id);

      ToastService.showSuccess('Regla guardada');
      widget.onSaved();
    } catch (e, stack) {
      ToastService.showErrorWithDetails(ToastService.friendlyError(e), e, stack);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.paddingMD,
        0,
        AppConstants.paddingMD,
        AppConstants.paddingMD,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: AppConstants.paddingMD),

          // Hour range
          Row(
            children: [
              Expanded(
                child: _IntField(
                  label: 'Hora inicio',
                  value: _hourStart,
                  min: 0,
                  max: 23,
                  onChanged: (v) => setState(() => _hourStart = v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _IntField(
                  label: 'Hora fin',
                  value: _hourEnd,
                  min: 0,
                  max: 24,
                  onChanged: (v) => setState(() => _hourEnd = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Day range
          Row(
            children: [
              Expanded(
                child: _IntField(
                  label: 'Día inicio (0=Dom)',
                  value: _dayStart,
                  min: 0,
                  max: 6,
                  onChanged: (v) => setState(() => _dayStart = v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _IntField(
                  label: 'Día fin',
                  value: _dayEnd,
                  min: 0,
                  max: 6,
                  onChanged: (v) => setState(() => _dayEnd = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Description
          TextField(
            controller: TextEditingController(text: _description),
            onChanged: (v) => _description = v,
            decoration: InputDecoration(
              labelText: 'Descripción',
              labelStyle: GoogleFonts.nunito(fontSize: 13),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),

          // Offsets
          Row(
            children: [
              Expanded(
                child: _IntField(
                  label: 'Offset días mín',
                  value: _offsetDaysMin,
                  min: 0,
                  max: 30,
                  onChanged: (v) => setState(() => _offsetDaysMin = v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _IntField(
                  label: 'Offset días máx',
                  value: _offsetDaysMax,
                  min: 0,
                  max: 30,
                  onChanged: (v) => setState(() => _offsetDaysMax = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Preferred hours
          Row(
            children: [
              Expanded(
                child: _IntField(
                  label: 'Hora pref. inicio',
                  value: _preferredHourStart,
                  min: 0,
                  max: 23,
                  onChanged: (v) =>
                      setState(() => _preferredHourStart = v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _IntField(
                  label: 'Hora pref. fin',
                  value: _preferredHourEnd,
                  min: 0,
                  max: 24,
                  onChanged: (v) =>
                      setState(() => _preferredHourEnd = v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _IntField(
                  label: 'Hora pico',
                  value: _peakHour ?? -1,
                  min: -1,
                  max: 23,
                  onChanged: (v) =>
                      setState(() => _peakHour = v < 0 ? null : v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Active toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Activa',
                  style: GoogleFonts.nunito(
                      fontSize: 14, color: colors.onSurface)),
              Switch(
                value: _isActive,
                activeColor: colors.primary,
                onChanged: (v) => setState(() => _isActive = v),
              ),
            ],
          ),

          const SizedBox(height: AppConstants.paddingMD),

          // Save button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 44),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('GUARDAR'),
            ),
          ),
        ],
      ),
    );
  }
}

class _IntField extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _IntField({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.nunito(
                fontSize: 11,
                color: colors.onSurface.withValues(alpha: 0.5))),
        const SizedBox(height: 4),
        Row(
          children: [
            InkWell(
              onTap: value > min ? () => onChanged(value - 1) : null,
              child: Icon(Icons.remove_circle_outline,
                  size: 20,
                  color: value > min
                      ? colors.primary
                      : Theme.of(context).dividerColor),
            ),
            Expanded(
              child: Text(
                value < 0 ? 'ASAP' : '$value',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface,
                ),
              ),
            ),
            InkWell(
              onTap: value < max ? () => onChanged(value + 1) : null,
              child: Icon(Icons.add_circle_outline,
                  size: 20,
                  color: value < max
                      ? colors.primary
                      : Theme.of(context).dividerColor),
            ),
          ],
        ),
      ],
    );
  }
}
