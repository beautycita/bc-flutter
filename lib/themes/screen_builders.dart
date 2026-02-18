import 'theme_variant.dart';
import 'variant_config.dart';
import 'variants/rose_gold/rose_gold_config.dart';
import 'variants/black_gold/black_gold_config.dart';
import 'variants/glass/glass_config.dart';
import 'variants/midnight_orchid/mo_config.dart';
import 'variants/ocean_noir/on_config.dart';
import 'variants/cherry_blossom/cb_config.dart';
import 'variants/emerald_luxe/el_config.dart';

/// Returns the variant config for the given theme variant.
ThemeVariantConfig getVariantConfig(ThemeVariant variant) {
  return switch (variant) {
    ThemeVariant.roseGold => RoseGoldConfig(),
    ThemeVariant.blackGold => BlackGoldConfig(),
    ThemeVariant.glass => GlassConfig(),
    ThemeVariant.midnightOrchid => MidnightOrchidConfig(),
    ThemeVariant.oceanNoir => OceanNoirConfig(),
    ThemeVariant.cherryBlossom => CherryBlossomConfig(),
    ThemeVariant.emeraldLuxe => EmeraldLuxeConfig(),
  };
}
