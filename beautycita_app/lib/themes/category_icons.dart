import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme_variant.dart';

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Returns a themed icon widget for the given [categoryId] and [variant].
Widget getCategoryIcon({
  required ThemeVariant variant,
  required String categoryId,
  required Color color,
  required double size,
}) {
  final icon = _categoryIcon(categoryId);

  switch (variant) {
    case ThemeVariant.roseGold:
      return Icon(icon, color: color, size: size);

    case ThemeVariant.blackGold:
      return _GoldShaderIcon(icon: icon, size: size);

    case ThemeVariant.glass:
      return _NeonGlowIcon(icon: icon, color: color, size: size);

    case ThemeVariant.midnightOrchid:
      return _OrchidShaderIcon(icon: icon, size: size);

    case ThemeVariant.oceanNoir:
      return _AngularIcon(icon: icon, color: color, size: size);

    case ThemeVariant.cherryBlossom:
      return _DuotoneIcon(icon: icon, color: color, size: size);

    case ThemeVariant.emeraldLuxe:
      return _HexIcon(icon: icon, color: color, size: size);
  }
}

// ---------------------------------------------------------------------------
// Icon mapping — Flutter built-in Icons.* only (zero external packages)
// ---------------------------------------------------------------------------

IconData _categoryIcon(String categoryId) {
  switch (categoryId) {
    case 'nails':
      return Icons.spa;
    case 'hair':
      return Icons.content_cut;
    case 'lashes_brows':
      return Icons.visibility;
    case 'makeup':
      return Icons.brush;
    case 'facial':
      return Icons.face_retouching_natural;
    case 'body_spa':
      return Icons.self_improvement;
    case 'specialized':
      return Icons.science;
    case 'barberia':
      return Icons.content_cut;
    default:
      return Icons.spa;
  }
}

// ---------------------------------------------------------------------------
// Black Gold — ShaderMask with metallic gold gradient
// ---------------------------------------------------------------------------

class _GoldShaderIcon extends StatelessWidget {
  const _GoldShaderIcon({required this.icon, required this.size});
  final IconData icon;
  final double size;

  static const _goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF8B6914), Color(0xFFD4AF37), Color(0xFFFFD700)],
  );

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => _goldGradient.createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: Icon(icon, color: Colors.white, size: size),
    );
  }
}

// ---------------------------------------------------------------------------
// Glass — neon glow via BoxShadow
// ---------------------------------------------------------------------------

class _NeonGlowIcon extends StatelessWidget {
  const _NeonGlowIcon({required this.icon, required this.color, required this.size});
  final IconData icon;
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
          BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 12, spreadRadius: 4),
          BoxShadow(color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.3), blurRadius: 4, spreadRadius: 1),
        ],
      ),
      child: Center(
        child: Icon(icon, color: color, size: size * 0.72),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Midnight Orchid — ShaderMask with purple-pink gradient
// ---------------------------------------------------------------------------

class _OrchidShaderIcon extends StatelessWidget {
  const _OrchidShaderIcon({required this.icon, required this.size});
  final IconData icon;
  final double size;

  static const _orchidGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF7B1FA2), Color(0xFFE040FB)],
  );

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => _orchidGradient.createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: Icon(icon, color: Colors.white, size: size),
    );
  }
}

// ---------------------------------------------------------------------------
// Ocean Noir — angular diamond border with icon inside
// ---------------------------------------------------------------------------

class _AngularIcon extends StatelessWidget {
  const _AngularIcon({required this.icon, required this.color, required this.size});
  final IconData icon;
  final Color color;
  final double size;

  static const _cyanBorder = Color(0xFF00E5FF);

  @override
  Widget build(BuildContext context) {
    final containerSize = size + 8;
    return CustomPaint(
      painter: _AngularBorderPainter(borderColor: _cyanBorder.withValues(alpha: 0.4), size: containerSize),
      child: SizedBox(
        width: containerSize,
        height: containerSize,
        child: Center(child: Icon(icon, color: color, size: size * 0.72)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cherry Blossom — duotone effect via stacked icons at different opacities
// ---------------------------------------------------------------------------

class _DuotoneIcon extends StatelessWidget {
  const _DuotoneIcon({required this.icon, required this.color, required this.size});
  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(icon, color: color.withValues(alpha: 0.35), size: size),
        Icon(icon, color: color, size: size * 0.85),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Emerald Luxe — hexagonal border with icon inside
// ---------------------------------------------------------------------------

class _HexIcon extends StatelessWidget {
  const _HexIcon({required this.icon, required this.color, required this.size});
  final IconData icon;
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
        child: Center(child: Icon(icon, color: color, size: size * 0.70)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Custom painters (unchanged)
// ---------------------------------------------------------------------------

class _AngularBorderPainter extends CustomPainter {
  const _AngularBorderPainter({required this.borderColor, required this.size});
  final Color borderColor;
  final double size;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final paint = Paint()..color = borderColor..style = PaintingStyle.stroke..strokeWidth = 1.0;
    final bg = Paint()..color = const Color(0xFF0D2137)..style = PaintingStyle.fill;
    final cx = canvasSize.width / 2;
    final cy = canvasSize.height / 2;
    final half = size / 2;
    final path = Path()
      ..moveTo(cx, cy - half)..lineTo(cx + half, cy)
      ..lineTo(cx, cy + half)..lineTo(cx - half, cy)..close();
    canvas.drawPath(path, bg);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_AngularBorderPainter old) => old.borderColor != borderColor || old.size != size;
}

class _HexBorderPainter extends CustomPainter {
  const _HexBorderPainter({required this.accentColor, required this.size});
  final Color accentColor;
  final double size;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final cx = canvasSize.width / 2;
    final cy = canvasSize.height / 2;
    final r = size / 2;
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (math.pi / 3) * i - math.pi / 6;
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);
      if (i == 0) { path.moveTo(x, y); } else { path.lineTo(x, y); }
    }
    path.close();
    final gradient = LinearGradient(
      begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [const Color(0xFF00C853), accentColor, const Color(0xFFFFD700)],
    );
    final paint = Paint()
      ..shader = gradient.createShader(Rect.fromCenter(center: Offset(cx, cy), width: size, height: size))
      ..style = PaintingStyle.stroke..strokeWidth = 1.5;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_HexBorderPainter old) => old.accentColor != accentColor || old.size != size;
}
