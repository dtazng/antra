# Widget Contracts: Composer Redesign & Timeline Polish

**Feature**: `012-composer-redesign`
**Date**: 2026-03-14

---

## BulletCaptureBar (modified)

**File**: `app/lib/widgets/bullet_capture_bar.dart`

### Public interface (unchanged)

```dart
class BulletCaptureBar extends ConsumerStatefulWidget {
  final String date; // ISO date YYYY-MM-DD used as dayId for new bullets
  const BulletCaptureBar({super.key, required this.date});
}
```

### Behaviour contracts

| State | Visible elements | Trigger |
|-------|-----------------|---------|
| Collapsed (idle) | Text input only | Initial render; after Done; after Cancel |
| Expanded | Text input + action row | Text input receives focus |

**Action row layout**:

- Left side: `[@ Person]` button · `[Follow-up]` button (with date chip if one is selected)
- Right side: `[Cancel]` text button · `[Done]` filled button

**Cancel contract**:
1. Clears `TextField` content.
2. Unfocuses the `FocusNode` (keyboard dismisses).
3. Clears `_linkedPeople` list.
4. Clears `_selectedFollowUpDate`.
5. Sets `_isExpanded = false`.

**Done contract**:
1. If `content.trim().isEmpty` → calls `_cancel()`, no entry saved.
2. Otherwise → inserts bullet with `followUpDate` and `followUpStatus` set if a follow-up was chosen, then calls `_cancel()`.

**Follow-up chip**: When `_selectedFollowUpDate != null`, the Follow-up button in the action row shows the chosen date label (e.g., "Tomorrow") instead of the plain "Follow-up" label. Tapping it re-opens the picker, replacing the selection.

---

## FollowUpPickerSheet (new)

**File**: `app/lib/widgets/follow_up_picker_sheet.dart`

### Public function

```dart
/// Opens a bottom sheet presenting follow-up time presets.
/// Returns the chosen [DateTime] or null if dismissed without selection.
Future<DateTime?> showFollowUpPicker(BuildContext context);
```

### Behaviour contracts

- Returns a `DateTime` set to the correct local date/time for the chosen preset.
- Returns `null` if the user taps outside the sheet or presses the system back button without selecting.
- "Custom date" preset opens the platform date picker. If the user cancels the date picker, the sheet remains open (does not dismiss automatically).
- The custom date picker's `firstDate` is always `DateTime.now() + 1 day`. Past dates are not selectable.
- The sheet does not save anything to the database — it only returns a value.

### Visual contract

- Displayed as a modal bottom sheet with `GlassSurface(style: GlassStyle.modal)` background.
- Five rows of options, each a full-width tappable `ListTile`.
- Selected state is not persisted in the sheet — it is stateless. Selection closes the sheet immediately.

---

## TimelineScreen (modified)

**File**: `app/lib/screens/timeline/timeline_screen.dart`

### Back-to-Today button contract

| Condition | Button state |
|-----------|-------------|
| `scrollOffset ≤ todayEnd + screenHeight` | Hidden (opacity 0 or removed from tree) |
| `scrollOffset > todayEnd + screenHeight` | Visible, positioned right-aligned above capture bar |

- Tapping the button calls `_scrollController.animateTo(0, ...)` — scrolls to the absolute top of the scroll view.
- The button fades in/out using `AnimatedOpacity(duration: AntraMotion.fadeDismiss)`.
- The button does not interrupt an in-progress scroll — calling `animateTo` while scrolling cancels the current animation and starts a new one.

### Bottom fade contract

- A `ShaderMask` with `BlendMode.dstIn` wraps the `body` widget (the `CustomScrollView` result).
- The gradient: fully opaque for the top 75% of the body height, fading to transparent over the bottom 25%.
- The fade does not block hit testing — touch events in the faded region pass through to the underlying `CustomScrollView`.
- The fade is applied to the `body`'s paint bounds, which automatically resize when the keyboard is open.

---

## Interaction with Existing Widgets

| Widget | Interaction |
|--------|------------|
| `PersonPickerSheet` | Called unchanged from the composer action row's Person button. Returns `List<PeopleData>?`. |
| `NeedsAttentionSection` | Unchanged. Follow-ups created by the new composer flow appear in Needs Attention via the existing `watchPendingFollowUps` query when the follow-up date arrives. |
| `BulletDetailScreen` | Unchanged. Follow-up date is visible and editable from the detail screen via the existing `_FollowUpRow` widget. |
