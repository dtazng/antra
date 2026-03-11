# Research: Person Detail View

**Branch**: `004-person-detail-view` | **Date**: 2026-03-10

## Decision 1: Where to store `isPinned`

**Decision**: Add `isPinned` (IntColumn, default 0) to the `BulletPersonLinks` table, not the `Bullets` table.

**Rationale**: Pinning is a relationship-level annotation — a note is pinned *for a specific person*, not globally. If stored on `Bullets`, pinning a note for Alice would make it appear pinned in every other person's view it is linked to. `BulletPersonLinks` already owns the per-person relationship context (`linkType`, `isDeleted`). Adding `isPinned` here is consistent and minimal.

**Alternatives considered**:
- `Bullets.isPinned`: Rejected — global pin pollutes bullet record with person-specific UI state. A note could be linked to two people; pinning it for one should not affect the other.
- Separate `pinned_notes` junction table: Rejected — premature over-engineering for what is a boolean flag on an existing junction record.

---

## Decision 2: Interaction summary counts

**Decision**: Compute summary counts (total, last 30 days, last 90 days, per-type breakdown) via a single raw SQL `customSelect` query in `PeopleDao` using `COUNT(CASE WHEN ... THEN 1 END)` expressions. Returns a lightweight `InteractionSummary` data class.

**Rationale**: One round-trip to SQLite. The `bullet_person_links` + `bullets` join is already indexed. A Dart-side approach would require loading all linked bullet records into memory first, which is inefficient for persons with 500+ interactions.

**Alternatives considered**:
- Multiple separate SQL queries (one per count): Rejected — 4+ round-trips vs. one.
- Dart-side aggregation: Rejected — requires fetching all rows before counting; wasteful when only aggregates are needed.
- Persisted counter columns on `People`: Rejected — denormalization requires careful invalidation on every link insert/delete, adding complexity and sync risk.

---

## Decision 3: Pagination for Full Activity Timeline

**Decision**: Offset-based pagination using drift's `.limit(pageSize, offset: offset)` on a `Future`-returning DAO method. Flutter UI holds a `List<Bullet>` accumulated across pages in a `PersonTimelineNotifier` (`@riverpod class`). `ScrollController` listener triggers next page load when `position.pixels >= maxScrollExtent - 300`. Page size = 20.

**Rationale**: Offset-based pagination is sufficient and simple for a personal app (≤ 500 interactions per person). Cursor-based pagination adds complexity without meaningful benefit at this scale. drift's `limit/offset` support is first-class. Riverpod `AsyncNotifier` with accumulated list is the idiomatic pattern for infinite scroll in this codebase.

**Alternatives considered**:
- Cursor-based pagination (by `created_at`): More robust for large datasets but over-engineered for ≤500 rows. Rejected.
- Stream-based paging: Drift doesn't natively support paginated streams without `watch()` on the full dataset. Rejected — defeats the purpose of pagination.
- `flutter_infinite_scroll_pagination` package: Adds a dependency for functionality achievable in ~30 lines. Rejected.

---

## Decision 4: Quick action "Log Interaction" from Person Detail

**Decision**: A new `LogInteractionSheet` bottom sheet (new file: `app/lib/widgets/log_interaction_sheet.dart`). Contains a `TextField` for content, type chips (note / event / task), and a pre-filled person badge. On save: inserts a new Bullet into today's `DayLog` (reusing the `BulletsDao.insertBullet` pattern), then calls `PeopleDao.insertLink(bulletId, personId, linkType: 'manual')`. Navigates back to profile, which reactively shows the new entry.

**Rationale**: The capture bar (`BulletCaptureBar`) is designed for the daily log tab and carries global state (active day, suggestions overlay). Reusing it in a modal context introduces coupling across unrelated screens. A dedicated `LogInteractionSheet` is simpler, scoped to person-linked logging, and follows the existing "lightweight bottom sheet for creation" pattern (see `CreatePersonSheet`, `EditPersonSheet`).

**Alternatives considered**:
- Opening the full daily log with the capture bar pre-filled: Requires navigation away from the person profile — loses context. Rejected.
- Reusing `BulletCaptureBar` in a bottom sheet: Captures bar depends on `dailyLogProvider` state and the tab scaffold. Tight coupling. Rejected.

---

## Decision 5: Full Activity Timeline grouping

**Decision**: Dart-side grouping after each SQL page fetch. Each page of 20 bullets (sorted `created_at DESC`) is appended to the accumulated list. After accumulation, the list is transformed into a flat `List<TimelineItem>` where `TimelineItem` is a sealed class/union with variants `MonthHeader(String label)` and `ActivityRow(Bullet bullet)`. The `SliverList` renders each item type differently.

**Rationale**: SQL `GROUP BY` would require a separate count query and doesn't help with rendering. Month headers are a presentation concern — computing them in Dart after pagination is correct and trivial (O(n) pass over already-fetched rows).

**Alternatives considered**:
- Pre-grouped data structure from SQL: Would require a more complex query with aggregation; still needs Dart-side reconstruction for the SliverList. Rejected.
- One `SliverGroup` per month: Not a Flutter primitive. `SliverList` with mixed item types is the Flutter idiom. Used.

---

## Decision 6: Schema migration version

**Decision**: `schemaVersion` 3 → 4. One `ALTER TABLE bullet_person_links ADD COLUMN is_pinned INTEGER NOT NULL DEFAULT 0` in the `onUpgrade` block. No FTS rebuild needed (column not indexed for FTS). One new index `idx_bpl_person_pinned` on `(person_id, is_pinned)` for the pinned notes query.

**Rationale**: Additive migration, zero data loss. Single column addition.

---

## Decision 7: PersonDetailScreen vs. PersonProfileScreen

**Decision**: Replace `PersonProfileScreen` content with the new structured layout in-place (same file path, same class name). The existing `PersonProfileScreen` entry point is already used as a navigation target across the app. Renaming or adding a parallel screen would require updating all navigation call sites.

The `_ProfileBody` widget will be substantially rewritten, and the existing `_TimelineRow`/`_EmptyTimeline` private widgets will be relocated to `PersonFullTimelineScreen`. The `bulletsForPersonProvider` (which streams all bullets) will be replaced by two new providers: `recentBulletsForPersonProvider` (Future, limit 5–10) and `PersonTimelineNotifier` (paginated, for the full timeline screen).

**Rationale**: Single authoritative profile screen; no navigation updates needed across the codebase.

---

## Decision 8: InteractionSummary data model

**Decision**: A plain Dart `class InteractionSummary` (not a drift-generated class) with fields: `total`, `last30Days`, `last90Days`, `byType` (`Map<String, int>`). Computed by `PeopleDao.getInteractionSummary(String personId) → Future<InteractionSummary>`.

**Rationale**: This is derived/computed data, not persisted data. A plain Dart class is appropriate. Drift `customSelect` returns raw `QueryRow` objects — mapping to `InteractionSummary` in the DAO is straightforward.
