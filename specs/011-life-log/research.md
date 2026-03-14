# Research: Life Log & Follow-Up System

**Branch**: `011-life-log` | **Date**: 2026-03-13

---

## Decision 1: Bullets Table Evolution vs. New LogEntry Table

**Decision**: Evolve the existing `bullets` table in place (schema version 4 → 5) rather than creating a new `log_entries` table.

**Rationale**: The `bullets` table already has all required fields (`id`, `content`, `createdAt`, `deviceId`, `isDeleted`, `syncId`). An additive migration (new nullable columns) preserves all existing data and sync history. A parallel table would require a data migration, dual-write logic during transition, and would leave the old table as dead weight.

**Implementation**: Add five new nullable columns to `bullets`:
- `followUpDate` — ISO date string (YYYY-MM-DD). Null = no follow-up attached.
- `followUpStatus` — `'pending' | 'done' | 'snoozed' | 'dismissed'`. Null = no follow-up.
- `followUpSnoozedUntil` — ISO date string. Set when status = `'snoozed'`.
- `followUpCompletedAt` — ISO UTC timestamp. Set when status = `'done'`.
- `sourceId` — FK → bullets.id. Set only on completion event bullets (type = `'completion_event'`).

**Alternatives considered**:
- New `log_entries` table: cleaner separation but requires full data migration and dual-read logic — rejected.
- New `follow_ups` table: cleaner follow-up entity isolation but adds a join on every timeline query — rejected in favor of denormalized columns on `bullets`.

---

## Decision 2: Completion Events as Bullets with type = 'completion_event'

**Decision**: When a suggestion is marked Done, insert a new bullet row with `type = 'completion_event'` and `sourceId` pointing to the original log entry bullet.

**Rationale**: Completion events appear in the infinite timeline just like regular log entries. Reusing the `bullets` table means the same timeline query, the same sync path, the same encryption path, and the same swipe-to-delete affordance apply without new infrastructure. The `sourceId` column establishes the link between the completion event and its originating entry.

**Content format**: `"Followed up with [personName]"` — constructed at completion time from the linked person name. If no person is linked, the content is `"Completed follow-up"`.

**Alternatives considered**:
- Separate `completion_events` table: cleaner schema but requires a union query in the timeline provider — rejected.
- In-place status update on the original bullet: doesn't create a new timeline entry at the completion date — rejected (spec requires a separate completion event in the timeline).

---

## Decision 3: dayId Handling for New Bullets

**Decision**: Keep `dayId` as a non-null column (no schema change to the column itself). For all new bullets created by the life-log capture bar, populate `dayId` with the ISO date portion of `createdAt` (e.g., `"2026-03-13"`). The `day_logs` table is no longer required as a prerequisite for creating bullets.

**Rationale**: Making `dayId` nullable requires a schema migration plus null-safety handling everywhere `dayId` is read. Instead, repurpose `dayId` as a denormalized date string (`createdAt.substring(0, 10)`) for all new bullets. Old bullets retain their existing `dayId` values (foreign keys to `day_logs`). The `day_logs` table remains but is not written to for new records.

**Impact on queries**: The infinite timeline provider queries by `createdAt` date — `dayId` is no longer used for grouping. Existing `watchBulletsForDay(dayId)` queries are kept for backward-compat with the DayView provider (to be removed in a future cleanup).

**Alternatives considered**:
- Nullable `dayId` migration: cleaner long-term but breaks all existing DAO queries and tests — deferred.
- Remove `day_logs` table: requires a migration with data movement — out of scope.

---

## Decision 4: Infinite Timeline — SliverPersistentHeader for Sticky Date Headers

**Decision**: Implement sticky date headers using `SliverPersistentHeader(pinned: true)` within a `CustomScrollView`. The timeline provider groups bullets into `TimelineDay` objects; the widget renders one `SliverPersistentHeader` + one `SliverList` per day group.

**Rationale**: `SliverPersistentHeader` is the Flutter-native solution for sticky headers in a sliver-based scroll view. It requires no additional packages. The performance profile matches the existing `AnimatedList`-based timeline and maintains 60 fps scroll.

**Header delegate**: A minimal `SliverPersistentHeaderDelegate` with `minExtent == maxExtent == 32.0` (a single text row with padding).

**Alternatives considered**:
- `sticky_headers` package: adds a dependency for behavior achievable with core Flutter — rejected (no new packages constraint).
- `SliverStickyHeader` from `sliver_tools`: same rejection rationale.
- Non-sticky date labels (inline): breaks the "sticky while scrolling" acceptance criterion — rejected.

---

## Decision 5: Needs Attention Section — Horizontal Scroll Strip

**Decision**: Render the Needs Attention section as a horizontal-scroll strip of suggestion cards above the timeline. Each card shows the follow-up context and three action buttons (Done, Snooze, Dismiss). The strip is absent (not rendered) when there are zero pending suggestions.

**Rationale**: A vertical list in the Needs Attention section risks growing into a stressful task list (spec explicitly warns against this). A horizontal strip is bounded in height, naturally conveys "a set of items to quickly act on", and disappears entirely when empty. The Done/Snooze/Dismiss actions are visible without swipe — keeping the affordance explicit.

**Implementation**: `SliverToBoxAdapter` wrapping a horizontal `ListView` of suggestion cards. Provider watches bullets where `followUpStatus = 'pending'` AND `followUpDate <= today` (or `followUpSnoozedUntil <= today` for snoozed items resurfacing).

**Alternatives considered**:
- Vertical list above timeline: grows unbounded, becomes stressful — rejected.
- Bottom sheet: requires extra tap to reveal; buried — rejected.
- Collapsible header: adds state complexity for minimal gain — rejected.

---

## Decision 6: Person Relationship Timeline — Unified Query

**Decision**: The person detail view queries two sources merged and sorted by date: (a) all bullets linked to the person via `bullet_person_links`, and (b) all completion event bullets (`type = 'completion_event'`) where the `sourceId` bullet has a person link to this person. These are merged in the DAO layer into a single `List<Bullet>` sorted by `createdAt`.

**Rationale**: Both data types use the `bullets` table; a union SQL query avoids separate streams and complex merge logic in the provider layer. The merged list is then grouped by date in the provider, identical to the main timeline grouping.

**Alternatives considered**:
- Separate streams merged in Dart: two reactive streams are harder to sort correctly — rejected.
- Only showing direct-linked bullets (not completion events): loses the "Followed up with Anna" entry from the person's timeline — rejected (spec US6 requires completion events to appear).

---

## Decision 7: Navigation Reduction — Keeping Screens in Codebase

**Decision**: Remove `DayViewScreen`, `CollectionsScreen`, `SearchScreen`, and `ReviewScreen` from `RootTabScreen._screens` and `_tabs`. The screen files themselves are kept in the codebase but no longer imported from `root_tab_screen.dart`. The `weeklyReviewTasksProvider` watch is removed from `RootTabScreen`.

**Rationale**: Removing the tab entries is the minimum change to satisfy US7. Deleting the screen files is out of scope for this feature — those screens may be useful reference for future work or may be re-integrated. Removing the `import` statements and `_screens` entries is sufficient to eliminate all navigation to those screens.

**Alternatives considered**:
- Delete screen files: too destructive for a spec-scoped feature — deferred.
- Keep all tabs, add Timeline as a new tab: contradicts the spec's "exactly two tabs" requirement — rejected.

---

## Decision 8: No New Packages

**Decision**: All implementation uses Flutter core + existing project dependencies (drift, Riverpod, intl, uuid). No new packages are added.

**Rationale**: `SliverPersistentHeader` covers sticky headers. `Text.rich` / `TextSpan` covers mention styling (already implemented). `CustomScrollView` + `SliverList` covers infinite scroll. No external package is required for any of the seven user stories.
