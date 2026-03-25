# Flutter Transitions & Animations: Comprehensive Reference Guide

Compiled: 2026-03-24 | Flutter 3.38+ / Impeller era

---

## Table of Contents

1. [Implicit Animations](#1-implicit-animations)
2. [Explicit Animations](#2-explicit-animations)
3. [Hero Animations](#3-hero-animations)
4. [Page Route Transitions](#4-page-route-transitions)
5. [Staggered Animations](#5-staggered-animations)
6. [Custom Painters with Animation](#6-custom-painters-with-animation)
7. [Physics-based Animations](#7-physics-based-animations)
8. [Shader-based Transitions](#8-shader-based-transitions)
9. [Rive and Lottie Animations](#9-rive-and-lottie-animations)
10. [Performance Optimization](#10-performance-optimization)
11. [Advanced Packages](#11-advanced-packages)
12. [Cross-platform Considerations](#12-cross-platform-considerations)
13. [Resource-efficient Patterns](#13-resource-efficient-patterns)
14. [Decision Framework](#14-decision-framework)

---

## 1. Implicit Animations

Implicit animations automatically animate property changes without requiring an AnimationController. You change a value, and the widget animates to it.

### AnimatedContainer

**What it does:** Animates changes to any Container property (color, size, padding, margin, decoration, alignment, transform).

**When to use:** Simple state-driven visual changes — button press effects, layout shifts, theme changes.

**Performance cost:** Low. Single widget rebuild, GPU-composited transform when possible.

**Cross-platform:** All platforms (Android, iOS, Web, Linux, macOS, Windows).

```dart
AnimatedContainer(
  duration: const Duration(milliseconds: 300),
  curve: Curves.easeInOut,
  width: _expanded ? 200 : 100,
  height: _expanded ? 200 : 100,
  decoration: BoxDecoration(
    color: _expanded ? Colors.blue : Colors.red,
    borderRadius: BorderRadius.circular(_expanded ? 32 : 8),
  ),
  child: const Icon(Icons.star),
)
```

### AnimatedOpacity

**What it does:** Fades a widget in or out by animating its opacity.

**When to use:** Show/hide elements with a fade. Simpler than FadeTransition when you don't need controller access.

**Performance cost:** Low. Opacity is composited on the GPU via a separate layer.

**Cross-platform:** All platforms.

```dart
AnimatedOpacity(
  opacity: _visible ? 1.0 : 0.0,
  duration: const Duration(milliseconds: 500),
  child: const Text('Hello'),
)
```

### AnimatedPositioned

**What it does:** Animates position changes within a Stack.

**When to use:** Moving elements within a Stack layout — sliding panels, repositioning chips.

**Performance cost:** Low-Medium. Triggers layout on the Stack during animation.

**Cross-platform:** All platforms.

```dart
Stack(
  children: [
    AnimatedPositioned(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      left: _moved ? 200 : 0,
      top: _moved ? 100 : 0,
      child: const FlutterLogo(size: 60),
    ),
  ],
)
```

### AnimatedDefaultTextStyle

**What it does:** Animates text style changes (size, color, weight, letter spacing).

**When to use:** Emphasizing text on selection, theme transitions, heading size changes.

**Performance cost:** Low. Rebuilds only the text render object.

**Cross-platform:** All platforms.

```dart
AnimatedDefaultTextStyle(
  duration: const Duration(milliseconds: 300),
  style: _selected
      ? const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue)
      : const TextStyle(fontSize: 16, fontWeight: FontWeight.normal, color: Colors.grey),
  child: const Text('Tap me'),
)
```

### AnimatedCrossFade

**What it does:** Cross-fades between two children with automatic size animation.

**When to use:** Toggling between two views (expanded/collapsed, login/signup forms).

**Performance cost:** Low. Both children exist in the tree; one fades out while the other fades in.

**Cross-platform:** All platforms.

```dart
AnimatedCrossFade(
  duration: const Duration(milliseconds: 300),
  crossFadeState: _showFirst ? CrossFadeState.showFirst : CrossFadeState.showSecond,
  firstChild: const Icon(Icons.favorite, size: 80, color: Colors.red),
  secondChild: const Icon(Icons.favorite_border, size: 80, color: Colors.grey),
)
```

### AnimatedSwitcher

**What it does:** Animates the transition when its child is replaced (by key or type).

**When to use:** Swapping widgets with a transition — counter changes, tab content, icon swaps.

**Performance cost:** Low. Default is FadeTransition; customizable via transitionBuilder.

**Cross-platform:** All platforms.

```dart
AnimatedSwitcher(
  duration: const Duration(milliseconds: 300),
  transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
  child: Text(
    '$_count',
    key: ValueKey<int>(_count), // Key change triggers animation
    style: const TextStyle(fontSize: 48),
  ),
)
```

### Other Notable Implicit Widgets

| Widget | Animates | Cost |
|--------|----------|------|
| `AnimatedAlign` | Alignment within parent | Low |
| `AnimatedPadding` | Padding values | Low |
| `AnimatedPhysicalModel` | Elevation, shadow, shape | Low-Medium |
| `AnimatedTheme` | ThemeData changes | Low |
| `AnimatedSize` | Size to fit child | Medium (triggers layout) |
| `AnimatedSlide` | Offset-based slide | Low |
| `AnimatedRotation` | Rotation in turns | Low |
| `AnimatedScale` | Scale factor | Low |
| `AnimatedFractionallySizedBox` | Fractional size | Medium |

### TweenAnimationBuilder

**What it does:** The most flexible implicit animation widget. Animates any value via a custom Tween without needing an AnimationController.

**When to use:** When no pre-built implicit widget exists for your property, or when you need to animate a custom value (angle, progress, custom double).

**Performance cost:** Low. Single widget rebuild per frame.

**Cross-platform:** All platforms.

```dart
TweenAnimationBuilder<double>(
  tween: Tween(begin: 0, end: _targetAngle),
  duration: const Duration(milliseconds: 600),
  curve: Curves.elasticOut,
  builder: (context, angle, child) {
    return Transform.rotate(angle: angle, child: child);
  },
  child: const Icon(Icons.refresh, size: 48), // const child = no rebuild
)
```

---

## 2. Explicit Animations

Explicit animations give full control over timing, direction, repetition, and chaining. They require an AnimationController managed by you.

### Core Components

**AnimationController** — The engine. Produces values from `lowerBound` to `upperBound` (default 0.0 to 1.0) over a `duration`. Requires a `TickerProvider` (usually `SingleTickerProviderStateMixin` or `TickerProviderStateMixin`).

**Tween** — Maps the controller's 0.0-1.0 range to your target range (colors, sizes, offsets, etc.).

**CurvedAnimation** — Applies an easing curve to the controller's linear output.

**AnimatedBuilder** — Rebuilds only its builder function when the animation ticks, leaving `child` untouched (performance optimization).

### Lifecycle Management

```dart
class _MyWidgetState extends State<MyWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,  // SingleTickerProviderStateMixin provides this
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose(); // CRITICAL: always dispose
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: const Card(child: Text('Hello')),
      ),
    );
  }
}
```

### vsync Explained

The `vsync` parameter ties the controller to the screen's refresh rate. Without it, the controller would tick at arbitrary rates, wasting CPU/GPU cycles on frames that will never be displayed.

- `SingleTickerProviderStateMixin` — Use when you have exactly one AnimationController in the State.
- `TickerProviderStateMixin` — Use when you have multiple AnimationControllers in the same State.

The ticker automatically pauses when the widget is not visible (e.g., off-screen in a TabView), saving resources.

### Pre-built Transition Widgets

These widgets take an `Animation<T>` and apply it, avoiding manual AnimatedBuilder usage:

| Widget | Animates | Input Type |
|--------|----------|------------|
| `FadeTransition` | Opacity | `Animation<double>` |
| `SlideTransition` | Position via offset | `Animation<Offset>` |
| `ScaleTransition` | Scale | `Animation<double>` |
| `RotationTransition` | Rotation (in turns) | `Animation<double>` |
| `SizeTransition` | Size along an axis | `Animation<double>` |
| `DecoratedBoxTransition` | BoxDecoration | `Animation<Decoration>` |
| `AlignTransition` | Alignment | `Animation<AlignmentGeometry>` |
| `PositionedTransition` | Position in Stack | `Animation<RelativeRect>` |

**Performance cost:** Low-Medium depending on what's being animated. Transform-based animations (scale, rotation, slide) are GPU-composited and cheap. Layout-affecting animations (size) are more expensive.

**Cross-platform:** All platforms.

---

## 3. Hero Animations

### Standard Hero

**What it does:** Animates a widget from one screen to another, creating a shared-element transition. Flutter automatically calculates the flight path, size change, and position delta.

**When to use:** Image gallery to detail view, card to full-screen, avatar to profile page.

**Performance cost:** Medium. Creates an overlay entry, animates size and position simultaneously.

**Cross-platform:** All platforms. Works identically on web.

```dart
// Source screen
Hero(
  tag: 'product-${product.id}',  // Must match destination
  child: Image.network(product.imageUrl, width: 100, height: 100, fit: BoxFit.cover),
)

// Destination screen
Hero(
  tag: 'product-${product.id}',
  child: Image.network(product.imageUrl, width: double.infinity, height: 300, fit: BoxFit.cover),
)
```

### Custom Hero Flight Path

**What it does:** Override the default linear flight with a custom path (arc, bounce, etc.).

```dart
Hero(
  tag: 'avatar',
  flightShuttleBuilder: (flightContext, animation, direction, fromContext, toContext) {
    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.easeInOutBack,
    );
    return AnimatedBuilder(
      animation: curvedAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: 1.0 + 0.3 * math.sin(curvedAnimation.value * math.pi),
          child: fromContext.widget,
        );
      },
    );
  },
  child: const CircleAvatar(radius: 24),
)
```

### Hero with Custom Rect Tween

```dart
Hero(
  tag: 'item-$id',
  createRectTween: (begin, end) {
    return MaterialRectArcTween(begin: begin!, end: end!);
    // or: MaterialRectCenterArcTween for center-based arcs
  },
  child: widget,
)
```

### Tips

- The `tag` must be unique on each screen. Duplicate tags cause assertion errors.
- Wrap text in `Material(type: MaterialType.transparency)` to prevent visual artifacts during flight.
- Use `placeholderBuilder` to show a placeholder at the source position during flight.

---

## 4. Page Route Transitions

### PageRouteBuilder

**What it does:** Lets you define custom enter/exit transitions for page navigation.

**When to use:** Custom screen transitions beyond MaterialPageRoute's default.

**Performance cost:** Low-Medium. The transition itself is just an animation wrapping the page widget.

**Cross-platform:** All platforms.

```dart
Navigator.push(context, PageRouteBuilder(
  pageBuilder: (context, animation, secondaryAnimation) => const DetailPage(),
  transitionsBuilder: (context, animation, secondaryAnimation, child) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeInOutCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.0, 0.05),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  },
  transitionDuration: const Duration(milliseconds: 400),
  reverseTransitionDuration: const Duration(milliseconds: 300),
));
```

### Common Transition Patterns

**Slide from right (iOS-style):**
```dart
SlideTransition(
  position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
      .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
  child: child,
)
```

**Slide from bottom (modal-style):**
```dart
SlideTransition(
  position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
      .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
  child: child,
)
```

**Scale + fade (zoom-in):**
```dart
FadeTransition(
  opacity: animation,
  child: ScaleTransition(
    scale: Tween<double>(begin: 0.8, end: 1.0)
        .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutBack)),
    child: child,
  ),
)
```

**Rotation (flip-card style):**
```dart
RotationTransition(
  turns: Tween(begin: 0.0, end: 1.0)
      .animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut)),
  child: child,
)
```

### Reusable Custom Route Class

```dart
class FadeSlideRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  FadeSlideRoute({required this.page})
      : super(
          pageBuilder: (_, __, ___) => page,
          transitionsBuilder: (_, animation, __, child) {
            final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, 0.03), end: Offset.zero).animate(curved),
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 350),
        );
}

// Usage:
Navigator.push(context, FadeSlideRoute(page: const DetailPage()));
```

---

## 5. Staggered Animations

### Concept

Staggered animations run multiple animations with overlapping or sequential timing using `Interval` within a single AnimationController's 0.0-1.0 timeline.

**When to use:** Entrance animations for lists, cascading card reveals, multi-step form animations, onboarding sequences.

**Performance cost:** Medium. Multiple animated widgets updating, but still single controller.

**Cross-platform:** All platforms.

### Basic Staggered Pattern

```dart
class _StaggeredDemoState extends State<StaggeredDemo> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // First third: fade in
    _opacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.33, curve: Curves.easeIn)),
    );

    // Middle third: slide up (overlaps with fade)
    _slide = Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.15, 0.65, curve: Curves.easeOutCubic)),
    );

    // Last third: scale up
    _scale = Tween(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.5, 1.0, curve: Curves.elasticOut)),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return FadeTransition(
          opacity: _opacity,
          child: SlideTransition(
            position: _slide,
            child: ScaleTransition(scale: _scale, child: child),
          ),
        );
      },
      child: const Card(child: ListTile(title: Text('Staggered Item'))),
    );
  }
}
```

### Cascade Effect for Lists

```dart
// In a list builder, delay each item's animation start
Widget _buildAnimatedItem(int index) {
  final startInterval = (index * 0.1).clamp(0.0, 0.7);
  final endInterval = (startInterval + 0.3).clamp(0.0, 1.0);

  final animation = Tween(begin: 0.0, end: 1.0).animate(
    CurvedAnimation(
      parent: _controller,
      curve: Interval(startInterval, endInterval, curve: Curves.easeOutCubic),
    ),
  );

  return FadeTransition(
    opacity: animation,
    child: SlideTransition(
      position: Tween(begin: const Offset(0, 0.2), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(startInterval, endInterval, curve: Curves.easeOutCubic),
        ),
      ),
      child: _buildCard(index),
    ),
  );
}
```

---

## 6. Custom Painters with Animation

### Animated CustomPainter

**What it does:** Draws custom graphics on a Canvas that update every frame based on an animation value.

**When to use:** Custom progress indicators, waveforms, particle effects, charts, path animations, anything not expressible with standard widgets.

**Performance cost:** Medium-High. Runs the paint method every frame. Cost depends on drawing complexity.

**Cross-platform:** All platforms, but performance varies (see Section 12).

### Efficient Pattern: repaint Argument

The most efficient approach passes the animation as the `repaint` argument to `CustomPainter`. This skips the build and layout phases entirely — only paint is called.

```dart
class WavePainter extends CustomPainter {
  final Animation<double> animation;

  WavePainter({required this.animation}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final path = Path();
    for (double x = 0; x < size.width; x++) {
      final y = size.height / 2 +
          math.sin((x / size.width * 4 * math.pi) + (animation.value * 2 * math.pi)) *
              size.height * 0.2;
      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(WavePainter oldDelegate) => false;
  // Returns false because repaint: animation handles repainting.
  // shouldRepaint is only for when the painter is reconstructed with new config.
}

// Usage in State:
CustomPaint(
  painter: WavePainter(animation: _controller),
  size: const Size(double.infinity, 200),
)
```

### shouldRepaint Optimization

```dart
@override
bool shouldRepaint(MyPainter oldDelegate) {
  // Only return true when drawing parameters actually changed
  return oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  // Do NOT compare animation here — use repaint: argument instead
}
```

### Performance Tips for CustomPainter

- Pass the animation as `repaint:` to avoid build/layout phases.
- Return `false` from `shouldRepaint` when using repaint notifier.
- Pre-allocate `Paint` objects if they don't change per frame.
- Minimize allocations in `paint()` — avoid creating new lists, paths, or objects every frame when possible.
- Wrap in `RepaintBoundary` to isolate from surrounding widget repaints.
- Use `canvas.save()`/`canvas.restore()` instead of creating new Paint objects for state changes.
- Use `canvas.clipRect()` to limit drawing area when only part of the canvas changes.

---

## 7. Physics-based Animations

### Overview

Physics simulations produce natural-feeling motion by modeling real physical forces. Instead of a fixed duration and curve, the animation is driven by velocity, mass, stiffness, and damping.

**When to use:** Drag-and-release gestures, pull-to-refresh, fling-to-dismiss, bouncy UI elements, momentum scrolling.

**Performance cost:** Low-Medium. Simulation math is lightweight; rendering cost depends on what's animated.

**Cross-platform:** All platforms.

### SpringSimulation

Models a spring oscillation. Controlled by `SpringDescription` (mass, stiffness, damping).

```dart
void _startSpring(double velocity) {
  final spring = SpringDescription(
    mass: 1.0,
    stiffness: 200.0,   // Higher = snappier
    damping: 12.0,       // Higher = less bounce
  );
  final simulation = SpringSimulation(spring, _controller.value, 1.0, velocity);
  _controller.animateWith(simulation);
}
```

**Common presets:**
- Snappy, no bounce: `SpringDescription(mass: 1, stiffness: 300, damping: 30)`
- Bouncy: `SpringDescription(mass: 1, stiffness: 180, damping: 8)`
- Gentle: `SpringDescription(mass: 1, stiffness: 100, damping: 15)`

### Spring Curves (Predefined)

Flutter provides built-in spring curves since Flutter 3.x:

```dart
CurvedAnimation(
  parent: _controller,
  curve: Curves.easeOutBack,     // Overshoot then settle
  // Or use SpringCurve from physics:
)
```

### FrictionSimulation

Models deceleration (like a puck sliding on ice). Good for fling gestures.

```dart
void _onFling(double velocity) {
  final simulation = FrictionSimulation(
    0.135,             // Drag coefficient (higher = more friction)
    _controller.value, // Start position
    velocity,          // Initial velocity from gesture
  );
  _controller.animateWith(simulation);
}
```

### GravitySimulation

Models falling under gravity. Useful for drop animations.

```dart
final simulation = GravitySimulation(
  500.0,   // Acceleration (pixels/s^2)
  0.0,     // Starting position
  500.0,   // Ending position (threshold to stop)
  0.0,     // Starting velocity
);
_controller.animateWith(simulation);
```

### ClampingScrollSimulation

Used internally by Flutter's scrolling. Models the Android-style scroll fling with clamping.

### Combining with GestureDetector

```dart
GestureDetector(
  onPanUpdate: (details) {
    _controller.value += details.primaryDelta! / maxDrag;
  },
  onPanEnd: (details) {
    final velocity = details.primaryVelocity! / maxDrag;
    final spring = SpringDescription(mass: 1, stiffness: 200, damping: 15);
    final target = _controller.value > 0.5 ? 1.0 : 0.0;
    _controller.animateWith(SpringSimulation(spring, _controller.value, target, velocity));
  },
  child: AnimatedBuilder(
    animation: _controller,
    builder: (context, child) {
      return Transform.translate(
        offset: Offset(_controller.value * maxDrag, 0),
        child: child,
      );
    },
    child: const Card(child: Text('Drag me')),
  ),
)
```

---

## 8. Shader-based Transitions

### Overview

Fragment shaders execute GLSL code on the GPU per-pixel, enabling effects impossible with standard widgets: dissolves, ripples, distortions, chromatic aberration, noise transitions.

**When to use:** High-end visual effects, custom page transitions, brand-differentiating animations.

**Performance cost:** Medium-High. Runs per-pixel every frame. Cost scales with resolution and shader complexity.

**Cross-platform:** Android and iOS (Impeller). NOT supported on Flutter Web. Desktop support varies.

### Setup

**1. Write a .frag shader file:**

```glsl
// shaders/dissolve.frag
#version 320 es
precision mediump float;

#include <flutter/runtime_effect.glsl>

uniform float progress;      // 0.0 to 1.0
uniform vec2 resolution;
uniform sampler2D image;

out vec4 fragColor;

void main() {
  vec2 uv = FlutterFragCoord().xy / resolution;
  vec4 color = texture(image, uv);

  // Simple dissolve using noise-like pattern
  float noise = fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
  float threshold = progress;

  if (noise < threshold) {
    fragColor = vec4(0.0); // transparent
  } else {
    fragColor = color;
  }
}
```

**2. Register in pubspec.yaml:**

```yaml
flutter:
  shaders:
    - shaders/dissolve.frag
```

**3. Load and use in Dart:**

```dart
class ShaderTransition extends StatefulWidget {
  // ...
}

class _ShaderTransitionState extends State<ShaderTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  FragmentShader? _shader;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1));
    _loadShader();
  }

  Future<void> _loadShader() async {
    final program = await FragmentProgram.fromAsset('shaders/dissolve.frag');
    setState(() => _shader = program.fragmentShader());
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_shader == null) return widget.child;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        _shader!
          ..setFloat(0, _controller.value)        // progress
          ..setFloat(1, MediaQuery.sizeOf(context).width)  // resolution.x
          ..setFloat(2, MediaQuery.sizeOf(context).height); // resolution.y
        return ShaderMask(
          shaderCallback: (bounds) => _shader!,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
```

### GLSL Subset Limitations (FLSL)

Flutter uses a subset of GLSL ES 3.20 called FLSL:
- No geometry or vertex shaders — fragment shaders only.
- No integer uniforms — use float and cast.
- Limited sampler support — `sampler2D` only.
- Must include `<flutter/runtime_effect.glsl>` for `FlutterFragCoord()`.
- Uniform indexing starts at 0 and must be sequential floats.

### Impeller vs Skia

As of 2026, Impeller has fully replaced Skia on iOS and Android:
- Impeller pre-compiles all shaders at build time — no first-frame jank.
- Custom fragment shaders are converted to SPIR-V (Android/Linux) or MSL (iOS/macOS) during build.
- On web, there is NO Impeller backend. Fragment shaders do not work on Flutter Web.

### Performance Tips

- Cache `FragmentProgram` instances — load once, reuse.
- Reuse `FragmentShader` objects across frames — just update uniforms.
- Keep GLSL lean: avoid branching (`if/else`), minimize `texture()` calls.
- Precompute values in Dart and pass as uniforms rather than computing in shader.
- Lower resolution for complex shaders: render to a smaller `ImageFilter` and scale up.

---

## 9. Rive and Lottie Animations

### Rive

**What it is:** A real-time interactive animation tool with its own editor, state machine system, and GPU-accelerated renderer.

**When to use:** Interactive animations that respond to user input (animated buttons, character reactions, loading states with logic, onboarding flows with state machines). Also excellent for complex vector animations where file size matters.

**Performance cost:** Low-Medium. Custom GPU renderer bypasses Flutter's widget system.

**Cross-platform:** Android, iOS, Web, Linux, macOS, Windows.

**File size:** Binary `.riv` format — 10-15x smaller than equivalent Lottie JSON. A 240KB Lottie file can be ~16KB as Rive.

```dart
// pubspec.yaml: rive: ^0.13.0
import 'package:rive/rive.dart';

class AnimatedButton extends StatefulWidget {
  @override
  State<AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<AnimatedButton> {
  late RiveAnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = OneShotAnimation('tap', autoplay: false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _controller.isActive = true,
      child: RiveAnimation.asset(
        'assets/button.riv',
        controllers: [_controller],
        fit: BoxFit.contain,
      ),
    );
  }
}
```

**Rive State Machine (interactive):**
```dart
class InteractiveRive extends StatefulWidget {
  @override
  State<InteractiveRive> createState() => _InteractiveRiveState();
}

class _InteractiveRiveState extends State<InteractiveRive> {
  StateMachineController? _smController;
  SMIBool? _isHovered;

  void _onRiveInit(Artboard artboard) {
    _smController = StateMachineController.fromArtboard(artboard, 'State Machine 1');
    artboard.addController(_smController!);
    _isHovered = _smController!.findInput<bool>('hover') as SMIBool?;
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _isHovered?.value = true,
      onExit: (_) => _isHovered?.value = false,
      child: RiveAnimation.asset(
        'assets/interactive.riv',
        onInit: _onRiveInit,
      ),
    );
  }
}
```

### Lottie

**What it is:** After Effects animations exported as JSON via Bodymovin plugin. Rendered frame-by-frame.

**When to use:** Simple decorative animations (loading spinners, success checkmarks, empty states, micro-interactions). Best when your design team already uses After Effects.

**Performance cost:** Low for simple animations. Medium-High for complex ones with many layers.

**Cross-platform:** Android, iOS, Web, Linux, macOS, Windows.

**File size:** JSON format. `.lottie` (dotLottie) format reduces by 40-70% via ZIP compression.

```dart
// pubspec.yaml: lottie: ^3.0.0
import 'package:lottie/lottie.dart';

// Simple playback
Lottie.asset(
  'assets/success.json',
  width: 200,
  height: 200,
  repeat: false,
)

// With controller for precise control
class LottieExample extends StatefulWidget {
  @override
  State<LottieExample> createState() => _LottieExampleState();
}

class _LottieExampleState extends State<LottieExample>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Lottie.asset(
      'assets/progress.json',
      controller: _controller,
      onLoaded: (composition) {
        _controller.duration = composition.duration;
        _controller.forward();
      },
    );
  }
}
```

### Rive vs Lottie Decision Matrix

| Factor | Rive | Lottie |
|--------|------|--------|
| Interactivity | Built-in state machines | None (playback only) |
| File size | ~10-15x smaller | Larger (JSON-based) |
| Rendering | Custom GPU renderer | Canvas-based |
| Design tool | Rive editor (web-based) | After Effects + Bodymovin |
| Learning curve | New tool to learn | AE is widely known |
| Runtime logic | State machines, conditions | Manual controller code |
| Community | Growing fast | Very large, mature |
| Best for | Interactive, stateful animations | Decorative, playback animations |

---

## 10. Performance Optimization

### RepaintBoundary

**What it does:** Creates a separate composited layer so unchanged widgets reuse cached bitmaps instead of repainting.

**When to use:** Around any widget that updates frequently (animated spinners, progress bars, ticking clocks) while its siblings remain static.

**When NOT to use:** Don't wrap everything — each boundary adds memory and GPU compositing overhead. Only isolate widgets that repaint often AND are expensive to rebuild.

```dart
// Good: animated widget isolated from static siblings
Column(
  children: [
    const Text('Static header'),  // Won't repaint when spinner changes
    RepaintBoundary(
      child: SpinnerWidget(animation: _controller),
    ),
    const Text('Static footer'),
  ],
)
```

### const Constructors

Widgets marked `const` are compile-time constants. Flutter skips rebuilding them entirely during `setState` or animation ticks.

```dart
// BAD: rebuilds Text every frame
AnimatedBuilder(
  animation: _controller,
  builder: (context, child) {
    return Transform.scale(
      scale: _controller.value,
      child: Text('Hello'),  // Rebuilt every frame
    );
  },
)

// GOOD: Text is const, passed as child, never rebuilt
AnimatedBuilder(
  animation: _controller,
  builder: (context, child) {
    return Transform.scale(scale: _controller.value, child: child);
  },
  child: const Text('Hello'),  // Built once
)
```

### Avoid setState During Animations

`setState` triggers a full widget rebuild. For animations, use `AnimatedBuilder` or `ValueListenableBuilder` to limit rebuilds to a specific subtree.

```dart
// BAD: entire widget tree rebuilds 60 times/second
_controller.addListener(() {
  setState(() {}); // Rebuilds everything
});

// GOOD: only the builder function runs
AnimatedBuilder(
  animation: _controller,
  builder: (context, child) {
    return Opacity(opacity: _controller.value, child: child);
  },
  child: const ExpensiveWidget(), // Built once
)
```

### Transform vs Layout Changes

**GPU-composited (cheap):** `Transform.translate`, `Transform.rotate`, `Transform.scale`, `Opacity`.
These apply a matrix transform at the compositing layer — no layout recalculation.

**Layout-triggering (expensive):** Changing `width`, `height`, `padding`, `margin`, `Positioned` coordinates.
These force the widget and potentially its ancestors to recalculate layout.

```dart
// CHEAP: GPU-only, no layout
Transform.translate(
  offset: Offset(_controller.value * 100, 0),
  child: child,
)

// EXPENSIVE: triggers layout every frame
Container(
  margin: EdgeInsets.only(left: _controller.value * 100),
  child: child,
)
```

### Listenable Builders vs setState

```dart
// ValueListenableBuilder for single value changes
ValueListenableBuilder<double>(
  valueListenable: _progress,
  builder: (context, value, child) {
    return LinearProgressIndicator(value: value);
  },
)

// ListenableBuilder (Flutter 3.10+) for any Listenable
ListenableBuilder(
  listenable: _controller,
  builder: (context, child) {
    return Transform.rotate(
      angle: _controller.value * 2 * math.pi,
      child: child,
    );
  },
  child: const Icon(Icons.refresh),
)
```

### Pre-warming and Caching

```dart
// Pre-load Rive/Lottie files before they're needed
late final Future<RiveFile> _riveFile;

@override
void initState() {
  super.initState();
  _riveFile = RiveFile.asset('assets/animation.riv'); // Start loading immediately
}

// Cache fragment shader programs
static FragmentProgram? _cachedProgram;

Future<FragmentShader> _getShader() async {
  _cachedProgram ??= await FragmentProgram.fromAsset('shaders/effect.frag');
  return _cachedProgram!.fragmentShader();
}
```

### 120Hz Considerations

- On 120Hz displays, you have ~8ms per frame instead of ~16ms.
- Flutter automatically adjusts ticker rate to match display refresh.
- Profile on 120Hz devices — animations that are smooth at 60Hz may jank at 120Hz.
- Impeller's pre-compiled shaders help maintain consistent frame times.
- Reduce `paint()` complexity for CustomPainter on high-refresh displays.
- Avoid allocations in hot animation loops — GC pauses hit harder at 120Hz.

---

## 11. Advanced Packages

### flutter_animate

**What it does:** Declarative animation chains via extension methods. No controllers to manage.

**Best for:** Quick, composable animations. Prototyping. Entrance effects.

**Performance:** Low overhead. Manages controllers internally.

**Cross-platform:** All platforms.

```dart
// pubspec.yaml: flutter_animate: ^4.5.0

// Chained API (most common)
Text('Hello')
  .animate()
  .fadeIn(duration: 300.ms)
  .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic)
  .then(delay: 200.ms)  // Sequential: wait for previous
  .shimmer(duration: 1200.ms);

// Parallel effects (default behavior)
Icon(Icons.star)
  .animate()
  .fade(duration: 500.ms)
  .scale(begin: const Offset(0.5, 0.5), end: const Offset(1, 1))
  .rotate(begin: -0.1, end: 0);

// Looping
Container(color: Colors.blue, width: 50, height: 50)
  .animate(onPlay: (controller) => controller.repeat())
  .shimmer(duration: 1.5.seconds, color: Colors.white24);

// Staggered list entrance
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) {
    return ListTile(title: Text(items[index]))
      .animate()
      .fadeIn(delay: (index * 100).ms)
      .slideX(begin: 0.1, end: 0);
  },
)
```

### animations (Material Motion)

**What it does:** Official Flutter package implementing Material Design motion patterns.

**Best for:** Material-compliant transitions. Container transforms, shared axis, fade through.

**Performance:** Low-Medium. Well-optimized by Google.

**Cross-platform:** All platforms.

```dart
// pubspec.yaml: animations: ^2.0.0

// Container Transform — item expands into detail page
OpenContainer(
  closedBuilder: (context, openContainer) {
    return ListTile(
      title: Text(item.title),
      onTap: openContainer,
    );
  },
  openBuilder: (context, closeContainer) {
    return DetailPage(item: item, onClose: closeContainer);
  },
  closedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  transitionDuration: const Duration(milliseconds: 500),
)

// Shared Axis — navigational transition
PageTransitionSwitcher(
  duration: const Duration(milliseconds: 400),
  transitionBuilder: (child, primaryAnimation, secondaryAnimation) {
    return SharedAxisTransition(
      animation: primaryAnimation,
      secondaryAnimation: secondaryAnimation,
      transitionType: SharedAxisTransitionType.horizontal,
      child: child,
    );
  },
  child: _pages[_currentIndex], // Key must change
)

// Fade Through — non-connected elements
PageTransitionSwitcher(
  transitionBuilder: (child, primaryAnimation, secondaryAnimation) {
    return FadeThroughTransition(
      animation: primaryAnimation,
      secondaryAnimation: secondaryAnimation,
      child: child,
    );
  },
  child: _currentWidget,
)
```

### simple_animations

**What it does:** Timeline-based multi-property animations, stateless animation widgets.

**Best for:** Multi-property tweens in a single timeline. Simple looping animations without boilerplate.

**Performance:** Low.

**Cross-platform:** All platforms.

```dart
// pubspec.yaml: simple_animations: ^5.0.0

// MovieTween — multi-property timeline
final tween = MovieTween()
  ..tween('width', Tween(begin: 0.0, end: 200.0),
      duration: const Duration(milliseconds: 700), curve: Curves.easeOut)
  ..tween('height', Tween(begin: 0.0, end: 150.0),
      duration: const Duration(milliseconds: 700), curve: Curves.easeOut)
  ..tween('color', ColorTween(begin: Colors.red, end: Colors.blue),
      duration: const Duration(milliseconds: 700));

// PlayAnimationBuilder — plays once
PlayAnimationBuilder<Movie>(
  tween: tween,
  duration: tween.duration,
  builder: (context, value, child) {
    return Container(
      width: value.get('width'),
      height: value.get('height'),
      color: value.get('color'),
    );
  },
)

// LoopAnimationBuilder — continuous loop
LoopAnimationBuilder<double>(
  tween: Tween(begin: 0, end: 2 * math.pi),
  duration: const Duration(seconds: 2),
  builder: (context, value, child) {
    return Transform.rotate(angle: value, child: child);
  },
  child: const Icon(Icons.sync),
)
```

### rive

**What it does:** Runtime for Rive animations with state machine support.

**Version:** `rive: ^0.13.0`

See [Section 9](#9-rive-and-lottie-animations) for detailed usage.

### lottie

**What it does:** Renders After Effects animations exported as JSON.

**Version:** `lottie: ^3.0.0`

See [Section 9](#9-rive-and-lottie-animations) for detailed usage.

### Other Notable Packages

| Package | Purpose | Notes |
|---------|---------|-------|
| `animate_do` | Pre-built entrance animations (FadeIn, BounceIn, etc.) | Very simple API, good for quick effects |
| `animated_text_kit` | Text animations (typewriter, wavy, colorize, etc.) | Good for onboarding, splash screens |
| `motion` | Device gyroscope-based parallax/tilt effects | Mobile only (uses accelerometer) |
| `spring` | Simple spring-based implicit animations | Lightweight alternative to physics sim |
| `animated_reorderable_list` | Animated list reordering with drag | Better than stock AnimatedList for reorder |
| `flutter_staggered_animations` | Easy staggered grid/list animations | Quick setup, less flexible than manual |
| `auto_animated` | Automatic scroll-based entrance animations | Good for landing pages |

---

## 12. Cross-platform Considerations

### Platform Support Matrix

| Feature | Android | iOS | Web | Linux | macOS | Windows |
|---------|---------|-----|-----|-------|-------|---------|
| Implicit animations | Full | Full | Full | Full | Full | Full |
| Explicit animations | Full | Full | Full | Full | Full | Full |
| Hero transitions | Full | Full | Full | Full | Full | Full |
| CustomPainter | Full | Full | Full | Full | Full | Full |
| Physics simulations | Full | Full | Full | Full | Full | Full |
| Fragment shaders | Full | Full | **No** | Partial | Partial | Partial |
| Rive | Full | Full | Full | Full | Full | Full |
| Lottie | Full | Full | Full | Full | Full | Full |
| 120Hz support | Yes | Yes | Browser-dependent | Display-dependent | Yes | Yes |
| Impeller renderer | Default | Default | **No** | In progress | In progress | In progress |

### Rendering Engines (2026 Status)

**Mobile (Android/iOS):**
- Impeller is the default renderer. Skia is deprecated.
- Pre-compiled shaders eliminate first-frame jank.
- Fragment shaders are converted to SPIR-V (Android) or MSL (iOS) at build time.
- 120Hz display support is automatic via ticker.

**Web:**
- CanvasKit (WebAssembly Skia) is the current standard renderer.
- Skwasm (WebAssembly + shared memory) offers better startup and frame performance.
- HTML renderer is deprecated and removed in recent stable releases.
- **Fragment shaders do NOT work on web** — there is no Impeller web backend.
- Large initial download size (~2-3MB for CanvasKit WASM).
- Web WASM (Dart compiled to WebAssembly) is the recommended path for 2026.

**Desktop (Linux/macOS/Windows):**
- Impeller adoption is in progress but not fully default on all desktop platforms.
- Skia still used as fallback on some desktop targets.
- Fragment shader support varies — test on target platform.
- Performance is generally excellent on desktop hardware.

### Web-specific Workarounds

```dart
import 'package:flutter/foundation.dart' show kIsWeb;

Widget buildAnimation() {
  if (kIsWeb) {
    // Use standard Flutter transitions instead of shaders
    return FadeTransition(opacity: _animation, child: content);
  } else {
    // Use shader-based transition on mobile
    return ShaderTransitionWidget(animation: _animation, child: content);
  }
}
```

### Performance Profiles by Platform

**Fastest:** iOS (Impeller + Metal, consistent 120fps on modern devices)

**Fast:** Android (Impeller + Vulkan/OpenGL, varies by GPU — flagship devices match iOS)

**Moderate:** Desktop (powerful hardware compensates for less-optimized rendering path)

**Slowest:** Web (JavaScript/WASM overhead, no GPU shader access, canvas limitations). Avoid complex CustomPainter animations and staggered effects with many elements on web.

---

## 13. Resource-efficient Patterns

### Lazy Animation Initialization

Don't create controllers until they're needed:

```dart
AnimationController? _controller;

void _ensureController() {
  _controller ??= AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );
}

void startAnimation() {
  _ensureController();
  _controller!.forward();
}

@override
void dispose() {
  _controller?.dispose();
  super.dispose();
}
```

### Proper Controller Disposal

Every `AnimationController` must be disposed. Failure to dispose causes memory leaks and ticker leaks (the ticker keeps firing after the widget is removed).

```dart
// Single controller
@override
void dispose() {
  _controller.dispose();
  super.dispose();
}

// Multiple controllers
@override
void dispose() {
  _fadeController.dispose();
  _slideController.dispose();
  _scaleController.dispose();
  super.dispose();
}
```

### const Widgets Around Animated Children

```dart
// The child parameter of AnimatedBuilder is built ONCE and reused
AnimatedBuilder(
  animation: _controller,
  builder: (context, child) {
    return Transform.translate(
      offset: Offset(0, _controller.value * -20),
      child: child,
    );
  },
  // Everything below is const — never rebuilt during animation
  child: const Card(
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Icon(Icons.star, size: 48),
          SizedBox(height: 8),
          Text('Rating', style: TextStyle(fontSize: 18)),
        ],
      ),
    ),
  ),
)
```

### AnimatedList for Efficient List Animations

```dart
final _listKey = GlobalKey<AnimatedListState>();
final _items = <String>[];

void _addItem(String item) {
  _items.add(item);
  _listKey.currentState?.insertItem(_items.length - 1,
    duration: const Duration(milliseconds: 300),
  );
}

void _removeItem(int index) {
  final removed = _items.removeAt(index);
  _listKey.currentState?.removeItem(index,
    (context, animation) => SizeTransition(
      sizeFactor: animation,
      child: ListTile(title: Text(removed)),
    ),
    duration: const Duration(milliseconds: 300),
  );
}

@override
Widget build(BuildContext context) {
  return AnimatedList(
    key: _listKey,
    initialItemCount: _items.length,
    itemBuilder: (context, index, animation) {
      return SlideTransition(
        position: animation.drive(
          Tween(begin: const Offset(1, 0), end: Offset.zero)
              .chain(CurveTween(curve: Curves.easeOutCubic)),
        ),
        child: ListTile(title: Text(_items[index])),
      );
    },
  );
}
```

### SliverAnimatedList for Large Scrollable Lists

Use `SliverAnimatedList` inside a `CustomScrollView` for better integration with slivers and lazy loading:

```dart
CustomScrollView(
  slivers: [
    const SliverAppBar(title: Text('Items'), floating: true),
    SliverAnimatedList(
      key: _sliverListKey,
      initialItemCount: _items.length,
      itemBuilder: (context, index, animation) {
        return FadeTransition(
          opacity: animation,
          child: SizeTransition(
            sizeFactor: animation,
            child: ListTile(title: Text(_items[index])),
          ),
        );
      },
    ),
  ],
)
```

### Prefer Transform Over Layout Changes

```dart
// DO: Transform.translate (GPU composited, no layout)
AnimatedBuilder(
  animation: _controller,
  builder: (context, child) {
    return Transform.translate(
      offset: Offset(0, -_controller.value * 50),
      child: child,
    );
  },
  child: const MyWidget(),
)

// DON'T: Padding/Margin changes (triggers layout every frame)
AnimatedBuilder(
  animation: _controller,
  builder: (context, child) {
    return Padding(
      padding: EdgeInsets.only(top: (1 - _controller.value) * 50),
      child: child,
    );
  },
  child: const MyWidget(),
)
```

### Ticker Mixin Selection

```dart
// ONE controller — use Single (lighter weight)
class _MyState extends State<MyWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
}

// MULTIPLE controllers — use the multi version
class _MyState extends State<MyWidget> with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final AnimationController _slideController;
}
```

### Offscreen Compositing with Transform

`Transform` widgets create a composited layer that the GPU can manipulate without affecting layout. This is the cheapest type of animation.

```dart
// Scale, rotate, and translate are all GPU-composited
Transform(
  transform: Matrix4.identity()
    ..setEntry(3, 2, 0.001) // Perspective
    ..rotateX(_controller.value * 0.5)
    ..rotateY(_controller.value * 0.3),
  alignment: Alignment.center,
  child: const Card(child: Text('3D Card')),
)
```

---

## 14. Decision Framework

Use this flowchart to pick the right animation approach:

```
Is it a simple property change (color, size, opacity)?
├── YES → Use Implicit Animation (AnimatedContainer, AnimatedOpacity, etc.)
│         No controller needed. Lowest code overhead.
└── NO
    ↓
Do you need precise control (pause, reverse, repeat, listen)?
├── YES → Use Explicit Animation (AnimationController + Tween)
│         ├── Single property? → Use pre-built Transition widget (FadeTransition, etc.)
│         ├── Multiple properties? → Use AnimatedBuilder with multiple Tweens
│         └── Sequence of effects? → Use Staggered with Interval
└── NO
    ↓
Is it a screen-to-screen transition?
├── YES → Is there a shared element?
│         ├── YES → Use Hero animation
│         └── NO  → Use PageRouteBuilder or Material Motion (animations package)
└── NO
    ↓
Does it respond to gestures/velocity?
├── YES → Use Physics-based animation (SpringSimulation, FrictionSimulation)
└── NO
    ↓
Is it a complex vector animation from a designer?
├── YES → Is it interactive/stateful?
│         ├── YES → Use Rive
│         └── NO  → Use Lottie (if from After Effects) or Rive
└── NO
    ↓
Is it a custom visual effect (dissolve, ripple, distortion)?
├── YES → Can you skip web support?
│         ├── YES → Use Fragment Shaders
│         └── NO  → Use CustomPainter (fallback for web)
└── NO
    ↓
Is it a custom shape/path animation?
├── YES → Use CustomPainter with repaint: animation
└── NO  → Re-evaluate — one of the above likely fits
```

### Quick Reference: Performance Cost Ranking

| Technique | CPU Cost | GPU Cost | Memory | Code Complexity |
|-----------|----------|----------|--------|-----------------|
| Implicit (AnimatedContainer) | Very Low | Low | Low | Very Low |
| Transform-based explicit | Low | Low | Low | Low |
| FadeTransition / SlideTransition | Low | Low | Low | Low |
| AnimatedSwitcher | Low | Low | Medium | Low |
| Hero | Medium | Medium | Medium | Low |
| Staggered (multiple Intervals) | Medium | Low-Medium | Low | Medium |
| AnimatedList | Medium | Low | Medium | Medium |
| Physics simulation | Low | Low | Low | Medium |
| CustomPainter (simple) | Medium | Low | Low | Medium |
| CustomPainter (complex) | High | Medium | Low | High |
| Lottie | Medium | Medium | Medium | Low |
| Rive | Low-Medium | Medium | Medium | Low-Medium |
| Fragment Shaders | Low | High | Low | High |
| Material Motion (OpenContainer) | Medium | Medium | Medium | Low |

---

## Appendix: Common Curves Reference

| Curve | Behavior | Best For |
|-------|----------|----------|
| `Curves.linear` | Constant speed | Progress indicators |
| `Curves.easeIn` | Slow start, fast end | Exit animations |
| `Curves.easeOut` | Fast start, slow end | Entrance animations |
| `Curves.easeInOut` | Slow start and end | General purpose |
| `Curves.easeOutCubic` | Smooth deceleration | Most UI animations |
| `Curves.easeInOutCubic` | Smooth S-curve | Page transitions |
| `Curves.easeOutBack` | Overshoot then settle | Playful entrances |
| `Curves.elasticOut` | Spring-like bounce | Attention-grabbing |
| `Curves.bounceOut` | Ball-drop bounce | Playful, cartoonish |
| `Curves.fastOutSlowIn` | Material standard curve | Material Design |
| `Curves.decelerate` | Smooth stop | Fling-to-stop |

**Custom curves:**
```dart
// Cubic bezier (match CSS cubic-bezier values)
const customCurve = Cubic(0.25, 0.1, 0.25, 1.0);

// Spring curve
final springCurve = SpringDescription(mass: 1, stiffness: 100, damping: 10);
```

---

## Appendix: Duration Guidelines

| Animation Type | Recommended Duration | Notes |
|----------------|---------------------|-------|
| Micro-interaction (tap feedback) | 50-150ms | Should feel instant |
| Fade in/out | 150-300ms | Standard visibility toggle |
| Slide / position change | 200-400ms | Depends on distance |
| Page transition | 300-500ms | Material default is 300ms |
| Hero transition | 300-500ms | Complex heroes may need more |
| Staggered cascade (per item) | 50-150ms delay between items | Total under 1-2 seconds |
| Physics (spring) | No fixed duration | Determined by simulation |
| Complex entrance | 600-1200ms total | Keep individual steps shorter |
| Loading animation (loop) | 1-3 seconds per cycle | Should not be distracting |
