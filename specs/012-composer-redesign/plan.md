# Implementation Plan: Composer Redesign & Timeline Polish

**Branch**: `012-composer-redesign` | **Date**: 2026-03-14 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/012-composer-redesign/spec.md`

---

## Summary

A focused UX refinement of the bottom composer and timeline home screen. The existing `BulletCaptureBar` is refactored into a collapsible two-row composer: idle state shows only the text input; tapping the input expands an action row (person link, follow-up, cancel, done) with a smooth `AnimatedSize` animation. Follow-up scheduling is added inline via a lightweight bottom sheet with five time presets. The `TimelineScreen` gains a "Back to today" button (appears after scrolling one full screen past today) and a gradient fade-out overlay at the timeline's bottom edge. No schema migrations are required — all follow-up columns already exist from `011-life-log`. No new packages are introduced.

---

## Technical Context

**Language/Version**: Dart 3.3+ / Flutter 3.19+
**Primary Dependencies**: flutter_riverpod 2.5, drift 2.18, intl 0.19, uuid 4.x — all existing; **no new packages**
**Storage**: SQLite via drift + SQLCipher — **no schema changes**; `followUpDate` column already present on `bullets` table (added in `011-life-log`)
**Testing**: flutter_test — widget tests for composer states, follow-up picker, back-to-today visibility
**Target Platform**: iOS (primary), Android
**Project Type**: Mobile app
**Performance Goals**: Action-row expand animation ≤ 250ms; capture latency < 500ms; 60fps scroll (all per constitution)
**Constraints**: No new packages; no schema migration; all existing tests must continue to pass
**Scale/Scope**: 2 files modified (`bullet_capture_bar.dart`, `timeline_screen.dart`) + 1 new widget file (`follow_up_picker_sheet.dart`)

---

## Constitution Check

*GATE: Must pass before implementation. Re-checked after design.*

### I. Code Quality ✅ PASS

- `BulletCaptureBar` is refactored in-place — renamed internally to `LogComposer` semantics but no file rename (avoids breaking import chain). The expanded/collapsed state is a single `bool _isExpanded` — single responsibility, no hidden complexity.
- `FocusNode` is created and disposed in `_BulletCaptureBarState` following Flutter idiomatic lifecycle (`initState` / `dispose`). No leaks.
- `FollowUpPickerSheet` is a single private class in its own file, returned via `showModalBottomSheet`. Returns `DateTime?` — clear contract, no side-effects.
- Back-to-today scroll threshold reuses the existing `_kEntryH` / `_kHeaderH` height estimation already in `TimelineScreen`. No new estimation logic.
- The fade overlay is an `IgnorePointer`-wrapped `ShaderMask` — no interaction is blocked; touch events pass through.
- No dead code: the `_kTabBarClearance` constant comment from `011-life-log` cleanup is preserved, value already corrected to 8.0.

### II. Testing Standards ✅ PASS

- Composer collapsed state (action row hidden): widget test required.
- Composer expands on focus: widget test required.
- Cancel clears input, collapses, dismisses keyboard: widget test required.
- Done saves entry, collapses: widget test (mocked DAO) required.
- Follow-up picker shows 5 presets: widget test required.
- Back-to-today button appears/disappears based on scroll: widget test required.
- All 11 existing widget tests in `app/test/` must continue to pass.

### III. User Experience Consistency ✅ PASS

- **Capture speed is sacred**: The collapsed state reduces the composer's visual footprint. The critical path (tap input → type → Done) is no longer interrupted by an always-visible action row. Tap-to-expand adds ≤250ms, within spec.
- **Calm by default**: No new badges, scores, or notifications introduced. Follow-up is opt-in and requires two taps minimum.
- **Consistent affordances**: Person-linking button in the action row reuses the existing `PersonPickerSheet` flow — same interaction model as before.
- **Graceful empty states**: If the timeline is empty, the composer still expands normally; the back-to-today button does not appear (no scrollable distance).
- **Destructive actions**: Cancel clears unsaved input (non-destructive — no saved data is removed). No confirmation required per spec.

### IV. Performance Requirements ✅ PASS

- `AnimatedSize` uses the Flutter engine's layout animation path — hardware-accelerated, no canvas draws per-frame.
- The bottom fade uses `ShaderMask` + `LinearGradient` — single GPU compositing step, does not affect scroll performance.
- The back-to-today button uses `AnimatedOpacity` — no layout changes; opacity-only animation is the cheapest Flutter animation.
- `_scrollController` listener is already attached in `TimelineScreen`; the back-to-today threshold check is a single comparison appended to the existing `_updateStickyLabel` listener — no additional listener registered.

### Privacy & Data Integrity ✅ PASS

- No new data columns, no schema migration. Follow-up date is written to an existing nullable column (`followUpDate`) on the `bullets` row at insert time — same transaction as the bullet itself, atomic.
- No new sync paths. The existing sync queue picks up the `followUpDate` field automatically (it's part of the same `bullets` row).

---

## Project Structure

### Documentation (this feature)

```text
specs/012-composer-redesign/
├── plan.md              ✅ (this file)
├── research.md          ✅
├── data-model.md        ✅
├── quickstart.md        ✅
├── contracts/
│   └── widget-contracts.md  ✅
├── checklists/
│   └── requirements.md  ✅
└── tasks.md             (created by /speckit.tasks)
```

### Source Code (files modified or created)

```text
app/
├── lib/
│   ├── widgets/
│   │   ├── bullet_capture_bar.dart      # MODIFY: add collapsed/expanded states,
│   │   │                                #   FocusNode, AnimatedSize action row,
│   │   │                                #   Follow-up date state, Done/Cancel handlers
│   │   └── follow_up_picker_sheet.dart  # NEW: lightweight bottom sheet with 5 time presets
│   └── screens/
│       └── timeline/
│           └── timeline_screen.dart     # MODIFY: add back-to-today button + ShaderMask fade
└── test/
    └── widgets/
        ├── bullet_capture_bar_test.dart # NEW: composer states, Follow-up, Cancel/Done
        └── timeline_screen_test.dart    # ADD: back-to-today visibility tests
```

**Structure Decision**: Single Flutter project. Changes are tightly scoped to 2 modified files + 1 new widget file + 2 test files. No new providers, no new models, no schema changes.

---

## Implementation Notes Per User Story

### US1 — Collapsible Composer with Action Row

**File**: `app/lib/widgets/bullet_capture_bar.dart`

**State added to `_BulletCaptureBarState`**:

```dart
bool _isExpanded = false;
late FocusNode _focusNode;

@override
void initState() {
  super.initState();
  _focusNode = FocusNode();
  _focusNode.addListener(_onFocusChange);
  _controller.addListener(_onTextChanged);
}

void _onFocusChange() {
  if (_focusNode.hasFocus && !_isExpanded) {
    setState(() => _isExpanded = true);
  }
}
```

**Action row animation** — wrap in `AnimatedSize` + `ClipRect`:

```dart
ClipRect(
  child: AnimatedSize(
    duration: _isExpanded ? AntraMotion.springExpand : AntraMotion.springCollapse,
    curve: _isExpanded ? AntraMotion.expandCurve : AntraMotion.collapseCurve,
    alignment: Alignment.topCenter,
    child: _isExpanded ? _buildActionRow() : const SizedBox.shrink(),
  ),
)
```

**Cancel handler**:

```dart
void _cancel() {
  _controller.clear();
  _focusNode.unfocus();
  setState(() {
    _isExpanded = false;
    _linkedPeople = [];
    _selectedFollowUpDate = null;
  });
}
```

**Done handler**: saves bullet (with optional `followUpDate`), then calls `_cancel()` to reset state.

**Multi-line input**: set `maxLines: null` on `TextField` (already uses `minLines: 1, maxLines: 4` — change `maxLines` to `null` to allow unlimited growth up to natural height).

---

### US2 — Follow-Up Scheduling

**File**: `app/lib/widgets/follow_up_picker_sheet.dart` (new)

```dart
/// Lightweight time-preset picker returned by [showFollowUpPicker].
///
/// Returns the chosen [DateTime] or null if dismissed.
Future<DateTime?> showFollowUpPicker(BuildContext context) {
  return showModalBottomSheet<DateTime?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _FollowUpPickerSheet(),
  );
}
```

**Presets**:

| Label | Value |
|-------|-------|
| Later today | Today at 23:59 local |
| Tomorrow | Tomorrow at 00:00 local |
| In 3 days | Today + 3 days at 00:00 |
| Next week | Today + 7 days at 00:00 |
| Custom date | `showDatePicker(firstDate: tomorrow)` |

**Integration in `_BulletCaptureBarState`**:

```dart
String? _selectedFollowUpDate; // ISO date string, e.g. "2026-03-15"

Future<void> _pickFollowUp() async {
  final date = await showFollowUpPicker(context);
  if (date != null && mounted) {
    setState(() => _selectedFollowUpDate = DateFormat('yyyy-MM-dd').format(date));
  }
}
```

**In `_submit()`**: pass `followUpDate: Value(_selectedFollowUpDate)` in the `BulletsCompanion.insert()` call alongside `followUpStatus: Value(_selectedFollowUpDate != null ? 'pending' : null)`. No separate `addFollowUpToEntry` call needed — follows "single transaction" principle.

---

### US3 — Back to Today Navigation

**File**: `app/lib/screens/timeline/timeline_screen.dart`

**State added**:

```dart
bool _showBackToToday = false;
```

**Threshold check** — appended to `_updateStickyLabel()`:

```dart
final screenH = MediaQuery.sizeOf(context).height;
// "Today" is the first section (index 0) — offset 0 or after attention section.
final todayEnd = (_hasAttentionItems ? _kAttentionH : 0) +
    _kHeaderH +
    (_days.isNotEmpty ? _days.first.entries.length * _kEntryH : 0);
final show = offset > todayEnd + screenH;
if (show != _showBackToToday) setState(() => _showBackToToday = show);
```

**Button in Stack** (positioned above capture bar, right-aligned):

```dart
if (_showBackToToday)
  Positioned(
    right: 20,
    bottom: MediaQuery.viewPaddingOf(context).bottom + 112, // above capture bar
    child: AnimatedOpacity(
      opacity: _showBackToToday ? 1.0 : 0.0,
      duration: AntraMotion.fadeDismiss,
      child: _BackToTodayButton(onTap: _scrollToToday),
    ),
  ),
```

**Scroll handler**:

```dart
void _scrollToToday() {
  _scrollController.animateTo(
    0,
    duration: const Duration(milliseconds: 350),
    curve: Curves.easeOutCubic,
  );
}
```

---

### US4 — Timeline Bottom Fade

**File**: `app/lib/screens/timeline/timeline_screen.dart`

Wrap the scrollable `body` widget in a `ShaderMask` before placing it in the `Stack`:

```dart
ShaderMask(
  shaderCallback: (Rect bounds) {
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Colors.black, Colors.black, Colors.transparent],
      stops: const [0.0, 0.75, 1.0],
    ).createShader(bounds);
  },
  blendMode: BlendMode.dstIn,
  child: body,
)
```

`BlendMode.dstIn` preserves only the pixels where the gradient is opaque. The gradient is fully opaque (black) for the top 75% of the viewport and fades to transparent in the bottom 25%. This creates the visual fade-out at the bottom of the content area.

The `ShaderMask` applies to the `body` widget's paint region — as the content area shrinks when the keyboard is open, the fade adjusts automatically because it is relative to the widget's own bounds.

---

## Complexity Tracking

No constitution violations. This feature is a pure refinement of existing UI — no new patterns, no new packages, no schema changes.
