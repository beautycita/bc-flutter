import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:beautycita/config/fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:beautycita/config/constants.dart';
import 'package:beautycita/config/theme_extension.dart';
import 'package:beautycita/providers/feature_toggle_provider.dart';
import 'package:beautycita/providers/profile_provider.dart';
import 'package:beautycita/providers/service_modifiers_provider.dart';
import 'package:beautycita/providers/theme_provider.dart';
import 'package:beautycita/providers/user_preferences_provider.dart';
import 'package:beautycita/services/location_service.dart';
import 'package:beautycita/services/places_service.dart';
import 'package:beautycita/services/toast_service.dart';
import 'package:beautycita/services/supabase_client.dart';
import 'package:beautycita/widgets/location_picker_sheet.dart';
import 'package:beautycita_core/supabase.dart';

// ── Notification state model ───────────────────────────────────────────────

enum _NotifState { sound, silent, off }

// ── Radius dial stops ──────────────────────────────────────────────────────

const _radiusStops = <int>[
  10, 15, 20, 25, 30, 35, 40, 45, 50, 60, 70, 80, 90, 100,
];

String _approxRadiusLabel(int km) {
  if (km <= 12) return '~10km';
  if (km <= 37) return '~25km';
  if (km <= 75) return '~50km';
  return '~100km';
}

int _nearestStop(int km) {
  int best = _radiusStops.first;
  int bestDist = (km - best).abs();
  for (final s in _radiusStops) {
    final d = (km - s).abs();
    if (d < bestDist) {
      bestDist = d;
      best = s;
    }
  }
  return best;
}

// ── Main Screen ────────────────────────────────────────────────────────────

class PreferencesScreen extends ConsumerStatefulWidget {
  const PreferencesScreen({super.key});

  @override
  ConsumerState<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends ConsumerState<PreferencesScreen>
    with SingleTickerProviderStateMixin {
  // Notification tri-state map
  late Map<String, _NotifState> _notifStates;
  bool _notifInitialized = false;

  // For radius animation on the map
  late AnimationController _radiusPulse;

  // Analytics opt-out (LFPDPPP)
  bool _analyticsOn = true;
  bool _analyticsLoading = true;

  @override
  void initState() {
    super.initState();
    _radiusPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _loadAnalyticsPref();
  }

  Future<void> _loadAnalyticsPref() async {
    final userId = SupabaseClientService.currentUserId;
    if (userId == null) return;
    try {
      final data = await SupabaseClientService.client
          .from(BCTables.profiles)
          .select('opted_out_analytics')
          .eq('id', userId)
          .maybeSingle();
      if (mounted) setState(() { _analyticsOn = data?['opted_out_analytics'] != true; _analyticsLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _analyticsLoading = false);
    }
  }

  Future<void> _toggleAnalytics(bool on) async {
    final userId = SupabaseClientService.currentUserId;
    if (userId == null) return;
    setState(() => _analyticsOn = on);
    try {
      await SupabaseClientService.client
          .from(BCTables.profiles)
          .update({'opted_out_analytics': !on})
          .eq('id', userId);
    } catch (_) {
      if (mounted) setState(() => _analyticsOn = !on);
    }
  }

  @override
  void dispose() {
    _radiusPulse.dispose();
    super.dispose();
  }

  void _initNotifStates(UserPrefsState prefs) {
    if (_notifInitialized) return;
    _notifStates = {
      'reminders': prefs.notifyBookingReminders ? _NotifState.sound : _NotifState.silent,
      'confirmations': _NotifState.sound, // Always on -- can't turn off confirmations
      'updates': prefs.notifyAppointmentUpdates ? _NotifState.sound : _NotifState.silent,
      'messages': prefs.notifyMessages ? _NotifState.sound : _NotifState.off,
      'orders': _NotifState.sound, // Default on
      'disputes': _NotifState.sound, // Always on -- can't turn off dispute alerts
      'promos': prefs.notifyPromotions ? _NotifState.silent : _NotifState.off,
    };
    _notifInitialized = true;
  }

  @override
  Widget build(BuildContext context) {
    final prefsState = ref.watch(userPrefsProvider);
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<BCThemeExtension>()!;

    _initNotifStates(prefsState);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Preferencias')),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.screenPaddingHorizontal,
          vertical: AppConstants.paddingMD,
        ),
        children: [
                // Hero banner as card inside page
                _buildHeroBanner(cs, ext),
                const SizedBox(height: AppConstants.paddingLG),

                // ── Preference Dials ──
                _buildPreferenceDials(prefsState, cs, ext),
                const SizedBox(height: AppConstants.paddingLG),

                // ── Live Map + Radius ──
                _buildLiveMap(prefsState, cs, ext),
                const SizedBox(height: AppConstants.paddingLG),

                // ── Location Cards ──
                _buildLocationCards(cs, ext),
                const SizedBox(height: AppConstants.paddingLG),

                // ── Accessibility ──
                _buildAccessibilitySection(cs),
                const SizedBox(height: AppConstants.paddingLG),

                // ── Service modifiers (gated on enable_service_modifiers) ──
                _buildServiceModifiersSection(cs),

                // ── Notifications ──
                _buildNotificationsSection(cs, ext),
                const SizedBox(height: AppConstants.paddingXXL),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 1. Hero Banner
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildHeroBanner(ColorScheme cs, BCThemeExtension ext) {
    final onBrand = Theme.of(context).colorScheme.onPrimary;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingLG,
        vertical: AppConstants.paddingMD + AppConstants.paddingSM,
      ),
      decoration: BoxDecoration(
        gradient: ext.primaryGradient,
        borderRadius: BorderRadius.circular(AppConstants.radiusLG),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MI ESTILO',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: onBrand.withValues(alpha: 0.7),
                  letterSpacing: 1.0,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: AppConstants.paddingXS),
          Text(
            'Personaliza tu experiencia',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: onBrand,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: AppConstants.paddingMD),
          // Analytics opt-out (LFPDPPP) — lives inside the hero so consent
          // is visible before any data-collection-adjacent setting.
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.paddingSM,
              vertical: AppConstants.paddingSM,
            ),
            decoration: BoxDecoration(
              color: onBrand.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppConstants.radiusMD),
              border: Border.all(color: onBrand.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                Icon(Icons.insights_outlined, size: 16,
                    color: onBrand.withValues(alpha: 0.85)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Análisis de actividad',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: onBrand,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Usamos tus patrones de uso para mejorar recomendaciones y detectar fraude. Puedes apagarlo cuando quieras.',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: onBrand.withValues(alpha: 0.7),
                              fontSize: 10,
                              height: 1.3,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                if (_analyticsLoading)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: onBrand,
                    ),
                  )
                else
                  Transform.scale(
                    scale: 0.85,
                    child: Switch(
                      value: _analyticsOn,
                      onChanged: _toggleAnalytics,
                      activeThumbColor: onBrand,
                      activeTrackColor: onBrand.withValues(alpha: 0.35),
                      inactiveThumbColor: onBrand.withValues(alpha: 0.6),
                      inactiveTrackColor: onBrand.withValues(alpha: 0.15),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 2. Preference Dials
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildPreferenceDials(
      UserPrefsState prefs, ColorScheme cs, BCThemeExtension ext) {
    final budgetValue = switch (prefs.priceComfort) {
      'budget' => 0.0,
      'premium' => 1.0,
      _ => 0.5,
    };

    // Map radius to slider value (index into _radiusStops)
    final radiusIdx = _radiusStops.indexOf(_nearestStop(prefs.searchRadiusKm));
    final radiusSliderVal = (radiusIdx < 0 ? 0.0 : radiusIdx.toDouble());

    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PREFERENCIAS',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.5),
                  letterSpacing: 1.0,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: AppConstants.paddingMD),

          // Budget slider
          _buildSliderRow(
            label: 'Presupuesto',
            startLabel: '\$',
            endLabel: '\$\$\$',
            value: budgetValue,
            divisions: 2,
            activeColor: cs.primary,
            valueLabel: _priceLabel(prefs.priceComfort),
            onChanged: (v) {
              final next = v < 0.33 ? 'budget' : v > 0.66 ? 'premium' : 'moderate';
              ref.read(userPrefsProvider.notifier).setPriceComfort(next);

            },
          ),
          const SizedBox(height: AppConstants.paddingSM),

          // Quality vs Speed slider
          _buildSliderRow(
            label: 'Calidad vs Rapidez',
            startLabel: 'Rapido',
            endLabel: 'Calidad',
            value: prefs.qualitySpeed,
            divisions: 2,
            activeColor: cs.secondary,
            valueLabel: _qualityLabel(prefs.qualitySpeed),
            onChanged: (v) {
              // Snap to 0, 0.5, 1.0
              final snapped = v < 0.25 ? 0.0 : v < 0.75 ? 0.5 : 1.0;
              ref.read(userPrefsProvider.notifier).setQualitySpeed(snapped);

            },
          ),
          const SizedBox(height: AppConstants.paddingSM),

          // Explore vs Loyalty slider
          _buildSliderRow(
            label: 'Explorar vs Lealtad',
            startLabel: 'Nuevo',
            endLabel: 'Fiel',
            value: prefs.exploreLoyalty,
            divisions: 2,
            activeColor: ext.infoColor,
            valueLabel: _exploreLabel(prefs.exploreLoyalty),
            onChanged: (v) {
              final snapped = v < 0.25 ? 0.0 : v < 0.75 ? 0.5 : 1.0;
              ref.read(userPrefsProvider.notifier).setExploreLoyalty(snapped);

            },
          ),
          const SizedBox(height: AppConstants.paddingSM),

          // Search radius slider
          _buildSliderRow(
            label: 'Radio de busqueda',
            startLabel: '10km',
            endLabel: '100km',
            value: radiusSliderVal,
            divisions: _radiusStops.length - 1,
            min: 0,
            max: (_radiusStops.length - 1).toDouble(),
            activeColor: ext.successColor,
            valueLabel: _approxRadiusLabel(prefs.searchRadiusKm),
            onChanged: (v) {
              final idx = v.round().clamp(0, _radiusStops.length - 1);
              ref.read(userPrefsProvider.notifier).setSearchRadius(_radiusStops[idx]);

            },
          ),
        ],
      ),
    );
  }

  Widget _buildSliderRow({
    required String label,
    required String startLabel,
    required String endLabel,
    required double value,
    required int divisions,
    required Color activeColor,
    required String valueLabel,
    required ValueChanged<double> onChanged,
    double min = 0.0,
    double max = 1.0,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: activeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppConstants.radiusXS),
              ),
              child: Text(
                valueLabel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: activeColor,
                    ),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Text(
              startLabel,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: activeColor,
                  inactiveTrackColor: activeColor.withValues(alpha: 0.15),
                  thumbColor: activeColor,
                  overlayColor: activeColor.withValues(alpha: 0.12),
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                ),
                child: Slider(
                  value: value.clamp(min, max),
                  min: min,
                  max: max,
                  divisions: divisions,
                  onChanged: onChanged,
                ),
              ),
            ),
            Text(
              endLabel,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
            ),
          ],
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 3. Live Map + Radius
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildLiveMap(
      UserPrefsState prefs, ColorScheme cs, BCThemeExtension ext) {
    const mapHeight = 200.0;
    // Map radius to circle size (10 km -> ~35px, 100 km -> ~160px)
    final radiusFraction = (prefs.searchRadiusKm - 10) / (100 - 10);
    final circleSize = 35.0 + (radiusFraction.clamp(0.0, 1.0) * 125.0);
    final radiusColor = ext.successColor;
    final salonEstimate = (prefs.searchRadiusKm * 3).clamp(5, 300);

    return Column(
      children: [
        // Map container
        ClipRRect(
          borderRadius: BorderRadius.circular(AppConstants.radiusLG),
          child: Container(
            height: mapHeight,
            width: double.infinity,
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(AppConstants.radiusLG),
              border: Border.all(
                color: cs.onSurface.withValues(alpha: 0.08),
              ),
            ),
            child: Stack(
              children: [
                // Real Mapbox map
                _PrefsMapView(
                  radiusKm: prefs.searchRadiusKm,
                  overrideLat: ref.watch(tempSearchLocationProvider)?.lat,
                  overrideLng: ref.watch(tempSearchLocationProvider)?.lng,
                ),
                // Salon scatter dots
                _SalonScatterDots(
                  radiusKm: prefs.searchRadiusKm,
                  circleSize: circleSize,
                  dotColor: cs.primary,
                ),
                // Animated radius circle
                Center(
                  child: AnimatedBuilder(
                    animation: _radiusPulse,
                    builder: (context, child) {
                      final pulse = 1.0 + (_radiusPulse.value * 0.04);
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutCubic,
                        width: circleSize * pulse,
                        height: circleSize * pulse,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: radiusColor.withValues(alpha: 0.12),
                          border: Border.all(
                            color: radiusColor.withValues(alpha: 0.35),
                            width: 1.5,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Center pin
                Center(
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: radiusColor,
                      boxShadow: [
                        BoxShadow(
                          color: radiusColor.withValues(alpha: 0.4),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
                // Salon count badge (bottom right)
                Positioned(
                  bottom: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: 0.92),
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusXS),
                      border: Border.all(
                        color: radiusColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      '$salonEstimate salones',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: radiusColor,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 4. Location Cards
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildLocationCards(ColorScheme cs, BCThemeExtension ext) {
    final tempLoc = ref.watch(tempSearchLocationProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Current location card
        Container(
          padding: const EdgeInsets.all(AppConstants.paddingMD),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(AppConstants.radiusMD),
            border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: ext.primaryGradient,
                  borderRadius:
                      BorderRadius.circular(AppConstants.radiusSM),
                ),
                child: Icon(
                  Icons.my_location_outlined,
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: 18,
                ),
              ),
              const SizedBox(width: AppConstants.paddingMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tu ubicacion actual',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Usando GPS del dispositivo',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.5),
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppConstants.paddingSM),

        // Temp location active card OR dashed "add" card
        if (tempLoc != null)
          _buildActiveTempCard(tempLoc, cs)
        else
          _buildAddTempCard(cs),
      ],
    );
  }

  Widget _buildActiveTempCard(PlaceLocation tempLoc, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.location_on_outlined,
              color: Colors.amber.shade700, size: 22),
          const SizedBox(width: AppConstants.paddingMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tempLoc.address,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Temporal \u2014 se reinicia al cerrar la app',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.amber.shade800,
                        fontSize: 11,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppConstants.paddingSM),
          GestureDetector(
            onTap: () =>
                ref.read(tempSearchLocationProvider.notifier).state = null,
            child: Icon(Icons.close_outlined,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildAddTempCard(ColorScheme cs) {
    final ext = Theme.of(context).extension<BCThemeExtension>()!;
    return GestureDetector(
      onTap: () => _pickTempLocation(context),
      child: Container(
        padding: const EdgeInsets.all(AppConstants.paddingMD),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppConstants.radiusMD),
          border: Border.all(color: ext.cardBorderColor),
        ),
        child: Row(
          children: [
            Icon(Icons.add_location_alt_outlined, color: cs.secondary, size: 20),
            const SizedBox(width: AppConstants.paddingMD),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Buscar desde otro lugar',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cs.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Text(
                    'Viaje, boda, evento...',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.5),
                        ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_outlined, color: cs.onSurface.withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTempLocation(BuildContext context) async {
    final location = await showLocationPicker(
      context: context,
      ref: ref,
      title: 'Buscar desde esta ubicacion',
    );
    if (location != null && mounted) {
      ref.read(tempSearchLocationProvider.notifier).state = location;
      ToastService.showSuccess('Buscando desde: ${location.address}');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 5. Accessibility Section
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildAccessibilitySection(ColorScheme cs) {
    final themeState = ref.watch(themeProvider);

    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ACCESIBILIDAD',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.5),
                  letterSpacing: 1.0,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: AppConstants.paddingMD),

          // Text size: 3 levels
          Text(
            'Tamano de texto',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: AppConstants.paddingSM),
          _TextSizeSelector(
            value: themeState.fontScale,
            cs: cs,
            onChanged: (v) =>
                ref.read(themeProvider.notifier).setFontScale(v),
          ),
          // Reduce animations toggle
          const SizedBox(height: AppConstants.paddingMD),
          Consumer(
            builder: (context, ref, _) {
              final prefs = ref.watch(userPrefsProvider);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.speed_rounded, size: 20, color: cs.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Reducir animaciones',
                            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface)),
                          Text('Transiciones simples para dispositivos lentos',
                            style: GoogleFonts.nunito(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5))),
                        ],
                      ),
                    ),
                    Switch(
                      value: prefs.reduceAnimations,
                      onChanged: (_) => ref.read(userPrefsProvider.notifier).toggleReduceAnimations(),
                      activeThumbColor: cs.primary,
                    ),
                  ],
                ),
              );
            },
          ),

          // Dark mode 3-way toggle
          const SizedBox(height: AppConstants.paddingMD),
          _ThemeModeSelector(
            value: themeState.themeMode,
            cs: cs,
            onChanged: (mode) =>
                ref.read(themeProvider.notifier).setThemeMode(mode),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 5b. Service Modifiers Section (60056, toggle-gated)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildServiceModifiersSection(ColorScheme cs) {
    final toggles = ref.watch(featureTogglesProvider);
    if (!toggles.isEnabled('enable_service_modifiers')) {
      return const SizedBox.shrink();
    }

    final prefsAsync = ref.watch(servicePreferencesProvider);
    final prefs = prefsAsync.valueOrNull ?? ServicePreferences.empty();

    Widget rowToggle({
      required IconData icon,
      required String label,
      required String subtitle,
      required bool value,
      required ValueChanged<bool> onChanged,
    }) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: cs.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        color: cs.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeThumbColor: cs.primary,
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.paddingLG),
      child: Container(
        padding: const EdgeInsets.all(AppConstants.paddingMD),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppConstants.radiusMD),
          border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PREFERENCIAS DE BUSQUEDA',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.5),
                    letterSpacing: 1.0,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: AppConstants.paddingSM),
            rowToggle(
              icon: Icons.child_care_outlined,
              label: 'Tengo hijos pequenos',
              subtitle: 'Prioriza salones con experiencia infantil',
              value: prefs.kidsFriendly,
              onChanged: (v) => updateServicePreferences(
                ref,
                prefs.copyWith(kidsFriendly: v),
              ),
            ),
            rowToggle(
              icon: Icons.accessible_outlined,
              label: 'Necesito ingreso accesible',
              subtitle: 'Solo muestra salones con rampa, acceso silla de ruedas',
              value: prefs.accessibilityRequired,
              onChanged: (v) => updateServicePreferences(
                ref,
                prefs.copyWith(accessibilityRequired: v),
              ),
            ),
            rowToggle(
              icon: Icons.elderly_outlined,
              label: 'Atencion para adultos mayores',
              subtitle: 'Prioriza salones con paciencia y cuidado especial',
              value: prefs.seniorFriendlyOverride == true,
              onChanged: (v) => updateServicePreferences(
                ref,
                prefs.copyWith(seniorFriendlyOverride: v ? true : null),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 6. Notifications Section
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildNotificationsSection(ColorScheme cs, BCThemeExtension ext) {
    // Entries: key, label, icon, canTurnOff
    final entries = <(String, String, IconData, bool)>[
      ('reminders', 'Recordatorios de citas', Icons.calendar_today_outlined, false),
      ('confirmations', 'Confirmacion de reserva', Icons.check_circle_outlined, false),
      ('updates', 'Cambios y reagendamientos', Icons.update_outlined, false),
      ('messages', 'Mensajes', Icons.chat_bubble_outline_rounded, true),
      ('orders', 'Pedidos y envios', Icons.local_shipping_outlined, true),
      ('disputes', 'Disputas y reembolsos', Icons.gavel_outlined, false),
      ('promos', 'Promociones', Icons.local_offer_outlined, true),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'NOTIFICACIONES',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: cs.primary,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
                fontSize: 9,
              ),
        ),
        const SizedBox(height: AppConstants.paddingSM),
        Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(AppConstants.radiusMD),
            border: Border.all(color: ext.cardBorderColor),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).shadowColor.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
              BoxShadow(
                color: Theme.of(context).shadowColor.withValues(alpha: 0.02),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              for (var i = 0; i < entries.length; i++) ...[
                _buildNotifToggleRow(
                  entries[i].$1, entries[i].$2, entries[i].$3, entries[i].$4, cs,
                ),
                if (i < entries.length - 1)
                  Divider(height: 1, thickness: 1, color: cs.onSurface.withValues(alpha: 0.04)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotifToggleRow(
    String key, String label, IconData icon, bool canTurnOff, ColorScheme cs,
  ) {
    final state = _notifStates[key] ?? _NotifState.sound;
    final stateLabel = switch (state) {
      _NotifState.sound => 'Con sonido',
      _NotifState.silent => 'Silencioso',
      _NotifState.off => 'Apagado',
    };
    final stateColor = switch (state) {
      _NotifState.sound => cs.primary,
      _NotifState.silent => cs.secondary,
      _NotifState.off => cs.onSurface.withValues(alpha: 0.3),
    };

    return InkWell(
      onTap: () => _cycleNotifState(key),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.paddingMD,
          vertical: 12,
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: stateColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 16, color: stateColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(stateLabel, style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: stateColor, fontSize: 10, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            // Tri-state indicator dots
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _triDot(state == _NotifState.sound, cs.primary),
                const SizedBox(width: 3),
                _triDot(state == _NotifState.silent, cs.secondary),
                const SizedBox(width: 3),
                if (canTurnOff)
                  _triDot(state == _NotifState.off, cs.onSurface.withValues(alpha: 0.3)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _triDot(bool active, Color color) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: active ? 10 : 6,
      height: active ? 10 : 6,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? color : color.withValues(alpha: 0.15),
        boxShadow: active ? [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 4)] : null,
      ),
    );
  }

  void _cycleNotifState(String key) {
    setState(() {
      final current = _notifStates[key] ?? _NotifState.off;
      // Only messages, orders, and promos can be turned off
      const canTurnOffKeys = {'messages', 'orders', 'promos'};
      final canTurnOff = canTurnOffKeys.contains(key);
      final next = switch (current) {
        _NotifState.sound => _NotifState.silent,
        _NotifState.silent => canTurnOff ? _NotifState.off : _NotifState.sound,
        _NotifState.off => _NotifState.sound,
      };
      _notifStates[key] = next;
    });

    // Persist the boolean state (on = sound or silent, off = off)
    final isOn = _notifStates[key] != _NotifState.off;
    final notifier = ref.read(userPrefsProvider.notifier);
    switch (key) {
      case 'reminders':
        if (isOn != ref.read(userPrefsProvider).notifyBookingReminders) {
          notifier.toggleBookingReminders();
        }
      case 'updates':
        if (isOn != ref.read(userPrefsProvider).notifyAppointmentUpdates) {
          notifier.toggleAppointmentUpdates();
        }
      case 'messages':
        if (isOn != ref.read(userPrefsProvider).notifyMessages) {
          notifier.toggleMessages();
        }
      case 'promos':
        if (isOn != ref.read(userPrefsProvider).notifyPromotions) {
          notifier.togglePromotions();
        }
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
    if (value > 0.65) return 'Calidad';
    return 'Balance';
  }

  static String _exploreLabel(double value) {
    if (value < 0.35) return 'Nuevo';
    if (value > 0.65) return 'Fiel';
    return 'Balance';
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Private Widgets
// ═══════════════════════════════════════════════════════════════════════════

// (_PreferenceDial removed — replaced by Slider widgets)

// (_DialRingPainter removed — replaced by Slider widgets)

// ── Salon Scatter Dots ──────────────────────────────────────────────────────

class _SalonScatterDots extends StatelessWidget {
  final int radiusKm;
  final double circleSize;
  final Color dotColor;

  const _SalonScatterDots({
    required this.radiusKm,
    required this.circleSize,
    required this.dotColor,
  });

  @override
  Widget build(BuildContext context) {
    // Seeded random based on radiusKm so dots are consistent per radius
    final rng = math.Random(radiusKm * 7919 + 42);
    const dotCount = 13;
    final maxOffset = circleSize / 2 * 0.85; // Keep dots within radius circle

    return Center(
      child: SizedBox(
        width: circleSize,
        height: circleSize,
        child: Stack(
          clipBehavior: Clip.none,
          children: List.generate(dotCount, (i) {
            // Random angle and distance from center
            final angle = rng.nextDouble() * 2 * math.pi;
            final dist = rng.nextDouble() * maxOffset;
            final dx = dist * math.cos(angle);
            final dy = dist * math.sin(angle);
            final dotSize = 4.0 + rng.nextDouble() * 2.0; // 4-6px

            return Positioned(
              left: circleSize / 2 + dx - dotSize / 2,
              top: circleSize / 2 + dy - dotSize / 2,
              child: Container(
                width: dotSize,
                height: dotSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor.withValues(alpha: 0.35),
                  boxShadow: [
                    BoxShadow(
                      color: dotColor.withValues(alpha: 0.15),
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ── Real Mapbox Map Widget ──────────────────────────────────────────────────

class _PrefsMapView extends StatefulWidget {
  final int radiusKm;
  final double? overrideLat;
  final double? overrideLng;
  const _PrefsMapView({required this.radiusKm, this.overrideLat, this.overrideLng});

  @override
  State<_PrefsMapView> createState() => _PrefsMapViewState();
}

class _PrefsMapViewState extends State<_PrefsMapView> with TickerProviderStateMixin {
  final _mapController = MapController();
  ll.LatLng _deviceCenter = const ll.LatLng(20.6534, -105.2253); // PV default

  ll.LatLng get _center {
    if (widget.overrideLat != null && widget.overrideLng != null) {
      return ll.LatLng(widget.overrideLat!, widget.overrideLng!);
    }
    return _deviceCenter;
  }

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  @override
  void didUpdateWidget(covariant _PrefsMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.overrideLat != widget.overrideLat ||
        oldWidget.overrideLng != widget.overrideLng ||
        oldWidget.radiusKm != widget.radiusKm) {
      _animatedMove(_center, _zoomForRadius);
    }
  }

  Future<void> _loadLocation() async {
    try {
      final loc = await LocationService.getCurrentLocation();
      if (loc != null && mounted) {
        setState(() {
          _deviceCenter = ll.LatLng(loc.lat, loc.lng);
        });
        _animatedMove(_center, _zoomForRadius);
      }
    } catch (_) {
      // Keep default
    }
  }

  void _animatedMove(ll.LatLng dest, double destZoom) {
    final startLat = _mapController.camera.center.latitude;
    final startLng = _mapController.camera.center.longitude;
    final startZoom = _mapController.camera.zoom;

    final controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    final curve = CurvedAnimation(parent: controller, curve: Curves.easeInOutCubic);

    controller.addListener(() {
      final lat = startLat + (dest.latitude - startLat) * curve.value;
      final lng = startLng + (dest.longitude - startLng) * curve.value;
      final zoom = startZoom + (destZoom - startZoom) * curve.value;
      _mapController.move(ll.LatLng(lat, lng), zoom);
    });
    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) controller.dispose();
    });
    controller.forward();
  }

  String get _tileUrl {
    final token = dotenv.env['MAPBOX_TOKEN'] ?? '';
    if (token.isNotEmpty) {
      return 'https://api.mapbox.com/styles/v1/mapbox/light-v11/tiles/{z}/{x}/{y}@2x?access_token=$token';
    }
    return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  }

  double get _zoomForRadius {
    final km = widget.radiusKm;
    if (km >= 100) return 9;
    if (km >= 80) return 9.5;
    if (km >= 60) return 10;
    if (km >= 50) return 10.3;
    if (km >= 40) return 10.7;
    if (km >= 30) return 11;
    if (km >= 20) return 11.5;
    if (km >= 15) return 12;
    if (km >= 10) return 12.5;
    return 13;
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _center,
          initialZoom: _zoomForRadius,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.none,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: _tileUrl,
            userAgentPackageName: 'com.beautycita',
            maxZoom: 18,
          ),
        ],
      ),
    );
  }
}

// ── Text Size Selector ──────────────────────────────────────────────────────

class _TextSizeSelector extends StatelessWidget {
  final double value;
  final ColorScheme cs;
  final ValueChanged<double> onChanged;

  const _TextSizeSelector({
    required this.value,
    required this.cs,
    required this.onChanged,
  });

  static const _stops = [0.85, 1.0, 1.15];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(3, (i) {
        final isSelected = (_stops[i] - value).abs() < 0.01;
        final fontSize = [13.0, 16.0, 20.0][i];
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(_stops[i]),
            child: AnimatedContainer(
              duration: AppConstants.shortAnimation,
              margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
              padding:
                  const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? cs.primary.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius:
                    BorderRadius.circular(AppConstants.radiusSM),
                border: Border.all(
                  color: isSelected
                      ? cs.primary.withValues(alpha: 0.3)
                      : cs.onSurface.withValues(alpha: 0.1),
                ),
              ),
              child: Center(
                child: Text(
                  'A',
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w400,
                    color: isSelected
                        ? cs.primary
                        : cs.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// 3-way theme mode toggle: System / Light / Dark
class _ThemeModeSelector extends StatelessWidget {
  final ThemeMode value;
  final ColorScheme cs;
  final ValueChanged<ThemeMode> onChanged;

  const _ThemeModeSelector({
    required this.value,
    required this.cs,
    required this.onChanged,
  });

  static const _modes = [ThemeMode.system, ThemeMode.light, ThemeMode.dark];
  static const _icons = [
    Icons.settings_brightness_rounded,
    Icons.light_mode_rounded,
    Icons.dark_mode_rounded,
  ];
  static const _labels = ['Sistema', 'Claro', 'Oscuro'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.contrast_rounded, size: 20, color: cs.primary),
              const SizedBox(width: 12),
              Text(
                'Modo de pantalla',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: List.generate(3, (i) {
              final isSelected = _modes[i] == value;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(_modes[i]),
                  child: AnimatedContainer(
                    duration: AppConstants.shortAnimation,
                    margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? cs.primary.withValues(alpha: 0.1)
                          : Colors.transparent,
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusSM),
                      border: Border.all(
                        color: isSelected
                            ? cs.primary.withValues(alpha: 0.3)
                            : cs.onSurface.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _icons[i],
                          size: 20,
                          color: isSelected
                              ? cs.primary
                              : cs.onSurface.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _labels[i],
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w400,
                            color: isSelected
                                ? cs.primary
                                : cs.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
