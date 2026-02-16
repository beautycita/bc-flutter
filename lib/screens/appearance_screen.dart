import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/palettes.dart';
import '../providers/theme_provider.dart';
import '../config/constants.dart';

class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentThemeId = ref.watch(themeProvider).themeId;
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
              final isSelected = palette.id == currentThemeId;
              return _ThemePreviewCard(
                palette: palette,
                isSelected: isSelected,
                onTap: () => ref.read(themeProvider.notifier).setTheme(palette.id),
              );
            },
          ),
          const SizedBox(height: AppConstants.paddingLG),
          if (currentThemeId != roseGoldPalette.id)
            Center(
              child: TextButton(
                onPressed: () => ref.read(themeProvider.notifier).resetToDefault(),
                child: Text(
                  'Restablecer tema original',
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
