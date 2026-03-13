# Widget Contracts: UI Polish — Composer, Task Cards & Tab Bar

**Branch**: `009-ui-polish` | **Date**: 2026-03-13

---

## BulletsDao — new completion methods

### `completeTask(String id) → Future<void>`
- Sets `status = 'complete'` and `completedAt = now` in one DB transaction.
- Enqueues a pending_sync 'update' row.
- Calling on a non-task bullet is a no-op (caller's responsibility to gate on `type == 'task'`).

### `uncompleteTask(String id) → Future<void>`
- Sets `status = 'open'` and `completedAt = null` in one DB transaction.
- Enqueues a pending_sync 'update' row.

---

## TodayInteraction model

### New fields (additive)
```
status:      String           // 'open' | 'complete' | 'cancelled' | 'migrated'
completedAt: String?          // null = open; non-null = completed timestamp
```

### Existing fields (unchanged)
```
bulletId, personId, personName, content, type, loggedAt
```

---

## TodayInteractionTimeline widget

### New parameter
```dart
required void Function(String bulletId, bool complete) onComplete
```

### Behavioral contract
- Task entries (`type == 'task'`): show a tappable leading completion control.
  - Open: hollow circle icon (`Icons.radio_button_unchecked`, white54).
  - Complete: filled circle/check icon (`Icons.check_circle_rounded`, white54).
  - On tap: call `onComplete(entry.bulletId, entry.status != 'complete')`.
- Note entries: leading indicator unchanged (small dot, no completion control).
- Completed task text: rendered at `Colors.white38` opacity (reduced emphasis).
- No 'TASK' trailing label.
- Content `Text`: no `overflow` / `maxLines` constraints. Full text wraps.
- Entry `Row` `crossAxisAlignment`: `CrossAxisAlignment.start`.
- `onTap`, `onDelete` callbacks: unchanged.

### Invariants
- Widget does not own the completion state. It receives `status`/`completedAt` via `TodayInteraction` and fires `onComplete`. The parent handles the DAO call.
- All existing constructor params (`interactions`, `onTap`, `onDelete`) are unchanged — `onComplete` is added alongside them.

---

## BulletCaptureBar widget

### Type switch (simplified)
- Single `Text` label only: `'Note'` or `'Task'` (14px, white70, weight 500).
- Sublabel ('Context' / 'Follow-up') removed entirely.
- `GestureDetector` and toggle logic unchanged.

### TextField appearance
- `filled: true`
- `fillColor: Colors.white.withValues(alpha: 0.05)`
- `border`, `enabledBorder`, `focusedBorder`: all `OutlineInputBorder(borderRadius: BorderRadius.circular(AntraRadius.card), borderSide: BorderSide.none)`
- All other TextField properties unchanged.

---

## _FloatingTabBar (RootTabScreen) widget

### Background container
- `color`: `AntraColors.auroraNavy` (replaces `cs.surfaceContainerHigh`)
- `border`: `Border.all(color: Colors.white.withValues(alpha: AntraColors.glassBorderOpacity), width: 0.5)`
- `boxShadow`, `borderRadius`: unchanged (`AntraRadius.tabBar = 30`)

### _TabButton — active state
- Active container `color`: `Colors.white.withValues(alpha: 0.10)` (replaces `cs.primaryContainer.withValues(alpha: 0.8)`)
- Active icon `color`: `Colors.white` (replaces `cs.primary`)
- Inactive icon `color`: `Colors.white38` (replaces `cs.onSurfaceVariant.withValues(alpha: 0.55)`)
- Tab labels removed (icon-only). This simplifies the button layout and reduces height pressure.
- Badge and `reviewBadgeCount` logic: unchanged.
- All navigation behavior: unchanged.
