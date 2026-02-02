import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../providers/admin_provider.dart';
import '../../services/supabase_client.dart';

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

    return rulesAsync.when(
      data: (rules) => _buildList(rules),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('Error: $e',
            style: GoogleFonts.nunito(color: BeautyCitaTheme.textLight)),
      ),
    );
  }

  Widget _buildList(List<TimeInferenceRule> rules) {
    return ListView(
      padding: const EdgeInsets.all(BeautyCitaTheme.spaceMD),
      children: [
        // Header row
        Padding(
          padding: const EdgeInsets.only(
            bottom: BeautyCitaTheme.spaceSM,
            left: BeautyCitaTheme.spaceMD,
            right: BeautyCitaTheme.spaceMD,
          ),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text('Horas',
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: BeautyCitaTheme.textLight)),
              ),
              Expanded(
                flex: 2,
                child: Text('Días',
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: BeautyCitaTheme.textLight)),
              ),
              Expanded(
                flex: 3,
                child: Text('Ventana',
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: BeautyCitaTheme.textLight)),
              ),
              SizedBox(
                width: 50,
                child: Text('Pico',
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: BeautyCitaTheme.textLight)),
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

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BeautyCitaTheme.radiusSmall),
      ),
      margin: const EdgeInsets.only(bottom: 4),
      child: Column(
        children: [
          // Summary row
          InkWell(
            onTap: () => setState(() {
              _expandedId = isExpanded ? null : rule.id;
            }),
            borderRadius: BorderRadius.circular(BeautyCitaTheme.radiusSmall),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: BeautyCitaTheme.spaceMD,
                vertical: BeautyCitaTheme.spaceSM + 2,
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
                          fontSize: 13, color: BeautyCitaTheme.textDark),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      _dayRange(rule.dayStart, rule.dayEnd),
                      style: GoogleFonts.nunito(
                          fontSize: 13, color: BeautyCitaTheme.textDark),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      rule.description ?? '-',
                      style: GoogleFonts.nunito(
                          fontSize: 13, color: BeautyCitaTheme.textDark),
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
                        color: BeautyCitaTheme.primaryRose,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: BeautyCitaTheme.textLight,
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
            'day_start': _dayStart,
            'day_end': _dayEnd,
            'description': _description.isEmpty ? null : _description,
            'offset_days_min': _offsetDaysMin,
            'offset_days_max': _offsetDaysMax,
            'preferred_hour_start': _preferredHourStart,
            'preferred_hour_end': _preferredHourEnd,
            'peak_hour': _peakHour,
            'is_active': _isActive,
          }).eq('id', widget.rule.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Regla guardada'),
            backgroundColor: BeautyCitaTheme.primaryRose,
          ),
        );
      }
      widget.onSaved();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BeautyCitaTheme.spaceMD,
        0,
        BeautyCitaTheme.spaceMD,
        BeautyCitaTheme.spaceMD,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: BeautyCitaTheme.spaceMD),

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
                      fontSize: 14, color: BeautyCitaTheme.textDark)),
              Switch(
                value: _isActive,
                activeColor: BeautyCitaTheme.primaryRose,
                onChanged: (v) => setState(() => _isActive = v),
              ),
            ],
          ),

          const SizedBox(height: BeautyCitaTheme.spaceMD),

          // Save button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: BeautyCitaTheme.primaryRose,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.nunito(
                fontSize: 11, color: BeautyCitaTheme.textLight)),
        const SizedBox(height: 4),
        Row(
          children: [
            InkWell(
              onTap: value > min ? () => onChanged(value - 1) : null,
              child: Icon(Icons.remove_circle_outline,
                  size: 20,
                  color: value > min
                      ? BeautyCitaTheme.primaryRose
                      : BeautyCitaTheme.dividerLight),
            ),
            Expanded(
              child: Text(
                value < 0 ? 'ASAP' : '$value',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: BeautyCitaTheme.textDark,
                ),
              ),
            ),
            InkWell(
              onTap: value < max ? () => onChanged(value + 1) : null,
              child: Icon(Icons.add_circle_outline,
                  size: 20,
                  color: value < max
                      ? BeautyCitaTheme.primaryRose
                      : BeautyCitaTheme.dividerLight),
            ),
          ],
        ),
      ],
    );
  }
}
