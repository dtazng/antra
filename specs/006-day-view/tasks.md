# Tasks: AI-style Day View with Relationship Briefing and Morphing Cards

**Input**: Design documents from `specs/006-day-view/`
**Branch**: `006-day-view`
**Prerequisites**: plan.md ✅ spec.md ✅ research.md ✅ data-model.md ✅ contracts/ ✅ quickstart.md ✅

**Tests**: Included — Constitution Principle II requires automated coverage for every public-facing acceptance scenario.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: Which user story this task belongs to (US1–US5)
- All paths are relative to repo root

---

## Phase 1: Setup

No project initialization required. No new dependencies, no schema migration, no new packages. All changes are additive new files layered onto the existing Flutter project.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Models, `SuggestionEngine`, and Riverpod providers are shared by all five user stories. All must be complete before any story widget work begins.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [X] T001 [P] Create `Suggestion` value object and `SuggestionType` enum in `app/lib/models/suggestion.dart` — fields: `type`, `personId`, `personName`, `personNotes`, `signalText`, `score`; see data-model.md
- [X] T002 [P] Create `TodayInteraction` value object in `app/lib/models/today_interaction.dart` — fields: `bulletId`, `personId`, `personName`, `interactionLabel`, `loggedAt`; see data-model.md
- [X] T003 [P] Create `DailyGoal` value object in `app/lib/models/daily_goal.dart` — fields: `target` (hardcoded 3), `reached`; add `bool get completed => reached >= target`; see data-model.md
- [X] T004 Write unit tests for `SuggestionEngine` in `app/test/unit/suggestion_engine_test.dart` — test: birthday-within-7-days scores 3pts, needsFollowUp scores 2pts, contact gap 90+ days scores 2pts, gap 30–89 days scores 1pt, results capped at 4, contacts interacted with today are excluded, empty input returns empty list; verify tests FAIL before T005
- [X] T005 Implement `SuggestionEngine` pure Dart service in `app/lib/services/suggestion_engine.dart` — single public method `List<Suggestion> compute(List<PeopleData> people, String today, Set<String> todayPersonIds)`, no Flutter imports; implement scoring per research.md Decision 2; make T004 tests pass
- [X] T006 Implement `app/lib/providers/day_view_provider.dart` with four providers:
  - `suggestionsProvider` — `StreamProvider<List<Suggestion>>`: watches `allPeople`, filters today contacts from `bulletsForDayProvider`, runs `SuggestionEngine.compute()`, emits ranked list
  - `dailyGoalProvider` — `StreamProvider<DailyGoal>`: queries `bullet_person_links` joined to today's `day_logs` date, counts `DISTINCT person_id`, emits `DailyGoal(target: 3, reached: count)`
  - `todayInteractionsProvider` — `StreamProvider<List<TodayInteraction>>`: watches `bulletsForDayProvider(today)`, filters to bullets with person links, joins people names, maps to `TodayInteraction` list sorted newest-first
  - `SuggestionNotifier` — `@riverpod class` with `String? expandedPersonId` and `Set<String> dismissedPersonIds`; methods: `expand(String personId)`, `collapse()`, `dismiss(String personId)`
- [X] T007 Run `cd app && dart run build_runner build --delete-conflicting-outputs` to generate `app/lib/providers/day_view_provider.g.dart`

**Checkpoint**: `flutter test app/test/unit/suggestion_engine_test.dart` passes. All providers compile cleanly.

---

## Phase 3: User Story 1 — Relationship Briefing (Priority: P1) 🎯 MVP

**Goal**: A `RelationshipBriefing` widget reads `suggestionsProvider`, renders 2–4 human-readable suggestion rows, and shows a calm empty state when no signals exist.

**Independent Test**: Render `RelationshipBriefing` with a stubbed list of 3 `Suggestion` objects. Verify 3 suggestion rows appear with correct signal text. Render with empty list. Verify neutral message appears and no rows are shown.

### Tests for User Story 1

- [X] T008 [P] [US1] Write widget tests for `RelationshipBriefing` in `app/test/widgets/relationship_briefing_test.dart`:
  - Given 3 suggestions → 3 rows rendered with correct `signalText` values
  - Given empty suggestions → neutral message visible, no suggestion rows
  - Given `loading = true` → no suggestion text rendered
  - Given birthday suggestion → row contains person name

### Implementation for User Story 1

- [X] T009 [P] [US1] Implement `RelationshipBriefing` stateless widget in `app/lib/widgets/relationship_briefing.dart`:
  - Constructor: `suggestions` (`List<Suggestion>`), `loading` (`bool`)
  - When `loading = true`: show a placeholder shimmer or progress indicator
  - When `suggestions.isEmpty`: show neutral encouragement text (e.g., "Your relationships are looking good today.")
  - When `suggestions.isNotEmpty`: show "Good morning." header, subtitle "Here are [N] relationship things worth doing today:", then one bullet row per suggestion using `suggestion.signalText`; cap display at 4 items
  - Make T008 tests pass

**Checkpoint**: `flutter test app/test/widgets/relationship_briefing_test.dart` passes.

---

## Phase 4: User Story 2 — Morphing Suggestion Cards (Priority: P1)

**Goal**: A `SuggestionCard` widget shows a compact collapsed state and expands in place with an animation to reveal contact notes and contextual action buttons. Only one card is expanded at a time. Completing an action collapses/removes the card.

**Independent Test**: Render a `SuggestionCard` with a `Reconnect` suggestion, `expanded = false`. Verify action buttons are absent. Tap card header → pass `onTap`. Render with `expanded = true`. Verify "Message", "Call", and "Log meeting" buttons are present. Tap "Log meeting" → verify `onAction` called.

### Tests for User Story 2

- [X] T010 [P] [US2] Write widget tests for `SuggestionCard` in `app/test/widgets/suggestion_card_test.dart`:
  - Given `expanded = false` → action buttons NOT in widget tree
  - Given `expanded = true` → action buttons ARE in widget tree
  - Given `expanded = false`, tap card → `onTap` called
  - Given reconnect card `expanded = true` → "Message", "Call", "Log meeting" present
  - Given birthday card `expanded = true` → "Send greeting", "Log call" present
  - Given `expanded = true`, tap "Log meeting" → `onAction(SuggestionAction.logMeeting)` called
  - Given `personNotes = null`, `expanded = true` → notes section absent

### Implementation for User Story 2

- [X] T011 [P] [US2] Implement `SuggestionCard` widget in `app/lib/widgets/suggestion_card.dart`:
  - Constructor: `suggestion` (`Suggestion`), `expanded` (`bool`), `onTap` (`VoidCallback`), `onAction` (`void Function(SuggestionAction)`), `onDismiss` (`VoidCallback`)
  - Define `enum SuggestionAction { message, call, logMeeting, sendGreeting, logCall, followUp, scheduleLater, markDone, logNote }` (can live in `suggestion.dart`)
  - Collapsed state: contact name (prominent), card type chip, `suggestion.signalText`
  - Expanded state (wrap in `AnimatedSize(duration: Duration(milliseconds: 250), curve: Curves.easeInOut)`): collapsed content + notes section (if `suggestion.personNotes != null`) + action row with 2–4 `TextButton` chips per card type (see contracts/ui-contracts.md Component 3)
  - Wrap the card header area in a `GestureDetector(onTap: onTap)` with `behavior: HitTestBehavior.opaque`
  - Make T010 tests pass

**Checkpoint**: `flutter test app/test/widgets/suggestion_card_test.dart` passes. Card expands/collapses smoothly at 250ms.

---

## Phase 5: User Story 3 — Quick Log Interaction Bar (Priority: P1)

**Goal**: A persistent `QuickLogBar` pinned to the bottom of the screen shows 4 interaction type icons. Tapping a type shows the person picker. Selecting a person and tapping Save logs the interaction in ≤ 3 taps with no note required.

**Independent Test**: Render `QuickLogBar`. Verify 4 type icons (Coffee, Call, Message, Note) are visible. Tap Coffee → verify person picker visible. Tap a contact → verify Save button available. Tap Save → verify `onInteractionLogged` callback called.

### Tests for User Story 3

- [X] T012 [P] [US3] Write widget tests for `QuickLogBar` in `app/test/widgets/quick_log_bar_test.dart`:
  - Given idle state → 4 type icons visible (☕, 📞, ✉️, ✍️), person picker absent
  - Given Coffee tapped → person picker visible (or bottom sheet shows)
  - Given type and person selected → Save button available
  - Given Save tapped with no note → `onInteractionLogged` called, UI resets to idle
  - Given Coffee selected → created bullet has `type = 'event'` and content starting with `☕`
  - Given Note selected → note field required (not auto-saved); Save disabled until text entered

### Implementation for User Story 3

- [X] T013 [P] [US3] Implement `QuickLogBar` widget in `app/lib/widgets/quick_log_bar.dart`:
  - Constructor: `onInteractionLogged` (`void Function(String bulletId)`)
  - Render a `SafeArea`-wrapped row with 4 tappable icon+label buttons: ☕ Coffee, 📞 Call, ✉️ Message, ✍️ Note
  - On type tap: show existing `PersonPickerSheet` (at `app/lib/screens/people/person_picker_sheet.dart`) as a modal bottom sheet; use selected person to advance to step 2
  - On person selected: show a compact inline UI (or update bottom sheet) showing type + person name + optional note `TextField` + Save button
  - On Save: create bullet via `BulletsDao.insertBullet` with auto-generated content (e.g., `☕ Coffee with [name]`) and `type = 'event'`; call `PeopleDao.insertLink`; call `onInteractionLogged(bulletId)`; reset to idle
  - Note type: require user-typed content before enabling Save; `type = 'note'`, content = user text
  - Handle errors at save boundary only; show `SnackBar` on failure
  - Make T012 tests pass

**Checkpoint**: `flutter test app/test/widgets/quick_log_bar_test.dart` passes. Coffee → person → Save completes in 3 taps.

---

## Phase 6: User Story 4 — Daily Relationship Goal (Priority: P2)

**Goal**: A `DailyGoalWidget` reads `dailyGoalProvider`, shows a progress bar and count, and switches to a completion message when `goal.completed = true`.

**Independent Test**: Render `DailyGoalWidget` with `DailyGoal(target: 3, reached: 1)`. Verify "1 / 3 completed" text visible and progress bar partially filled. Render with `DailyGoal(target: 3, reached: 3)`. Verify completion message visible.

### Tests for User Story 4

- [X] T014 [P] [US4] Write widget tests for `DailyGoalWidget` in `app/test/widgets/daily_goal_widget_test.dart`:
  - Given `DailyGoal(target: 3, reached: 0)` → shows "0 / 3 completed", empty progress bar
  - Given `DailyGoal(target: 3, reached: 1)` → shows "1 / 3 completed"
  - Given `DailyGoal(target: 3, reached: 3)` → shows completion message, no "X / 3 completed" text
  - Given `DailyGoal(target: 3, reached: 2)` → progress bar value equals 2/3

### Implementation for User Story 4

- [X] T015 [P] [US4] Implement `DailyGoalWidget` stateless widget in `app/lib/widgets/daily_goal_widget.dart`:
  - Constructor: `goal` (`DailyGoal`)
  - When `goal.completed = false`: show "Reach out to {target} people today" header, "{reached} / {target} completed" sub-text, `LinearProgressIndicator(value: goal.reached / goal.target)`
  - When `goal.completed = true`: replace entire section with "Daily relationships complete ✓" title and "You strengthened {reached} connections today." subtitle; hide progress bar
  - Make T014 tests pass

**Checkpoint**: `flutter test app/test/widgets/daily_goal_widget_test.dart` passes.

---

## Phase 7: User Story 5 — Today Interaction Timeline (Priority: P2)

**Goal**: A `TodayInteractionTimeline` widget reads `todayInteractionsProvider`, shows today's logged interactions in reverse-chronological order, and shows an empty state when no interactions exist.

**Independent Test**: Render `TodayInteractionTimeline` with 3 `TodayInteraction` objects (different timestamps). Verify 3 entries appear in reverse-chronological order. Render with empty list. Verify empty-state message visible.

### Tests for User Story 5

- [X] T016 [P] [US5] Write widget tests for `TodayInteractionTimeline` in `app/test/widgets/today_timeline_test.dart`:
  - Given empty interactions → "No interactions logged yet today." visible
  - Given 3 interactions → 3 entries rendered in reverse-chronological order (newest first)
  - Given entry tapped → `onTap(bulletId)` called with correct ID
  - Given Coffee interaction → entry shows "☕" or "Coffee" label with person name

### Implementation for User Story 5

- [X] T017 [P] [US5] Implement `TodayInteractionTimeline` stateless widget in `app/lib/widgets/today_timeline.dart`:
  - Constructor: `interactions` (`List<TodayInteraction>`), `onTap` (`void Function(String bulletId)`)
  - When `interactions.isEmpty`: show "No interactions logged yet today." empty state (no blank area)
  - When `interactions.isNotEmpty`: show "Today" section header, then `ListView` of entries each showing timestamp (`HH:mm`), `interactionLabel`, and `personName` (e.g., "09:20 — ☕ Coffee with Alex"); entries sorted newest-first (callers provide them sorted; widget renders in order)
  - Wrap each entry in `GestureDetector(onTap: () => onTap(interaction.bulletId))`
  - Make T016 tests pass

**Checkpoint**: `flutter test app/test/widgets/today_timeline_test.dart` passes.

---

## Phase 8: Screen Assembly (Depends on T009, T011, T013, T015, T017)

**Goal**: Assemble all widgets into `DayViewScreen`. Wire all providers. Update `RootTabScreen` to show `DayViewScreen` at Tab 0. Verify the full screen integrates correctly end-to-end.

- [X] T018 Implement `DayViewScreen` in `app/lib/screens/day_view/day_view_screen.dart`:
  - `ConsumerStatefulWidget` watching `suggestionsProvider`, `dailyGoalProvider`, `todayInteractionsProvider`, `suggestionNotifierProvider`
  - Layout: `Scaffold` with a scrollable body containing (top-to-bottom): `RelationshipBriefing`, `DailyGoalWidget`, list of `SuggestionCard` widgets filtered by `dismissed` set, `TodayInteractionTimeline`; `QuickLogBar` pinned above the floating tab bar via `bottomNavigationBar` or a `Stack`
  - `SuggestionCard.expanded` determined by comparing `suggestion.personId` with `SuggestionNotifier.expandedPersonId`
  - `SuggestionCard.onTap` → calls `notifier.expand(personId)` (collapses others)
  - `SuggestionCard.onAction` → calls appropriate `BulletsDao`/`PeopleDao` method; on completion calls `notifier.dismiss(personId)`
  - `SuggestionCard.onDismiss` → calls `notifier.dismiss(personId)`
  - `QuickLogBar.onInteractionLogged` → no additional logic needed (providers auto-update via reactive streams)
  - `TodayInteractionTimeline.onTap(bulletId)` → `Navigator.push` to existing `BulletDetailScreen(bulletId: bulletId)`
  - Handle loading and error states for each async provider

- [X] T019 Write integration widget test for `DayViewScreen` in `app/test/widgets/day_view_screen_test.dart`:
  - Given `suggestionsProvider` returns 2 suggestions and `dailyGoalProvider` returns 0/3 → verify both suggestion cards visible and "0 / 3" text present
  - Given suggestion card tapped → card expands (action buttons visible)
  - Given second card tapped while first is expanded → first collapses, second expands
  - Given `todayInteractionsProvider` returns 1 interaction → timeline entry visible

- [X] T020 Update `RootTabScreen` at `app/lib/screens/root_tab_screen.dart`: replace `DailyLogScreen()` with `DayViewScreen()` at index 0 of `_screens`; update tab icon/label at index 0 if desired (e.g., "Today"); add `import 'package:antra/screens/day_view/day_view_screen.dart'`

**Checkpoint**: App launches showing `DayViewScreen` as Tab 0. Logging via `QuickLogBar` updates timeline and goal without navigation. `flutter test app/test/widgets/day_view_screen_test.dart` passes.

---

## Phase 9: Polish & Cross-Cutting Concerns

- [X] T021 [P] Run `cd app && dart analyze lib/` and fix any new warnings or errors introduced by this feature
- [X] T022 [P] Run full test suite `cd app && flutter test` and confirm all tests pass (zero failures)
- [X] T023 Run manual verification scenarios from `specs/006-day-view/quickstart.md` on iOS simulator: briefing shows correct signals, card expand/collapse animation works, Quick Log in 3 taps, goal increments, timeline updates, empty states are graceful

---

## Dependencies & Execution Order

### Phase Dependencies

- **Foundational (Phase 2)**: No dependencies — start immediately. T001, T002, T003 are parallel.
- **US1–US5 (Phases 3–7)**: All depend on Phase 2 completion (T007). Can start simultaneously after T007.
- **Assembly (Phase 8)**: Depends on all widget phases (T009, T011, T013, T015, T017) complete.
- **Polish (Phase 9)**: Depends on Assembly (T020) complete.

### User Story Dependencies

- **US1 (P1)**: Starts after Foundational. Independent — uses `suggestionsProvider` already created in T006.
- **US2 (P1)**: Starts after Foundational. Independent — uses `suggestionsProvider` + `SuggestionNotifier`.
- **US3 (P1)**: Starts after Foundational. Independent — uses `BulletsDao` + `PeopleDao` (existing).
- **US4 (P2)**: Starts after Foundational. Independent — uses `dailyGoalProvider`.
- **US5 (P2)**: Starts after Foundational. Independent — uses `todayInteractionsProvider`.

### Within Each User Story

- Test task MUST be written and confirmed to FAIL before implementation begins
- Widget implementation follows its test
- Only Phase 8 (Assembly) requires all widget phases to be complete

### Parallel Opportunities

- T001, T002, T003 (model files) — all parallel
- T004 can start after T001 (needs `Suggestion` type only)
- T005 follows T004 (TDD: red before green)
- T006 follows T001+T002+T003 (needs all models); can start in parallel with T004/T005
- T008, T010, T012, T014, T016 (all story tests) — can all start in parallel after T007
- T009, T011, T013, T015, T017 (all story widgets) — can all run in parallel (different files) after respective tests
- T021, T022 — parallel with each other after T020

---

## Parallel Example: Phase 3–7 (after T007 Foundational complete)

```text
After T007 completes:

Launch all story test + implementation pairs in parallel:
  US1: T008 RelationshipBriefing test → T009 RelationshipBriefing impl
  US2: T010 SuggestionCard test → T011 SuggestionCard impl
  US3: T012 QuickLogBar test → T013 QuickLogBar impl
  US4: T014 DailyGoalWidget test → T015 DailyGoalWidget impl
  US5: T016 TodayInteractionTimeline test → T017 TodayInteractionTimeline impl

After all T009, T011, T013, T015, T017 complete:
  Assembly: T018 → T019 → T020
```

---

## Implementation Strategy

### MVP First (US1 Only)

1. Complete Phase 2: Foundational (T001–T007)
2. Complete Phase 3: US1 Briefing (T008–T009)
3. **STOP and VALIDATE**: Render `DayViewScreen` with only `RelationshipBriefing` wired up
4. Add US2, US3, US4, US5 incrementally

### Incremental Delivery

1. Foundation (T001–T007) → All providers ready
2. US1 Briefing (T008–T009) → Briefing visible
3. US2 Cards (T010–T011) → Cards visible and expandable
4. US3 Quick Log (T012–T013) → Interactions loggable
5. US4 Goal (T014–T015) → Goal progress visible
6. US5 Timeline (T016–T017) → Timeline visible
7. Assembly (T018–T020) → Full screen wired, Tab 0 replaced
