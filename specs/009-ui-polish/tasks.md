# Tasks: UI Polish — Composer, Task Cards & Tab Bar

**Input**: Design documents from `/specs/009-ui-polish/`
**Prerequisites**: plan.md ✅ spec.md ✅ research.md ✅ data-model.md ✅ contracts/ ✅ quickstart.md ✅

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: Which user story this task belongs to (US1–US5)
- Exact file paths included in all task descriptions

---

## Phase 1: Setup (Read Existing Files)

**Purpose**: Load current state of all files touched by this feature before making any changes

- [x] T001 Read app/lib/models/today_interaction.dart, app/lib/providers/day_view_provider.dart, and app/lib/screens/day_view/day_view_screen.dart to understand current TodayInteraction model, how it is built from Bullet data, and how DayViewScreen wires the timeline
- [x] T002 Read app/lib/database/daos/bullets_dao.dart lines 60–120 to understand the existing `updateBulletStatus`, `softDeleteBullet`, and `undoSoftDeleteBullet` patterns before adding completion methods
- [x] T003 Read app/lib/widgets/today_timeline.dart and app/test/widgets/today_timeline_test.dart to understand current widget API and test structure before modifying both
- [x] T004 [P] Read app/lib/widgets/bullet_capture_bar.dart to understand current type toggle and TextField structure before removing the sublabel and adding rounded borders
- [x] T005 [P] Read app/lib/screens/root_tab_screen.dart to understand current `_FloatingTabBar` and `_TabButton` color references before the redesign

---

## Phase 2: Foundational (Blocking Prerequisite)

**Purpose**: Update `TodayInteraction` model with `status` and `completedAt` fields. All US1–US3 timeline changes depend on this.

**⚠️ CRITICAL**: US1 (task completion rendering) cannot be implemented until TodayInteraction carries these fields.

- [x] T006 Add `status: String` (default `'open'`) and `completedAt: String?` fields to the `TodayInteraction` class in app/lib/models/today_interaction.dart, update its constructor, and update every call site in app/lib/providers/day_view_provider.dart (or wherever TodayInteraction objects are constructed) to pass `status: bullet.status` and `completedAt: bullet.completedAt`

**Checkpoint**: `TodayInteraction` objects now carry completion state — US1 implementation can proceed.

---

## Phase 3: User Story 1 — Task Completion (Priority: P1) 🎯 MVP

**Goal**: Users can tap a completion control on task cards to toggle done/undone. State persists in the database and survives app restarts.

**Independent Test**: Log a task, tap the hollow circle icon, verify it shows a filled checkmark and text at reduced opacity. Restart the app and confirm the state is preserved.

- [x] T007 [US1] Add `completeTask(String id)` method to `BulletsDao` in app/lib/database/daos/bullets_dao.dart: sets `status = 'complete'` and `completedAt = now UTC ISO 8601` in a DB transaction, then calls `_enqueueBulletSyncFromRow(updated, 'update')` — mirror the `updateBulletStatus` pattern exactly
- [x] T008 [US1] Add `uncompleteTask(String id)` method to `BulletsDao` in app/lib/database/daos/bullets_dao.dart: sets `status = 'open'` and `completedAt = null` in a DB transaction, then enqueues sync — mirror `completeTask` pattern
- [x] T009 [US1] Add required `onComplete: void Function(String bulletId, bool complete)` callback to `TodayInteractionTimeline` in app/lib/widgets/today_timeline.dart; update `_buildEntry` so task entries show `Icons.radio_button_unchecked` (size 14, white54) when open and `Icons.check_circle_rounded` (size 14, white54) when `entry.status == 'complete'`; completed task content Text renders at `Colors.white38` instead of `Colors.white`; wire `onTap` on the leading icon to call `onComplete(entry.bulletId, entry.status != 'complete')`
- [x] T010 [US1] Add `_onToggleComplete(BuildContext context, String bulletId, bool complete)` to `DayViewScreen` in app/lib/screens/day_view/day_view_screen.dart: calls `BulletsDao(db).completeTask(bulletId)` when `complete == true`, `uncompleteTask(bulletId)` when false; handle error silently (no snackbar needed); wire `onComplete: (id, c) => _onToggleComplete(context, id, c)` in the `TodayInteractionTimeline` call site; also add `onComplete: (_,__) {}` noop in the error-state call site if one exists
- [x] T011 [US1] Update app/test/widgets/today_timeline_test.dart: add `onComplete: (_,__) {}` to all four `TodayInteractionTimeline` instantiations (lines that currently have `onTap: (_) {}, onDelete: (_) {}`)

**Checkpoint**: Tap a task card's leading icon → it toggles. Restart app → state preserved. All existing tests pass.

---

## Phase 4: User Story 2 — Remove TASK Label (Priority: P2)

**Goal**: The "TASK" text badge on the right side of task cards is gone. Task identity is conveyed only by the leading icon.

**Independent Test**: Log a task and a note. View the timeline. No text reading "TASK" appears on either card.

- [x] T012 [US2] In `_buildEntry` in app/lib/widgets/today_timeline.dart, remove the trailing `if (entry.type == 'task') ...[const SizedBox(width: 6), const Text('TASK', ...)]` block entirely — no replacement

**Checkpoint**: Timeline shows zero TASK labels. Task cards are still recognizable by the hollow checkbox leading icon.

---

## Phase 5: User Story 3 — Dynamic Card Height (Priority: P3)

**Goal**: Long notes and tasks display their full text without ellipsis. Cards grow vertically. Leading icons pin to the top.

**Independent Test**: Log a note with 5 lines of text. All 5 lines are visible. Swipe-to-delete still works on the full card.

- [x] T013 [US3] In `_buildEntry` in app/lib/widgets/today_timeline.dart, change the content `Text` widget: remove `overflow: TextOverflow.ellipsis` (and any `maxLines` if present); change the surrounding entry `Row`'s `crossAxisAlignment` from `CrossAxisAlignment.center` to `CrossAxisAlignment.start` so the leading icon, timestamp, and content top-align correctly on multi-line cards

**Checkpoint**: Multi-line entries show full content. Single-line entries are visually unchanged.

---

## Phase 6: User Story 4 — Simplified Composer (Priority: P4)

**Goal**: The composer's type toggle shows only "Note" or "Task" — no sublabel. The text field has a subtle rounded background that integrates with the card.

**Independent Test**: Open the composer. The type switch shows exactly one line of text. The text field has visible rounded corners that match the card.

- [x] T014 [US4] In `BulletCaptureBar` in app/lib/widgets/bullet_capture_bar.dart, find the `Column` inside the type-toggle `GestureDetector` that contains two `Text` children (label + sublabel); remove the second `Text` child (the one showing 'Context' / 'Follow-up'); simplify the `Column` to a single `Text('Note'/'Task', style: TextStyle(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w500))` — adjust font size/color to match the current first label's style
- [x] T015 [US4] In the `TextField` inside `BulletCaptureBar` in app/lib/widgets/bullet_capture_bar.dart, update `InputDecoration`: add `filled: true` and `fillColor: Colors.white.withValues(alpha: 0.05)`; replace `border: InputBorder.none`, `enabledBorder: InputBorder.none`, `focusedBorder: InputBorder.none` with `border: OutlineInputBorder(borderRadius: BorderRadius.circular(AntraRadius.card), borderSide: BorderSide.none)`, `enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AntraRadius.card), borderSide: BorderSide.none)`, `focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AntraRadius.card), borderSide: BorderSide.none)` — keep all other decoration properties unchanged

**Checkpoint**: Composer type toggle shows one label. Text field has a subtle rounded appearance in all states (empty, focused, multiline).

---

## Phase 7: User Story 5 — Tab Bar Redesign (Priority: P5)

**Goal**: The floating tab bar uses aurora palette colors and a subtle active state instead of Material 3 defaults.

**Independent Test**: View any tab. The bar background is dark (`AntraColors.auroraNavy`), active icon is white, inactive icons are `Colors.white38`, active container is a very faint white tint — no bright colored pill.

- [x] T016 [US5] In `_FloatingTabBar.build` in app/lib/screens/root_tab_screen.dart, replace the container `color` conditional (`brightness == Brightness.dark ? cs.surfaceContainerHigh : cs.surface`) with `AntraColors.auroraNavy`; add `border: Border.all(color: Colors.white.withValues(alpha: AntraColors.glassBorderOpacity), width: 0.5)` to the `BoxDecoration`; remove the `import` or usage of `Theme.of(context).colorScheme` in this widget if it becomes unused after T017
- [x] T017 [US5] In `_TabButton.build` in app/lib/screens/root_tab_screen.dart, replace the active container `color` (`cs.primaryContainer.withValues(alpha: 0.8)`) with `Colors.white.withValues(alpha: 0.10)`; replace the active icon `color` (`cs.primary`) with `Colors.white`; replace the inactive icon `color` (`cs.onSurfaceVariant.withValues(alpha: 0.55)`) with `Colors.white38`; remove the `final cs = Theme.of(context).colorScheme;` line if it is no longer referenced in this class

**Checkpoint**: Tab bar looks aurora-native. Navigation behavior is unchanged. Review badge still appears.

---

## Phase 8: Polish & Validation

**Purpose**: Verify all user stories work correctly together, no regressions.

- [x] T018 [P] Run `flutter test` from app/ directory and confirm all tests pass (0 failures)
- [x] T019 [P] Run `flutter analyze` from app/ directory and confirm no new issues introduced by this feature (pre-existing issues are acceptable)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Requires Phase 1 — BLOCKS US1 rendering
- **US1 (Phase 3)**: Requires Phase 2 (TodayInteraction model); modifies today_timeline.dart, bullets_dao.dart, day_view_screen.dart, today_timeline_test.dart
- **US2 (Phase 4)**: Requires US1 complete (same file: today_timeline.dart)
- **US3 (Phase 5)**: Requires US1 complete (same file: today_timeline.dart); can run concurrently with US2 if edits don't conflict (they touch different lines)
- **US4 (Phase 6)**: Independent of US1–US3 (different file: bullet_capture_bar.dart) — can start after Phase 2
- **US5 (Phase 7)**: Independent of US1–US4 (different file: root_tab_screen.dart) — can start after Phase 2
- **Polish (Phase 8)**: All phases complete

### Parallel Opportunities

- T004 and T005 (Setup reads) can run together
- T007 and T008 are in the same file (bullets_dao.dart) — sequential
- After Phase 2: US4 (T014–T015) and US5 (T016–T017) can run in parallel with US1–US3
- T018 and T019 (flutter test / flutter analyze) can run in parallel

---

## Implementation Strategy

### MVP (User Story 1 Only)

1. Complete Phase 1: Setup reads
2. Complete Phase 2: TodayInteraction model update
3. Complete Phase 3: Task completion (T007–T011)
4. **STOP and validate**: Log a task, tap to complete, restart app, confirm state preserved
5. All 103 existing tests still pass

### Full Delivery

1. Phase 1 + 2 (foundation)
2. Phase 3 (US1 — task completion)
3. Phase 4 (US2 — remove TASK label) — same file as US1, sequential
4. Phase 5 (US3 — dynamic height) — same file as US1, sequential
5. Phase 6 (US4 — composer cleanup) — independent, can overlap with US2/US3
6. Phase 7 (US5 — tab bar) — independent, can overlap with any
7. Phase 8 (tests + analyze)

---

## Notes

- No new packages — all changes use Flutter core + existing AntraColors/AntraRadius/AntraMotion tokens
- No DB migration — `completedAt` and `status` already exist on bullets table (schema v4)
- `onComplete` is a **breaking additive** change to TodayInteractionTimeline — all call sites must be updated in T010/T011
- US2, US3 both modify today_timeline.dart and must follow US1; they are sequential within the file
- Tab bar redesign removes dependency on `Theme.of(context).colorScheme` — verify no build warnings after T016/T017
