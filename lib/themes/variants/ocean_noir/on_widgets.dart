import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

// ─── ONColors: brightness-aware color palette ─────────────────────────────────

class ONColors {
  final Color surface0, surface1, surface2, surface3, surface4;
  final Color cyan, cyanDark, cyanGlow, red, green, teal;
  final Color cardBorder;
  final Color text, textSecondary, textMuted;
  final LinearGradient cyanGradient;

  const ONColors._({
    required this.surface0, required this.surface1, required this.surface2,
    required this.surface3, required this.surface4,
    required this.cyan, required this.cyanDark, required this.cyanGlow,
    required this.red, required this.green, required this.teal,
    required this.cardBorder,
    required this.text, required this.textSecondary, required this.textMuted,
    required this.cyanGradient,
  });

  static const dark = ONColors._(
    surface0: Color(0xFF080C14),
    surface1: Color(0xFF0D1520),
    surface2: Color(0xFF0D2137),
    surface3: Color(0xFF123352),
    surface4: Color(0xFF163C5F),
    cyan: Color(0xFF00E5FF),
    cyanDark: Color(0xFF0D3B54),
    cyanGlow: Color(0xFF00E5FF),
    red: Color(0xFFFF1744),
    green: Color(0xFF00E676),
    teal: Color(0xFF00E676),
    cardBorder: Color(0xFF0D3B54),
    text: Color(0xFFE0F7FA),
    textSecondary: Color(0xFF80DEEA),
    textMuted: Color(0xFF4DD0E1),
    cyanGradient: LinearGradient(
      colors: [Color(0xFF00E5FF), Color(0xFF00E676)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );

  static const light = ONColors._(
    surface0: Color(0xFFF0F8FA),
    surface1: Color(0xFFE5F0F5),
    surface2: Color(0xFFDAEAF0),
    surface3: Color(0xFFD0E0EA),
    surface4: Color(0xFFC5D8E5),
    cyan: Color(0xFF00838F),
    cyanDark: Color(0xFFC5D8E5),
    cyanGlow: Color(0xFF00838F),
    red: Color(0xFFC62828),
    green: Color(0xFF2E7D32),
    teal: Color(0xFF2E7D32),
    cardBorder: Color(0xFFC5D8E5),
    text: Color(0xFF0A1628),
    textSecondary: Color(0xFF3D5570),
    textMuted: Color(0xFF7090A8),
    cyanGradient: LinearGradient(
      colors: [Color(0xFF00838F), Color(0xFF2E7D32)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );

  static ONColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

// ─── Surface elevation constants (Ocean Noir — Cyberpunk HUD) ─────────────────
const onSurface0 = Color(0xFF080C14);
const onSurface1 = Color(0xFF0D1520);
const onSurface2 = Color(0xFF0D2137);
const onCyan = Color(0xFF00E5FF);
const onCyanDark = Color(0xFF0D3B54);
const onCyanGlow = Color(0xFF00E5FF);
const onRed = Color(0xFFFF1744);
const onGreen = Color(0xFF00E676);

// Legacy aliases used in existing code
const onTeal = Color(0xFF00E676);
const onCardBorder = Color(0xFF0D3B54);
const onSurface3 = Color(0xFF123352);
const onSurface4 = Color(0xFF163C5F);

const onCyanGradient = LinearGradient(
  colors: [onCyan, onGreen],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

// ─── ONAngularClipper ─────────────────────────────────────────────────────────

enum _ClipCorner { topRight, topLeft, bottomRight, bottomLeft }

/// CustomClipper that cuts a diagonal corner.
class ONAngularClipper extends CustomClipper<Path> {
  final double clipSize;
  final _ClipCorner corner;

  const ONAngularClipper({
    this.clipSize = 20,
    this.corner = _ClipCorner.topRight,
  });

  @override
  Path getClip(Size size) {
    final path = Path();
    final c = clipSize;
    switch (corner) {
      case _ClipCorner.topRight:
        path.moveTo(0, 0);
        path.lineTo(size.width - c, 0);
        path.lineTo(size.width, c);
        path.lineTo(size.width, size.height);
        path.lineTo(0, size.height);
      case _ClipCorner.topLeft:
        path.moveTo(c, 0);
        path.lineTo(size.width, 0);
        path.lineTo(size.width, size.height);
        path.lineTo(0, size.height);
        path.lineTo(0, c);
      case _ClipCorner.bottomRight:
        path.moveTo(0, 0);
        path.lineTo(size.width, 0);
        path.lineTo(size.width, size.height - c);
        path.lineTo(size.width - c, size.height);
        path.lineTo(0, size.height);
      case _ClipCorner.bottomLeft:
        path.moveTo(0, 0);
        path.lineTo(size.width, 0);
        path.lineTo(size.width, size.height);
        path.lineTo(c, size.height);
        path.lineTo(0, size.height - c);
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(ONAngularClipper old) =>
      old.clipSize != clipSize || old.corner != corner;
}

/// Angular card using ONAngularClipper with optional border overlay.
class ONAngularCard extends StatelessWidget {
  final Widget child;
  final double clipSize;
  final Color? background;
  final EdgeInsetsGeometry? padding;
  final bool showBorder;
  final Color? borderColor;

  const ONAngularCard({
    super.key,
    required this.child,
    this.clipSize = 18,
    this.background,
    this.padding,
    this.showBorder = true,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: ONAngularClipper(clipSize: clipSize),
      child: Container(
        padding: padding ?? const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: background ?? onSurface2,
          border: showBorder
              ? Border.all(
                  color: (borderColor ?? onCyan).withValues(alpha: 0.25),
                  width: 1.0,
                )
              : null,
        ),
        child: child,
      ),
    );
  }
}

// ─── ONScanLine ───────────────────────────────────────────────────────────────

/// Animated horizontal cyan scan line sweeping top-to-bottom inside a container.
class ONScanLine extends StatefulWidget {
  final double height;
  final Duration duration;
  final Color color;

  const ONScanLine({
    super.key,
    this.height = 120,
    this.duration = const Duration(milliseconds: 2000),
    this.color = onCyan,
  });

  @override
  State<ONScanLine> createState() => _ONScanLineState();
}

class _ONScanLineState extends State<ONScanLine>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          return Stack(
            children: [
              Positioned(
                top: _ctrl.value * widget.height,
                left: 0,
                right: 0,
                child: Container(
                  height: 1.5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        widget.color.withValues(alpha: 0.0),
                        widget.color.withValues(alpha: 0.9),
                        widget.color.withValues(alpha: 0.0),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.color.withValues(alpha: 0.5),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── ONTypingText ──────────────────────────────────────────────────────────────

/// Text widget that types out character by character with an optional blinking cursor.
class ONTypingText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration charDelay;
  final Duration startDelay;
  final bool showCursor;
  final VoidCallback? onComplete;

  const ONTypingText({
    super.key,
    required this.text,
    this.style,
    this.charDelay = const Duration(milliseconds: 50),
    this.startDelay = Duration.zero,
    this.showCursor = true,
    this.onComplete,
  });

  @override
  State<ONTypingText> createState() => _ONTypingTextState();
}

class _ONTypingTextState extends State<ONTypingText>
    with SingleTickerProviderStateMixin {
  int _visibleChars = 0;
  bool _cursorVisible = true;
  Timer? _typingTimer;
  Timer? _cursorTimer;
  bool _complete = false;

  @override
  void initState() {
    super.initState();
    _startCursorBlink();
    Future.delayed(widget.startDelay, _startTyping);
  }

  void _startTyping() {
    if (!mounted) return;
    _typingTimer = Timer.periodic(widget.charDelay, (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_visibleChars < widget.text.length) {
          _visibleChars++;
        } else {
          _complete = true;
          t.cancel();
          widget.onComplete?.call();
        }
      });
    });
  }

  void _startCursorBlink() {
    _cursorTimer = Timer.periodic(const Duration(milliseconds: 530), (_) {
      if (!mounted) return;
      setState(() => _cursorVisible = !_cursorVisible);
    });
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _cursorTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shown = widget.text.substring(0, _visibleChars);
    final cursor = widget.showCursor
        ? (_cursorVisible ? '|' : ' ')
        : '';
    return Text(
      '$shown$cursor',
      style: widget.style,
    );
  }
}

// ─── ONHudFrame ───────────────────────────────────────────────────────────────

/// Corner-bracket frame drawn with positioned containers.
/// Creates the ┌─ ─┐ / └─ ─┘ effect.
class ONHudFrame extends StatelessWidget {
  final Widget child;
  final double bracketSize;
  final double bracketThickness;
  final Color color;
  final EdgeInsetsGeometry padding;

  const ONHudFrame({
    super.key,
    required this.child,
    this.bracketSize = 16,
    this.bracketThickness = 1.5,
    this.color = onCyan,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    final b = bracketSize;
    final t = bracketThickness;
    return Stack(
      children: [
        Padding(padding: padding, child: child),
        // Top-left
        Positioned(
          top: 0,
          left: 0,
          child: _Corner(size: b, thickness: t, color: color,
              top: true, left: true),
        ),
        // Top-right
        Positioned(
          top: 0,
          right: 0,
          child: _Corner(size: b, thickness: t, color: color,
              top: true, left: false),
        ),
        // Bottom-left
        Positioned(
          bottom: 0,
          left: 0,
          child: _Corner(size: b, thickness: t, color: color,
              top: false, left: true),
        ),
        // Bottom-right
        Positioned(
          bottom: 0,
          right: 0,
          child: _Corner(size: b, thickness: t, color: color,
              top: false, left: false),
        ),
      ],
    );
  }
}

class _Corner extends StatelessWidget {
  final double size;
  final double thickness;
  final Color color;
  final bool top;
  final bool left;

  const _Corner({
    required this.size,
    required this.thickness,
    required this.color,
    required this.top,
    required this.left,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CornerPainter(
          color: color,
          thickness: thickness,
          top: top,
          left: left,
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;
  final double thickness;
  final bool top;
  final bool left;

  const _CornerPainter({
    required this.color,
    required this.thickness,
    required this.top,
    required this.left,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    final w = size.width;
    final h = size.height;

    if (top && left) {
      canvas.drawLine(const Offset(0, 0), Offset(w, 0), paint);
      canvas.drawLine(const Offset(0, 0), Offset(0, h), paint);
    } else if (top && !left) {
      canvas.drawLine(Offset(0, 0), Offset(w, 0), paint);
      canvas.drawLine(Offset(w, 0), Offset(w, h), paint);
    } else if (!top && left) {
      canvas.drawLine(Offset(0, h), Offset(w, h), paint);
      canvas.drawLine(Offset(0, 0), Offset(0, h), paint);
    } else {
      canvas.drawLine(Offset(0, h), Offset(w, h), paint);
      canvas.drawLine(Offset(w, 0), Offset(w, h), paint);
    }
  }

  @override
  bool shouldRepaint(_CornerPainter old) =>
      old.color != color || old.thickness != thickness;
}

// ─── ONAngularButton ──────────────────────────────────────────────────────────

/// Button with diagonal-clipped top-right corner and cyan border.
class ONAngularButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final double height;
  final Color? color;
  final Color? textColor;
  final bool filled;

  const ONAngularButton({
    super.key,
    required this.label,
    this.onTap,
    this.height = 52,
    this.color,
    this.textColor,
    this.filled = true,
  });

  @override
  State<ONAngularButton> createState() => _ONAngularButtonState();
}

class _ONAngularButtonState extends State<ONAngularButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );
    _scale = Tween(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveColor = widget.color ?? onCyan;
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: ClipPath(
          clipper: const ONAngularClipper(clipSize: 10),
          child: Container(
            height: widget.height,
            decoration: BoxDecoration(
              color: widget.filled
                  ? effectiveColor
                  : effectiveColor.withValues(alpha: 0.08),
              border: Border.all(
                color: effectiveColor.withValues(alpha: 0.7),
                width: 1.0,
              ),
              boxShadow: widget.filled
                  ? [
                      BoxShadow(
                        color: effectiveColor.withValues(alpha: 0.3),
                        blurRadius: 12,
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              widget.label,
              style: GoogleFontsHelper.rajdhani(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: widget.textColor ??
                    (widget.filled ? onSurface0 : effectiveColor),
                letterSpacing: 2.0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── ONDataDots (angular/digital style) ───────────────────────────────────────

/// Three dashes cycling — angular loading indicator.
class ONDataDots extends StatefulWidget {
  const ONDataDots({super.key});

  @override
  State<ONDataDots> createState() => _ONDataDotsState();
}

class _ONDataDotsState extends State<ONDataDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i * 0.25;
            final v =
                ((_ctrl.value - delay) % 1.0).clamp(0.0, 1.0);
            final opacity = (math.sin(v * math.pi)).clamp(0.15, 1.0);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 10,
              height: 2,
              color: onCyan.withValues(alpha: opacity),
            );
          }),
        );
      },
    );
  }
}

// ─── ONPageIndicator ──────────────────────────────────────────────────────────

/// Angular page indicator for a horizontal PageView (dashes, not circles).
class ONPageIndicator extends StatelessWidget {
  final int pageCount;
  final int currentPage;
  final List<String> labels;

  const ONPageIndicator({
    super.key,
    required this.pageCount,
    required this.currentPage,
    this.labels = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(pageCount, (i) {
            final isActive = i == currentPage;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: isActive ? 24 : 10,
              height: 2,
              decoration: BoxDecoration(
                color: isActive
                    ? onCyan
                    : onCyan.withValues(alpha: 0.25),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: onCyan.withValues(alpha: 0.6),
                          blurRadius: 6,
                        ),
                      ]
                    : null,
              ),
            );
          }),
        ),
        if (labels.length == pageCount) ...[
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(pageCount, (i) {
              final isActive = i == currentPage;
              return SizedBox(
                width: 70,
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  style: GoogleFontsHelper.rajdhani(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: isActive
                        ? onCyan
                        : onCyan.withValues(alpha: 0.3),
                  ),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

// ─── ONNeonBorder (legacy compat) ─────────────────────────────────────────────

class ONNeonBorder extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double glowRadius;
  final double borderWidth;
  final Color color;

  const ONNeonBorder({
    super.key,
    required this.child,
    this.borderRadius = 4,
    this.glowRadius = 8,
    this.borderWidth = 1.0,
    this.color = onCyan,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: color.withValues(alpha: 0.7),
          width: borderWidth,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: glowRadius,
          ),
        ],
      ),
      child: child,
    );
  }
}

// ─── ONCyanButton (legacy compat) ─────────────────────────────────────────────

class ONCyanButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final double height;

  const ONCyanButton({
    super.key,
    required this.label,
    this.onTap,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    return ONAngularButton(
      label: label,
      onTap: onTap,
      height: height,
    );
  }
}

// ─── ONCyanDivider (legacy compat) ────────────────────────────────────────────

class ONCyanDivider extends StatelessWidget {
  const ONCyanDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            onCyan.withValues(alpha: 0.0),
            onCyan.withValues(alpha: 0.35),
            onCyan.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }
}

// ─── ONGlitchText (legacy compat) ─────────────────────────────────────────────

class ONGlitchText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration interval;

  const ONGlitchText({
    super.key,
    required this.text,
    this.style,
    this.interval = const Duration(milliseconds: 3500),
  });

  @override
  State<ONGlitchText> createState() => _ONGlitchTextState();
}

class _ONGlitchTextState extends State<ONGlitchText> {
  double _offsetX = 0;
  double _offsetXAlt = 0;

  @override
  void initState() {
    super.initState();
    _scheduleGlitch();
  }

  void _scheduleGlitch() async {
    while (mounted) {
      await Future.delayed(widget.interval);
      if (!mounted) return;
      final rng = math.Random();
      for (int i = 0; i < 4; i++) {
        if (!mounted) return;
        setState(() {
          _offsetX = (rng.nextDouble() - 0.5) * 8;
          _offsetXAlt = (rng.nextDouble() - 0.5) * 6;
        });
        await Future.delayed(const Duration(milliseconds: 50));
      }
      if (mounted) setState(() { _offsetX = 0; _offsetXAlt = 0; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Transform.translate(
          offset: Offset(_offsetX, 0),
          child: Text(
            widget.text,
            style: (widget.style ?? const TextStyle()).copyWith(
              color: onCyan.withValues(alpha: _offsetX.abs() > 0 ? 0.4 : 0.0),
            ),
          ),
        ),
        Transform.translate(
          offset: Offset(_offsetXAlt, 0),
          child: Text(
            widget.text,
            style: (widget.style ?? const TextStyle()).copyWith(
              color: onTeal.withValues(alpha: _offsetXAlt.abs() > 0 ? 0.3 : 0.0),
            ),
          ),
        ),
        Text(widget.text, style: widget.style),
      ],
    );
  }
}

// ─── GoogleFontsHelper ────────────────────────────────────────────────────────

/// Thin wrapper to avoid importing google_fonts in every file that uses on_widgets.dart.
/// The actual screens import google_fonts directly — this is just used internally here.
class GoogleFontsHelper {
  static TextStyle rajdhani({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    List<Shadow>? shadows,
  }) {
    return TextStyle(
      fontFamily: 'Rajdhani',
      package: null,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      shadows: shadows,
    );
  }

  static TextStyle monospace({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: 'FiraCode',
      package: null,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }
}
