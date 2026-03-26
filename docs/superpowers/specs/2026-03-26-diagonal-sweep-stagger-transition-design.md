# Diagonal Gradient Sweep + Staggered Card Transition

**Date:** 2026-03-26
**Status:** Approved
**File:** `beautycita_app/lib/config/app_transitions.dart`

## Problem

The current `bcSweepStaggerTransition` has three defects vs. the intended design:
1. The gradient band is vertical (left-to-right), not diagonal
2. The band is decorative overlay only — it doesn't wipe/mask the old page away
3. No card stagger — the entire new page appears as one unit

## Design

### Transition 1: Diagonal Gradient Sweep (all page navigation)

A thick (~120px) diagonal gradient band sweeps **top-left to bottom-right**. It acts as a mask boundary: behind the band the new page is revealed, ahead of the band the old page remains visible. The band carries the brand gradient (pink/purple/blue) with soft feathered edges — no hard clip lines.

**Implementation — Clip Geometry:**

The sweep axis runs from top-left corner to bottom-right corner. The clip boundary is a line perpendicular to this axis. The angle is derived from the screen aspect ratio: `atan(screenWidth / screenHeight)` — so the diagonal always connects opposite corners regardless of device dimensions.

At animation value `t`, the clip path is a polygon covering everything to the upper-left of the diagonal boundary line:
- `t = 0.0`: polygon covers nothing (line is off-screen to the top-left)
- `t = 0.5`: line crosses screen center diagonally
- `t = 1.0`: polygon covers entire screen (line is off-screen to the bottom-right)

The total sweep distance is `sqrt(screenWidth^2 + screenHeight^2)` (the screen diagonal). The boundary line position at time `t` is `offset = t * totalSweepDistance` along the sweep axis, measured from the top-left corner.

Polygon vertices at any `t`: start from the intersection of the diagonal boundary line with the screen edges, then include all screen corners that fall on the "revealed" (upper-left) side.

**Implementation — Gradient Band:**

The gradient band is drawn by a `CustomPaint` overlay using `canvas.save()` → `canvas.translate()` to the boundary line center → `canvas.rotate()` to match the diagonal angle → draw a `Rect(-bandWidth/2, -screenDiag, bandWidth/2, screenDiag)` filled with a `LinearGradient` shader in local (rotated) coordinates → `canvas.restore()`. This ensures the band always straddles the clip edge at the correct angle.

**Implementation — Page Layering:**
- Old page content is not explicitly managed — Flutter's `transitionsBuilder` receives only the new page as `child`. The old page naturally sits behind in the route stack. The clip on the new page creates the reveal effect.

**Implementation — Brand Colors:**
- The gradient band reads brand colors from `Theme.of(context)` via the `BuildContext` parameter available in `transitionsBuilder`, not hardcoded hex values.

**Timing (650ms forward, 450ms reverse):**
- `0.00-0.65`: Diagonal band sweeps across screen. Curve: `easeInOutCubic`
- `0.20-0.85`: New page content fades in (opacity 0-1) with subtle upward slide (20px-0). Starts before sweep finishes for fluid feel.
- Reverse (pop): same diagonal in reverse direction, 450ms. `BcStaggeredList` does nothing on reverse — the diagonal sweep masks children as it recedes, which is sufficient.

**Note on duration:** The design system token `pageTransition: 350ms` is for standard fade/slide transitions. This diagonal sweep covers more visual distance (the full screen diagonal) and needs more time to read. 650ms is intentional and within the Flutter transitions guide's 600-1200ms range for complex entrance animations.

**Band visual:**
- Width: ~120 logical pixels
- Gradient stops: transparent -> pink 15% -> pink 50% -> purple 80% -> blue 50% -> blue 15% -> transparent
- `MaskFilter.blur(BlurStyle.normal, 6)` for soft glow on edges

### Transition 2: Radial Burst (unchanged)

Dialogs and bottom sheets keep the existing radial burst implementation. No changes.

### BcStaggeredList Widget (new)

Drop-in replacement for `ListView`/`Column` that staggers children after the page sweep.

**Behavior:**
- Reads the enclosing `ModalRoute.of(context)` animation
- **Null safety:** If `ModalRoute.of(context)` returns null (dialog, nested navigator, test harness) or the animation is already complete (`value == 1.0`), all children render immediately without stagger
- Each child gets a staggered `Interval`: child 0 starts at 0.45, child 1 at 0.50, child 2 at 0.55, etc. (5% offset per item)
- Each child's interval spans from `startOffset` to `min(startOffset + 0.20, 1.0)`. For child 7 (last stagger slot): 0.80 to 1.0.
- Cap at 8 stagger slots — items beyond index 7 share the last interval (appear together)
- Per-child animation: fade in (0-1) + slide up (30px-0) with `easeOutCubic`
- **Reverse (pop):** No stagger-out. The diagonal sweep handles visual exit by masking children as the clip recedes.
- Supports `ScrollPhysics`, `padding`, `shrinkWrap` — same API surface as `ListView`

**Usage:**
```dart
// Before
ListView(children: [card1, card2, card3])

// After
BcStaggeredList(children: [card1, card2, card3])
```

**Initial screens to update:**
1. `home_screen.dart` — category grid
2. `result_cards_screen.dart` — top 3 curated result cards
3. `provider_list_screen.dart` — search results list

Other screens can adopt `BcStaggeredList` incrementally.

## Files Modified

| File | Change |
|------|--------|
| `beautycita_app/lib/config/app_transitions.dart` | Rewrite `bcSweepStaggerTransition` with diagonal clip + band. Add `BcStaggeredList` widget. Keep `bcSweepPage`/`bcBurstPage`/`bcSlashPage` API unchanged. |
| `beautycita_app/lib/screens/home_screen.dart` | Replace `ListView`/`Column` with `BcStaggeredList` for category cards |
| `beautycita_app/lib/screens/result_cards_screen.dart` | Replace list with `BcStaggeredList` for result cards |
| `beautycita_app/lib/screens/provider_list_screen.dart` | Replace list with `BcStaggeredList` for provider cards |

## What Does NOT Change

- `bcSweepPage`, `bcBurstPage`, `bcSlashPage` function signatures
- All GoRouter route definitions in `routes.dart`
- `showBurstDialog` / `showBurstBottomSheet`
- Radial burst transition
- Web app transitions (`web_transitions.dart`)

## Performance

- Single `CustomClipper` + single `CustomPaint` per frame — minimal GPU cost
- Stagger animations use the existing route animation controller — no extra `AnimationController` allocations
- `shouldReclip` returns true only when the animation value changes (every frame during animation, but not on unrelated rebuilds). Same for `shouldRepaint`.
- 650ms total duration keeps transitions perceptible but not sluggish

## Acceptance Criteria

1. Diagonal gradient band visibly sweeps top-left to bottom-right, masking old page and revealing new
2. Band is thick (~120px) with soft feathered edges, no hard clip lines or screen tears
3. New page content fades + slides up smoothly behind the sweep
4. On screens using `BcStaggeredList`, cards animate in sequentially after sweep passes
5. Reverse transition (pop/back) plays the sweep in reverse
6. No stagger animation when returning to a cached/already-built page
7. Transition feels fluid at 650ms — visible but not annoying
