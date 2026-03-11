# Data Model: Person Detail View

**Branch**: `004-person-detail-view` | **Date**: 2026-03-10

## Schema Changes: v3 → v4

### 1. `bullet_person_links` — add `is_pinned` column

```sql
ALTER TABLE bullet_person_links ADD COLUMN is_pinned INTEGER NOT NULL DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_bpl_person_pinned
  ON bullet_person_links(person_id, is_pinned)
  WHERE is_deleted = 0;
```

**Drift column DSL** (add to `BulletPersonLinks` table class):
```dart
/// 1 = this bullet is pinned in this person's detail view. 0 = not pinned.
IntColumn get isPinned => integer().withDefault(const Constant(0))();
```

No other schema changes. `Bullets` table unchanged. `People` table unchanged.

---

## New Dart Data Classes (not persisted)

### `InteractionSummary`

Computed aggregate — never stored in SQLite.

```dart
class InteractionSummary {
  final int total;
  final int last30Days;
  final int last90Days;
  final Map<String, int> byType; // e.g. {'note': 12, 'task': 5, 'event': 3}

  const InteractionSummary({
    required this.total,
    required this.last30Days,
    required this.last90Days,
    required this.byType,
  });

  static const empty = InteractionSummary(
    total: 0,
    last30Days: 0,
    last90Days: 0,
    byType: {},
  );
}
```

### `TimelineItem` (sealed class)

Used by the Full Activity Timeline to mix month headers and activity rows in a single `SliverList`.

```dart
sealed class TimelineItem {}

class TimelineMonthHeader extends TimelineItem {
  final String label; // e.g. "March 2026"
  TimelineMonthHeader(this.label);
}

class TimelineActivityRow extends TimelineItem {
  final Bullet bullet;
  TimelineActivityRow(this.bullet);
}
```

---

## SQL: Interaction Summary Query

Used by `PeopleDao.getInteractionSummary(String personId)`.

```sql
SELECT
  COUNT(*) AS total,
  COUNT(CASE WHEN b.created_at >= :cutoff30 THEN 1 END) AS last_30,
  COUNT(CASE WHEN b.created_at >= :cutoff90 THEN 1 END) AS last_90,
  COUNT(CASE WHEN b.type = 'note'  THEN 1 END) AS type_note,
  COUNT(CASE WHEN b.type = 'task'  THEN 1 END) AS type_task,
  COUNT(CASE WHEN b.type = 'event' THEN 1 END) AS type_event
FROM bullet_person_links bpl
JOIN bullets b ON b.id = bpl.bullet_id
WHERE bpl.person_id = :personId
  AND bpl.is_deleted = 0
  AND b.is_deleted = 0
```

Where `:cutoff30` = `DateTime.now().subtract(Duration(days: 30)).toUtc().toIso8601String()` and `:cutoff90` the same for 90 days.

---

## SQL: Recent Bullets for Person (limit 10)

Used by `PeopleDao.getRecentBulletsForPerson(String personId, {int limit = 10})`.

```sql
SELECT b.*
FROM bullet_person_links bpl
JOIN bullets b ON b.id = bpl.bullet_id
WHERE bpl.person_id = :personId
  AND bpl.is_deleted = 0
  AND b.is_deleted = 0
ORDER BY b.created_at DESC
LIMIT :limit
```

---

## SQL: Paginated Timeline for Person

Used by `PeopleDao.getBulletsForPersonPaged(String personId, {String? typeFilter, required int limit, required int offset})`.

```sql
SELECT b.*
FROM bullet_person_links bpl
JOIN bullets b ON b.id = bpl.bullet_id
WHERE bpl.person_id = :personId
  AND bpl.is_deleted = 0
  AND b.is_deleted = 0
  [AND b.type = :typeFilter]   -- omitted when typeFilter is null
ORDER BY b.created_at DESC
LIMIT :limit OFFSET :offset
```

---

## SQL: Pinned Bullets for Person

Used by `PeopleDao.getPinnedBulletsForPerson(String personId)`.

```sql
SELECT b.*
FROM bullet_person_links bpl
JOIN bullets b ON b.id = bpl.bullet_id
WHERE bpl.person_id = :personId
  AND bpl.is_pinned = 1
  AND bpl.is_deleted = 0
  AND b.is_deleted = 0
  AND b.type = 'note'
ORDER BY bpl.created_at ASC
```

(Ordered oldest-first so pinned notes appear in the order they were pinned, keeping context stable.)

---

## Dart Model Mapping Summary

| Source | Dart Type | Notes |
|--------|-----------|-------|
| `bullet_person_links.is_pinned` | `int` (0/1) | New column in v4 migration |
| `InteractionSummary` | Plain Dart class | Computed, not persisted |
| `TimelineItem` | Sealed class | UI model, not persisted |
| `Bullet` (existing) | drift-generated | No changes |
| `PeopleData` (existing) | drift-generated | No changes |
| `BulletPersonLinksData` (existing) | drift-generated | Regenerated with `isPinned` field |

---

## Entity Relationships (unchanged from v3)

```text
People ←──── BulletPersonLinks ────→ Bullets
              │
              └── isPinned (NEW, v4)
              └── linkType ('mention' | 'manual')
              └── isDeleted (soft-delete)
```

`InteractionSummary` is a read-only projection of the BulletPersonLinks + Bullets join.
`TimelineItem` is a UI-layer wrapper — no database backing.
