import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';
import 'flare_particle_painter.dart';

class CinematicQuestionText extends StatefulWidget {
  final String text;
  final Color primaryColor;
  final Color accentColor;
  final double fontSize;
  final Duration entranceDuration;
  final Duration flareDuration;

  const CinematicQuestionText({
    super.key,
    required this.text,
    this.primaryColor = BeautyCitaTheme.primaryRose,
    this.accentColor = BeautyCitaTheme.secondaryGold,
    this.fontSize = 28,
    this.entranceDuration = const Duration(milliseconds: 1200),
    this.flareDuration = const Duration(milliseconds: 800),
  });

  @override
  State<CinematicQuestionText> createState() => _CinematicQuestionTextState();
}

class _CinematicQuestionTextState extends State<CinematicQuestionText>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late AnimationController _flareController;
  late AnimationController _floatController;
  late int _particleSeed;

  @override
  void initState() {
    super.initState();
    _particleSeed = DateTime.now().millisecondsSinceEpoch;

    _entranceController = AnimationController(
      duration: widget.entranceDuration,
      vsync: this,
    );

    _flareController = AnimationController(
      duration: widget.flareDuration,
      vsync: this,
    );

    _floatController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _startSequence();
  }

  void _startSequence() {
    _entranceController.forward();

    // Start flare burst at 65% through entrance
    final flareDelay = widget.entranceDuration * 0.65;
    Future.delayed(flareDelay, () {
      if (mounted) _flareController.forward();
    });

    // Start float loop after entrance completes
    Future.delayed(widget.entranceDuration + const Duration(milliseconds: 200), () {
      if (mounted) _floatController.repeat(reverse: true);
    });
  }

  @override
  void didUpdateWidget(CinematicQuestionText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _particleSeed = DateTime.now().millisecondsSinceEpoch;
      _entranceController.reset();
      _flareController.reset();
      _floatController.stop();
      _floatController.reset();
      _startSequence();
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _flareController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.85, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOut),
            ),
            child: child,
          ),
        );
      },
      child: _CinematicContent(
        key: ValueKey(widget.text),
        text: widget.text,
        primaryColor: widget.primaryColor,
        accentColor: widget.accentColor,
        fontSize: widget.fontSize,
        entranceController: _entranceController,
        flareController: _flareController,
        floatController: _floatController,
        particleSeed: _particleSeed,
      ),
    );
  }
}

class _CinematicContent extends StatelessWidget {
  final String text;
  final Color primaryColor;
  final Color accentColor;
  final double fontSize;
  final AnimationController entranceController;
  final AnimationController flareController;
  final AnimationController floatController;
  final int particleSeed;

  const _CinematicContent({
    super.key,
    required this.text,
    required this.primaryColor,
    required this.accentColor,
    required this.fontSize,
    required this.entranceController,
    required this.flareController,
    required this.floatController,
    required this.particleSeed,
  });

  @override
  Widget build(BuildContext context) {
    final characters = text.characters.toList();
    final totalChars = characters.length;
    // Stagger: 40ms per char within the entrance duration
    final staggerFraction = totalChars > 1
        ? (40.0 * totalChars) / entranceController.duration!.inMilliseconds
        : 0.5;

    return AnimatedBuilder(
      animation: Listenable.merge([entranceController, flareController, floatController]),
      builder: (context, _) {
        // Float offset: gentle 2px up/down
        final floatOffset = floatController.isAnimating
            ? sin(floatController.value * pi) * 2.0
            : 0.0;

        return Transform.translate(
          offset: Offset(0, floatOffset),
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Flare particles behind text
              if (flareController.value > 0 && flareController.value < 1)
                Positioned.fill(
                  child: CustomPaint(
                    painter: FlareParticlePainter(
                      progress: flareController.value,
                      accentColor: accentColor,
                      particleCount: 12,
                      seed: particleSeed,
                    ),
                  ),
                ),

              // Character-by-character text with 3D fly-in + realistic 24kt polished gold shader
              ShaderMask(
                shaderCallback: (bounds) {
                  return const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF8B6914), // Deep shadow edge
                      Color(0xFFD4AF37), // Rich gold
                      Color(0xFFFFF8DC), // Bright highlight (cornsilk)
                      Color(0xFFFFD700), // Pure gold
                      Color(0xFFC19A26), // Mid gold
                      Color(0xFFF5D547), // Light gold
                      Color(0xFFFFFFE0), // Near-white specular
                      Color(0xFFD4AF37), // Rich gold
                      Color(0xFFA67C00), // Bronze shadow
                      Color(0xFFCDAD38), // Warm gold
                      Color(0xFFFFF8DC), // Bright highlight
                      Color(0xFFB8860B), // Dark goldenrod
                      Color(0xFF8B6914), // Deep shadow edge
                    ],
                    stops: [0.0, 0.08, 0.15, 0.25, 0.35, 0.45, 0.50, 0.58, 0.68, 0.78, 0.85, 0.93, 1.0],
                  ).createShader(bounds);
                },
                blendMode: BlendMode.srcIn,
                child: _buildCharacterRow(characters, totalChars, staggerFraction),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCharacterRow(List<String> characters, int totalChars, double staggerFraction) {
    // Split text into words so wrapping only happens at word boundaries
    final words = text.split(' ');
    int charIndex = 0;

    Widget textContent = Wrap(
      alignment: WrapAlignment.center,
      children: words.map((word) {
        final wordChars = word.characters.toList();
        final wordWidgets = <Widget>[];

        for (final char in wordChars) {
          final i = charIndex;
          charIndex++;

          final charStart = totalChars > 1
              ? (i / totalChars) * staggerFraction.clamp(0.0, 0.85)
              : 0.0;
          final charEnd = (charStart + (1.0 - staggerFraction.clamp(0.0, 0.85))).clamp(0.0, 1.0);

          final charProgress = Interval(
            charStart,
            charEnd,
            curve: Curves.easeOutBack,
          ).transform(entranceController.value);

          final zOffset = -200.0 * (1.0 - charProgress);
          final xRotation = (pi / 6) * (1.0 - charProgress);
          final yRotation = (pi / 8) * (1.0 - charProgress) * (i.isEven ? 1 : -1);
          final opacity = charProgress.clamp(0.0, 1.0);

          final matrix = Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..translate(0.0, 0.0, zOffset)
            ..rotateX(xRotation)
            ..rotateY(yRotation);

          wordWidgets.add(Opacity(
            opacity: opacity,
            child: Transform(
              transform: matrix,
              alignment: Alignment.center,
              child: Text(
                char,
                style: GoogleFonts.poppins(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.2,
                ),
              ),
            ),
          ));
        }

        // Account for the space character between words
        charIndex++;

        // Row keeps word characters together; trailing space allows Wrap to break between words
        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: wordWidgets,
          ),
        );
      }).toList(),
    );

    // Continuous gold specular sweep — like light catching polished 24kt
    if (entranceController.isCompleted) {
      textContent = textContent
          .animate(onPlay: (controller) => controller.repeat())
          .shimmer(
            duration: const Duration(milliseconds: 3000),
            color: const Color(0xFFFFF8DC).withValues(alpha: 0.6),
            delay: const Duration(milliseconds: 500),
          );
    }

    return textContent;
  }
}
