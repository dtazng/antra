# Data Model: UI Polish — Composer, Task Cards & Tab Bar

**Branch**: `009-ui-polish` | **Date**: 2026-03-13

---

## Schema Changes

**No database migration required.** All five user stories are UI-layer changes only.

The `bullets` table already has:
- `completedAt` — nullable ISO 8601 UTC timestamp. Non-null = completed.
- `status` — text: `'open'` | `'complete'` | `'cancelled'` | `'migrated'`. Already semantically correct.
- Schema version remains **4**.

---

## DAO Changes

### BulletsDao — new methods

#### `completeTask(String id)`
Sets `status = 'complete'` and stamps `completedAt` in a single transaction. Enqueues a sync update.

```
Input:  bullet id (UUID string)
Effect: bullets.status → 'complete', bullets.completedAt → now UTC ISO 8601, bullets.updatedAt → now
        pending_sync row → 'update'
```

#### `uncompleteTask(String id)`
Reverts `status = 'open'` and clears `completedAt`. Enqueues a sync update.

```
Input:  bullet id (UUID string)
Effect: bullets.status → 'open', bullets.completedAt → null, bullets.updatedAt → now
        pending_sync row → 'update'
```

---

## UI State Changes

### TodayInteraction model

Add two new fields sourced from the `Bullet` record when the timeline entries are built:
- `status: String` — passed through from `bullet.status`
- `completedAt: String?` — passed through from `bullet.completedAt` (nullable)

These are read-only in the timeline widget. Completion toggling goes through the DAO.

### TodayInteractionTimeline widget

- Receives a new `onComplete: void Function(String bulletId, bool complete)` callback.
- Each task entry shows a tappable completion control (hollow circle/checkbox icon when open, filled circle/checkmark icon when complete).
- Completed task text renders at reduced opacity (`Colors.white38`) — no strikethrough (keeps the calm aesthetic).
- `crossAxisAlignment` in the entry `Row` changes from `center` to `start` for multi-line card support.
- `overflow: TextOverflow.ellipsis` removed from content `Text`.
- The trailing 'TASK' label widget is removed.

### BulletCaptureBar widget

- Type toggle `Column` reduced to single `Text` — sublabel removed.
- `TextField` gains `filled: true`, `fillColor: Colors.white.withValues(alpha: 0.05)`, and `OutlineInputBorder` with `AntraRadius.card` for all border states (enabled, focused, error all use `BorderSide.none`).

### RootTabScreen / _FloatingTabBar widget

- Background `color` changes from `cs.surfaceContainerHigh` / `cs.surface` to `AntraColors.auroraNavy` directly.
- Adds a glass border: `Border.all(color: Colors.white.withValues(alpha: AntraColors.glassBorderOpacity))`.
- Active tab indicator `color` changes from `cs.primaryContainer.withValues(alpha: 0.8)` to `Colors.white.withValues(alpha: 0.10)`.
- Active icon `color` changes from `cs.primary` to `Colors.white` (full opacity).
- Inactive icon `color` changes from `cs.onSurfaceVariant.withValues(alpha: 0.55)` to `Colors.white38`.
- Tab labels are removed — icon-only tab bar (labels add visual weight; icons suffice at this size).

---

## Data Flow

### Task completion tap
```
User taps completion control on a task card
  → TodayInteractionTimeline.onComplete(bulletId, !currentlyComplete)
  → DayViewScreen._onToggleComplete(bulletId, complete)
  → BulletsDao.completeTask(id)  or  BulletsDao.uncompleteTask(id)
  → watchAllBulletsForDay stream emits updated list
  → DayViewProvider rebuilds TodayInteraction list with new status/completedAt
  → TodayInteractionTimeline rebuilds entry with updated visual state
```

### Completion persistence
- `completedAt` and `status` are stored in SQLite immediately on toggle.
- Both fields are included in the sync payload (existing `_enqueueBulletSyncFromRow` already serializes all Bullet columns).
- No in-memory-only state — the source of truth is always the database.
