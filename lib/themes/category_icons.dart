import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'theme_variant.dart';

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Returns a themed icon widget for the given [categoryId] and [variant].
///
/// [color] is the category accent color from the active palette.
/// [size]  controls the base icon size.
Widget getCategoryIcon({
  required ThemeVariant variant,
  required String categoryId,
  required Color color,
  required double size,
}) {
  switch (variant) {
    case ThemeVariant.roseGold:
      return _RoseGoldIcon(categoryId: categoryId, color: color, size: size);
    case ThemeVariant.blackGold:
      return _BlackGoldIcon(categoryId: categoryId, color: color, size: size);
    case ThemeVariant.glass:
      return _GlassIcon(categoryId: categoryId, color: color, size: size);
    case ThemeVariant.midnightOrchid:
      return _MidnightOrchidIcon(
          categoryId: categoryId, color: color, size: size);
    case ThemeVariant.oceanNoir:
      return _OceanNoirIcon(categoryId: categoryId, color: color, size: size);
    case ThemeVariant.cherryBlossom:
      return _CherryBlossomIcon(
          categoryId: categoryId, color: color, size: size);
    case ThemeVariant.emeraldLuxe:
      return _EmeraldLuxeIcon(categoryId: categoryId, color: color, size: size);
  }
}

// ---------------------------------------------------------------------------
// Icon data helpers — Phosphor (PhosphorIcons.<name>(style))
// ---------------------------------------------------------------------------

PhosphorIconData _phosphorIcon(String categoryId, PhosphorIconsStyle style) {
  switch (categoryId) {
    case 'nails':
      return PhosphorIcons.hand(style);
    case 'hair':
      return PhosphorIcons.scissors(style);
    case 'lashes_brows':
      return PhosphorIcons.eye(style);
    case 'makeup':
      return PhosphorIcons.palette(style);
    case 'facial':
      return PhosphorIcons.sparkle(style);
    case 'body_spa':
      return PhosphorIcons.flowerLotus(style);
    case 'specialized':
      return PhosphorIcons.drop(style);
    case 'barberia':
      // Phosphor has no barber-specific icon; scissors is the closest match.
      return PhosphorIcons.scissors(style);
    default:
      return PhosphorIcons.sparkle(style);
  }
}

// ---------------------------------------------------------------------------
// Hugeicons helper
// ---------------------------------------------------------------------------

IconData _hugeIcon(String categoryId) {
  switch (categoryId) {
    case 'nails':
      return HugeIcons.strokeRoundedHairClips; // fingers/nails theme
    case 'hair':
      return HugeIcons.strokeRoundedHairDryer;
    case 'lashes_brows':
      return HugeIcons.strokeRoundedEye;
    case 'makeup':
      return HugeIcons.strokeRoundedBlushBrush01;
    case 'facial':
      return HugeIcons.strokeRoundedSparkles;
    case 'body_spa':
      return HugeIcons.strokeRoundedFlower;
    case 'specialized':
      return HugeIcons.strokeRoundedMedicine01;
    case 'barberia':
      return HugeIcons.strokeRoundedChairBarber;
    default:
      return HugeIcons.strokeRoundedSparkles;
  }
}

// ---------------------------------------------------------------------------
// Material Symbols helper
// ---------------------------------------------------------------------------

IconData _symbolIcon(String categoryId) {
  switch (categoryId) {
    case 'nails':
      return Symbols.spa_rounded;
    case 'hair':
      return Symbols.content_cut_rounded;
    case 'lashes_brows':
      return Symbols.visibility_rounded;
    case 'makeup':
      return Symbols.brush_rounded;
    case 'facial':
      return Symbols.face_retouching_natural_rounded;
    case 'body_spa':
      return Symbols.self_improvement_rounded;
    case 'specialized':
      return Symbols.science_rounded;
    case 'barberia':
      return Symbols.content_cut_rounded;
    default:
      return Symbols.spa_rounded;
  }
}

// ---------------------------------------------------------------------------
// Rose Gold — Phosphor Light, plain Icon with category color
// ---------------------------------------------------------------------------

class _RoseGoldIcon extends StatelessWidget {
  const _RoseGoldIcon({
    required this.categoryId,
    required this.color,
    required this.size,
  });

  final String categoryId;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Icon(
      _phosphorIcon(categoryId, PhosphorIconsStyle.light),
      color: color,
      size: size,
    );
  }
}

// ---------------------------------------------------------------------------
// Black Gold — Phosphor Bold, ShaderMask with metallic gold gradient
// ---------------------------------------------------------------------------

class _BlackGoldIcon extends StatelessWidget {
  const _BlackGoldIcon({
    required this.categoryId,
    required this.color,
    required this.size,
  });

  final String categoryId;
  final Color color;
  final double size;

  static const _goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF8B6914),
      Color(0xFFD4AF37),
      Color(0xFFFFD700),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => _goldGradient.createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: Icon(
        _phosphorIcon(categoryId, PhosphorIconsStyle.bold),
        color: Colors.white, // masked by shader
        size: size,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Glass — Hugeicons stroke, neon glow via BoxShadow on a Container
// ---------------------------------------------------------------------------

class _GlassIcon extends StatelessWidget {
  const _GlassIcon({
    required this.categoryId,
    required this.color,
    required this.size,
  });

  final String categoryId;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          // Colored outer glow
          BoxShadow(
            color: color.withValues(alpha: 0.5),
            blurRadius: 12,
            spreadRadius: 4,
          ),
          // White inner core glow
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.3),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Icon(
        _hugeIcon(categoryId),
        color: color,
        size: size * 0.72,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Midnight Orchid — Phosphor Fill, ShaderMask with purple-pink gradient
// ---------------------------------------------------------------------------

class _MidnightOrchidIcon extends StatelessWidget {
  const _MidnightOrchidIcon({
    required this.categoryId,
    required this.color,
    required this.size,
  });

  final String categoryId;
  final Color color;
  final double size;

  static const _orchidGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF7B1FA2),
      Color(0xFFE040FB),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => _orchidGradient.createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: Icon(
        _phosphorIcon(categoryId, PhosphorIconsStyle.fill),
        color: Colors.white, // masked by shader
        size: size,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Ocean Noir — Material Symbols Rounded, inside angular-clipped container
// ---------------------------------------------------------------------------

class _OceanNoirIcon extends StatelessWidget {
  const _OceanNoirIcon({
    required this.categoryId,
    required this.color,
    required this.size,
  });

  final String categoryId;
  final Color color;
  final double size;

  static const _cyanBorder = Color(0xFF00E5FF);
  static const _darkBg = Color(0xFF0D2137);

  @override
  Widget build(BuildContext context) {
    final containerSize = size + 8;
    return CustomPaint(
      painter: _AngularBorderPainter(
        borderColor: _cyanBorder.withValues(alpha: 0.4),
        size: containerSize,
      ),
      child: SizedBox(
        width: containerSize,
        height: containerSize,
        child: Center(
          child: Icon(
            _symbolIcon(categoryId),
            color: color,
            size: size * 0.72,
          ),
        ),
      ),
    );
  }
}

class _AngularBorderPainter extends CustomPainter {
  const _AngularBorderPainter({
    required this.borderColor,
    required this.size,
  });

  final Color borderColor;
  final double size;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final paint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final bg = Paint()
      ..color = const Color(0xFF0D2137)
      ..style = PaintingStyle.fill;

    // Simple diamond/rhombus shape
    final cx = canvasSize.width / 2;
    final cy = canvasSize.height / 2;
    final half = size / 2;
    final path = Path()
      ..moveTo(cx, cy - half)
      ..lineTo(cx + half, cy)
      ..lineTo(cx, cy + half)
      ..lineTo(cx - half, cy)
      ..close();

    canvas.drawPath(path, bg);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_AngularBorderPainter old) =>
      old.borderColor != borderColor || old.size != size;
}

// ---------------------------------------------------------------------------
// Cherry Blossom — Phosphor Duotone, soft colors, no extra wrapper
// ---------------------------------------------------------------------------

class _CherryBlossomIcon extends StatelessWidget {
  const _CherryBlossomIcon({
    required this.categoryId,
    required this.color,
    required this.size,
  });

  final String categoryId;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return PhosphorIcon(
      _phosphorIcon(categoryId, PhosphorIconsStyle.duotone),
      color: color,
      size: size,
      duotoneSecondaryColor: color.withValues(alpha: 0.35),
      duotoneSecondaryOpacity: 1.0,
    );
  }
}

// ---------------------------------------------------------------------------
// Emerald Luxe — Phosphor Bold inside a hexagonal CustomPainter border
// ---------------------------------------------------------------------------

class _EmeraldLuxeIcon extends StatelessWidget {
  const _EmeraldLuxeIcon({
    required this.categoryId,
    required this.color,
    required this.size,
  });

  final String categoryId;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final outerSize = size + 12;
    return CustomPaint(
      painter: _HexBorderPainter(accentColor: color, size: outerSize),
      child: SizedBox(
        width: outerSize,
        height: outerSize,
        child: Center(
          child: Icon(
            _phosphorIcon(categoryId, PhosphorIconsStyle.bold),
            color: color,
            size: size * 0.70,
          ),
        ),
      ),
    );
  }
}

class _HexBorderPainter extends CustomPainter {
  const _HexBorderPainter({
    required this.accentColor,
    required this.size,
  });

  final Color accentColor;
  final double size;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final cx = canvasSize.width / 2;
    final cy = canvasSize.height / 2;
    final r = size / 2;

    // Build hexagon path (flat-top orientation)
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (math.pi / 3) * i - math.pi / 6;
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    // Gradient stroke — emerald to gold
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        const Color(0xFF00C853), // emerald
        accentColor,
        const Color(0xFFFFD700), // gold
      ],
    );

    final paint = Paint()
      ..shader = gradient.createShader(
          Rect.fromCenter(center: Offset(cx, cy), width: size, height: size))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_HexBorderPainter old) =>
      old.accentColor != accentColor || old.size != size;
}
