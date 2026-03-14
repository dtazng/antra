# Tasks: Day View Polish — Clarity, Hierarchy & Visual Cohesion

**Input**: Design documents from `/specs/010-day-view-polish/`
**Prerequisites**: plan.md ✅ spec.md ✅ research.md ✅ data-model.md ✅ contracts/ ✅ quickstart.md ✅

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: Which user story this task belongs to (US1–US7)
- Exact file paths included in all task descriptions

---

## Phase 1: Setup (Read Existing Files)

**Purpose**: Load current state of all files touched by this feature before making any changes.

- [x] T001 Read app/lib/widgets/today_timeline.dart (full file) to understand the current Row structure in `_buildEntry`: leading icon, SizedBox(width:10) gap, SizedBox(width:40) timestamp, SizedBox(width:4), Expanded content Text, and optional personName trailing Text
- [x] T002 Read app/lib/screens/day_view/day_view_screen.dart lines 87–220 to understand empty-state rendering location inside `suggestionsAsync.when(data:)` and the scope of `interactionsAsync` at that point
- [x] T003 [P] Read app/lib/widgets/bullet_capture_bar.dart lines 260–270 to understand the current bottom padding formula in `_BulletCaptureBarState.build()`
- [x] T004 [P] Read app/test/widgets/today_timeline_test.dart to locate all 4 `TodayInteractionTimeline(...)` instantiations before modifying them
- [x] T005 [P] Read app/lib/widgets/glass_surface.dart lines 86–102 and app/lib/theme/app_theme.dart to understand the current `glassBorderOpacity = 0.15` constant and how it is used in the chip border `BoxDecoration`

---

## Phase 2: Foundational (Blocking Prerequisite)

**Purpose**: Add `sectionLabel` parameter to `TodayInteractionTimeline`. This new `required` parameter breaks all existing call sites and tests until all three tasks below are complete. All US3/US5 work in the timeline widget depends on this landing first.

**⚠️ CRITICAL**: US5 section header and all DayViewScreen call sites cannot be updated until T006 is complete.

- [x] T006 Add `required String sectionLabel` to the `TodayInteractionTimeline` constructor in app/lib/widgets/today_timeline.dart; in `build()`, replace the hard-coded `'TODAY'` string in the section header `Text` with `widget.sectionLabel`; update the header `TextStyle` to `fontWeight: FontWeight.w400, letterSpacing: 0.4` (keep `fontSize: 11, color: Colors.white38` unchanged)
- [x] T007 In app/lib/screens/day_view/day_view_screen.dart, add `sectionLabel: _displayLabel` to the `TodayInteractionTimeline(...)` call inside `interactionsAsync.when(data:)` (approx line 182); add `sectionLabel: 'Today'` to the `TodayInteractionTimeline(...)` call in the `error:` state (approx line 197)
- [x] T008 In app/test/widgets/today_timeline_test.dart, add `sectionLabel: 'Today'` to all 4 `TodayInteractionTimeline(...)` instantiations (lines 33, 60, 84, 100) so the existing test suite compiles and passes

**Checkpoint**: Run `flutter test` from `app/` — all existing tests must pass before proceeding.

---

## Phase 3: User Story 1 — Fix Empty-State Logic (Priority: P1) 🎯 MVP

**Goal**: The "Nothing to do — you're all caught up." message never appears when there are timeline entries visible on screen.

**Independent Test**: Log one entry for today. Open the Day View. Confirm no empty-state message appears. Delete all entries. Confirm the message then appears.

- [x] T009 [US1] In app/lib/screens/day_view/day_view_screen.dart inside `suggestionsAsync.when(data: (suggestions) { ... })`, change the block `if (visible.isEmpty) { return const _EmptyState(...); }` to: `if (visible.isEmpty) { if (interactionsAsync.valueOrNull?.isEmpty == true) { return const _EmptyState(icon: Icons.favorite_border_rounded, message: 'Nothing to do — you\'re all caught up.'); } return const SizedBox.shrink(); }` — `interactionsAsync` is already watched in `build()` and is in scope

**Checkpoint**: Log one entry → no empty state. Delete all entries → empty state appears. Suggestions empty but timeline non-empty → no empty state.

---

## Phase 4: User Story 2 — Task vs Note Distinction (Priority: P2)

**Status**: ✅ Pre-completed in feature 009-ui-polish. Hollow circle icon for open tasks, filled checkmark for completed tasks, and a simple dot for notes are already implemented in `today_timeline.dart`. No implementation tasks required for this phase.

---

## Phase 5: User Story 3 & 4 — Timestamp Repositioning + Multiline Indentation (Priority: P3, P4)

**Goal**: The timestamp moves to trailing-right of each entry row. Content text becomes the primary visual element. Multiline wrapped lines align with the content column start (resolves US4 simultaneously — no separate task needed).

**Independent Test**: Log three entries at different times. Scan the timeline left-to-right. For each entry, the content text is reached before the timestamp. Log a 4-line note and confirm all wrapped lines start at the same horizontal position.

- [x] T010 [US3] In `_buildEntry` in app/lib/widgets/today_timeline.dart, restructure the inner `Row` children: (1) change leading icon to content gap from `SizedBox(width: 10)` to `SizedBox(width: 8)`; (2) remove the `SizedBox(width: 40, child: Text(_timeFmt.format(entry.loggedAt), ...))` and `SizedBox(width: 4)` that currently sit between the leading icon and content; (3) replace `Expanded(child: Text(entry.content, style: TextStyle(fontSize: 14, color: isComplete ? Colors.white38 : Colors.white)))` and the separate trailing `if (entry.personName != null) ...[SizedBox(6), Text(personName, ...)]` with `Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(entry.content, style: TextStyle(fontSize: 14, color: isComplete ? Colors.white38 : Colors.white)), if (entry.personName != null) Text(entry.personName!, style: const TextStyle(fontSize: 11, color: Colors.white38))]))` ; (4) add at the end of the Row: `const SizedBox(width: 8)` and `Text(_timeFmt.format(entry.loggedAt), style: const TextStyle(fontSize: 11, color: Colors.white30))`

**Checkpoint**: Timeline entries show content before timestamp. A 4-line note's wrapped lines align with the first content character.

---

## Phase 6: User Story 5 — Spacing, Card Styling & Section Header (Priority: P5)

**Goal**: Cards breathe more. Borders are subtler. The section header is quiet and editorial.

**Independent Test**: View a Day View with 5+ entries. Cards are visibly separated. Borders are subtle. The section header is legible but understated. The "Today" label matches the navigation context (not hard-coded "TODAY").

- [x] T011 [P] [US5] Add `static const double chipGlassBorderOpacity = 0.08` to the `AntraColors` class in app/lib/theme/app_theme.dart, immediately after the existing `static const double glassBorderOpacity = 0.15` line
- [x] T012 [P] [US5] In app/lib/widgets/glass_surface.dart, add `this.borderOpacityOverride` as a `final double? borderOpacityOverride;` field and optional named constructor parameter to `GlassSurface`; in `_GlassSurfaceState.build()`, change the `Border.all` call's `color` argument from `Colors.white.withValues(alpha: AntraColors.glassBorderOpacity)` to `Colors.white.withValues(alpha: widget.borderOpacityOverride ?? AntraColors.glassBorderOpacity)`
- [x] T013 [US5] In `_buildEntry` in app/lib/widgets/today_timeline.dart (depends on T011 and T012): (1) change the outer card `Padding` `vertical` from `3` to `4`; (2) change the `GlassSurface` `padding:` from `EdgeInsets.symmetric(horizontal: 12, vertical: 8)` to `EdgeInsets.symmetric(horizontal: 12, vertical: 10)`; (3) add `borderOpacityOverride: AntraColors.chipGlassBorderOpacity` as a named argument to the `GlassSurface(...)` constructor call

**Checkpoint**: Cards have visible internal padding and soft borders. Section header reads "Today" / "Yesterday" / "Mar 10, 2026" in quiet typography.

---

## Phase 7: User Story 6 — @Mention Styling (Priority: P6)

**Goal**: Person mentions (`@Name`) within log entries are subtly visually differentiated from body text.

**Independent Test**: Log "Caught up with @Alex about the project." View the entry. "@Alex" appears with slight visual emphasis. Tap the card — it navigates to bullet detail as usual.

- [x] T014 [US6] In `_TodayInteractionTimelineState` in app/lib/widgets/today_timeline.dart: (1) add class-level static `static final _mentionRegex = RegExp(r'(@\w+)');` immediately after `static final _timeFmt`; (2) add helper method `TextSpan _buildContentSpan(String content, bool isComplete)` that iterates `_mentionRegex.allMatches(content)`, accumulating `TextSpan` children — non-mention text uses the inherited style, mention text uses `TextStyle(fontWeight: isComplete ? FontWeight.normal : FontWeight.w500, color: isComplete ? Colors.white38 : Colors.white70)`, returns `TextSpan(children: spans)`; (3) in `_buildEntry`, replace the `Text(entry.content, style: TextStyle(fontSize: 14, color: isComplete ? Colors.white38 : Colors.white))` inside the Column (added in T010) with `Text.rich(_buildContentSpan(entry.content, isComplete), style: TextStyle(fontSize: 14, color: isComplete ? Colors.white38 : Colors.white))`

**Checkpoint**: "@Name" mentions are visually emphasized in open entries and blended at reduced opacity in completed entries.

---

## Phase 8: User Story 7 — Composer and Tab Bar Integration (Priority: P7)

**Goal**: The `BulletCaptureBar` sits visually above the floating tab bar as a unified bottom region when the keyboard is hidden.

**Independent Test**: View the Day View with keyboard hidden. The composer sits directly above the tab bar with no gap or overlap. Open the composer — the tab bar is hidden, the composer is fully accessible.

- [x] T015 [US7] In app/lib/widgets/bullet_capture_bar.dart: (1) add top-level file constant `const double _kTabBarClearance = 60.0;` immediately after `const _uuid = Uuid();` (line 16); (2) in `_BulletCaptureBarState.build()`, change the `Padding` `bottom:` value from `keyboardVisible ? 0 : MediaQuery.viewPaddingOf(context).bottom` to `keyboardVisible ? 0 : MediaQuery.viewPaddingOf(context).bottom + _kTabBarClearance`

**Checkpoint**: Composer sits flush above the tab bar when keyboard is hidden. Keyboard open hides the tab bar and exposes the full composer.

---

## Phase 9: Polish & Validation

**Purpose**: Verify all user stories work together, no regressions.

- [x] T016 [P] Run `flutter test` from app/ directory and confirm all tests pass (0 failures)
- [x] T017 [P] Run `flutter analyze` from app/ directory and confirm no new issues introduced by this feature (pre-existing issues are acceptable)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Requires Phase 1 reads — BLOCKS all user story work in `today_timeline.dart` and `day_view_screen.dart`
- **US1 (Phase 3)**: Requires Phase 2 (T007 adds `sectionLabel` to the call site); modifies `day_view_screen.dart` only
- **US2 (Phase 4)**: Pre-completed — no tasks
- **US3/US4 (Phase 5)**: Requires Phase 2 (T006 adds `sectionLabel`); modifies `today_timeline.dart`
- **US5 (Phase 6)**: Requires US3/US4 complete (same file: `today_timeline.dart`); T011 and T012 can run in parallel (different files); T013 depends on T011 and T012
- **US6 (Phase 7)**: Requires US5 complete (same file: `today_timeline.dart`)
- **US7 (Phase 8)**: Independent of US1–US6 (different file: `bullet_capture_bar.dart`) — can start after Phase 2
- **Polish (Phase 9)**: All phases complete

### Parallel Opportunities

- T001–T005 (Setup reads): T003, T004, T005 can all run in parallel with each other and T001/T002
- After Phase 2: US1 (`day_view_screen.dart`) and US3 (`today_timeline.dart`) can run concurrently — different files
- After Phase 2: US7 (`bullet_capture_bar.dart`) can run concurrently with US1 and US3 — different file
- T011 and T012 (US5 setup) can run in parallel — `app_theme.dart` vs `glass_surface.dart`
- T016 and T017 (flutter test / flutter analyze) can run in parallel

### today_timeline.dart — Sequential Edit Order

All modifications to `today_timeline.dart` must be sequential:

1. **T006** (Foundational): Add `sectionLabel` param + header label/style
2. **T010** (US3): Restructure Row — move timestamp to trailing, wrap content in Column
3. **T013** (US5): Increase card padding, add `borderOpacityOverride`
4. **T014** (US6): Replace `Text(content)` with `Text.rich(_buildContentSpan(...))`

---

## Implementation Strategy

### MVP (User Story 1 Only)

1. Complete Phase 1: Setup reads
2. Complete Phase 2: Add `sectionLabel` param (T006–T008)
3. Complete Phase 3: Fix empty-state condition (T009)
4. **STOP and validate**: Day with entries → no empty state. Empty day → message appears.
5. Run `flutter test` to confirm all tests pass

### Full Delivery

1. Phase 1 + 2 (foundation)
2. Phase 3 (US1 — empty state fix, `day_view_screen.dart`)
3. Phase 5 (US3/US4 — timestamp reposition, `today_timeline.dart`)
4. Phase 6 (US5 — spacing + border, `app_theme.dart` → `glass_surface.dart` → `today_timeline.dart`)
5. Phase 7 (US6 — mention rich text, `today_timeline.dart`, sequential after US5)
6. Phase 8 (US7 — composer padding, `bullet_capture_bar.dart`, independent)
7. Phase 9 (tests + analyze)

---

## Notes

- No new packages — all changes use Flutter core + existing AntraColors/AntraRadius/AntraMotion tokens
- No DB migration — no data model changes
- US2 (task vs note distinction) is pre-completed from 009-ui-polish; no code changes needed
- US4 (multiline indentation) is automatically resolved by the US3 Row restructuring (T010); no separate task
- `sectionLabel` is a **breaking additive** change to `TodayInteractionTimeline` — all three of T006/T007/T008 must land before any tests pass
- `borderOpacityOverride` on `GlassSurface` is backward-compatible (optional param with `??` fallback to `glassBorderOpacity`) — no other `GlassSurface` usages are affected
- The optional timeline connector treatment described in spec assumptions (subtle vertical line between entries) is **out of scope** for this feature
