# Tasks: Composer Redesign & Timeline Polish

**Input**: Design documents from `/specs/012-composer-redesign/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, contracts/ ✅, quickstart.md ✅

**Tests**: Not explicitly requested in spec. Validation via `flutter test` (existing suite) in the Polish phase.

**Organization**: 4 user stories → 2 independent file tracks that can be worked in parallel:
- **Track A** (US1 → US2): `app/lib/widgets/bullet_capture_bar.dart` + new `follow_up_picker_sheet.dart`
- **Track B** (US3 → US4): `app/lib/screens/timeline/timeline_screen.dart`

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: User story this task belongs to
- No schema changes; no new packages; no new providers

---

## Phase 1: Setup

**Purpose**: Confirm baseline is clean before any changes.

- [X] T001 Run `flutter test` in `app/` and confirm all existing tests pass before any changes (baseline checkpoint)

---

## Phase 2: US1 — Collapsible Composer with Action Row (Priority: P1) 🎯 MVP

**Goal**: Redesign `BulletCaptureBar` so it is collapsed (text input only) by default and expands an animated action row when the user taps the input. Cancel and Done replace the old submit icon button.

**Independent Test**: Open the timeline, confirm only the text input is visible. Tap input — confirm action row animates in with Person, Follow-up, Cancel, Done. Tap Cancel — confirm row hides, keyboard dismisses, input clears.

- [X] T002 [US1] Add `late FocusNode _focusNode` and `bool _isExpanded = false` fields to `_BulletCaptureBarState`; create and dispose `_focusNode` in `initState`/`dispose` in `app/lib/widgets/bullet_capture_bar.dart`
- [X] T003 [US1] Add `_onFocusChange()` listener to `_focusNode` that calls `setState(() => _isExpanded = true)` when `_focusNode.hasFocus && !_isExpanded`; attach listener in `initState` in `app/lib/widgets/bullet_capture_bar.dart`
- [X] T004 [US1] Assign `focusNode: _focusNode` to the `TextField`; change `maxLines: 4` to `maxLines: null` to allow unlimited vertical growth; remove the old `_SubmitButton` widget from the input row in `app/lib/widgets/bullet_capture_bar.dart`
- [X] T005 [US1] Implement `_buildActionRow()` — a `Row` with left side: `[@ Person]` `GestureDetector` + `[Follow-up]` `GestureDetector`; right side: `[Cancel]` `TextButton` + `[Done]` filled `GestureDetector`; style using existing `AntraColors` and `GlassSurface` tokens in `app/lib/widgets/bullet_capture_bar.dart`
- [X] T006 [US1] Wrap `_buildActionRow()` in `ClipRect(child: AnimatedSize(duration: _isExpanded ? AntraMotion.springExpand : AntraMotion.springCollapse, curve: ..., alignment: Alignment.topCenter, child: _isExpanded ? _buildActionRow() : const SizedBox.shrink()))` and place it below the `GlassSurface` card (or inside it as a second row) in `app/lib/widgets/bullet_capture_bar.dart`
- [X] T007 [US1] Implement `_cancel()` — calls `_controller.clear()`, `_focusNode.unfocus()`, `setState(() { _isExpanded = false; _linkedPeople = []; _selectedFollowUpDate = null; })`; wire Cancel button to `_cancel()` in `app/lib/widgets/bullet_capture_bar.dart`
- [X] T008 [US1] Update `_submit()` to call `_cancel()` after a successful save (replacing inline `FocusScope.of(context).unfocus()` + `setState(() => _linkedPeople = [])`); wire Done button to `_submit()`; remove the now-unused `_SubmitButton` class from `app/lib/widgets/bullet_capture_bar.dart`

**Checkpoint**: Composer collapses/expands on focus. Cancel and Done work. Person-linking from the action row works. Multi-line input grows freely.

---

## Phase 3: US2 — Follow-Up Scheduling from Composer (Priority: P2)

**Goal**: Add a Follow-up time picker reachable from the composer action row. Selecting a preset and tapping Done saves the log entry with a follow-up date attached. The follow-up surfaces in Needs Attention on the chosen date.

**Independent Test**: Type an entry, tap Follow-up, choose "Tomorrow", tap Done. Verify entry appears in timeline and has `follow_up_date` set to tomorrow's ISO date in the database.

- [X] T009 [P] [US2] Create `app/lib/widgets/follow_up_picker_sheet.dart` with top-level `Future<DateTime?> showFollowUpPicker(BuildContext context)` function that calls `showModalBottomSheet<DateTime?>` with `isScrollControlled: true, backgroundColor: Colors.transparent`
- [X] T010 [US2] Implement `_FollowUpPickerSheet` StatelessWidget inside `follow_up_picker_sheet.dart` — a `GlassSurface(style: GlassStyle.modal)`-wrapped `SafeArea(child: Column(mainAxisSize: MainAxisSize.min))` with 5 `ListTile` rows: "Later today" (DateTime(y,m,d,23,59)), "Tomorrow" (d+1), "In 3 days" (d+3), "Next week" (d+7), "Custom date" — each tapping `Navigator.pop(context, dateValue)` in `app/lib/widgets/follow_up_picker_sheet.dart`
- [X] T011 [US2] Implement "Custom date" option: tap calls `showDatePicker(context, initialDate: tomorrow, firstDate: tomorrow, lastDate: 2 years from now)`; on selection calls `Navigator.pop(context, picked)`; on cancellation stays open in `app/lib/widgets/follow_up_picker_sheet.dart`
- [X] T012 [US2] Add `String? _selectedFollowUpDate` field to `_BulletCaptureBarState`; implement `_pickFollowUp()` that calls `await showFollowUpPicker(context)` and sets `_selectedFollowUpDate = DateFormat('yyyy-MM-dd').format(date)` if result is non-null in `app/lib/widgets/bullet_capture_bar.dart`
- [X] T013 [US2] Wire Follow-up button in `_buildActionRow()` to `_pickFollowUp()`; when `_selectedFollowUpDate != null` replace the "Follow-up" label with the selected date string (e.g. "Mar 15") and show a small indicator icon; tapping it again re-opens the picker in `app/lib/widgets/bullet_capture_bar.dart`
- [X] T014 [US2] Update `BulletsCompanion.insert()` call in `_submit()` to include `followUpDate: Value(_selectedFollowUpDate)` and `followUpStatus: Value(_selectedFollowUpDate != null ? 'pending' : null)` (no separate `addFollowUpToEntry` call needed — single transaction) in `app/lib/widgets/bullet_capture_bar.dart`

**Checkpoint**: Follow-up picker opens, all 5 presets work, custom date blocks past dates, selected date shown on button, saving sets `follow_up_date` + `follow_up_status = 'pending'` on the bullet.

---

## Phase 4: US3 — Back to Today Navigation (Priority: P3)

**Goal**: A "Back to today" pill button appears in the bottom-right corner once the user has scrolled one full screen height past today's last entry. Tapping it animates back to the top.

**Independent Test**: Scroll timeline past today. Confirm button appears. Tap it. Confirm smooth scroll back to top and button disappears.

> **Note**: This phase is independent of US1/US2 (different file). It can be worked in parallel with Phase 2/3.

- [X] T015 [P] [US3] Add `bool _showBackToToday = false` field to `_TimelineScreenState` in `app/lib/screens/timeline/timeline_screen.dart`
- [X] T016 [P] [US3] Extend `_updateStickyLabel()` with back-to-today threshold: compute `todayEnd = (_hasAttentionItems ? _kAttentionH : 0) + _kHeaderH + (_days.isNotEmpty ? _days.first.entries.length * _kEntryH : 0)`; call `if (offset > todayEnd + MediaQuery.sizeOf(context).height != _showBackToToday) setState(() => _showBackToToday = ...)` in `app/lib/screens/timeline/timeline_screen.dart`
- [X] T017 [US3] Implement `_scrollToToday()` — calls `_scrollController.animateTo(0, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic)` in `app/lib/screens/timeline/timeline_screen.dart`
- [X] T018 [US3] Create private `_BackToTodayButton` `StatelessWidget` — a small pill `GestureDetector` with a `GlassSurface`-styled container showing an upward arrow icon + "Today" label, styled with `AntraColors.auroraNavy` background and white38 text; takes a `VoidCallback onTap` in `app/lib/screens/timeline/timeline_screen.dart`
- [X] T019 [US3] Add `AnimatedOpacity(opacity: _showBackToToday ? 1.0 : 0.0, duration: AntraMotion.fadeDismiss, child: _BackToTodayButton(onTap: _scrollToToday))` inside a `Positioned(right: 20, bottom: MediaQuery.viewPaddingOf(context).bottom + 112)` in the `Stack` in `TimelineScreen.build` in `app/lib/screens/timeline/timeline_screen.dart`

**Checkpoint**: Scroll far down → button fades in. Tap → timeline animates to today. Button fades out when back at top.

---

## Phase 5: US4 — Timeline Bottom Fade (Priority: P4)

**Goal**: The timeline content fades out gracefully at the bottom, blending into the composer area instead of hard-cutting.

**Independent Test**: Open the timeline with entries. Verify the last ~25% of the content area fades to transparent. Verify taps in the faded region still register on timeline entries.

> **Note**: Modifies the same file as US3. Must follow Phase 4 (or be done in one session with Phase 4).

- [X] T020 [US4] Wrap the `body` variable (the `CustomScrollView` or loading/error widget) in `ShaderMask(shaderCallback: (bounds) => LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black, Colors.black, Colors.transparent], stops: [0.0, 0.75, 1.0]).createShader(bounds), blendMode: BlendMode.dstIn, child: body)` before placing it in the `Stack` in `app/lib/screens/timeline/timeline_screen.dart`

**Checkpoint**: Visible gradient fade at bottom of timeline. Content in faded region is still scrollable and tappable. Fade adjusts correctly when keyboard is open.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [X] T021 [P] Run `flutter analyze` in `app/` and fix all warnings and errors introduced by this feature (especially unused imports from removed `_SubmitButton`, `FocusScope` usages)
- [X] T022 [P] Run `flutter test` in `app/` — fix any tests broken by composer restructuring (hint: `day_view_screen_test.dart` tests the capture bar hint text; widget tests that pump `BulletCaptureBar` may need updates for the new expanded/collapsed layout)
- [X] T023 Manually verify all 12 quickstart scenarios from `specs/012-composer-redesign/quickstart.md` (scenarios 1–12 covering: idle state, expand, cancel, done, empty done, follow-up presets, custom date, back-to-today visibility, scroll-to-today, and bottom fade)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies — start immediately
- **Phase 2 (US1)**: Depends on Phase 1 — core composer refactor, blocks Phase 3
- **Phase 3 (US2)**: Depends on Phase 2 (US1 action row must exist to wire Follow-up button); T009–T011 (new file) can begin in parallel with Phase 2
- **Phase 4 (US3)**: Independent of Phases 2–3 (different file) — can begin after Phase 1
- **Phase 5 (US4)**: Depends on Phase 4 completion (same file, same `Stack`)
- **Phase 6 (Polish)**: Depends on all story phases complete

### User Story Dependencies

- **US1 (P1)**: Only depends on Phase 1 — no other story dependencies
- **US2 (P2)**: T009–T011 (new file) can start immediately after Phase 1; T012–T014 depend on T005 (US1 action row built)
- **US3 (P3)**: Fully independent of US1/US2 — different file; can start after Phase 1
- **US4 (P4)**: Depends on US3 (same file, sequential)

### Parallel Opportunities

- **T009–T011** (create `follow_up_picker_sheet.dart`): Can run in parallel with **T002–T008** (US1 refactor) since they touch different files.
- **T015–T019** (US3 back-to-today): Can run in parallel with **T002–T014** (US1+US2) since they modify `timeline_screen.dart` not `bullet_capture_bar.dart`.
- **T021 and T022** (analyze + test) can run in parallel after all story phases.

---

## Parallel Example: Track A vs Track B

```text
# After T001 (baseline passes), two tracks can proceed simultaneously:

Track A — bullet_capture_bar.dart:
  T002 → T003 → T004 → T005 → T006 → T007 → T008 (US1)
  ↓ (T005 unblocks T012)
  T009 [P with T002-T008] → T010 → T011 (new file, US2)
  T012 → T013 → T014 (US2 wiring)

Track B — timeline_screen.dart:
  T015 [P] + T016 [P] → T017 → T018 → T019 (US3)
  ↓
  T020 (US4)
```

---

## Implementation Strategy

### MVP (US1 Only — Phases 1–2)

1. Complete Phase 1: baseline passing
2. Complete Phase 2: collapsible composer (T002–T008)
3. **STOP and VALIDATE**: Tap input → action row animates in. Cancel → collapses. Done → saves entry. Multi-line input works.

### Incremental Delivery

1. Phase 1 + Phase 2 → **MVP**: composer collapses/expands with action row
2. Phase 3 → Follow-up scheduling inline
3. Phases 4 + 5 → Back to today + timeline fade
4. Phase 6 → Polished, all tests green

### Minimal Parallel Strategy (Solo Developer)

Follow phases strictly in order (1 → 2 → 3 → 4 → 5 → 6). Optionally create `follow_up_picker_sheet.dart` (T009–T011) as a side task while working on US1 wiring, since it is a new file with no conflicts.

---

## Notes

- No schema migration, no new packages, no new providers — pure UI refactor
- `_SubmitButton` private class in `bullet_capture_bar.dart` is fully removed in T008
- `followUpDate` and `followUpStatus` columns already exist on `bullets` table (schema v5 from `011-life-log`)
- The `ShaderMask` (T020) does not affect hit testing — scroll and tap events pass through normally
- `_BackToTodayButton` (T018) uses approximate height estimation for positioning; acceptable accuracy per research.md Decision 5
