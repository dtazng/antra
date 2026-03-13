# Research: UI Polish — Composer, Task Cards & Tab Bar

**Branch**: `009-ui-polish` | **Date**: 2026-03-13

---

## Decision 1: Task completion — use existing `completedAt` + `status` columns

**Decision**: Reuse `bullets.completedAt` (nullable ISO 8601 timestamp) and `bullets.status` (text, values: 'open' | 'complete' | 'cancelled' | 'migrated') which already exist in the schema (added in v2 migration). No new columns or migration required.

**Rationale**: The bullets table already has both fields specifically designed for task lifecycle tracking. The `updateBulletStatus` DAO method already sets `status`; we add a thin `completeTask` / `uncompleteTask` helper that also stamps/clears `completedAt` in the same transaction to keep both fields consistent.

**Alternatives considered**:
- Add a new `isCompleted` boolean column — rejected; `completedAt` provides richer data (when it was done) and `status` is already the semantic store.
- Use only `status = 'complete'` without touching `completedAt` — rejected; `completedAt` is part of the established schema contract and should remain consistent with `status`.

---

## Decision 2: Tab bar redesign — direct AntraColors, no Material color scheme

**Decision**: Replace `cs.primaryContainer` active state and `cs.surfaceContainerHigh` background with `AntraColors` constants directly. Active indicator: a faint `AntraColors.auroraIndigo` or `Colors.white.withValues(alpha: 0.10)` tinted container (not a bright pill). Tab bar background: `AntraColors.auroraNavy` with same glass border treatment used by `GlassStyle.bar`.

**Rationale**: The current tab bar uses `Theme.of(context).colorScheme.primaryContainer` which resolves to Material 3 defaults — in practice a colored pill that clashes with the aurora dark palette. The rest of the app (GlassSurface, BulletCaptureBar, etc.) directly references `AntraColors` constants to stay independent of the M3 color scheme. The tab bar should follow the same pattern.

**Alternatives considered**:
- Override Material theme's `NavigationBarTheme` — rejected; the tab bar is a custom widget (`_FloatingTabBar`), not a `NavigationBar`, so theme overrides don't apply cleanly.
- Keep the floating pill shape but recolor it — rejected; the pill shape itself may look too playful for the dark aurora aesthetic; a flat container with a subtle icon highlight is more editorial.

---

## Decision 3: Rounded TextField appearance — remove InputDecoration borders, use transparent fill

**Decision**: Give the `TextField` in `BulletCaptureBar` a subtle transparent glass-tinted `fillColor` and `filled: true`, with `OutlineInputBorder(borderRadius: BorderRadius.circular(AntraRadius.card), borderSide: BorderSide.none)` for all border states. This makes the text field appear as a seamlessly rounded pocket within the card rather than a flat rectangle with invisible borders.

**Rationale**: The current approach uses `border: InputBorder.none` which removes visible borders but leaves the default `InputDecoration` layout structure, making the field feel like an invisible rectangle. Adding a subtle `fillColor` (e.g., `Colors.white.withValues(alpha: 0.05)`) and an `OutlineInputBorder` with the card's corner radius makes the boundary visible and rounded without adding visual weight.

**Alternatives considered**:
- Wrap the TextField in a Container with decoration — rejected; layering a Container inside GlassSurface adds complexity and may cause double-background artifacts.
- Use `UnderlineInputBorder` — rejected; underlines contradict the card-integrated visual goal.

---

## Decision 4: Dynamic card height — remove `overflow: TextOverflow.ellipsis` and `maxLines`

**Decision**: Remove `overflow: TextOverflow.ellipsis` from the content `Text` widget in `TodayInteractionTimeline`. Set no `maxLines` limit. Change the entry Row's `crossAxisAlignment` to `CrossAxisAlignment.start` so leading icons/actions pin to the top of tall cards rather than centering vertically.

**Rationale**: The current timeline constrains text with `overflow: TextOverflow.ellipsis` which truncates content. Since cards are in a `ListView` (via `AnimatedList` + `shrinkWrap: true`), removing the constraint allows natural height expansion. No additional layout changes are required — Flutter's list items already support variable heights.

**Alternatives considered**:
- Add an "expand" tap interaction — rejected; the spec explicitly says default behavior should favor showing content, not requiring extra taps.
- Cap at e.g. 4 lines with a "show more" affordance — rejected; the spec says "avoid fixed-height cards" and "default behavior should favor showing the actual content". No cap needed for typical journal entries.

---

## Decision 5: Remove sublabel from composer type switch — single `Text` widget

**Decision**: Remove the second `Text` widget in the type toggle column of `BulletCaptureBar` (the one showing 'Context' / 'Follow-up'). The single label 'Note' / 'Task' remains. The `Column` wrapping them simplifies to a single child or can be replaced with a plain `Text`.

**Rationale**: The sublabel was added in 008 to clarify mode meaning. In practice, 'Note' and 'Task' are self-explanatory journal terms. The sublabel adds visual weight and makes the toggle feel like a form control rather than a calm journal affordance.

**Alternatives considered**:
- Replace sublabel with a tooltip — rejected; tooltips are not discoverable and add interaction overhead.
- Keep sublabel but reduce its opacity further — rejected; the spec explicitly requires its removal.

---

## Decision 6: No new packages

**Decision**: All changes use only Flutter core widgets and the existing `AntraColors`/`AntraRadius`/`AntraMotion` tokens already in `app/lib/theme/app_theme.dart`. No pubspec changes.

**Rationale**: The aurora design system already provides all necessary tokens. All five user stories are styling and behavioral changes to existing widgets.
