# Diagonal Gradient Sweep + Staggered Card Transition — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the broken vertical fade-overlay page transition with a diagonal gradient band that wipes old→new page, plus a BcStaggeredList widget for card stagger animations.

**Architecture:** CustomClipper-based diagonal reveal with CustomPaint gradient band overlay. BcStaggeredList reads ModalRoute animation and applies per-child staggered Intervals. All existing bcSweepPage/bcBurstPage APIs preserved — zero route changes.

**Tech Stack:** Flutter CustomClipper, CustomPaint, ModalRoute animation, GoRouter CustomTransitionPage

**Spec:** `docs/superpowers/specs/2026-03-26-diagonal-sweep-stagger-transition-design.md`

---

## File Structure

| File | Role |
|------|------|
| `beautycita_app/lib/config/app_transitions.dart` | Rewrite `bcSweepStaggerTransition` + diagonal clipper/painter. Add `BcStaggeredList`. Keep all public API signatures. |
| `beautycita_app/lib/screens/home_screen.dart` | No changes — already has `flutter_animate` per-card stagger that works with the diagonal sweep. |
| `beautycita_app/lib/screens/provider_list_screen.dart` | Wrap `ListView.builder` items with stagger. |
| `beautycita_app/lib/screens/result_cards_screen.dart` | Wrap Column children with stagger. |

---

### Task 1: Rewrite diagonal sweep transition

**Files:**
- Modify: `beautycita_app/lib/config/app_transitions.dart`

This is the core task. Replace `bcSweepStaggerTransition` with the diagonal clip-and-reveal approach.

- [ ] **Step 1: Replace `_DiagonalClipper` and `_DiagonalBandPainter`**

Delete the existing `bcSweepStaggerTransition` function body (lines 21-90). Replace with:

```dart
Widget bcSweepStaggerTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  final size = MediaQuery.of(context).size;
  final theme = Theme.of(context);

  // Brand colors from theme (fallback to hardcoded if unavailable)
  final pink = theme.colorScheme.primary;
  final purple = theme.colorScheme.secondary;
  final blue = theme.colorScheme.tertiary;

  // Sweep progress: band crosses screen diagonal
  final sweepProgress = CurvedAnimation(
    parent: animation,
    curve: const Interval(0.0, 0.65, curve: Curves.easeInOutCubic),
  );

  // Content fade + slide (starts before sweep finishes)
  final contentOpacity = CurvedAnimation(
    parent: animation,
    curve: const Interval(0.20, 0.85, curve: Curves.easeOut),
  );
  final contentSlide = Tween<Offset>(
    begin: const Offset(0, 0.05),
    end: Offset.zero,
  ).animate(CurvedAnimation(
    parent: animation,
    curve: const Interval(0.20, 0.85, curve: Curves.easeOutCubic),
  ));

  return AnimatedBuilder(
    animation: animation,
    builder: (context, _) {
      final t = sweepProgress.value;
      return Stack(
        children: [
          // Clipped new page — revealed by diagonal
          ClipPath(
            clipper: _DiagonalRevealClipper(progress: t, size: size),
            child: SlideTransition(
              position: contentSlide,
              child: FadeTransition(
                opacity: contentOpacity,
                child: child,
              ),
            ),
          ),
          // Gradient band on the clip edge
          if (t > 0.01 && t < 0.99)
            CustomPaint(
              size: size,
              painter: _DiagonalBandPainter(
                progress: t,
                screenSize: size,
                colors: [pink, purple, blue],
              ),
            ),
        ],
      );
    },
  );
}
```

- [ ] **Step 2: Implement `_DiagonalRevealClipper`**

```dart
class _DiagonalRevealClipper extends CustomClipper<Path> {
  final double progress;
  final Size size;

  _DiagonalRevealClipper({required this.progress, required this.size});

  @override
  Path getClip(Size size) {
    // Diagonal angle based on screen aspect ratio
    final diagonal = math.sqrt(size.width * size.width + size.height * size.height);
    final angle = math.atan2(size.width, size.height);

    // Band width in diagonal-axis space
    const bandHalf = 60.0;

    // How far along the diagonal the leading edge has traveled
    // Extend beyond diagonal so clip fully covers screen at t=1
    final travel = progress * (diagonal + bandHalf * 2) - bandHalf;

    // The clip boundary is a line perpendicular to the diagonal,
    // positioned at 'travel' along the diagonal axis from top-left.
    // We build a polygon covering everything "behind" (upper-left of) this line.

    // Direction vector along the diagonal (top-left → bottom-right)
    final dx = math.sin(angle); // normalized x component
    final dy = math.cos(angle); // normalized y component

    // Point on diagonal at 'travel' distance
    final cx = travel * dx;
    final cy = travel * dy;

    // Perpendicular direction (rotated 90°)
    final px = -dy;
    final py = dx;

    // Extend perpendicular line far enough to exceed screen bounds
    final extend = diagonal;

    final path = Path();
    // Line across screen at the clip boundary
    final x1 = cx + px * extend;
    final y1 = cy + py * extend;
    final x2 = cx - px * extend;
    final y2 = cy - py * extend;

    // Polygon: clip boundary line + everything to top-left
    path.moveTo(x1, y1);
    path.lineTo(x2, y2);
    // Close toward top-left corner area
    path.lineTo(x2 - dx * diagonal * 2, y2 - dy * diagonal * 2);
    path.lineTo(x1 - dx * diagonal * 2, y1 - dy * diagonal * 2);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(covariant _DiagonalRevealClipper old) =>
      old.progress != progress;
}
```

- [ ] **Step 3: Implement `_DiagonalBandPainter`**

```dart
class _DiagonalBandPainter extends CustomPainter {
  final double progress;
  final Size screenSize;
  final List<Color> colors;

  _DiagonalBandPainter({
    required this.progress,
    required this.screenSize,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final diagonal = math.sqrt(size.width * size.width + size.height * size.height);
    final angle = math.atan2(size.width, size.height);

    const bandHalf = 60.0;
    final travel = progress * (diagonal + bandHalf * 2) - bandHalf;

    final cx = travel * math.sin(angle);
    final cy = travel * math.cos(angle);

    canvas.save();
    canvas.translate(cx, cy);
    // Rotate so the band is perpendicular to the diagonal
    canvas.rotate(angle);

    final bandRect = Rect.fromCenter(
      center: Offset.zero,
      width: bandHalf * 2,
      height: diagonal * 2,
    );

    // Soft opacity that fades at edges of the animation
    final edgeFade = (1.0 - (progress * 2 - 1).abs()).clamp(0.0, 1.0);
    final alpha = 0.7 * edgeFade;

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.transparent,
          colors[0].withValues(alpha: alpha * 0.3),
          colors[0].withValues(alpha: alpha * 0.7),
          colors[1].withValues(alpha: alpha),
          colors[2].withValues(alpha: alpha * 0.7),
          colors[2].withValues(alpha: alpha * 0.3),
          Colors.transparent,
        ],
      ).createShader(bandRect)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    canvas.drawRect(bandRect, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DiagonalBandPainter old) =>
      old.progress != progress;
}
```

- [ ] **Step 4: Keep brand color constants for radial burst**

The top-level `_brandPink`, `_brandPurple`, `_brandBlue` constants (lines 13-15) are still used by `_RadialGlowPainter` and the radial burst transition. Do NOT delete them. The new diagonal sweep reads colors from `Theme.of(context)` but the existing radial burst code stays unchanged.

- [ ] **Step 5: Update bcSweepPage duration**

In `bcSweepPage` (around line 185), update the durations to match the spec:
```dart
// FROM:
transitionDuration: const Duration(milliseconds: 550),
reverseTransitionDuration: const Duration(milliseconds: 400),

// TO:
transitionDuration: const Duration(milliseconds: 650),
reverseTransitionDuration: const Duration(milliseconds: 450),
```

Also update `bcSlashPage` since it delegates to `bcSweepPage` (confirm it still does after the rewrite).

- [ ] **Step 6: Preserve bcDiagonalSlashTransition alias**

The file ends with `bcDiagonalSlashTransition` (line ~367) which aliases to `bcSweepStaggerTransition`. This is used in some screens. Leave it in place — it will automatically use the new diagonal sweep since it delegates to `bcSweepStaggerTransition`.

- [ ] **Step 7: Test on device**

```bash
cd /home/bc/futureBeauty/beautycita_app
flutter run -d 192.168.0.40:5555
```

Navigate between screens. Verify:
- Diagonal band sweeps top-left → bottom-right
- New page revealed behind the band
- No hard clip edges or screen tears
- Pop (back) reverses the diagonal cleanly
- Band has soft gradient glow, not a hard line

- [ ] **Step 8: Commit**

```bash
git add beautycita_app/lib/config/app_transitions.dart
git commit -m "Rewrite page transition: diagonal gradient sweep with clip reveal"
```

---

### Task 2: Add BcStaggeredList widget

**Files:**
- Modify: `beautycita_app/lib/config/app_transitions.dart` (append to end)

- [ ] **Step 1: Add BcStaggeredList widget**

Append to `app_transitions.dart`:

```dart
// ═══════════════════════════════════════════════════════════════════════════
// BcStaggeredList — drop-in ListView replacement with route-driven stagger
// ═══════════════════════════════════════════════════════════════════════════

class BcStaggeredList extends StatelessWidget {
  final List<Widget> children;
  final ScrollPhysics? physics;
  final EdgeInsetsGeometry? padding;
  final bool shrinkWrap;

  const BcStaggeredList({
    super.key,
    required this.children,
    this.physics,
    this.padding,
    this.shrinkWrap = false,
  });

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context);
    final animation = route?.animation;

    // No route animation (dialog, test, or already complete) → render immediately
    if (animation == null || animation.isCompleted) {
      return ListView(
        physics: physics,
        padding: padding,
        shrinkWrap: shrinkWrap,
        children: children,
      );
    }

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        // Once animation completes, just show children
        if (animation.isCompleted) {
          return ListView(
            physics: physics,
            padding: padding,
            shrinkWrap: shrinkWrap,
            children: children,
          );
        }

        return ListView(
          physics: physics,
          padding: padding,
          shrinkWrap: shrinkWrap,
          children: [
            for (int i = 0; i < children.length; i++)
              _BcStaggerItem(
                animation: animation,
                index: i,
                child: children[i],
              ),
          ],
        );
      },
    );
  }
}

class _BcStaggerItem extends StatelessWidget {
  final Animation<double> animation;
  final int index;
  final Widget child;

  const _BcStaggerItem({
    required this.animation,
    required this.index,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // Stagger: each item starts 5% later, capped at 8 slots
    final slot = index.clamp(0, 7);
    final start = 0.45 + slot * 0.05;
    final end = (start + 0.20).clamp(0.0, 1.0);

    final itemAnimation = CurvedAnimation(
      parent: animation,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );

    return FadeTransition(
      opacity: itemAnimation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(itemAnimation),
        child: child,
      ),
    );
  }
}
```

- [ ] **Step 2: Test on device**

Navigate to any screen. Verify BcStaggeredList compiles. (Integration with screens in Task 3.)

- [ ] **Step 3: Commit**

```bash
git add beautycita_app/lib/config/app_transitions.dart
git commit -m "Add BcStaggeredList widget for route-driven card stagger"
```

---

### Task 3: Integrate BcStaggeredList into screens

**Files:**
- Modify: `beautycita_app/lib/screens/provider_list_screen.dart`
- Modify: `beautycita_app/lib/screens/result_cards_screen.dart`
- Review: `beautycita_app/lib/screens/home_screen.dart` (already has flutter_animate stagger — may skip)

**Note on home_screen.dart:** The home screen already uses `flutter_animate` for per-card stagger on the GridView (`.animate().fadeIn().slideY()` with delay per index). This existing stagger works well and is independent of the page transition. Leave it as-is — the diagonal sweep will reveal the page, and the existing stagger will animate the cards. Double-staggering with BcStaggeredList would conflict.

- [ ] **Step 1: Update provider_list_screen.dart**

The screen uses `ListView.builder` at line 84. Since `BcStaggeredList` takes explicit children (not a builder), we need to wrap the built items. Replace the `ListView.builder` block:

In `provider_list_screen.dart`, around line 84, change:

```dart
// FROM:
return ListView.builder(
  physics: const BouncingScrollPhysics(),
  padding: const EdgeInsets.symmetric(
    horizontal: AppConstants.screenPaddingHorizontal,
    vertical: AppConstants.screenPaddingVertical,
  ),
  itemCount: providers.length,
  itemBuilder: (context, index) {
    final provider = providers[index];
    return Padding(
      padding: EdgeInsets.only(
        bottom: index < providers.length - 1
            ? AppConstants.cardSpacing
            : 0,
      ),
      child: _ProviderCard(
        provider: provider,
        categoryColor: effectiveColor,
        category: category,
        onTap: () => context.push('/provider/${provider.id}'),
      ),
    );
  },
);

// TO:
return BcStaggeredList(
  physics: const BouncingScrollPhysics(),
  padding: const EdgeInsets.symmetric(
    horizontal: AppConstants.screenPaddingHorizontal,
    vertical: AppConstants.screenPaddingVertical,
  ),
  children: [
    for (int i = 0; i < providers.length; i++)
      Padding(
        padding: EdgeInsets.only(
          bottom: i < providers.length - 1
              ? AppConstants.cardSpacing
              : 0,
        ),
        child: _ProviderCard(
          provider: providers[i],
          categoryColor: effectiveColor,
          category: category,
          onTap: () => context.push('/provider/${providers[i].id}'),
        ),
      ),
  ],
);
```

Add import at top if not already present (app_transitions.dart is already imported).

- [ ] **Step 2: Update result_cards_screen.dart**

The result cards screen uses a Column with Expanded for its swipe-card stack. Don't replace the Column — that would break the `Expanded` layout. Instead, wrap individual children with `_BcStaggerItem` directly by reading the route animation. Add a helper method to the state class:

```dart
// Add to _ResultCardsScreenState:
Widget _staggerChild(int index, Widget child) {
  final route = ModalRoute.of(context);
  final anim = route?.animation;
  if (anim == null || anim.isCompleted) return child;

  final slot = index.clamp(0, 7);
  final start = 0.45 + slot * 0.05;
  final end = (start + 0.20).clamp(0.0, 1.0);

  final curved = CurvedAnimation(
    parent: anim,
    curve: Interval(start, end, curve: Curves.easeOutCubic),
  );

  return FadeTransition(
    opacity: curved,
    child: SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.08),
        end: Offset.zero,
      ).animate(curved),
      child: child,
    ),
  );
}
```

Then wrap each Column child around line 265:

```dart
body: Column(
  children: [
    _staggerChild(0, const Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: CinematicQuestionText(
        text: 'Elige tu mejor opcion',
        fontSize: 24,
      ),
    )),
    _staggerChild(1, Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        '${_currentIndex + 1}/$_totalCards',
        ...
      ),
    )),
    Expanded(
      child: _staggerChild(2, _buildCardStack(results, _currentIndex)),
    ),
  ],
),
```

This preserves the Column + Expanded layout while adding the stagger effect.

- [ ] **Step 3: Test full flow on device**

```bash
cd /home/bc/futureBeauty/beautycita_app
flutter run -d 192.168.0.40:5555
```

Test sequence:
1. Home → tap category → subcategory sheet opens (burst transition, no change)
2. Subcategory → provider list: diagonal sweep + cards stagger in
3. Provider list → provider detail: diagonal sweep
4. Back navigation: diagonal reverse, no re-stagger
5. Home → booking flow → result cards: diagonal sweep + stagger on header/counter/card stack
6. Rapid navigation: no jank, no clipping artifacts

- [ ] **Step 4: Commit**

```bash
git add beautycita_app/lib/screens/provider_list_screen.dart beautycita_app/lib/screens/result_cards_screen.dart
git commit -m "Integrate BcStaggeredList into provider list and result cards screens"
```

---

### Task 4: Polish and tune timing

**Files:**
- Modify: `beautycita_app/lib/config/app_transitions.dart`

- [ ] **Step 1: Test and tune on physical device**

Run on the Galaxy S10 (older device, performance baseline):
```bash
flutter run --profile -d 192.168.0.40:5555
```

Check:
- Frame rate stays at 60fps during transition (use `--profile` mode performance overlay)
- 650ms feels right — not too fast, not sluggish
- Band gradient is visible and beautiful, not too subtle
- Stagger timing feels natural — cards don't appear to "wait"

If timing needs adjustment, tune these values in `app_transitions.dart`:
- `bcSweepPage` duration: currently 650ms (try 600-700ms range)
- Sweep interval: `0.0-0.65` (try `0.0-0.60` if sweep feels slow)
- Content fade start: `0.20` (lower = content appears sooner)
- Stagger start: `0.45` (lower = cards start sooner after sweep)
- Stagger offset: `0.05` per item (lower = faster stagger, higher = more dramatic)

- [ ] **Step 2: Tune band opacity and blur**

On device, verify the band is:
- Visible enough to be a clear visual element (not a faint ghost)
- Not so opaque it looks like a solid wall
- Blur is soft (MaskFilter blur radius 6 is the starting point)

Adjust `edgeFade` multiplier and alpha values in `_DiagonalBandPainter.paint()` if needed.

- [ ] **Step 3: Final commit with any tuning**

```bash
git add beautycita_app/lib/config/app_transitions.dart
git commit -m "Tune diagonal sweep timing and band opacity"
```

(Skip this commit if no tuning was needed.)
