import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita/config/theme.dart';
import 'package:beautycita/config/constants.dart';
import 'package:beautycita/providers/uber_provider.dart';
import 'package:beautycita/providers/user_preferences_provider.dart';
import 'package:beautycita/widgets/settings_widgets.dart';

class PreferencesScreen extends ConsumerWidget {
  const PreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uberState = ref.watch(uberLinkProvider);
    final prefsState = ref.watch(userPrefsProvider);
    final textTheme = Theme.of(context).textTheme;

    ref.listen<UberLinkState>(uberLinkProvider, (prev, next) {
      if (next.justLinked && !(prev?.justLinked ?? false)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Uber vinculado exitosamente'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: BeautyCitaTheme.backgroundWhite,
      appBar: AppBar(title: const Text('Preferencias')),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.screenPaddingHorizontal,
          vertical: BeautyCitaTheme.spaceMD,
        ),
        children: [
          // ── Preferencias ──
          const SectionHeader(label: 'Preferencias'),
          const SizedBox(height: BeautyCitaTheme.spaceXS),

          SettingsTile(
            icon: Icons.attach_money_rounded,
            label: 'Presupuesto',
            trailing: Text(
              _priceLabel(prefsState.priceComfort),
              style: textTheme.bodyMedium?.copyWith(color: BeautyCitaTheme.textLight),
            ),
            onTap: () => _showPriceSheet(context, ref, prefsState.priceComfort),
          ),
          SettingsTile(
            icon: Icons.speed_rounded,
            label: 'Calidad vs Rapidez',
            trailing: Text(
              _qualityLabel(prefsState.qualitySpeed),
              style: textTheme.bodyMedium?.copyWith(color: BeautyCitaTheme.textLight),
            ),
            onTap: () => _showQualitySheet(context, ref, prefsState.qualitySpeed),
          ),
          SettingsTile(
            icon: Icons.explore_rounded,
            label: 'Explorar vs Lealtad',
            trailing: Text(
              _exploreLabel(prefsState.exploreLoyalty),
              style: textTheme.bodyMedium?.copyWith(color: BeautyCitaTheme.textLight),
            ),
            onTap: () => _showExploreSheet(context, ref, prefsState.exploreLoyalty),
          ),
          SettingsTile(
            icon: Icons.radar_rounded,
            label: 'Radio de busqueda',
            trailing: Text(
              '${prefsState.searchRadiusKm} km',
              style: textTheme.bodyMedium?.copyWith(color: BeautyCitaTheme.textLight),
            ),
            onTap: () => _showRadiusSheet(context, ref, prefsState.searchRadiusKm),
          ),

          const SizedBox(height: BeautyCitaTheme.spaceLG),

          // ── Transporte ──
          const SectionHeader(label: 'Transporte'),
          const SizedBox(height: BeautyCitaTheme.spaceXS),

          _UberTile(uberState: uberState, ref: ref),
          SettingsTile(
            icon: _transportIcon(prefsState.defaultTransport),
            label: 'Transporte preferido',
            trailing: Text(
              _transportLabel(prefsState.defaultTransport),
              style: textTheme.bodyMedium?.copyWith(color: BeautyCitaTheme.textLight),
            ),
            onTap: () => _showTransportSheet(context, ref, prefsState.defaultTransport),
          ),

          const SizedBox(height: BeautyCitaTheme.spaceLG),

          // ── Notificaciones ──
          const SectionHeader(label: 'Notificaciones'),
          const SizedBox(height: BeautyCitaTheme.spaceXS),

          // Master notifications toggle
          SettingsTile(
            icon: Icons.notifications_outlined,
            label: 'Todas las notificaciones',
            trailing: Switch(
              value: prefsState.notificationsEnabled,
              activeColor: BeautyCitaTheme.primaryRose,
              onChanged: (_) {
                ref.read(userPrefsProvider.notifier).toggleNotifications();
              },
            ),
          ),

          // Individual notification toggles (nested under master)
          if (prefsState.notificationsEnabled) ...[
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

          const SizedBox(height: BeautyCitaTheme.spaceLG),
        ],
      ),
    );
  }

  // ── Bottom Sheets ──

  void _showTransportSheet(BuildContext context, WidgetRef ref, String current) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppConstants.radiusLG)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildSheetHeader(context, 'Transporte preferido'),
                _buildTransportOption(ctx, ref, context, '\u{1F697}', 'Mi auto', 'Manejo yo', 'car', current),
                const SizedBox(height: 8),
                _buildTransportOption(ctx, ref, context, '\u{1F695}', 'Uber', 'Que me lleven', 'uber', current),
                const SizedBox(height: 8),
                _buildTransportOption(ctx, ref, context, '\u{1F68C}', 'Transporte', 'Me llevo yo', 'transit', current),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTransportOption(BuildContext ctx, WidgetRef ref, BuildContext parentContext,
      String emoji, String label, String subtitle, String value, String current) {
    return OptionTile(
      emoji: emoji,
      label: label,
      subtitle: subtitle,
      selected: current == value,
      onTap: () {
        try {
          ref.read(userPrefsProvider.notifier).setDefaultTransport(value);
          Navigator.pop(ctx);
          if (parentContext.mounted) {
            ScaffoldMessenger.of(parentContext).showSnackBar(
              SnackBar(
                content: const Text('Transporte favorito guardado'),
                backgroundColor: Colors.green.shade600,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } catch (e) {
          Navigator.pop(ctx);
          if (parentContext.mounted) {
            ScaffoldMessenger.of(parentContext).showSnackBar(
              SnackBar(
                content: Text('Error al guardar: $e'),
                backgroundColor: Colors.red.shade600,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      },
    );
  }

  void _showRadiusSheet(BuildContext context, WidgetRef ref, int currentKm) {
    double sliderValue = currentKm.toDouble();
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
                              color: BeautyCitaTheme.primaryRose,
                            ),
                      ),
                    ),
                    Slider(
                      value: sliderValue,
                      min: 5,
                      max: 100,
                      divisions: 19,
                      activeColor: BeautyCitaTheme.primaryRose,
                      label: '${sliderValue.round()} km',
                      onChanged: (v) => setSheetState(() => sliderValue = v),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          try {
                            ref.read(userPrefsProvider.notifier).setSearchRadius(sliderValue.round());
                            Navigator.pop(ctx);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Radio de busqueda guardado'),
                                  backgroundColor: Colors.green.shade600,
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          } catch (e) {
                            Navigator.pop(ctx);
                            _showError(context, e);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: BeautyCitaTheme.primaryRose,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppConstants.radiusSM),
                          ),
                        ),
                        child: const Text('Guardar'),
                      ),
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
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Presupuesto guardado'),
                          backgroundColor: Colors.green.shade600,
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  }
                });
              } catch (e) {
                if (ctx.mounted) Navigator.pop(ctx);
                _showError(context, e);
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
                              color: BeautyCitaTheme.primaryRose,
                            ),
                      ),
                    ),
                    Row(
                      children: [
                        Text('Lo mas rapido',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: BeautyCitaTheme.textLight)),
                        Expanded(
                          child: Slider(
                            value: sliderValue,
                            min: 0.0,
                            max: 1.0,
                            divisions: 10,
                            activeColor: BeautyCitaTheme.primaryRose,
                            onChanged: (v) => setSheetState(() => sliderValue = v),
                          ),
                        ),
                        Text('Lo mejor',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: BeautyCitaTheme.textLight)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildSaveButton(context, ctx, () {
                      ref.read(userPrefsProvider.notifier).setQualitySpeed(sliderValue);
                    }),
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
                              color: BeautyCitaTheme.primaryRose,
                            ),
                      ),
                    ),
                    Row(
                      children: [
                        Text('Explorar nuevos',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: BeautyCitaTheme.textLight)),
                        Expanded(
                          child: Slider(
                            value: sliderValue,
                            min: 0.0,
                            max: 1.0,
                            divisions: 10,
                            activeColor: BeautyCitaTheme.primaryRose,
                            onChanged: (v) => setSheetState(() => sliderValue = v),
                          ),
                        ),
                        Text('Mis favoritos',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: BeautyCitaTheme.textLight)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildSaveButton(context, ctx, () {
                      ref.read(userPrefsProvider.notifier).setExploreLoyalty(sliderValue);
                    }),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSaveButton(BuildContext parentCtx, BuildContext sheetCtx, VoidCallback save) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          try {
            save();
            Navigator.pop(sheetCtx);
            if (parentCtx.mounted) {
              ScaffoldMessenger.of(parentCtx).showSnackBar(
                SnackBar(
                  content: const Text('Preferencia guardada'),
                  backgroundColor: Colors.green.shade600,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          } catch (e) {
            Navigator.pop(sheetCtx);
            _showError(parentCtx, e);
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: BeautyCitaTheme.primaryRose,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusSM),
          ),
        ),
        child: const Text('Guardar'),
      ),
    );
  }

  void _showError(BuildContext context, Object e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar: $e'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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

  static IconData _transportIcon(String mode) {
    return switch (mode) {
      'uber' => Icons.local_taxi_rounded,
      'transit' => Icons.directions_bus_rounded,
      _ => Icons.directions_car_rounded,
    };
  }

  static String _transportLabel(String mode) {
    return switch (mode) {
      'uber' => 'Uber',
      'transit' => 'Transporte',
      _ => 'Mi auto',
    };
  }
}

// ---------------------------------------------------------------------------
// Uber Tile (moved from settings_screen.dart)
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
                color: BeautyCitaTheme.textLight,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w400,
                    color: BeautyCitaTheme.textDark,
                  ),
                ),
              ),
              SizedBox(
                height: 28,
                child: FittedBox(
                  child: Switch(
                    value: value,
                    activeColor: BeautyCitaTheme.primaryRose,
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

// ---------------------------------------------------------------------------
// Uber Tile (moved from settings_screen.dart)
// ---------------------------------------------------------------------------

class _UberTile extends StatelessWidget {
  final UberLinkState uberState;
  final WidgetRef ref;

  const _UberTile({required this.uberState, required this.ref});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (uberState.isLoading) {
      return SettingsTile(
        icon: Icons.local_taxi_rounded,
        label: 'Uber',
        trailing: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (uberState.isLinked) {
      return SettingsTile(
        icon: Icons.local_taxi_rounded,
        iconColor: Colors.green.shade600,
        label: 'Uber',
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _confirmUnlink(context),
              child: Text(
                'Desvincular',
                style: textTheme.bodySmall?.copyWith(color: Colors.red.shade400),
              ),
            ),
          ],
        ),
      );
    }

    return SettingsTile(
      icon: Icons.local_taxi_rounded,
      label: 'Vincular Uber',
      onTap: () => ref.read(uberLinkProvider.notifier).initiateLink(),
    );
  }

  void _confirmUnlink(BuildContext context) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppConstants.radiusXL)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.paddingLG,
              AppConstants.paddingMD,
              AppConstants.paddingLG,
              AppConstants.paddingLG,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: BeautyCitaTheme.spaceMD),
                Icon(Icons.local_taxi_rounded, size: AppConstants.iconSizeXL, color: Colors.red.shade400),
                const SizedBox(height: BeautyCitaTheme.spaceSM),
                Text(
                  'Desvincular Uber?',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: BeautyCitaTheme.spaceXS),
                Text(
                  'Ya no se programaran viajes automaticamente. Puedes volver a vincular en cualquier momento.',
                  style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(color: BeautyCitaTheme.textLight),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: BeautyCitaTheme.spaceLG),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, AppConstants.minTouchHeight),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusLG)),
                        ),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: BeautyCitaTheme.spaceSM),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade500,
                          minimumSize: const Size(0, AppConstants.minTouchHeight),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusLG)),
                        ),
                        child: const Text('Desvincular', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed == true) {
      ref.read(uberLinkProvider.notifier).unlink();
    }
  }
}
