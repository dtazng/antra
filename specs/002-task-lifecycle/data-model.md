# Data Model: Task Lifecycle & Review Flow

**Branch**: `002-task-lifecycle` | **Date**: 2026-03-10

---

## Schema Changes

### Modified table: `bullets`

New columns added via `ALTER TABLE` in schema migration v1 → v2:

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| `scheduled_date` | TEXT | YES | NULL | YYYY-MM-DD date the user scheduled this task. NULL = not scheduled. |
| `carry_over_count` | INTEGER | NO | 0 | How many times this task has been carried over or kept for today. |
| `completed_at` | TEXT | YES | NULL | ISO 8601 UTC timestamp when the task was completed. |
| `canceled_at` | TEXT | YES | NULL | ISO 8601 UTC timestamp when the task was canceled. |

**Existing status values** (no rename, backward compat):

| DB Value | Semantic Meaning |
|----------|-----------------|
| `open` | Active — eligible for carry-over and weekly review |
| `complete` | Completed — excluded from all queues |
| `cancelled` | Canceled — excluded from all queues |
| `backlog` | Backlog — excluded from queues unless reactivated |
| `migrated` | Deprecated — legacy rows only; new code never writes this |

---

### New table: `task_lifecycle_events`

Append-only event log. One row per lifecycle transition on any task.

```
task_lifecycle_events
├── id           TEXT PK  — client UUID
├── bullet_id    TEXT     — FK → bullets.id (not enforced at DB level, app-enforced)
├── event_type   TEXT     — see event types below
├── metadata     TEXT     — nullable JSON (e.g. {"scheduledDate":"2026-03-15"})
└── occurred_at  TEXT     — ISO 8601 UTC timestamp
```

**Event types**:

| Event Type | When recorded |
|------------|---------------|
| `created` | Task bullet is first inserted |
| `carried_over` | System automatically shows task as carry-over (first time it appears in "From Yesterday") |
| `kept_for_today` | User taps "Keep for Today" — dayId updated to today |
| `scheduled` | User sets a specific future date — `metadata.scheduledDate` populated |
| `moved_to_backlog` | User sends task to backlog |
| `reactivated` | User reactivates a backlog task |
| `entered_weekly_review` | Task first becomes eligible for weekly review (recorded on first query match) |
| `completed` | User marks task complete |
| `canceled` | User cancels the task |
| `converted_to_note` | User converts the task to a note-type bullet |

**Index**: `CREATE INDEX idx_task_events_bullet_id ON task_lifecycle_events(bullet_id)`

---

## Derived Display States

These are computed in `TaskLifecycleService`, never stored:

| Display State | Derivation Rule |
|---------------|----------------|
| `dueToday` | `status='open'` AND `scheduled_date = today` |
| `carriedFromYesterday` | `status='open'` AND `day_logs.date = yesterday` AND `(scheduled_date IS NULL OR scheduled_date <= today)` AND `created_at > (today - 7 days)` |
| `pendingWeeklyReview` | `status='open'` AND `created_at <= (today - 7 days)` AND `(scheduled_date IS NULL OR scheduled_date <= today)` |
| `backlog` | `status='backlog'` |
| `completed` | `status='complete'` |
| `canceled` | `status='cancelled'` |
| `active` | `status='open'` AND no other derived state applies (task is scheduled for a future date, or is in a non-yesterday day) |

**Mutual exclusion**: `carriedFromYesterday` and `pendingWeeklyReview` are mutually exclusive by the `created_at` threshold. A task created within 7 days that is in yesterday's log is `carriedFromYesterday`. A task older than 7 days is `pendingWeeklyReview` regardless of which day it currently belongs to.

---

## Entity Relationships

```
day_logs (1) ─────────── (N) bullets
                                │
                                │ (1)
                                │
                          (N) task_lifecycle_events
```

- Each `bullet` belongs to one `day_log` via `day_id` (mutable — updated on "Keep for Today")
- Each `task_lifecycle_events` row belongs to one `bullet` via `bullet_id`
- `task_lifecycle_events` is append-only; rows are never updated or deleted

---

## State Transition Diagram

```
             ┌─────────────────────────────────────────────────────┐
             │                      ACTIVE (open)                  │
             │  ┌──────────────────────────────────────────────┐   │
             │  │  Sub-states (derived, not stored):           │   │
             │  │  • carriedFromYesterday                       │   │
             │  │  • pendingWeeklyReview                        │   │
             │  │  • dueToday                                   │   │
             │  │  • active (default)                           │   │
             │  └──────────────────────────────────────────────┘   │
             └─────────────────────────────────────────────────────┘
                    │           │          │           │
           keepForToday    schedule    backlog       complete/cancel/convertToNote
                    │           │          │           │
                    ▼           ▼          ▼           ▼
             [tomorrow's  [scheduled  [BACKLOG]   [COMPLETED /
              carry-over]  date view]             CANCELED /
                                                  NOTE (terminal)]
                                 │
                            reactivate
                                 │
                                 ▼
                              ACTIVE
```

---

## Queries

### Q1: Today's active tasks (existing, unchanged)
```sql
SELECT b.* FROM bullets b
INNER JOIN day_logs dl ON dl.id = b.day_id
WHERE dl.date = :today AND b.is_deleted = 0 AND b.type != 'task' OR
      (b.type = 'task' AND b.status NOT IN ('open') -- carry-overs excluded from main list)
ORDER BY b.position ASC
```

Actually cleaner: the main list shows everything for today's day_log; carry-over section is separate.

### Q2: Carry-over tasks ("From Yesterday")
```sql
SELECT b.* FROM bullets b
INNER JOIN day_logs dl ON dl.id = b.day_id
WHERE dl.date = :yesterday
  AND b.type = 'task'
  AND b.status = 'open'
  AND b.is_deleted = 0
  AND (b.scheduled_date IS NULL OR b.scheduled_date <= :today)
  AND b.created_at > :sevenDaysAgo
ORDER BY b.created_at ASC
```

### Q3: Weekly Review eligibility
```sql
SELECT b.* FROM bullets b
WHERE b.type = 'task'
  AND b.status = 'open'
  AND b.is_deleted = 0
  AND b.created_at <= :sevenDaysAgo
  AND (b.scheduled_date IS NULL OR b.scheduled_date <= :today)
ORDER BY b.created_at ASC
```

### Q4: Task lifecycle events for a bullet
```sql
SELECT * FROM task_lifecycle_events
WHERE bullet_id = :bulletId
ORDER BY occurred_at ASC
```

---

## Schema Migration (v1 → v2)

```dart
onUpgrade: (Migrator m, int from, int to) async {
  if (from < 2) {
    // Add new columns to bullets
    await m.addColumn(bullets, bullets.scheduledDate);
    await m.addColumn(bullets, bullets.carryOverCount);
    await m.addColumn(bullets, bullets.completedAt);
    await m.addColumn(bullets, bullets.canceledAt);

    // Create task_lifecycle_events table
    await m.createTable(taskLifecycleEvents);

    // Index for efficient per-bullet event queries
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_task_events_bullet_id '
      'ON task_lifecycle_events(bullet_id)',
    );

    // Index for weekly review query (created_at threshold)
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_bullets_created_at '
      'ON bullets(created_at)',
    );
  }
}
```
