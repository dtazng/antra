# Implementation Plan: AI-style Day View with Relationship Briefing and Morphing Cards

**Branch**: `006-day-view` | **Date**: 2026-03-11 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/006-day-view/spec.md`

---

## Summary

Replace Tab 0 (`DailyLogScreen`) with a new `DayViewScreen` that functions as a daily relationship command center. The screen generates ranked relationship suggestions from existing People data using an on-device `SuggestionEngine` service, tracks a daily interaction goal (count of distinct people reached today), and provides a persistent Quick Log bar for logging interactions in 3 taps. No schema migration. All new data is derived from the existing v3 schema.

---

## Technical Context

**Language/Version**: Dart 3.3+ / Flutter 3.19+
**Primary Dependencies**: drift 2.18 (SQLite ORM), flutter_riverpod 2.5, riverpod_annotation 2.3, uuid 4.x, intl 0.19 (all existing)
**Storage**: SQLite via drift + SQLCipher. Schema version stays at v4 — no migration required.
**Testing**: flutter_test (widget tests), dart test (unit tests for `SuggestionEngine`)
**Target Platform**: iOS (primary), Android
**Project Type**: Mobile app (Flutter)
**Performance Goals**:

- Day View interactive within 2s cold launch (constitution Principle IV)
- `SuggestionEngine.compute()` < 100ms for up to 200 contacts
- Suggestion card expand animation completes in ≤ 300ms
- Quick Log interaction logged within 500ms of Save tap (constitution Principle IV)

**Constraints**: Offline-first. All suggestion generation is on-device. No external API calls.
**Scale/Scope**: 20–200 contacts per user. ~100 bullets/day typical. Single-user device.

---

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-evaluated below after Phase 1 design.*

### Principle I — Code Quality

| Check | Status | Notes |
| --- | --- | --- |
| Single responsibility | ✓ PASS | `SuggestionEngine` is a pure Dart class with one job. Each widget covers one section. |
| No dead code | ✓ PASS | DailyLogScreen is not deleted — it is navigated to from other paths (still used). |
| Consistency over cleverness | ✓ PASS | Uses existing patterns: `@riverpod` providers, ConsumerWidget, drift DAOs, `PeopleDao.insertLink`. |
| Error handling at boundaries | ✓ PASS | Quick Log and card actions handle errors at the save boundary, not defensively throughout. |

### Principle II — Testing Standards

| Check | Status | Notes |
| --- | --- | --- |
| Happy path + edge case per acceptance scenario | ✓ REQUIRED | `SuggestionEngine` unit tests + widget tests for all 6 components. See tasks.md. |
| Test independence | ✓ REQUIRED | Each test sets up its own stub data via Riverpod overrides. |
| Offline path | ✓ PASS | All features are fully offline. No online-only path to test separately. |

### Principle III — UX Consistency

| Check | Status | Notes |
| --- | --- | --- |
| Capture speed (launch → log) | ✓ PASS | QuickLogBar: 3 taps. Uses existing `PersonPickerSheet` + `BulletsDao.insertBullet`. |
| Calm by default | ✓ PASS | No badges, streaks, or streak-break penalties. Goal is motivating but not punishing. |
| Consistent affordances | ✓ PASS | Card actions reuse same gesture patterns as existing `CarryOverTaskItem` chips. |
| Graceful empty states | ✓ REQUIRED | All 5 sections must render an empty state (spec FR-021). |
| Destructive actions require confirmation | ✓ PASS | No destructive data actions in Day View. Card dismissal is in-memory only. |
| Offline-transparent UX | ✓ PASS | All writes go through existing `BulletsDao` + `PeopleDao` which are local-first. |

### Principle IV — Performance

| Check | Status | Notes |
| --- | --- | --- |
| App launch to ready ≤ 2s | ✓ ACHIEVABLE | Day View is all local data. `SuggestionEngine` runs in <100ms. No network on launch. |
| Capture latency ≤ 500ms | ✓ ACHIEVABLE | Reuses existing `BulletsDao.insertBullet` path, already optimized. |
| Scroll at 60 fps | ✓ REQUIRED | `SuggestionCard` uses `AnimatedSize` (GPU-accelerated). No rebuilds on scroll. |
| Memory budget < 150 MB | ✓ PASS | No new images or heavy assets. Suggestions are 4 objects max. |

### Privacy & Data Integrity

| Check | Status |
| --- | --- |
| All data encrypted at rest | ✓ PASS — uses existing SQLCipher setup |
| Local is source of truth | ✓ PASS — no remote reads |
| No external analytics | ✓ PASS — no external service calls |
| No AI/LLM calls | ✓ PASS — `SuggestionEngine` is pure local computation |

**GATE RESULT: All principles pass. No violations to justify.**

---

## Project Structure

### Documentation (this feature)

```text
specs/006-day-view/
├── plan.md              # This file
├── research.md          # Phase 0 output ✅
├── data-model.md        # Phase 1 output ✅
├── quickstart.md        # Phase 1 output ✅
├── contracts/
│   └── ui-contracts.md  # Phase 1 output ✅
└── tasks.md             # Phase 2 output (created by /speckit.tasks)
```

### Source Code Layout

```text
app/lib/
  models/
    suggestion.dart            # NEW: Suggestion value object + SuggestionType enum
    today_interaction.dart     # NEW: TodayInteraction value object
    daily_goal.dart            # NEW: DailyGoal value object
  services/
    suggestion_engine.dart     # NEW: Pure Dart scoring service (no Flutter imports)
  providers/
    day_view_provider.dart     # NEW: suggestions, dailyGoal, todayInteractions, SuggestionNotifier
    day_view_provider.g.dart   # AUTO-GENERATED by build_runner
  screens/
    day_view/
      day_view_screen.dart     # NEW: Root screen (replaces DailyLogScreen at Tab 0)
  widgets/
    relationship_briefing.dart # NEW: Top briefing section
    daily_goal_widget.dart     # NEW: Progress bar + completion message
    suggestion_card.dart       # NEW: Morphing expand/collapse card
    quick_log_bar.dart         # NEW: Pinned 4-icon interaction capture bar
    today_timeline.dart        # NEW: Today's person-linked interaction list

  # Modified files:
  screens/
    root_tab_screen.dart       # MODIFY: swap DailyLogScreen → DayViewScreen at index 0

app/test/
  unit/
    suggestion_engine_test.dart   # NEW: Pure Dart unit tests
  widgets/
    relationship_briefing_test.dart
    daily_goal_widget_test.dart
    suggestion_card_test.dart
    quick_log_bar_test.dart
    today_timeline_test.dart
    day_view_screen_test.dart     # Integration-level widget test
```

**Structure Decision**: Single Flutter project, consistent with existing layout. New screens under `screens/day_view/`, new widgets under `widgets/`, new models under `models/`. One new provider file. No new packages.

---

## Implementation Strategy

### Phase-by-Phase

**Phase 1 — Setup & Models** (no dependencies):

- Create model files: `Suggestion`, `TodayInteraction`, `DailyGoal`.
- Create `SuggestionEngine` pure Dart service.
- Write unit tests for `SuggestionEngine` (scoring, ranking, exclusion, cap at 4).

**Phase 2 — Providers** (depends on Phase 1 models):

- Create `day_view_provider.dart` with `suggestionsProvider`, `dailyGoalProvider`, `todayInteractionsProvider`, `SuggestionNotifier`.
- Run `build_runner` to generate `.g.dart` files.

**Phase 3 — Widgets** (depends on Phase 2 providers; all parallelizable):

- `RelationshipBriefing` widget + test.
- `DailyGoalWidget` widget + test.
- `SuggestionCard` widget + test (expand/collapse, actions).
- `QuickLogBar` widget + test (type select → person select → save flow).
- `TodayInteractionTimeline` widget + test.

**Phase 4 — Screen assembly** (depends on Phase 3):

- `DayViewScreen` assembles all widgets with correct provider wiring.
- Integration widget test: log → timeline updates, goal increments, card removed.
- Update `RootTabScreen` to use `DayViewScreen` at index 0.

**Phase 5 — Polish** (parallel):

- `dart analyze` clean pass.
- Full `flutter test` suite pass.
- Manual verification per `quickstart.md`.

### MVP Scope

**Must ship** (P1 stories): Suggestion cards (US2), Quick Log bar (US3), Daily Goal widget (US4), Today Timeline (US5), Relationship Briefing (US1).
All 5 user stories are in MVP — they form one cohesive screen. US1–US3 are P1, US4–US5 are P2 but trivially derivable from data already computed for US1–US3.

---

## Post-Phase 1 Constitution Re-check

After Phase 1 design, all decisions have been reviewed:

- **No new DB tables**: Goal computed, suggestions computed. No sync complexity added.
- **No new packages**: `AnimatedSize` (Flutter SDK), existing `PersonPickerSheet`. Constitution Principle I satisfied.
- **`DailyLogScreen` not deleted**: Still accessible; only removed from Tab 0 default position. No dead code created.
- **Suggestion dismissal is in-memory**: No persistent state, no sync concern.

**Post-design GATE: PASS. No constitution violations.**

---

## Complexity Tracking

> No constitution violations — this table is empty.

*No deviations from any principle were required for this feature.*
