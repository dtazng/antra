# Tasks: Day View — Bullet Journal Refinement

**Input**: Design documents from `specs/001-day-view-journal/`
**Branch**: `001-day-view-journal` | **Date**: 2026-03-13

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: Which user story this task belongs to (US1–US4)
- Tests are NOT included (not explicitly requested in the spec)

---

## Phase 1: Setup

**Purpose**: Establish a clean baseline before making changes.

- [X] T001 Run `flutter analyze` from `app/` to capture the pre-change analyzer baseline — zero new warnings are allowed after this feature lands

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Remove dead code (gamification model + providers + DAO method) that must be deleted before any user story work touches `day_view_screen.dart`. All four tasks touch different files and can run in parallel.

**⚠️ CRITICAL**: T002–T005 can run in parallel (different files). T006 must follow T004.

- [X] T002 [P] Delete `app/lib/models/daily_goal.dart` entirely — the `DailyGoal` view model is a gamification artifact with no remaining callers after this feature
- [X] T003 [P] Delete `app/lib/widgets/daily_goal_widget.dart` entirely — the `DailyGoalWidget` is the "Reach out to N people" progress card being removed
- [X] T004 [P] Remove `dailyGoalProvider` stream function and its `import 'package:antra/models/daily_goal.dart'` line from `app/lib/providers/day_view_provider.dart`; also delete the `watchDistinctPersonCountForDay` helper call site reference inside the provider
- [X] T005 [P] Remove the `watchDistinctPersonCountForDay` method from `app/lib/database/daos/bullets_dao.dart` (lines 290–299 in current code — the `Stream<int>` that counts distinct people per day)
- [X] T006 Run `dart run build_runner build --delete-conflicting-outputs` from `app/` to regenerate Riverpod code after T004 removes the `dailyGoalProvider` annotated function

**Checkpoint**: `flutter analyze` passes with no reference to `DailyGoal`, `DailyGoalWidget`, `dailyGoalProvider`, or `watchDistinctPersonCountForDay`. `flutter test` still passes.

---

## Phase 3: User Story 2 — Remove Gamification Elements (Priority: P1)

**Goal**: The Day View renders with zero outreach quota, progress bar, or count copy. The `RelationshipBriefing` summary card and `DailyGoalWidget` progress card are absent from the screen.

**Independent Test**: Open Day View on the simulator. Scroll from top to bottom. No card showing "Here are N relationship things worth doing today", no progress bar, no "0 / 3 completed" text, and no outreach goal copy appears anywhere on the screen.

### Implementation for User Story 2

- [X] T007 [US2] Remove `DailyGoalWidget` render block, the `goalAsync` watch (`ref.watch(dailyGoalProvider(_dateKey))`), and the `daily_goal_widget.dart` import from `app/lib/screens/day_view/day_view_screen.dart`
- [X] T008 [US2] Remove `RelationshipBriefing` render block and the `relationship_briefing.dart` import from `app/lib/screens/day_view/day_view_screen.dart` — the `suggestionsAsync` watch must remain because it still feeds `SuggestionCard`

**Checkpoint**: Launch Day View. The top briefing card ("Good morning. Here are…") and the goal progress card ("Reach out to 3 people today") are gone. `SuggestionCard` items still appear. `flutter test` still passes.

---

## Phase 4: User Story 1 — Bullet Journal Log Composer (Priority: P1) 🎯 MVP

**Goal**: The QuickLogBar (Coffee / Call / Message / Note buttons) is replaced by a journal-style freeform text composer. Users type a plain-text bullet, optionally `@mention` a person, and save in under 10 seconds. New people can be created inline without leaving the Day View.

**Independent Test**: Tap the composer, type "Coffee with @Alice", tap the Alice suggestion, tap submit. Entry saved, composer clears within 300ms. Type "@New Person", tap "Create 'New Person'", complete the creation sheet — new person exists and the mention resolves without navigating away. The old Coffee/Call/Message/Note buttons are nowhere on the screen.

### Implementation for User Story 1

- [X] T009 [P] [US1] Adapt `app/lib/widgets/bullet_capture_bar.dart`: (a) remove the `_types`, `_typeIcons`, `_typeLabels` constants, the `_TypePill` widget class, and the `_selectedType` state field + all setState calls referencing it; (b) hard-code `type: Value('note')` in the `BulletsCompanion.insert` call (removing `Value(_selectedType)`); (c) replace the outer `Container(decoration: BoxDecoration(color: cs.surface ...))` with `GlassSurface(style: GlassStyle.bar, padding: EdgeInsets.zero)` + add required imports; (d) replace `CircleAvatar` widgets in the `@mention` overlay with `PersonAvatar(personId: '', displayName: person.name, radius: 14)` and style the overlay container with `Colors.white.withValues(alpha: 0.08)` fill + `Colors.white.withValues(alpha: 0.12)` border; (e) change all `cs.onSurfaceVariant`, `cs.surface`, `cs.primaryContainer` etc. references to equivalent aurora white-opacity values (white text, white38 hint, `Colors.white.withValues(alpha: 0.18)` for the submit button background); (f) update hint text to `'What happened today…'`
- [X] T010 [US1] In `app/lib/screens/day_view/day_view_screen.dart`: remove the `quick_log_bar.dart` import; add `import 'package:antra/widgets/bullet_capture_bar.dart'`; replace `QuickLogBar(date: _dateKey, onInteractionLogged: (_) {})` in the pinned `Positioned` block with `BulletCaptureBar(date: _dateKey)`; remove the unused `_QuickLogBar`-related comment about estimated height (adjust the ListView bottom padding accordingly if needed)

**Checkpoint**: Launch Day View. The bottom bar shows a freeform text input with "What happened today…" hint. Type an `@mention` — a suggestion overlay appears. Save an entry — timeline (if person-linked) updates, composer resets. The old emoji/type buttons are gone entirely.

---

## Phase 5: User Story 3 — Single Follow-Up Surface Per Person (Priority: P2)

**Goal**: Each pending follow-up appears exactly once. The summary card (removed in US2/T008) was the source of duplication — this phase adds the correct empty state when there are no follow-ups, ensuring the screen never shows a count or aggregate.

**Independent Test**: Open Day View with 2 pending follow-ups. Exactly 2 `SuggestionCard` items appear. Dismiss both. The screen shows "Nothing to do — you're all caught up." No counter, no quota, no summary card.

### Implementation for User Story 3

- [X] T011 [US3] In `app/lib/screens/day_view/day_view_screen.dart`, update the empty state shown when the suggestion list is empty (currently `_EmptyState(icon: Icons.favorite_border_rounded, message: 'No suggestions right now — great work!')`) — change `message` to `'Nothing to do — you\'re all caught up.'` to match the calm, non-motivational tone defined in `contracts/ui-contracts.md`

**Checkpoint**: Dismiss all follow-up cards. The empty state reads "Nothing to do — you're all caught up." No goal counter, streak, or quota text appears anywhere.

---

## Phase 6: User Story 4 — Today Navigation Boundary (Priority: P2)

**Goal**: When today is the selected date, the forward (next-day) navigation arrow is hidden. Past dates still show both arrows. The forward button reappears only until the date reaches today again.

**Independent Test**: Open Day View (today selected). Forward arrow is absent. Tap backward — forward arrow reappears. Tap forward — date is today again, forward arrow disappears. Swipe right fast — date does not advance past today.

### Implementation for User Story 4

- [X] T012 [US4] In `app/lib/screens/day_view/day_view_screen.dart`: (a) in `_DayViewScreenState.build()`, compute `final bool _isBeforeToday = DateTime(_displayDate.year, _displayDate.month, _displayDate.day).isBefore(DateTime(now.year, now.month, now.day))` (add a local `final now = DateTime.now()`); (b) add a `showNext` named bool parameter to `_DateNavigator`; (c) in `_DateNavigator.build()`, replace the right `_NavArrow(icon: Icons.chevron_right_rounded, onTap: onNext)` with `widget.showNext ? _NavArrow(...) : const SizedBox(width: 30)` (matching the existing arrow tap-area width) so the layout remains balanced; (d) pass `showNext: _isBeforeToday` in the `_DateNavigator(...)` call in the AppBar

**Checkpoint**: Open Day View. Right arrow is invisible. Navigate back two days — right arrow is visible. Navigate forward to yesterday — still visible. Navigate forward to today — right arrow disappears. Fast swipe right has no effect.

---

## Phase 7: Polish & Validation

**Purpose**: Ensure analyzer is clean, tests pass, and quickstart scenarios verify all 4 user stories end-to-end.

- [X] T013 [P] Run `flutter analyze` from `app/` — fix all new analyzer warnings introduced by T002–T012 (zero new warnings allowed; pre-existing warnings are acceptable)
- [X] T014 [P] Run `flutter test` from `app/` — fix all failing tests; if existing tests reference `DailyGoalWidget`, `DailyGoal`, `RelationshipBriefing` render output, `QuickLogBar`, or `dailyGoalProvider` they must be updated or removed
- [X] T015 Manual verification on iPhone 16e simulator — run all 10 quickstart.md scenarios (S1–S10); pay particular attention to: composer reset timing (≤ 300ms, SC-007), forward button boundary (S7/S8), and no gamification elements visible (S4)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 — **BLOCKS all user story phases**; T002–T005 can run in parallel; T006 must follow T004
- **US2 (Phase 3)**: Depends on Phase 2 (T006 complete — generated code must be clean before modifying DayViewScreen)
- **US1 (Phase 4)**: T009 can start after Phase 2 (different file from DayViewScreen); T010 must follow T007+T008 (same file as US2 changes)
- **US3 (Phase 5)**: Depends on US2 (T008 removes the duplicate source; T011 adds correct empty state to the same file)
- **US4 (Phase 6)**: Depends on US1+US2+US3 being complete in `day_view_screen.dart` (same file — sequential edits)
- **Polish (Phase 7)**: Depends on all user story phases complete; T013 and T014 can run in parallel

### User Story Dependencies

- **US2 (P1)**: Must run before US1 DayViewScreen changes (T010), US3, and US4 — all touch the same file
- **US1 (P1)**: T009 (`bullet_capture_bar.dart`) is independent; T010 (`day_view_screen.dart`) follows US2
- **US3 (P2)**: Follows US2 (same file — RelationshipBriefing removal resolves the primary duplication concern)
- **US4 (P2)**: Fully self-contained but touches `day_view_screen.dart` — schedule after US1/US2/US3 to minimise merge conflicts

### Parallel Opportunities

1. **Phase 2 dead code removal** (T002, T003, T004, T005 — 4 different files, fully parallel)
2. **US1 composer adaptation** (T009 — `bullet_capture_bar.dart`) runs in parallel with Phase 3 US2 changes
3. **Phase 7 validation** (T013, T014 — independent tools, run in parallel)

---

## Parallel Example: Foundational Phase

```
Parallel batch (start together, all complete before T006):
  T002: Delete app/lib/models/daily_goal.dart
  T003: Delete app/lib/widgets/daily_goal_widget.dart
  T004: Remove dailyGoalProvider from app/lib/providers/day_view_provider.dart
  T005: Remove watchDistinctPersonCountForDay from app/lib/database/daos/bullets_dao.dart

Sequential (after T004):
  T006: dart run build_runner build --delete-conflicting-outputs
```

## Parallel Example: US1 + US2 (after Phase 2 complete)

```
Parallel (different files):
  T007+T008 (US2): Remove gamification from day_view_screen.dart
  T009 (US1):      Adapt bullet_capture_bar.dart

Sequential (after T007+T008):
  T010 (US1): Swap QuickLogBar → BulletCaptureBar in day_view_screen.dart
```

---

## Implementation Strategy

### MVP First (US2 + US1 — Gamification removed + Composer live)

1. Complete Phase 2: Foundational dead code removal (T002–T006)
2. Complete Phase 3: US2 (T007, T008) — gamification gone
3. Complete Phase 4: US1 (T009, T010) — journal composer live
4. **STOP and VALIDATE**: Day View has no progress card, no briefing summary, and the journal composer works end-to-end
5. Demoable: the two highest-impact P1 stories are complete

### Incremental Delivery

1. Foundation (T002–T006) → dead code deleted, build clean
2. US2 (T007, T008) → gamification removed, screen is calm
3. US1 (T009, T010) → journal composer replaces shortcut bar
4. US3 (T011) → correct empty state copy
5. US4 (T012) → today nav boundary enforced
6. Polish (T013–T015) → clean, verified

---

## Summary

| Phase | Tasks | User Story | Priority |
|-------|-------|------------|----------|
| Phase 1: Setup | T001 | — | — |
| Phase 2: Foundational | T002–T006 | — (blocking) | — |
| Phase 3: US2 Remove Gamification | T007–T008 | US2 | P1 |
| Phase 4: US1 Journal Composer | T009–T010 | US1 | P1 |
| Phase 5: US3 Single Follow-Up | T011 | US3 | P2 |
| Phase 6: US4 Today Nav Boundary | T012 | US4 | P2 |
| Phase 7: Polish | T013–T015 | — | — |
| **Total** | **15 tasks** | **4 stories** | — |

### Tasks per user story

| Story | Count | Description |
|-------|-------|-------------|
| US1 | 2 | Adapt `BulletCaptureBar`; swap into `DayViewScreen` |
| US2 | 2 | Remove `DailyGoalWidget` and `RelationshipBriefing` render calls |
| US3 | 1 | Update empty state copy |
| US4 | 1 | Hide forward nav arrow when today is selected |
| Foundation | 5 | Delete dead code files + methods + rebuild |
| Setup + Polish | 4 | Baseline + analyze + test + manual verify |

### Parallel opportunities identified: 3 groups

1. Foundation tasks T002–T005 (4 different files — delete in parallel)
2. US1 T009 (`bullet_capture_bar.dart`) alongside US2 T007/T008 (`day_view_screen.dart`)
3. Polish T013 + T014 (`flutter analyze` and `flutter test` — independent tools)

### Suggested MVP scope: Phase 2 (Foundation) + Phase 3 (US2) + Phase 4 (US1)

Completing T002–T010 delivers the highest-impact changes: gamification removed and the journal composer live — fully demoable and constitutionally compliant.
