# Widget Contracts: Day View Polish

**Branch**: `010-day-view-polish` | **Date**: 2026-03-13

---

## TodayInteractionTimeline

### New parameter

```dart
required String sectionLabel
```

- Receives the day label from `DayViewScreen` (e.g., `'Today'`, `'Yesterday'`, `'Mar 10, 2026'`).
- Replaces the hard-coded `'TODAY'` string in the section header.
- Displayed with quiet typography: `fontSize: 11`, `fontWeight: FontWeight.w400`, `Colors.white38`, `letterSpacing: 0.4`.

### Changed layout — entry row

**Before** (current):
```
[leading icon] [10px] [timestamp — 40px SizedBox] [4px] [content — Expanded] [6px?] [personName?]
```

**After**:
```
[leading icon] [8px] [content — Expanded] [8px] [personName?] [6px?] [timestamp — trailing]
```

- Timestamp moves to trailing-right of the row.
- Content `Expanded` starts immediately after the leading icon gap.
- Timestamp `Text` has no `SizedBox` width constraint — it shrinks to its natural width.
- `CrossAxisAlignment.start` on the outer Row is preserved (from 009-ui-polish).

### Changed rendering — content Text → Text.rich

- `Text(entry.content, ...)` is replaced with `Text.rich(TextSpan(children: [...]))`.
- Content is parsed by a `RegExp(r'(@\w+)')` split.
- Non-mention spans: `TextStyle(fontSize: 14, color: isComplete ? Colors.white38 : Colors.white)`.
- Mention spans: `TextStyle(fontSize: 14, color: isComplete ? Colors.white38 : Colors.white70, fontWeight: isComplete ? FontWeight.normal : FontWeight.w500)`.
- Tapping on a mention span does not navigate — `onTap` on the card still fires `onComplete` / `onTap` as before.

### Changed styling — card outer padding

- From: `EdgeInsets.symmetric(horizontal: 12, vertical: 3)`
- To: `EdgeInsets.symmetric(horizontal: 12, vertical: 4)`

### Changed styling — GlassSurface inner padding

- From: `EdgeInsets.symmetric(horizontal: 12, vertical: 8)`
- To: `EdgeInsets.symmetric(horizontal: 12, vertical: 10)`

### Unchanged

- `interactions`, `onTap`, `onDelete`, `onComplete` parameters — no change.
- Leading icon logic (task hollow/filled, person dot, note dot) — no change.
- `AnimatedList` insert animation — no change.
- Swipe-to-delete `Dismissible` — no change.

---

## DayViewScreen — Empty-State Logic

### Changed condition

The `_EmptyState` widget is no longer rendered solely when suggestions are empty. New rule:

```
Show _EmptyState when:
  visible suggestions == 0
  AND timeline interactions.isEmpty
```

### Implementation contract

Inside `suggestionsAsync.when(data:)`, the existing `if (visible.isEmpty) return _EmptyState(...)` is replaced by a check that reads from `interactionsAsync`:

```dart
if (visible.isEmpty && interactionsAsync.valueOrNull?.isEmpty == true) {
  return _EmptyState(...);
}
```

If suggestions are empty but interactions are non-empty, the suggestions section renders nothing (or a `SizedBox.shrink()`) and the timeline below shows the entries normally.

### Unchanged

- `_EmptyState` widget itself — no structural change.
- Timeline `TodayInteractionTimeline` call site — unchanged (except new `sectionLabel` param).
- All navigation, async provider, delete, and completion logic.

---

## BulletCaptureBar — Bottom Padding

### Changed behavior

When keyboard is hidden, `BulletCaptureBar` increases its bottom padding to visually clear the floating tab bar:

```dart
// Existing:
bottom: keyboardVisible ? 0 : MediaQuery.viewPaddingOf(context).bottom

// New:
bottom: keyboardVisible ? 0 : MediaQuery.viewPaddingOf(context).bottom + kFloatingTabBarHeight
```

Where `kFloatingTabBarHeight = 60.0` (matches the tab bar button height defined in `root_tab_screen.dart`).

When keyboard is open, behavior is unchanged (bottom padding = 0).

### Unchanged

- All submission, person-linking, @mention, type-toggle behavior.
- TextField appearance and rounded borders (from 009-ui-polish).
