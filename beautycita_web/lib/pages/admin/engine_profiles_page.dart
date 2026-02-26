import 'package:beautycita_core/supabase.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/breakpoints.dart';
import '../../config/router.dart';
import '../../providers/admin_engine_provider.dart';

/// Engine profiles page — `/app/admin/engine/profiles`
///
/// Left: list of service types from service_profiles table.
/// Right: editor with sliders for each weight.
class EngineProfilesPage extends ConsumerStatefulWidget {
  const EngineProfilesPage({super.key});

  @override
  ConsumerState<EngineProfilesPage> createState() =>
      _EngineProfilesPageState();
}

class _EngineProfilesPageState extends ConsumerState<EngineProfilesPage> {
  ServiceProfile? _selected;
  ServiceProfile? _editing;
  bool _saving = false;

  void _selectProfile(ServiceProfile profile) {
    setState(() {
      _selected = profile;
      _editing = profile;
    });
  }

  Future<void> _save() async {
    if (_editing == null || !BCSupabase.isInitialized) return;

    setState(() => _saving = true);
    try {
      await BCSupabase.client
          .from('service_profiles')
          .update({
            'quality_weight': _editing!.qualityWeight,
            'distance_weight': _editing!.distanceWeight,
            'price_weight': _editing!.priceWeight,
            'availability_weight': _editing!.availabilityWeight,
            'search_radius_km': _editing!.searchRadiusKm,
            'max_results': _editing!.maxResults,
          })
          .eq('id', _editing!.id);

      ref.invalidate(serviceProfilesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil guardado')),
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
    final profilesAsync = ref.watch(serviceProfilesProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isMobile = WebBreakpoints.isMobile(width);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Breadcrumb(isMobile: isMobile),
            const Divider(height: 1),
            Expanded(
              child: profilesAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(strokeWidth: 2)),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (profiles) {
                  if (isMobile) {
                    return _MobileLayout(
                      profiles: profiles,
                      selected: _selected,
                      editing: _editing,
                      saving: _saving,
                      onSelect: _selectProfile,
                      onEdit: (p) => setState(() => _editing = p),
                      onSave: _save,
                      onBack: () => setState(() {
                        _selected = null;
                        _editing = null;
                      }),
                    );
                  }
                  return _DesktopLayout(
                    profiles: profiles,
                    selected: _selected,
                    editing: _editing,
                    saving: _saving,
                    onSelect: _selectProfile,
                    onEdit: (p) => setState(() => _editing = p),
                    onSave: _save,
                  );
                },
              ),
            ),
          ],
        );
      },
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
            'Perfiles de servicio',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Desktop layout ─────────────────────────────────────────────────────────

class _DesktopLayout extends StatelessWidget {
  const _DesktopLayout({
    required this.profiles,
    required this.selected,
    required this.editing,
    required this.saving,
    required this.onSelect,
    required this.onEdit,
    required this.onSave,
  });

  final List<ServiceProfile> profiles;
  final ServiceProfile? selected;
  final ServiceProfile? editing;
  final bool saving;
  final ValueChanged<ServiceProfile> onSelect;
  final ValueChanged<ServiceProfile> onEdit;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left: profile list
        SizedBox(
          width: 280,
          child: _ProfileList(
            profiles: profiles,
            selected: selected,
            onSelect: onSelect,
          ),
        ),
        VerticalDivider(width: 1, thickness: 1, color: colors.outlineVariant),
        // Right: editor
        Expanded(
          child: editing != null
              ? _ProfileEditor(
                  profile: editing!,
                  saving: saving,
                  onEdit: onEdit,
                  onSave: onSave,
                )
              : const _EmptyEditor(),
        ),
      ],
    );
  }
}

// ── Mobile layout ──────────────────────────────────────────────────────────

class _MobileLayout extends StatelessWidget {
  const _MobileLayout({
    required this.profiles,
    required this.selected,
    required this.editing,
    required this.saving,
    required this.onSelect,
    required this.onEdit,
    required this.onSave,
    required this.onBack,
  });

  final List<ServiceProfile> profiles;
  final ServiceProfile? selected;
  final ServiceProfile? editing;
  final bool saving;
  final ValueChanged<ServiceProfile> onSelect;
  final ValueChanged<ServiceProfile> onEdit;
  final VoidCallback onSave;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    if (editing != null) {
      return Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Volver a lista'),
            ),
          ),
          Expanded(
            child: _ProfileEditor(
              profile: editing!,
              saving: saving,
              onEdit: onEdit,
              onSave: onSave,
            ),
          ),
        ],
      );
    }

    return _ProfileList(
      profiles: profiles,
      selected: selected,
      onSelect: onSelect,
    );
  }
}

// ── Profile list ───────────────────────────────────────────────────────────

class _ProfileList extends StatelessWidget {
  const _ProfileList({
    required this.profiles,
    required this.selected,
    required this.onSelect,
  });

  final List<ServiceProfile> profiles;
  final ServiceProfile? selected;
  final ValueChanged<ServiceProfile> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (profiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tune, size: 48, color: colors.onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text(
              'Sin perfiles de servicio',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: profiles.length,
      itemBuilder: (context, index) {
        final profile = profiles[index];
        final isSelected = selected?.id == profile.id;

        return _ProfileTile(
          profile: profile,
          isSelected: isSelected,
          onTap: () => onSelect(profile),
        );
      },
    );
  }
}

class _ProfileTile extends StatefulWidget {
  const _ProfileTile({
    required this.profile,
    required this.isSelected,
    required this.onTap,
  });

  final ServiceProfile profile;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_ProfileTile> createState() => _ProfileTileState();
}

class _ProfileTileState extends State<_ProfileTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    Color bgColor;
    if (widget.isSelected) {
      bgColor = colors.primary.withValues(alpha: 0.08);
    } else if (_hovering) {
      bgColor = colors.primary.withValues(alpha: 0.04);
    } else {
      bgColor = Colors.transparent;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: bgColor,
            border: Border(
              left: widget.isSelected
                  ? BorderSide(color: colors.primary, width: 3)
                  : BorderSide.none,
              bottom: BorderSide(
                color: colors.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.profile.name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight:
                      widget.isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                widget.profile.serviceType,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Profile editor ─────────────────────────────────────────────────────────

class _ProfileEditor extends StatelessWidget {
  const _ProfileEditor({
    required this.profile,
    required this.saving,
    required this.onEdit,
    required this.onSave,
  });

  final ServiceProfile profile;
  final bool saving;
  final ValueChanged<ServiceProfile> onEdit;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            profile.name,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tipo: ${profile.serviceType}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 32),

          // Weight sliders
          _WeightSlider(
            label: 'Calidad',
            value: profile.qualityWeight,
            color: const Color(0xFF4CAF50),
            onChanged: (v) =>
                onEdit(profile.copyWith(qualityWeight: v.round())),
          ),
          const SizedBox(height: 20),
          _WeightSlider(
            label: 'Distancia',
            value: profile.distanceWeight,
            color: const Color(0xFF2196F3),
            onChanged: (v) =>
                onEdit(profile.copyWith(distanceWeight: v.round())),
          ),
          const SizedBox(height: 20),
          _WeightSlider(
            label: 'Precio',
            value: profile.priceWeight,
            color: const Color(0xFFFF9800),
            onChanged: (v) =>
                onEdit(profile.copyWith(priceWeight: v.round())),
          ),
          const SizedBox(height: 20),
          _WeightSlider(
            label: 'Disponibilidad',
            value: profile.availabilityWeight,
            color: const Color(0xFF9C27B0),
            onChanged: (v) =>
                onEdit(profile.copyWith(availabilityWeight: v.round())),
          ),
          const SizedBox(height: 32),

          // Search radius
          _LabeledSlider(
            label: 'Radio de busqueda',
            value: profile.searchRadiusKm,
            min: 1,
            max: 50,
            divisions: 49,
            suffix: 'km',
            onChanged: (v) =>
                onEdit(profile.copyWith(searchRadiusKm: v)),
          ),
          const SizedBox(height: 20),

          // Max results
          _LabeledSlider(
            label: 'Resultados maximos',
            value: profile.maxResults.toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            suffix: '',
            onChanged: (v) =>
                onEdit(profile.copyWith(maxResults: v.round())),
          ),
          const SizedBox(height: 32),

          // Action buttons
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Simulacion de curacion: proximamente'),
                    ),
                  );
                },
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('Preview'),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: saving ? null : onSave,
                icon: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child:
                            CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save, size: 18),
                label: Text(saving ? 'Guardando...' : 'Guardar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Empty editor ───────────────────────────────────────────────────────────

class _EmptyEditor extends StatelessWidget {
  const _EmptyEditor();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.tune,
            size: 48,
            color: colors.onSurface.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 12),
          Text(
            'Selecciona un perfil para editar',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Weight slider ──────────────────────────────────────────────────────────

class _WeightSlider extends StatelessWidget {
  const _WeightSlider({
    required this.label,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  final String label;
  final int value;
  final Color color;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$value',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: color,
            thumbColor: color,
            overlayColor: color.withValues(alpha: 0.12),
            inactiveTrackColor: colors.outlineVariant,
          ),
          child: Slider(
            value: value.toDouble(),
            min: 0,
            max: 100,
            divisions: 100,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

// ── Labeled slider ─────────────────────────────────────────────────────────

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.suffix,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String suffix;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final displayValue = value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Text(
              '$displayValue$suffix',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
