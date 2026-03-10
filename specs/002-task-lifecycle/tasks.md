# Tasks: Task Lifecycle & Review Flow

**Input**: Design documents from `/specs/002-task-lifecycle/`
**Prerequisites**: plan.md ✅ | spec.md ✅ | research.md ✅ | data-model.md ✅ | contracts/ ✅ | quickstart.md ✅

**Stack**: Flutter 3.19+ / Dart 3.3+ · drift 2.18 · flutter_riverpod 2.5 · riverpod_annotation 2.3 · SQLite (SQLCipher)

**Organization**: Tasks are grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: Which user story (US1–US3) this task belongs to
- Every task includes the exact file path

---

## Phase 1: Setup (Schema & Table Definitions)

**Purpose**: Add new columns and the new lifecycle events table to the drift schema definitions. These are pure Dart/drift table changes — no logic yet.

- [X] T001 Add `scheduledDate`, `carryOverCount`, `completedAt`, `canceledAt` columns to the `Bullets` drift table class in `app/lib/database/tables/bullets.dart`
- [X] T002 Create the `TaskLifecycleEvents` drift table class in `app/lib/database/tables/task_lifecycle_events.dart` with columns: `id` (TEXT PK), `bulletId` (TEXT), `eventType` (TEXT), `metadata` (TEXT nullable), `occurredAt` (TEXT)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Wire the new tables into the database, write the migration, build the DAO and service, and expose Riverpod providers. ALL user story work depends on this phase being complete.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [X] T003 Register `TaskLifecycleEvents` in `app/lib/database/app_database.dart`: add import + export, add to `@DriftDatabase(tables: [...])`, bump `schemaVersion` to `2`, implement `onUpgrade` migration using `m.addColumn()` for the four new bullet columns and `m.createTable(taskLifecycleEvents)`, add `idx_task_events_bullet_id` and `idx_bullets_created_at` indexes in migration
- [X] T004 [P] Create `TaskLifecycleDao` in `app/lib/database/daos/task_lifecycle_dao.dart` — annotated `@DriftAccessor(tables: [Bullets, TaskLifecycleEvents, DayLogs])` — with these methods:
  - `Stream<List<TaskLifecycleEvent>> watchEventsForBullet(String bulletId)` — SELECT from task_lifecycle_events WHERE bullet_id = ? ORDER BY occurred_at ASC
  - `Future<void> insertEvent(String bulletId, String eventType, {String? metadata})` — inserts a new row with uuid v4 id and UTC now timestamp
  - `Future<List<Bullet>> getCarryOverTasks(String yesterday, String today, String sevenDaysAgo)` — raw SQL joining bullets + day_logs WHERE dl.date = yesterday AND b.type = 'task' AND b.status = 'open' AND b.is_deleted = 0 AND (b.scheduled_date IS NULL OR b.scheduled_date <= today) AND b.created_at > sevenDaysAgo ORDER BY b.created_at ASC
  - `Stream<List<Bullet>> watchCarryOverTasks(String yesterday, String today, String sevenDaysAgo)` — same as above but watch()
  - `Stream<List<Bullet>> watchWeeklyReviewTasks(String today, String sevenDaysAgo)` — SELECT from bullets WHERE b.type = 'task' AND b.status = 'open' AND b.is_deleted = 0 AND b.created_at <= sevenDaysAgo AND (b.scheduled_date IS NULL OR b.scheduled_date <= today) ORDER BY b.created_at ASC
- [X] T005 [P] Mark `migrateBullet()` in `app/lib/database/daos/bullets_dao.dart` as `@Deprecated('Use TaskLifecycleService.keepForToday() instead. Legacy migrated rows are still readable.')` — do not delete the method, only annotate it
- [X] T006 Create `TaskLifecycleService` in `app/lib/services/task_lifecycle_service.dart` — pure Dart class (no Flutter imports), takes `AppDatabase db` and `String deviceId` in constructor, delegates DB writes to `TaskLifecycleDao`. Implement all seven state transition methods, each in a `db.transaction()`:
  - `completeTask(String bulletId)` → set `status='complete'`, `completedAt=now`, append `completed` event
  - `cancelTask(String bulletId)` → set `status='cancelled'`, `canceledAt=now`, append `canceled` event
  - `keepForToday(String bulletId, String todayDate)` → get/create today's DayLog, update `dayId` to today's log id, increment `carryOverCount`, append `kept_for_today` event with metadata `{"fromDate": yesterday, "toDate": todayDate}`
  - `scheduleTask(String bulletId, String date)` → set `scheduledDate=date`, append `scheduled` event with metadata `{"scheduledDate": date}`
  - `moveToBacklog(String bulletId)` → set `status='backlog'`, clear `scheduledDate`, append `moved_to_backlog` event
  - `reactivateTask(String bulletId, String todayDate)` → get/create today's DayLog, set `status='open'`, update `dayId` to today, append `reactivated` event
  - `convertToNote(String bulletId)` → set `type='note'`, append `converted_to_note` event
  - `moveToThisWeek(String bulletId, String todayDate)` → identical to `keepForToday` — delegates to it
- [X] T007 Run `dart run build_runner build --delete-conflicting-outputs` in `app/` to regenerate `app_database.g.dart`, `task_lifecycle_dao.g.dart`, and all other `.g.dart` files after T003 and T004 are complete
- [X] T008 Create `app/lib/providers/task_lifecycle_provider.dart` with these Riverpod `@riverpod` providers:
  - `taskLifecycleService(ref)` — async provider returning `TaskLifecycleService(db: await ref.watch(appDatabaseProvider.future))`
  - `carryOverTasksProvider(ref)` — stream provider that computes `yesterday` (local timezone date string), `today`, and `sevenDaysAgo` then calls `TaskLifecycleDao(db).watchCarryOverTasks(...)`
  - `weeklyReviewTasksProvider(ref)` — stream provider calling `TaskLifecycleDao(db).watchWeeklyReviewTasks(...)`
  - `taskLifecycleEventsProvider(ref, String bulletId)` — stream provider calling `TaskLifecycleDao(db).watchEventsForBullet(bulletId)`
  - Include a private helper `String _localDateString(DateTime dt)` → `dt.toLocal()` formatted as `'YYYY-MM-DD'` using intl DateFormat
- [X] T009 Run `dart run build_runner build --delete-conflicting-outputs` in `app/` again after T008 to generate `task_lifecycle_provider.g.dart`

**Checkpoint**: DB migrates cleanly, service compiles, providers resolve. Verify with `flutter run` — app must launch without crash.

---

## Phase 3: User Story 1 — Daily Carry-Over (Priority: P1) 🎯 MVP

**Goal**: Today screen shows a "From Yesterday" section with unfinished tasks. Users can act on each task with 6 quick actions from a bottom sheet without opening a detail view.

**Independent Test**: Create a task on "yesterday" (seed or advance device date). Open app. Verify "From Yesterday" section appears with the task and a carry-over indicator. Tap each quick action and verify the task state changes correctly and the section updates reactively.

- [X] T010 [P] [US1] Create `CarryOverTaskItem` widget in `app/lib/widgets/carry_over_task_item.dart` — `StatelessWidget` accepting `Bullet bullet`, `VoidCallback onTap`, `VoidCallback onQuickAction`. Layout: a row with a migration/carry-over icon (e.g. `Icons.redo`), the task content text (max 2 lines, overflow ellipsis), a carry-over count badge showing `"×N"` if `bullet.carryOverCount > 0`, and a trailing chevron. The whole row is tappable (`InkWell`) calling `onTap`. Long press calls `onQuickAction`.
- [X] T011 [P] [US1] Create `TaskQuickActionsSheet` in `app/lib/widgets/task_quick_actions_sheet.dart` — a `ConsumerWidget` shown via `showModalBottomSheet`. Accepts `Bullet bullet` and a reference to `taskLifecycleServiceProvider`. Displays 6 action rows in a `Column` inside a `SafeArea`: (1) Mark Complete — calls `service.completeTask(bullet.id)` then pops; (2) Keep for Today — calls `service.keepForToday(bullet.id, today)` then pops; (3) Schedule — shows `showDatePicker` (firstDate: tomorrow, lastDate: 1 year out) then calls `service.scheduleTask(bullet.id, picked)` then pops; (4) Move to Backlog — calls `service.moveToBacklog(bullet.id)` then pops; (5) Convert to Note — calls `service.convertToNote(bullet.id)` then pops; (6) Cancel Task — calls `service.cancelTask(bullet.id)`, pops, then shows a `ScaffoldMessenger.showSnackBar` with "Task canceled. Undo" (duration: 3 seconds). The Undo action calls `service.reactivateTask(bullet.id, today)`. Each row: leading icon, label text, full-width tap target.
- [X] T012 [US1] Modify `app/lib/screens/daily_log/daily_log_screen.dart` to add the "From Yesterday" section. Watch `carryOverTasksProvider` in the build method. In the `ListView.builder` for today's bullets, append a "From Yesterday" section header and a list of `CarryOverTaskItem` widgets when `carryOverTasks.isNotEmpty`. Section header: `Text('From Yesterday')` with a badge showing the count. Each `CarryOverTaskItem.onQuickAction` calls `showModalBottomSheet(builder: (_) => TaskQuickActionsSheet(bullet: task))`. Each `CarryOverTaskItem.onTap` navigates to `TaskDetailScreen(bulletId: task.id)` (stub navigation — `TaskDetailScreen` created in US2).
- [X] T013 [US1] Verify the complete US1 flow works end-to-end: carry-over section appears reactively, all 6 actions on `TaskQuickActionsSheet` update the task and remove it from the carry-over list, cancel undo restores the task within 3 seconds.

**Checkpoint**: US1 independently functional. Carry-over section appears and all quick actions work reactively without detail screen.

---

## Phase 4: User Story 2 — Task Detail View with Lifecycle History (Priority: P2)

**Goal**: Tapping any task opens a detail screen showing content, current state, scheduled date, carry-over count (with amber warning at 3+), full lifecycle history, and all available actions.

**Independent Test**: Create a task. Carry it over once (Keep for Today). Reschedule it. Open the task detail. Verify the history shows three events in chronological order with timestamps: "Created", "Kept for Today", "Scheduled". Verify carry-over count shows "1×". Perform complete/cancel from the detail view and verify the event list updates immediately.

- [X] T014 [P] [US2] Create `LifecycleEventTile` widget in `app/lib/widgets/lifecycle_event_tile.dart` — `StatelessWidget` accepting `TaskLifecycleEvent event`. Maps `event.eventType` to a leading `Icon` (see contracts/ui-screens.md event icon table) and a human-readable label string (e.g. `'kept_for_today'` → `'Kept for Today'`). Shows the `event.occurredAt` formatted as a relative or absolute date on the trailing side. Returns a `ListTile` with `dense: true`.
- [X] T015 [US2] Create `TaskDetailScreen` in `app/lib/screens/daily_log/task_detail_screen.dart` — `ConsumerWidget` accepting `String bulletId`. Watches the bullet via a new `singleBulletProvider(bulletId)` added to `app/lib/providers/bullets_provider.dart` (simple SELECT by id stream). Watches `taskLifecycleEventsProvider(bulletId)`. Layout in a `SingleChildScrollView`:
  - AppBar: close button, "Task" title
  - **Content section**: task content text, editable via tap (shows a text field, saves on dismiss with `bulletsDao.updateBulletContent()`)
  - **Status row**: colored chip showing current state (open → "Active", backlog → "Backlog", complete → "Completed", cancelled → "Canceled") + carry-over count text ("Carried over N×" in gray for N<3, amber for N≥3 with exclamation icon)
  - **Scheduled date row** (only if `bullet.scheduledDate != null`): calendar icon + formatted date + clear (X) button that calls `service.scheduleTask(bulletId, null)` — actually calls a new `clearSchedule(bulletId)` method that sets `scheduledDate=null` and appends a `scheduled` event with `{"scheduledDate": null}`
  - **Lifecycle history section**: header "History" + `ListView` of `LifecycleEventTile` for each event in chronological order
- [X] T016 [US2] Add an **Actions section** at the bottom of `TaskDetailScreen` — a `Wrap` of `OutlinedButton` / `FilledButton` widgets showing only contextually valid actions:
  - If status=open: Complete, Cancel, Schedule, Move to Backlog, Convert to Note
  - If status=backlog: Reactivate, Cancel
  - If status=complete or cancelled: no actions shown (read-only view)
  - Each button calls the corresponding `TaskLifecycleService` method; after the action the screen reactively updates (no manual refresh needed — the stream providers handle it)
- [X] T017 [US2] Wire `CarryOverTaskItem.onTap` in `app/lib/widgets/carry_over_task_item.dart` to navigate to `TaskDetailScreen(bulletId: bullet.id)` using `Navigator.of(context).push(MaterialPageRoute(builder: (_) => TaskDetailScreen(bulletId: bullet.id)))`
- [X] T018 [US2] Wire task-type bullet taps in `app/lib/screens/daily_log/daily_log_screen.dart` — in the `ListView.builder` for today's entries, if `bullet.type == 'task'`, wrap in an `InkWell` (or update `BulletListItem.onTap`) that navigates to `TaskDetailScreen(bulletId: bullet.id)`

**Checkpoint**: US2 independently functional. Tapping any task opens detail with full history. All actions work and history updates in real time.

---

## Phase 5: User Story 3 — Weekly Review Queue (Priority: P3)

**Goal**: The Weekly Review screen surfaces all active tasks older than 7 days that are not in backlog. Users can resolve each task with 5 quick actions directly from the list row.

**Independent Test**: Seed (or date-advance) tasks older than 7 days. Open Weekly Review. Verify each appears with age indicator. Perform each of the 5 actions and verify the task is removed from the queue reactively. Verify that none of these tasks appear in Today's "From Yesterday" section simultaneously.

- [X] T019 [P] [US3] Create `WeeklyReviewTaskItem` widget in `app/lib/widgets/weekly_review_task_item.dart` — `ConsumerWidget` accepting `Bullet bullet`. Shows: task content (2 lines max), age indicator (e.g. "12 days old" computed from `bullet.createdAt`), carry-over count badge if > 0. Below the content: a row of 5 compact `TextButton` / `IconButton` actions: [This Week] [Schedule] [Backlog] [Cancel] [→ Note]. Each action calls the corresponding `TaskLifecycleService` method via `ref.read(taskLifecycleServiceProvider.future)`. Schedule shows `showDatePicker` first. Cancel shows a `ScaffoldMessenger` snackbar with Undo (same 3-second pattern as `TaskQuickActionsSheet`).
- [X] T020 [US3] Add an `UnresolvedTasksSection` to `app/lib/screens/review/weekly_review_screen.dart`. Watch `weeklyReviewTasksProvider`. Add the section after existing review prompts. Section structure: header `Text('Needs Attention')` with count badge + subtitle `Text('Tasks older than 7 days')`, then a `ListView` of `WeeklyReviewTaskItem` widgets. Show an empty state when the list is empty: centered checkmark icon + `Text('Nothing to review — you\'re all caught up.')`.
- [X] T021 [US3] Verify the complete US3 flow end-to-end: weekly review tasks appear correctly, all 5 actions remove the task from the queue reactively, a task that appears in Weekly Review does NOT simultaneously appear in the "From Yesterday" section of Today (validate the mutual exclusion via the `created_at` query threshold).

**Checkpoint**: All three user stories independently functional and verified.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final quality pass — visual refinements, edge case handling, deprecation cleanup, and end-to-end validation.

- [X] T022 [P] Add an empty state for the "From Yesterday" section in `app/lib/screens/daily_log/daily_log_screen.dart` — the section header should only render when `carryOverTasks.isNotEmpty`; when the list drains to empty the section disappears with no blank space (verify this is already handled by the conditional render in T012, otherwise fix it here)
- [X] T023 [P] Apply amber/warning styling to the carry-over count in `app/lib/widgets/carry_over_task_item.dart` — when `bullet.carryOverCount >= 3`, render the count badge in `colorScheme.error` or amber color with a warning icon. Also verify the same emphasis is present in `TaskDetailScreen` (T015 carries this requirement; validate here)
- [X] T024 [P] Confirm `TaskLifecycleEvents` rows are excluded from the sync queue — verify `task_lifecycle_dao.dart` `insertEvent()` does NOT call `_enqueueSync()`. Add a comment in the DAO: `// Lifecycle events are local-only in v1. Sync integration deferred.`
- [ ] T025 Run all 8 quickstart.md validation scenarios manually on the simulator: Scenario 1 (basic carry-over), Scenario 2 (count accumulation), Scenario 3 (schedule removes task), Scenario 4 (backlog exclusion), Scenario 5 (weekly review eligibility), Scenario 6 (convert to note), Scenario 7 (cancel with undo), Scenario 8 (mutual exclusion)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies — start immediately. T001 and T002 can run in parallel.
- **Phase 2 (Foundational)**: Depends on Phase 1. T003 depends on T001+T002. T004 and T005 can run in parallel after T003. T006 depends on T004 (uses `TaskLifecycleDao`). T007 depends on T003+T004 (build_runner). T008 depends on T006. T009 depends on T008.
- **Phase 3 (US1)**: Depends on Phase 2. T010 and T011 can run in parallel. T012 depends on T010+T011. T013 validates T012.
- **Phase 4 (US2)**: Depends on Phase 2. T014 can run in parallel with T015. T015 depends on T014 (uses `LifecycleEventTile`). T016 depends on T015. T017 and T018 depend on T015.
- **Phase 5 (US3)**: Depends on Phase 2. T019 can start independently. T020 depends on T019. T021 validates T020.
- **Phase 6 (Polish)**: Depends on Phases 3–5.

### User Story Dependencies

- **US1 (P1)**: Depends only on Phase 2. Can start after foundational is done.
- **US2 (P2)**: Depends on Phase 2. Optionally enhanced by US1 (navigates from carry-over list), but `TaskDetailScreen` is independently accessible.
- **US3 (P3)**: Depends on Phase 2 only. Completely independent of US1 and US2.

---

## Parallel Opportunities

```
# Phase 1 — run both in parallel:
T001 bullets.dart column additions
T002 task_lifecycle_events.dart table definition

# Phase 2 — after T003:
T004 TaskLifecycleDao  ←── parallel
T005 @Deprecated on migrateBullet()  ←── parallel

# Phase 3 — after Phase 2:
T010 CarryOverTaskItem widget  ←── parallel
T011 TaskQuickActionsSheet widget  ←── parallel

# Phase 4 — after Phase 2:
T014 LifecycleEventTile widget  ←── parallel with T010/T011

# Phase 6 — all polish tasks:
T022, T023, T024  ←── all parallel
```

---

## Implementation Strategy

### MVP (User Story 1 Only)

1. Complete Phase 1 (T001–T002)
2. Complete Phase 2 (T003–T009)
3. Complete Phase 3 (T010–T013)
4. **STOP and VALIDATE**: "From Yesterday" appears, all 6 quick actions work
5. App is already more functional than before — ship or demo

### Incremental Delivery

1. Phase 1 + Phase 2 → schema and service ready
2. Phase 3 (US1) → Daily carry-over → validate → demo
3. Phase 4 (US2) → Task detail with history → validate → demo
4. Phase 5 (US3) → Weekly review queue → validate → demo
5. Phase 6 → Polish pass → release

---

## Notes

- `build_runner` must be re-run (T007, T009) whenever drift table definitions or Riverpod `@riverpod` annotations change
- `schemaVersion` bump (T003) requires uninstalling and reinstalling the app on a fresh simulator if the DB was already initialized at v1
- The `keepForToday` and `moveToThisWeek` methods in `TaskLifecycleService` are intentionally identical — `moveToThisWeek` delegates to `keepForToday`. Do not merge them; they have separate semantic meaning for lifecycle event readability.
- `cancelTask` and its undo pattern must be implemented as a soft cancel followed by a timer — do NOT implement as an optimistic UI update with a delayed commit. The service call happens immediately; `reactivateTask` is called on undo.
