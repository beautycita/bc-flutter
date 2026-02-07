import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:beautycita/config/theme.dart';
import 'package:beautycita/config/constants.dart';
import 'package:beautycita/providers/auth_provider.dart';
import 'package:beautycita/providers/uber_provider.dart';
import 'package:beautycita/providers/user_preferences_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final uberState = ref.watch(uberLinkProvider);
    final prefsState = ref.watch(userPrefsProvider);
    final textTheme = Theme.of(context).textTheme;

    // Show snackbar when Uber just linked
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
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.screenPaddingHorizontal,
          vertical: BeautyCitaTheme.spaceMD,
        ),
        children: [
          // ── Profile Card ──
          Container(
            padding: const EdgeInsets.all(AppConstants.paddingLG),
            decoration: BoxDecoration(
              gradient: BeautyCitaTheme.primaryGradient,
              borderRadius: BorderRadius.circular(AppConstants.radiusMD),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  child: const Icon(
                    Icons.person_outline,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: BeautyCitaTheme.spaceMD),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        authState.username ?? 'Usuario',
                        style: textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Cuenta anonima',
                        style: textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: BeautyCitaTheme.spaceLG),

          // ── Section: Preferencias ──
          const _SectionHeader(label: 'Preferencias'),
          const SizedBox(height: BeautyCitaTheme.spaceXS),

          _SettingsTile(
            icon: Icons.attach_money_rounded,
            label: 'Presupuesto',
            trailing: Text(
              _priceLabel(prefsState.priceComfort),
              style: textTheme.bodyMedium?.copyWith(
                color: BeautyCitaTheme.textLight,
              ),
            ),
            onTap: () => _showPriceSheet(context, ref, prefsState.priceComfort),
          ),
          _SettingsTile(
            icon: Icons.speed_rounded,
            label: 'Calidad vs Rapidez',
            trailing: Text(
              _qualityLabel(prefsState.qualitySpeed),
              style: textTheme.bodyMedium?.copyWith(
                color: BeautyCitaTheme.textLight,
              ),
            ),
            onTap: () => _showQualitySheet(context, ref, prefsState.qualitySpeed),
          ),
          _SettingsTile(
            icon: Icons.explore_rounded,
            label: 'Explorar vs Lealtad',
            trailing: Text(
              _exploreLabel(prefsState.exploreLoyalty),
              style: textTheme.bodyMedium?.copyWith(
                color: BeautyCitaTheme.textLight,
              ),
            ),
            onTap: () => _showExploreSheet(context, ref, prefsState.exploreLoyalty),
          ),

          const SizedBox(height: BeautyCitaTheme.spaceLG),

          // ── Section: Transporte ──
          const _SectionHeader(label: 'Transporte'),
          const SizedBox(height: BeautyCitaTheme.spaceXS),

          // Uber link/unlink tile
          _UberTile(uberState: uberState, ref: ref),

          // Default transport selector
          _SettingsTile(
            icon: _transportIcon(prefsState.defaultTransport),
            label: 'Transporte favorito',
            trailing: Text(
              _transportLabel(prefsState.defaultTransport),
              style: textTheme.bodyMedium?.copyWith(
                color: BeautyCitaTheme.textLight,
              ),
            ),
            onTap: () => _showTransportSheet(context, ref, prefsState.defaultTransport),
          ),

          const SizedBox(height: BeautyCitaTheme.spaceLG),

          // ── Section: General ──
          const _SectionHeader(label: 'General'),
          const SizedBox(height: BeautyCitaTheme.spaceXS),

          _SettingsTile(
            icon: Icons.qr_code_scanner_rounded,
            label: 'Vincular sesion web',
            onTap: () => context.push('/qr-scan'),
          ),
          _SettingsTile(
            icon: Icons.devices_rounded,
            label: 'Dispositivos conectados',
            onTap: () => context.push('/devices'),
          ),
          _SettingsTile(
            icon: Icons.calendar_today_rounded,
            label: 'Mis citas',
            onTap: () => context.push('/my-bookings'),
          ),
          _SettingsTile(
            icon: Icons.radar_rounded,
            label: 'Radio de busqueda',
            trailing: Text(
              '${prefsState.searchRadiusKm} km',
              style: textTheme.bodyMedium?.copyWith(
                color: BeautyCitaTheme.textLight,
              ),
            ),
            onTap: () => _showRadiusSheet(context, ref, prefsState.searchRadiusKm),
          ),

          const SizedBox(height: BeautyCitaTheme.spaceLG),

          // ── Section: Notificaciones ──
          const _SectionHeader(label: 'Notificaciones'),
          const SizedBox(height: BeautyCitaTheme.spaceXS),

          _SettingsTile(
            icon: Icons.notifications_outlined,
            label: 'Notificaciones',
            trailing: Switch(
              value: prefsState.notificationsEnabled,
              activeColor: BeautyCitaTheme.primaryRose,
              onChanged: (_) {
                try {
                  ref.read(userPrefsProvider.notifier).toggleNotifications();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          prefsState.notificationsEnabled
                              ? 'Notificaciones desactivadas'
                              : 'Notificaciones activadas',
                        ),
                        backgroundColor: Colors.green.shade600,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                } catch (e) {
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
              },
            ),
          ),

          const SizedBox(height: BeautyCitaTheme.spaceLG),

          // ── Section: Acerca de ──
          const _SectionHeader(label: 'Acerca de'),
          const SizedBox(height: BeautyCitaTheme.spaceXS),

          _SettingsTile(
            icon: Icons.info_outline_rounded,
            label: 'Version',
            trailing: Text(
              '0.1.0',
              style: textTheme.bodyMedium?.copyWith(
                color: BeautyCitaTheme.textLight,
              ),
            ),
          ),

          const SizedBox(height: BeautyCitaTheme.spaceXL),

          // ── Logout ──
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusMD),
                    ),
                    title: const Text('Cerrar sesion'),
                    content: const Text(
                      'Se cerrara tu sesion y tendras que autenticarte de nuevo.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Cancelar'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                        ),
                        child: const Text('Cerrar sesion'),
                      ),
                    ],
                  ),
                );

                if (confirmed == true) {
                  await ref.read(authStateProvider.notifier).logout();
                  if (context.mounted) {
                    context.go('/auth');
                  }
                }
              },
              icon: const Icon(Icons.logout),
              label: const Text('Cerrar sesion'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade600,
                side: BorderSide(color: Colors.red.shade300),
                padding: const EdgeInsets.symmetric(
                  vertical: AppConstants.paddingMD,
                ),
              ),
            ),
          ),

          const SizedBox(height: BeautyCitaTheme.spaceLG),
        ],
      ),
    );
  }

  // ── Transport selector bottom sheet ──
  void _showTransportSheet(BuildContext context, WidgetRef ref, String current) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
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
                const SizedBox(height: 16),
                Text(
                  'Transporte favorito',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 16),
                _TransportOption(
                  emoji: '\u{1F697}',
                  label: 'Mi auto',
                  subtitle: 'Manejo yo',
                  selected: current == 'car',
                  onTap: () {
                    try {
                      ref.read(userPrefsProvider.notifier).setDefaultTransport('car');
                      Navigator.pop(ctx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
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
                  },
                ),
                const SizedBox(height: 8),
                _TransportOption(
                  emoji: '\u{1F695}',
                  label: 'Uber',
                  subtitle: 'Que me lleven',
                  selected: current == 'uber',
                  onTap: () {
                    try {
                      ref.read(userPrefsProvider.notifier).setDefaultTransport('uber');
                      Navigator.pop(ctx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
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
                  },
                ),
                const SizedBox(height: 8),
                _TransportOption(
                  emoji: '\u{1F68C}',
                  label: 'Transporte',
                  subtitle: 'Me llevo yo',
                  selected: current == 'transit',
                  onTap: () {
                    try {
                      ref.read(userPrefsProvider.notifier).setDefaultTransport('transit');
                      Navigator.pop(ctx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
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
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Search radius bottom sheet ──
  void _showRadiusSheet(BuildContext context, WidgetRef ref, int currentKm) {
    double sliderValue = currentKm.toDouble();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                    const SizedBox(height: 16),
                    Text(
                      'Radio de busqueda',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
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
                      onChanged: (v) {
                        setSheetState(() => sliderValue = v);
                      },
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          try {
                            ref
                                .read(userPrefsProvider.notifier)
                                .setSearchRadius(sliderValue.round());
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

  // ── Price comfort bottom sheet ──
  void _showPriceSheet(BuildContext context, WidgetRef ref, String current) {
    String selected = current;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                    const SizedBox(height: 16),
                    Text(
                      'Tu presupuesto para belleza',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 16),
                    _TransportOption(
                      emoji: '\$',
                      label: 'Economico',
                      subtitle: 'Lo mejor al mejor precio',
                      selected: selected == 'budget',
                      onTap: () => pick('budget'),
                    ),
                    const SizedBox(height: 8),
                    _TransportOption(
                      emoji: '\$\$',
                      label: 'Moderado',
                      subtitle: 'Buen balance calidad-precio',
                      selected: selected == 'moderate',
                      onTap: () => pick('moderate'),
                    ),
                    const SizedBox(height: 8),
                    _TransportOption(
                      emoji: '\$\$\$',
                      label: 'Premium',
                      subtitle: 'La mejor experiencia sin importar el costo',
                      selected: selected == 'premium',
                      onTap: () => pick('premium'),
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

  // ── Quality vs Speed bottom sheet ──
  void _showQualitySheet(BuildContext context, WidgetRef ref, double current) {
    double sliderValue = current;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                    const SizedBox(height: 16),
                    Text(
                      'Calidad vs Rapidez',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
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
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: BeautyCitaTheme.textLight,
                                )),
                        Expanded(
                          child: Slider(
                            value: sliderValue,
                            min: 0.0,
                            max: 1.0,
                            divisions: 10,
                            activeColor: BeautyCitaTheme.primaryRose,
                            onChanged: (v) {
                              setSheetState(() => sliderValue = v);
                            },
                          ),
                        ),
                        Text('Lo mejor',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: BeautyCitaTheme.textLight,
                                )),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          try {
                            ref
                                .read(userPrefsProvider.notifier)
                                .setQualitySpeed(sliderValue);
                            Navigator.pop(ctx);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Preferencia guardada'),
                                  backgroundColor: Colors.green.shade600,
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          } catch (e) {
                            Navigator.pop(ctx);
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

  // ── Explore vs Loyalty bottom sheet ──
  void _showExploreSheet(BuildContext context, WidgetRef ref, double current) {
    double sliderValue = current;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                    const SizedBox(height: 16),
                    Text(
                      'Explorar vs Lealtad',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
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
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: BeautyCitaTheme.textLight,
                                )),
                        Expanded(
                          child: Slider(
                            value: sliderValue,
                            min: 0.0,
                            max: 1.0,
                            divisions: 10,
                            activeColor: BeautyCitaTheme.primaryRose,
                            onChanged: (v) {
                              setSheetState(() => sliderValue = v);
                            },
                          ),
                        ),
                        Text('Mis favoritos',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: BeautyCitaTheme.textLight,
                                )),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          try {
                            ref
                                .read(userPrefsProvider.notifier)
                                .setExploreLoyalty(sliderValue);
                            Navigator.pop(ctx);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Preferencia guardada'),
                                  backgroundColor: Colors.green.shade600,
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          } catch (e) {
                            Navigator.pop(ctx);
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
// Uber Tile
// ---------------------------------------------------------------------------

class _UberTile extends StatelessWidget {
  final UberLinkState uberState;
  final WidgetRef ref;

  const _UberTile({required this.uberState, required this.ref});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (uberState.isLoading) {
      return _SettingsTile(
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
      return _SettingsTile(
        icon: Icons.local_taxi_rounded,
        iconColor: Colors.green.shade600,
        label: 'Uber vinculado',
        trailing: TextButton(
          onPressed: () => _confirmUnlink(context),
          child: Text(
            'Desvincular',
            style: textTheme.bodySmall?.copyWith(
              color: Colors.red.shade400,
            ),
          ),
        ),
      );
    }

    return _SettingsTile(
      icon: Icons.local_taxi_rounded,
      label: 'Vincular Uber',
      onTap: () => ref.read(uberLinkProvider.notifier).initiateLink(),
    );
  }

  void _confirmUnlink(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        ),
        title: const Text('Desvincular Uber'),
        content: const Text(
          'Ya no se programaran viajes automaticamente. Puedes volver a vincular en cualquier momento.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
            ),
            child: const Text('Desvincular'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      ref.read(uberLinkProvider.notifier).unlink();
    }
  }
}

// ---------------------------------------------------------------------------
// Transport Option (for bottom sheet)
// ---------------------------------------------------------------------------

class _TransportOption extends StatelessWidget {
  final String emoji;
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _TransportOption({
    required this.emoji,
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? BeautyCitaTheme.primaryRose.withValues(alpha: 0.08)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(AppConstants.radiusSM),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusSM),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: BeautyCitaTheme.textLight,
                          ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(
                  Icons.check_circle_rounded,
                  color: BeautyCitaTheme.primaryRose,
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section Header
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: BeautyCitaTheme.textLight,
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

// ---------------------------------------------------------------------------
// Settings Tile
// ---------------------------------------------------------------------------

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    required this.label,
    this.iconColor,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusSM),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.paddingSM,
            vertical: AppConstants.paddingMD,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: AppConstants.iconSizeMD,
                color: iconColor ?? BeautyCitaTheme.primaryRose,
              ),
              const SizedBox(width: BeautyCitaTheme.spaceMD),
              Expanded(
                child: Text(
                  label,
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (trailing != null)
                trailing!
              else if (onTap != null)
                Icon(
                  Icons.chevron_right_rounded,
                  color: BeautyCitaTheme.textLight.withValues(alpha: 0.5),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
