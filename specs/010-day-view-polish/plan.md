# Implementation Plan: Day View Polish — Clarity, Hierarchy & Visual Cohesion

**Branch**: `010-day-view-polish` | **Date**: 2026-03-13 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/010-day-view-polish/spec.md`

---

## Summary

Seven targeted visual and logic improvements to the Day View — no new packages, no DB migration, no model changes. Changes are concentrated in three files: `day_view_screen.dart` (empty-state logic, composer bottom padding), `today_timeline.dart` (layout, typography, mention styling, section header), and `glass_surface.dart` (chip border opacity). All existing functionality (task completion, swipe-to-delete, navigation, dynamic card height) is preserved.

---

## Technical Context

**Language/Version**: Dart 3.3+ / Flutter 3.19+
**Primary Dependencies**: flutter_riverpod 2.5, drift 2.18, intl 0.19 (all existing — no new packages)
**Storage**: N/A — no DB changes
**Testing**: flutter_test (existing test suite; widget tests for today_timeline and day_view_screen)
**Target Platform**: iOS (primary), Android
**Project Type**: Mobile app
**Performance Goals**: 60 fps scroll; card layout changes must not introduce jank
**Constraints**: No new packages; no data model changes; all existing tests must continue to pass
**Scale/Scope**: Single screen polish across 3 source files + 1 test file

---

## Constitution Check

*GATE: Must pass before implementation. Re-checked after design.*

### I. Code Quality ✅ PASS

- All changes follow existing conventions (Riverpod providers, drift DAOs, `const` where possible).
- No dead code introduced: the `'TODAY'` hard-coded string is replaced by a passed `sectionLabel` parameter — no orphaned constant.
- `Text.rich` / `TextSpan` split is the standard Flutter idiom for inline styled text — no non-standard patterns.
- Single responsibility preserved: `TodayInteractionTimeline` remains a pure display widget; `DayViewScreen` owns the empty-state condition logic.

### II. Testing Standards ✅ PASS

- The empty-state condition change (US1) is the only behavioral change with correctness risk. It MUST have a widget test covering: (a) entries present → no empty state, (b) no entries → empty state shown.
- Layout/visual changes (US3–US7) are verified by manual inspection; existing tests must not regress.
- `onComplete`, `onTap`, `onDelete` behavioral tests are unchanged and must continue to pass.

### III. User Experience Consistency ✅ PASS

- **Capture speed**: `BulletCaptureBar` changes are padding-only — no new async paths on the capture critical path.
- **Calm by default**: No badges, streaks, or unsolicited feedback introduced.
- **Consistent affordances**: `Text.rich` mention spans are non-tappable — consistent with the card's existing `onTap` behavior.
- **Graceful empty states**: Empty-state condition is now stricter (correct), not removed.
- **Destructive actions**: Swipe-to-delete and undo behavior unchanged.

### IV. Performance Requirements ✅ PASS

- `Text.rich` with a `RegExp` split on content is O(n) in content length — negligible for typical bullet text lengths (<500 chars).
- Increased card padding adds a few pixels to layout height — no frame-rate impact.
- No `BackdropFilter` changes; blur budget unchanged.
- `sectionLabel` parameter adds a single `String` reference — no additional layout passes.

### Privacy & Data Integrity ✅ PASS

- No new data access, no new network calls, no new storage.
- `@Name` mention parsing operates on already-loaded `entry.content` — no additional DB reads.

---

## Project Structure

### Documentation (this feature)

```text
specs/010-day-view-polish/
├── plan.md              ✅ (this file)
├── research.md          ✅
├── data-model.md        ✅
├── quickstart.md        ✅
├── contracts/
│   └── widget-contracts.md  ✅
└── tasks.md             (created by /speckit.tasks)
```

### Source Code (files modified)

```text
app/
├── lib/
│   ├── widgets/
│   │   ├── today_timeline.dart          # US2–US6: layout, mention rich text, section header, spacing
│   │   └── glass_surface.dart           # US5: chip border opacity (targeted constant)
│   ├── screens/
│   │   └── day_view/
│   │       └── day_view_screen.dart     # US1: empty-state condition; US7: composer bottom padding
│   └── theme/
│       └── app_theme.dart               # US5: add chipGlassBorderOpacity constant
└── test/
    └── widgets/
        └── today_timeline_test.dart     # US1: add sectionLabel to all instantiations; US3 empty-state tests
```

**Structure Decision**: Single Flutter project. All changes are in existing files within the established `lib/widgets/`, `lib/screens/`, and `lib/theme/` hierarchy. No new files needed.

---

## Implementation Notes Per User Story

### US1 — Fix Empty-State Logic

**File**: `app/lib/screens/day_view/day_view_screen.dart`

Current code in `build()`:

```dart
suggestionsAsync.when(
  data: (suggestions) {
    final visible = ...;
    if (visible.isEmpty) {
      return const _EmptyState(icon: ..., message: '...');
    }
    return Column(children: [...cards]);
  },
  ...
),
```

New logic: Move empty-state decision to where both `suggestionsAsync` and `interactionsAsync` are in scope:

```dart
suggestionsAsync.when(
  data: (suggestions) {
    final visible = ...;
    if (visible.isEmpty) {
      // Only show empty state if timeline also has no entries.
      if (interactionsAsync.valueOrNull?.isEmpty == true) {
        return const _EmptyState(icon: ..., message: '...');
      }
      return const SizedBox.shrink();
    }
    return Column(children: [...cards]);
  },
  ...
),
```

**Note**: `interactionsAsync` is already watched in `build()` — no new provider needed.

---

### US2 — Task vs Note Distinction

Already implemented in 009-ui-polish (hollow circle / filled checkmark / dot). No changes needed. **Marked as complete in tasks.md without implementation work.**

---

### US3 — Timestamp as Secondary Metadata

**File**: `app/lib/widgets/today_timeline.dart`, method `_buildEntry`

Row layout change: Remove the `SizedBox(width: 40)` timestamp from between icon and content. Append timestamp as trailing widget after content.

```dart
// Before:
Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
  leadingIcon,
  const SizedBox(width: 10),
  SizedBox(width: 40, child: Text(timestamp)),
  const SizedBox(width: 4),
  Expanded(child: Text(content)),
  if (personName != null) ...[SizedBox(6), Text(personName)],
])

// After:
Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
  leadingIcon,
  const SizedBox(width: 8),
  Expanded(child: /* content column — see US4/US6 */),
  const SizedBox(width: 8),
  Text(timestamp, style: TextStyle(fontSize: 11, color: Colors.white30)),
])
```

The `personName` trailing text moves inside the content column (see US6 implementation note below).

---

### US4 — Multiline Text Indentation

Indentation is resolved automatically when the timestamp moves to trailing (US3). With the Row becoming `[leading icon] [gap] [content Expanded] [gap] [timestamp]`, wrapped lines of `content` naturally align with the content column start. No additional layout change needed.

---

### US5 — Spacing, Card Styling & Section Header

**Files**: `app/lib/theme/app_theme.dart`, `app/lib/widgets/today_timeline.dart`

**app_theme.dart**: Add a new constant:

```dart
static const double chipGlassBorderOpacity = 0.08;
```

**glass_surface.dart**: Update chip case in `_GlassProps.of()` to use `chipGlassBorderOpacity`:

```dart
case GlassStyle.chip:
  // border uses chipGlassBorderOpacity via GlassSurface param (see widget-contracts)
```

**Alternative to modifying glass_surface.dart**: Add a `borderOpacityOverride: double?` parameter to `GlassSurface` and pass `AntraColors.chipGlassBorderOpacity` from `_buildEntry`. This is the preferred approach — it keeps chip border opacity local to the timeline without affecting other chip usages.

**today_timeline.dart**:

- Outer card `Padding`: `vertical: 3` → `vertical: 4`
- `GlassSurface` `padding`: `vertical: 8` → `vertical: 10`
- Section header: change `'TODAY'` to `widget.sectionLabel`, update `TextStyle`:
  - `fontWeight: FontWeight.w700` → `FontWeight.w400`
  - `letterSpacing: 1.2` → `0.4`
  - Keep `fontSize: 11`, `Colors.white38`

---

### US6 — @Mention Styling

**File**: `app/lib/widgets/today_timeline.dart`, method `_buildEntry`

Replace `Text(entry.content, ...)` with `Text.rich(...)`:

```dart
static final _mentionRegex = RegExp(r'(@\w+)');

TextSpan _buildContentSpan(String content, bool isComplete) {
  final spans = <TextSpan>[];
  int last = 0;
  for (final match in _mentionRegex.allMatches(content)) {
    if (match.start > last) {
      spans.add(TextSpan(text: content.substring(last, match.start)));
    }
    spans.add(TextSpan(
      text: match.group(0),
      style: TextStyle(
        fontWeight: isComplete ? FontWeight.normal : FontWeight.w500,
        color: isComplete ? Colors.white38 : Colors.white70,
      ),
    ));
    last = match.end;
  }
  if (last < content.length) {
    spans.add(TextSpan(text: content.substring(last)));
  }
  return TextSpan(children: spans);
}
```

Usage in `_buildEntry`:

```dart
Expanded(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text.rich(
        _buildContentSpan(entry.content, isComplete),
        style: TextStyle(fontSize: 14, color: isComplete ? Colors.white38 : Colors.white),
      ),
      if (entry.personName != null)
        Text(entry.personName!, style: const TextStyle(fontSize: 11, color: Colors.white38)),
    ],
  ),
),
```

`_mentionRegex` is a class-level static to avoid repeated compilation.

---

### US7 — Composer and Tab Bar Integration

**File**: `app/lib/widgets/bullet_capture_bar.dart`

Add a named constant for tab bar height:

```dart
const double _kTabBarClearance = 60.0;
```

Change the outer `Padding` `bottom` value:

```dart
// Before:
bottom: keyboardVisible ? 0 : MediaQuery.viewPaddingOf(context).bottom

// After:
bottom: keyboardVisible ? 0 : MediaQuery.viewPaddingOf(context).bottom + _kTabBarClearance
```

The `_kTabBarClearance` aligns with the `_FloatingTabBar` button area height. When keyboard is hidden, the composer sits directly above the tab bar with no gap or overlap.

---

## Constitution Check — Post-Design Re-evaluation ✅ PASS

All seven changes remain within the principles. No gate failures. No complexity justification required.

---

## Complexity Tracking

No violations. All changes are incremental refinements to existing widgets using established Flutter patterns.
