# Implementation Plan: Day View — Bullet Journal Refinement

**Branch**: `001-day-view-journal` | **Date**: 2026-03-13 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/001-day-view-journal/spec.md`

---

## Summary

Refactor the Day View from a gamified relationship dashboard into a calm, editorial bullet journal. The changes are purely additive-removal: strip three UI surfaces (`RelationshipBriefing`, `DailyGoalWidget`, and `QuickLogBar`), delete their supporting code (`DailyGoal` model, `dailyGoalProvider`, `watchDistinctPersonCountForDay`), replace the input surface with a restyled `BulletCaptureBar`, and fix the date navigator to hide the forward button when today is selected. No database schema changes. No new packages.

---

## Technical Context

**Language/Version**: Dart 3.3+ / Flutter 3.19+
**Primary Dependencies**: flutter_riverpod 2.5, riverpod_annotation 2.3, drift 2.18, intl 0.19 — all existing; **no new packages**
**Storage**: SQLite via drift + SQLCipher (existing schema, no migration required)
**Testing**: flutter_test (widget tests), existing test suite in `app/test/`
**Target Platform**: iOS + Android (mobile-first)
**Project Type**: Mobile app (local-first personal CRM)
**Performance Goals**: Bullet save latency ≤ 500ms; composer reset ≤ 300ms; 60fps scroll
**Constraints**: No schema migration, no new packages, offline-capable, aurora glass aesthetic
**Scale/Scope**: Day View screen only (5 widgets modified/deleted, 1 provider removed, 1 widget adapted)

---

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design.*

### Principle I — Code Quality ✅

- Dead code is eliminated: `DailyGoalWidget`, `DailyGoal` model, `dailyGoalProvider`, `watchDistinctPersonCountForDay`, and the `RelationshipBriefing` render call are all removed.
- `BulletCaptureBar` is adapted (not duplicated). The type-pill UI is removed; the save logic and @mention system are reused unchanged.
- No backward-compatibility shims required — `DailyGoal` is a view model with no persistence footprint.

### Principle II — Testing Standards ✅

- Acceptance scenarios from the spec map directly to widget tests.
- Happy paths and edge cases are both covered (see `quickstart.md` scenarios 1–10).
- Tests must be independent (each sets up its own mock providers). No execution-order dependencies.
- Tests assert on user-observable outcomes: text visible in the timeline, button visibility, post-save empty state, etc.

### Principle III — UX Consistency ✅

- **Calm by default**: Removing all quota, streak, progress, and score elements directly satisfies this constitution requirement. No unsolicited performance pressure.
- **Capture speed is sacred**: The journal composer is the first interactive element on the screen (pinned bottom). Tap → keyboard up is the critical path. The existing `BulletCaptureBar` save path is < 500ms.
- **Graceful empty states**: Follow-up empty state ("Nothing to do — you're all caught up.") is defined. Composer idle state is always visible as the anchor entry point.
- **Consistent affordances**: The composer uses the same @mention and person-link gesture patterns as the existing `BulletCaptureBar` in the Daily Log screen.

### Principle IV — Performance ✅

- No new database queries added. One query removed (`watchDistinctPersonCountForDay`).
- `BulletCaptureBar` save path: `getOrCreateDayLog` + `insertBulletWithTags` + `insertLink` — identical to the existing Daily Log path, measured < 500ms on supported devices.
- No new heavy widgets. Removing `DailyGoalWidget` and `RelationshipBriefing` reduces the initial render complexity.

**Post-design re-check**: No violations in Phase 1 design decisions. All contracts in `ui-contracts.md` are consistent with the constitution.

---

## Project Structure

### Documentation (this feature)

```text
specs/001-day-view-journal/
├── plan.md              # This file
├── spec.md              # Feature specification
├── research.md          # Phase 0 — decisions on widget adaptation, data model, nav boundary
├── data-model.md        # Phase 1 — no schema changes; entity usage and removals documented
├── quickstart.md        # Phase 1 — 10 verification scenarios
├── contracts/
│   └── ui-contracts.md  # Phase 1 — widget contracts for Composer, DateNavigator, SuggestionCard, DayViewScreen
└── tasks.md             # Phase 2 output (/speckit.tasks — not created by /speckit.plan)
```

### Source Code (repository root)

```text
app/
├── lib/
│   ├── models/
│   │   └── daily_goal.dart              # DELETE — no longer referenced
│   ├── widgets/
│   │   ├── daily_goal_widget.dart       # DELETE — gamification card removed
│   │   ├── bullet_capture_bar.dart      # MODIFY — remove type-pill row; apply glass aesthetic; default type='note'
│   │   ├── relationship_briefing.dart   # KEEP FILE — remove render call from DayViewScreen only
│   │   └── quick_log_bar.dart           # KEEP FILE — remove render call from DayViewScreen only
│   ├── screens/
│   │   └── day_view/
│   │       └── day_view_screen.dart     # MODIFY — primary changes (see breakdown below)
│   ├── providers/
│   │   └── day_view_provider.dart       # MODIFY — remove dailyGoalProvider
│   └── database/
│       └── daos/
│           └── bullets_dao.dart         # MODIFY — remove watchDistinctPersonCountForDay
└── test/
    └── widgets/
        ├── day_view_screen_test.dart    # MODIFY — add boundary tests, verify no goal widget
        └── bullet_capture_bar_test.dart # NEW — journal composer widget tests
```

**Structure Decision**: Single Flutter app with no backend changes. All modifications are within `app/lib/` and `app/test/`.

---

## File-Level Change Breakdown

### `day_view_screen.dart` — primary modification

Changes:

1. Remove import of `daily_goal_widget.dart` and `relationship_briefing.dart`.
2. Remove `ref.watch(dailyGoalProvider(_dateKey))` call.
3. Remove `RelationshipBriefing(...)` render block from `ListView`.
4. Remove `DailyGoalWidget(goal: goal)` render block from `ListView`.
5. Replace `QuickLogBar(date: _dateKey, ...)` with `BulletCaptureBar(date: _dateKey)` in the pinned `Positioned` bottom block.
6. Add `import 'package:antra/widgets/bullet_capture_bar.dart'`.
7. In `_DateNavigator` call: add `showNext: _isBeforeToday` parameter.
8. Compute `_isBeforeToday` bool from `_displayDate` vs `DateTime.now()` at midnight.
9. `_DateNavigator` widget: add `showNext` bool field; conditionally show/hide right `_NavArrow`.

### `bullet_capture_bar.dart` — UI adaptation

Changes:

1. Remove type-pill row (`_types`, `_typeIcons`, `_typeLabels`, `_TypePill` widget, `_selectedType` state field, type-related setState calls).
2. Hard-code `type: Value('note')` in `BulletsCompanion.insert` call.
3. Replace `ColorScheme` references in the `@mention` overlay with aurora glass palette: `Colors.white.withValues(alpha: 0.08)` background, `Colors.white.withValues(alpha: 0.12)` border, white text, white38 hint.
4. Replace `CircleAvatar` in the overlay list with `PersonAvatar`.
5. Update hint text to something journal-appropriate (e.g., "What happened today…").
6. Wrap the outer container in `GlassSurface(style: GlassStyle.bar)` matching the existing `QuickLogBar` pattern.
7. Update submit button to use `Colors.white.withValues(alpha: 0.18)` glass style.

### `day_view_provider.dart` — remove `dailyGoalProvider`

Changes:

1. Delete the `dailyGoalProvider` function and its `part` generated code reference.
2. Delete `import 'package:antra/models/daily_goal.dart'`.
3. Re-run `dart run build_runner build` after deletion.

### `bullets_dao.dart` — remove `watchDistinctPersonCountForDay`

Changes:

1. Delete the `watchDistinctPersonCountForDay` method.

### `daily_goal_widget.dart` — DELETE

### `models/daily_goal.dart` — DELETE

---

## Complexity Tracking

No constitution violations. No complexity justification required.
