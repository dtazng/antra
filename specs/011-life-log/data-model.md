# Data Model: Life Log & Follow-Up System

**Branch**: `011-life-log` | **Date**: 2026-03-13

---

## Schema Change Summary

**Migration**: version 4 → 5 (additive — no data loss)

**Table modified**: `bullets` — 5 new nullable columns added

**Tables unchanged**: `people`, `bullet_person_links`, `day_logs`, `tags`, `bullet_tag_links`, `pending_sync`, `conflict_records`, `task_lifecycle_events`

**No new tables.**

---

## Bullets Table — New Columns (v5 migration)

```sql
ALTER TABLE bullets ADD COLUMN follow_up_date TEXT;
ALTER TABLE bullets ADD COLUMN follow_up_status TEXT;
ALTER TABLE bullets ADD COLUMN follow_up_snoozed_until TEXT;
ALTER TABLE bullets ADD COLUMN follow_up_completed_at TEXT;
ALTER TABLE bullets ADD COLUMN source_id TEXT;
```

### Column Definitions

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `follow_up_date` | TEXT (ISO date YYYY-MM-DD) | yes | Scheduled follow-up date. Null = no follow-up attached. |
| `follow_up_status` | TEXT | yes | `'pending'` \| `'done'` \| `'snoozed'` \| `'dismissed'`. Null = no follow-up. |
| `follow_up_snoozed_until` | TEXT (ISO date YYYY-MM-DD) | yes | Re-surface date when status = `'snoozed'`. |
| `follow_up_completed_at` | TEXT (ISO UTC timestamp) | yes | Set when status transitions to `'done'`. |
| `source_id` | TEXT (FK → bullets.id) | yes | Set only on completion event bullets (`type = 'completion_event'`). Points to the originating log entry. |

---

## Bullet Types (existing column — extended interpretation)

The existing `type` column (`'task' | 'note' | 'event'`) gains a new value:

| Value | Meaning |
|-------|---------|
| `'note'` | Standard log entry (the primary type going forward) |
| `'task'` | Legacy type — treated as log entry in all new UI |
| `'event'` | Legacy type — treated as log entry in all new UI |
| `'completion_event'` | **New** — created when a follow-up is marked Done. Carries `source_id`. |

---

## Entity Models (Dart)

### TimelineEntry (discriminated union — new model)

```dart
// app/lib/models/timeline_entry.dart
sealed class TimelineEntry {
  const TimelineEntry();
}

class LogEntryItem extends TimelineEntry {
  const LogEntryItem({
    required this.bulletId,
    required this.content,
    required this.createdAt,
    this.personId,
    this.personName,
    this.followUpDate,
    this.followUpStatus,
  });

  final String bulletId;
  final String content;
  final DateTime createdAt;
  final String? personId;
  final String? personName;
  final String? followUpDate;      // ISO date string
  final String? followUpStatus;    // pending|done|snoozed|dismissed
}

class CompletionEventItem extends TimelineEntry {
  const CompletionEventItem({
    required this.bulletId,
    required this.content,
    required this.createdAt,
    required this.sourceId,
    this.personId,
    this.personName,
  });

  final String bulletId;
  final String content;     // e.g. "Followed up with Anna"
  final DateTime createdAt;
  final String sourceId;    // FK → original LogEntry bulletId
  final String? personId;
  final String? personName;
}
```

### TimelineDay (grouping model — new)

```dart
class TimelineDay {
  const TimelineDay({required this.label, required this.date, required this.entries});

  final String label;               // "Today" | "Yesterday" | "Mar 12"
  final DateTime date;              // normalized to midnight local time
  final List<TimelineEntry> entries; // sorted newest-first within day
}
```

### NeedsAttentionItem (surface model — new)

```dart
// app/lib/models/needs_attention_item.dart
class NeedsAttentionItem {
  const NeedsAttentionItem({
    required this.bulletId,
    required this.content,
    required this.followUpDate,
    required this.followUpStatus,
    this.personId,
    this.personName,
  });

  final String bulletId;
  final String content;         // original log entry text (context for user)
  final String followUpDate;    // ISO date string
  final String followUpStatus;  // always 'pending' in this view
  final String? personId;
  final String? personName;
}
```

---

## DAO Query Additions (BulletsDao)

### watchTimelineEntries()

```dart
// Watches ALL non-deleted bullets (log entries + completion events),
// ordered by createdAt DESC. Excludes type='task' with status='open'
// (legacy tasks — treated as notes but not shown in the new timeline).
Stream<List<Bullet>> watchTimelineEntries();
```

### watchPendingFollowUps()

```dart
// Watches bullets where:
//   follow_up_status = 'pending' AND follow_up_date <= today
// OR
//   follow_up_status = 'snoozed' AND follow_up_snoozed_until <= today
// Ordered by follow_up_date ASC (earliest first).
Stream<List<Bullet>> watchPendingFollowUps(String today);
```

### insertCompletionEvent()

```dart
// Creates a new bullet with type = 'completion_event',
// sourceId = originalBulletId, content = "Followed up with [name]",
// and updates the source bullet's followUpStatus to 'done'.
Future<void> insertCompletionEvent({
  required String sourceId,
  required String content,
  required String dayId,  // createdAt.substring(0,10)
});
```

### updateFollowUpStatus()

```dart
Future<void> updateFollowUpStatus(
  String bulletId,
  String status, {
  String? snoozedUntil,
});
```

### addFollowUpToEntry()

```dart
Future<void> addFollowUpToEntry(String bulletId, String followUpDate);
```

---

## State Transitions — FollowUp Status

```
null (no follow-up)
  │
  └─ addFollowUp(date) → pending
                              │
               ┌─────────────┼─────────────┐
               ▼             ▼             ▼
             done          snoozed      dismissed
          (→ creates        │
        CompletionEvent)    └─ snoozedUntil reached → pending
```

---

## People Table — No Changes

`people.followUpDate` and `people.needsFollowUp` columns remain but are superseded by the new bullet-level follow-up system. They are not removed (additive policy) but are no longer populated by new code.

---

## Existing Tables — No Changes

- `day_logs` — retained; no longer written for new bullets (see Research Decision 3)
- `task_lifecycle_events` — retained but no new events written (task lifecycle removed from UI)
- All other tables unchanged
