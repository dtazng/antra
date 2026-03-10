# Data Model: Personal CRM (003-personal-crm)

**Phase**: 1 — Design
**Date**: 2026-03-10
**Schema version**: 2 → 3

---

## Overview

This feature augments two existing tables (`people`, `bullet_person_links`) with new columns and updates FTS5 triggers. No new tables are added. Schema version bumps from 2 to 3.

---

## Existing Tables (unchanged structure, referenced for context)

### `bullets`
Existing table. No changes in this feature. Referenced via `bullet_person_links`.

### `day_logs`
Existing table. Unchanged.

---

## Modified Table: `people`

### Current columns (v2)
| Column | Type | Constraints |
|--------|------|-------------|
| `id` | TEXT | PRIMARY KEY (client UUID) |
| `name` | TEXT | NOT NULL |
| `notes` | TEXT | NULL |
| `reminder_cadence_days` | INTEGER | NULL |
| `last_interaction_at` | TEXT | NULL (ISO-8601 UTC) |
| `created_at` | TEXT | NOT NULL |
| `updated_at` | TEXT | NOT NULL |
| `sync_id` | TEXT | UNIQUE, NULL |
| `device_id` | TEXT | NOT NULL |
| `is_deleted` | INTEGER | DEFAULT 0 |

### New columns added in v3
| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `company` | TEXT | NULL | Employer or organization |
| `role` | TEXT | NULL | Job title or role |
| `email` | TEXT | NULL | Email address |
| `phone` | TEXT | NULL | Phone number |
| `birthday` | TEXT | NULL | ISO-8601 date string (YYYY-MM-DD) |
| `location` | TEXT | NULL | City/region freeform |
| `tags` | TEXT | NULL | Comma-separated labels, e.g. `"work,mentor"` |
| `relationship_type` | TEXT | NULL | One of: `Friend`, `Family`, `Colleague`, `Mentor`, `Acquaintance`, `Other` |
| `needs_follow_up` | INTEGER | 0 | Boolean flag: 1 = needs follow-up |
| `follow_up_date` | TEXT | NULL | ISO-8601 date string for specific follow-up deadline |

### Constraints and validation rules
- `name` is required (non-empty); all other fields are optional.
- `relationship_type` must be one of the 6 enum values if set; validated in Dart before insert.
- `tags` stored as lowercase comma-separated string. Duplicates stripped before save. Max 20 tags.
- `needs_follow_up` auto-clears (set to 0) when a new `bullet_person_link` is inserted for this person (FR-026).
- `last_interaction_at` is updated (denormalized cache) on every `bullet_person_links` insert for this person.
- Soft-delete only (`is_deleted = 1`). Never physically deleted.

### Indexes (existing, unchanged)
- `idx_people_name ON people(name)`
- `idx_people_updated_at ON people(updated_at)`
- `idx_people_last_interaction ON people(last_interaction_at)`

### New index added in v3
- `idx_people_needs_follow_up ON people(needs_follow_up)` — supports FR-022 filter.

---

## Modified Table: `bullet_person_links`

### Current columns (v2)
| Column | Type | Constraints |
|--------|------|-------------|
| `bullet_id` | TEXT | PK component, FK → bullets.id |
| `person_id` | TEXT | PK component, FK → people.id |
| `created_at` | TEXT | NOT NULL |
| `sync_id` | TEXT | UNIQUE, NULL |
| `device_id` | TEXT | NOT NULL |
| `is_deleted` | INTEGER | DEFAULT 0 |

### New column added in v3
| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `link_type` | TEXT | `'mention'` | How the link was created: `mention` (from @capture bar) or `manual` (from log detail) |

### Primary key
Composite: (`bullet_id`, `person_id`). Supports multiple people per bullet at schema level; UI v1 exposes only first link.

### FK semantics
- Deleting a person → soft-delete all their `bullet_person_links` (isDeleted = 1). Bullets remain. (FR-004)
- Deleting a bullet → soft-delete its `bullet_person_links`. Person record unchanged. (Edge Case)

---

## FTS5 Virtual Table: `people_fts`

### Current columns (v2)
`name`, `notes` (content-table referencing `people`)

### Updated in v3
Add `company` to the indexed columns. The FTS5 table must be rebuilt after upgrade:
```sql
-- Drop old FTS table and triggers, recreate with company
DROP TABLE IF EXISTS people_fts;
CREATE VIRTUAL TABLE people_fts USING fts5(
  name, notes, company,
  content='people', content_rowid='rowid'
);
INSERT INTO people_fts(people_fts) VALUES ('rebuild');
```

### Updated triggers (v3)
Replace all three `people_ai`, `people_ad`, `people_au` triggers to include `company`:
```sql
CREATE TRIGGER people_ai AFTER INSERT ON people BEGIN
  INSERT INTO people_fts(rowid, name, notes, company)
    VALUES (new.rowid, new.name, COALESCE(new.notes, ''), COALESCE(new.company, ''));
END;
```

---

## Relationships

```
people (1) ──────< bullet_person_links >────── (N) bullets
                       linkType: mention | manual
```

- One person can be linked to many bullets.
- One bullet can be linked to many people (schema-level; UI exposes one in v1).
- `bullet_person_links` soft-delete cascades: person delete → links deleted; bullet delete → links deleted.

---

## Dart Model Mapping (drift)

### `People` table class changes
New drift columns in `app/lib/database/tables/people.dart`:
```dart
TextColumn get company => text().nullable()();
TextColumn get role => text().nullable()();
TextColumn get email => text().nullable()();
TextColumn get phone => text().nullable()();
TextColumn get birthday => text().nullable()();
TextColumn get location => text().nullable()();
TextColumn get tags => text().nullable()();
TextColumn get relationshipType => text().nullable()();
IntColumn get needsFollowUp => integer().withDefault(const Constant(0))();
TextColumn get followUpDate => text().nullable()();
```

### `BulletPersonLinks` table class changes
```dart
TextColumn get linkType => text().withDefault(const Constant('mention'))();
```

### Enum helper (Dart, not generated)
```dart
enum RelationshipType {
  friend('Friend'),
  family('Family'),
  colleague('Colleague'),
  mentor('Mentor'),
  acquaintance('Acquaintance'),
  other('Other');

  const RelationshipType(this.displayName);
  final String displayName;

  static RelationshipType? fromString(String? s) =>
      s == null ? null : RelationshipType.values.firstWhereOrNull((e) => e.displayName == s);
}
```

---

## State Transitions

### `needs_follow_up` lifecycle
```
Person created → needsFollowUp = 0
User taps "Mark needs follow-up" → needsFollowUp = 1
New bullet linked to person → needsFollowUp = 0 (auto-cleared, FR-026)
User taps "Clear follow-up" → needsFollowUp = 0
```

### `last_interaction_at` update flow
```
bullet_person_link INSERT (mention or manual)
  → updateLastInteractionAt(personId, now)
  → people.lastInteractionAt = now
  → enqueue person UPDATE sync
```

### Person stale indicator (display-only, derived in Dart)
```
lastInteractionAt = null → "No interactions yet"
now - lastInteractionAt > 30 days → show stale badge
otherwise → show relative date
```

---

## People List Sort/Filter State

Provider state model for `PeopleScreen`:

```dart
enum PeopleSort { lastInteraction, nameAZ, recentlyCreated }

class PeopleFilter {
  final String searchQuery;       // empty = no filter
  final String? relationshipType; // null = all
  final String? tag;              // null = all tags
  final bool needsFollowUpOnly;   // false = show all
}
```

Applied in order:
1. SQL: `ORDER BY` based on `PeopleSort`
2. SQL: `WHERE needs_follow_up = 1` if `needsFollowUpOnly`
3. SQL: `WHERE is_deleted = 0`
4. Dart: filter by `relationshipType` if set
5. Dart: filter by `tag` (comma-split check)
6. Dart: filter by `searchQuery` (FTS5 or LIKE, already reactive via `Stream`)

---

## Migration Script (v2 → v3)

```dart
if (from < 3) {
  // People: add CRM profile fields
  await m.addColumn(people, people.company);
  await m.addColumn(people, people.role);
  await m.addColumn(people, people.email);
  await m.addColumn(people, people.phone);
  await m.addColumn(people, people.birthday);
  await m.addColumn(people, people.location);
  await m.addColumn(people, people.tags);
  await m.addColumn(people, people.relationshipType);
  await m.addColumn(people, people.needsFollowUp);
  await m.addColumn(people, people.followUpDate);

  // BulletPersonLinks: add linkType
  await m.addColumn(bulletPersonLinks, bulletPersonLinks.linkType);

  // FTS5: rebuild people_fts with company column
  await customStatement('DROP TABLE IF EXISTS people_fts');
  await customStatement('''
    CREATE VIRTUAL TABLE people_fts USING fts5(
      name, notes, company,
      content='people', content_rowid='rowid'
    )
  ''');
  await customStatement("INSERT INTO people_fts(people_fts) VALUES ('rebuild')");

  // Drop old FTS triggers and recreate with company
  await customStatement('DROP TRIGGER IF EXISTS people_ai');
  await customStatement('DROP TRIGGER IF EXISTS people_ad');
  await customStatement('DROP TRIGGER IF EXISTS people_au');
  await customStatement('''
    CREATE TRIGGER people_ai AFTER INSERT ON people BEGIN
      INSERT INTO people_fts(rowid, name, notes, company)
        VALUES (new.rowid, new.name, COALESCE(new.notes, ''), COALESCE(new.company, ''));
    END
  ''');
  await customStatement('''
    CREATE TRIGGER people_ad AFTER DELETE ON people BEGIN
      INSERT INTO people_fts(people_fts, rowid, name, notes, company)
        VALUES ('delete', old.rowid, old.name, COALESCE(old.notes, ''), COALESCE(old.company, ''));
    END
  ''');
  await customStatement('''
    CREATE TRIGGER people_au AFTER UPDATE ON people BEGIN
      INSERT INTO people_fts(people_fts, rowid, name, notes, company)
        VALUES ('delete', old.rowid, old.name, COALESCE(old.notes, ''), COALESCE(old.company, ''));
      INSERT INTO people_fts(rowid, name, notes, company)
        VALUES (new.rowid, new.name, COALESCE(new.notes, ''), COALESCE(new.company, ''));
    END
  ''');

  // New index for follow-up filter
  await customStatement(
    'CREATE INDEX IF NOT EXISTS idx_people_needs_follow_up ON people(needs_follow_up)',
  );
}
```
