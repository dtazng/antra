# Research: Task Lifecycle & Review Flow

**Branch**: `002-task-lifecycle` | **Date**: 2026-03-10

---

## Decision 1: Task identity — mutate in place vs. duplicate

**Decision**: Tasks are mutated in place. No duplicate rows are created.

**Rationale**: The existing `migrateBullet()` in `bullets_dao.dart` creates a new bullet row and marks the source as `status='migrated'`. The new spec explicitly forbids this. Instead, lifecycle transitions update the single original row and append an event to `task_lifecycle_events`. The task's `dayId` (FK to `day_logs`) is updated when the user "keeps" a task for today — this is the carry-over action.

**Alternatives considered**:
- Keep the duplicate approach with a chain pointer (`migratedToId`). Rejected because it splits history across multiple rows and makes timeline reconstruction complex.
- Store the "current day" as a separate denormalized column instead of updating `dayId`. Rejected because `dayId` is already the FK for ownership and updating it is simpler than maintaining a redundant field.

---

## Decision 2: Lifecycle history — dedicated event log table

**Decision**: New `task_lifecycle_events` table. Append-only. One row per lifecycle transition.

**Rationale**: Storing history in the bullets row (e.g., a JSON blob in a `history` column) would make querying and syncing complex. A separate table with one event per row is idiomatic SQLite, efficient to query, and naturally append-only. Drift's typed DAOs work cleanly with it.

**Alternatives considered**:
- JSON blob column on `bullets`. Rejected: not queryable, not syncable without special handling, violates single-responsibility.
- Derive history from `updated_at` timestamps only. Rejected: `updated_at` alone cannot reconstruct the type of event that occurred.

---

## Decision 3: Derived display states — computed in service layer, not stored

**Decision**: Display states (`dueToday`, `carriedFromYesterday`, `pendingWeeklyReview`) are computed at the service layer from the task's stored fields. They are never stored in the database.

**Rationale**: Stored derived state requires synchronization logic to stay consistent. Computed state is always correct by construction. For a local-first app with offline writes, stored derived state would need to be recomputed on startup anyway. The service queries are efficient (date string comparisons on indexed columns).

**Alternatives considered**:
- Store a `displayState` column on `bullets`. Rejected: requires update logic on every state change, adds sync complexity, violates DRY.

---

## Decision 4: Status values — backward-compatible extension

**Decision**: Keep existing status values (`open`, `complete`, `cancelled`, `migrated`) in the DB. Add `backlog` as the only new status value. The service layer maps: `open` → active, `complete` → completed, `cancelled` → canceled, `backlog` → backlog. The `migrated` status is deprecated: existing migrated bullets remain as-is; new carries use the in-place mutation approach.

**Rationale**: Avoids a data migration of all existing rows. The service layer abstraction hides the DB naming from the UI. New code never writes `migrated`; only reads it for backward compatibility.

**Alternatives considered**:
- Rename all status values in a schema migration. Rejected: adds migration risk for a dev project with no production users yet and requires updating all existing queries.

---

## Decision 5: "From Yesterday" query approach

**Decision**: Query `bullets` joined to `day_logs` where `day_logs.date = yesterday` AND `bullets.type = 'task'` AND `bullets.status IN ('open')` AND `(bullets.scheduled_date IS NULL OR bullets.scheduled_date <= today)` AND `bullets.is_deleted = 0` AND `bullets.created_at <= (7 days ago)` excluded (those go to Weekly Review).

**More precisely**: a task appears in carry-over if its `day_logs.date = yesterday` AND `created_at` is within the last 7 days. If `created_at` is older than 7 days, the task goes to Weekly Review regardless of which day it currently belongs to.

**Rationale**: Using `day_logs.date` as the carry-over anchor naturally reflects the user's current ownership of the task. Using `created_at` as the 7-day threshold correctly separates carry-over (recent tasks) from weekly review (old tasks). The `idx_bullets_day_id` and `idx_day_logs_date` indexes make this query fast.

---

## Decision 6: Weekly Review eligibility — creation date threshold

**Decision**: A task is eligible for Weekly Review if: `bullets.created_at <= (today - 7 days)` AND `bullets.type = 'task'` AND `bullets.status = 'open'` AND `bullets.is_deleted = 0` AND `(bullets.scheduled_date IS NULL OR bullets.scheduled_date <= today)`.

**Rationale**: Using `created_at` (immutable) rather than the day_log date means a task cannot be "kept fresh" by repeatedly clicking "Keep for Today" to avoid weekly review. It also does not require a separate `lastActiveDate` column.

**Alternative considered**: Use `updated_at` as the threshold. Rejected: `updated_at` changes on any edit, so editing task content would reset the 7-day clock — an unintended consequence.

---

## Decision 7: Schema migration approach

**Decision**: Bump `schemaVersion` from 1 to 2 in `AppDatabase`. Add migration in `onUpgrade` using `ALTER TABLE bullets ADD COLUMN` for each new column. Create the new `task_lifecycle_events` table. Add index on `task_lifecycle_events(bullet_id)`.

**New columns on `bullets`**:
- `scheduled_date TEXT` — nullable, YYYY-MM-DD
- `carry_over_count INTEGER NOT NULL DEFAULT 0`
- `completed_at TEXT` — nullable, ISO 8601 UTC
- `canceled_at TEXT` — nullable, ISO 8601 UTC

**Rationale**: `ALTER TABLE ADD COLUMN` is the safest, minimal migration for SQLite. No data is lost. Existing rows get NULL/0 defaults for new columns.

---

## Decision 8: Drift reactive streams for combined Today view

**Decision**: Use two separate streams — `watchBulletsForDay(todayId)` and `watchCarryOverTasks(yesterday)` — and combine them in the Riverpod provider using `Rx.combineLatest2` or a custom async approach. The UI receives a `TodayScreenData` model with two separate lists.

**Rationale**: Drift's `watch()` returns reactive `Stream<List<T>>`. Combining streams in the provider layer keeps the DAO clean and lets the UI refresh whenever either list changes. The two-list model matches the two-section UI.

---

## Decision 9: Quick actions — bottom sheet, no forms

**Decision**: Tapping a carry-over task row shows a `showModalBottomSheet` with quick action buttons. No text inputs. "Schedule" shows a date picker only. All other actions execute immediately. Cancel action shows a brief snackbar with Undo.

**Rationale**: Matches the spec's "no forms" requirement and the app's "calm, minimal" UX principles. Bottom sheet is the established pattern in the existing codebase (see `CreatePersonSheet`). Cancel with undo satisfies the constitution's "Destructive actions require confirmation" principle without a blocking dialog.
