# Data Model: Day View — Bullet Journal Refinement

**Feature**: `001-day-view-journal`
**Date**: 2026-03-13

---

## No Schema Changes Required

This feature makes no changes to the SQLite schema. All required capabilities are already supported by the existing `Bullets`, `DayLogs`, `BulletPersonLinks`, and `People` tables.

---

## Existing Entities Used

### Bullet

The core log entry entity. No field changes.

| Field | Type | Notes |
|-------|------|-------|
| `id` | UUID string | Primary key |
| `dayId` | UUID string | FK → `DayLog.id` |
| `type` | string | Defaults to `'note'` for journal entries. `'task'`, `'event'`, `'note'` remain valid values. |
| `content` | string | Freeform text from the composer. May contain `@Name` mentions. |
| `status` | string | `'open'` on creation |
| `position` | int | `0` on creation from composer |
| `createdAt` | ISO 8601 UTC | Timestamp of creation |
| `updatedAt` | ISO 8601 UTC | Timestamp of last update |
| `deviceId` | string | `'local'` |
| `isDeleted` | int (0/1) | Soft-delete flag |
| All other fields | nullable | Unused for journal entries |

**Journal entry rule**: Entries created from the bullet journal composer always use `type = 'note'` and `status = 'open'`. The user never selects a type manually.

---

### BulletPersonLink

Links a bullet to a person. Used when the user includes an `@mention` in the journal entry.

| Field | Type | Notes |
|-------|------|-------|
| `bulletId` | UUID string | FK → `Bullet.id` |
| `personId` | UUID string | FK → `People.id` |
| `linkType` | string | `'mention'` for journal entries (matches existing `BulletCaptureBar` convention) |
| `isDeleted` | int (0/1) | Soft-delete flag |

**Linking rule**: Only created when the submitted text contains one or more `@Name` tokens that resolve to an existing person. Unresolved mentions are saved as plain text; no link is created.

---

### DayLog

Parent container for all bullets on a given date. No changes.

| Field | Type | Notes |
|-------|------|-------|
| `id` | UUID string | Primary key |
| `date` | YYYY-MM-DD string | One DayLog per calendar date |

**Creation rule**: `BulletsDao.getOrCreateDayLog(date)` creates the DayLog on first save if absent. The composer always passes `widget.date` (the currently displayed date key from `DayViewScreen`).

---

### People

Contact records. No changes. Created inline from the `CreatePersonSheet` when the user taps "Create [name]" in the @mention overlay.

---

## Removed Model

### DailyGoal *(deleted)*

`app/lib/models/daily_goal.dart` is deleted. The `DailyGoal` class was a derived view model (not persisted) used only by `DailyGoalWidget`. With the widget removed, the model has no callers.

---

## State Changes

### Provider removals

| Provider | File | Reason |
|----------|------|--------|
| `dailyGoalProvider` | `day_view_provider.dart` | Only feeds `DailyGoalWidget` |

### DAO method removals

| Method | File | Reason |
|--------|------|--------|
| `watchDistinctPersonCountForDay` | `bullets_dao.dart` | Only called by `dailyGoalProvider` |

---

## Timeline display

The `TodayInteractionTimeline` watches `watchPersonLinkedBulletsForDay`, which returns bullets that have at least one non-deleted `BulletPersonLink`. Journal entries without a person link do not appear in the timeline. This is existing behaviour and is unchanged.

**Consideration**: All bullets for the day (linked and unlinked) could be shown in the timeline. This is out of scope for this feature — the existing per-person filtered view is retained.
