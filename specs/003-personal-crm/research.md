# Research: Personal CRM (003-personal-crm)

**Phase**: 0 — Unknowns resolution
**Date**: 2026-03-10
**Status**: Complete — all NEEDS CLARIFICATION resolved

---

## 1. Schema Extension Strategy

**Question**: How should new People fields be added to the existing `People` table?

**Decision**: Schema migration v2 → v3 using `drift`'s `MigrationStrategy.onUpgrade`.

**Rationale**: All new columns are nullable with SQLite-compatible defaults, so `ALTER TABLE ADD COLUMN` works without data loss. Existing rows get `NULL` for new fields, which is correct (profile fields are optional). Schema v2 → v3 is a non-breaking additive migration.

**Fields to add to `People`** (all nullable):
`company`, `role`, `email`, `phone`, `birthday` (TEXT ISO-8601), `location`, `tags` (TEXT comma-separated), `relationshipType` (TEXT enum: Friend | Family | Colleague | Mentor | Acquaintance | Other), `needsFollowUp` (INTEGER default 0), `followUpDate` (TEXT ISO-8601 nullable)

**Field to add to `BulletPersonLinks`**: `linkType` (TEXT default 'mention')

**Alternatives considered**:
- Separate `PersonFields` table — rejected; adds a JOIN for every profile load with no benefit since the fields are 1:1.
- Replace People table entirely — rejected; would require data migration with no gain.

---

## 2. Tags Storage

**Question**: Should tags be stored as comma-separated text in `People.tags` or as a new `PersonTagLinks` junction table?

**Decision**: Comma-separated string in `People.tags` (e.g., `"work,mentor,friend"`).

**Rationale**:
- Spec says "free-form labels" with a small expected count (2–5 per person).
- Filtering by tag (FR-022) can be done with a `LIKE '%work%'` query or Dart-side after loading the list. For 500 people, Dart-side filtering is instant.
- A junction table adds code complexity (DAO methods, migration, sync payload) with no measurable benefit at this scale.
- FTS5 `people_fts` already indexes `notes`; tags can be parsed from the TEXT column on demand.

**Alternatives considered**:
- `PersonTagLinks` junction table — rejected; over-engineered for free-form personal labels at this scale.

---

## 3. FTS5 Search for People

**Question**: How to implement real-time name/company search (FR-020) using the existing `people_fts` virtual table?

**Decision**: Use drift `customSelect` with FTS5 query `SELECT people.* FROM people JOIN people_fts ON people.rowid = people_fts.rowid WHERE people_fts MATCH ?`.

**Rationale**:
- `people_fts` already has `name` and `notes` columns indexed. The FTS5 `MATCH` operator handles prefix search natively (`alice*`).
- For company search (new field, not in FTS5), supplement with a SQL `LIKE` clause on `company`. Since FTS5 and LIKE are both fast at 500 rows, combining them with a UNION or OR in Dart is acceptable.
- For the autocomplete in the capture bar (already working with a `startsWith` filter), keep the existing approach but enhance to include company field matching.

**Migration note**: `people_fts` currently indexes `name` and `notes`. After v3 adds `company`, the FTS triggers must be updated to include `company`. New triggers will be added in `onUpgrade` (v2→v3). The FTS table itself is rebuilt with `INSERT INTO people_fts(people_fts) VALUES ('rebuild')` after new data is inserted.

**Alternatives considered**:
- `LIKE %query%` on the `people` table — acceptable fallback, but FTS5 is already in place and faster.
- Full rebuild of `people_fts` schema — rejected; FTS5 `ALTER VIRTUAL TABLE` is not supported in SQLite; adding new columns requires the `content=` table pattern which is already used.

**Resolved approach**: Use existing FTS5 for name/notes matching. Add `company` to the FTS5 table triggers in v2→v3 migration via `people_fts` rebuild.

---

## 4. Duplicate Person Detection

**Question**: How should FR-003 / FR-028 duplicate detection be implemented?

**Decision**: Case-insensitive exact-name query first, then FTS5 prefix/LIKE for near-matches; evaluated in `PeopleDao.findSimilarPeople(name)`.

**Rationale**:
- Exact match: `SELECT * FROM people WHERE LOWER(name) = LOWER(?)` — already exists as `getPersonByName()`.
- Near-match: Use `LIKE '%fragment%'` split on first-name tokens; for short names, also check Levenshtein distance in Dart (no library needed, trivial implementation for names ≤ 30 chars).
- The duplicate check happens in the `CreatePersonSheet` before save, showing a warning bottom sheet.

**Alternatives considered**:
- Third-party fuzzy matching library — rejected; adds a dependency for a small feature. Dart-side string comparison is sufficient for personal contact lists (≤ 500 names).

---

## 5. @mention → Create New Person Flow

**Question**: When a typed `@name` doesn't match any existing person, how should the "create new person" flow work in the capture bar?

**Decision**: Show a special suggestion row "➕ Create 'Alice'" in the autocomplete list. Tapping it opens the `CreatePersonSheet` as a modal sheet with the name pre-filled, and on success links the new person to the log entry being composed.

**Rationale**:
- Preserves the existing suggestion overlay UX without adding a new UI surface.
- The bullet is saved first; if the user cancels person creation, the bullet is still saved unlinked. This matches the spec's "continue without linking" option (FR-010).
- `BulletCaptureBar._submit()` already handles post-save linking; the create flow hooks into the same path.

**Alternatives considered**:
- Inline "New person" text field in the suggestion overlay — rejected; too much UI state in the capture bar.
- Navigate to a full person creation screen — rejected; breaks capture flow.

---

## 6. Sort / Filter Implementation

**Question**: Should people list sort/filter be done in SQL (DAO) or Dart?

**Decision**: SQL for sort (ORDER BY), Dart for filter (tags, relationship type, follow-up) on the already-loaded list.

**Rationale**:
- Sort by `lastInteractionAt DESC`, `name ASC`, or `createdAt DESC` can be expressed as `OrderingTerm` in drift queries, keeping the result set minimal.
- Tag and relationship-type filters operate on data already in memory after the query; for ≤ 500 people this is instant and avoids multiple queries.
- Follow-up filter: `needsFollowUp = 1` can be a SQL WHERE clause.
- Stale indicator (FR-027): computed in Dart by comparing `lastInteractionAt` to `DateTime.now() - 30 days`. Not a filter, just a display decoration.

**Alternatives considered**:
- All filtering in SQL — valid but requires dynamic query construction in drift, which is more verbose for optional multi-condition filters. Dart-side is simpler for this feature size.

---

## 7. Link / Unlink Person from Log Detail

**Question**: How should FR-011 (attach/change/remove person link from log detail) be implemented?

**Decision**: Add a "Linked person" section to `BulletDetailScreen` and `TaskDetailScreen`. A chip shows the linked person (if any). Tapping "Add" shows a people picker bottom sheet; tapping a chip shows a popover with "Remove" and "Change" options.

**Rationale**:
- Consistent with the existing chips pattern in `BulletDetailScreen` (tags are already shown as chips).
- People picker is a new `PersonPickerSheet` widget reused from both detail screens.
- `PeopleDao.insertLink()` and `softDeleteLinksForBullet()` already exist; need to add `removeLink(bulletId, personId)` for precise unlink.

**Note**: In v1 the UI shows only the first linked person (consistent with spec's "one primary person" assumption). The schema supports multiple but the capture UI only exposes one.

---

## 8. Schema Version Summary

| Version | Changes |
|---------|---------|
| 1 | Initial schema: bullets, day_logs, people, tags, bullet_person_links, bullet_tag_links, collections, reviews, pending_sync, conflict_records |
| 2 | Added task lifecycle: bullets.scheduledDate, carryOverCount, completedAt, canceledAt; task_lifecycle_events table |
| 3 (this feature) | people: +company, +role, +email, +phone, +birthday, +location, +tags, +relationshipType, +needsFollowUp, +followUpDate; bullet_person_links: +linkType; FTS triggers updated |

---

## 9. Sync Payload Impact

All new People columns must be included in the `_enqueuePersonSync` payload in `PeopleDao`. The existing `SyncEngine` serializes fields as JSON; adding new nullable fields is backward-compatible with existing DynamoDB records (they simply lack those keys until the first update).

`BulletPersonLinks.linkType` must be included in the link sync payload (already handled by `_enqueueSync`; add `linkType` to the payload map).

---

## Summary of Decisions

| Area | Decision |
|------|----------|
| Tags | Comma-separated string in `People.tags` |
| Schema migration | v2 → v3 additive (ALTER TABLE ADD COLUMN) |
| FTS search | Existing `people_fts` + LIKE for company |
| Duplicate detection | Exact + near-match in DAO, warning in UI |
| @mention create flow | "Create X" row in autocomplete overlay |
| Sort/filter | SQL ORDER BY + Dart-side filter |
| Link/unlink from detail | `PersonPickerSheet` + chip UI |
| Multi-person per log | Schema-ready; UI shows first link only (v1) |
