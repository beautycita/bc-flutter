import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/constants.dart';
import '../../providers/admin_provider.dart';
import '../../services/supabase_client.dart';
import '../../services/toast_service.dart';

class EngineSettingsEditorScreen extends ConsumerStatefulWidget {
  const EngineSettingsEditorScreen({super.key});

  @override
  ConsumerState<EngineSettingsEditorScreen> createState() =>
      _EngineSettingsEditorScreenState();
}

class _EngineSettingsEditorScreenState
    extends ConsumerState<EngineSettingsEditorScreen> {
  /// Edited values keyed by setting key. Null = unchanged.
  final Map<String, String> _edits = {};
  bool _saving = false;

  bool get _hasEdits => _edits.isNotEmpty;

  Future<void> _save(List<EngineSetting> original) async {
    if (!_hasEdits) return;
    setState(() => _saving = true);

    try {
      for (final entry in _edits.entries) {
        await SupabaseClientService.client
            .from('engine_settings')
            .update({'value': entry.value}).eq('key', entry.key);
      }
      ref.invalidate(engineSettingsProvider);
      _edits.clear();
      ToastService.showSuccess('Configuracion guardada');
    } catch (e, stack) {
      ToastService.showErrorWithDetails(ToastService.friendlyError(e), e, stack);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _reset() {
    setState(() => _edits.clear());
  }

  String _currentValue(EngineSetting s) {
    return _edits[s.key] ?? s.value;
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(engineSettingsProvider);
    final colors = Theme.of(context).colorScheme;

    return settingsAsync.when(
      data: (settings) => _buildContent(settings),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('Error: $e',
            style: GoogleFonts.nunito(
                color: colors.onSurface.withValues(alpha: 0.5))),
      ),
    );
  }

  Widget _buildContent(List<EngineSetting> settings) {
    final colors = Theme.of(context).colorScheme;

    // Group by group_name
    final groups = <String, List<EngineSetting>>{};
    for (final s in settings) {
      groups.putIfAbsent(s.groupName, () => []);
      groups[s.groupName]!.add(s);
    }

    final groupOrder = groups.keys.toList();

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(AppConstants.paddingMD),
            itemCount: groupOrder.length,
            itemBuilder: (context, i) {
              final group = groupOrder[i];
              final items = groups[group]!;
              return _GroupCard(
                groupName: group,
                settings: items,
                edits: _edits,
                currentValue: _currentValue,
                onChanged: (key, value) {
                  setState(() => _edits[key] = value);
                },
              );
            },
          ),
        ),
        // Bottom action bar
        if (_hasEdits)
          Container(
            padding: const EdgeInsets.all(AppConstants.paddingMD),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Text(
                  '${_edits.length} cambio${_edits.length == 1 ? '' : 's'}',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: colors.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _reset,
                  child: const Text('DESCARTAR'),
                ),
                const SizedBox(width: AppConstants.paddingSM),
                ElevatedButton(
                  onPressed: _saving ? null : () => _save(settings),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(100, 44),
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
              ],
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Group card
// ---------------------------------------------------------------------------

class _GroupCard extends StatelessWidget {
  final String groupName;
  final List<EngineSetting> settings;
  final Map<String, String> edits;
  final String Function(EngineSetting) currentValue;
  final void Function(String key, String value) onChanged;

  const _GroupCard({
    required this.groupName,
    required this.settings,
    required this.edits,
    required this.currentValue,
    required this.onChanged,
  });

  static const _groupLabels = {
    'results': 'Resultados',
    'scoring': 'Algoritmo de Scoring',
    'uber_mode': 'Modo Uber',
    'transport': 'Transporte',
    'reviews': 'Reseñas',
    'user_patterns': 'Patrones de Usuario',
    'card_thresholds': 'Umbrales de Tarjeta',
  };

  static const _groupIcons = {
    'results': Icons.dashboard,
    'scoring': Icons.functions,
    'uber_mode': Icons.local_taxi,
    'transport': Icons.directions_car,
    'reviews': Icons.rate_review,
    'user_patterns': Icons.person_search,
    'card_thresholds': Icons.tune,
  };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
      ),
      margin: const EdgeInsets.only(bottom: AppConstants.paddingMD),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Group header
            Row(
              children: [
                Icon(
                  _groupIcons[groupName] ?? Icons.settings,
                  color: colors.primary,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  _groupLabels[groupName] ?? groupName,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.paddingMD),
            ...settings.map((s) => _SettingRow(
                  setting: s,
                  currentValue: currentValue(s),
                  isEdited: edits.containsKey(s.key),
                  onChanged: (v) => onChanged(s.key, v),
                )),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Individual setting row — slider for number, int picker for integer
// ---------------------------------------------------------------------------

class _SettingRow extends StatelessWidget {
  final EngineSetting setting;
  final String currentValue;
  final bool isEdited;
  final ValueChanged<String> onChanged;

  const _SettingRow({
    required this.setting,
    required this.currentValue,
    required this.isEdited,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isNumber = setting.dataType == 'number';
    final minVal = setting.minValue ?? 0.0;
    final maxVal = setting.maxValue ?? (isNumber ? 1.0 : 100.0);

    final parsed = double.tryParse(currentValue) ?? 0.0;
    final clamped = parsed.clamp(minVal, maxVal);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.paddingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label + value
          Row(
            children: [
              Expanded(
                child: Text(
                  _formatKey(setting.key),
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight:
                        isEdited ? FontWeight.w700 : FontWeight.w500,
                    color: isEdited
                        ? colors.primary
                        : colors.onSurface,
                  ),
                ),
              ),
              Text(
                isNumber
                    ? clamped.toStringAsFixed(2)
                    : clamped.toInt().toString(),
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isEdited
                      ? colors.primary
                      : colors.onSurface,
                ),
              ),
            ],
          ),

          // Slider
          Slider(
            value: clamped,
            min: minVal,
            max: maxVal,
            divisions: isNumber
                ? ((maxVal - minVal) * 100).round().clamp(1, 1000)
                : (maxVal - minVal).round().clamp(1, 1000),
            activeColor: isEdited
                ? colors.primary
                : colors.primary.withValues(alpha: 0.6),
            inactiveColor:
                colors.primary.withValues(alpha: 0.12),
            onChanged: (v) {
              onChanged(isNumber
                  ? v.toStringAsFixed(2)
                  : v.round().toString());
            },
          ),

          // Description
          if (setting.descriptionEs != null)
            Padding(
              padding:
                  const EdgeInsets.only(left: 4, right: 4, bottom: 4),
              child: Text(
                setting.descriptionEs!,
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  color: colors.onSurface.withValues(alpha: 0.5),
                  height: 1.3,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatKey(String key) {
    return key
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }
}
