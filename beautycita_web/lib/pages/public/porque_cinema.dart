import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

// ── Design Tokens ────────────────────────────────────────────────────────────

const _white = Color(0xFFFFFFFF);
const _textDark = Color(0xFF1A1A1A);
const _textMid = Color(0xFF666666);
const _textLight = Color(0xFF999999);
const _brandPink = Color(0xFFEC4899);
const _brandPurple = Color(0xFF9333EA);
const _brandBlue = Color(0xFF3B82F6);
const _green = Color(0xFF16A34A);
const _red = Color(0xFFEF4444);
const _brandGradient = LinearGradient(
  colors: [_brandPink, _brandPurple, _brandBlue],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

/// Responsive font scale — larger screens get larger text.
/// 375px (small phone) → 1.0x, 768px (tablet) → 1.3x, 1440px (desktop) → 1.8x
class _S {
  final double width;
  const _S(this.width);

  double get scale => (width / 500).clamp(0.85, 2.2);

  // Title sizes
  double get hero => 32 * scale;
  double get h1 => 28 * scale;
  double get h2 => 22 * scale;

  // Body sizes
  double get body => 16 * scale;
  double get bodySmall => 14 * scale;
  double get caption => 12 * scale;

  // Padding
  double get hPad => (width * 0.06).clamp(20, 80);
  double get maxContent => (width * 0.65).clamp(340, 900);
}

// ── Scene Content ────────────────────────────────────────────────────────────

class _Line {
  final String text;
  final Color? color;
  final bool bold;
  const _Line(this.text, {this.color, this.bold = false});
}

class _Scene {
  final String title;
  final List<_Line> lines;
  final Duration holdDuration;
  const _Scene(this.title, this.lines, {this.holdDuration = const Duration(milliseconds: 5000)});
}

final _scenes = [
  // 0: Title
  const _Scene('', [], holdDuration: Duration(milliseconds: 3000)),

  // 1: Pain (blocks)
  const _Scene('Lo que vives todos los dias', [
    _Line('Agenda de papel. Citas perdidas. Doble reservacion.'),
    _Line('WhatsApp x30 clientas al dia. Imposible no perder una.'),
    _Line('AgendaPro: \$4,500/mes. Cobran por todo.', color: _red),
    _Line('Impuestos a las 11pm con una calculadora.'),
    _Line('No sabes cuanto produce cada estilista.'),
  ]),

  // 2: Switch (sun/moon)
  const _Scene('Y si una sola herramienta reemplaza TODO?', [
    _Line('Calendario inteligente con drag & drop.'),
    _Line('WhatsApp ILIMITADO y GRATIS.', bold: true),
    _Line('Staff ilimitado. Sin cobro por persona.'),
    _Line('Impuestos calculados automaticamente.'),
    _Line('Productividad por estilista en tiempo real.'),
  ], holdDuration: Duration(milliseconds: 7000)),

  // 3: Catch (keyhole)
  const _Scene('OK pero cual es el truco?', [
    _Line('AgendaPro: \$4,500/mes + \$2 por mensaje.', color: _red),
    _Line('Vagaro: \$25 USD/mes por profesional.', color: _red),
    _Line('Fresha: 20% por cliente nuevo. VEINTE.', color: _red),
    _Line('WhatsApp: \$1,800/mes solo en mensajes.', color: _red),
    _Line(''),
    _Line('BeautyCita: TODO gratis. Cero trucos.', color: _green, bold: true),
  ]),

  // 4: Replace (blocks)
  const _Scene('Lo que reemplazas', [
    _Line('Agenda de papel → Calendario drag & drop'),
    _Line('"Llama para reagendar" → Arrastra la cita. Listo.'),
    _Line('WhatsApp manual → Alertas automaticas GRATIS'),
    _Line('AgendaPro \$2,500/mes → Todo gratis', color: _green),
    _Line('Calculadora → ISR e IVA automaticos', bold: true),
    _Line('La UNICA plataforma en Mexico con cumplimiento SAT.', color: _brandPurple, bold: true),
  ]),

  // 5: Deal (typewriter)
  const _Scene('El trato', [
    _Line('1. Te registras hoy. 2 minutos. Sin tarjeta.'),
    _Line('2. Usas TODO gratis. Sin limite de tiempo.'),
    _Line('3. Nosotros te buscamos clientas nuevas.'),
    _Line('4. Solo cobramos 3% cuando TE TRAEMOS una.', bold: true),
    _Line(''),
    _Line('Tus propias clientas: 0%. Siempre.', color: _green, bold: true),
  ]),

  // 6: Numbers (slot)
  const _Scene('En numeros', [
    _Line('\$0 — mensualidad', bold: true),
    _Line('\$0 — por estilista', bold: true),
    _Line('\$0 — por mensaje WhatsApp', bold: true),
    _Line('0 — funciones bloqueadas', bold: true),
    _Line('3% — solo si te traemos una clienta', color: _brandPurple, bold: true),
    _Line('100% — tuyo. Tus datos, tu negocio.', color: _green, bold: true),
  ]),

  // 7: Transparency (glass)
  const _Scene('Como es posible?', [
    _Line('Nuestros costos reales:', bold: true),
    _Line('Servidores: \$4,200/mes'),
    _Line('WhatsApp: \$0.15/mensaje'),
    _Line('Stripe: 2.9% + \$3 MXN'),
    _Line('Equipo: \$18,000/mes'),
    _Line(''),
    _Line('Elegimos a ti. No a una mesa de inversionistas.', color: _brandPurple, bold: true),
  ], holdDuration: Duration(milliseconds: 6000)),

  // 8: CTA
  const _Scene('', [], holdDuration: Duration(milliseconds: 0)),
];

// ── Cinema Engine ────────────────────────────────────────────────────────────

class PorQueCinemaPage extends StatefulWidget {
  const PorQueCinemaPage({super.key});

  @override
  State<PorQueCinemaPage> createState() => _CinemaState();
}

class _CinemaState extends State<PorQueCinemaPage> with TickerProviderStateMixin {
  int _scene = 0;
  bool _paused = false;
  bool _transitioning = false;

  late final AnimationController _enter;  // scene fade in
  late final AnimationController _play;   // scene-specific animation
  late final AnimationController _exit;   // scene fade out

  late final FocusNode _focusNode;

  // Shader for light reveal
  ui.FragmentProgram? _lightShader;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _play = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000));
    _exit = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _focusNode = FocusNode();

    // Load shader
    _loadShader();

    // Start show after brief delay
    Future.delayed(const Duration(milliseconds: 600), _runScene);
  }

  Future<void> _loadShader() async {
    try {
      _lightShader = await ui.FragmentProgram.fromAsset('shaders/light_reveal.frag');
    } catch (e) {
      debugPrint('[Cinema] Shader load failed (expected on some backends): $e');
    }
  }

  @override
  void dispose() {
    _enter.dispose();
    _play.dispose();
    _exit.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── Scene lifecycle ──

  Future<void> _runScene() async {
    if (!mounted) return;
    _transitioning = false;

    // Reset all controllers
    _enter.reset();
    _play.reset();
    _exit.reset();

    // Phase 1: Enter
    await _enter.animateTo(1.0, curve: Curves.easeOutCubic);
    if (!mounted) return;

    // Phase 2: Play scene animation (duration varies by scene type)
    final playDuration = _scene == 2
        ? const Duration(milliseconds: 6000)  // sun/moon needs more time
        : const Duration(milliseconds: 2500);
    _play.duration = playDuration;
    await _play.animateTo(1.0, curve: Curves.linear);
    if (!mounted) return;

    // Phase 3: Hold
    final hold = _scenes[_scene].holdDuration;
    if (hold.inMilliseconds > 0) {
      await _waitOrSkip(hold);
    }
    if (!mounted || _paused) return;

    // Phase 4: Auto-advance (unless last scene)
    if (_scene < _scenes.length - 1) {
      _nextScene();
    }
  }

  Future<void> _waitOrSkip(Duration duration) async {
    final end = DateTime.now().add(duration);
    while (DateTime.now().isBefore(end)) {
      if (!mounted || _paused) return;
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<void> _nextScene() async {
    if (_transitioning || _scene >= _scenes.length - 1) return;
    _transitioning = true;

    // Exit current scene
    await _exit.animateTo(1.0, curve: Curves.easeInCubic);
    if (!mounted) return;

    // White gap
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    setState(() => _scene++);
    _runScene();
  }

  Future<void> _prevScene() async {
    if (_transitioning || _scene <= 0) return;
    _transitioning = true;

    await _exit.animateTo(1.0, curve: Curves.easeInCubic);
    if (!mounted) return;

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    setState(() => _scene--);
    _runScene();
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
    if (!_paused && !_transitioning) {
      // Resume: if scene animation is done, advance
      if (_play.isCompleted && _scene < _scenes.length - 1) {
        _nextScene();
      }
    }
  }

  void _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowRight:
      case LogicalKeyboardKey.arrowDown:
        _paused = true;
        _nextScene();
      case LogicalKeyboardKey.arrowLeft:
      case LogicalKeyboardKey.arrowUp:
        _paused = true;
        _prevScene();
      case LogicalKeyboardKey.space:
        _togglePause();
      case LogicalKeyboardKey.escape:
        context.go('/');
      default:
        break;
    }
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    _focusNode.requestFocus();
    final size = MediaQuery.sizeOf(context);
    final isMobile = size.width < 800;
    final s = _S(size.width);

    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _onKey,
      child: Scaffold(
        backgroundColor: _white,
        body: GestureDetector(
          onTap: () {
            _paused = true;
            _nextScene();
          },
          // Clip everything to viewport — no overflowing moons
          child: ClipRect(
            child: Stack(
              children: [
                // Scene content with enter/exit opacity
                _buildAnimatedScene(isMobile, s),

              // BC logo — home link
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                left: isMobile ? 20 : 40,
                child: GestureDetector(
                  onTap: () => context.go('/'),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: ShaderMask(
                      shaderCallback: (b) => _brandGradient.createShader(b),
                      child: const Text('BeautyCita', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
                  ),
                ),
              ),

              // Controls — bottom
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 20,
                left: 0, right: 0,
                child: _buildControls(isMobile),
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedScene(bool isMobile, _S s) {
    return AnimatedBuilder(
      animation: Listenable.merge([_enter, _exit]),
      builder: (context, child) {
        final enterV = Curves.easeOut.transform(_enter.value);
        final exitV = Curves.easeIn.transform(_exit.value);
        final opacity = (enterV * (1.0 - exitV)).clamp(0.0, 1.0);
        final scale = 0.95 + 0.05 * enterV;

        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: _buildScene(_scene, isMobile, s),
          ),
        );
      },
    );
  }

  Widget _buildControls(bool isMobile) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Scene dots
        ...List.generate(_scenes.length, (i) {
          final isActive = i == _scene;
          return GestureDetector(
            onTap: () {
              _paused = true;
              if (i > _scene) {
                _nextScene();
              } else if (i < _scene) {
                _prevScene();
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: isActive ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: isActive ? _brandPurple : _textLight.withValues(alpha: 0.3),
              ),
            ),
          );
        }),

        const SizedBox(width: 20),

        // Pause/play
        GestureDetector(
          onTap: _togglePause,
          child: Icon(
            _paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
            size: 20,
            color: _textLight,
          ),
        ),

        if (!isMobile) ...[
          const SizedBox(width: 16),
          Text(
            '← → spacebar',
            style: TextStyle(fontSize: 11, color: _textLight.withValues(alpha: 0.4)),
          ),
        ],
      ],
    );
  }

  // ── Scene Router ──

  Widget _buildScene(int index, bool isMobile, _S s) {
    final scene = _scenes[index];
    switch (index) {
      case 0: return _TitleCard(anim: _play, s: s);
      case 2: return _SunMoonReveal(scene: scene, anim: _play, s: s, shader: _lightShader);
      case 3: return _KeyholeReveal(scene: scene, anim: _play, s: s);
      case 5: return _TypewriterReveal(scene: scene, anim: _play, s: s);
      case 6: return _SlotReveal(scene: scene, anim: _play, s: s);
      case 7: return _GlassReveal(scene: scene, anim: _play, s: s);
      case 8: return _SpotlightCTA(anim: _play, s: s, onTap: () => context.go('/'));
      default: return _BlocksReveal(scene: scene, anim: _play, s: s);
    }
  }
}

// ── Scene 0: Title Card ──────────────────────────────────────────────────────

class _TitleCard extends StatelessWidget {
  final Animation<double> anim;
  final _S s;
  const _TitleCard({required this.anim, required this.s});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: anim,
        builder: (_, __) {
          final t = Curves.easeOutCubic.transform(anim.value);
          return Opacity(
            opacity: t,
            child: Transform.scale(
              scale: 0.85 + 0.15 * t,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'porque',
                    style: TextStyle(
                      fontSize: s.hero * 0.8,
                      fontWeight: FontWeight.w200,
                      color: _textLight.withValues(alpha: t),
                      letterSpacing: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ShaderMask(
                    shaderCallback: (b) => _brandGradient.createShader(b),
                    child: Text(
                      'BeautyCita',
                      style: TextStyle(fontSize: s.hero, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Opacity(
                    opacity: ((t - 0.5) * 2).clamp(0.0, 1.0),
                    child: Text(
                      'toca para avanzar  ·  ← → para navegar',
                      style: TextStyle(fontSize: s.caption, color: _textLight),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Blocks Reveal (physics tumble) ───────────────────────────────────────────

class _BlocksReveal extends StatelessWidget {
  final _Scene scene;
  final Animation<double> anim;
  final _S s;
  const _BlocksReveal({required this.scene, required this.anim, required this.s});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: s.maxContent),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: s.hPad),
          child: AnimatedBuilder(
            animation: anim,
            builder: (_, __) {
              final t = anim.value;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bounceIn(
                    t: t, delay: 0.0, offsetY: -80,
                    child: Text(
                      scene.title,
                      style: TextStyle(fontSize: s.h1, fontWeight: FontWeight.w800, color: _textDark, height: 1.2),
                    ),
                  ),
                  SizedBox(height: s.body * 2),
                  ...scene.lines.asMap().entries.map((e) {
                    final i = e.key;
                    final line = e.value;
                    final delay = 0.1 + i * 0.08;
                    return Padding(
                      padding: EdgeInsets.only(bottom: s.bodySmall * 0.7),
                      child: _tumbleIn(
                        t: t, delay: delay, index: i,
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(horizontal: s.body, vertical: s.bodySmall),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAF7F4),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Text(
                            line.text,
                            style: TextStyle(
                              fontSize: s.body,
                              color: line.color ?? _textDark,
                              fontWeight: line.bold ? FontWeight.w700 : FontWeight.w500,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _bounceIn({required double t, required double delay, required double offsetY, required Widget child}) {
    final lt = ((t - delay) / 0.35).clamp(0.0, 1.0);
    final bounce = Curves.elasticOut.transform(lt);
    return Transform.translate(
      offset: Offset(0, offsetY * (1 - bounce)),
      child: Opacity(opacity: (lt * 2).clamp(0.0, 1.0), child: child),
    );
  }

  Widget _tumbleIn({required double t, required double delay, required int index, required Widget child}) {
    final lt = ((t - delay) / 0.22).clamp(0.0, 1.0);
    final bounce = Curves.elasticOut.transform(lt);
    // Bigger rotation — alternating direction, decreasing with index
    final startAngle = (index.isEven ? 0.15 : -0.12) * (1 + index * 0.03);
    final angle = startAngle * (1 - bounce);
    // Big drop — blocks fall from well above
    final dropDistance = 200.0 + index * 30;
    // Slight horizontal scatter
    final xOffset = (index.isEven ? -20.0 : 15.0) * (1 - bounce);
    return Transform(
      alignment: index.isEven ? Alignment.bottomLeft : Alignment.bottomRight,
      transform: Matrix4.identity()
        ..translate(xOffset, dropDistance * (1 - bounce))
        ..rotateZ(angle),
      child: Opacity(opacity: (lt * 1.5).clamp(0.0, 1.0), child: child),
    );
  }
}

// ── Sun/Moon Reveal ──────────────────────────────────────────────────────────

class _SunMoonReveal extends StatelessWidget {
  final _Scene scene;
  final Animation<double> anim;
  final _S s;
  final ui.FragmentProgram? shader;
  const _SunMoonReveal({required this.scene, required this.anim, required this.s, this.shader});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) {
        final t = anim.value;

        // Sun phase: 0.0 → 0.45 (sunrise to zenith)
        // Transition: 0.45 → 0.55 (day to night)
        // Moon phase: 0.55 → 1.0 (moonrise to set)
        final isSun = t < 0.5;
        final celestialT = isSun ? (t / 0.5) : ((t - 0.5) / 0.5);
        final nightBlend = ((t - 0.4) / 0.2).clamp(0.0, 1.0);

        // Arc position (parabolic)
        final x = celestialT;
        final y = 1.0 - 4.0 * celestialT * (1.0 - celestialT); // parabola peaking at 0.5

        final arcX = x * size.width;
        final arcY = size.height * 0.15 + y * size.height * 0.25;

        // Colors
        final bgColor = Color.lerp(_white, const Color(0xFF0A0A1A), nightBlend)!;
        final textColor = Color.lerp(_textDark, Colors.white, nightBlend)!;
        final celestialColor = isSun ? const Color(0xFFFFD700) : const Color(0xFFD4D4E0);
        final glowColor = isSun
            ? Color.lerp(const Color(0xFFFFE066), const Color(0xFFFF8C00), celestialT)!
            : Color.lerp(const Color(0xFF9999CC), const Color(0xFF6666AA), celestialT)!;

        // Light intensity — peaks at zenith (celestialT = 0.5)
        final intensity = math.sin(celestialT * math.pi);

        return Container(
          color: bgColor,
          child: Stack(
            children: [
              // Glow halo
              Positioned(
                left: arcX - 120,
                top: arcY - 120,
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        glowColor.withValues(alpha: 0.3 * intensity),
                        glowColor.withValues(alpha: 0.05 * intensity),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.4, 1.0],
                    ),
                  ),
                ),
              ),

              // Sun/moon body
              Positioned(
                left: arcX - 22,
                top: arcY - 22,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: celestialColor,
                    boxShadow: [
                      BoxShadow(color: glowColor.withValues(alpha: 0.5 * intensity), blurRadius: 30, spreadRadius: 5),
                    ],
                  ),
                ),
              ),

              // Content — revealed by proximity to light source
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: s.hPad),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        _lightRevealText(
                          text: scene.title,
                          style: TextStyle(fontSize: s.body * 2, fontWeight: FontWeight.w800, color: textColor, height: 1.2),
                          lightX: x, intensity: intensity,
                          yPosition: 0.4,
                        ),
                        SizedBox(height: s.body * 2),
                        // Lines — each has slightly different y position for staggered reveal
                        ...scene.lines.asMap().entries.map((e) {
                          final i = e.key;
                          final line = e.value;
                          final lineY = 0.5 + i * 0.06;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _lightRevealText(
                              text: line.text,
                              style: TextStyle(
                                fontSize: s.body,
                                color: line.color ?? textColor.withValues(alpha: 0.85),
                                fontWeight: line.bold ? FontWeight.w700 : FontWeight.w400,
                                height: 1.5,
                              ),
                              lightX: x, intensity: intensity,
                              yPosition: lineY,
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Text whose opacity depends on proximity to the light source
  Widget _lightRevealText({
    required String text,
    required TextStyle style,
    required double lightX,
    required double intensity,
    required double yPosition,
  }) {
    // Each line of text has a "position" on the page (0.0 = top, 1.0 = bottom)
    // The light sweeps left to right (lightX 0→1)
    // Text becomes visible when the light is "near" it horizontally
    // and the intensity (height of arc) is strong enough

    // Horizontal proximity — sharp falloff
    final hDist = (lightX - 0.5).abs(); // how far light is from center
    final hProximity = (1.0 - hDist * 2.5).clamp(0.0, 1.0);

    // Vertical stagger — lines lower on the page light up slightly later
    final vDelay = yPosition * 0.15;
    final adjustedIntensity = (intensity - vDelay).clamp(0.0, 1.0);

    // Sharp threshold — text is either mostly visible or mostly hidden
    final raw = adjustedIntensity * hProximity;
    final alpha = (raw * 2.5).clamp(0.0, 1.0); // steeper curve

    // Slight vertical lift as text appears
    final lift = (1.0 - alpha) * 8;

    return Transform.translate(
      offset: Offset(0, lift),
      child: Opacity(
        opacity: alpha,
        child: Text(text, style: style),
      ),
    );
  }
}

// ── Keyhole Reveal ───────────────────────────────────────────────────────────

class _KeyholeReveal extends StatelessWidget {
  final _Scene scene;
  final Animation<double> anim;
  final _S s;
  const _KeyholeReveal({required this.scene, required this.anim, required this.s});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) {
        final t = anim.value;
        final holeSize = (t / 0.6).clamp(0.0, 1.0); // 0→0.6: hole expands
        final contentT = ((t - 0.5) / 0.5).clamp(0.0, 1.0); // 0.5→1: content fades

        return Stack(
          children: [
            // Content behind the keyhole
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: s.hPad),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        scene.title,
                        style: TextStyle(fontSize: s.h1, fontWeight: FontWeight.w800, color: _textDark, height: 1.2),
                      ),
                      SizedBox(height: s.body * 2),
                      ...scene.lines.asMap().entries.map((e) {
                        final i = e.key;
                        final line = e.value;
                        final lineT = ((contentT - i * 0.1) / 0.3).clamp(0.0, 1.0);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Opacity(
                            opacity: Curves.easeOut.transform(lineT),
                            child: Transform.translate(
                              offset: Offset(20 * (1 - lineT), 0),
                              child: Text(
                                line.text,
                                style: TextStyle(
                                  fontSize: s.body,
                                  color: line.color ?? _textDark,
                                  fontWeight: line.bold ? FontWeight.w700 : FontWeight.w500,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),

            // Keyhole mask
            if (holeSize < 0.99)
              Positioned.fill(
                child: CustomPaint(
                  painter: _KeyholeMask(
                    openFraction: Curves.easeOutCubic.transform(holeSize),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _KeyholeMask extends CustomPainter {
  final double openFraction;
  _KeyholeMask({required this.openFraction});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final maxR = math.sqrt(size.width * size.width + size.height * size.height) / 2;

    // Fade the mask out as it opens fully
    final maskAlpha = (1.0 - ((openFraction - 0.8) / 0.2).clamp(0.0, 1.0));
    if (maskAlpha <= 0) return;

    final paint = Paint()..color = const Color(0xFF0A0A0A).withValues(alpha: maskAlpha);

    // The visible opening
    final holePath = Path();

    if (openFraction < 0.4) {
      // Phase 1: Classic keyhole shape, growing
      final progress = openFraction / 0.4;
      final circleR = 15 + progress * 60;
      final slotW = circleR * 0.35;
      final slotH = circleR * 0.8;

      // Circle part (upper)
      holePath.addOval(Rect.fromCircle(
        center: Offset(cx, cy - slotH * 0.15),
        radius: circleR,
      ));
      // Slot part (lower trapezoid)
      holePath.moveTo(cx - slotW * 0.4, cy + circleR * 0.3);
      holePath.lineTo(cx + slotW * 0.4, cy + circleR * 0.3);
      holePath.lineTo(cx + slotW * 0.7, cy + circleR * 0.3 + slotH);
      holePath.lineTo(cx - slotW * 0.7, cy + circleR * 0.3 + slotH);
      holePath.close();
    } else {
      // Phase 2: Morph to circle and expand to fill screen
      final progress = (openFraction - 0.4) / 0.6;
      final eased = Curves.easeOutCubic.transform(progress);
      final radius = 75 + eased * maxR;
      holePath.addOval(Rect.fromCircle(center: Offset(cx, cy), radius: radius));
    }

    // Mask = full screen minus the hole
    final maskPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addPath(holePath, Offset.zero)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(maskPath, paint);

    // Draw keyhole rim when small
    if (openFraction < 0.35) {
      final rimPaint = Paint()
        ..color = Color.lerp(const Color(0xFF8B7355), const Color(0xFF8B7355).withValues(alpha: 0), openFraction / 0.35)!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawPath(holePath, rimPaint);
    }
  }

  @override
  bool shouldRepaint(_KeyholeMask old) => openFraction != old.openFraction;
}

// ── Typewriter Reveal ────────────────────────────────────────────────────────

class _TypewriterReveal extends StatelessWidget {
  final _Scene scene;
  final Animation<double> anim;
  final _S s;
  const _TypewriterReveal({required this.scene, required this.anim, required this.s});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: s.hPad),
          child: AnimatedBuilder(
            animation: anim,
            builder: (_, __) {
              final t = anim.value;
              final titleT = (t * 4).clamp(0.0, 1.0);

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Opacity(
                    opacity: titleT,
                    child: Text(
                      scene.title,
                      style: TextStyle(
                        fontSize: s.h1,
                        fontWeight: FontWeight.w800,
                        color: _textDark,
                        height: 1.2,
                      ),
                    ),
                  ),
                  SizedBox(height: s.body * 2.5),
                  ...scene.lines.asMap().entries.map((e) {
                    final i = e.key;
                    final line = e.value;
                    if (line.text.isEmpty) return const SizedBox(height: 12);

                    final lineStart = 0.15 + i * 0.13;
                    final lineT = ((t - lineStart) / 0.13).clamp(0.0, 1.0);
                    final chars = (line.text.length * lineT).round();
                    final showCursor = lineT > 0 && lineT < 1.0;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: line.text.substring(0, chars),
                              style: TextStyle(
                                fontSize: s.body,
                                color: line.color ?? _textDark,
                                fontWeight: line.bold ? FontWeight.w700 : FontWeight.w400,
                                height: 1.5,
                                fontFamily: 'monospace',
                              ),
                            ),
                            if (showCursor)
                              TextSpan(
                                text: '|',
                                style: TextStyle(
                                  fontSize: s.body,
                                  color: _brandPurple,
                                  fontFamily: 'monospace',
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ── Slot Machine Reveal ──────────────────────────────────────────────────────

class _SlotReveal extends StatelessWidget {
  final _Scene scene;
  final Animation<double> anim;
  final _S s;
  const _SlotReveal({required this.scene, required this.anim, required this.s});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: s.hPad),
          child: AnimatedBuilder(
            animation: anim,
            builder: (_, __) {
              final t = anim.value;

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bounceIn(t, 0.0, Text(
                    scene.title,
                    style: TextStyle(fontSize: s.h1, fontWeight: FontWeight.w800, color: _textDark),
                  )),
                  SizedBox(height: s.body * 2.5),
                  ...scene.lines.asMap().entries.map((e) {
                    final i = e.key;
                    final line = e.value;
                    final lockT = ((t - 0.1 - i * 0.1) / 0.12).clamp(0.0, 1.0);
                    final bounce = Curves.elasticOut.transform(lockT);
                    final parts = line.text.split(' — ');
                    final value = parts[0];
                    final desc = parts.length > 1 ? parts[1] : '';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Transform.scale(
                        scale: 0.3 + 0.7 * bounce,
                        child: Opacity(
                          opacity: lockT,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              SizedBox(
                                width: s.h1 * 2.5,
                                child: ShaderMask(
                                  shaderCallback: (b) => _brandGradient.createShader(b),
                                  child: Text(
                                    value,
                                    style: TextStyle(fontSize: s.h2, fontWeight: FontWeight.w800, color: Colors.white),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  desc,
                                  style: TextStyle(fontSize: s.bodySmall, color: _textMid, height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _bounceIn(double t, double delay, Widget child) {
    final lt = ((t - delay) / 0.25).clamp(0.0, 1.0);
    final bounce = Curves.elasticOut.transform(lt);
    return Transform.translate(
      offset: Offset(0, -40 * (1 - bounce)),
      child: Opacity(opacity: lt, child: child),
    );
  }
}

// ── Glass Shatter Reveal ─────────────────────────────────────────────────────

class _GlassReveal extends StatelessWidget {
  final _Scene scene;
  final Animation<double> anim;
  final _S s;
  const _GlassReveal({required this.scene, required this.anim, required this.s});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) {
        final t = anim.value;
        final frostFade = (1.0 - ((t - 0.3) / 0.25).clamp(0.0, 1.0));
        final crackT = ((t - 0.15) / 0.2).clamp(0.0, 1.0);
        final contentT = ((t - 0.4) / 0.6).clamp(0.0, 1.0);

        return Container(
          color: const Color(0xFF0F0F1A),
          child: Stack(
            children: [
              // Content
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: s.hPad),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          scene.title,
                          style: TextStyle(fontSize: s.h1, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                        SizedBox(height: s.body * 1.5),
                        ...scene.lines.asMap().entries.map((e) {
                          final i = e.key;
                          final line = e.value;
                          if (line.text.isEmpty) return const SizedBox(height: 12);
                          final lineT = ((contentT - i * 0.06) * 3).clamp(0.0, 1.0);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Opacity(
                              opacity: lineT,
                              child: Transform.translate(
                                offset: Offset(0, 10 * (1 - lineT)),
                                child: Text(
                                  line.text,
                                  style: TextStyle(
                                    fontSize: s.body,
                                    color: line.color ?? Colors.white.withValues(alpha: 0.8),
                                    fontWeight: line.bold ? FontWeight.w700 : FontWeight.w400,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),

              // Frosted glass + cracks
              if (frostFade > 0.01)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _CracksPainter(crackProgress: crackT, frostOpacity: frostFade),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _CracksPainter extends CustomPainter {
  final double crackProgress;
  final double frostOpacity;
  _CracksPainter({required this.crackProgress, required this.frostOpacity});

  @override
  void paint(Canvas canvas, Size size) {
    // Frost layer
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.white.withValues(alpha: 0.12 * frostOpacity),
    );

    if (crackProgress <= 0) return;

    // Cracks radiating from impact point
    final impact = Offset(size.width * 0.35, size.height * 0.35);
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5 * frostOpacity)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final rng = math.Random(42);
    final numCracks = (10 * crackProgress).round();

    for (var i = 0; i < numCracks; i++) {
      final angle = rng.nextDouble() * math.pi * 2;
      final len = 40 + rng.nextDouble() * size.width * 0.35 * crackProgress;
      final path = Path()..moveTo(impact.dx, impact.dy);

      var pos = impact;
      for (var j = 0; j < 8; j++) {
        final frac = (j + 1) / 8;
        final target = Offset(
          impact.dx + math.cos(angle) * len * frac,
          impact.dy + math.sin(angle) * len * frac,
        );
        pos = target + Offset(
          (rng.nextDouble() - 0.5) * 12,
          (rng.nextDouble() - 0.5) * 12,
        );
        path.lineTo(pos.dx, pos.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_CracksPainter old) => crackProgress != old.crackProgress || frostOpacity != old.frostOpacity;
}

// ── Spotlight CTA ────────────────────────────────────────────────────────────

class _SpotlightCTA extends StatelessWidget {
  final Animation<double> anim;
  final _S s;
  final VoidCallback onTap;
  const _SpotlightCTA({required this.anim, required this.s, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) {
        final t = anim.value;
        final spotR = 30 + t * 500;
        final textT = ((t - 0.2) / 0.3).clamp(0.0, 1.0);
        final btnT = ((t - 0.5) / 0.3).clamp(0.0, 1.0);
        final earlyT = ((t - 0.7) / 0.3).clamp(0.0, 1.0);

        return Container(
          color: Color.lerp(Colors.black, const Color(0xFF0A0520), t),
          child: Stack(
            children: [
              // Spotlight glow
              Center(
                child: Container(
                  width: spotR * 2,
                  height: spotR * 2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.06),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Content
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: s.hPad),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Opacity(
                        opacity: Curves.easeOut.transform(textT),
                        child: Text(
                          'Cada dia que pagas mensualidad\nes dinero que pierdes.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: s.h1, fontWeight: FontWeight.w800, color: Colors.white, height: 1.3),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Opacity(
                        opacity: Curves.easeOut.transform(btnT),
                        child: GestureDetector(
                          onTap: onTap,
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: Container(
                              width: s.width < 800 ? double.infinity : 360,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              decoration: BoxDecoration(
                                gradient: _brandGradient,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [BoxShadow(color: _brandPurple.withValues(alpha: 0.4), blurRadius: 30, offset: const Offset(0, 8))],
                              ),
                              child: Text(
                                'Registrar Mi Salon — Gratis',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: s.body * 1.1, fontWeight: FontWeight.w700, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Opacity(
                        opacity: Curves.easeOut.transform(earlyT),
                        child: const Text(
                          'Esta es nuestra primera version — y solo va a mejorar.\n'
                          'Los salones que se unan ahora tendran cada nueva\nmejora y tecnologia. Para siempre. Gratis.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: Colors.white54, height: 1.5),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Opacity(
                        opacity: Curves.easeOut.transform(earlyT),
                        child: const Text(
                          'Sin tarjeta. Sin compromiso. Sin mensualidad.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: Colors.white30),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
