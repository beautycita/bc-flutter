# Analyzer Cleanup Plan — 153 Remaining Findings

**Status at session close (2026-04-19, build 60063):** 153 open.
**Snapshot:** `docs/cleanup/analyzer-snapshot-2026-04-19.txt` (full `flutter analyze` output — don't re-enumerate here, it'll rot).

This plan drives the **next** session. Structured by mechanic, not by rule: one rule can show up across many files, and one file can hit many rules. Working by mechanic knocks out the most findings per unit of effort.

---

## Pre-flight (5 min)

```bash
cd /home/bc/futureBeauty/beautycita_app
git checkout -b cleanup/analyzer-sweep
flutter analyze 2>&1 | tail -3   # confirm still 153
```

Commit the snapshot baseline so you can diff against it at the end:
```bash
git add docs/cleanup/
git commit -m "Baseline analyzer snapshot — 153 open before sweep"
```

---

## Phase 1 — `dart fix --apply` auto-sweep

**Target:** 60–90 findings auto-resolved.

Rules this eliminates cleanly:
| Rule | Count | Mechanical? |
|------|------:|-------------|
| `unused_import` | 23 | Yes |
| `unnecessary_underscores` | 23 | Yes |
| `unnecessary_const` | 5 | Yes |
| `curly_braces_in_flow_control_structures` | 2 | Yes |
| `unnecessary_cast` | 1 | Yes |
| `use_null_aware_elements` | 28 | Mostly |
| `no_leading_underscores_for_local_identifiers` | 2 | Yes |

```bash
# Dry run first to see what it'll do
dart fix --dry-run

# Apply
dart fix --apply

flutter analyze 2>&1 | tail -3
```

**Expected drop:** 60–84 findings. If the drop is <50, something's off — stop and inspect.

**Commit:**
```bash
git add -A
git commit -m "Analyzer sweep — dart fix --apply (~70 findings auto-resolved)"
```

**Test-file inclusion decision:** included. The 22 test-file `unused_import` hits are trivial + untouched by app runtime; `dart fix` handles them in the same pass. If we skip them they'll keep showing up in every future analyzer run, which is the exact noise we're trying to eliminate.

---

## Phase 2 — `share_plus` API migration (Share → SharePlus)

**Target:** 26 findings.

26 of the 41 `deprecated_member_use` hits are the same migration:
- `Share.share(text)` → `SharePlus.instance.share(ShareParams(text: text))`
- `Share.shareXFiles([...])` → `SharePlus.instance.share(ShareParams(files: [...]))`

```bash
# Locate all hits
grep -rn "Share\.share\|shareXFiles" lib/ --include="*.dart"
```

For each file (roughly 7–9 files based on the snapshot):
1. Replace `Share.` with `SharePlus.instance.` where it's a method call
2. Wrap the args in `ShareParams(text: ..., subject: ..., files: [...])`
3. Import `share_plus` (still the same package; API just moved)

Pattern reference:
```dart
// OLD
await Share.share('Hello', subject: 'Subj');
await Share.shareXFiles([XFile(path)]);

// NEW
await SharePlus.instance.share(ShareParams(text: 'Hello', subject: 'Subj'));
await SharePlus.instance.share(ShareParams(files: [XFile(path)]));
```

**After:**
```bash
flutter analyze 2>&1 | tail -3
```

**Expected drop:** 26 findings.

**Commit:**
```bash
git commit -am "Migrate Share → SharePlus.instance (share_plus 12+ API)"
```

---

## Phase 3 — Widget-API deprecations (~15 residual)

The other ~15 `deprecated_member_use` are scattered widget-API migrations. They are mechanical but each needs a tiny tweak:

| Old | New | Typical file |
|-----|-----|--------------|
| `activeColor: X` (on Radio/Switch/Slider) | `fillColor: WidgetStatePropertyAll(X)` or equivalent | 4 hits |
| `value: X, groupValue: Y, onChanged: Z` on Radio | `Radio(value: X, ...)` inside `RadioGroup<T>` | 5+1+1 hits |
| `Matrix4.translate` / `.scale` | `.translateByVector3`/`.scaleByVector3` (or vector_math equivalents) | 2 hits |
| `foregroundColor` on ElevatedButton | `ElevatedButton.styleFrom(foregroundColor: ...)` — check if still the preferred form in current Flutter | 1 hit |
| `copyWith` signature changes | Look at specific one on next session | 1 hit |

Work file-by-file, re-run `flutter analyze` after each file. If any deprecation resists a one-line fix (migration guide is non-trivial), park it in a `docs/cleanup/parked-deprecations.md` and move on — don't let one API change block the sweep.

**Commit per file** so each is atomic and revert-friendly.

**Expected drop:** 15 findings.

---

## Phase 4 — Dead code (real cleanup, light thinking)

14 findings across `unused_element` (8), `unused_local_variable` (3), `unused_field` (3), `unused_element_parameter` (3). Each represents code that was written, shipped, and forgotten.

**Decision per finding:** delete or wire up. Default to delete. Exceptions are dead code that names a real feature (e.g. `_buildAvatarStylesSection`, `_showCfdiDetail`) — those might be unfinished features worth surfacing before killing. Flag those to BC rather than silently deleting:

```
lib/screens/profile_screen.dart:426   _buildAvatarStylesSection (avatar styles UI — unfinished feature?)
lib/screens/business/business_dashboard_screen.dart:1577   _showCfdiDetail (CFDI detail drawer — SAT-related)
lib/screens/home_screen.dart:45       _saldoProvider (saldo provider — replaced by feature toggle?)
lib/screens/splash_screen.dart:69     _initVideo + _buildVideoSplash (old splash? replaced?)
lib/screens/booking_confirmation_screen.dart:642   _solidButton (helper likely replaced by theme)
```

Strategy:
1. Grep for each `_name` across the full codebase — confirm truly dead.
2. If zero external refs: delete.
3. If the name hints at a real feature (e.g. CFDI): pause, ask BC if it was intentional.

**Expected drop:** 14 findings.

---

## Phase 5 — Naming + docs residue (~10)

Whatever's left:
- 6 `non_constant_identifier_names` — rename the offenders (usually `SCREAMING_SNAKE` constants that should be `camelCase`)
- 2 `unintended_html_in_doc_comment` — escape `<...>` in docstrings or use backticks
- 2 `dead_code` in `test/services/updater_service_test.dart:175–176` — delete the unreachable branch
- 1 `dangling_library_doc_comments` — add a `library` directive or attach the comment to a declaration

Quick pass. 15 minutes.

---

## Exit criteria

```bash
flutter analyze 2>&1 | tail -3
# expect: 0–5 issues found
```

Acceptable to land with a handful of `// ignore:`-annotated sites where an analyzer rule and our architecture genuinely conflict (e.g., intentional `unused_element` for future hooks). Each `ignore` gets a one-line comment explaining why.

**Final commit on branch:**
```bash
git commit -am "Analyzer sweep complete — X issues remaining, all documented"
```

**Before merging to main:** rebuild APK + rerun test suite:
```bash
flutter build apk --release --target-platform android-arm64
flutter test
```

If both clean → merge, deploy with `--distribute` flag (no `--required`; it's pure hygiene).

---

## Out of scope (leave for later)

- **ProGuard / R8 warnings** — not in `flutter analyze` output
- **Test quality improvements** — separate project; this sweep only touches test files for `unused_import` cleanup via `dart fix`
- **`use_null_aware_elements` edge cases** — if `dart fix` doesn't auto-resolve some, leave them for a style-only pass. Zero functional impact.

---

## Why this order

1. `dart fix` first = biggest reduction for zero thought. Shrinks the problem set so the remaining items are easier to read.
2. Share→SharePlus next = single-pattern migration touches 20%+ of remaining, mechanical.
3. Widget deprecations after = requires reading docs, slower per fix.
4. Dead code after that = requires decisions (delete vs preserve).
5. Naming/docs last = trivial, finishing polish.

Working in any other order means either burying mechanical wins behind thinking-heavy work, or making decisions about dead code before you've confirmed it's actually dead (it might reference things `dart fix` is about to remove).

---

## Checklist for the next session

- [ ] Branch created, snapshot baseline committed
- [ ] Phase 1: `dart fix --apply` — expect ~70 findings gone
- [ ] Phase 2: Share→SharePlus migration — expect 26 findings gone
- [ ] Phase 3: Widget-API deprecations — expect 15 findings gone
- [ ] Phase 4: Dead code (with BC check on anything feature-named) — expect 14 findings gone
- [ ] Phase 5: Naming + docs — expect ~10 findings gone
- [ ] `flutter analyze` shows ≤5 remaining (all intentional + commented `// ignore:`)
- [ ] APK builds clean
- [ ] Tests pass
- [ ] Deployed with `--distribute` (no force update)
- [ ] New `analyzer-snapshot-YYYY-MM-DD.txt` checked in as the new floor
