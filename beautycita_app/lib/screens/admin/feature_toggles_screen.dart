import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/constants.dart';
import '../../providers/admin_provider.dart';
import '../../services/supabase_client.dart';

class FeatureTogglesScreen extends ConsumerStatefulWidget {
  const FeatureTogglesScreen({super.key});

  @override
  ConsumerState<FeatureTogglesScreen> createState() =>
      _FeatureTogglesScreenState();
}

class _FeatureTogglesScreenState
    extends ConsumerState<FeatureTogglesScreen> {
  final _localValues = <String, bool>{};

  static const _groupLabels = {
    'payments': 'Pagos',
    'booking': 'Reservas',
    'social': 'Social',
    'experimental': 'Experimental',
    'platform': 'Plataforma',
  };

  Future<void> _toggle(String key, bool value) async {
    final prev = !value;
    setState(() => _localValues[key] = value);
    try {
      await SupabaseClientService.client.from('app_config').update({
        'value': value.toString(),
        'updated_by': SupabaseClientService.currentUserId,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('key', key);
      await adminLogAction(
        action: 'toggle_feature',
        targetType: 'app_config',
        targetId: key,
        details: {'new_value': value.toString()},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('$key: ${value ? "activado" : "desactivado"}')),
        );
      }
    } catch (e) {
      setState(() => _localValues[key] = prev);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final togglesAsync = ref.watch(adminFeatureTogglesProvider);
    final colors = Theme.of(context).colorScheme;

    return togglesAsync.when(
      data: (toggles) {
        if (toggles.isEmpty) {
          return Center(
            child: Text('Sin feature toggles',
                style: GoogleFonts.nunito(
                    color: colors.onSurface.withValues(alpha: 0.5))),
          );
        }

        // Group by group_name
        final groups = <String, List<Map<String, dynamic>>>{};
        for (final t in toggles) {
          final group = t['group_name'] as String? ?? 'general';
          groups.putIfAbsent(group, () => []).add(t);
        }

        return RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(adminFeatureTogglesProvider),
          child: ListView(
            padding: const EdgeInsets.all(AppConstants.paddingMD),
            children: [
              for (final entry in groups.entries) ...[
                Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppConstants.radiusMD),
                    side: BorderSide(
                      color: colors.onSurface.withValues(alpha: 0.08),
                    ),
                  ),
                  shadowColor: colors.onSurface.withValues(alpha: 0.08),
                  surfaceTintColor: Colors.transparent,
                  margin: const EdgeInsets.only(
                      bottom: AppConstants.paddingMD),
                  child: Padding(
                    padding:
                        const EdgeInsets.all(AppConstants.paddingMD),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _groupLabels[entry.key] ??
                              entry.key[0].toUpperCase() +
                                  entry.key.substring(1),
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: colors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (final config in entry.value)
                          _buildToggle(config, colors),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child:
            Text('Error: $e', style: GoogleFonts.nunito(color: colors.error)),
      ),
    );
  }

  Widget _buildToggle(
      Map<String, dynamic> config, ColorScheme colors) {
    final key = config['key'] as String;
    final currentValue =
        _localValues[key] ?? (config['value'] as String) == 'true';
    final description =
        config['description_es'] as String? ?? key;

    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        key.replaceAll('_', ' ').replaceFirst('enable ', ''),
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: colors.onSurface,
        ),
      ),
      subtitle: Text(
        description,
        style: GoogleFonts.nunito(
          fontSize: 12,
          color: colors.onSurface.withValues(alpha: 0.5),
        ),
      ),
      value: currentValue,
      onChanged: (v) => _toggle(key, v),
    );
  }
}
