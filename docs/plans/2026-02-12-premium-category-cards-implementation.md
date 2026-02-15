# Premium Category Cards Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace flat white category cards with 3 switchable premium visual styles (Luxury Cushion, Glass Morphism, Elevated Tiles) with on-device toggle for comparison.

**Architecture:** Add a `cardStyleProvider` to switch between 3 card renderers. All 3 share gold gradient border, press animation, and Material Icon placeholders. The card widget delegates to a style-specific builder. A dev FAB cycles through styles.

**Tech Stack:** Flutter, Riverpod StateProvider, existing BeautyCitaTheme, existing `_goldGradient` pattern from booking flow.

---

### Task 1: Add Material Icon mapping to categories

**Files:**
- Modify: `lib/models/category.dart` (add `materialIcon` field)
- Modify: `lib/data/categories.dart` (add icon to each category)

**Step 1: Add `materialIcon` field to ServiceCategory**

In `lib/models/category.dart`, add field:

```dart
class ServiceCategory {
  final String id;
  final String nameEs;
  final String icon;       // emoji (keep for backwards compat)
  final IconData materialIcon; // Material icon for premium cards
  final Color color;
  final List<ServiceSubcategory> subcategories;

  const ServiceCategory({
    required this.id,
    required this.nameEs,
    required this.icon,
    required this.materialIcon,
    required this.color,
    required this.subcategories,
  });
}
```

**Step 2: Add materialIcon to each category in `lib/data/categories.dart`**

Add `import 'package:flutter/material.dart';` (already present) and add `materialIcon` to each:

| Category ID | materialIcon |
|------------|-------------|
| nails | `Icons.auto_awesome` |
| hair | `Icons.content_cut` |
| lashes_brows | `Icons.visibility` |
| makeup | `Icons.brush` |
| facial | `Icons.spa` |
| body_spa | `Icons.self_improvement` |
| specialized | `Icons.healing` |
| barberia | `Icons.face_retouching_natural` |

**Step 3: Build to verify no errors**

Run: `flutter build apk --debug 2>&1 | tail -5`
Expected: `Built build/app/outputs/flutter-apk/app-debug.apk`

**Step 4: Commit**

```bash
git add lib/models/category.dart lib/data/categories.dart
git commit -m "feat: add materialIcon field to ServiceCategory"
```

---

### Task 2: Add card style provider and gold gradient constant

**Files:**
- Create: `lib/providers/card_style_provider.dart`

**Step 1: Create the provider**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum CardStyle { luxuryCushion, glassMorphism, elevatedTiles }

final cardStyleProvider = StateProvider<CardStyle>((ref) => CardStyle.luxuryCushion);
```

**Step 2: Commit**

```bash
git add lib/providers/card_style_provider.dart
git commit -m "feat: add cardStyleProvider for switchable card styles"
```

---

### Task 3: Build Style A — Luxury Cushion card

**Files:**
- Modify: `lib/screens/home_screen.dart` (replace `_CategoryCard` build method)

**Step 1: Add gold gradient constant at top of home_screen.dart**

Same 13-stop `_goldGradient` used in transport_selection.dart and result_cards_screen.dart.

**Step 2: Rewrite `_CategoryCardState.build()` to dispatch by style**

The widget watches `cardStyleProvider` and calls the appropriate builder. For Style A (Luxury Cushion):

**Outer container**: gold gradient + borderRadius 20 + gold shadow
**Inner container**: margin 3 (the 3px gold border), borderRadius 17, decorated with:
- Radial gradient from center: white (0.95 alpha) at center, surfaceCream at edges — creates the pillow/convex look
- Faint inner-shadow effect using a second BoxDecoration layered via Stack or using a DecoratedBox with gradient overlay:
  - Top-left: subtle white highlight (convex light source)
  - Bottom-right: subtle darker edge (0.05 alpha black)

**Icon**: Material icon (from `category.materialIcon`), 44px, category color, with a drop shadow:
```dart
Icon(
  category.materialIcon,
  size: 44,
  color: category.color,
  shadows: [
    Shadow(
      color: category.color.withValues(alpha: 0.3),
      blurRadius: 8,
      offset: Offset(0, 4),
    ),
  ],
)
```

**Name**: Poppins 14 w600, category color (0.85 alpha), with subtle text shadow:
```dart
shadows: [
  Shadow(
    color: Colors.black.withValues(alpha: 0.08),
    blurRadius: 4,
    offset: Offset(0, 2),
  ),
],
```

**Press behavior**: When `_isPressed`:
- Radial gradient center brightness reduces (white 0.85 instead of 0.95)
- Shadow blur/offset decreases
- Gives the "deflation" tactile feel

**Step 3: Build and verify**

Run: `flutter build apk --debug 2>&1 | tail -5`

**Step 4: Commit**

```bash
git add lib/screens/home_screen.dart
git commit -m "feat: implement Style A (Luxury Cushion) category cards"
```

---

### Task 4: Build Style B — Glass Morphism card

**Files:**
- Modify: `lib/screens/home_screen.dart` (add `_buildGlassMorphism` method)

**Step 1: Add background pattern to grid area**

The glass blur needs something behind it to look good. Add a subtle radial gradient or pattern behind the GridView in the `Expanded` widget. A simple approach: wrap the grid `Padding` in a `DecoratedBox` with a faint radial gradient using primaryRose at very low alpha.

**Step 2: Build the glass card**

**Outer container**: gold gradient + borderRadius 20 + gold shadow (same as A)
**Inner container**: margin 3, borderRadius 17, uses `ClipRRect` + `BackdropFilter`:

```dart
ClipRRect(
  borderRadius: BorderRadius.circular(17),
  child: BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: // icon + name
    ),
  ),
)
```

**Icon**: Material icon 44px with a soft glow behind it:
```dart
Container(
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    boxShadow: [
      BoxShadow(
        color: category.color.withValues(alpha: 0.3),
        blurRadius: 20,
        spreadRadius: 5,
      ),
    ],
  ),
  child: Icon(category.materialIcon, size: 44, color: category.color),
)
```

**Name**: Poppins 14 w600, `BeautyCitaTheme.textDark`

**Press**: Glass overlay opacity goes from 0.15 to 0.25

**Step 3: Build and verify**

**Step 4: Commit**

```bash
git add lib/screens/home_screen.dart
git commit -m "feat: implement Style B (Glass Morphism) category cards"
```

---

### Task 5: Build Style C — Elevated Tiles card

**Files:**
- Modify: `lib/screens/home_screen.dart` (add `_buildElevatedTiles` method)

**Step 1: Build the tile card**

**Outer container**: gold gradient + borderRadius 20 + 3-layer shadow stack:
```dart
boxShadow: [
  // Deep ambient
  BoxShadow(
    color: Colors.black.withValues(alpha: 0.08),
    blurRadius: 24,
    offset: Offset(0, 12),
    spreadRadius: -4,
  ),
  // Mid range
  BoxShadow(
    color: Colors.black.withValues(alpha: 0.06),
    blurRadius: 12,
    offset: Offset(0, 6),
  ),
  // Contact shadow
  BoxShadow(
    color: Colors.black.withValues(alpha: 0.04),
    blurRadius: 4,
    offset: Offset(0, 2),
  ),
],
```

**Inner container**: margin 3, borderRadius 17, white, with a `Row` layout:

```dart
Row(
  children: [
    // 4px color accent bar
    Container(
      width: 4,
      height: double.infinity,
      margin: EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: category.color,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
    SizedBox(width: 12),
    // Icon + name column
    Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(category.materialIcon, size: 36, color: category.color),
          SizedBox(height: 8),
          Text(category.nameEs, ...),
        ],
      ),
    ),
  ],
)
```

**Press**: All 3 shadows collapse to single tight shadow:
```dart
BoxShadow(
  color: Colors.black.withValues(alpha: 0.1),
  blurRadius: 4,
  offset: Offset(0, 2),
),
```

**Step 2: Build and verify**

**Step 3: Commit**

```bash
git add lib/screens/home_screen.dart
git commit -m "feat: implement Style C (Elevated Tiles) category cards"
```

---

### Task 6: Add toggle FAB and wire up provider

**Files:**
- Modify: `lib/screens/home_screen.dart` (convert to ConsumerWidget if not already, add FAB)

**Step 1: Make HomeScreen watch cardStyleProvider**

HomeScreen is already a `ConsumerWidget`. Add import for `card_style_provider.dart`. Pass the current style to `_CategoryCard`.

**Step 2: Add a FAB to the Scaffold**

```dart
floatingActionButton: FloatingActionButton(
  mini: true,
  onPressed: () {
    final current = ref.read(cardStyleProvider);
    final next = CardStyle.values[(current.index + 1) % CardStyle.values.length];
    ref.read(cardStyleProvider.notifier).state = next;
  },
  child: Icon(Icons.palette_outlined),
),
```

**Step 3: Show current style name as a snackbar on toggle**

After changing state, show: `ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next.name)))`.

**Step 4: Build release APK, install on phone**

Run:
```bash
flutter build apk --release --no-tree-shake-icons 2>&1 | tail -5
adb -s 192.168.0.25:5555 install -r build/app/outputs/flutter-apk/app-release.apk
```

**Step 5: Commit and push**

```bash
git add lib/screens/home_screen.dart lib/providers/card_style_provider.dart
git commit -m "feat: add style toggle FAB for comparing category card designs"
git push -u origin feature/category-flip-cards
```

---

## Dependency Chain

Task 1 (model) -> Task 2 (provider) -> Task 3 (Style A) -> Task 4 (Style B) -> Task 5 (Style C) -> Task 6 (toggle + deploy)

Tasks 3, 4, 5 could be done in parallel but they all modify the same file, so sequential is safer.

## Future Work (Not This Plan)

- Custom SVG/PNG illustrations replacing Material Icons
- Scatter transition on subcategory selection
- Color scheme experiments (black+gold, black+purple-pink+gold)
- Remove toggle FAB before shipping
