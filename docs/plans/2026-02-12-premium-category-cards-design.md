# Premium Category Cards Design

**Date:** 2026-02-12
**Branch:** `feature/category-flip-cards`
**Status:** Approved

## Problem

The current category selection cards on the home screen are flat white boxes with emojis. They are functional but uninspiring. For a beauty/luxury app, the first thing users interact with needs to convey premium quality and build confidence.

## Decision

Build 3 visual styles for the category cards, all switchable on-device via a toggle FAB. Compare on the phone, pick a winner, remove the toggle.

All 3 styles share:
- 13-stop real gold gradient border (3px) — same as booking flow
- Press animation (scale 0.95 + style-specific feedback)
- Material Icons as placeholders (swap for custom illustrations later)
- Category name in Poppins 600

## Style A: "Luxury Cushion"

- **Surface**: Radial gradient — bright highlight center fading to slightly darker edges, creating a convex/pillow illusion
- **Faint inner shadow**: Top-left light, bottom-right darker to enhance 3D curvature
- **Icon**: 44px, centered, with soft drop shadow (offset 0,4 blur 8) for floating depth
- **Name**: Below icon, subtle text shadow (0,2 blur 4) for floating effect
- **Press**: Shadow reduces + radial highlight flattens (center brightness decreases) = "deflation"

## Style B: "Glass Morphism"

- **Surface**: `BackdropFilter` with blur (sigma 12) + semi-transparent white overlay (0.15 alpha)
- **Glass edge**: Faint white inner border (1px, 0.2 alpha)
- **Icon**: Soft category-color glow behind it (0.3 alpha, blurred)
- **Name**: Crisp on top of glass
- **Background requirement**: Subtle gradient or pattern behind the grid for blur to be visible
- **Press**: Glass gets slightly more opaque

## Style C: "Elevated Tiles"

- **Surface**: Clean white
- **Shadows**: 3-layer box shadow stack (soft large spread, medium mid-range, tight contact)
- **Accent**: 4px vertical category-color bar on left edge inside card
- **Layout**: Icon + name left-aligned next to accent bar
- **Press**: Shadows collapse to single tight shadow = "pressing into surface"

## Icon Mapping (Placeholder)

| Category | Icon |
|----------|------|
| Unas | `auto_awesome` |
| Cabello | `content_cut` |
| Pestanas y Cejas | `visibility` |
| Maquillaje | `brush` |
| Facial | `spa` |
| Cuerpo y Spa | `self_improvement` |
| Cuidado Especializado | `healing` |
| Barberia | `face_retouching_natural` |

## Toggle Mechanism

- `FloatingActionButton` in bottom-right of home screen
- Cycles A -> B -> C on tap
- State in `StateProvider<int>`
- Removed before shipping

## Future Work (Not This Branch)

- Custom SVG/PNG illustrations replacing Material Icons
- Scatter transition when subcategory is selected (cards fly apart to reveal loading)
- Color scheme experiments: black+gold, black+blue-purple-pink+gold
