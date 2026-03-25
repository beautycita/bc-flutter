# BeautyCita Design System

The single source of truth for visual decisions. Every screen references this.
Code references: `constants.dart`, `palettes.dart`, `theme.dart`, `theme_extension.dart`.

---

## Color Architecture

BeautyCita uses **7 adaptive palettes** selected via the home screen easter egg hero color picker. All UI must use theme tokens, never hardcoded colors.

### Access Pattern
```dart
final cs = Theme.of(context).colorScheme;      // primary, surface, onSurface, etc
final ext = Theme.of(context).extension<BCThemeExtension>()!;  // gradients, card border, shimmer
final palette = ref.watch(paletteProvider);     // full palette object
```

### Color Tokens (never use hex values directly)
| Token | Usage | Rose & Gold Value |
|-------|-------|-------------------|
| `cs.primary` | CTAs, active states, brand accent | #EC4899 |
| `cs.secondary` | Secondary actions, gradient midpoint | #9333EA |
| `cs.surface` | Card backgrounds, input fills | #FFF8F0 |
| `cs.onSurface` | Primary text | #212121 |
| `cs.scaffoldBackgroundColor` | Page background | #FFFFFF |
| `ext.cardBorderColor` | Card/tile borders | #EEEEEE |
| `ext.shimmerColor` | Loading shimmer, brand shimmer | #9333EA |
| `ext.primaryGradient` | Hero banners, active pills, branded elements | pink→purple→blue |
| `ext.accentGradient` | Secondary gradient, hover states | pink→purple |

### Brand Gradient
```dart
ext.primaryGradient  // LinearGradient — adapts per palette
// Rose & Gold: #EC4899 → #9333EA → #3B82F6
// Each palette defines its own gradient
```

**Gradient usage rules:**
- Hero banners: full gradient
- Active pills/chips: full gradient
- Dial ring fills: single color from gradient (primary, secondary, or tertiary)
- Body text: NEVER gradient
- Borders: single color, not gradient

---

## Spacing Scale

Source: `AppConstants` in `constants.dart`

| Token | Value | Usage |
|-------|-------|-------|
| `paddingXS` | 4 | Tight inline spacing |
| `paddingSM` | 8 | Between related elements |
| `paddingMD` | 16 | Standard content padding |
| `paddingLG` | 24 | Section gaps |
| `paddingXL` | 32 | Major section dividers |
| `paddingXXL` | 48 | Hero spacing |
| `screenPaddingHorizontal` | 20 | Page-level left/right margin |
| `screenPaddingVertical` | 16 | Page-level top/bottom margin |

**Spacing rules:**
- Between elements in same group: `paddingSM` (8)
- Between sections: `paddingLG` (24)
- Screen edge to content: `screenPaddingHorizontal` (20)
- Card internal padding: `paddingMD` (16)

---

## Border Radius Scale

| Token | Value | Usage |
|-------|-------|-------|
| `radiusXS` | 8 | Small chips, tags, inline badges |
| `radiusSM` | 12 | Settings tiles, list items |
| `radiusMD` | 16 | Cards, input fields, dialogs |
| `radiusLG` | 24 | Bottom sheets (top corners), hero cards |
| `radiusXL` | 32 | Pill buttons, large CTAs |
| `radiusFull` | 999 | Circles, avatar clips, pill badges |

**Radius rules (palette-scaled):**
```dart
final r = palette.radiusScale;  // multiplier per theme
final actualRadius = AppConstants.radiusMD * r;
```

---

## Typography

Each palette defines its own font pair via `headingFont` and `bodyFont`.

| Text Style | Font | Size | Weight | Usage |
|-----------|------|------|--------|-------|
| `displayLarge` | heading | 32 | bold | Splash, hero numbers |
| `displayMedium` | heading | 28 | bold | Page titles (rare) |
| `displaySmall` | heading | 24 | w600 | Section heroes |
| `headlineMedium` | heading | 20 | w600 | Screen titles |
| `headlineSmall` | heading | 18 | w600 | Card titles |
| `titleMedium` | body | 16 | w600 | Tile labels, subtitles |
| `titleSmall` | body | 14 | w600 | Small labels |
| `bodyLarge` | body | 16 | w400 | Primary body text |
| `bodyMedium` | body | 14 | w400 | Standard body text |
| `bodySmall` | body | 12 | w400 | Captions, hints |
| `labelLarge` | body | 16 | w600 | Button text |
| `labelSmall` | body | 12 | w500 | Small labels, timestamps |

**Font scale:** User-adjustable via preferences (0.85, 1.0, 1.15). Applied via `fontScale` parameter in `buildThemeFromPalette`.

---

## Touch Targets

| Token | Value | Usage |
|-------|-------|-------|
| `minTouchHeight` | 56 | Minimum for any tappable element |
| `comfortableTouchHeight` | 64 | Preferred for primary actions |
| `largeTouchHeight` | 72 | Dials, preference circles |
| `iconTouchTarget` | 48 | Clickable icons (with hit area padding) |

**Thumb zone:** Bottom 60% of screen is the comfort zone. Primary actions go here. Top 40% is stretch zone — passive content only.

---

## Icon System

**Style:** Material Icons, `_outlined` variant (wireframe style).

```dart
// CORRECT
Icons.explore_outlined
Icons.settings_outlined
Icons.chat_bubble_outline_rounded
Icons.notifications_outlined

// WRONG (too heavy for this app)
Icons.explore
Icons.settings
Icons.chat_bubble
```

**Sizes:**
| Token | Value | Usage |
|-------|-------|-------|
| `iconSizeSM` | 20 | Inline icons, list item leading |
| `iconSizeMD` | 24 | Standard icon, app bar |
| `iconSizeLG` | 32 | Feature icons, empty states |
| `iconSizeXL` | 48 | Hero icons, status indicators |
| `iconSizeXXL` | 64 | Splash, large empty states |

**Note:** Icons are placeholders. BC will replace with custom icons when ready. Do not invest time in icon selection beyond the wireframe set.

---

## Component Patterns

### Section Header
```dart
SectionHeader(label: 'SECTION NAME')
// 10px, uppercase, letter-spacing 1.2, primary color, bold
```

### Settings Tile
```dart
SettingsTile(
  icon: Icons.xxx_outlined,
  label: 'Label text',
  trailing: Widget,  // value display or toggle
  onTap: () {},
)
```

### Preference Dial (NEW — approved 2026-03-24)
Circular SVG ring with value in center. Tap opens bottom sheet.
- Size: `largeTouchHeight` (72)
- Ring stroke: 5
- Track: `surface` color at low opacity
- Fill: single color from gradient (primary/secondary/tertiary)
- Label below: `bodySmall`, `w600`

### Gradient Pill / Notification Chip (NEW — approved 2026-03-24)
```dart
Container(
  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  decoration: BoxDecoration(
    gradient: ext.primaryGradient,  // or segment of it
    borderRadius: BorderRadius.circular(radiusXL),  // pill shape
  ),
  child: Row(children: [emoji, Text, stateIcon]),
)
```
Three states: 🔔 (sound) → 🔇 (silent) → ✗ (off). Tap cycles.
- Active with sound: gradient background, white text
- Active silent: gradient background, white text, 🔇 icon
- Off: surface background, hint text, border

### Location Card
```dart
// Current location
Container(radius: radiusMD, surface background, border)
// Leading: gradient icon box (36x36, radiusSM)
// Title: address, bodyMedium w600
// Subtitle: "Tu ubicacion actual", bodySmall

// Temp location (when active)
Container(radius: radiusMD, amber gradient background)
// Same structure, amber tones, ✕ dismiss button
```

### Live Map with Radius (NEW — approved 2026-03-24)
- Container: `radiusLG` (24), 200px height
- Background: stylized map or actual Mapbox
- Center pin: gradient-colored map pin
- Radius circle: semi-transparent primary color, animated resize
- Radius label: bottom-right badge

### Hero Banner
```dart
Container(
  decoration: BoxDecoration(
    gradient: ext.primaryGradient,
    borderRadius: BorderRadius.circular(radiusLG),  // 24
  ),
  padding: EdgeInsets.all(paddingMD + paddingSM),  // 24
)
// Section label: 10px, white 70%, letter-spacing 1
// Title: 17-18px, white, w800
```

---

## Animation

| Token | Duration | Usage |
|-------|----------|-------|
| `shortAnimation` | 200ms | Micro-interactions, toggles |
| `mediumAnimation` | 300ms | State changes, selections |
| `longAnimation` | 500ms | Major transitions |
| `pageTransition` | 350ms | Screen push/pop |
| `bottomSheetAnimation` | 400ms | Sheet open/close |
| `shimmerAnimation` | 1500ms | Loading shimmer cycle |

---

## Elevation

| Token | Value | Usage |
|-------|-------|-------|
| `elevationNone` | 0 | Flat cards with border |
| `elevationLow` | 2 | Standard cards |
| `elevationMedium` | 4 | Buttons, FAB |
| `elevationHigh` | 8 | Bottom sheets, dialogs |
| `elevationXHigh` | 16 | Overlays |

**Shadow pattern:**
```dart
BoxShadow(
  color: Colors.black.withValues(alpha: 0.04),
  blurRadius: 6,
  offset: Offset(0, 2),
)
```

---

## Bottom Sheet Pattern

```dart
showModalBottomSheet(
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(
      top: Radius.circular(AppConstants.radiusLG),  // 24
    ),
  ),
  // Max height: 85% of screen
  // Drag handle: 40w × 4h, radius 2, centered
  // Content padding: fromLTRB(24, 16, 24, 24)
  // Header: buildSheetHeader(context, 'Title')
  // Auto-dismiss: 400ms after slider change
)
```

---

## Screen Layout Template

```dart
Scaffold(
  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
  appBar: AppBar(title: Text('Screen Title')),
  body: ListView(
    padding: EdgeInsets.symmetric(
      horizontal: AppConstants.screenPaddingHorizontal,  // 20
      vertical: AppConstants.paddingMD,  // 16
    ),
    children: [
      // Hero banner (if applicable)
      // Content sections separated by SizedBox(height: paddingLG)  // 24
      // Section headers in primary color, uppercase, small
    ],
  ),
)
```

---

## File Map

| File | Purpose | Edit when... |
|------|---------|-------------|
| `config/constants.dart` | Spacing, sizes, durations | Adding new dimension tokens |
| `config/palettes.dart` | 7 color palettes | Adding/modifying a theme |
| `config/theme.dart` | ThemeData builder | Changing component theme defaults |
| `config/theme_extension.dart` | BCThemeExtension fields | Adding new theme-aware properties |
| `widgets/settings_widgets.dart` | SettingsTile, SectionHeader | Changing shared settings components |
| `docs/DESIGN-SYSTEM.md` | This file | After ANY visual decision |

---

## APPROVED STYLE (locked 2026-03-24)

These rules are NON-NEGOTIABLE. Every screen must follow them exactly.

### Screen Template
- Standard `AppBar` with clean white/scaffold background — NO gradient headers
- `ListView` with `screenPaddingHorizontal` (20) + `paddingMD` (16) padding
- Hero banner as a **rounded card INSIDE the page** (not the page header)
  - `LinearGradient(135deg)` using `ext.primaryGradient`
  - `borderRadius: radiusLG` (24) — all four corners
  - Internal padding: `paddingLG` (24) horizontal + vertical

### Cards
- Background: `cs.surface` (#FFF8F0 in Rose & Gold)
- Border: `1px solid ext.cardBorderColor`
- Border radius: `radiusMD` (16) for content cards, `radiusLG` (24) for hero
- Shadow: `BoxShadow(color: black 3%, blur: 10, offset: 0,3)` — subtle
- Internal padding: `paddingMD` (16)
- Grouped info rows inside one card with `Divider` between rows (1px, `#f5f0eb`)

### Info Row Pattern
```
Row: [IconBox 34x34 radius:10 colored-bg] [gap:10] [Column: label(8px,gray,uppercase) + value(13px,w600)] [trailing]
```

### Icons
- **ONLY** `_outlined` Material icons. No filled, no rounded, no emoji replacements.
- Icon boxes: 34x34, `borderRadius: 10`, colored background at ~8% opacity of the accent color

### Section Headers
- `9px`, `letterSpacing: 1.2`, `fontWeight: 700`, `color: primary (#c4548a)`
- Uppercase
- `margin: 14px top, 6px bottom, 4px left`

### Interactive Elements
- Tappable cards: `GestureDetector` → visual feedback via `InkWell` or opacity change
- No dashed borders anywhere
- Trailing indicators: `Icons.chevron_right_outlined` at `0.3 opacity`
- Toggle switches: standard `Switch` with `activeThumbColor: cs.primary`
- Badges: small rounded containers with colored background (e.g., orange for "Verificar")

### Spacing Between Sections
- Between cards in same section: `paddingSM` (8)
- Between sections: `paddingLG` (24)
- After last section: `paddingXXL` (48)

### Typography in Cards
- Field label: `8px`, gray (#aaa), uppercase, `w600`, `letterSpacing: 0.5`
- Field value: `13px`, `#1a1a1a`, `w600`
- Card title: `12-13px`, `w700`
- Card subtitle: `9px`, gray (#999)

### Colors — Theme-Adaptive
- Never hardcode hex colors. Always use `cs.primary`, `cs.secondary`, `cs.surface`, `cs.onSurface`, `ext.cardBorderColor`, etc.
- Gradient: `ext.primaryGradient` — adapts to palette + avatar style selection
- Accent backgrounds: `cs.primary.withValues(alpha: 0.08)` for pink tint, `cs.secondary.withValues(alpha: 0.08)` for purple tint

### Animations
- Hero/gradient changes: `AnimatedContainer` 800ms `easeInOut`
- State changes: 500ms `easeInOut`
- Micro-interactions: 200-300ms

*Last updated: 2026-03-24. Update this file after every visual decision.*
