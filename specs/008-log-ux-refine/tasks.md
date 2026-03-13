# Tasks: Log UX Refinement

**Input**: Design documents from `/specs/008-log-ux-refine/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, contracts/widget-contracts.md ✅, quickstart.md ✅

**Tests**: Not explicitly requested — test tasks are omitted per template policy.

**Organization**: Tasks are grouped by user story (P1 → P5) to enable independent implementation and delivery.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (touches different files, no blocking dependency)
- **[Story]**: Which user story this task belongs to

---

## Phase 1: Setup

**Purpose**: Read and understand the files to be modified before making changes.

- [x] T001 Read `app/lib/widgets/glass_surface.dart` (source of truth for `GlassSurface` API and `_GlassProps`)
- [x] T002 [P] Read `app/lib/widgets/bullet_capture_bar.dart` (full current state of composer widget)
- [x] T003 [P] Read `app/lib/widgets/today_timeline.dart` (full current state of timeline widget)
- [x] T004 [P] Read `app/lib/screens/people/person_picker_sheet.dart` (full current state of picker)
- [x] T005 [P] Read `app/lib/database/daos/bullets_dao.dart` lines containing `softDeleteBullet` and surrounding context

---

## Phase 2: Foundational (Blocking Prerequisite)

**Purpose**: The `GlassSurface` `borderRadius` override is used by US1 (composer corners), and `undoSoftDeleteBullet` is used by US5 (swipe-to-delete). Both are foundational utilities consumed by downstream stories. Complete these before any user story work.

**⚠️ CRITICAL**: US1 depends on T006; US5 depends on T007.

- [ ] T006 Add optional `borderRadius` parameter to `GlassSurface` in `app/lib/widgets/glass_surface.dart`: add `final BorderRadius? borderRadius;` field to the widget, update `_GlassSurfaceState.build()` to use `widget.borderRadius ?? props.borderRadius` in both `Container` decoration and `ClipRRect`
- [ ] T007 Add `undoSoftDeleteBullet(String id)` method to `BulletsDao` in `app/lib/database/daos/bullets_dao.dart`: write `UPDATE bullets SET is_deleted = 0, updated_at = <now ISO-8601 UTC> WHERE id = ?` using drift `update(bullets)..where(...)` with `BulletsCompanion(isDeleted: const Value(0), updatedAt: Value(now))`

**Checkpoint**: `GlassSurface` accepts `borderRadius` override; `BulletsDao` has `undoSoftDeleteBullet`. US1 and US5 can now proceed.

---

## Phase 3: User Story 1 — Fix Input Card Corners (Priority: P1) 🎯 MVP

**Goal**: The `BulletCaptureBar` composer card has uniformly rounded corners (all four) in all states — idle, focused, keyboard open, multi-line expanded.

**Independent Test**: Open Day View. The `GlassSurface.bar` currently only rounds top corners. After this change, all four corners of the composer card are rounded to `AntraRadius.card` (20px). Verify visually in idle and keyboard-open state.

### Implementation

- [ ] T008 [US1] In `app/lib/widgets/bullet_capture_bar.dart`, change the `GlassSurface` wrapping the composer body: pass `borderRadius: BorderRadius.circular(AntraRadius.card)` — this overrides the `GlassStyle.bar` default that only rounds top corners. Keep `style: GlassStyle.bar` for blur/tint/elevation settings.

**Checkpoint**: Composer card shows 4 rounded corners in all states. US1 complete.

---

## Phase 4: User Story 2 — Task vs Note Visual Distinction (Priority: P2)

**Goal**: Timeline entries are visually differentiated by type. Notes show a small circle; tasks show a hollow checkbox outline and a "TASK" text label.

**Independent Test**: Log a note and a task. In the Day View timeline, the note row has a `•` dot; the task row has a `☐` icon and a muted "TASK" label on the right. No need to tap — distinction is visible at a glance.

### Implementation

- [ ] T009 [US2] In `app/lib/widgets/today_timeline.dart`, update `_buildEntry` leading icon logic: replace the current `if (entry.personId != null) PersonIdentityAccent ... else Icon(type == 'task' ? check_box_outline_blank : radio_button_unchecked)` with: when `entry.personId != null` keep `PersonIdentityAccent`; when `entry.personId == null` and `entry.type == 'task'` use `Icon(Icons.check_box_outline_blank_rounded, size: 12, color: Colors.white54)`; otherwise use `Icon(Icons.circle, size: 6, color: Colors.white38)`.
- [ ] T010 [US2] In `app/lib/widgets/today_timeline.dart`, in the `_buildEntry` row `children` list, after the `Expanded(child: Text(entry.content ...))`, add a conditional `if (entry.type == 'task') Text('TASK', style: TextStyle(fontSize: 10, color: Colors.white38, letterSpacing: 0.8, fontWeight: FontWeight.w600))`. Ensure this appears after content and before the optional `personName` suffix. Adjust spacing as needed with a `SizedBox(width: 6)` before the TASK label.

**Checkpoint**: Notes and tasks are visually distinct in the timeline without tapping. US2 complete.

---

## Phase 5: User Story 3 — Improved Type Switch with Labels (Priority: P3)

**Goal**: The type toggle in `BulletCaptureBar` shows a label ("Note" or "Task") and a brief subtitle ("Context" or "Follow-up") so the user knows which mode is active and what it means.

**Independent Test**: Open composer. The leftmost control shows "Note" (13pt) above "Context" (10pt muted). Tap it — it switches to "Task" above "Follow-up". Tap again — returns to Note. Logging in each mode saves with the correct `type` value.

### Implementation

- [ ] T011 [US3] In `app/lib/widgets/bullet_capture_bar.dart`, replace the type toggle `GestureDetector` child (currently a single `Padding + Icon`) with a `Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w500)), Text(subtitle, style: TextStyle(fontSize: 10, color: Colors.white38))])` where `label = _selectedType == 'note' ? 'Note' : 'Task'` and `subtitle = _selectedType == 'note' ? 'Context' : 'Follow-up'`. Adjust the outer `Padding` to `const EdgeInsets.symmetric(horizontal: 10, vertical: 6)` to keep vertical rhythm. Keep `_toggleType()` as the `onTap` handler.

**Checkpoint**: Type toggle shows labeled mode with subtitle. Task and note are distinguishable before submitting. US3 complete.

---

## Phase 6: User Story 4 — Link Multiple People to One Log Entry (Priority: P4)

**Goal**: A single log entry can be linked to multiple people. Linked people appear as removable chips in the composer. The people picker supports multi-select. On save, all linked people are stored. The entry appears in each person's detail timeline.

**Independent Test**: Open composer, tap `@` button, select two people, tap Done. Two chips appear. Type content, submit. Navigate to each linked person's detail view — the entry appears in both timelines.

### Implementation

- [ ] T012 [P] [US4] In `app/lib/screens/people/person_picker_sheet.dart`, convert from single-select to multi-select: (a) add `final List<PeopleData> alreadyLinked` constructor param (default `const []`); (b) add `List<PeopleData> _selected` state initialized from `widget.alreadyLinked`; (c) each person `ListTile` gets a `trailing: _selected.any((p) => p.id == person.id) ? const Icon(Icons.check_rounded, color: Colors.white70) : null` and `onTap` toggles presence in `_selected`; (d) add a "Done" `TextButton` right-aligned in the header area that calls `Navigator.of(context).pop(_selected)`; (e) change the `'Create new person'` row so after creation the new person is added to `_selected` and sheet stays open; (f) update `Navigator.pop` calls for drag-dismiss to pop `widget.alreadyLinked` (no changes).
- [ ] T013 [US4] In `app/lib/widgets/bullet_capture_bar.dart`, change `PeopleData? _linkedPerson` to `List<PeopleData> _linkedPeople = []`. Update `_pickPerson()`: open `PersonPickerSheet(alreadyLinked: _linkedPeople)`, receive `List<PeopleData>?` result, merge into `_linkedPeople` deduplicating by id. Update `_selectSuggestion(PeopleData person)` to add person to `_linkedPeople` if not already present (check by id) instead of setting `_linkedPerson`. Update `_removeLinkedPerson` to remove by id: `setState(() => _linkedPeople.removeWhere((p) => p.id == person.id))`. Update the chip display area to use a `Wrap(spacing: 6, children: _linkedPeople.map((p) => _buildPersonChip(p)).toList())` replacing the current single-chip row. Update `_submit()`: loop `for (final p in _linkedPeople)` calling `peopleDao.insertLink(id, p.id, linkType: 'mention')` instead of the single `_linkedPerson` check; keep @mention extraction loop but skip IDs already in `_linkedPeople`; clear with `setState(() => _linkedPeople = [])` after save.
- [ ] T014 [US4] In `app/lib/widgets/bullet_capture_bar.dart`, implement `_buildPersonChip(PeopleData person)` as a private helper method returning a `Row(mainAxisSize: MainAxisSize.min, children: [PersonAvatar(personId: person.id, displayName: person.name, radius: 10), SizedBox(width: 4), Text(person.name, style: TextStyle(fontSize: 12, color: Colors.white70)), SizedBox(width: 2), GestureDetector(onTap: () => _removeLinkedPerson(person), child: Icon(Icons.close, size: 12, color: Colors.white38))])` wrapped in a `Container` with subtle glass styling (`color: Colors.white.withValues(alpha: 0.08)`, `borderRadius: BorderRadius.circular(20)`, `padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4)`). Replace the existing single-person chip `Padding` block with `if (_linkedPeople.isNotEmpty) Padding(padding: const EdgeInsets.only(left: 4, bottom: 4), child: Wrap(spacing: 6, runSpacing: 4, children: _linkedPeople.map(_buildPersonChip).toList()))`.
- [ ] T015 [US4] Update `_removeLinkedPerson` signature in `app/lib/widgets/bullet_capture_bar.dart` to accept `PeopleData person` parameter (was no parameter or `_linkedPerson = null`): `void _removeLinkedPerson(PeopleData person) => setState(() => _linkedPeople.removeWhere((p) => p.id == person.id))`.

**Checkpoint**: Multiple people can be linked to one entry. Entry appears in each person's timeline. US4 complete.

---

## Phase 7: User Story 5 — Swipe-to-Delete with Undo (Priority: P5)

**Goal**: Swiping a timeline entry left removes it with a 4-second undo opportunity. Uses soft delete (is_deleted = 1); undo reverses to is_deleted = 0.

**Independent Test**: Swipe any timeline entry left past threshold → entry disappears → "Entry deleted · Undo" snackbar appears → tap Undo within 4s → entry reappears. Let it expire → entry is permanently removed.

### Implementation

- [ ] T016 [P] [US5] In `app/lib/widgets/today_timeline.dart`, add `required this.onDelete` to the `TodayInteractionTimeline` public constructor: `final void Function(String bulletId) onDelete`. In `_buildEntry`, wrap the returned `SlideTransition + FadeTransition` widget in a `Dismissible(key: ValueKey(entry.bulletId), direction: DismissDirection.endToStart, background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), color: Colors.red.shade800, child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 20)), onDismissed: (_) => widget.onDelete(entry.bulletId), child: ...)`. Note: the `AnimatedList` item builder receives the widget via `_buildEntry`; the `Dismissible` must be the outermost widget returned from `_buildEntry` so the `AnimatedList` can track it. Also update `didUpdateWidget` to handle list shrinks from deletions (already handled by the `else` branch that refreshes `_items`).
- [ ] T017 [US5] In `app/lib/screens/day_view/day_view_screen.dart`, implement the `onDelete` handler: create a method `void _onDeleteEntry(BuildContext context, String bulletId)` that: (1) reads `appDatabaseProvider` via `ref.read(...).whenData(...)` or `ref.read(...).value` to get the db; (2) calls `BulletsDao(db).softDeleteBullet(bulletId)`; (3) calls `ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Entry deleted'), action: SnackBarAction(label: 'Undo', onPressed: () async { final db = await ref.read(appDatabaseProvider.future); await BulletsDao(db).undoSoftDeleteBullet(bulletId); }), duration: const Duration(seconds: 4)))`. Wire `onDelete: (id) => _onDeleteEntry(context, id)` into the `TodayInteractionTimeline` call in the screen's build method.

**Checkpoint**: Swipe-to-delete with 4-second undo works for both notes and tasks. US5 complete.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Verify all stories integrate cleanly; fix any visual edge cases surfaced during implementation.

- [ ] T018 Verify `today_timeline_test.dart` still passes with the new `onDelete` required parameter — update existing test instantiations to include `onDelete: (_) {}` stub in `app/test/widgets/today_timeline_test.dart`
- [ ] T019 [P] Verify `day_view_screen_test.dart` still passes — confirm the `TodayInteractionTimeline` mock in the test still builds; add `onDelete: (_) {}` if needed in `app/test/widgets/day_view_screen_test.dart`
- [ ] T020 [P] Run `flutter test` in `app/` and fix any compilation or assertion failures introduced by the `PersonPickerSheet` return type change or `_linkedPeople` refactor
- [ ] T021 [P] Run `flutter analyze` in `app/` and resolve any warnings or deprecated API usages introduced by this feature

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies — read-only, start immediately; all 5 reads can run in parallel
- **Phase 2 (Foundational)**: Depends on Phase 1 reads. T006 and T007 can run in parallel (different files). BLOCKS US1 (needs T006) and US5 (needs T007).
- **Phase 3 (US1)**: Depends on T006 (borderRadius in GlassSurface). No other story dependency.
- **Phase 4 (US2)**: Depends only on Phase 1 reads of `today_timeline.dart`. Independent of US1.
- **Phase 5 (US3)**: Depends only on Phase 1 reads of `bullet_capture_bar.dart`. Independent of US1 and US2.
- **Phase 6 (US4)**: Depends on Phase 1 reads of `bullet_capture_bar.dart` and `person_picker_sheet.dart`. T012 (picker) and T013–T015 (capture bar) are sequentially ordered within the phase but T012 can start in parallel with T013 (different files).
- **Phase 7 (US5)**: Depends on T007 (undoSoftDeleteBullet DAO). T016 (timeline widget) and T017 (screen handler) can run in parallel.
- **Phase 8 (Polish)**: Depends on all story phases complete.

### User Story Dependencies

- **US1 (P1)**: Depends on T006 only — immediately executable after Phase 2
- **US2 (P2)**: Depends only on Phase 1 reads — independently executable; touches only `today_timeline.dart`
- **US3 (P3)**: Depends only on Phase 1 reads — independently executable; touches only `bullet_capture_bar.dart` toggle area
- **US4 (P4)**: Depends on Phase 1 reads — touches `person_picker_sheet.dart` and `bullet_capture_bar.dart`; T013–T015 depend on T012 logically (same file edit sequence)
- **US5 (P5)**: Depends on T007 — T016 (`today_timeline.dart`) and T017 (`day_view_screen.dart`) are independent files

### Parallel Opportunities

```text
Phase 1:  T001 ║ T002 ║ T003 ║ T004 ║ T005  (all reads in parallel)
Phase 2:  T006 ║ T007                         (different files)
Phase 3+: T008 ║ T009 ║ T011 ║ T012          (different files, after prereqs)
          T010 (after T009, same file)
          T013 → T014 → T015 (same file, sequential)
          T016 ║ T017 (different files, both need T007)
Phase 8:  T018 ║ T019 ║ T020 ║ T021          (all in parallel)
```

---

## Implementation Strategy

### MVP: US1 + US2 (Corner Fix + Task/Note Distinction)

1. Complete Phase 1 (reads)
2. Complete T006 (borderRadius — needed for US1)
3. T008 (US1 corner fix) — one-line change in `BulletCaptureBar`
4. T009 + T010 (US2 timeline indicators and TASK label)
5. **STOP and VALIDATE**: Composer has 4 rounded corners; notes and tasks look different in feed
6. Ship MVP — two visible improvements, zero API changes, zero risk

### Incremental Delivery

1. MVP (US1 + US2) → Corner fix + type distinction visible
2. US3 → Type toggle labeled (low risk, one widget change)
3. US4 → Multi-person linking (larger change; coordinate picker + capture bar)
4. US5 → Swipe-to-delete with undo (Dismissible + snackbar)
5. Phase 8 polish → test fixes, analyze clean

---

## Notes

- `[P]` tasks touch different files and have no blocking dependency on each other
- `[Story]` label maps each task to its user story for traceability
- No new packages, no DB migrations — all changes are widget-level or single DAO method
- `PersonPickerSheet` return type change from `PeopleData?` to `List<PeopleData>` is the highest-impact API change; the only caller is `BulletCaptureBar._pickPerson()`
- `TodayInteractionTimeline.onDelete` is a new required parameter; all existing test instantiations must add `onDelete: (_) {}` stub
- `undoSoftDeleteBullet` is safe to add at any time — it's purely additive
