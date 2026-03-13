# Widget Interface Contracts: Log UX Refinement

**Branch**: `008-log-ux-refine` | **Date**: 2026-03-13

---

## GlassSurface

### Change: Add optional `borderRadius` parameter

```dart
class GlassSurface extends StatefulWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.style = GlassStyle.card,
    this.padding,
    this.onTap,
    this.borderRadius,   // NEW: when provided, overrides the style's default borderRadius
  });

  final BorderRadius? borderRadius;   // NEW
  // ... existing fields unchanged
}
```

**Contract**:
- When `borderRadius` is null, the `GlassStyle` default is used (existing behavior, backward compatible).
- When `borderRadius` is provided, it overrides the style's `_GlassProps.borderRadius` for both the `Container` decoration and the `ClipRRect`.
- All existing call sites continue to work without modification.

---

## BulletCaptureBar

### No public API change

`BulletCaptureBar` is used as `BulletCaptureBar(date: _dateKey)` — no parameter change. Internal state changes from `PeopleData?` to `List<PeopleData>` are encapsulated.

**Behavioral contract**:
- Composer displays linked-people chips above the text field, one chip per person, each with a remove (×) button.
- Tapping `@` button opens `PersonPickerSheet` in multi-select mode; returned people are merged into the chip list.
- @mention autocomplete adds the selected person to the chip list (does not replace).
- On submit: all chip-listed people + all @mentioned people (deduplicated) are linked via `BulletPersonLinksCompanion`.
- After submit: chip list is cleared, text field is cleared.
- Type toggle shows current mode label + subtitle; tapping cycles Note ↔ Task.
- Card renders with `BorderRadius.circular(AntraRadius.card)` on all four corners via `GlassSurface(borderRadius: BorderRadius.circular(AntraRadius.card))`.

---

## PersonPickerSheet

### Change: Multi-select mode with confirmation

```dart
class PersonPickerSheet extends ConsumerStatefulWidget {
  const PersonPickerSheet({
    super.key,
    this.alreadyLinked = const [],   // NEW: pre-selected people shown with checkmark
  });

  final List<PeopleData> alreadyLinked;   // NEW
}
```

**Return value change**:
- **Before**: `Navigator.pop(person)` → `PeopleData?`
- **After**: `Navigator.pop(selected)` → `List<PeopleData>` (empty list if nothing selected or dismissed)

**Contract**:
- Sheet shows a checkmark on rows for people already in `alreadyLinked` on open.
- Tapping a row toggles selection (checked ↔ unchecked).
- "Done" button in the header area confirms and pops with `List<PeopleData>` of all checked people.
- Tapping the drag handle or swiping down dismisses without changes (pops with original `alreadyLinked` list, not an empty list, so caller can diff).
- "Create new person" row at bottom opens `CreatePersonSheet`; on creation, new person is added to selection and sheet does not auto-close (user must tap Done).

---

## TodayInteractionTimeline

### No API change

Public constructor unchanged: `TodayInteractionTimeline({required interactions, required onTap})`.

**Behavioral contract — type rendering**:
- Entry with `type == 'note'`: leading indicator is a small `•` dot (Icon `Icons.circle`, size 6, color white38).
- Entry with `type == 'task'`: leading indicator is `Icons.check_box_outline_blank_rounded`, size 12, color white54.
- Entry with `type == 'task'`: a small uppercase label "TASK" (fontSize 10, white38, letterSpacing 0.8) is appended as the last inline element in the row, after the content text.
- Entry with `personName != null`: person name shown as muted suffix (existing behavior, unchanged).
- Empty state text: "Nothing logged yet today." (unchanged).

**Swipe-to-delete contract**:
- Each entry row is wrapped in a `Dismissible` keyed by `bulletId`.
- Direction: `DismissDirection.endToStart` (swipe left).
- Background: deep red (`Colors.red.shade800`) with a trash icon (`Icons.delete_outline_rounded`, white, right-aligned with 20px padding).
- On `onDismissed`: calls `onDelete(bulletId)` callback.
- `confirmDismiss` is not used (always returns null/proceeds); deletion confirmation is handled via undo snackbar by the parent widget.

```dart
class TodayInteractionTimeline extends StatefulWidget {
  const TodayInteractionTimeline({
    super.key,
    required this.interactions,
    required this.onTap,
    required this.onDelete,   // NEW
  });

  final void Function(String bulletId) onDelete;   // NEW
}
```

---

## BulletsDao

### New method: `undoSoftDeleteBullet`

```dart
Future<void> undoSoftDeleteBullet(String id) async {
  final now = DateTime.now().toUtc().toIso8601String();
  await (update(bullets)..where((b) => b.id.equals(id))).write(
    BulletsCompanion(
      isDeleted: const Value(0),
      updatedAt: Value(now),
    ),
  );
}
```

**Contract**:
- Sets `is_deleted = 0` and `updated_at = now` for the given bullet ID.
- No-op if bullet ID does not exist.
- Used exclusively by the undo snackbar action within 4 seconds of a `softDeleteBullet` call.
