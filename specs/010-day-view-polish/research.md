# Research: Day View Polish — Clarity, Hierarchy & Visual Cohesion

**Branch**: `010-day-view-polish` | **Date**: 2026-03-13

---

## Decision 1: Empty-State Condition Fix

**Decision**: The empty-state message ("Nothing to do — you're all caught up") must be shown only when `suggestionsAsync` has zero visible suggestions AND `interactionsAsync` has zero entries. Currently it is triggered solely by empty suggestions, independent of the timeline.

**Rationale**: In `day_view_screen.dart` line 144–149, `_EmptyState` is rendered inside `suggestionsAsync.when(data: (suggestions) { if (visible.isEmpty) return _EmptyState(...) })`. This fires regardless of whether `interactionsAsync` has entries. The fix requires cross-referencing both async values before deciding to show the empty state.

**Implementation approach**: Move the empty-state rendering to a position where both `suggestionsAsync` and `interactionsAsync` are in scope. Pattern: inside `interactionsAsync.when(data:)`, check `visible.isEmpty && interactions.isEmpty` before rendering `_EmptyState`. The suggestions section renders its cards above; the empty state replaces both sections only when both are empty.

**Alternatives considered**:
- Restructure `build()` to use `suggestionsAsync.value` and `interactionsAsync.value` synchronously — rejected because it loses the declarative `AsyncValue.when` pattern and adds null checks throughout.
- Show no empty state at all — rejected; FR-001 explicitly requires the empty state for the all-empty case.

---

## Decision 2: Timestamp Repositioning — Trailing Right-Aligned

**Decision**: Move the timestamp from its current inline position (between leading icon and content) to a right-aligned trailing position within the entry row. Layout becomes: `[leading icon] [8px gap] [content — Expanded] [8px gap] [timestamp — right]`.

**Rationale**: This resolves US3 — the reading flow goes left-to-right: icon → content → timestamp. The timestamp is still on the same row (no extra vertical space needed), consistent for both single-line and multiline entries. The `40px SizedBox` wrapper for the timestamp is removed; instead `Text` is placed at the end of the Row.

**Side benefit**: With the timestamp moved to trailing, the `Expanded` content column now starts immediately after the leading icon and gap. Multiline text wraps with consistent left-alignment against the content start column (US4 resolved simultaneously).

**Alternatives considered**:
- Place timestamp below content as sub-line text — more vertical space used; reasonable for very long entries but adds complexity and vertical density for short entries.
- Keep timestamp inline but use smaller/dimmer font — doesn't fix reading-flow order, only de-emphasizes it visually.

---

## Decision 3: @Mention Rich Text Rendering

**Decision**: Replace the plain `Text(entry.content)` with `Text.rich(TextSpan(...))` that splits the content on `@\w+` regex matches. Mention spans use `TextStyle(color: Colors.white70, fontWeight: FontWeight.w500)`. Non-mention spans use the existing body style (`fontSize: 14, color: isComplete ? Colors.white38 : Colors.white`).

**Rationale**: Flutter's `Text.rich` with inline `TextSpan` children is the standard approach for inline styled text. No new packages needed. The mention pattern `@\w+` (word characters after `@`) covers the existing autocomplete format used in `BulletCaptureBar`. The subtle `white70` / `w500` styling distinguishes mentions without heavy color contrast.

**Constraints**:
- Mention styling is visual only — no tap navigation from the mention span. Tapping the card still calls `onTap(bulletId)` as before.
- Completed tasks: mention spans fall back to the same `Colors.white38` as body text (no extra emphasis on completed entries).

**Alternatives considered**:
- Add a separate `linkedPersonName` display (already exists as trailing text) — doesn't handle `@Name` inline in content.
- Use a dedicated mention widget — overkill; inline `TextSpan` is sufficient.

---

## Decision 4: Card Spacing and Border Opacity

**Decision**: Increase outer card margin from `vertical: 3` to `vertical: 4`. Increase inner `GlassSurface` padding from `vertical: 8` to `vertical: 10`. In `GlassSurface` chip style, reduce border opacity from the current value (approximately `white.withValues(alpha: 0.12)`) to `white.withValues(alpha: 0.07)`.

**Rationale**: Small incremental increases preserve the compact bullet-journal feel while adding breathing room. The border opacity reduction makes cards feel more premium and less "boxed".

**Implementation note**: `GlassSurface` border styling is defined in `glass_surface.dart`. Changes to chip style affect all chip-style glass surfaces in the app — need to verify only timeline cards use `GlassStyle.chip` before changing the shared style, or apply the change locally in `_buildEntry` via `GlassSurface` parameters.

**Alternatives considered**:
- Remove borders entirely — makes card boundaries unclear when entries are adjacent.
- Use elevation/shadow instead of border — adds complexity to the glass surface system.

---

## Decision 5: Section Header Typography

**Decision**: Change the section header from uppercase `'TODAY'` with `letterSpacing: 1.2`, `fontWeight: FontWeight.w700`, `fontSize: 11` to title-case `'Today'` (or the date string already used in `_displayLabel`) with `fontWeight: FontWeight.w400`, `fontSize: 11`, `Colors.white38`, `letterSpacing: 0.4`.

**Rationale**: All-caps with high letter spacing reads as a "label" in a SaaS dashboard, not a journal. The softer weight and minimal letter spacing make the header feel like a quiet date marker — consistent with the editorial identity.

**Implementation note**: The section header is currently a hard-coded `'TODAY'` string in `today_timeline.dart`. This should be replaced with the actual date label passed from `DayViewScreen` (which already computes `'Today'`, `'Yesterday'`, or `'MMM d, yyyy'`). This means `TodayInteractionTimeline` needs a `sectionLabel: String` parameter.

**Alternatives considered**:
- Remove section header entirely — loses the day-anchor context when scrolling past multiple days.
- Keep uppercase but reduce weight — still feels dashboard-y.

---

## Decision 6: Composer and Tab Bar Visual Integration

**Decision**: The `BulletCaptureBar` is `Positioned(bottom: 0)` inside a `Stack` in `DayViewScreen`, while `_FloatingTabBar` floats in `RootTabScreen` above the safe area. Visual integration is achieved by ensuring the `BulletCaptureBar` bottom padding includes the tab bar height (~60px) using `MediaQuery.viewPaddingOf(context).bottom + 60`. This creates a visual gap between the capture bar and the screen edge that is the same height as the tab bar, making them appear as a stacked unit.

**Rationale**: This is a layout-only change with no structural refactoring. The `BulletCaptureBar` sits just above the tab bar area by accounting for tab bar height in its bottom padding. No component hierarchy changes needed.

**Constraint**: When the keyboard is open, `MediaQuery.viewInsetsOf(context).bottom > 0` causes `BulletCaptureBar` to remove its bottom padding (existing behavior). The tab bar is hidden by the keyboard in this state — no change needed.

**Alternatives considered**:
- Move composer into `RootTabScreen` as a child above the tab bar — major structural refactor, breaks the current scoped `date`-aware composer.
- Use a shared `BottomSheet` or `Scaffold.bottomNavigationBar` — not compatible with the current `Stack`-based floating design.

---

## Decision 7: No New Packages or Data Model Changes

**Decision**: All changes are purely visual/layout. No new packages required. No DB schema changes. The `@Name` mention pattern is already stored in bullet content. `TodayInteraction` model already has `status` and `completedAt` from 009-ui-polish.

**Rationale**: Consistent with the constitution's "no dead code / no speculative architecture" principle. All required data is already present.
