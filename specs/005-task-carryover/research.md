# Research: Carried-Over Tasks and Quick-Action Cards

**Feature**: `005-task-carryover`
**Date**: 2026-03-11

---

## Finding 1: Data Model Is Complete — No Schema Migration Needed

**Decision**: Keep schema at version 4. No migration.

**Rationale**: All required fields already exist on the `bullets` table:
- `scheduledDate` (TEXT, nullable) — ISO date for future scheduling
- `carryOverCount` (INTEGER, default 0) — explicit keep-for-today counter
- `completedAt` (TEXT, nullable) — completion timestamp
- `canceledAt` (TEXT, nullable) — cancellation timestamp
- `status` — already supports 'backlog' (written by `TaskLifecycleService.moveToBacklog`)
- `createdAt` (TEXT) — immutable creation timestamp; used for age calculation

`TaskLifecycleEvents` table also exists with all needed event types: `carried_over`, `kept_for_today`, `scheduled`, `moved_to_backlog`, `completed`, `canceled`, `converted_to_note`, `reactivated`, `entered_weekly_review`.

**Alternatives considered**: Adding a `isInBacklog` boolean column — rejected; the existing `status='backlog'` value is sufficient and avoids redundancy.

---

## Finding 2: TaskLifecycleService Is Complete — No New Methods Needed

**Decision**: Use `TaskLifecycleService` as-is. No new methods.

**Rationale**: All 6 quick actions and both weekly review actions are already implemented:
- `completeTask(bulletId)` — sets status='complete', completedAt, logs 'completed'
- `keepForToday(bulletId, todayDate)` — moves dayId to today, increments carryOverCount, logs 'kept_for_today'
- `scheduleTask(bulletId, date)` — sets scheduledDate, logs 'scheduled'
- `moveToBacklog(bulletId)` — sets status='backlog', clears scheduledDate, logs 'moved_to_backlog'
- `cancelTask(bulletId)` — sets status='cancelled', sets canceledAt, logs 'canceled'
- `convertToNote(bulletId)` — sets type='note' in-place, logs 'converted_to_note'
- `reactivateTask(bulletId, todayDate)` — undo for cancel/backlog
- `moveToThisWeek(bulletId, todayDate)` — delegates to keepForToday for weekly review context

**Alternatives considered**: Adding a separate `keepActive` method for weekly review — rejected; `moveToThisWeek` already wraps `keepForToday` with the same semantics.

---

## Finding 3: Carry-Over Query Has a Date-Range Bug

**Decision**: Change `watchCarryOverTasks` and `getCarryOverTasks` to use `dl.date >= sevenDaysAgo AND dl.date < today` instead of `dl.date = yesterday`.

**Rationale**: The current query only surfaces tasks whose DayLog date is exactly yesterday. A task created 3 days ago that the user never interacted with has its `dayId` pointing to a 3-day-old DayLog. It would never appear in the Carried Over section until the user does "Keep for Today" (which moves the dayId to today).

The spec requires: "If no action is taken on a carried-over task, it MUST continue to appear in the Carried Over section on each subsequent day" (FR-017). A date-range query (`dl.date >= sevenDaysAgo AND dl.date < today`) satisfies this.

After "Keep for Today", the task's `dayId` is moved to today's DayLog. Tomorrow, its DayLog date will be today (i.e., yesterday) and it will appear again in the carry-over range — correct behaviour.

**Alternatives considered**: Computing carry-over entirely from `createdAt` without joining DayLogs — rejected; the DayLog join is needed for the "Keep for Today" behaviour where a task is explicitly moved to a given day, and we want to preserve the ability to navigate back to a specific day's log.

---

## Finding 4: CarryOverTaskItem Needs Inline Action Row (Long-Press Is Insufficient)

**Decision**: Add a scrollable horizontal chip row directly in `CarryOverTaskItem`; remove the `onQuickAction` callback.

**Rationale**: The current widget only supports long-press to open a bottom sheet. The spec (FR-008, FR-015, UXR-004–007) requires action buttons immediately visible on the card. `WeeklyReviewTaskItem` already implements this pattern with a `SingleChildScrollView(Axis.horizontal)` chip row — the same pattern can be applied to `CarryOverTaskItem`.

`TaskQuickActionsSheet` can remain in the codebase as a potential long-press fallback or for use in the detail screen; it does not need to be removed.

**Alternatives considered**: Keep long-press as the trigger and just make it more discoverable — rejected; the spec explicitly states "immediately tappable" and "faster than opening a detail screen."

---

## Finding 5: WeeklyReviewTaskItem Missing Complete Action

**Decision**: Add a `Complete` chip as the first action in `WeeklyReviewTaskItem`.

**Rationale**: The current widget has: This Week, Schedule, Backlog, → Note, Cancel. "Complete" is absent. The spec (FR-023) requires Weekly Review to offer the same quick actions as daily Carried Over. `TaskLifecycleService.completeTask` already exists.

---

## Finding 6: Review Tab Badge Pattern — Material 3 Badge Widget

**Decision**: Use Flutter's built-in `Badge` widget (Material 3, available in Flutter 3.19+) to overlay a count badge on the Review tab's `NavigationDestination`.

**Rationale**: `RootTabScreen` uses `NavigationBar` + `NavigationDestination`. Flutter 3.19 provides `Badge` as a first-class Material 3 widget. Watch `weeklyReviewTasksProvider` in `RootTabScreen` and conditionally show a badge on the Review tab destination. No custom overlay logic needed.

**Alternatives considered**: A red dot without count — less informative; user can't gauge triage load at a glance.

---

## Finding 7: WeeklyReviewScreen Layout — Unresolved Tasks Should Be Primary

**Decision**: Move `_UnresolvedTasksSection` to the top of `WeeklyReviewScreen`.

**Rationale**: Per the spec, "Weekly Review" is specifically about tasks older than 7 days. The current screen leads with "Open Tasks this week" and "Events" before showing "Needs Attention." Reordering puts the spec-defined primary content first.

The legacy `_migrateTask` function (which uses `BulletsDao.migrateBullet`) in the "Open Tasks this week" section should be updated to use `TaskLifecycleService.keepForToday` for consistency, since `migrateBullet` is marked deprecated.

---

## Unresolved Items

None. All NEEDS CLARIFICATION markers in the spec have been resolved. All technical unknowns are resolved by existing codebase analysis.
