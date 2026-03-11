# Data Model: Carried-Over Tasks and Quick-Action Cards

**Feature**: `005-task-carryover`
**Date**: 2026-03-11
**Schema version**: 4 (unchanged — no migration needed)

---

## Entities

### Bullet (existing, `bullets` table)

All fields relevant to this feature already exist. No new columns.

| Field | Type | Notes |
| --- | --- | --- |
| `id` | TEXT (PK) | Client UUID |
| `dayId` | TEXT (FK → day_logs.id) | Day log the task currently belongs to; updated by `keepForToday` |
| `type` | TEXT | 'task' \| 'note' \| 'event'; `convertToNote` changes this to 'note' |
| `content` | TEXT | Task text |
| `status` | TEXT | 'open' \| 'complete' \| 'cancelled' \| 'backlog' \| 'migrated' |
| `createdAt` | TEXT | ISO 8601 UTC; immutable; used for age calculation |
| `scheduledDate` | TEXT (nullable) | YYYY-MM-DD; null means not scheduled |
| `carryOverCount` | INTEGER | Count of explicit keep-for-today / keep-active actions |
| `completedAt` | TEXT (nullable) | ISO 8601 UTC; set when status→'complete' |
| `canceledAt` | TEXT (nullable) | ISO 8601 UTC; set when status→'cancelled' |
| `updatedAt` | TEXT | LWW sync key; updated on every write |
| `isDeleted` | INTEGER | Soft-delete tombstone |

### TaskLifecycleEvent (existing, `task_lifecycle_events` table)

Append-only. One row per state-change action. No new event types needed.

| Field | Type | Notes |
| --- | --- | --- |
| `id` | TEXT (PK) | Client UUID |
| `bulletId` | TEXT (FK → bullets.id) | Task this event belongs to |
| `eventType` | TEXT | See event type list below |
| `metadata` | TEXT (nullable) | JSON; e.g. `{"scheduledDate":"2026-04-01"}` |
| `occurredAt` | TEXT | ISO 8601 UTC |

### DayLog (existing, `day_logs` table)

Used by the carry-over date-range query. No changes.

| Field | Type | Notes |
| --- | --- | --- |
| `id` | TEXT (PK) | Client UUID |
| `date` | TEXT (UNIQUE) | YYYY-MM-DD; one row per calendar day |

---

## Status Values

| Value | Meaning | In Carried Over? | In Weekly Review? |
| --- | --- | --- | --- |
| `open` | Active, unresolved | Yes (age 1–7d) | Yes (age >7d) |
| `complete` | Done | No | No |
| `cancelled` | Dismissed | No | No |
| `backlog` | Parked | No | No |
| `migrated` | Legacy (pre-v2) | No | No |

---

## Derived Display States (computed at query time, not stored)

| State | Query Condition |
| --- | --- |
| `carried-over` | type='task', status='open', dl.date >= sevenDaysAgo AND dl.date < today, (scheduledDate IS NULL OR scheduledDate <= today), isDeleted=0 |
| `weekly-review` | type='task', status='open', createdAt <= sevenDaysAgo, (scheduledDate IS NULL OR scheduledDate <= today), isDeleted=0 |
| `scheduled` | type='task', status='open', scheduledDate > today |

---

## Lifecycle Event Types

| Event Type | Triggered By |
| --- | --- |
| `created` | Task first captured |
| `completed` | `completeTask()` |
| `canceled` | `cancelTask()` |
| `moved_to_backlog` | `moveToBacklog()` |
| `scheduled` | `scheduleTask()` |
| `kept_for_today` | `keepForToday()` / `moveToThisWeek()` |
| `converted_to_note` | `convertToNote()` |
| `reactivated` | `reactivateTask()` |
| `carried_over` | (informational; can be logged when task first qualifies — optional) |
| `entered_weekly_review` | (informational; can be logged on first appearance in weekly review — optional) |

---

## Age Calculation

Age in days is always computed from `createdAt`:

```
ageDays = today_local_date − date(createdAt_utc_converted_to_local)
```

Display format: compact badge `"Nd"` (e.g., "1d", "3d", "7d").

This value is derived at render time — not stored. It updates each calendar day automatically.

---

## State Transition Diagram

```
                   ┌─────────────────────────────────┐
                   │         status = 'open'          │
                   │   (type = 'task', isDeleted = 0) │
                   └────────────────┬────────────────┘
                                    │
              ┌─────────────────────┼──────────────────────┐
              │                     │                       │
     age 1-7d, dl.date         age > 7d,              scheduledDate
     in [sevenDaysAgo, today)  created_at ≤             > today
              │                sevenDaysAgo                 │
              ▼                     ▼                       ▼
     [carried-over]          [weekly-review]          [scheduled]
      display state           display state           display state
              │                     │                       │
     Quick actions:          Quick actions:          (appears on
     • Complete ─────────────────────────────────► status='complete'
     • Keep for Today ──────────────────────────► dayId → today, count+1
     • Schedule ────────────────────────────────► scheduledDate set
     • Move to Backlog ─────────────────────────► status='backlog'
     • Cancel ──────────────────────────────────► status='cancelled'
     • Convert to Note ─────────────────────────► type='note'
     • Age reaches day 8 ───────────────────────► moves to weekly-review
                                                   (no stored state change)
```
