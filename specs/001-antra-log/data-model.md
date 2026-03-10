# Data Model: Antra Log (Revised — Flutter + DynamoDB)

**Branch**: `001-antra-log` | **Date**: 2026-03-09
**Spec**: [spec.md](spec.md) | **Research**: [research.md](research.md)

Two schemas are defined here: the **local SQLite schema** (drift, on-device) and the
**DynamoDB schema** (AWS, sync store). The local schema is the source of truth; DynamoDB
stores opaque JSON blobs for sync. FTS lives in local SQLite only.

---

## Part 1: Local SQLite Schema (drift)

All tables include sync metadata columns. Soft-delete via `is_deleted` is universal.
`updated_at` is an ISO 8601 UTC string used for LWW conflict detection.

### Entity Relationship Overview

```
DayLog ──────────< Bullet >────────────< BulletPersonLink >──── Person
                     │                                              │
                     └──< BulletTagLink >──── Tag         [reminder_cadence_days]
                     │
                     └── type: task/note/event
                         status: open/complete/cancelled/migrated

Collection ──── filter_rules (JSON)
Review ──── period_type: week/month
ConflictRecord ──── entity_type + entity_id → any entity
PendingSync ──── entity_type + entity_id → any entity
```

---

### Table: day_logs

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | TEXT (UUID) | PRIMARY KEY | Client-generated |
| `date` | TEXT | NOT NULL, UNIQUE | Calendar date `YYYY-MM-DD` |
| `created_at` | TEXT | NOT NULL | ISO 8601 UTC |
| `updated_at` | TEXT | NOT NULL | ISO 8601 UTC; used for LWW |
| `sync_id` | TEXT | NULLABLE, UNIQUE | Server-assigned UUID after first push |
| `device_id` | TEXT | NOT NULL | Device that last wrote |
| `is_deleted` | INTEGER | DEFAULT 0 | Soft-delete tombstone |

**Drift table class**: `DayLogs`
**Indexes**: `date` (unique), `updated_at`

---

### Table: bullets

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | TEXT (UUID) | PRIMARY KEY | Client-generated |
| `day_id` | TEXT | NOT NULL, FK → day_logs.id | |
| `type` | TEXT | NOT NULL | `task` \| `note` \| `event` |
| `content` | TEXT | NOT NULL | Plain text content |
| `status` | TEXT | NOT NULL | `open` \| `complete` \| `cancelled` \| `migrated` |
| `position` | INTEGER | NOT NULL | Display order within day |
| `migrated_to_id` | TEXT | NULLABLE, FK → bullets.id | Set when `status = migrated` |
| `encryption_enabled` | INTEGER | DEFAULT 0 | 1 = E2E encrypted (Pro) |
| `created_at` | TEXT | NOT NULL | ISO 8601 UTC; immutable |
| `updated_at` | TEXT | NOT NULL | ISO 8601 UTC; updated on any field change |
| `sync_id` | TEXT | NULLABLE, UNIQUE | |
| `device_id` | TEXT | NOT NULL | |
| `is_deleted` | INTEGER | DEFAULT 0 | |

**Drift table class**: `Bullets`
**Indexes**: `day_id`, `updated_at`, `type`, `status`

**FTS5 virtual table** (`bullets_fts`, created via raw SQL migration):
```sql
CREATE VIRTUAL TABLE bullets_fts USING fts5(content, content='bullets', content_rowid='rowid');
```

**Invariants**:
- `status` is only meaningful for `type = 'task'`. Notes and events always have `status = open`.
- `migrated_to_id` MUST only be set when `status = 'migrated'`.
- Default `type` is `note` when unspecified; default `status` is `open`.

---

### Table: people

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | TEXT (UUID) | PRIMARY KEY | |
| `name` | TEXT | NOT NULL | Display name |
| `notes` | TEXT | NULLABLE | Context notes |
| `reminder_cadence_days` | INTEGER | NULLABLE | Days between check-in reminders |
| `last_interaction_at` | TEXT | NULLABLE | ISO 8601 UTC; denormalized cache |
| `created_at` | TEXT | NOT NULL | |
| `updated_at` | TEXT | NOT NULL | |
| `sync_id` | TEXT | NULLABLE, UNIQUE | |
| `device_id` | TEXT | NOT NULL | |
| `is_deleted` | INTEGER | DEFAULT 0 | |

**Drift table class**: `People`
**Indexes**: `name`, `updated_at`, `last_interaction_at`

**FTS5 virtual table** (`people_fts`):
```sql
CREATE VIRTUAL TABLE people_fts USING fts5(name, notes, content='people', content_rowid='rowid');
```

---

### Table: bullet_person_links

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `bullet_id` | TEXT | NOT NULL, FK → bullets.id | |
| `person_id` | TEXT | NOT NULL, FK → people.id | |
| `created_at` | TEXT | NOT NULL | |
| `sync_id` | TEXT | NULLABLE, UNIQUE | |
| `device_id` | TEXT | NOT NULL | |
| `is_deleted` | INTEGER | DEFAULT 0 | |

**Primary key**: (`bullet_id`, `person_id`)

---

### Table: tags

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | TEXT (UUID) | PRIMARY KEY | |
| `name` | TEXT | NOT NULL, UNIQUE | Normalized lowercase |
| `created_at` | TEXT | NOT NULL | |
| `sync_id` | TEXT | NULLABLE, UNIQUE | |
| `device_id` | TEXT | NOT NULL | |
| `is_deleted` | INTEGER | DEFAULT 0 | |

---

### Table: bullet_tag_links

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `bullet_id` | TEXT | NOT NULL, FK → bullets.id | |
| `tag_id` | TEXT | NOT NULL, FK → tags.id | |
| `created_at` | TEXT | NOT NULL | |
| `sync_id` | TEXT | NULLABLE, UNIQUE | |
| `device_id` | TEXT | NOT NULL | |
| `is_deleted` | INTEGER | DEFAULT 0 | |

**Primary key**: (`bullet_id`, `tag_id`)

---

### Table: collections

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | TEXT (UUID) | PRIMARY KEY | |
| `name` | TEXT | NOT NULL | |
| `description` | TEXT | NULLABLE | |
| `filter_rules` | TEXT | NOT NULL | JSON array of filter rule objects |
| `position` | INTEGER | NOT NULL | Display order |
| `created_at` | TEXT | NOT NULL | |
| `updated_at` | TEXT | NOT NULL | |
| `sync_id` | TEXT | NULLABLE, UNIQUE | |
| `device_id` | TEXT | NOT NULL | |
| `is_deleted` | INTEGER | DEFAULT 0 | |

**Filter rule JSON schema**:
```json
[
  { "type": "tag", "value": "work" },
  { "type": "person", "personId": "uuid" },
  { "type": "bullet_type", "value": "task" },
  { "type": "date_range", "from": "2026-01-01", "to": "2026-03-31" }
]
```

---

### Table: reviews

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | TEXT (UUID) | PRIMARY KEY | |
| `period_type` | TEXT | NOT NULL | `week` \| `month` |
| `start_date` | TEXT | NOT NULL | `YYYY-MM-DD` |
| `end_date` | TEXT | NOT NULL | `YYYY-MM-DD` |
| `summary_notes` | TEXT | NULLABLE | |
| `completed_at` | TEXT | NULLABLE | NULL = in-progress |
| `created_at` | TEXT | NOT NULL | |
| `updated_at` | TEXT | NOT NULL | |
| `sync_id` | TEXT | NULLABLE, UNIQUE | |
| `device_id` | TEXT | NOT NULL | |
| `is_deleted` | INTEGER | DEFAULT 0 | |

---

### Table: conflict_records (local only — never synced)

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | TEXT (UUID) | PRIMARY KEY | |
| `entity_type` | TEXT | NOT NULL | `bullet` \| `person` \| `tag` \| etc. |
| `entity_id` | TEXT | NOT NULL | ID of the conflicting entity |
| `local_snapshot` | TEXT | NOT NULL | JSON snapshot of the local version |
| `remote_snapshot` | TEXT | NOT NULL | JSON snapshot of the remote version (winner) |
| `detected_at` | TEXT | NOT NULL | ISO 8601 UTC |
| `resolved_at` | TEXT | NULLABLE | NULL = unresolved |
| `resolution` | TEXT | NULLABLE | `kept_remote` \| `restored_local` \| `dismissed` |

---

### Table: pending_sync (local only — never synced)

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | TEXT (UUID) | PRIMARY KEY | |
| `entity_type` | TEXT | NOT NULL | |
| `entity_id` | TEXT | NOT NULL | |
| `operation` | TEXT | NOT NULL | `create` \| `update` \| `delete` |
| `payload` | TEXT | NOT NULL | JSON-serialized entity snapshot |
| `created_at` | TEXT | NOT NULL | |
| `retry_count` | INTEGER | DEFAULT 0 | |
| `last_error` | TEXT | NULLABLE | |
| `is_synced` | INTEGER | DEFAULT 0 | 1 = uploaded; row deleted after success |

---

### drift Migration Plan

| Migration ID | Description |
|-------------|-------------|
| `v1_core_tables` | Create `day_logs`, `bullets`, `people` |
| `v1_link_tables` | Create `bullet_person_links`, `bullet_tag_links`, `tags` |
| `v1_fts_tables` | Create `bullets_fts` and `people_fts` FTS5 virtual tables (raw SQL) |
| `v1_collections` | Create `collections` |
| `v1_reviews` | Create `reviews` |
| `v1_sync_tables` | Create `pending_sync`, `conflict_records` |
| `v1_indexes` | Create all performance indexes |
| `v2_encryption_flag` | Add `encryption_enabled` to `bullets` (Pro E2E feature) |

---

## Part 2: DynamoDB Schema (AWS Sync Store)

DynamoDB stores only opaque sync blobs. The server never parses `data` content.
All business logic and FTS live in the local SQLite database.

### Table: `antra_sync`

**Capacity mode**: On-demand (pay-per-request) at launch; switch to provisioned at >10K users.

**Primary keys**:

| Key | Attribute | Type | Value format |
|-----|-----------|------|--------------|
| PK | `pk` | String | `USER#{cognitoUserId}` |
| SK | `sk` | String | `ENTITY#{entityType}#{entityId}` |

**Item attributes**:

| Attribute | Type | Required | Notes |
|-----------|------|----------|-------|
| `pk` | String | YES | `USER#{userId}` |
| `sk` | String | YES | `ENTITY#{type}#{id}` |
| `syncId` | String | YES | Server-assigned UUID (also stored locally) |
| `entityType` | String | YES | `bullet` \| `person` \| `tag` \| `bullet_person_link` \| etc. |
| `entityId` | String | YES | Client UUID |
| `data` | String | YES | JSON blob (opaque; AES-encrypted if E2E enabled) |
| `updatedAt` | String | YES | ISO 8601 UTC; sort key for GSI1 |
| `deviceId` | String | YES | |
| `isDeleted` | Boolean | YES | Soft-delete flag |
| `encryptionEnabled` | Boolean | YES | Signals server to never attempt parsing |
| `version` | Number | NO | Incrementing counter for debugging |
| `ttl` | Number | NO | Unix timestamp; DynamoDB auto-expires soft-deleted records after 90 days |

**GSI1 — Delta Sync Index**:

| Key | Attribute | Value |
|-----|-----------|-------|
| GSI1PK | `userId` | `{cognitoUserId}` (plain, not prefixed) |
| GSI1SK | `updatedAt` | ISO 8601 UTC string |

Projection: ALL (required for sync payload reconstruction)

**Query for delta sync pull**:
```
GSI1: KeyConditionExpression = "userId = :uid AND updatedAt > :lastSync"
Limit = 500
ExclusiveStartKey = <cursor from previous page>
```

**Example item**:
```json
{
  "pk": "USER#a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "sk": "ENTITY#bullet#b1b2c3d4-0000-0000-0000-000000000001",
  "syncId": "s1b2c3d4-0000-0000-0000-000000000001",
  "entityType": "bullet",
  "entityId": "b1b2c3d4-0000-0000-0000-000000000001",
  "userId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "data": "{\"type\":\"note\",\"content\":\"Coffee with Alice\",\"status\":\"open\"}",
  "updatedAt": "2026-03-09T10:15:00Z",
  "deviceId": "device-uuid-123",
  "isDeleted": false,
  "encryptionEnabled": false,
  "version": 3,
  "ttl": null
}
```

**TTL policy**: When `isDeleted = true`, set `ttl = now + 90 days` (Unix timestamp).
DynamoDB will automatically remove the tombstone record after 90 days. This prevents
indefinite accumulation of deleted records while still propagating deletes to all devices
that sync within 90 days.
