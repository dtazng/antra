# Research: Day View — Bullet Journal Refinement

**Feature**: `001-day-view-journal`
**Date**: 2026-03-13

---

## Decision 1: Composer widget strategy — new widget vs. adapt existing

**Decision**: Adapt the existing `BulletCaptureBar` widget rather than building a new one from scratch.

**Rationale**: `BulletCaptureBar` already implements exactly the required behaviour — freeform text entry, `@mention` autocomplete that fuzzy-matches contacts, and an inline "Create [name]" row that opens `CreatePersonSheet` as a modal bottom sheet (which does not navigate away from the Day View). The only required changes are:
1. Remove the type-pill row (`task / note / event`) so the composer defaults to `type = 'note'` silently.
2. Apply the aurora glass aesthetic (`GlassSurface.bar` + white text palette) to match the Day View style established in `007-aurora-design-system`.
3. Replace `CircleAvatar` + `ColorScheme` references in the @mention overlay with `PersonAvatar` + glass container styling.

**Alternatives considered**:
- **Keep QuickLogBar, add text field**: Would result in two input modes with conflicting affordances and dead code (type-button logic would become unreachable). Rejected.
- **Build a new composer from scratch**: Unnecessary duplication of @mention autocomplete logic already validated in production code. Rejected.

---

## Decision 2: Inline person creation — modal sheet vs. inline form

**Decision**: Retain the existing `showModalBottomSheet` pattern with `CreatePersonSheet`. This satisfies the spec requirement ("without navigating away from the Day View") because a modal bottom sheet is overlaid on top of the current route — it does not push a new route onto the navigation stack.

**Rationale**: The spec states "allow creating a new person inline... without leaving the Day View." A modal bottom sheet does not leave the Day View — the aurora background and screen state remain intact underneath. A fully inline form (collapsing into the composer) would add significant complexity for no additional user benefit.

**Alternatives considered**:
- **Inline expansion of the composer into a mini person-form**: More complex to implement, harder to handle validation feedback, would require managing two input states simultaneously. Rejected.

---

## Decision 3: Bullet type for journal entries

**Decision**: Journal entries from the new composer default to `type = 'note'` (no schema change required).

**Rationale**: The `Bullets` table already has `type` as a nullable text column (with a default of `'note'` in `BulletCaptureBar`). Existing timeline display in `TodayInteractionTimeline` and `BulletDetailScreen` handles `type = 'note'` correctly. The spec's intent is that users do not need to pick a type — removing the type-pill UI achieves this without any database migration.

**Alternatives considered**:
- **Add a new `type = 'log'` value**: Would require a schema migration (schema version bump) and downstream query updates. No functional benefit for this feature. Rejected.
- **Make `type` nullable in the schema**: Also a migration. The existing `'note'` default serves the same semantic purpose. Rejected.

---

## Decision 4: Removing the RelationshipBriefing summary card

**Decision**: Remove `RelationshipBriefing` from `DayViewScreen` entirely. The widget file and class are retained (not deleted) because they may be used in onboarding or other future screens, but the import and render call in `DayViewScreen` are removed.

**Rationale**: The spec requires removing the top summary card that says "Here are N relationship things worth doing today." `RelationshipBriefing` is that card. Its data source (`suggestionsFilteredProvider`) is still needed for `SuggestionCard` cards below, so the provider is retained.

**Alternatives considered**:
- **Refactor `RelationshipBriefing` to show something else**: No alternative content is specified. Removing is simpler and produces less dead code. Retained.

---

## Decision 5: Removing DailyGoalWidget and its supporting infrastructure

**Decision**: Delete `app/lib/widgets/daily_goal_widget.dart`, `app/lib/models/daily_goal.dart`, and remove `dailyGoalProvider` from `day_view_provider.dart`. Also remove `watchDistinctPersonCountForDay` from `BulletsDao` as it has no other callers.

**Rationale**: Complete removal of dead code aligns with Constitution Principle I ("No dead code"). These components exist solely to power the gamified goal card. No other screen or feature uses them.

**Alternatives considered**:
- **Keep the provider in case it's needed later**: Speculative retention of dead code. Rejected per Constitution Principle I.

---

## Decision 6: Today navigation boundary implementation

**Decision**: Pass a `showNext: bool` parameter to `_DateNavigator` computed from `_displayDate == today`. When `showNext = false`, the right arrow is hidden (replaced with a sized box) rather than grayed out.

**Rationale**: Hiding is cleaner than disabling — a disabled control implies the action will be available later, whereas hiding it communicates a hard boundary. The existing `_goToNextDay()` method already guards against advancing past today in its implementation; this change only updates the visual affordance to match.

**Alternatives considered**:
- **Disable (not hide) the right arrow**: Leaves visual clutter and an affordance that implies future navigation is possible. Rejected in favor of hiding.
- **Remove `_goToNextDay()` and rely solely on UI hiding**: The internal guard should stay as defense-in-depth (e.g., swipe gesture also calls `_goToNextDay()`). Both layers retained.
