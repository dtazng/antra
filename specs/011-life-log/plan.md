# Implementation Plan: Life Log & Follow-Up System

**Branch**: `011-life-log` | **Date**: 2026-03-13 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/011-life-log/spec.md`

---

## Summary

A major product model simplification replacing the task-centric, day-centric Day View with a calm, unified life log experience. Seven user stories span: (1) a fixed bottom capture bar for instant log entry creation; (2) an infinite-scroll timeline with sticky date separators; (3) inline `@mention` person linking; (4) follow-up dates attached to log entries; (5) a "Needs Attention" section for pending follow-up suggestions; (6) a redesigned person relationship timeline; and (7) simplified two-tab navigation. No new packages are required. A single schema migration bumps the `bullets` table from version 4 → 5, adding follow-up columns and a `sourceId` column for completion events.

---

## Technical Context

**Language/Version**: Dart 3.3+ / Flutter 3.19+
**Primary Dependencies**: flutter_riverpod 2.5, riverpod_annotation 2.3, drift 2.18, intl 0.19, uuid 4.x — all existing; no new packages
**Storage**: SQLite via drift + SQLCipher. Schema version 4 → 5. Additive migration: new nullable columns on `bullets`, no data loss.
**Testing**: flutter_test (existing test suite; widget tests for timeline, needs-attention, capture bar)
**Target Platform**: iOS (primary), Android
**Project Type**: Mobile app
**Performance Goals**: 60 fps scroll; timeline load < 1 second; capture latency < 500 ms (constitution requirement)
**Constraints**: No new packages; no data loss in migration; all existing tests must continue to pass; offline-first behavior unchanged
**Scale/Scope**: Major refactor across 6 files + new TimelineScreen; 5 → 2 navigation tabs; 1 schema migration

---

## Constitution Check

*GATE: Must pass before implementation. Re-checked after design.*

### I. Code Quality ✅ PASS

- The `bullets` table is evolved in place (additive migration) — no orphaned data, no parallel table.
- `type = 'task'` bullets are treated as log entries going forward. Existing `type` column is preserved for backward compat with sync; new entries use `type = 'note'` (the only meaningful value going forward).
- `LogEntry`, `FollowUpStatus`, `TimelineEntry`, and `NeedsAttentionSuggestion` are pure Dart model classes — single responsibility, no Flutter imports.
- `timelineEntriesProvider` replaces `todayInteractionsProvider` — no dead providers left in place.
- Navigation simplification removes 3 tabs cleanly; no remnant screen imports in `RootTabScreen`.

### II. Testing Standards ✅ PASS

- Empty timeline → empty state: widget test required (US2 edge case).
- Needs Attention appears / disappears on suggestion state change: widget test required (US5 happy path + empty case).
- Follow-up Done creates a completion event: DAO unit test required (US4 acceptance scenario 3).
- All existing tests (`today_timeline_test.dart`, `day_view_screen_test.dart`) must be migrated or replaced.
- Person relationship timeline accuracy: widget test required (US6 acceptance scenario 1).

### III. User Experience Consistency ✅ PASS

- **Capture speed is sacred**: `BulletCaptureBar` is preserved and repositioned as the persistent bottom input. The log → save → appear path remains local-only (< 500 ms).
- **Calm by default**: Needs Attention section is suppressed when empty (FR-010). No badges, scores, or streaks introduced.
- **Consistent affordances**: Swipe-to-delete and undo behavior unchanged on timeline cards. Done/Snooze/Dismiss actions follow the existing swipe card pattern from the suggestion system.
- **Graceful empty states**: Timeline, Needs Attention (absent when empty, not an empty card), and Person detail each have a meaningful empty state.
- **Destructive actions**: Deleting a log entry (which also removes follow-up) goes through the existing swipe-to-delete + undo snackbar pattern.

### IV. Performance Requirements ✅ PASS

- Infinite timeline uses `CustomScrollView` + `SliverList` — inherently lazy-loaded; only visible rows are built.
- `SliverPersistentHeader` for sticky date headers adds negligible layout cost.
- The timeline provider watches the full bullets stream (no day filter) — acceptable because SQLite with drift delivers reactive streams efficiently for up to 10,000 entries (per constitution search requirement).
- No `BackdropFilter` changes; blur budget unchanged on timeline cards.

### Privacy & Data Integrity ✅ PASS

- Schema migration is additive (nullable columns only) — no existing data is modified or at risk.
- Follow-up status transitions are local-only state changes on the `bullets` row — no new sync paths introduced.
- Completion events are new bullet rows (`type = 'completion_event'`) with the same encryption and sync logic as existing bullets.

---

## Project Structure

### Documentation (this feature)

```text
specs/011-life-log/
├── plan.md              ✅ (this file)
├── research.md          ✅
├── data-model.md        ✅
├── quickstart.md        ✅
├── contracts/
│   └── widget-contracts.md  ✅
└── tasks.md             (created by /speckit.tasks)
```

### Source Code (files modified or created)

```text
app/
├── lib/
│   ├── database/
│   │   ├── app_database.dart              # Schema version 4 → 5; new columns on bullets; new migration
│   │   ├── tables/
│   │   │   └── bullets.dart               # Add: followUpDate, followUpStatus, followUpSnoozedUntil,
│   │   │                                  #   followUpCompletedAt, sourceId columns
│   │   └── daos/
│   │       └── bullets_dao.dart           # Add: watchTimelineEntries(), insertCompletionEvent(),
│   │                                      #   updateFollowUpStatus(), watchPendingFollowUps()
│   ├── models/
│   │   ├── timeline_entry.dart            # New: LogEntry | CompletionEvent discriminated union
│   │   └── needs_attention_item.dart      # New: pending follow-up surface model
│   ├── providers/
│   │   ├── timeline_provider.dart         # New: timelineEntriesProvider (replaces day_view_provider)
│   │   └── needs_attention_provider.dart  # New: needsAttentionProvider
│   ├── screens/
│   │   ├── root_tab_screen.dart           # Reduce to 2 tabs: Timeline + People
│   │   └── timeline/
│   │       └── timeline_screen.dart       # New: infinite-scroll timeline home screen
│   ├── widgets/
│   │   ├── timeline_list.dart             # New: CustomScrollView + sticky headers + entry cards
│   │   ├── needs_attention_section.dart   # New: horizontal-scroll suggestion strip
│   │   └── bullet_capture_bar.dart        # Modify: remove _kTabBarClearance (tab bar now 2-tab)
│   └── screens/
│       └── people/
│           └── person_detail_screen.dart  # Modify: replace flat list with grouped relationship timeline
└── test/
    └── widgets/
        ├── timeline_screen_test.dart      # New
        └── needs_attention_test.dart      # New
```

**Structure Decision**: Single Flutter project. Changes are concentrated in 4 source layers: database (migration + DAO), models (2 new), providers (2 new), screens/widgets (1 new screen, 3 new widgets, 2 existing modified). Navigation is simplified in `root_tab_screen.dart`.

---

## Implementation Notes Per User Story

### US1 — Log an Entry

**File**: `app/lib/widgets/bullet_capture_bar.dart`, `app/lib/screens/timeline/timeline_screen.dart`

`BulletCaptureBar` is already built with `@mention` autocomplete, person linking, and instant save. Changes:
- Remove the `dayId`-based `getOrCreateDayLog` requirement — new bullets set `dayId` to a sentinel (today's date string re-used for now) or `null` if the DAO is updated to support nullable `dayId`.
- Research Decision 3 below: keep `dayId` as a non-null column but populate it with the date string `createdAt.substring(0,10)` for all new bullets. This avoids a nullable migration.
- `_kTabBarClearance` constant stays at `60.0` — the new 2-tab bar has the same height as the old 5-tab bar.

### US2 — Infinite Timeline

**File**: `app/lib/screens/timeline/timeline_screen.dart`, `app/lib/widgets/timeline_list.dart`, `app/lib/providers/timeline_provider.dart`

```dart
// Provider delivers sorted list of TimelineEntry (discriminated union)
@riverpod
Stream<List<TimelineDay>> timelineEntries(TimelineEntriesRef ref) async* { ... }

// Widget structure
CustomScrollView(
  slivers: [
    SliverToBoxAdapter(child: NeedsAttentionSection(...)),  // US5
    for (final day in days) ...[
      SliverPersistentHeader(delegate: _DateHeaderDelegate(day.label), pinned: true),
      SliverList(delegate: SliverChildBuilderDelegate(...)),
    ],
  ],
)
```

`TimelineDay` is a grouping model: `{ label: String, entries: List<TimelineEntry> }`.

Date label logic: same as existing `_displayLabel` in DayViewScreen — Today / Yesterday / `DateFormat('MMM d').format(date)`.

### US3 — Person Linking

**No new implementation** — `BulletCaptureBar` already supports `@mention` autocomplete and person-linked bullet creation. The only change is ensuring that the `watchAllBulletsForDay` query is replaced by `watchTimelineEntries` (all-time) in the timeline provider.

### US4 — Follow-Up Attachment

**Files**: `app/lib/database/tables/bullets.dart` (new columns), `app/lib/database/daos/bullets_dao.dart` (new methods)

```dart
// New columns on Bullets table (nullable — additive migration)
TextColumn get followUpDate => text().nullable()();
TextColumn get followUpStatus => text().nullable()(); // pending|done|snoozed|dismissed
TextColumn get followUpSnoozedUntil => text().nullable()();
TextColumn get followUpCompletedAt => text().nullable()();

// New column for completion events
TextColumn get sourceId => text().nullable()(); // FK → bullets.id
```

Follow-up attachment UI: a date picker accessed via a swipe-up action on an existing timeline entry card (tap → detail → add follow-up).

### US5 — Needs Attention Section

**Files**: `app/lib/widgets/needs_attention_section.dart`, `app/lib/providers/needs_attention_provider.dart`

```dart
@riverpod
Stream<List<NeedsAttentionItem>> needsAttentionItems(NeedsAttentionItemsRef ref) async* {
  // Watches bullets where followUpStatus = 'pending' AND followUpDate <= today
}
```

`NeedsAttentionSection` is a `SliverToBoxAdapter` above the timeline slivers. Hidden (returns `SizedBox.shrink()`) when list is empty.

### US6 — Person Relationship Timeline

**File**: `app/lib/screens/people/person_detail_screen.dart`

Replace the existing flat `ListView` with a `CustomScrollView` matching the timeline pattern: sticky date headers + grouped entry list. Data source: all bullets linked to `personId` (via `bullet_person_links`) + all completion events where `sourceId` bullet has a person link to `personId`.

### US7 — Simplified Navigation

**File**: `app/lib/screens/root_tab_screen.dart`

```dart
static const _screens = [TimelineScreen(), PeopleScreen()];
static const _tabs = [
  _TabItem(icon: Icons.timeline_outlined, label: 'Timeline'),
  _TabItem(icon: Icons.people_outline_rounded, label: 'People'),
];
```

Remove: `DayViewScreen`, `CollectionsScreen`, `SearchScreen`, `ReviewScreen` from `_screens`. Remove `weeklyReviewTasksProvider` watch (badge no longer shown). Remove `_kReviewTabIndex` constant.

---

## Constitution Check — Post-Design Re-evaluation ✅ PASS

All seven changes remain within the principles. No gate failures. The schema migration is additive (no data loss). Navigation reduction removes dead code cleanly. No new packages. No new async paths on the capture critical path.

---

## Complexity Tracking

No violations. All changes are incremental refinements using established patterns (drift migrations, Riverpod stream providers, CustomScrollView slivers).
