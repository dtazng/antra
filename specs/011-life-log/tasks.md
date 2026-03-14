# Tasks: Life Log & Follow-Up System

**Input**: Design documents from `/specs/011-life-log/`
**Prerequisites**: plan.md ✅ spec.md ✅ research.md ✅ data-model.md ✅ contracts/ ✅ quickstart.md ✅

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: Which user story this task belongs to (US1–US7)
- Exact file paths included in all task descriptions

---

## Phase 1: Setup (Read Existing Files)

**Purpose**: Load current state of all files touched by this feature before making any changes.

- [X] T001 Read app/lib/database/tables/bullets.dart (full file) to understand all current columns, especially `type` values and `canceledAt` position — new columns are added immediately after `canceledAt`
- [X] T002 Read app/lib/database/app_database.dart (full file) to understand schemaVersion (currently 4), migration getter structure, and `@DriftDatabase` tables list — needed before bumping to version 5
- [X] T003 [P] Read app/lib/database/daos/bullets_dao.dart (full file) to understand all existing methods, especially `insertBullet()`, `getOrCreateDayLog()`, `watchAllBulletsForDay()`, and the `_enqueueBulletSync()` helper before adding new DAO methods
- [X] T004 [P] Read app/lib/widgets/bullet_capture_bar.dart (full file) to locate the exact submit/save method that calls `getOrCreateDayLog(today)` and determine how `dayId` is resolved and passed to `insertBullet()`
- [X] T005 [P] Read app/lib/screens/root_tab_screen.dart (full file) to understand the current 5-tab `_screens`/`_tabs` setup, `_FloatingTabBar` constructor, `_TabButton` Badge usage, and `weeklyReviewTasksProvider` watch
- [X] T006 [P] Read app/lib/screens/people/person_detail_screen.dart (full file) to understand the current flat list structure — the list widget, data provider used, and bullet card rendering — before redesigning in US6

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Schema migration and new model files that MUST land before any user story work begins. All user story work in bullets_dao.dart and the timeline depends on these.

**⚠️ CRITICAL**: US1–US7 cannot be implemented until T007–T012 are complete.

- [X] T007 In app/lib/database/tables/bullets.dart, add 5 new nullable column declarations immediately after the existing `canceledAt` column: `TextColumn get followUpDate => text().nullable()();`, `TextColumn get followUpStatus => text().nullable()();`, `TextColumn get followUpSnoozedUntil => text().nullable()();`, `TextColumn get followUpCompletedAt => text().nullable()();`, `TextColumn get sourceId => text().nullable()();` — add a doc comment on each matching data-model.md definitions
- [X] T008 In app/lib/database/app_database.dart: (1) increment `schemaVersion` from 4 to 5; (2) add a migration step from version 4 to 5 in the `migration` getter (using `MigrationStrategy`) that executes exactly these 5 statements via `customStatement()`: `ALTER TABLE bullets ADD COLUMN follow_up_date TEXT`, `ALTER TABLE bullets ADD COLUMN follow_up_status TEXT`, `ALTER TABLE bullets ADD COLUMN follow_up_snoozed_until TEXT`, `ALTER TABLE bullets ADD COLUMN follow_up_completed_at TEXT`, `ALTER TABLE bullets ADD COLUMN source_id TEXT` — follow the existing migration step pattern already in the file
- [X] T009 Run `dart run build_runner build --delete-conflicting-outputs` from the `app/` directory to regenerate drift-generated code for the new bullets columns; confirm zero errors
- [X] T010 Create app/lib/models/timeline_entry.dart containing: (1) `sealed class TimelineEntry { const TimelineEntry(); }` with no concrete fields; (2) `class LogEntryItem extends TimelineEntry` with `const` constructor and fields: `bulletId`, `content`, `createdAt` (DateTime), `personId`?, `personName`?, `followUpDate`? (String ISO date), `followUpStatus`? (String); (3) `class CompletionEventItem extends TimelineEntry` with fields: `bulletId`, `content`, `createdAt` (DateTime), `sourceId`, `personId`?, `personName`?; (4) `class TimelineDay` (NOT a TimelineEntry subclass) with fields: `label` (String — Today/Yesterday/MMM d), `date` (DateTime, midnight local), `entries` (List<TimelineEntry>, newest first)
- [X] T011 [P] Create app/lib/models/needs_attention_item.dart containing `class NeedsAttentionItem` with a `const` constructor and fields: `bulletId` (String), `content` (String — original log entry text shown as context), `followUpDate` (String ISO date YYYY-MM-DD), `followUpStatus` (String — always 'pending' in this view), `personId`? (String), `personName`? (String) — all final

**Checkpoint**: Run `flutter analyze` from app/ — must pass with zero errors before user story work begins.

---

## Phase 3: User Story 1 — Log an Entry (Priority: P1) 🎯 MVP

**Goal**: A user can type into a fixed bottom capture bar and save a log entry instantly. The entry appears in a basic timeline list.

**Independent Test**: Open the app, type "Coffee with Anna" into the bottom capture bar, press submit, confirm the entry appears in the timeline list under "Today" within 500 ms. No day_logs lookup should block the save path.

- [X] T012 [US1] In app/lib/database/daos/bullets_dao.dart, add `Future<void> insertBulletForDate(BulletsCompanion companion)` that: (1) derives `dayId` as `companion.createdAt.value.substring(0, 10)` (the ISO date string, e.g., `'2026-03-13'`) instead of a day_logs UUID; (2) calls the existing `insertBullet(companion.copyWith(dayId: Value(dateStr)))` internally — this removes the blocking `getOrCreateDayLog` async call from the capture critical path; also add a private helper `static String _dateStr(String isoTimestamp) => isoTimestamp.substring(0, 10)`
- [X] T013 [US1] Create app/lib/screens/timeline/timeline_screen.dart as a `ConsumerStatefulWidget`: (1) in `build()`, render a `Stack` with a `SafeArea`-padded `CustomScrollView` body and `BulletCaptureBar` `Positioned(bottom:0, left:0, right:0)`; (2) as a temporary US1 data source, watch `todayInteractionsProvider(_todayStr())` (already exists in day_view_provider.dart) to show today's entries in a flat `SliverList` using glass card style (outer Padding vertical:4, GlassSurface padding: EdgeInsets.symmetric(horizontal:12, vertical:10)); (3) show `_EmptyState(icon: Icons.edit_outlined, message: 'Nothing logged yet.\nStart by writing your first entry.')` when the list is empty — the `_EmptyState` widget can be a private class identical in structure to the one in day_view_screen.dart
- [X] T014 [US1] In app/lib/widgets/bullet_capture_bar.dart, locate the submit method (the one that calls `getOrCreateDayLog(today)` then `insertBullet()`) and replace the `getOrCreateDayLog` call: instead of resolving a day_logs UUID, call the new `dao.insertBulletForDate(companion)` directly — where `companion` is constructed with `dayId: Value(_dateStr(now))` using the same date-string helper; confirm that person-link creation (`_createPersonLinks`) still fires after `insertBulletForDate` completes, as it uses `bulletId` not `dayId`

**Checkpoint**: App launches. Typing in the capture bar and pressing submit creates an entry visible in the timeline under "Today". No existing tests should fail.

---

## Phase 4: User Story 2 — Infinite Timeline (Priority: P2)

**Goal**: Full infinite-scroll timeline with sticky date separators grouping all entries across all days.

**Independent Test**: With entries logged on multiple days, open the Timeline tab. Entries appear grouped by date with sticky "Today", "Yesterday", and "Mar N" headers. Scrolling past a day boundary updates the sticky header.

- [X] T015 [US2] In app/lib/database/daos/bullets_dao.dart, add `Stream<List<Bullet>> watchTimelineEntries()` that selects all non-deleted bullets ordered by `createdAt` DESC: `(select(bullets)..where((t) => t.isDeleted.equals(0))..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).watch()`
- [X] T016 [US2] Create app/lib/providers/timeline_provider.dart with `@riverpod Stream<List<TimelineDay>> timelineEntries(TimelineEntriesRef ref)` that: (1) awaits `appDatabaseProvider.future`; (2) watches `BulletsDao(db).watchTimelineEntries()`; (3) for each bullet in each emission, calls `PeopleDao(db).getLinkedPersonForBullet(bullet.id)` to get optional personName; (4) maps each bullet to `LogEntryItem` (type != 'completion_event') or `CompletionEventItem` (type == 'completion_event'); (5) groups the sorted list into `List<TimelineDay>` using a private `_groupByDate(List<TimelineEntry> entries)` function that compares `entry.createdAt.toLocal()` date and computes the label: `'Today'` if same calendar day as now, `'Yesterday'` if one day before, `DateFormat('MMM d').format(date)` otherwise (using `intl` package already imported)
- [X] T017 [US2] Run `dart run build_runner build --delete-conflicting-outputs` from app/ to generate app/lib/providers/timeline_provider.g.dart; confirm zero errors
- [X] T018 [US2] Update app/lib/screens/timeline/timeline_screen.dart to use the full infinite timeline: (1) replace the temporary `todayInteractionsProvider` watch with `ref.watch(timelineEntriesProvider)`; (2) add private `_StickyDateHeaderDelegate` class implementing `SliverPersistentHeaderDelegate` with `minExtent = maxExtent = 36.0`, building `Container(color: Theme.of(context).scaffoldBackgroundColor, child: Padding(padding: EdgeInsets.symmetric(horizontal:16, vertical:10), child: Text(label, style: TextStyle(fontSize:11, color:Colors.white38, fontWeight:FontWeight.w500, letterSpacing:0.4))))`; (3) replace the flat `SliverList` with a loop over `timelineDays` that emits two slivers per day: `SliverPersistentHeader(pinned:true, delegate: _StickyDateHeaderDelegate(day.label))` then `SliverList(delegate: SliverChildBuilderDelegate((ctx, i) => _buildEntryCard(day.entries[i]), childCount: day.entries.length))`; (4) keep the empty state check: show `_EmptyState` only when `timelineDays.isEmpty`

**Checkpoint**: Timeline shows all entries across all days with sticky date headers. Scrolling past a day boundary correctly pins the new day's header.

---

## Phase 5: User Story 3 — Person Linking (Priority: P3)

**Goal**: Timeline entry cards show the linked person name. @mention autocomplete still works. Entries linked to a person are visible on that person's detail when the person timeline is redesigned in US6.

**Independent Test**: Log "Coffee with @Anna" via the capture bar. Confirm the entry appears in the timeline with "Anna" shown as a sub-line below the content. Navigate to Anna in the People tab — confirm the entry appears in her detail view (US6 completes this validation).

- [X] T019 [US3] In app/lib/screens/timeline/timeline_screen.dart, implement `_buildEntryCard(TimelineEntry entry)`: for a `LogEntryItem`, render a `GestureDetector(onTap: () => _onTap(entry.bulletId), child: Padding(vertical:4, child: GlassSurface(borderOpacityOverride: AntraColors.chipGlassBorderOpacity, padding: EdgeInsets.symmetric(horizontal:12, vertical:10), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [leadingIcon, SizedBox(8), Expanded(child: Column(crossAxisAlignment: start, children: [Text.rich(_buildContentSpan(entry.content)), if (entry.personName != null) Text(entry.personName!, style: TextStyle(fontSize:11, color:Colors.white38))])), SizedBox(8), Text(_timeFmt.format(entry.createdAt), style: TextStyle(fontSize:11, color:Colors.white30))]))))` — add `static final _mentionRegex = RegExp(r'(@\w+)')` and `_buildContentSpan(String content)` method (identical to today_timeline.dart's implementation); for a `CompletionEventItem`, use a checkmark leading icon and `Colors.white54` text color
- [X] T020 [US3] In app/lib/providers/timeline_provider.dart, confirm the `getLinkedPersonForBullet` call is present for every bullet entry (added in T016) — if not already included, add it; add a comment: `// person lookup: O(n) queries acceptable at typical timeline scale (<500 entries)`

**Checkpoint**: Timeline cards show "@mention" text with subtle bold styling. Person name appears as a secondary line when a bullet is linked to a person.

---

## Phase 6: User Story 4 — Follow-Up Attachment (Priority: P4)

**Goal**: A user can attach a follow-up date to any log entry. The follow-up later surfaces in Needs Attention (US5).

**Independent Test**: Log an entry. Tap it to open detail. Set a follow-up date. Confirm the follow-up is persisted (re-open the detail to verify). Advance the device clock to the follow-up date — confirm the Needs Attention section shows this entry (requires US5 to validate fully).

- [X] T021 [US4] In app/lib/database/daos/bullets_dao.dart, add three follow-up methods: (1) `Future<void> addFollowUpToEntry(String bulletId, String followUpDate)` — calls `(update(bullets)..where((t) => t.id.equals(bulletId))).write(BulletsCompanion(followUpDate: Value(followUpDate), followUpStatus: Value('pending'), updatedAt: Value(now)))` then enqueues sync; (2) `Future<void> updateFollowUpStatus(String bulletId, String status, {String? snoozedUntil})` — writes followUpStatus, sets followUpSnoozedUntil if provided, sets followUpCompletedAt to current UTC timestamp if status == 'done', then enqueues sync; (3) `Future<void> insertCompletionEvent({required String sourceId, required String content, required String date})` — inserts a BulletsCompanion with `id: Value(_uuid.v4())`, `type: Value('completion_event')`, `sourceId: Value(sourceId)`, `content: Value(content)`, `dayId: Value(date)`, `status: Value('open')`, `position: Value(0)`, `createdAt: Value(now)`, `updatedAt: Value(now)`, `deviceId: Value(_deviceId)`, `encryptionEnabled: Value(0)`, `isDeleted: Value(0)`, then enqueues sync
- [X] T022 [US4] In app/lib/screens/timeline/timeline_screen.dart, update `_onTap(String bulletId)` to show a `showModalBottomSheet` panel: the panel is a `StatefulWidget` that: (1) loads the tapped bullet from `BulletsDao(db)` using `getBullet(bulletId)` (add this DAO method if not present — single `getSingleOrNull` select by id); (2) displays content text, personName if linked, and current followUpDate (formatted) if set; (3) shows an "Add Follow-Up" `TextButton` that calls `showDatePicker(context:context, initialDate:DateTime.now(), firstDate:DateTime.now(), lastDate:DateTime.now().add(Duration(days:365)))` and on date selected calls `BulletsDao(db).addFollowUpToEntry(bulletId, selected.toIso8601String().substring(0, 10))`; (4) shows swipe-to-delete on the bottom sheet matching existing pattern

**Checkpoint**: Tapping a timeline entry opens a detail panel. Adding a follow-up date and re-tapping the entry shows the follow-up date in the panel.

---

## Phase 7: User Story 5 — Needs Attention Section (Priority: P5)

**Goal**: A horizontal suggestion strip above the timeline surfaces pending follow-ups. Done/Snooze/Dismiss actions work immediately.

**Independent Test**: Create two entries with follow-up dates set to today. Open the Timeline tab. Both appear in a Needs Attention strip above the timeline. Dismiss one — only one remains. Mark the other Done — it disappears from Needs Attention and a "Followed up with [name]" entry appears in the timeline.

- [X] T023 [US5] In app/lib/database/daos/bullets_dao.dart, add `Stream<List<Bullet>> watchPendingFollowUps(String today)` using `customSelect` with SQL: `SELECT * FROM bullets WHERE is_deleted = 0 AND ((follow_up_status = 'pending' AND follow_up_date <= ?) OR (follow_up_status = 'snoozed' AND follow_up_snoozed_until <= ?)) ORDER BY follow_up_date ASC` with `variables: [Variable(today), Variable(today)]` and `readsFrom: {bullets}`; map result rows to `Bullet` using `db.bullets.map((row) => row)`
- [X] T024 [US5] Create app/lib/providers/needs_attention_provider.dart with `@riverpod Stream<List<NeedsAttentionItem>> needsAttentionItems(NeedsAttentionItemsRef ref)` that: (1) awaits `appDatabaseProvider.future`; (2) watches `BulletsDao(db).watchPendingFollowUps(_todayStr())`; (3) for each bullet fetches linked person name via `PeopleDao(db).getLinkedPersonForBullet(bullet.id)`; (4) maps to `NeedsAttentionItem(bulletId: b.id, content: b.content, followUpDate: b.followUpDate!, followUpStatus: b.followUpStatus!, personId: person?.id, personName: person?.name)` — add private `String _todayStr() => DateFormat('yyyy-MM-dd').format(DateTime.now())` helper; run `dart run build_runner build --delete-conflicting-outputs` from app/ after writing
- [X] T025 [US5] Create app/lib/widgets/needs_attention_section.dart with: (1) `NeedsAttentionSection` StatelessWidget accepting `List<NeedsAttentionItem> items`, `void Function(String) onDone`, `void Function(String) onSnooze`, `void Function(String) onDismiss`; returns `SizedBox.shrink()` when `items.isEmpty`; otherwise renders `Padding(padding: EdgeInsets.fromLTRB(16,16,16,8), child: Column(crossAxisAlignment:start, children: [Text('Needs Attention', style: TextStyle(fontSize:11, color:Colors.white38, fontWeight:FontWeight.w400, letterSpacing:0.4)), SizedBox(height:8), SizedBox(height:128, child: ListView.separated(scrollDirection:Axis.horizontal, ...))]))`; (2) `_SuggestionCard` private StatelessWidget with fixed width 240, GlassSurface(borderOpacityOverride: AntraColors.chipGlassBorderOpacity, padding: EdgeInsets.all(12)), showing: optional `Text(personName!, style: TextStyle(fontSize:11, color:Colors.white38))`, `Text(content, style: TextStyle(fontSize:13, color:Colors.white), maxLines:2, overflow:ellipsis)`, `Text(followUpDate, style: TextStyle(fontSize:11, color:Colors.white30))`, and a `Row` of three `IconButton`s: Done(`Icons.check_circle_outline_rounded`, onPressed: onDone), Snooze(`Icons.snooze_rounded`, onPressed: onSnooze), Dismiss(`Icons.close_rounded`, onPressed: onDismiss)
- [X] T026 [US5] In app/lib/screens/timeline/timeline_screen.dart: (1) watch `needsAttentionItemsProvider`; (2) add `SliverToBoxAdapter(child: NeedsAttentionSection(items: items, onDone: (id) async { final item = items.firstWhere((i) => i.bulletId == id); final name = item.personName; await BulletsDao(db).insertCompletionEvent(sourceId: id, content: name != null ? 'Followed up with $name' : 'Completed follow-up', date: _todayStr()); await BulletsDao(db).updateFollowUpStatus(id, 'done'); }, onSnooze: (id) async { final snoozed = DateTime.now().add(const Duration(days: 3)); await BulletsDao(db).updateFollowUpStatus(id, 'snoozed', snoozedUntil: DateFormat('yyyy-MM-dd').format(snoozed)); }, onDismiss: (id) async { await BulletsDao(db).updateFollowUpStatus(id, 'dismissed'); }))` as the FIRST sliver in the `CustomScrollView`, before the day slivers

**Checkpoint**: Needs Attention strip appears when pending follow-ups exist. Done creates a completion event in the timeline. Snooze hides and re-surfaces after 3 days. Dismiss removes permanently. Strip is absent when no pending items exist.

---

## Phase 8: User Story 6 — Person Relationship Timeline (Priority: P6)

**Goal**: The person detail view shows a grouped chronological timeline of all log entries and completion events linked to that person, with a last-seen date in the header.

**Independent Test**: Log three entries linked to "Anna" on different days. Mark one follow-up as Done. Open Anna's detail view. Confirm three log entries and one completion event appear, grouped by date with sticky headers. Header shows "Last seen: [correct date]".

- [X] T027 [US6] In app/lib/database/daos/bullets_dao.dart, add `Future<List<Bullet>> getPersonTimeline(String personId)` that runs a raw `customSelect` UNION query: `SELECT b.* FROM bullets b INNER JOIN bullet_person_links bpl ON bpl.bullet_id = b.id WHERE bpl.person_id = ? AND b.is_deleted = 0 AND bpl.is_deleted = 0 UNION SELECT b2.* FROM bullets b2 WHERE b2.type = 'completion_event' AND b2.source_id IN (SELECT bpl2.bullet_id FROM bullet_person_links bpl2 WHERE bpl2.person_id = ? AND bpl2.is_deleted = 0) AND b2.is_deleted = 0 ORDER BY created_at DESC` with `variables: [Variable(personId), Variable(personId)]` and `readsFrom: {bullets, bulletPersonLinks}`; map each `QueryRow` to a `Bullet` using `db.bullets.mapFromRow(row.rawData)` — also add a `Stream<List<Bullet>> watchPersonTimeline(String personId)` wrapper using `customSelectStream` with the same query
- [X] T028 [US6] Create app/lib/providers/person_timeline_provider.dart with `@riverpod Stream<List<TimelineDay>> personTimeline(PersonTimelineRef ref, String personId)` that watches `BulletsDao(db).watchPersonTimeline(personId)`, maps each bullet to TimelineEntry (same type-switch as `timelineEntriesProvider`), and groups into TimelineDay objects sorted oldest-first (reverse the newest-first sort for the person view — use `List<TimelineDay>.reversed`); run `dart run build_runner build --delete-conflicting-outputs` from app/ after writing
- [X] T029 [US6] Modify app/lib/screens/people/person_detail_screen.dart: (1) watch `personTimelineProvider(person.id)` and derive `lastSeenLabel` from `timelineDays.isNotEmpty ? _dateLabel(timelineDays.last.date) : null` (reuse the Today/Yesterday/MMM d logic); (2) update the person info header section to show `Text('Last seen: $lastSeenLabel', style: TextStyle(fontSize:12, color:Colors.white38))` below the person name — hide this line if `lastSeenLabel == null`; (3) replace the existing flat list section with a `CustomScrollView` whose slivers loop over `timelineDays` and emit a `_StickyDateHeaderDelegate` (extract to a shared location or duplicate from timeline_screen.dart) + `SliverList` per day; (4) show `Text('No interactions yet with ${person.name}.')` centered when `timelineDays.isEmpty`

**Checkpoint**: Person detail shows grouped timeline entries with sticky date headers. Last-seen date is accurate. Completion events ("Followed up with Anna") appear at their completion date.

---

## Phase 9: User Story 7 — Simplified Navigation (Priority: P7)

**Goal**: Exactly two tabs visible: Timeline and People. All other tabs and their associated watchers are removed.

**Independent Test**: Open the app. Count the tabs. Exactly two: Timeline and People. Confirm no Day View, Collections, Search, or Review tab is accessible. Confirm tapping Timeline shows the infinite scroll timeline with Needs Attention above it.

- [X] T030 [US7] In app/lib/screens/root_tab_screen.dart: (1) add `import 'package:antra/screens/timeline/timeline_screen.dart';`; (2) replace `_screens` const with `[const TimelineScreen(), const PeopleScreen()]`; (3) replace `_tabs` const with `[_TabItem(icon: Icons.timeline_outlined, label: 'Timeline'), _TabItem(icon: Icons.people_outline_rounded, label: 'People')]`; (4) remove `final weeklyCount = ref.watch(weeklyReviewTasksProvider).valueOrNull?.length ?? 0;` from `build()`; (5) remove `reviewBadgeCount: weeklyCount` argument from the `_FloatingTabBar(...)` call; (6) remove the `reviewBadgeCount` field and parameter from `_FloatingTabBar` and remove the `Badge` widget from `_TabButton.build()` (replace Badge with just `Icon(item.icon, ...)`); (7) remove `_kReviewTabIndex` constant; (8) remove unused imports: DayViewScreen, CollectionsScreen, SearchScreen, ReviewScreen, task_lifecycle_provider

**Checkpoint**: App shows exactly two tabs. Timeline is the home screen. People tab shows the contact list. No analyzer errors introduced.

---

## Phase 10: Polish & Validation

**Purpose**: Verify all user stories work together, no regressions.

- [X] T031 [P] Run `flutter test` from app/ directory and confirm all tests pass (0 failures) — fix any tests that break due to the BulletCaptureBar submit-path change (T014) or root_tab_screen tab reduction (T030)
- [X] T032 [P] Run `flutter analyze` from app/ directory and confirm no new issues introduced by this feature (pre-existing issues acceptable)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Requires Phase 1 reads — BLOCKS all user story work
- **US1 (Phase 3)**: Requires Phase 2 complete (T007–T011); modifies `bullets_dao.dart`, `bullet_capture_bar.dart`, new `timeline_screen.dart`
- **US2 (Phase 4)**: Requires US1 complete (same file: `timeline_screen.dart`); adds `timeline_provider.dart` (new file, can overlap with US1 if different developer)
- **US3 (Phase 5)**: Requires US2 complete (same file: `timeline_screen.dart` entry card rendering)
- **US4 (Phase 6)**: Requires US2 complete (same file: `bullets_dao.dart`, `timeline_screen.dart` tap handler); can start after US2 if US3 proceeds concurrently
- **US5 (Phase 7)**: Requires US4 complete (depends on `insertCompletionEvent`, `updateFollowUpStatus` from T021); new files `needs_attention_provider.dart`, `needs_attention_section.dart` can start after foundational
- **US6 (Phase 8)**: Requires Phase 2 complete; independent of US1–US5 (different file: `person_detail_screen.dart`, new `person_timeline_provider.dart`)
- **US7 (Phase 9)**: Requires US1 complete (needs `TimelineScreen` to exist); independent of US2–US6
- **Polish (Phase 10)**: All phases complete

### today_timeline.dart — Sequential Edit Order for bullets_dao.dart

All additions to `bullets_dao.dart` are additive (new methods only) and do not conflict. They can be written in any order, but the checklist preserves sequential task IDs to avoid file conflicts during single-developer execution:

1. T012 — `insertBulletForDate()`
2. T015 — `watchTimelineEntries()`
3. T021 — `addFollowUpToEntry()`, `updateFollowUpStatus()`, `insertCompletionEvent()`
4. T022 — `getBullet()` (if not already present)
5. T023 — `watchPendingFollowUps()`
6. T027 — `getPersonTimeline()`, `watchPersonTimeline()`

### Parallel Opportunities

- T001–T006 (Setup reads): T003, T004, T005, T006 can all run in parallel with T001/T002
- T007 and T008 must be sequential (T007 before T008 — column declarations before migration SQL)
- T010 and T011 can run in parallel (different new files)
- After Phase 2: US1 and US6 can start concurrently (different files)
- After US2: US3, US4, US5 can start concurrently IF each developer works on separate tasks within the same file sequentially
- T024 and T025 (US5) can run in parallel — different files

---

## Implementation Strategy

### MVP (User Story 1 Only)

1. Complete Phase 1: Setup reads
2. Complete Phase 2: Schema migration (T007–T011)
3. Complete Phase 3: US1 — capture bar + basic timeline (T012–T014)
4. **STOP and validate**: Type entry → appears in timeline under "Today" within 500 ms
5. Run `flutter test` — all tests pass

### Full Delivery

1. Phase 1 + 2 (foundation)
2. Phase 3 (US1 — capture bar, basic timeline)
3. Phase 4 (US2 — infinite timeline with sticky headers, `timeline_provider.dart`)
4. Phase 5 (US3 — person name display on cards)
5. Phase 6 (US4 — follow-up attachment, DAO methods)
6. Phase 7 (US5 — Needs Attention section)
7. Phase 8 (US6 — person relationship timeline)
8. Phase 9 (US7 — 2-tab navigation)
9. Phase 10 (flutter test + flutter analyze)

---

## Notes

- No new packages — all changes use Flutter core + existing drift, Riverpod, intl, uuid tokens
- Schema migration is additive (nullable columns only) — no existing data at risk
- `dayId` on new bullets holds an ISO date string (e.g., `'2026-03-13'`) not a day_logs UUID — old bullets retain their UUID dayId; the timeline groups by `createdAt` date, not `dayId`
- Completion events are stored as bullets with `type = 'completion_event'` and `sourceId` pointing to the originating entry
- `watchBulletsForDay(dayId)` remains in the DAO for backward compatibility with existing tests; it is not called by any new code
- US3 (person linking) is mostly pre-built in `BulletCaptureBar`; the main US3 tasks ensure person names appear on timeline cards
- US6 can be developed independently of US1–US5 (different file) after the foundational phase
