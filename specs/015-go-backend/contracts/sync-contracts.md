# Sync Protocol Contracts: 015-Go Backend

**Date**: 2026-03-15

---

## Protocol Overview

**Per-entity-type, timestamp-based, latest-write-wins.**

- Client is source of truth for local writes.
- Server assigns canonical timestamps to accepted records.
- Conflict policy: if `server.updated_at > client.updated_at`, push is rejected; server record returned.
- Tombstones: `deleted_at IS NOT NULL` on deleted records; included in pull responses indefinitely.

---

## Supported Entity Types

| entity_type | Push data fields | Pull data fields |
|-------------|-----------------|-----------------|
| `persons` | name, notes, created_at | name, notes, last_interaction_date, created_at |
| `logs` | content, type, status, day_id, device_id, person_ids, created_at | content, type, status, day_id, device_id |
| `follow_ups` | title, due_date, status, snoozed_until, is_recurring, recurrence_interval_days, recurrence_type, log_id, person_id, created_at | title, due_date, status, snoozed_until, completed_at, is_recurring, recurrence_interval_days |

---

## Push Conflict Resolution

1. Client sends `{ id, operation, updated_at, data }`.
2. Server looks up record by `id`:
   - **Not found**: accept unconditionally (new record).
   - **Found, server `updated_at` > client `updated_at`**: reject, return server record as conflict.
   - **Found, server `updated_at` ≤ client `updated_at`**: accept, overwrite with `server_timestamp` as new `updated_at`.
3. For `operation=delete`: same conflict check applies. If server is newer, client should pull first.

### Accepted Response

```json
{ "accepted": 3, "conflicts": [], "server_timestamp": "2026-03-15T10:02:00Z" }
```

### Conflict Response

```json
{
  "accepted": 2,
  "conflicts": [{
    "id": "uuid",
    "reason": "server_newer",
    "server_record": { "id": "uuid", "updated_at": "...", "deleted_at": null, "data": {...} }
  }],
  "server_timestamp": "2026-03-15T10:02:00Z"
}
```

Client MUST accept server record on conflict (server wins).

---

## Pull Protocol

**`GET /v1/sync/{entity_type}/pull?since=ISO8601&limit=200`**

| Param | Default | Notes |
|-------|---------|-------|
| `since` | `1970-01-01T00:00:00Z` | Returns all records on first sync |
| `limit` | `200` | Max records per page |

- Records with `deleted_at != null` are tombstones → client deletes locally.
- `data` is `null` for tombstones.
- `next_cursor` is null (cursor pagination deferred to v2).

---

## Recommended Client Sync Sequence

1. **Pull** all entity types with `since = last_sync_at` (epoch on first sync).
2. Apply server records locally.
3. **Push** all local records modified since `last_sync_at`.
4. Store `server_timestamp` from push response as new `last_sync_at`.

---

## First Sync (Cold Start / DynamoDB Migration)

1. `GET /v1/sync/{type}/pull?since=1970-01-01T00:00:00Z` → empty (no server records yet).
2. `POST /v1/sync/{type}/push` with all local SQLite records → all accepted (no conflicts on empty DB).
3. Store `server_timestamp` as cursor.

---

## Tombstone Lifecycle

1. Client deletes locally → marks `deleted_at` in SQLite.
2. Client pushes `{ id, operation: "delete", updated_at: now }`.
3. Server sets `deleted_at = server_timestamp`.
4. Future pulls return tombstone with `deleted_at` set, `data: null`.
5. Receiving clients delete the record locally.
6. Tombstones are retained indefinitely in v1.
