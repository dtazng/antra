# Contract: TaskLifecycleService

**Type**: Internal service interface (Flutter/Dart)
**File**: `app/lib/services/task_lifecycle_service.dart`

The `TaskLifecycleService` is a pure Dart class (no Flutter imports) that owns all task lifecycle logic. It is the single point of truth for state transitions. No UI code, DAO, or provider may directly write task status or lifecycle events — all writes go through this service.

---

## Constructor

```dart
TaskLifecycleService({
  required AppDatabase db,
  String deviceId = 'local',
})
```

---

## Methods

### `completeTask(String bulletId)`
Marks a task complete. Records a `completed` lifecycle event.

**Preconditions**: Task exists, status is `open`, type is `task`.
**Postconditions**: `bullets.status = 'complete'`, `bullets.completed_at` set, event appended.
**Throws**: `StateError` if task not found or already complete/canceled.

---

### `cancelTask(String bulletId)`
Cancels a task. Records a `canceled` lifecycle event.

**Preconditions**: Task exists, status is `open` or `backlog`.
**Postconditions**: `bullets.status = 'cancelled'`, `bullets.canceled_at` set, event appended.

---

### `keepForToday(String bulletId, String todayDate)`
Moves a carry-over task into today's log. Records a `kept_for_today` lifecycle event. Increments `carry_over_count`.

**Preconditions**: Task exists, status is `open`, task is in yesterday's log or is a valid carry-over.
**Postconditions**: `bullets.day_id` updated to today's day_log id, `carry_over_count` incremented, event appended.

---

### `scheduleTask(String bulletId, String date)`
Sets a future scheduled date on a task. Records a `scheduled` lifecycle event with `metadata: {"scheduledDate": date}`.

**Preconditions**: Task exists, status is `open` or `backlog`. Date must be today or in the future (YYYY-MM-DD).
**Postconditions**: `bullets.scheduled_date = date`, event appended.

---

### `moveToBacklog(String bulletId)`
Moves a task to backlog. Records a `moved_to_backlog` lifecycle event.

**Preconditions**: Task exists, status is `open`.
**Postconditions**: `bullets.status = 'backlog'`, `bullets.scheduled_date = null` (clears any schedule), event appended.

---

### `reactivateTask(String bulletId, String todayDate)`
Reactivates a backlog task, moving it into today's log. Records a `reactivated` lifecycle event.

**Preconditions**: Task exists, status is `backlog`.
**Postconditions**: `bullets.status = 'open'`, `bullets.day_id` updated to today, event appended.

---

### `convertToNote(String bulletId)`
Changes a task to a note. Records a `converted_to_note` lifecycle event. Terminal — task is permanently excluded from all task queues.

**Preconditions**: Task exists, type is `task`, status is `open` or `backlog`.
**Postconditions**: `bullets.type = 'note'`, `bullets.status = 'open'`, event appended.

---

### `moveToThisWeek(String bulletId, String todayDate)`
Moves a weekly review task back into the active daily flow. Records a `kept_for_today` lifecycle event. Increments `carry_over_count`. Functionally identical to `keepForToday`.

**Preconditions**: Task exists, is eligible for weekly review.
**Postconditions**: Same as `keepForToday`.

---

### `recordCarryOverSeen(String bulletId)` *(optional, best-effort)*
Records a `carried_over` lifecycle event the first time a task appears in the "From Yesterday" section. Called by the DAO query when returning carry-over tasks. Idempotent — only records the event once per day.

---

## Streams (provided by TaskLifecycleDao)

The service exposes read operations via DAO streams. The service itself does not expose streams; the Riverpod providers watch the DAO directly.

| Stream | Source |
|--------|--------|
| `watchCarryOverTasks(String yesterday, String today, String sevenDaysAgo)` | `TaskLifecycleDao` |
| `watchWeeklyReviewTasks(String today, String sevenDaysAgo)` | `TaskLifecycleDao` |
| `watchLifecycleEvents(String bulletId)` | `TaskLifecycleDao` |
