# Quickstart / Integration Scenarios: UI Polish

**Branch**: `009-ui-polish` | **Date**: 2026-03-13

---

## Scenario 1 — Task completion: mark done

**Setup**: Day view shows a task entry (type = 'task', status = 'open').

**Steps**:
1. User taps the hollow circle icon on the left of the task card.
2. `onComplete(bulletId, true)` fires.
3. `BulletsDao.completeTask(bulletId)` sets status = 'complete', completedAt = now.
4. Stream emits updated bullet. `TodayInteraction` rebuilds with `status = 'complete'`.
5. Task card icon changes to filled checkmark; text renders at `Colors.white38`.

**Expected**: Completion state is visible immediately. No "TASK" label present.

---

## Scenario 2 — Task completion: undo (un-complete)

**Setup**: Day view shows a completed task (status = 'complete').

**Steps**:
1. User taps the filled checkmark icon.
2. `onComplete(bulletId, false)` fires.
3. `BulletsDao.uncompleteTask(bulletId)` sets status = 'open', completedAt = null.
4. Task card reverts to hollow circle; text returns to full opacity.

**Expected**: Completion state toggles bidirectionally.

---

## Scenario 3 — Completion persists after restart

**Setup**: Mark a task as complete, close and reopen the app.

**Expected**: The task still appears with the completed visual state (filled icon, reduced opacity text). `completedAt` is non-null in DB.

---

## Scenario 4 — No "TASK" label on task cards

**Setup**: Day view has one note and one task.

**Expected**: No text reading "TASK" appears anywhere on either card. The task is identifiable solely by its completion control (hollow circle icon).

---

## Scenario 5 — Dynamic card height: long note

**Setup**: Create a note with 5 lines of text.

**Expected**: The card grows to show all 5 lines. No ellipsis. Swipe-to-delete still works on the full card.

---

## Scenario 6 — Dynamic card height: long task

**Setup**: Create a task with 3 lines of text.

**Expected**: The card grows vertically. The completion control icon is top-aligned with the first line of text.

---

## Scenario 7 — Composer: sublabel absent

**Setup**: Open the log composer.

**Expected**: The type toggle shows exactly one line of text ("Note" or "Task"). No secondary line below.

---

## Scenario 8 — Composer: rounded input field

**Setup**: Tap the text field in the composer.

**Expected**: The input area shows a faint rounded background that matches the card's corner radius. No sharp rectangular block is visible inside the rounded card.

---

## Scenario 9 — Tab bar: dark aurora palette

**Setup**: View any screen with the tab bar visible.

**Expected**: Tab bar background is dark (`AntraColors.auroraNavy`), not light or grey. Active tab has a very subtle whitish tinted pill, not a bright colored highlight. Icons are the only visual element per tab (no label text).

---

## Scenario 10 — Tab bar: navigation unchanged

**Setup**: Tap each of the 5 tabs.

**Expected**: Navigation behaves identically to before — Today, People, Collections, Search, Review screens all load correctly. Review badge still appears when tasks are pending.
