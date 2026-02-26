import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/palettes.dart';
import '../providers/theme_provider.dart';
import '../config/constants.dart';

class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Apariencia')),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.screenPaddingHorizontal,
          vertical: AppConstants.paddingMD,
        ),
        children: [
          Text(
            'Elige tu estilo',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppConstants.paddingMD),

          // ── Theme palette grid ──
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.75,
            ),
            itemCount: allPalettes.length,
            itemBuilder: (context, index) {
              final palette = allPalettes.values.elementAt(index);
              final isSelected = palette.id == themeState.themeId;
              return _ThemePreviewCard(
                palette: palette,
                isSelected: isSelected,
                onTap: () => ref.read(themeProvider.notifier).setTheme(palette.id),
              );
            },
          ),

          const SizedBox(height: AppConstants.paddingLG),

          // ── Theme Mode ──
          _SectionCard(
            title: 'Modo',
            icon: Icons.brightness_6_rounded,
            child: _ThemeModeSelector(
              current: themeState.themeMode,
              onChanged: (mode) => ref.read(themeProvider.notifier).setThemeMode(mode),
            ),
          ),

          const SizedBox(height: AppConstants.paddingMD),

          // ── Font Size ──
          _SectionCard(
            title: 'Tamano de texto',
            icon: Icons.text_fields_rounded,
            child: _FontScaleSlider(
              value: themeState.fontScale,
              onChanged: (v) => ref.read(themeProvider.notifier).setFontScale(v),
            ),
          ),

          const SizedBox(height: AppConstants.paddingMD),

          // ── Corner Roundness ──
          _SectionCard(
            title: 'Redondez de esquinas',
            icon: Icons.rounded_corner_rounded,
            child: _RadiusScaleSlider(
              value: themeState.radiusScale,
              onChanged: (v) => ref.read(themeProvider.notifier).setRadiusScale(v),
            ),
          ),

          const SizedBox(height: AppConstants.paddingMD),

          // ── Animation Speed ──
          _SectionCard(
            title: 'Velocidad de animaciones',
            icon: Icons.speed_rounded,
            child: _AnimSpeedSlider(
              value: themeState.animationSpeed,
              onChanged: (v) => ref.read(themeProvider.notifier).setAnimationSpeed(v),
            ),
          ),

          const SizedBox(height: AppConstants.paddingLG),

          // ── Reset All ──
          Center(
            child: TextButton.icon(
              onPressed: () => ref.read(themeProvider.notifier).resetAll(),
              icon: const Icon(Icons.restart_alt_rounded, size: 20),
              label: Text(
                'Restablecer todo',
                style: TextStyle(color: cs.primary),
              ),
            ),
          ),

          const SizedBox(height: AppConstants.paddingLG),
        ],
      ),
    );
  }
}

// ─── Section card wrapper ───────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(color: cs.outline.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.paddingMD),
          child,
        ],
      ),
    );
  }
}

// ─── Theme Mode selector ────────────────────────────────────────────────────

class _ThemeModeSelector extends StatelessWidget {
  final ThemeMode current;
  final ValueChanged<ThemeMode> onChanged;

  const _ThemeModeSelector({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SegmentedButton<ThemeMode>(
      segments: const [
        ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_rounded, size: 18), label: Text('Claro')),
        ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.settings_brightness_rounded, size: 18), label: Text('Sistema')),
        ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_rounded, size: 18), label: Text('Oscuro')),
      ],
      selected: {current},
      onSelectionChanged: (set) => onChanged(set.first),
      style: SegmentedButton.styleFrom(
        selectedForegroundColor: cs.onPrimary,
        selectedBackgroundColor: cs.primary,
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
              // Snap to nearest stop
              final snapped = _stops.reduce((a, b) => (v - a).abs() < (v - b).abs() ? a : b);
              onChanged(snapped);
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(3, (i) => Text(
            _labels[i],
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: _stops[i] == value ? FontWeight.w700 : FontWeight.w400,
              color: _stops[i] == value
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          )),
        ),
        const SizedBox(height: AppConstants.paddingSM),
        // Live preview
        Text(
          'Vista previa del texto',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    );
  }
}

// ─── Radius scale slider ────────────────────────────────────────────────────

class _RadiusScaleSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _RadiusScaleSlider({required this.value, required this.onChanged});

  static const _stops = [0.5, 0.75, 1.0, 1.25, 1.5];
  static const _labels = ['Angular', '', 'Normal', '', 'Redondo'];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            showValueIndicator: ShowValueIndicator.never,
          ),
          child: Slider(
            value: value,
            min: 0.5,
            max: 1.5,
            divisions: 4,
            onChanged: (v) {
              final snapped = _stops.reduce((a, b) => (v - a).abs() < (v - b).abs() ? a : b);
              onChanged(snapped);
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Angular', style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: value <= 0.5 ? FontWeight.w700 : FontWeight.w400,
              color: value <= 0.5 ? cs.primary : cs.onSurface.withValues(alpha: 0.5),
            )),
            Text('Normal', style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: value == 1.0 ? FontWeight.w700 : FontWeight.w400,
              color: value == 1.0 ? cs.primary : cs.onSurface.withValues(alpha: 0.5),
            )),
            Text('Redondo', style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: value >= 1.5 ? FontWeight.w700 : FontWeight.w400,
              color: value >= 1.5 ? cs.primary : cs.onSurface.withValues(alpha: 0.5),
            )),
          ],
        ),
        const SizedBox(height: AppConstants.paddingSM),
        // Live preview — 3 mini cards with current radius
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(3, (i) => Container(
            width: 64,
            height: 48,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(AppConstants.radiusMD * value),
              border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
            ),
            child: Center(
              child: Icon(
                [Icons.star_rounded, Icons.favorite_rounded, Icons.bookmark_rounded][i],
                size: 20,
                color: cs.primary,
              ),
            ),
          )),
        ),
      ],
    );
  }
}

// ─── Animation speed slider ─────────────────────────────────────────────────

class _AnimSpeedSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _AnimSpeedSlider({required this.value, required this.onChanged});

  static const _stops = [0.5, 1.0, 1.5];
  static const _labels = ['Rapido', 'Normal', 'Lento'];

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
            min: 0.5,
            max: 1.5,
            divisions: 2,
            onChanged: (v) {
              final snapped = _stops.reduce((a, b) => (v - a).abs() < (v - b).abs() ? a : b);
              onChanged(snapped);
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(3, (i) => Text(
            _labels[i],
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: _stops[i] == value ? FontWeight.w700 : FontWeight.w400,
              color: _stops[i] == value
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          )),
        ),
      ],
    );
  }
}

// ─── Theme preview card (unchanged from original) ───────────────────────────

class _ThemePreviewCard extends StatelessWidget {
  final BCPalette palette;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemePreviewCard({
    required this.palette,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppConstants.radiusMD),
          border: Border.all(
            color: isSelected ? palette.primary : palette.divider,
            width: isSelected ? 3 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: palette.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppConstants.radiusMD - 1),
          child: Column(
            children: [
              // Mini phone mockup
              Expanded(
                child: Container(
                  color: palette.scaffoldBackground,
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      // Mini header bar
                      Container(
                        height: 24,
                        decoration: BoxDecoration(
                          gradient: palette.primaryGradient,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Mini cards
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: palette.cardColor,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: palette.cardBorderColor,
                                    width: 0.5,
                                  ),
                                ),
                                child: Center(
                                  child: Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: palette.categoryColors.isNotEmpty
                                          ? palette.categoryColors[0]
                                          : palette.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: palette.cardColor,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: palette.cardBorderColor,
                                    width: 0.5,
                                  ),
                                ),
                                child: Center(
                                  child: Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: palette.categoryColors.length > 1
                                          ? palette.categoryColors[1]
                                          : palette.secondary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Mini button
                      Container(
                        height: 20,
                        decoration: BoxDecoration(
                          color: palette.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Container(
                            width: 30,
                            height: 4,
                            decoration: BoxDecoration(
                              color: palette.onPrimary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Label
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                color: isSelected ? palette.primary : palette.scaffoldBackground,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isSelected) ...[
                      Icon(
                        Icons.check_circle,
                        size: 16,
                        color: palette.onPrimary,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      palette.nameEs,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: isSelected
                                ? palette.onPrimary
                                : palette.textPrimary,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
