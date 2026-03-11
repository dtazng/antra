# Tasks: Person Detail View

**Input**: Design documents from `/specs/004-person-detail-view/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, contracts/ ✅, quickstart.md ✅

**Organization**: Tasks are grouped by user story to enable independent implementation and testing. Tests are **not** included (not requested in spec).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1–US5)
- Paths are relative to repository root

---

## Phase 1: Setup

**Purpose**: Verify starting state and prepare shared data classes needed by all user stories.

- [X] T001 Read `app/lib/database/tables/bullet_person_links.dart` and `app/lib/database/tables/bullets.dart` to confirm schema v3 baseline; verify `BulletPersonLinks` does NOT yet have `isPinned` column
- [X] T002 Create `app/lib/models/timeline_item.dart`: declare `sealed class TimelineItem {}`, `final class TimelineMonthHeader extends TimelineItem { final String label; TimelineMonthHeader(this.label); }`, `final class TimelineActivityRow extends TimelineItem { final Bullet bullet; TimelineActivityRow(this.bullet); }`; import `app/lib/database/app_database.dart`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Schema migration, DAO extension, and provider additions that every user story depends on.

**⚠️ CRITICAL**: Complete all of Phase 2 before any Phase 3+ work.

### 2a — Schema migration (v3 → v4)

- [X] T003 Add `isPinned` column to `BulletPersonLinks` table in `app/lib/database/tables/bullet_person_links.dart`: `IntColumn get isPinned => integer().withDefault(const Constant(0))();` with doc comment `/// 1 = pinned in this person's detail view. 0 = not pinned.`
- [X] T004 Bump `schemaVersion` from 3 to 4 in `app/lib/database/app_database.dart`; add `if (from < 4)` block in `MigrationStrategy.onUpgrade` containing: `await m.addColumn(bulletPersonLinks, bulletPersonLinks.isPinned);` and `await customStatement('CREATE INDEX IF NOT EXISTS idx_bpl_person_pinned ON bullet_person_links(person_id, is_pinned) WHERE is_deleted = 0;');`
- [X] T005 Run `cd app && dart run build_runner build --delete-conflicting-outputs` and confirm `.g.dart` files regenerate without errors; verify `BulletPersonLinksData` now has `isPinned` field

### 2b — DAO extension

- [X] T006 Add `InteractionSummary` class to `app/lib/database/daos/people_dao.dart` (before the DAO class): `class InteractionSummary { final int total; final int last30Days; final int last90Days; final Map<String, int> byType; const InteractionSummary({required this.total, required this.last30Days, required this.last90Days, required this.byType}); static const empty = InteractionSummary(total: 0, last30Days: 0, last90Days: 0, byType: {}); }`
- [X] T007 Add `getInteractionSummary(String personId) → Future<InteractionSummary>` to `PeopleDao` in `app/lib/database/daos/people_dao.dart`: uses `customSelect` with `COUNT(CASE WHEN ...)` for total, last30, last90, and per-type (note/task/event); computes cutoff30 and cutoff90 as `DateTime.now().subtract(Duration(days: N)).toUtc().toIso8601String()`; returns `InteractionSummary.empty` if no rows; see data-model.md §"Interaction Summary Query" for the exact SQL
- [X] T008 Add `getRecentBulletsForPerson(String personId, {int limit = 10}) → Future<List<Bullet>>` to `PeopleDao` in `app/lib/database/daos/people_dao.dart`: raw `customSelect` joining `bullet_person_links` and `bullets` filtered by both `is_deleted = 0`, `ORDER BY b.created_at DESC LIMIT :limit`; see data-model.md §"Recent Bullets for Person"
- [X] T009 Add `getBulletsForPersonPaged(String personId, {String? typeFilter, required int limit, required int offset}) → Future<List<Bullet>>` to `PeopleDao` in `app/lib/database/daos/people_dao.dart`: same join pattern as T008 but adds `AND b.type = :typeFilter` when typeFilter is non-null, and `LIMIT :limit OFFSET :offset`; see data-model.md §"Paginated Timeline for Person"
- [X] T010 Add `getPinnedBulletsForPerson(String personId) → Future<List<Bullet>>` to `PeopleDao` in `app/lib/database/daos/people_dao.dart`: join `bullet_person_links` and `bullets`, filter `bpl.is_pinned = 1`, `bpl.is_deleted = 0`, `b.is_deleted = 0`, `b.type = 'note'`, `ORDER BY bpl.created_at ASC`; see data-model.md §"Pinned Bullets for Person"
- [X] T011 Add `setPinned(String bulletId, String personId, {required bool pinned}) → Future<void>` to `PeopleDao` in `app/lib/database/daos/people_dao.dart`: `(update(bulletPersonLinks)..where((t) => t.bulletId.equals(bulletId) & t.personId.equals(personId))).write(BulletPersonLinksCompanion(isPinned: Value(pinned ? 1 : 0)));`; then enqueue sync for the updated link row (consistent with existing `_enqueueSync` pattern)

### 2c — Providers

- [X] T012 Add `interactionSummaryProvider(String personId) → Future<InteractionSummary>` to `app/lib/providers/people_provider.dart`: `@riverpod Future<InteractionSummary> interactionSummary(InteractionSummaryRef ref, String personId) async { final db = await ref.watch(appDatabaseProvider.future); return PeopleDao(db).getInteractionSummary(personId); }`
- [X] T013 Add `recentBulletsForPersonProvider(String personId) → Future<List<Bullet>>` to `app/lib/providers/people_provider.dart`: delegates to `PeopleDao(db).getRecentBulletsForPerson(personId)`; not a stream (re-fetched via `ref.invalidate` after link mutations)
- [X] T014 Add `pinnedBulletsForPersonProvider(String personId) → Future<List<Bullet>>` to `app/lib/providers/people_provider.dart`: delegates to `PeopleDao(db).getPinnedBulletsForPerson(personId)`
- [X] T015 Add `PersonTimelineState` data class and `PersonTimelineNotifier` to `app/lib/providers/people_provider.dart`: `PersonTimelineState` holds `List<TimelineItem> items`, `bool hasMore`, `bool isLoadingMore`, `String? typeFilter`; `PersonTimeline` notifier (`@riverpod class PersonTimeline extends _$PersonTimeline`) takes `String personId`; `build()` loads first page (offset 0, limit 20) and groups into `TimelineItem` list with `TimelineMonthHeader` inserted when month-year changes; `setTypeFilter(String? filter)` resets to page 0; `loadNextPage()` is a no-op when `isLoadingMore = true`, appends new items, sets `hasMore = false` when page returns < 20 rows; use `DateFormat('MMMM y').format(dt)` from `intl` package for month headers; import `app/lib/models/timeline_item.dart`
- [X] T016 Run `cd app && dart run build_runner build --delete-conflicting-outputs` to regenerate `.g.dart` for all new providers; confirm zero analysis errors on new provider code

**Checkpoint**: Foundation ready. App still runs, people list still works, people profile still opens (profile body not yet redesigned — that's Phase 3+).

---

## Phase 3: User Story 1 — At-a-Glance Relationship Overview (Priority: P1) 🎯 MVP

**Goal**: Opening a person's profile shows structured sections (header with identity, relationship summary stats, recent activity preview ≤10 entries) rather than an infinite log. The screen is useful even without Phase 4–7.

**Independent Test**: Open a person with 50+ interactions. Confirm: summary stats card shows total/30d/90d counts; Recent Activity shows ≤10 rows; "View All Activity" link is visible; screen loads without jank.

- [X] T017 [US1] Rewrite `_ProfileBody` in `app/lib/screens/people/person_profile_screen.dart` to replace the existing `CustomScrollView` body with a new section-based layout: keep `_ProfileBodyState` as `ConsumerStatefulWidget`; replace single long `SliverToBoxAdapter` column with individual `SliverToBoxAdapter` children for each section, in order: `_HeaderSection`, `_QuickActionsBar`, `_RelationshipSummaryCard`, `_RecentActivitySection`, `_PinnedNotesSection`, `_InsightsSection`, `_DeleteButton`
- [X] T018 [US1] Implement `_HeaderSection` widget (private) in `app/lib/screens/people/person_profile_screen.dart`: `CircleAvatar` radius 32 with initial; `titleLarge` name; `[role] · [company]` subtitle if either non-null; `_LastInteractionLabel(person: p)` (move existing widget usage here); `PersonStatusBadge(person: p)` (existing widget, shown in header area)
- [X] T019 [US1] Implement `_RelationshipSummaryCard` widget (private) in `app/lib/screens/people/person_profile_screen.dart`: watches `interactionSummaryProvider(p.id)` via `ref.watch`; renders a `Container` with `surfaceContainerHighest.withValues(alpha: 0.5)` background, 12px border radius, 12px padding; `Row` of three `_StatChip` widgets showing "N total", "N · 30d", "N · 90d"; below the row, if `summary.byType` has ≥ 2 non-zero type entries, add a `Wrap` of smaller type chips; show `CircularProgressIndicator` while loading, "No interactions yet" centered when `total = 0`
- [X] T020 [US1] Implement `_RecentActivitySection` widget (private) in `app/lib/screens/people/person_profile_screen.dart`: watches `recentBulletsForPersonProvider(p.id)`; section header row: "Recent Activity" (`titleSmall`) + "View All →" `TextButton` right-aligned (navigation wired in T035); shows 5 rows initially; `_showMoreCount` local state (`StatefulWidget`) toggles to 10 when "Show more" tapped; each row is a `_ActivityRow` private widget showing type icon (16px), 1-line content ellipsis (14px), relative date (12px, right side); `InkWell` tap navigates to `BulletDetailScreen` or `TaskDetailScreen` per `bullet.type`; empty state: `Icons.link_off_outlined` + "No interactions linked yet"

**Checkpoint**: US1 functional. Person profile shows summary card and recent activity instead of the old full log.

---

## Phase 4: User Story 2 — Quick Action Bar (Priority: P1)

**Goal**: Four quick action buttons (Log, Note, Follow-up, Edit) are permanently visible on the person profile. Users can log a new interaction in ≤3 taps.

**Independent Test**: From a person's profile, tap each of the 4 quick actions. Confirm: Log opens `LogInteractionSheet` pre-attached to person; Note opens it with type pre-set to 'note'; Follow-up opens the follow-up picker; Edit opens `EditPersonSheet`.

- [X] T021 [P] [US2] Create `app/lib/widgets/log_interaction_sheet.dart`: `ConsumerStatefulWidget` with constructor params `{required String personId, required String personName, String initialType = 'note', bool pinOnSave = false}`; UI: drag handle, non-interactive person badge chip, type selector row (FilterChips: Note / Event / Task), `TextField` (multiline, autofocus, hint "What happened? Add a note…"), `FilledButton` "Save"; Save behavior: validate non-empty; get or create today's `DayLog` (call `BulletsDao` or `DayLogsDao` — use existing `insertBullet` pattern from `BulletsDao`); insert `Bullet` with type/content/dayId/position; call `PeopleDao.insertLink(bullet.id, personId, linkType: 'manual')`; if `pinOnSave`: call `PeopleDao.setPinned(bullet.id, personId, pinned: true)`; invalidate `recentBulletsForPersonProvider(personId)` and `interactionSummaryProvider(personId)`; `Navigator.pop(context, bullet)`
- [X] T022 [US2] Implement `_QuickActionsBar` widget (private) in `app/lib/screens/people/person_profile_screen.dart`: a `Row` of 4 evenly-spaced `_QuickActionButton` columns (Icon + label Text below); Log (`Icons.add_circle_outline`) → `showModalBottomSheet(builder: (_) => LogInteractionSheet(personId: p.id, personName: p.name))`; Note (`Icons.sticky_note_2_outlined`) → `LogInteractionSheet(personId: p.id, personName: p.name, initialType: 'note')`; Follow-up (`Icons.flag_outlined`) → show existing `_FollowUpSection` as a standalone bottom sheet or trigger scroll to the follow-up section; Edit (`Icons.edit_outlined`) → `showModalBottomSheet(builder: (_) => EditPersonSheet(person: p))`; import `app/lib/widgets/log_interaction_sheet.dart`

**Checkpoint**: US2 functional. All 4 quick actions open the correct sheets from the profile.

---

## Phase 5: User Story 3 — Full Activity Timeline (Priority: P2)

**Goal**: A dedicated `PersonFullTimelineScreen` shows paginated history grouped by month with type filters. Accessed via "View All Activity" from the profile.

**Independent Test**: Open full timeline for a person with 60+ interactions. Confirm: month headers present; "Notes" filter leaves only note rows; scroll past first 20 → next 20 load automatically; empty filter state shown when no matching type.

- [X] T023 [US3] Create `app/lib/screens/people/person_full_timeline_screen.dart`: `ConsumerStatefulWidget` with `final PeopleData person` constructor param; `ScrollController _scrollController` initialized in `initState`, disposed in `dispose`; adds listener that calls `notifier.loadNextPage()` when `_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300`; watches `personTimelineProvider(person.id)` for `PersonTimelineState`
- [X] T024 [US3] Implement the `AppBar` in `person_full_timeline_screen.dart`: title `"${person.name}'s Activity"`; no actions in AppBar (filter chips are in sticky header below)
- [X] T025 [US3] Implement the filter chip bar in `person_full_timeline_screen.dart`: `SliverPersistentHeader(pinned: true)` containing a `Row` of 4 `FilterChip` or `ChoiceChip` widgets: All / Notes / Tasks / Events; tapping calls `ref.read(personTimelineProvider(person.id).notifier).setTypeFilter(type)`; selected chip shows filled background
- [X] T026 [US3] Implement the timeline `SliverList` in `person_full_timeline_screen.dart`: for each `TimelineItem` in `state.items`: if `TimelineMonthHeader` → render a left-aligned `Text` with `titleSmall` style in a `Padding(EdgeInsets.fromLTRB(16, 20, 16, 6))`; if `TimelineActivityRow` → render `_ActivityRow` (reuse/share the widget defined in `person_profile_screen.dart` or extract to a shared file); `InkWell` tap navigates per `bullet.type`
- [X] T027 [US3] Implement load-more indicator and end-of-list footer in `person_full_timeline_screen.dart`: `SliverToBoxAdapter` at the bottom showing: `CircularProgressIndicator` when `state.isLoadingMore = true`; "All interactions loaded" `Text` when `state.hasMore = false` and `items.isNotEmpty`; empty states: when `state.items.isEmpty && !state.isLoadingMore` and no filter → `Icons.history_toggle_off` + "No interactions yet"; when empty with active filter → `Icons.filter_list_off` + "No [type] logged yet" + "Clear filter" `TextButton`
- [X] T028 [US3] Wire "View All →" `TextButton` in `_RecentActivitySection` (in `person_profile_screen.dart`) to push `PersonFullTimelineScreen(person: p)` via `Navigator.of(context).push(MaterialPageRoute(builder: (_) => PersonFullTimelineScreen(person: p)))`; add import for `person_full_timeline_screen.dart`

**Checkpoint**: US3 functional. Full timeline opens from profile, paginates, and filters correctly.

---

## Phase 6: User Story 4 — Pinned Notes / Key Facts (Priority: P2)

**Goal**: Notes can be pinned to the top of the person's profile. Pinned notes persist above the activity section and can be unpinned via long-press.

**Independent Test**: Log a note, long-press → pin → profile shows it in Pinned section. Reopen profile → still pinned. Long-press → unpin → Pinned section hidden.

- [X] T029 [US4] Implement `_PinnedNotesSection` widget (private) in `app/lib/screens/people/person_profile_screen.dart`: watches `pinnedBulletsForPersonProvider(p.id)`; returns `SizedBox.shrink()` when list is empty (section hidden); when non-empty: section header row with "Pinned" (`titleSmall`) + `IconButton(Icons.push_pin_outlined)` that opens `LogInteractionSheet(personId: p.id, personName: p.name, initialType: 'note', pinOnSave: true)`; below: a `Column` of `_PinnedNoteCard` widgets, one per bullet
- [X] T030 [US4] Implement `_PinnedNoteCard` widget (private) in `app/lib/screens/people/person_profile_screen.dart`: `StatefulWidget` with `bool _expanded = false`; shows `Text(bullet.content, maxLines: _expanded ? null : 3, overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis)`; if content exceeds 3 lines (use `LayoutBuilder` + `TextPainter` or simply always show "Show more" toggle), show `TextButton('Show more'/'Show less')` that toggles `_expanded`; `InkWell` long-press opens a bottom sheet with two options: "Unpin" (calls `PeopleDao(db).setPinned(bullet.id, p.id, pinned: false)` then `ref.invalidate(pinnedBulletsForPersonProvider(p.id))`) and "Open entry" (navigates to `BulletDetailScreen(bulletId: bullet.id)`)

**Checkpoint**: US4 functional. Pins and unpins work; profile hides Pinned section when empty.

---

## Phase 7: User Story 5 — Relationship Insights (Priority: P3)

**Goal**: A passive, non-intrusive insights section appears when the relationship is stale, a follow-up is overdue, or a follow-up is upcoming. Hidden when no condition applies.

**Independent Test**: Set cadence = 7d, `lastInteractionAt` = 10d ago → stale warning shown. Set future follow-up date → countdown shown. Clear all → section hidden.

- [X] T031 [US5] Implement `_InsightsSection` widget (private) in `app/lib/screens/people/person_profile_screen.dart`: pure computation from `PeopleData p` — no provider needed; compute `daysSinceLast` from `p.lastInteractionAt`; priority order: (1) overdue follow-up (`needsFollowUp=1` AND `followUpDate` parses to past date) → `cs.errorContainer` background, "Follow-up overdue — due [date]"; (2) upcoming follow-up (`needsFollowUp=1` AND `followUpDate` parses to future date) → `cs.tertiaryContainer`, "Follow up due in N days"; (3) needs follow-up, no date → `cs.tertiaryContainer`, "Marked as needs follow-up"; (4) stale by cadence (`p.reminderCadenceDays != null` AND `daysSinceLast > p.reminderCadenceDays`) → `cs.surfaceContainerHighest`, "Last contact [N] days ago — consider reaching out"; returns `SizedBox.shrink()` when none apply; use `Padding(padding: EdgeInsets.only(bottom: 12))` wrapping a `Container` with 10px border radius, 12px padding, icon (small) + text

**Checkpoint**: US5 functional. Insights section appears and disappears correctly based on person state.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Navigation wiring, invalidation correctness, deprecation cleanup, and final analysis.

- [X] T032 [P] Verify `ref.invalidate` chains are complete after all mutations: after `LogInteractionSheet` saves → `recentBulletsForPersonProvider` and `interactionSummaryProvider` are invalidated; after `setPinned` → `pinnedBulletsForPersonProvider` is invalidated; after `EditPersonSheet` saves → `singlePersonProvider` stream auto-updates (no manual invalidate needed); after `setFollowUp` → `singlePersonProvider` stream auto-updates
- [X] T033 [P] Check if `bulletsForPersonProvider` (the old all-bullets stream from `people_provider.dart`) is still used anywhere other than `PersonProfileScreen`; if used only in the profile (now replaced by `recentBulletsForPersonProvider`), remove it; if used elsewhere, leave it but add a TODO comment noting it should not be used in the profile
- [X] T034 [P] Extract `_ActivityRow` widget to a shared location if it is duplicated between `person_profile_screen.dart` and `person_full_timeline_screen.dart`; either pass it as a private widget from a shared import or keep it private to each file (duplication acceptable if the two versions diverge slightly — do not prematurely abstract)
- [X] T035 Run `flutter analyze app/` and fix all warnings and infos in files touched by this feature: `bullet_person_links.dart`, `app_database.dart`, `people_dao.dart`, `people_provider.dart`, `timeline_item.dart`, `person_profile_screen.dart`, `person_full_timeline_screen.dart`, `log_interaction_sheet.dart`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies — start immediately
- **Phase 2 (Foundational)**: Depends on Phase 1 — BLOCKS all user story phases
- **Phase 3 (US1)**: Depends on Phase 2 complete — can start after T016 (providers)
- **Phase 4 (US2)**: Depends on Phase 2 complete and T021 (`LogInteractionSheet`) — can run in parallel with Phase 3 (different files)
- **Phase 5 (US3)**: Depends on Phase 2 complete (T015 `PersonTimelineNotifier`) and Phase 3 T020 (for `_ActivityRow` reuse) — start after Phase 3
- **Phase 6 (US4)**: Depends on Phase 2 complete (T011 `setPinned`, T014 `pinnedBulletsForPersonProvider`) and Phase 4 T021 (`LogInteractionSheet` with `pinOnSave`) — start after Phase 4
- **Phase 7 (US5)**: Depends on Phase 3 T017 (profile body structure) — can add `_InsightsSection` slot after T017
- **Phase 8 (Polish)**: Depends on all desired phases complete

### User Story Dependencies

- **US1 (P1)**: Immediately after Phase 2 — no inter-story dependencies
- **US2 (P1)**: Immediately after Phase 2 — `LogInteractionSheet` (T021) is an independent new file; `_QuickActionsBar` (T022) slots into the profile body structure from T017
- **US3 (P2)**: After Phase 2 + Phase 3 T020 (needs `_ActivityRow` pattern established)
- **US4 (P2)**: After Phase 2 + Phase 4 T021 (`LogInteractionSheet` with `pinOnSave`)
- **US5 (P3)**: After Phase 3 T017 (needs the profile body section slot)

### Within Each User Story

- DAO methods before providers that call them
- Providers before widgets that watch them
- New widgets (`LogInteractionSheet`) before widgets that open them (`_QuickActionsBar`)

### Parallel Opportunities

Within Phase 2:

- T003 (BulletPersonLinks column) is independent of T006–T011 (DAO methods) in terms of code, but build_runner must run after T003 before T005 confirms success
- T012–T015 (providers) can be written simultaneously (same file, different methods — sequential within file)

Within Phase 4:

- T021 (`LogInteractionSheet`) and T017–T020 (profile sections) are in different files — parallel

---

## Parallel Example: Phase 4 (US2)

```text
# T021 and Phase 3 US1 tasks can run in parallel (different files):
T021 — app/lib/widgets/log_interaction_sheet.dart   (new file)
T017 — app/lib/screens/people/person_profile_screen.dart (profile body)

# T022 depends on T021 existing:
T022 — _QuickActionsBar (same file as T017–T020)
```

---

## Implementation Strategy

### MVP First (US1 + US2 Only)

1. Complete Phase 1: Setup (T001–T002)
2. Complete Phase 2: Foundational (T003–T016)
3. Complete Phase 3: US1 — structured overview (T017–T020)
4. Complete Phase 4: US2 — quick actions (T021–T022)
5. **STOP and VALIDATE**: Profile shows summary card, recent activity, quick actions all work
6. Continue with US3–US5 in priority order

### Incremental Delivery

1. Phase 2 complete → foundation ready, app still functional
2. Phase 3 (US1) → summary-first profile replaces old log view
3. Phase 4 (US2) → quick logging from profile works
4. Phase 5 (US3) → full timeline with pagination and filters
5. Phase 6 (US4) → pinned notes
6. Phase 7 (US5) → relationship insights
7. Phase 8 → polish and final verification

---

## Task Count Summary

| Phase | Tasks | Notes |
| ----- | ----- | ----- |
| Phase 1: Setup | 2 | T001–T002 |
| Phase 2: Foundational | 14 | T003–T016 |
| Phase 3: US1 (P1) | 4 | T017–T020 |
| Phase 4: US2 (P1) | 2 | T021–T022 |
| Phase 5: US3 (P2) | 6 | T023–T028 |
| Phase 6: US4 (P2) | 2 | T029–T030 |
| Phase 7: US5 (P3) | 1 | T031 |
| Phase 8: Polish | 4 | T032–T035 |
| **Total** | **35** | |

---

## Notes

- [P] tasks = different files, no dependencies between them
- [Story] label maps each task to its user story for independent testing and delivery
- Build runner must be run after T003+T004 (schema) and after T015 (providers) — these are checkpoints, not optional
- `_ActivityRow` is defined in Phase 3 (US1) and reused in Phase 5 (US3); extraction decision deferred to T034
- `LogInteractionSheet` requires access to `DayLogsDao` or an equivalent method to get/create today's day log — use the same pattern already present in `BulletCaptureBar` or `daily_log_screen.dart`
