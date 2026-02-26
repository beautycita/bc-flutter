import 'package:beautycita_core/supabase.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/breakpoints.dart';
import '../../providers/admin_config_provider.dart';

/// Feature toggles page — `/app/admin/toggles`
///
/// List of feature toggles with switch widgets.
/// Each toggle saves immediately to app_config table.
class TogglesPage extends ConsumerStatefulWidget {
  const TogglesPage({super.key});

  @override
  ConsumerState<TogglesPage> createState() => _TogglesPageState();
}

class _TogglesPageState extends ConsumerState<TogglesPage> {
  // Track which toggles are currently being saved
  final Set<String> _saving = {};

  Future<void> _toggle(FeatureToggle toggle, bool newValue) async {
    if (!BCSupabase.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Base de datos no conectada')),
      );
      return;
    }

    setState(() => _saving.add(toggle.key));

    try {
      // Upsert the config entry
      await BCSupabase.client.from('app_config').upsert(
        {
          'key': toggle.key,
          'value': newValue.toString(),
          'type': 'bool',
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'key',
      );

      ref.invalidate(featureTogglesProvider);
      ref.invalidate(appConfigProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${toggle.name}: ${newValue ? 'activado' : 'desactivado'}',
            ),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving.remove(toggle.key));
    }
  }

  @override
  Widget build(BuildContext context) {
    final togglesAsync = ref.watch(featureTogglesProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isMobile = WebBreakpoints.isMobile(width);

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16.0 : 24.0,
            vertical: 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(isMobile: isMobile),
              const SizedBox(height: 8),
              _ImmediateEffectBanner(),
              const SizedBox(height: 24),
              togglesAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (toggles) => _TogglesList(
                  toggles: toggles,
                  saving: _saving,
                  onToggle: _toggle,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

// ── Header ─────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.isMobile});
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Feature Toggles',
          style: (isMobile
                  ? theme.textTheme.headlineSmall
                  : theme.textTheme.headlineMedium)
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Activa o desactiva funciones de la aplicacion. Los cambios afectan ambas apps inmediatamente.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

// ── Immediate effect banner ────────────────────────────────────────────────

class _ImmediateEffectBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFF9800).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFFF9800).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline,
            size: 18,
            color: Color(0xFFFF9800),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Los toggles tienen efecto inmediato. Ambas apps (mobile y web) leen estos valores en tiempo real.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFFE65100),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Toggles list ───────────────────────────────────────────────────────────

class _TogglesList extends StatelessWidget {
  const _TogglesList({
    required this.toggles,
    required this.saving,
    required this.onToggle,
  });

  final List<FeatureToggle> toggles;
  final Set<String> saving;
  final Future<void> Function(FeatureToggle, bool) onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < toggles.length; i++) ...[
          _ToggleCard(
            toggle: toggles[i],
            isSaving: saving.contains(toggles[i].key),
            onToggle: (v) => onToggle(toggles[i], v),
          ),
          if (i < toggles.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

// ── Toggle card ────────────────────────────────────────────────────────────

class _ToggleCard extends StatefulWidget {
  const _ToggleCard({
    required this.toggle,
    required this.isSaving,
    required this.onToggle,
  });

  final FeatureToggle toggle;
  final bool isSaving;
  final ValueChanged<bool> onToggle;

  @override
  State<_ToggleCard> createState() => _ToggleCardState();
}

class _ToggleCardState extends State<_ToggleCard> {
  bool _hovering = false;

  IconData get _icon => switch (widget.toggle.key) {
        'toggle_bitcoin_payments' => Icons.currency_bitcoin,
        'toggle_uber_integration' => Icons.local_taxi,
        'toggle_virtual_studio' => Icons.camera_alt,
        'toggle_aphrodite_ai' => Icons.auto_awesome,
        'toggle_google_calendar' => Icons.calendar_month,
        'toggle_qr_auth' => Icons.qr_code,
        'toggle_cita_express' => Icons.bolt,
        'toggle_push_notifications' => Icons.notifications_active,
        _ => Icons.toggle_on,
      };

  Color get _accentColor => switch (widget.toggle.key) {
        'toggle_bitcoin_payments' => const Color(0xFFF7931A),
        'toggle_uber_integration' => const Color(0xFF000000),
        'toggle_virtual_studio' => const Color(0xFF9C27B0),
        'toggle_aphrodite_ai' => const Color(0xFFE91E63),
        'toggle_google_calendar' => const Color(0xFF4285F4),
        'toggle_qr_auth' => const Color(0xFF00BCD4),
        'toggle_cita_express' => const Color(0xFFFF9800),
        'toggle_push_notifications' => const Color(0xFF4CAF50),
        _ => const Color(0xFF2196F3),
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isEnabled = widget.toggle.enabled;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _hovering
                ? _accentColor.withValues(alpha: 0.3)
                : colors.outlineVariant,
          ),
          boxShadow: _hovering
              ? [
                  BoxShadow(
                    color: _accentColor.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: (isEnabled ? _accentColor : colors.onSurface)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _icon,
                size: 22,
                color: isEnabled
                    ? _accentColor
                    : colors.onSurface.withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(width: 16),

            // Name + description
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.toggle.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isEnabled
                          ? null
                          : colors.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.toggle.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Switch or loading
            if (widget.isSaving)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Switch(
                value: isEnabled,
                onChanged: widget.onToggle,
                activeTrackColor: _accentColor,
              ),
          ],
        ),
      ),
    );
  }
}
