import 'package:beautycita_core/supabase.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/breakpoints.dart';
import '../../config/web_theme.dart';
import '../../providers/admin_config_provider.dart';
import '../../widgets/web_design_system.dart';

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
          'data_type': 'bool',
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
    return WebSectionHeader(
      label: 'Configuracion',
      title: 'Feature Toggles',
      subtitle: 'Activa o desactiva funciones de la aplicacion. Los cambios afectan ambas apps inmediatamente.',
      centered: false,
      titleSize: isMobile ? 28 : 36,
    );
  }
}

// ── Immediate effect banner ────────────────────────────────────────────────

class _ImmediateEffectBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFF9800).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFF9800).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFFF9800).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.info_outlined,
              size: 18,
              color: Color(0xFFFF9800),
            ),
          ),
          const SizedBox(width: 12),
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
        'enable_stripe_payments' => Icons.credit_card,
        'enable_btc_payments' => Icons.currency_bitcoin,
        'enable_cash_payments' => Icons.money,
        'enable_deposit_required' => Icons.lock_outline,
        'enable_instant_booking' => Icons.bolt,
        'enable_time_inference' => Icons.access_time_filled,
        'enable_uber_integration' => Icons.local_taxi,
        'enable_waitlist' => Icons.hourglass_top,
        'enable_push_notifications' => Icons.notifications_active,
        'enable_reviews' => Icons.star_outline,
        'enable_salon_chat' => Icons.chat_bubble_outline,
        'enable_referrals' => Icons.share,
        'enable_analytics' => Icons.analytics,
        'enable_maintenance_mode' => Icons.construction,
        'enable_ai_recommendations' => Icons.auto_awesome,
        'enable_virtual_studio' => Icons.camera_alt,
        'enable_voice_booking' => Icons.mic,
        _ => Icons.toggle_on,
      };

  Color get _accentColor => switch (widget.toggle.key) {
        'enable_stripe_payments' => const Color(0xFF635BFF),
        'enable_btc_payments' => const Color(0xFFF7931A),
        'enable_cash_payments' => const Color(0xFF4CAF50),
        'enable_deposit_required' => const Color(0xFF795548),
        'enable_instant_booking' => const Color(0xFFFF9800),
        'enable_time_inference' => const Color(0xFF00BCD4),
        'enable_uber_integration' => const Color(0xFF000000),
        'enable_waitlist' => const Color(0xFF607D8B),
        'enable_push_notifications' => const Color(0xFF4CAF50),
        'enable_reviews' => const Color(0xFFFFC107),
        'enable_salon_chat' => const Color(0xFF2196F3),
        'enable_referrals' => const Color(0xFF9C27B0),
        'enable_analytics' => const Color(0xFF3F51B5),
        'enable_maintenance_mode' => const Color(0xFFE53935),
        'enable_ai_recommendations' => const Color(0xFFE91E63),
        'enable_virtual_studio' => const Color(0xFF9C27B0),
        'enable_voice_booking' => const Color(0xFF009688),
        _ => const Color(0xFF2196F3),
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEnabled = widget.toggle.enabled;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _hovering ? -2 : 0, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kWebSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _hovering
                ? _accentColor.withValues(alpha: 0.3)
                : kWebCardBorder,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _hovering ? 0.06 : 0.03),
              blurRadius: _hovering ? 16 : 10,
              offset: Offset(0, _hovering ? 6 : 2),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: _hovering ? 0.04 : 0.02),
              blurRadius: _hovering ? 30 : 20,
              offset: Offset(0, _hovering ? 10 : 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon box
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: (isEnabled ? _accentColor : kWebTextHint)
                    .withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _icon,
                size: 24,
                color: isEnabled
                    ? _accentColor
                    : kWebTextHint,
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
                          ? kWebTextPrimary
                          : kWebTextHint,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.toggle.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: kWebTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Switch or loading — accent color kWebPrimary
            if (widget.isSaving)
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: kWebPrimary,
                ),
              )
            else
              Switch(
                value: isEnabled,
                onChanged: widget.onToggle,
                activeTrackColor: kWebPrimary,
              ),
          ],
        ),
      ),
    );
  }
}
