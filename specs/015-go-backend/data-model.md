# Data Model: 015-Go Backend with PostgreSQL

**Date**: 2026-03-15

---

## Entity Relationship Summary

```
users ─┬── refresh_tokens (1:N)
       ├── persons (1:N)
       ├── logs (1:N)
       ├── follow_ups (1:N)
       ├── notifications (1:N)
       ├── device_tokens (1:N)
       └── user_settings (1:1)

logs ──── log_person_links (M:N) ─── persons
follow_ups ──── logs (N:1, optional)
follow_ups ──── persons (N:1, optional)
notifications ──── follow_ups (N:1, optional)
notification_deliveries ──── notifications (N:1)
notification_deliveries ──── device_tokens (N:1, optional)
sync_metadata ──── users (N:1)
```

---

## Tables

### users

| Column | Type | Constraints |
|--------|------|-------------|
| id | UUID | PK, default gen_random_uuid() |
| email | TEXT | NOT NULL, UNIQUE |
| password_hash | TEXT | NOT NULL |
| created_at | TIMESTAMPTZ | NOT NULL, default now() |
| updated_at | TIMESTAMPTZ | NOT NULL, default now() |
| deleted_at | TIMESTAMPTZ | nullable (soft delete) |

**Indexes**: `ix_users_email` (unique). Partial index `WHERE deleted_at IS NULL` for active-user queries.

---

### refresh_tokens

| Column | Type | Constraints |
|--------|------|-------------|
| id | UUID | PK (token = UUID itself) |
| user_id | UUID | FK → users.id ON DELETE CASCADE |
| expires_at | TIMESTAMPTZ | NOT NULL |
| created_at | TIMESTAMPTZ | NOT NULL, default now() |

**Indexes**: `ix_refresh_tokens_user_id`, `ix_refresh_tokens_expires_at`.

**Notes**: Refresh token is the UUID primary key. Logout = DELETE row. Expired rows pruned by background job.

---

### persons

| Column | Type | Constraints |
|--------|------|-------------|
| id | UUID | PK (client-generated) |
| user_id | UUID | FK → users.id ON DELETE CASCADE |
| name | TEXT | NOT NULL |
| notes | TEXT | nullable |
| last_interaction_date | DATE | nullable |
| search_vector | TSVECTOR | GENERATED ALWAYS AS to_tsvector('english', coalesce(name,'') \|\| ' ' \|\| coalesce(notes,'')) STORED |
| created_at | TIMESTAMPTZ | NOT NULL, default now() |
| updated_at | TIMESTAMPTZ | NOT NULL, default now() |
| deleted_at | TIMESTAMPTZ | nullable (tombstone) |

**Indexes**: `(user_id, deleted_at)`, `(user_id, name)`, `(user_id, last_interaction_date)`, GIN on `search_vector`.

---

### logs

| Column | Type | Constraints |
|--------|------|-------------|
| id | UUID | PK (client-generated) |
| user_id | UUID | FK → users.id ON DELETE CASCADE |
| content | TEXT | NOT NULL |
| type | TEXT | NOT NULL, default 'note' |
| status | TEXT | NOT NULL, default 'open' |
| day_id | DATE | NOT NULL |
| device_id | TEXT | NOT NULL |
| search_vector | TSVECTOR | GENERATED ALWAYS AS to_tsvector('english', coalesce(content,'')) STORED |
| created_at | TIMESTAMPTZ | NOT NULL, default now() |
| updated_at | TIMESTAMPTZ | NOT NULL, default now() |
| deleted_at | TIMESTAMPTZ | nullable (tombstone) |

**Indexes**: `(user_id, day_id DESC)`, `(user_id, deleted_at)`, `(user_id, updated_at)`, GIN on `search_vector`.

**Valid `type` values**: `note`, `task`, `interaction`
**Valid `status` values**: `open`, `done`, `dismissed`

---

### log_person_links

| Column | Type | Constraints |
|--------|------|-------------|
| id | UUID | PK, default gen_random_uuid() |
| log_id | UUID | FK → logs.id ON DELETE CASCADE |
| person_id | UUID | FK → persons.id ON DELETE CASCADE |
| user_id | UUID | FK → users.id ON DELETE CASCADE |
| link_type | TEXT | NOT NULL, default 'mention' |
| created_at | TIMESTAMPTZ | NOT NULL, default now() |

**Constraints**: UNIQUE(log_id, person_id).
**Indexes**: `ix_lpl_log_id`, `ix_lpl_person_id`.

---

### follow_ups

| Column | Type | Constraints |
|--------|------|-------------|
| id | UUID | PK (client-generated) |
| user_id | UUID | FK → users.id ON DELETE CASCADE |
| log_id | UUID | FK → logs.id ON DELETE SET NULL, nullable |
| person_id | UUID | FK → persons.id ON DELETE SET NULL, nullable |
| title | TEXT | NOT NULL |
| due_date | DATE | NOT NULL |
| status | TEXT | NOT NULL, default 'pending' |
| snoozed_until | DATE | nullable |
| completed_at | TIMESTAMPTZ | nullable |
| is_recurring | BOOLEAN | NOT NULL, default false |
| recurrence_interval_days | INTEGER | nullable |
| recurrence_type | TEXT | nullable |
| source_type | TEXT | nullable |
| created_at | TIMESTAMPTZ | NOT NULL, default now() |
| updated_at | TIMESTAMPTZ | NOT NULL, default now() |
| deleted_at | TIMESTAMPTZ | nullable (tombstone) |

**Indexes**: `(user_id, status, due_date)`, `(user_id, deleted_at)`, `(user_id, updated_at)`, `ix_fu_person_id`.

**Valid `status` values**: `pending`, `due`, `snoozed`, `completed`, `dismissed`
**Valid `recurrence_type` values**: `interval`, `post_completion`

**State machine**:
```
pending ──► due         job: due_date ≤ today AND (snoozed_until IS NULL OR snoozed_until ≤ today)
snoozed ──► due         job: snoozed_until ≤ today
due ──────► snoozed     user: PATCH snoozed_until
due ──────► completed   user: PATCH status=completed → triggers new follow_up if is_recurring
due ──────► dismissed   user: PATCH status=dismissed
```

---

### notifications

| Column | Type | Constraints |
|--------|------|-------------|
| id | UUID | PK, default gen_random_uuid() |
| user_id | UUID | FK → users.id ON DELETE CASCADE |
| follow_up_id | UUID | FK → follow_ups.id ON DELETE SET NULL, nullable |
| title | TEXT | NOT NULL |
| body | TEXT | NOT NULL |
| status | TEXT | NOT NULL, default 'scheduled' |
| retry_count | INTEGER | NOT NULL, default 0 |
| max_retries | INTEGER | NOT NULL, default 3 |
| created_at | TIMESTAMPTZ | NOT NULL, default now() |
| updated_at | TIMESTAMPTZ | NOT NULL, default now() |

**Indexes**: `(user_id, status)`, `(user_id, created_at DESC)`, `(status, retry_count)`.

**Valid `status` values**: `scheduled`, `sent`, `failed`, `dismissed`

---

### notification_deliveries

| Column | Type | Constraints |
|--------|------|-------------|
| id | UUID | PK, default gen_random_uuid() |
| notification_id | UUID | FK → notifications.id ON DELETE CASCADE |
| device_token_id | UUID | FK → device_tokens.id ON DELETE SET NULL, nullable |
| status | TEXT | NOT NULL |
| error_message | TEXT | nullable |
| attempted_at | TIMESTAMPTZ | NOT NULL, default now() |

**Indexes**: `ix_nd_notification_id`.

---

### device_tokens

| Column | Type | Constraints |
|--------|------|-------------|
| id | UUID | PK, default gen_random_uuid() |
| user_id | UUID | FK → users.id ON DELETE CASCADE |
| token | TEXT | NOT NULL, UNIQUE |
| platform | TEXT | NOT NULL |
| is_active | BOOLEAN | NOT NULL, default true |
| created_at | TIMESTAMPTZ | NOT NULL, default now() |
| updated_at | TIMESTAMPTZ | NOT NULL, default now() |

**Indexes**: `(user_id, is_active)`.
**Valid `platform` values**: `ios`, `android`

---

### user_settings

| Column | Type | Constraints |
|--------|------|-------------|
| id | UUID | PK, default gen_random_uuid() |
| user_id | UUID | FK → users.id ON DELETE CASCADE, UNIQUE |
| notifications_enabled | BOOLEAN | NOT NULL, default true |
| default_follow_up_days | INTEGER | NOT NULL, default 7 |
| inactivity_follow_ups_enabled | BOOLEAN | NOT NULL, default false |
| inactivity_threshold_days | INTEGER | NOT NULL, default 90 |
| created_at | TIMESTAMPTZ | NOT NULL, default now() |
| updated_at | TIMESTAMPTZ | NOT NULL, default now() |

**Notes**: Auto-created on user registration. UNIQUE(user_id) enforces 1:1.

---

### sync_metadata

| Column | Type | Constraints |
|--------|------|-------------|
| id | UUID | PK, default gen_random_uuid() |
| user_id | UUID | FK → users.id ON DELETE CASCADE |
| entity_type | TEXT | NOT NULL |
| device_id | TEXT | NOT NULL |
| last_sync_at | TIMESTAMPTZ | NOT NULL |
| updated_at | TIMESTAMPTZ | NOT NULL, default now() |

**Constraints**: UNIQUE(user_id, entity_type, device_id).
**Valid `entity_type` values**: `persons`, `logs`, `follow_ups`

---

## sqlc Query Map

Key queries that sqlc will generate typed functions for:

| Query | Table | Description |
|-------|-------|-------------|
| GetUserByEmail | users | Login lookup |
| CreateUser | users | Registration |
| SoftDeleteUser | users | Account deletion |
| CreateRefreshToken | refresh_tokens | Login/register |
| GetRefreshToken | refresh_tokens | Token exchange |
| DeleteRefreshToken | refresh_tokens | Logout |
| UpsertPerson | persons | Sync push |
| SoftDeletePerson | persons | Sync push delete |
| GetPersonsByUpdatedSince | persons | Sync pull |
| SearchPersons | persons | FTS search |
| UpsertLog | logs | Sync push |
| SoftDeleteLog | logs | Sync push delete |
| GetLogsByUpdatedSince | logs | Sync pull |
| ReplaceLogPersonLinks | log_person_links | Log upsert |
| UpsertFollowUp | follow_ups | Sync push |
| GetDueFollowUps | follow_ups | Background job |
| MarkFollowUpsDue | follow_ups | Background job update |
| CreateNotification | notifications | Background job |
| GetPendingNotifications | notifications | Notification job |
| CreateDelivery | notification_deliveries | Notification job |
| GetActiveDeviceTokens | device_tokens | Notification job |
| GetOrCreateUserSettings | user_settings | Registration + GET /settings |
| UpdateUserSettings | user_settings | PATCH /settings |
| UpsertSyncMetadata | sync_metadata | Post-sync |

---

## Migration Strategy (DynamoDB → PostgreSQL)

**Cold migration** per Assumption A-003:
1. Deploy new Go backend with PostgreSQL.
2. Mobile app update points to new backend URL.
3. On first sync: client pushes all local SQLite records (`since=epoch` pull returns empty, then full push).
4. DynamoDB kept read-only for 90 days before decommission.

Goose migration file `00001_initial_schema.sql` creates all 11 tables.
