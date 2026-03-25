import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:beautycita/config/constants.dart';
import 'package:beautycita/config/theme_extension.dart';
import 'package:beautycita/providers/profile_provider.dart';
import 'package:beautycita/providers/theme_provider.dart';
import 'package:beautycita/providers/user_preferences_provider.dart';
import 'package:beautycita/services/location_service.dart';
import 'package:beautycita/services/places_service.dart';
import 'package:beautycita/services/toast_service.dart';
import 'package:beautycita/widgets/location_picker_sheet.dart';

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

  // Radius drag state
  double _radiusDragFraction = 0.0;
  bool _isDraggingRadius = false;

  @override
  void initState() {
    super.initState();
    _radiusPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
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

  double _fractionForRadius(int km) {
    final idx = _radiusStops.indexOf(_nearestStop(km));
    if (idx < 0) return 0.0;
    return idx / (_radiusStops.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    final prefsState = ref.watch(userPrefsProvider);
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<BCThemeExtension>()!;

    _initNotifStates(prefsState);

    // Sync drag fraction when not actively dragging
    if (!_isDraggingRadius) {
      _radiusDragFraction = _fractionForRadius(prefsState.searchRadiusKm);
    }

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
                  color: Colors.white.withValues(alpha: 0.7),
                  letterSpacing: 1.0,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: AppConstants.paddingXS),
          Text(
            'Personaliza tu experiencia',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
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
    final budgetFraction = switch (prefs.priceComfort) {
      'budget' => 0.33,
      'premium' => 1.0,
      _ => 0.66,
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _PreferenceDial(
          label: 'Presupuesto',
          valueLabel: _priceLabel(prefs.priceComfort),
          fraction: budgetFraction,
          color: cs.primary,
          onTap: () {
            final next = switch (prefs.priceComfort) {
              'budget' => 'moderate',
              'moderate' => 'premium',
              _ => 'budget',
            };
            ref.read(userPrefsProvider.notifier).setPriceComfort(next);
            _shiftGradientColor();
          },
        ),
        _PreferenceDial(
          label: 'Calidad',
          valueLabel: _qualityLabel(prefs.qualitySpeed),
          fraction: prefs.qualitySpeed,
          color: cs.secondary,
          onTap: () {
            final current = prefs.qualitySpeed;
            final next = current < 0.35 ? 0.5 : current < 0.65 ? 1.0 : 0.0;
            ref.read(userPrefsProvider.notifier).setQualitySpeed(next);
            _shiftGradientColor();
          },
        ),
        _PreferenceDial(
          label: 'Explorar',
          valueLabel: _exploreLabel(prefs.exploreLoyalty),
          fraction: prefs.exploreLoyalty,
          color: ext.infoColor,
          onTap: () {
            final current = prefs.exploreLoyalty;
            final next = current < 0.35 ? 0.5 : current < 0.65 ? 1.0 : 0.0;
            ref.read(userPrefsProvider.notifier).setExploreLoyalty(next);
            _shiftGradientColor();
          },
        ),
        // Radius dial -- drag-to-rotate instead of tap-to-cycle
        _buildRadiusDial(prefs, ext),
      ],
    );
  }

  Widget _buildRadiusDial(UserPrefsState prefs, BCThemeExtension ext) {
    const size = AppConstants.largeTouchHeight; // 72
    final cs = Theme.of(context).colorScheme;
    final color = ext.successColor;

    return GestureDetector(
      onVerticalDragStart: (_) {
        setState(() => _isDraggingRadius = true);
      },
      onVerticalDragUpdate: (details) {
        setState(() {
          // Drag UP = increase (negative dy), DOWN = decrease (positive dy)
          _radiusDragFraction =
              (_radiusDragFraction - details.delta.dy * 0.002)
                  .clamp(0.0, 1.0);
        });
        // Live-update the actual radius as we drag
        final idx = (_radiusDragFraction * (_radiusStops.length - 1)).round();
        final newKm = _radiusStops[idx.clamp(0, _radiusStops.length - 1)];
        if (newKm != prefs.searchRadiusKm) {
          ref.read(userPrefsProvider.notifier).setSearchRadius(newKm);
        }
      },
      onVerticalDragEnd: (_) {
        // Snap to nearest stop
        final idx = (_radiusDragFraction * (_radiusStops.length - 1)).round();
        final snappedKm = _radiusStops[idx.clamp(0, _radiusStops.length - 1)];
        ref.read(userPrefsProvider.notifier).setSearchRadius(snappedKm);
        setState(() {
          _radiusDragFraction = idx / (_radiusStops.length - 1);
          _isDraggingRadius = false;
        });
        _shiftGradientColor();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(end: _radiusDragFraction),
            duration: _isDraggingRadius
                ? Duration.zero
                : const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, animatedFraction, child) {
              return TweenAnimationBuilder<Color?>(
                tween: ColorTween(end: color),
                duration: const Duration(milliseconds: 500),
                builder: (context, animatedColor, _) {
                  final c = animatedColor ?? color;
                  return Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        center: const Alignment(-0.3, -0.3),
                        radius: 0.8,
                        colors: [
                          Colors.white.withValues(alpha: 0.15),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.08),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.8),
                          blurRadius: 2,
                          offset: const Offset(0, -1),
                        ),
                      ],
                      border: Border.all(
                        color: cs.onSurface.withValues(alpha: 0.08),
                        width: 1,
                      ),
                    ),
                    child: CustomPaint(
                      painter: _DialRingPainter(
                        fraction: animatedFraction,
                        trackColor: cs.surface,
                        fillColor: c,
                      ),
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: AppConstants.paddingXS),
          Text(
            _approxRadiusLabel(prefs.searchRadiusKm),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface.withValues(alpha: 0.6),
                ),
          ),
        ],
      ),
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
                child: const Icon(
                  Icons.my_location_outlined,
                  color: Colors.white,
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
                color: Colors.grey.shade500, size: 20),
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
          // High contrast and reduce animations removed -- not implemented yet
        ],
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
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
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

  // ── Color shift on preference change ──

  void _shiftGradientColor() {
    final rng = math.Random();
    final hue = rng.nextDouble() * 360;
    // Keep saturation high for vibrant colors
    final sat = 0.7 + (rng.nextDouble() * 0.3); // 0.7-1.0
    ref.read(themeProvider.notifier).setCustomColorLive(hue, sat);
    ref.read(themeProvider.notifier).saveCustomColor();
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

// ── Preference Dial ─────────────────────────────────────────────────────────

class _PreferenceDial extends StatelessWidget {
  final String label;
  final String valueLabel;
  final double fraction;
  final Color color;
  final VoidCallback onTap;

  const _PreferenceDial({
    required this.label,
    required this.valueLabel,
    required this.fraction,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const size = AppConstants.largeTouchHeight; // 72
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(end: fraction),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, animatedFraction, child) {
              return TweenAnimationBuilder<Color?>(
                tween: ColorTween(end: color),
                duration: const Duration(milliseconds: 500),
                builder: (context, animatedColor, _) {
                  final c = animatedColor ?? color;
                  return Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        center: const Alignment(-0.3, -0.3),
                        radius: 0.8,
                        colors: [
                          Colors.white.withValues(alpha: 0.15),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.08),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.8),
                          blurRadius: 2,
                          offset: const Offset(0, -1),
                        ),
                      ],
                      border: Border.all(
                        color: cs.onSurface.withValues(alpha: 0.08),
                        width: 1,
                      ),
                    ),
                    child: CustomPaint(
                      painter: _DialRingPainter(
                        fraction: animatedFraction,
                        trackColor: cs.surface,
                        fillColor: c,
                      ),
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: AppConstants.paddingXS),
          Text(
            valueLabel,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface.withValues(alpha: 0.6),
                ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface.withValues(alpha: 0.4),
                  fontSize: 10,
                ),
          ),
        ],
      ),
    );
  }
}

// ── Dial Ring Painter ───────────────────────────────────────────────────────

class _DialRingPainter extends CustomPainter {
  final double fraction;
  final Color trackColor;
  final Color fillColor;

  _DialRingPainter({
    required this.fraction,
    required this.trackColor,
    required this.fillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - 4;
    const strokeWidth = 5.0;

    // Outer ring (subtle border with shadow feel)
    final outerRingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = fillColor.withValues(alpha: 0.12);
    canvas.drawCircle(center, radius + 3, outerRingPaint);

    // Track
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = trackColor
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // Inset shadow ring (darker ring inside for depth)
    final insetPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.black.withValues(alpha: 0.05);
    canvas.drawCircle(center, radius - strokeWidth / 2 - 1, insetPaint);

    // Fill arc
    final fillPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = fillColor
      ..strokeCap = StrokeCap.round;
    final sweepAngle = 2 * math.pi * fraction.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // Start from top
      sweepAngle,
      false,
      fillPaint,
    );

    // Notch indicator (raised bump at the end of the arc)
    final notchAngle = -math.pi / 2 + sweepAngle;
    final notchX = center.dx + radius * math.cos(notchAngle);
    final notchY = center.dy + radius * math.sin(notchAngle);
    final notchCenter = Offset(notchX, notchY);

    // Notch shadow (gives raised feel)
    final notchShadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawCircle(
      notchCenter + const Offset(0, 1),
      5,
      notchShadowPaint,
    );

    // Notch body
    final notchPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(notchCenter, 4.5, notchPaint);

    // Notch highlight (top-left light reflection)
    final notchHighlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      notchCenter + const Offset(-1, -1),
      2,
      notchHighlightPaint,
    );

    // Radial gradient fill for dial face (highlight top-left, shadow bottom-right)
    final facePaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.3),
        radius: 0.9,
        colors: [
          Colors.white.withValues(alpha: 0.06),
          Colors.transparent,
          Colors.black.withValues(alpha: 0.04),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius - strokeWidth))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius - strokeWidth, facePaint);
  }

  @override
  bool shouldRepaint(covariant _DialRingPainter old) =>
      old.fraction != fraction ||
      old.trackColor != trackColor ||
      old.fillColor != fillColor;
}

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
