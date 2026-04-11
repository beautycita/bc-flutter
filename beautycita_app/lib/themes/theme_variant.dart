import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_provider.dart';

/// Maps each palette to a unique visual variant with different screen layouts.
enum ThemeVariant {
  rosePink,
  darkAccent,
  glass,
  midnightOrchid,
  oceanNoir,
  cherryBlossom,
  emeraldLuxe,
}

/// Maps a palette ID string to its ThemeVariant enum value.
ThemeVariant variantFromPaletteId(String id) {
  return switch (id) {
    'rose_gold' => ThemeVariant.rosePink,
    'rose_pink' => ThemeVariant.rosePink,
    'black_gold' => ThemeVariant.darkAccent,
    'dark_accent' => ThemeVariant.darkAccent,
    'glass' => ThemeVariant.glass,
    'midnight_orchid' => ThemeVariant.midnightOrchid,
    'ocean_noir' => ThemeVariant.oceanNoir,
    'cherry_blossom' => ThemeVariant.cherryBlossom,
    'emerald_luxe' => ThemeVariant.emeraldLuxe,
    _ => ThemeVariant.rosePink,
  };
}

/// Derives the current ThemeVariant from the active palette.
final currentVariantProvider = Provider<ThemeVariant>((ref) {
  return variantFromPaletteId(ref.watch(themeProvider).themeId);
});
