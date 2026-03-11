# Tasks: Carried-Over Tasks and Quick-Action Cards

**Input**: Design documents from `specs/005-task-carryover/`
**Branch**: `005-task-carryover`
**Prerequisites**: plan.md ✅ spec.md ✅ research.md ✅ data-model.md ✅ quickstart.md ✅

**Tests**: Included — the project constitution (Principle II) requires automated test coverage for every public-facing behavior described in acceptance scenarios.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)
- All paths are relative to repo root

---

## Phase 1: Setup

No setup required — no schema migration, no new dependencies, no new files. All changes are additive modifications to existing files.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Fix the carry-over DAO query. Both US1 and US2 depend on tasks appearing from the correct date range. This must be complete before any user story work begins.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [x] T001 Write unit test asserting `watchCarryOverTasks` returns tasks from any past day in the 1–7 day window (not just yesterday) in `app/test/database/daos/task_lifecycle_dao_test.dart` — ensure test FAILS before T002
- [x] T002 Update `watchCarryOverTasks` and `getCarryOverTasks` in `app/lib/database/daos/task_lifecycle_dao.dart`: replace `WHERE dl.date = ?` (yesterday) with `WHERE dl.date >= ? AND dl.date < ?` (sevenDaysAgo to today); update method signatures to remove `yesterday` parameter
- [x] T003 Update `carryOverTasksProvider` in `app/lib/providers/task_lifecycle_provider.dart` to pass `(sevenDaysAgo, today)` instead of `(yesterday, today, sevenDaysAgo)`; remove the `yesterday` local variable

**Checkpoint**: `flutter test app/test/database/daos/task_lifecycle_dao_test.dart` passes. A task created 3 days ago now appears in the carry-over stream.

---

## Phase 3: User Story 1 — Triage Carried-Over Tasks in Today's View (Priority: P1) 🎯 MVP

**Goal**: Today's daily log shows a "Carried Over" section containing all open, unscheduled tasks from the past 1–7 days. Each card displays the task title and an age badge ("Nd"). The section header disappears when empty.

**Independent Test**: Create a task 3 days ago (or inject a `Bullet` with `createdAt` = 3 days ago). Open today's `DailyLogScreen`. Verify:
1. A "Carried Over" section header appears.
2. The card shows the task title and a "3d" age badge.
3. No "Carried Over" section appears when no qualifying tasks exist.

### Tests for User Story 1

> **Write these tests FIRST — ensure they FAIL before T006**

- [x] T004 [P] [US1] Write widget test: `DailyLogScreen` shows "Carried Over" section with correct count badge when `carryOverTasksProvider` returns tasks in `app/test/widgets/daily_log_screen_test.dart`
- [x] T005 [P] [US1] Write widget test: `CarryOverTaskItem` renders age badge ("3d", "7d") computed from `bullet.createdAt` in `app/test/widgets/carry_over_task_item_test.dart`

### Implementation for User Story 1

- [x] T006 [US1] Convert `CarryOverTaskItem` to `ConsumerStatelessWidget`; add `_ageBadge(String createdAt)` helper returning "Nd" string; render age badge in card header row alongside the carry-over icon; remove `onQuickAction` constructor parameter in `app/lib/widgets/carry_over_task_item.dart`
- [x] T007 [US1] Update `DailyLogScreen`: remove `onQuickAction` callback from `CarryOverTaskItem` usage; rename `_FromYesterdayHeader` display text from `'From Yesterday'` to `'Carried Over'` in `app/lib/screens/daily_log/daily_log_screen.dart`

**Checkpoint**: `flutter test app/test/widgets/` passes. Run app on simulator — "Carried Over" section with age badges visible. Section disappears when all tasks resolved.

---

## Phase 4: User Story 2 — Quick-Action Task Cards Without Opening Detail Screen (Priority: P1)

**Goal**: Each carried-over task card shows an inline horizontal row of 6 quick-action chips (Complete, Keep for Today, Schedule, Backlog, → Note, Cancel). Tapping any chip applies the action immediately without navigation. Tapping the card body opens the detail screen.

**Independent Test**: Render a `CarryOverTaskItem` widget with a mock `Bullet`. Tap each action chip. Verify:
1. Tapping "Complete" calls `TaskLifecycleService.completeTask`.
2. Tapping "Keep for Today" calls `TaskLifecycleService.keepForToday`.
3. Tapping "Cancel" shows a snackbar with an undo action.
4. Tapping "Schedule" opens a date picker.
5. Tapping the non-button area of the card triggers `onTap` (navigates to detail).

### Tests for User Story 2

> **Write these tests FIRST — ensure they FAIL before T010**

- [x] T008 [P] [US2] Write widget test: tapping "Complete" chip on `CarryOverTaskItem` calls `completeTask` on a mocked `TaskLifecycleService` in `app/test/widgets/carry_over_task_item_test.dart`
- [x] T009 [P] [US2] Write widget test: tapping "Cancel" chip shows a snackbar with "Undo" action; tapping "Undo" calls `reactivateTask` in `app/test/widgets/carry_over_task_item_test.dart`

### Implementation for User Story 2

- [x] T010 [US2] Add inline action row to `CarryOverTaskItem` in `app/lib/widgets/carry_over_task_item.dart`: below the content column, add `SingleChildScrollView(scrollDirection: Axis.horizontal)` containing action chips in order: Complete (primary style), Keep for Today (primary style), Schedule (opens `showDatePicker`), Backlog, → Note (shows confirmation dialog before calling `convertToNote`), Cancel (destructive; shows undo snackbar calling `reactivateTask`). Wire each chip to `TaskLifecycleService` via `ref.read(taskLifecycleServiceProvider.future)`. Use `_today` getter: `DateFormat('yyyy-MM-dd').format(DateTime.now().toLocal())`
- [x] T011 [US2] Remove `_showQuickActions` call from `DailyLogScreen` (no longer needed as primary path) in `app/lib/screens/daily_log/daily_log_screen.dart` — `TaskQuickActionsSheet` may remain available for secondary use

**Checkpoint**: `flutter test app/test/widgets/carry_over_task_item_test.dart` passes. All 6 chips visible on card. Tapping Complete removes card. Tapping Keep for Today removes from Carried Over. No navigation required for any chip action.

---

## Phase 5: User Story 3 — Weekly Review for Long-Running Tasks (Priority: P2)

**Goal**: Tasks older than 7 days appear exclusively in Weekly Review (not in daily Carried Over). The Review tab shows a numeric badge when eligible tasks exist. Weekly Review shows the "Needs Attention" section at the top with a Complete action. Age badges use the compact "Nd" format matching the daily view.

**Independent Test**:
1. Create a task with `createdAt` = 8 days ago. Open today's log — task does NOT appear in Carried Over. Open Review tab — badge shows count ≥ 1. Open Weekly Review — task appears in "Needs Attention" with a "Complete" chip.
2. Tap "Complete" — task disappears from the list.

### Tests for User Story 3

> **Write these tests FIRST — ensure they FAIL before T015**

- [x] T012 [P] [US3] Write widget test: `WeeklyReviewTaskItem` renders a "Complete" chip as the first action chip in `app/test/widgets/weekly_review_task_item_test.dart`
- [x] T013 [P] [US3] Write widget test: `WeeklyReviewTaskItem` displays age as "Nd" compact badge (not "X days old" text) in `app/test/widgets/weekly_review_task_item_test.dart`
- [x] T014 [P] [US3] Write widget test: `RootTabScreen` Review tab shows a `Badge` with task count when `weeklyReviewTasksProvider` returns non-empty list in `app/test/widgets/root_tab_screen_test.dart`

### Implementation for User Story 3

- [x] T015 [P] [US3] Add "Complete" chip as first action in `WeeklyReviewTaskItem`'s action row; update age display from `"$days days old"` text to compact `"${days}d"` badge matching `CarryOverTaskItem` style in `app/lib/widgets/weekly_review_task_item.dart`
- [x] T016 [P] [US3] Move `_UnresolvedTasksSection()` to the top of `WeeklyReviewScreen`'s `SingleChildScrollView` column (above "Open Tasks" and "Events"); replace `BulletsDao(db).migrateBullet(bullet.id, today)` in `_migrateTask` with `TaskLifecycleService.keepForToday(bullet.id, today)` in `app/lib/screens/review/weekly_review_screen.dart`
- [x] T017 [US3] Watch `weeklyReviewTasksProvider` in `RootTabScreen`; wrap the Review tab's icon with `Badge(isLabelVisible: count > 0, label: Text('$count'), child: Icon(...))` using Material 3 `Badge` widget in `app/lib/screens/root_tab_screen.dart`

**Checkpoint**: `flutter test app/test/widgets/` passes. A task 8+ days old: absent from daily Carried Over, present in Weekly Review with Complete chip and "Nd" age badge. Review tab badge count reflects eligible tasks.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [x] T018 [P] Run full test suite and fix any failures: `cd app && flutter test`
- [x] T019 [P] Verify `dart analyze app/lib` reports zero new warnings or errors
- [ ] T020 Run quickstart.md manual verification scenarios end-to-end on iOS simulator

---

## Dependencies & Execution Order

### Phase Dependencies

- **Foundational (Phase 2)**: No dependencies — start immediately
- **US1 (Phase 3)**: Depends on Phase 2 completion (T001–T003)
- **US2 (Phase 4)**: Depends on Phase 3 completion (US1 adds age badge and removes `onQuickAction`; US2 adds action row to the same widget)
- **US3 (Phase 5)**: Depends on Phase 2 completion; independent of US1/US2 (different widgets and screen)
- **Polish (Phase 6)**: Depends on all desired phases complete

### User Story Dependencies

- **US1 (P1)**: Starts after Foundational. Independent.
- **US2 (P1)**: Starts after US1 (same `CarryOverTaskItem` file; US1 adds the age badge, US2 adds the action row).
- **US3 (P2)**: Starts after Foundational. Independent of US1 and US2 (different widgets). Can run in parallel with US1/US2.

### Within Each User Story

- Tests MUST be written first and confirmed to FAIL before implementation
- Widget modifications follow tests
- Screen/provider updates follow widget completion

### Parallel Opportunities

- T004 and T005 (US1 tests) can run in parallel
- T008 and T009 (US2 tests) can run in parallel
- T012, T013, T014 (US3 tests) can all run in parallel
- T015 and T016 (US3 implementation) can run in parallel (different files)
- US3 (all tasks T012–T017) can start immediately after Phase 2, in parallel with US1+US2

---

## Parallel Example: US3 (can start right after Phase 2)

```text
After Phase 2 completes:

Launch in parallel:
  Task T012: "WeeklyReviewTaskItem Complete chip test in app/test/widgets/weekly_review_task_item_test.dart"
  Task T013: "WeeklyReviewTaskItem age badge format test in app/test/widgets/weekly_review_task_item_test.dart"
  Task T014: "RootTabScreen badge test in app/test/widgets/root_tab_screen_test.dart"

After tests fail (confirmed), launch in parallel:
  Task T015: "WeeklyReviewTaskItem widget changes in app/lib/widgets/weekly_review_task_item.dart"
  Task T016: "WeeklyReviewScreen layout + migrateTask fix in app/lib/screens/review/weekly_review_screen.dart"

After T015 completes:
  Task T017: "RootTabScreen badge in app/lib/screens/root_tab_screen.dart"
```

---

## Implementation Strategy

### MVP First (US1 + US2 Only)

1. Complete Phase 2: Foundational (DAO query fix) — **CRITICAL**
2. Complete Phase 3: US1 — age badge + "Carried Over" label
3. Complete Phase 4: US2 — inline action chips
4. **STOP and VALIDATE**: Triage a carried-over task in 1–2 taps without opening detail screen
5. Ship US1+US2 independently before starting US3

### Full Delivery

1. Phase 2 → Phase 3 (US1) → Phase 4 (US2) sequential
2. Phase 5 (US3) in parallel with US1+US2 if separate developer available
3. Phase 6: Polish after all stories complete

---

## Task Count Summary

| Phase | Tasks | Notes |
| --- | --- | --- |
| Phase 2: Foundational | 3 | Blocks US1 + US2; US3 independent |
| Phase 3: US1 | 4 | 2 tests + 2 impl |
| Phase 4: US2 | 4 | 2 tests + 2 impl |
| Phase 5: US3 | 6 | 3 tests + 3 impl |
| Phase 6: Polish | 3 | — |
| **Total** | **20** | |

| Story | Parallel Tasks | Sequential Tasks |
| --- | --- | --- |
| US1 | T004, T005 (tests) | T006, T007 (impl) |
| US2 | T008, T009 (tests) | T010, T011 (impl) |
| US3 | T012, T013, T014 (tests); T015, T016 (impl) | T017 |
