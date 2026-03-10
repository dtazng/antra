# Tasks: Personal CRM

**Input**: Design documents from `/specs/003-personal-crm/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, contracts/ ✅, quickstart.md ✅

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story. Tests are **not** included (not explicitly requested in spec).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1–US5)
- Paths are relative to repository root

---

## Phase 1: Setup

**Purpose**: Verify the starting point and prepare the augmentation branch.

- [X] T001 Verify schema v2 tables exist in `app/lib/database/tables/people.dart` and `app/lib/database/tables/bullet_person_links.dart` (read both files; confirm current columns match data-model.md baseline)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Schema migration, DAO extension, and provider additions that every user story depends on. No user story work can begin until this phase is complete.

**⚠️ CRITICAL**: Complete this phase before any Phase 3+ tasks.

### 2a — Schema changes

- [X] T002 Add 10 new nullable columns to `People` table in `app/lib/database/tables/people.dart`: `company`, `role`, `email`, `phone`, `birthday`, `location`, `tags`, `relationshipType`, `needsFollowUp` (IntColumn default 0), `followUpDate` — using drift column DSL as documented in data-model.md §"Dart Model Mapping"
- [X] T003 Add `linkType` column (TextColumn, default `'mention'`) to `BulletPersonLinks` table in `app/lib/database/tables/bullet_person_links.dart`
- [X] T004 Bump `schemaVersion` from 2 to 3 and add `if (from < 3)` migration block to `MigrationStrategy.onUpgrade` in `app/lib/database/app_database.dart` — include all `m.addColumn` calls, FTS5 rebuild, trigger replacements, and new index from data-model.md §"Migration Script (v2 → v3)"
- [X] T005 Run `cd app && dart run build_runner build --delete-conflicting-outputs` and confirm `.g.dart` files regenerate without errors for `app_database.g.dart`, `people_dao.g.dart`, and `bullet_person_links.dart`-related generated code

### 2b — DAO extension

- [X] T006 Add `watchPersonById(String id) → Stream<PeopleData?>` to `app/lib/database/daos/people_dao.dart` using `select(people)..where(t.id.equals(id) & t.isDeleted.equals(0)).watchSingleOrNull()`
- [X] T007 Add `searchPeople(String query) → Future<List<PeopleData>>` to `app/lib/database/daos/people_dao.dart` using FTS5 `customRawQuery` on `people_fts` with appended `*` for prefix matching; empty query returns all non-deleted people ordered by `lastInteractionAt DESC`
- [X] T008 Add `findSimilarPeople(String name) → Future<List<PeopleData>>` to `app/lib/database/daos/people_dao.dart` combining exact `getPersonByName` result + `LIKE '%fragment%'` on first name token; returns up to 5 non-deleted matches
- [X] T009 Add `watchPeopleSorted(PeopleSort sort, {bool needsFollowUpOnly}) → Stream<List<PeopleData>>` to `app/lib/database/daos/people_dao.dart` — three sort orderings via `OrderingTerm`; optional `WHERE needs_follow_up = 1`; always excludes `is_deleted = 1`
- [X] T010 Add `PeopleSort` enum (`lastInteraction`, `nameAZ`, `recentlyCreated`) to `app/lib/database/daos/people_dao.dart` (or a new `app/lib/models/people_sort.dart` file if preferred for import clarity)
- [X] T011 Update `insertLink` signature in `app/lib/database/daos/people_dao.dart` to accept `{String linkType = 'mention'}` and pass it to `BulletPersonLinksCompanion`; within the same transaction clear `needsFollowUp = 0` on the person record (FR-026)
- [X] T012 Add `removeLink(String bulletId, String personId) → Future<void>` to `app/lib/database/daos/people_dao.dart` — soft-deletes the specific (bulletId, personId) row and enqueues a delete sync for it
- [X] T013 Add `softDeleteLinksForPerson(String personId) → Future<void>` to `app/lib/database/daos/people_dao.dart` — soft-deletes all `bullet_person_links` where `person_id = personId`; call this inside `softDeletePerson` transaction after setting `isDeleted = 1` on the person
- [X] T014 Update `softDeletePerson` in `app/lib/database/daos/people_dao.dart` to call `softDeleteLinksForPerson(id)` within the same transaction (FR-004)
- [X] T015 Add `getLinkedPersonForBullet(String bulletId) → Future<PeopleData?>` to `app/lib/database/daos/people_dao.dart` — joins `bullet_person_links` and `people`, filters `isDeleted = 0` on both, returns first result or null
- [X] T016 Add `setFollowUp(String personId, {required bool needs, String? followUpDate}) → Future<void>` to `app/lib/database/daos/people_dao.dart` — writes `needsFollowUp` (1 or 0) and `followUpDate` (value or null); enqueues update sync
- [X] T017 Update `_enqueuePersonSync` and `_enqueuePersonSyncFromRow` in `app/lib/database/daos/people_dao.dart` to include all 10 new People fields in the JSON payload
- [X] T018 Update `_enqueueSync` call in `insertLink` to include `linkType` in the payload map

### 2c — Providers

- [X] T019 Add `peopleSortedProvider(PeopleSort sort, {bool needsFollowUpOnly})` stream provider to `app/lib/providers/people_provider.dart` using `@riverpod` code-gen and `PeopleDao.watchPeopleSorted`
- [X] T020 Add `singlePersonProvider(String personId)` stream provider to `app/lib/providers/people_provider.dart` delegating to `PeopleDao.watchPersonById`
- [X] T021 Add `linkedPersonForBulletProvider(String bulletId)` future provider to `app/lib/providers/people_provider.dart` delegating to `PeopleDao.getLinkedPersonForBullet`
- [X] T022 Add `PeopleScreenState` data class and `PeopleScreenNotifier` `@riverpod` notifier to `app/lib/providers/people_provider.dart` with state fields: `sort` (default `lastInteraction`), `searchQuery` (default `''`), `relationshipType` (nullable), `tag` (nullable), `needsFollowUpOnly` (default false); expose `setSort`, `setSearchQuery`, `setRelationshipTypeFilter`, `setTagFilter`, `setNeedsFollowUpOnly`, `clearFilters` methods
- [X] T023 Run `cd app && dart run build_runner build --delete-conflicting-outputs` to regenerate `.g.dart` for all new providers; confirm zero analysis errors

**Checkpoint**: Foundation ready — launch app on simulator, confirm it migrates from v2 to v3 without crash, people list still shows existing data.

---

## Phase 3: User Story 1 — Create a Person and Link a Log Entry (Priority: P1) 🎯 MVP

**Goal**: A user can type `@Alice` in the capture bar to find or create Alice and have the log entry automatically linked to her. They can also manually attach a person from any log detail view.

**Independent Test**: Type `@Alice` in capture bar with no existing Alice → "Create 'Alice'" row appears → tap it → `CreatePersonSheet` opens pre-filled with "Alice" → save → bullet saved and linked to Alice → open Alice's profile and confirm the bullet appears in her timeline.

- [X] T024 [P] [US1] Add `initialName` parameter to `CreatePersonSheet` in `app/lib/screens/people/create_person_sheet.dart`; pre-fill `_nameController.text = widget.initialName ?? ''`; change `showModalBottomSheet` caller to `showModalBottomSheet<PeopleData?>` and `Navigator.pop(context, createdPerson)` on success so callers receive the newly created `PeopleData`
- [X] T025 [US1] Update `_BulletCaptureBarState` in `app/lib/widgets/bullet_capture_bar.dart`: when `_suggestions` is empty AND `_currentMention.isNotEmpty`, append a synthetic "Create '[name]'" row to the suggestions overlay list (rendered distinctly with a `+` icon and italic text); tapping it opens `CreatePersonSheet(initialName: _currentMention)` via `showModalBottomSheet<PeopleData?>`; on non-null return call `_selectSuggestion(newPerson)` to insert `@${newPerson.name}` into the text field and proceed
- [X] T026 [US1] Create `PersonPickerSheet` widget in `app/lib/screens/people/person_picker_sheet.dart`: `ConsumerStatefulWidget` with a search `TextField` (autofocus), live-filtered `ListView` of people from `allPeopleProvider` (filtered Dart-side by `name.toLowerCase().contains(query)`), each row is a `ListTile` with avatar + name; tapping a row calls `Navigator.pop(context, person)`; bottom of list has "➕ Create new person" tile that opens `CreatePersonSheet` and pops with its result
- [X] T027 [P] [US1] Add linked person section to `BulletDetailScreen` in `app/lib/screens/daily_log/bullet_detail_screen.dart`: watch `linkedPersonForBulletProvider(bulletId)` and render: (a) if null → ghost chip "Link person" with person icon; (b) if linked → filled chip with avatar initial + name (tapping chip navigates to `PersonProfileScreen`; long-press shows popover/bottom sheet with "Remove link" → calls `PeopleDao.removeLink` + `ref.invalidate(linkedPersonForBulletProvider(bulletId))` and "Change person" → opens `PersonPickerSheet`); "Link person" chip tap opens `PersonPickerSheet`, on return calls `PeopleDao.insertLink(bulletId, person.id, linkType: 'manual')` + `ref.invalidate`
- [X] T028 [P] [US1] Add linked person section to `TaskDetailScreen` in `app/lib/screens/daily_log/task_detail_screen.dart` using the same `linkedPersonForBulletProvider` + `PersonPickerSheet` pattern as T027; place the section in the info card row alongside status and scheduled date

**Checkpoint**: US1 fully functional. Full @mention flow and manual link/unlink working end-to-end.

---

## Phase 4: User Story 2 — View a Person's Full Interaction History (Priority: P2)

**Goal**: Opening a person's profile shows their full reverse-chronological interaction timeline, tappable through to the correct detail screen, with a clear empty state.

**Independent Test**: Link 5 bullets of different types (task, note, event) to one person, open their profile, verify all 5 appear newest-first, tap each to confirm navigation to the correct detail screen.

- [X] T029 [US2] Update `PersonProfileScreen` in `app/lib/screens/people/person_profile_screen.dart` to use `singlePersonProvider(widget.person.id)` instead of the `_person` local state copy — watch the stream so all fields reactively update when edits are made elsewhere; handle `null` case (person deleted) by popping the screen
- [X] T030 [US2] Update the bullet timeline in `PersonProfileScreen` `SliverList` to pass `onTap` to `BulletListItem` for each bullet: `bullet.type == 'task'` → navigate to `TaskDetailScreen(bulletId: bullet.id)`; `bullet.type == 'note'` or `'event'` → navigate to `BulletDetailScreen(bulletId: bullet.id)` (mirrors the routing already in `daily_log_screen.dart`)
- [X] T031 [US2] Add a proper empty state to the timeline section in `PersonProfileScreen`: when `bulletList.isEmpty`, show a centered column with an icon (`Icons.link_off_outlined`) and two-line message "No interactions yet" / "Link a log entry to see it here"
- [X] T032 [US2] Add type icon + date + content preview to each bullet row in `PersonProfileScreen` timeline: replace bare `BulletListItem` with a custom `_TimelineRow` private widget inside the screen file that shows type icon (task/note/event) in a small circle, formatted date (`DateFormat('MMM d')`), and truncated content (2-line `overflow: TextOverflow.ellipsis`), and task status chip if `type == 'task'`

**Checkpoint**: US2 functional. Person profile shows complete reactive timeline with correct navigation.

---

## Phase 5: User Story 3 — Browse and Search the People List (Priority: P2)

**Goal**: The People screen supports real-time text search by name/company, sort by last interaction / name / created, and filter by relationship type, tags, and follow-up status.

**Independent Test**: Add 10 people with varied names and companies. Type a partial name in the search bar and confirm the list filters in real-time. Switch sort to "Name A–Z" and confirm alphabetical order. Filter by follow-up and confirm only flagged people show.

- [X] T033 [US3] Create `PersonStatusBadge` widget in `app/lib/widgets/person_status_badge.dart`: `StatelessWidget` accepting a `PeopleData person`; implements display logic from `contracts/ui-screens.md §"Stale / Follow-up indicator widget"` — red badge for overdue follow-up, amber badge for pending follow-up (with or without date), grey stale badge when `lastInteractionAt` is > 30 days ago, no widget when none apply
- [X] T034 [US3] Update `PeopleScreen` in `app/lib/screens/people/people_screen.dart`: replace `allPeopleProvider` with `peopleScreenNotifierProvider` (for state) + `peopleSortedProvider` (for sorted SQL data); add a `TextField` search bar below the `AppBar` (inside the body, pinned above the list); on text change call `ref.read(peopleScreenNotifierProvider.notifier).setSearchQuery(query)` debounced 200ms
- [X] T035 [US3] Add Dart-side filtering to `PeopleScreen`: after receiving the sorted list from `peopleSortedProvider`, apply three optional Dart filters from `PeopleScreenState`: (1) `searchQuery` — keep people where `name.toLowerCase().contains(q)` or `(company ?? '').toLowerCase().contains(q)`; (2) `tag` — keep people where `(tags ?? '').split(',').contains(tag)`; (3) `relationshipType` — keep people where `relationshipType == type`; render filtered empty state "No matches for '[query]'" when result is empty
- [X] T036 [US3] Add sort bottom sheet to `PeopleScreen`: `IconButton` (sort icon) in `AppBar` opens a `showModalBottomSheet` with three `ListTile` options ("Last interaction", "Name A–Z", "Recently created"); tapping one calls `notifier.setSort(sort)` and pops; currently selected option shows a checkmark
- [X] T037 [US3] Add filter chip row to `PeopleScreen` between search bar and list: chips for "Needs follow-up" (toggle), relationship type (dropdown chip), and tag (dropdown chip from unique tags across all people); active chips show filled/tinted; tapping clears filter; uses `PeopleScreenNotifier` methods
- [X] T038 [US3] Update `_PersonTile` in `app/lib/screens/people/people_screen.dart`: add `PersonStatusBadge(person)` below the subtitle row; replace `withOpacity` calls with `withValues(alpha:)`; add `company` subtitle line (show `company` if non-null, otherwise keep "No interactions yet" / relative date logic)

**Checkpoint**: US3 functional. Full search, sort, filter, and stale/follow-up badges working in people list.

---

## Phase 6: User Story 4 — Create and Edit a Person Profile (Priority: P2)

**Goal**: Users can create a person with name only (fast path), get warned about duplicates, and later edit any profile field from the person's detail screen.

**Independent Test**: Create "Alice Ng" with name only — succeeds immediately. Attempt to create another "Alice Ng" — duplicate warning appears. Edit the first Alice to add company "Acme" and tag "work" — changes reflect immediately on profile and list.

- [X] T039 [US4] Update `CreatePersonSheet` in `app/lib/screens/people/create_person_sheet.dart`: call `PeopleDao.findSimilarPeople(name)` before saving; if results exist, show an inline warning card below the name field listing matches with name + company; add "Use existing" button per match (navigates to `PersonProfileScreen`) and "Create anyway" button to proceed; skip duplicate check if `initialName` was pre-filled and user is arriving from the @mention flow (pass `skipDuplicateCheck: false` optional param)
- [X] T040 [US4] Create `EditPersonSheet` in `app/lib/screens/people/edit_person_sheet.dart`: `ConsumerStatefulWidget` accepting `PeopleData person`; full-field editor with `TextField` for name (required), company, role, email, phone, location; `DatePicker` for birthday; segmented control or `DropdownButton` for relationship type (Friend / Family / Colleague / Mentor / Acquaintance / Other / clear); chip tag editor (text field input → add chip on submit, ✕ per chip to remove, max 20, de-duplicated); multiline `TextField` for notes; save button calls `PeopleDao.updatePerson(companion)` with all fields; validates name non-empty
- [X] T041 [US4] Add edit `IconButton` in `PersonProfileScreen` `AppBar` in `app/lib/screens/people/person_profile_screen.dart` that opens `EditPersonSheet(person: currentPerson)` via `showModalBottomSheet` (isScrollControlled: true); after sheet closes, the `singlePersonProvider` stream update automatically refreshes the UI (no manual setState needed)
- [X] T042 [US4] Add "Delete person" destructive action to `PersonProfileScreen`: `TextButton` or `OutlinedButton` at bottom of profile body with red/error color; tapping shows a confirmation bottom sheet with "Delete [name]?" message and "Delete" / "Cancel" buttons; confirming calls `PeopleDao.softDeletePerson(id)` and then `Navigator.of(context).pop()` to return to people list

**Checkpoint**: US4 functional. Create with duplicate check, full field editing, and delete all work.

---

## Phase 7: User Story 5 — Follow-up Reminders and Stale Relationship Surfacing (Priority: P3)

**Goal**: Users can mark a person as "needs follow-up" or set a specific follow-up date. The people list shows stale and overdue indicators passively. When a new log is linked, the follow-up flag clears automatically.

**Independent Test**: Mark Alice as "needs follow-up" → her row shows a follow-up badge. Link a new bullet to Alice → open her profile and confirm `needsFollowUp = 0` (badge gone). Set a specific follow-up date in the past → confirm "Overdue" red badge appears in the list.

- [X] T043 [US5] Add follow-up section to `PersonProfileScreen` in `app/lib/screens/people/person_profile_screen.dart`: below the context notes and above the timeline, add a row showing follow-up state per `contracts/ui-screens.md §"PersonProfileScreen — Follow-up section behavior"`; "Mark as needs follow-up" button calls `PeopleDao.setFollowUp(id, needs: true)`; "Set date" opens `showDatePicker` and calls `setFollowUp(id, needs: true, followUpDate: 'YYYY-MM-DD')`; "Clear" button calls `setFollowUp(id, needs: false)`
- [X] T044 [US5] Verify that `insertLink` in `app/lib/database/daos/people_dao.dart` correctly clears `needsFollowUp = 0` within its transaction (implemented in T011) — confirm by reading the updated person record after `insertLink` and checking the flag is 0
- [X] T045 [US5] Verify `PersonStatusBadge` widget (implemented in T033) correctly surfaces overdue follow-up (red), pending follow-up with date (amber + date), needs-follow-up without date (amber), and stale (grey); confirm the 30-day threshold is computed with `DateTime.now().difference(dt).inDays > 30`

**Checkpoint**: US5 functional. Follow-up toggle, date picker, auto-clear on link, and stale indicator all working.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: API consistency, deprecation fixes, and final validation against quickstart.md test scenarios.

- [X] T046 [P] Replace all remaining `withOpacity(...)` calls with `withValues(alpha: ...)` and `onSurfaceVariant` → `surfaceContainerHighest` deprecation fixes in `app/lib/screens/people/people_screen.dart` and `app/lib/screens/people/person_profile_screen.dart`
- [X] T047 [P] Replace `withOpacity` calls in `app/lib/screens/people/create_person_sheet.dart` and any new files created in this feature if applicable
- [X] T048 Run `flutter analyze app/` and fix all warnings/infos in files touched by this feature
- [ ] T049 Walk through all acceptance scenarios from `specs/003-personal-crm/quickstart.md §"Testing focus areas"` manually on iOS simulator; mark each scenario as verified or create a follow-up bug note

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies — start immediately
- **Phase 2 (Foundational)**: Depends on Phase 1 — BLOCKS all user story phases
- **Phase 3 (US1)**: Depends on Phase 2 complete — can start immediately after checkpoint
- **Phase 4 (US2)**: Depends on Phase 2 complete — can run in parallel with Phase 3
- **Phase 5 (US3)**: Depends on Phase 2 complete — can run in parallel with Phase 3 and 4
- **Phase 6 (US4)**: Depends on Phase 2 complete; lightly depends on Phase 3 (CreatePersonSheet reused) — start after Phase 3 T024 is done
- **Phase 7 (US5)**: Depends on Phase 2 complete (setFollowUp DAO) and Phase 4 (PersonProfileScreen UI)
- **Phase 8 (Polish)**: Depends on all desired phases complete

### User Story Dependencies

- **US1 (P1)**: Can start immediately after Phase 2 — no dependency on other stories
- **US2 (P2)**: Can start after Phase 2 — singlePersonProvider (T020) and timeline tap routing (T030) are independent of US1
- **US3 (P2)**: Can start after Phase 2 — peopleSortedProvider (T019) and PeopleScreenNotifier (T022) are independent
- **US4 (P2)**: Can start after Phase 2 T024 (CreatePersonSheet initialName param) is done
- **US5 (P3)**: Can start after Phase 2 (T016 setFollowUp DAO) and Phase 4 (PersonProfileScreen reactive)

### Within Each User Story

- Schema (Phase 2a) before DAO (Phase 2b) before Providers (Phase 2c)
- DAO methods before the providers that call them
- Providers before the widgets that watch them
- Core widget before integrations (e.g., PersonPickerSheet before using it in BulletDetailScreen)

### Parallel Opportunities

Within Phase 2:
- T002 and T003 (People + BulletPersonLinks column additions) are independent — can run in parallel
- T006 through T015 (DAO methods) are all additions to the same file — sequential within the file, but T006–T010 (read-only methods) can conceptually be written simultaneously

Within Phase 3:
- T024 (CreatePersonSheet initialName) and T025 (CaptureBar create row) are different files — parallel
- T027 (BulletDetailScreen linked person) and T028 (TaskDetailScreen linked person) are different files — parallel

Within Phase 5 (US3):
- T033 (PersonStatusBadge widget) and T034–T035 (PeopleScreen search) are different files — parallel

---

## Parallel Example: Phase 3 (US1)

```text
# These can be worked on simultaneously (different files):
T024 — app/lib/screens/people/create_person_sheet.dart
T025 — app/lib/widgets/bullet_capture_bar.dart
T026 — app/lib/screens/people/person_picker_sheet.dart (new file)

# Then in parallel after T026 exists:
T027 — app/lib/screens/daily_log/bullet_detail_screen.dart
T028 — app/lib/screens/daily_log/task_detail_screen.dart
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001)
2. Complete Phase 2: Foundational (T002–T023) — build_runner after T005 and T023
3. Complete Phase 3: US1 (T024–T028)
4. **STOP and VALIDATE**: Full @mention → create → link → profile timeline flow working
5. Continue with US2–US5 in priority order

### Incremental Delivery

1. Phase 2 complete → foundation works, people list still functional
2. Phase 3 (US1) → @mention and manual linking working
3. Phase 4 (US2) → person profile timeline complete
4. Phase 5 (US3) → search/sort/filter in people list
5. Phase 6 (US4) → duplicate check + full profile editing
6. Phase 7 (US5) → follow-up surfacing
7. Phase 8 → polish and final verification

---

## Task Count Summary

| Phase | Tasks | Notes |
|-------|-------|-------|
| Phase 1: Setup | 1 | T001 |
| Phase 2: Foundational | 22 | T002–T023 |
| Phase 3: US1 (P1) | 5 | T024–T028 |
| Phase 4: US2 (P2) | 4 | T029–T032 |
| Phase 5: US3 (P2) | 6 | T033–T038 |
| Phase 6: US4 (P2) | 4 | T039–T042 |
| Phase 7: US5 (P3) | 3 | T043–T045 |
| Phase 8: Polish | 4 | T046–T049 |
| **Total** | **49** | |

---

## Notes

- All `[P]` tasks touch different files and have no incomplete task dependencies within their phase
- `[Story]` labels map directly to User Stories 1–5 in `spec.md`
- Run `dart run build_runner build --delete-conflicting-outputs` after T005 and T023 — these are the two points where generated code must be regenerated before continuing
- Soft-delete is used everywhere — never `DELETE FROM`
- `linkType = 'mention'` from capture bar; `linkType = 'manual'` from log detail picker
- `tags` is comma-separated string — strip and rejoin on edit; never store leading/trailing commas
