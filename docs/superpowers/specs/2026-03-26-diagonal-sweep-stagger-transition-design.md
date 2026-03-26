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

**Implementation:**
- `CustomClipper<Path>` draws a diagonal line perpendicular to the sweep direction (roughly 30-35 degrees from vertical)
- The clip region grows as the animation progresses, revealing the new page underneath
- The gradient band is a `CustomPaint` overlay positioned along the clip edge
- Old page content is not explicitly managed — Flutter's `transitionsBuilder` receives only the new page as `child`. The old page naturally sits behind in the route stack. The clip on the new page creates the reveal effect.

**Timing (650ms forward, 450ms reverse):**
- `0.00-0.65`: Diagonal band sweeps across screen. Curve: `easeInOutCubic`
- `0.20-0.85`: New page content fades in (opacity 0-1) with subtle upward slide (20px-0). Starts before sweep finishes for fluid feel.
- Reverse (pop): same diagonal in reverse direction, 450ms

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
- Each child gets a staggered `Interval`: child 0 starts at 0.45, child 1 at 0.50, child 2 at 0.55, etc. (5% offset per item)
- Cap at 8 stagger slots — items beyond index 7 share the last interval (appear together)
- Per-child animation: fade in (0-1) + slide up (30px-0) with `easeOutCubic`
- If route animation is already complete (value == 1.0, e.g. returning to cached page), all children render immediately — no stagger on back-navigation
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
- `shouldReclip` / `shouldRepaint` guard against unnecessary repaints
- 650ms total duration keeps transitions perceptible but not sluggish

## Acceptance Criteria

1. Diagonal gradient band visibly sweeps top-left to bottom-right, masking old page and revealing new
2. Band is thick (~120px) with soft feathered edges, no hard clip lines or screen tears
3. New page content fades + slides up smoothly behind the sweep
4. On screens using `BcStaggeredList`, cards animate in sequentially after sweep passes
5. Reverse transition (pop/back) plays the sweep in reverse
6. No stagger animation when returning to a cached/already-built page
7. Transition feels fluid at 650ms — visible but not annoying
