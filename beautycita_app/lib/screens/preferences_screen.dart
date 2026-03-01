import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita/config/constants.dart';
import 'package:beautycita/providers/theme_provider.dart';
import 'package:beautycita/providers/user_preferences_provider.dart';
import 'package:beautycita/services/toast_service.dart';
import 'package:beautycita/widgets/settings_widgets.dart';

class PreferencesScreen extends ConsumerWidget {
  const PreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsState = ref.watch(userPrefsProvider);
    final textTheme = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Preferencias')),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.screenPaddingHorizontal,
          vertical: AppConstants.paddingMD,
        ),
        children: [
          // ── Preferencias card ──
          const SectionHeader(label: 'Preferencias'),
          const SizedBox(height: AppConstants.paddingXS),

          Container(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(AppConstants.radiusMD),
              border: Border.all(color: cs.outline.withValues(alpha: 0.1)),
            ),
            child: Column(
              children: [
                SettingsTile(
                  icon: Icons.attach_money_rounded,
                  label: 'Presupuesto',
                  trailing: Text(
                    _priceLabel(prefsState.priceComfort),
                    style: textTheme.bodyMedium?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  onTap: () => _showPriceSheet(context, ref, prefsState.priceComfort),
                ),
                Divider(height: 1, indent: 48, color: cs.outline.withValues(alpha: 0.08)),
                SettingsTile(
                  icon: Icons.speed_rounded,
                  label: 'Calidad vs Rapidez',
                  trailing: Text(
                    _qualityLabel(prefsState.qualitySpeed),
                    style: textTheme.bodyMedium?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  onTap: () => _showQualitySheet(context, ref, prefsState.qualitySpeed),
                ),
                Divider(height: 1, indent: 48, color: cs.outline.withValues(alpha: 0.08)),
                SettingsTile(
                  icon: Icons.explore_rounded,
                  label: 'Explorar vs Lealtad',
                  trailing: Text(
                    _exploreLabel(prefsState.exploreLoyalty),
                    style: textTheme.bodyMedium?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  onTap: () => _showExploreSheet(context, ref, prefsState.exploreLoyalty),
                ),
                Divider(height: 1, indent: 48, color: cs.outline.withValues(alpha: 0.08)),
                SettingsTile(
                  icon: Icons.radar_rounded,
                  label: 'Radio de busqueda',
                  trailing: Text(
                    '${prefsState.searchRadiusKm} km',
                    style: textTheme.bodyMedium?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  onTap: () => _showRadiusSheet(context, ref, prefsState.searchRadiusKm),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppConstants.paddingLG),

          // ── Tamano de texto ──
          const SectionHeader(label: 'Tamano de texto'),
          const SizedBox(height: AppConstants.paddingXS),

          Builder(builder: (context) {
            final themeState = ref.watch(themeProvider);
            return Container(
              padding: const EdgeInsets.all(AppConstants.paddingMD),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                border: Border.all(color: cs.outline.withValues(alpha: 0.1)),
              ),
              child: _FontScaleSlider(
                value: themeState.fontScale,
                onChanged: (v) => ref.read(themeProvider.notifier).setFontScale(v),
              ),
            );
          }),

          const SizedBox(height: AppConstants.paddingLG),

          // ── Notificaciones card ──
          const SectionHeader(label: 'Notificaciones'),
          const SizedBox(height: AppConstants.paddingXS),

          Container(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(AppConstants.radiusMD),
              border: Border.all(color: cs.outline.withValues(alpha: 0.1)),
            ),
            child: Column(
              children: [
                // Master notifications toggle
                SettingsTile(
                  icon: Icons.notifications_outlined,
                  label: 'Todas las notificaciones',
                  trailing: Switch(
                    value: prefsState.notificationsEnabled,
                    activeColor: cs.primary,
                    onChanged: (_) {
                      ref.read(userPrefsProvider.notifier).toggleNotifications();
                    },
                  ),
                ),

                // Individual notification toggles (nested under master)
                if (prefsState.notificationsEnabled) ...[
                  Divider(height: 1, indent: 48, color: cs.outline.withValues(alpha: 0.08)),
                  _NotifChildTile(
                    icon: Icons.calendar_today_outlined,
                    label: 'Recordatorios de citas',
                    value: prefsState.notifyBookingReminders,
                    onChanged: (_) => ref.read(userPrefsProvider.notifier).toggleBookingReminders(),
                  ),
                  _NotifChildTile(
                    icon: Icons.update_outlined,
                    label: 'Cambios en citas',
                    value: prefsState.notifyAppointmentUpdates,
                    onChanged: (_) => ref.read(userPrefsProvider.notifier).toggleAppointmentUpdates(),
                  ),
                  _NotifChildTile(
                    icon: Icons.chat_bubble_outline,
                    label: 'Mensajes',
                    value: prefsState.notifyMessages,
                    onChanged: (_) => ref.read(userPrefsProvider.notifier).toggleMessages(),
                  ),
                  _NotifChildTile(
                    icon: Icons.local_offer_outlined,
                    label: 'Promociones',
                    value: prefsState.notifyPromotions,
                    onChanged: (_) => ref.read(userPrefsProvider.notifier).togglePromotions(),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: AppConstants.paddingLG),
        ],
      ),
    );
  }

  // ── Bottom Sheets ──

  void _showRadiusSheet(BuildContext context, WidgetRef ref, int currentKm) {
    double sliderValue = currentKm.toDouble();
    Timer? autoDismiss;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppConstants.radiusLG)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildSheetHeader(context, 'Radio de busqueda'),
                    Center(
                      child: Text(
                        '${sliderValue.round()} km',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    ),
                    Row(
                      children: [
                        Text('5 km',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                            )),
                        Expanded(
                          child: Slider(
                            value: sliderValue,
                            min: 5,
                            max: 100,
                            divisions: 19,
                            activeColor: Theme.of(context).colorScheme.primary,
                            onChanged: (v) {
                              setSheetState(() => sliderValue = v);
                              ref.read(userPrefsProvider.notifier).setSearchRadius(v.round());
                              autoDismiss?.cancel();
                              autoDismiss = Timer(const Duration(milliseconds: 400), () {
                                if (ctx.mounted) Navigator.pop(ctx);
                              });
                            },
                          ),
                        ),
                        Text('100 km',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                            )),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showPriceSheet(BuildContext context, WidgetRef ref, String current) {
    String selected = current;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppConstants.radiusLG)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            void pick(String value) {
              setSheetState(() => selected = value);
              try {
                ref.read(userPrefsProvider.notifier).setPriceComfort(value);
                Future.delayed(const Duration(milliseconds: 350), () {
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ToastService.showSuccess('Presupuesto guardado');
                  }
                });
              } catch (e, stack) {
                if (ctx.mounted) Navigator.pop(ctx);
                ToastService.showErrorWithDetails(ToastService.friendlyError(e), e, stack);
              }
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildSheetHeader(context, 'Tu presupuesto para belleza'),
                    OptionTile(emoji: '\$', label: 'Economico', subtitle: 'Lo mejor al mejor precio', selected: selected == 'budget', onTap: () => pick('budget')),
                    const SizedBox(height: 8),
                    OptionTile(emoji: '\$\$', label: 'Moderado', subtitle: 'Buen balance calidad-precio', selected: selected == 'moderate', onTap: () => pick('moderate')),
                    const SizedBox(height: 8),
                    OptionTile(emoji: '\$\$\$', label: 'Premium', subtitle: 'La mejor experiencia sin importar el costo', selected: selected == 'premium', onTap: () => pick('premium')),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showQualitySheet(BuildContext context, WidgetRef ref, double current) {
    double sliderValue = current;
    Timer? autoDismiss;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppConstants.radiusLG)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildSheetHeader(context, 'Calidad vs Rapidez'),
                    Center(
                      child: Text(
                        _qualityLabel(sliderValue),
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    ),
                    Row(
                      children: [
                        Text('Lo mas rapido',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                            )),
                        Expanded(
                          child: Slider(
                            value: sliderValue,
                            min: 0.0,
                            max: 1.0,
                            divisions: 10,
                            activeColor: Theme.of(context).colorScheme.primary,
                            onChanged: (v) {
                              setSheetState(() => sliderValue = v);
                              ref.read(userPrefsProvider.notifier).setQualitySpeed(v);
                              autoDismiss?.cancel();
                              autoDismiss = Timer(const Duration(milliseconds: 400), () {
                                if (ctx.mounted) Navigator.pop(ctx);
                              });
                            },
                          ),
                        ),
                        Text('Lo mejor',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                            )),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showExploreSheet(BuildContext context, WidgetRef ref, double current) {
    double sliderValue = current;
    Timer? autoDismiss;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppConstants.radiusLG)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildSheetHeader(context, 'Explorar vs Lealtad'),
                    Center(
                      child: Text(
                        _exploreLabel(sliderValue),
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    ),
                    Row(
                      children: [
                        Text('Explorar nuevos',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                            )),
                        Expanded(
                          child: Slider(
                            value: sliderValue,
                            min: 0.0,
                            max: 1.0,
                            divisions: 10,
                            activeColor: Theme.of(context).colorScheme.primary,
                            onChanged: (v) {
                              setSheetState(() => sliderValue = v);
                              ref.read(userPrefsProvider.notifier).setExploreLoyalty(v);
                              autoDismiss?.cancel();
                              autoDismiss = Timer(const Duration(milliseconds: 400), () {
                                if (ctx.mounted) Navigator.pop(ctx);
                              });
                            },
                          ),
                        ),
                        Text('Mis favoritos',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                            )),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── Helpers ──

  static String _priceLabel(String value) {
    return switch (value) {
      'budget' => '\$',
      'premium' => '\$\$\$',
      _ => '\$\$',
    };
  }

  static String _qualityLabel(double value) {
    if (value < 0.35) return 'Rapido';
    if (value > 0.65) return 'Mejor calidad';
    return 'Balanceado';
  }

  static String _exploreLabel(double value) {
    if (value < 0.35) return 'Explorador';
    if (value > 0.65) return 'Fiel';
    return 'Balanceado';
  }
}

// ---------------------------------------------------------------------------

/// Compact, indented notification child toggle.
class _NotifChildTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _NotifChildTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 32),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppConstants.radiusSM),
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.paddingSM,
            vertical: 8,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w400,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              SizedBox(
                height: 28,
                child: FittedBox(
                  child: Switch(
                    value: value,
                    activeColor: Theme.of(context).colorScheme.primary,
                    onChanged: onChanged,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Font scale slider ──────────────────────────────────────────────────────

class _FontScaleSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _FontScaleSlider({required this.value, required this.onChanged});

  static const _stops = [0.85, 1.0, 1.15];
  static const _labels = ['Pequeno', 'Normal', 'Grande'];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            showValueIndicator: ShowValueIndicator.never,
          ),
          child: Slider(
            value: value,
            min: 0.85,
            max: 1.15,
            divisions: 2,
            onChanged: (v) {
              final snapped = _stops.reduce(
                  (a, b) => (v - a).abs() < (v - b).abs() ? a : b);
              onChanged(snapped);
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
              3,
              (i) => Text(
                    _labels[i],
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight:
                              _stops[i] == value ? FontWeight.w700 : FontWeight.w400,
                          color: _stops[i] == value
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.5),
                        ),
                  )),
        ),
        const SizedBox(height: AppConstants.paddingSM),
        Text(
          'Vista previa del texto',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    );
  }
}
