# Data Model: Day View Polish

**Branch**: `010-day-view-polish` | **Date**: 2026-03-13

---

## Summary

No database schema changes. No new model classes. All changes are visual/layout-only. The existing `TodayInteraction` model (extended in 009-ui-polish with `status` and `completedAt`) carries all required data.

---

## Existing Models — Extended API

### TodayInteraction (no new fields)

Already has all required fields:

```
bulletId:    String     // unique ID
personId:    String?    // linked person (nullable)
personName:  String?    // linked person display name (nullable)
content:     String     // full text including @mentions
type:        String     // 'note' | 'task'
loggedAt:    DateTime   // used for timestamp display
status:      String     // 'open' | 'complete' (from 009-ui-polish)
completedAt: String?    // nullable timestamp (from 009-ui-polish)
```

The `content` field already contains inline `@Name` mention text — no new field needed for mention detection.

---

## Widget API Changes (non-model)

### TodayInteractionTimeline — new parameter

```dart
required String sectionLabel
```

- The section header currently hard-codes `'TODAY'`. This field will receive the display label from `DayViewScreen` (e.g., `'Today'`, `'Yesterday'`, `'Mar 10, 2026'`).
- No change to `interactions`, `onTap`, `onDelete`, `onComplete` parameters.

### DayViewScreen — empty-state logic

No model changes. The empty-state condition changes from:
```
visible suggestions == 0
```
to:
```
visible suggestions == 0 AND interactions.isEmpty
```

Both values are already in scope from existing `suggestionsAsync` and `interactionsAsync` providers.

---

## State Transitions (unchanged)

Task completion state transitions remain identical to 009-ui-polish:

```
open  →  complete   via BulletsDao.completeTask(id)
complete → open     via BulletsDao.uncompleteTask(id)
```

Both methods already exist and are wired in `DayViewScreen._onToggleComplete`.
