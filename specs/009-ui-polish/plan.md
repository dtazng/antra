# Implementation Plan: UI Polish — Composer, Task Cards & Tab Bar

**Branch**: `009-ui-polish` | **Date**: 2026-03-13 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/009-ui-polish/spec.md`

## Summary

Refine the app's core UI components — the day-view timeline, log composer, and bottom tab bar — to feel cohesive, calm, and aligned with the aurora bullet-journal aesthetic. Changes span five user stories: task completion interaction (US1), removal of redundant "TASK" label (US2), dynamic card height (US3), simplified composer without sublabel (US4), and tab bar redesign using aurora palette (US5). No database migration is required — `completedAt` and `status` already exist on the `bullets` table.

## Technical Context

**Language/Version**: Dart 3.3+ / Flutter 3.19+
**Primary Dependencies**: flutter_riverpod 2.5, drift 2.18 (existing — no new packages)
**Storage**: SQLite via drift + SQLCipher. Schema version stays at **4** — no migration needed.
**Testing**: flutter_test (widget tests)
**Target Platform**: iOS (primary), Android, Web
**Project Type**: Mobile app
**Performance Goals**: Completion toggle visible within 500 ms of tap; list scroll at 60 fps with dynamic-height cards
**Constraints**: No new packages. No breaking changes to existing widget APIs (additive params only).
**Scale/Scope**: 5 files modified, 2 new DAO methods, 1 model field addition

## Constitution Check

*GATE: Must pass before implementation.*

| Principle | Check | Status |
| --------- | ----- | ------ |
| I. Code Quality — Readability | All changes are additive (new DAO methods, new widget param) or targeted removals. No cross-cutting duplication. | ✅ PASS |
| I. Code Quality — No dead code | Removing sublabel, TASK label, and Material color-scheme references cleans up dead visual paths. | ✅ PASS |
| II. Testing Standards | TodayInteractionTimeline and BulletCaptureBar already have widget tests that must be updated for new `onComplete` param. Completion toggle happy path must be covered. | ✅ PASS |
| III. UX Consistency — Capture speed | Completion toggle is a single tap with immediate local DB write. No loading state on critical path. | ✅ PASS |
| III. UX Consistency — Consistent affordances | Task completion control added consistently to all task entries in the timeline. | ✅ PASS |
| III. UX Consistency — Destructive actions | Completion is reversible (toggle). Not a destructive action. | ✅ PASS |
| IV. Performance — Scroll at 60 fps | Dynamic-height cards use natural Flutter layout expansion — no intrinsic measurements or nested scrollables. | ✅ PASS |
| Privacy & Data Integrity | `completeTask` / `uncompleteTask` enqueue sync. Both fields (`completedAt`, `status`) already included in the sync payload. | ✅ PASS |

**Complexity Tracking**: No violations. No additional justification needed.

## Project Structure

### Documentation (this feature)

```text
specs/009-ui-polish/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/
│   └── widget-contracts.md
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (files modified)

```text
app/lib/
├── database/
│   └── daos/
│       └── bullets_dao.dart          # + completeTask(), uncompleteTask()
├── models/
│   └── today_interaction.dart        # + status, completedAt fields
├── widgets/
│   ├── today_timeline.dart           # + onComplete param, remove TASK label,
│   │                                 #   remove overflow/maxLines, icon updates,
│   │                                 #   crossAxisAlignment.start
│   └── bullet_capture_bar.dart       # remove sublabel, rounded TextField
└── screens/
    ├── day_view/
    │   └── day_view_screen.dart      # + _onToggleComplete(), wire onComplete
    └── root_tab_screen.dart          # redesign _FloatingTabBar colors

app/test/
├── unit/
│   └── bullets_dao_completion_test.dart  # completeTask / uncompleteTask
└── widgets/
    ├── today_timeline_test.dart          # update for onComplete + completed state
    └── quick_log_bar_test.dart           # update for removed sublabel
```

## Implementation Notes

### US1 — Task completion

The `completeTask` and `uncompleteTask` DAO methods mirror the existing `updateBulletStatus` pattern: write in a transaction and enqueue sync. They additionally stamp/clear `completedAt`.

`TodayInteraction` model gains `status: String` and `completedAt: String?` so the timeline widget can render completion state without an extra DAO query.

`TodayInteractionTimeline` adds `onComplete` as a required callback alongside the existing `onTap` and `onDelete`. This is an additive breaking change — existing call sites (day_view_screen.dart, widget tests) must be updated to provide the callback.

Completed tasks stay in the feed (no sectioning) to preserve the bullet-journal "daily record" feel.

### US2 — Remove TASK label

In `_buildEntry` within `today_timeline.dart`, remove the trailing `if (entry.type == 'task') ...[SizedBox, Text('TASK', ...)]` block entirely.

### US3 — Dynamic card height

In `_buildEntry`, change the content `Text`:

- Remove `overflow: TextOverflow.ellipsis`
- Remove any `maxLines` constraint
- Change the wrapping `Row` `crossAxisAlignment` to `CrossAxisAlignment.start`

No layout container changes needed — Flutter's `AnimatedList` supports variable-height items natively.

### US4 — Simplified composer

In `BulletCaptureBar._buildTypeToggle` (the `GestureDetector` > `Column` block):

- Remove the second `Text` child ('Context' / 'Follow-up')
- Change the `Column` to a plain `Text` or single-child layout

For the rounded TextField:

- Add `filled: true`, `fillColor: Colors.white.withValues(alpha: 0.05)`
- Set `border`, `enabledBorder`, `focusedBorder` to `OutlineInputBorder(borderRadius: BorderRadius.circular(AntraRadius.card), borderSide: BorderSide.none)`

### US5 — Tab bar redesign

In `_FloatingTabBar.build`:

- Replace `cs.surfaceContainerHigh` / `cs.surface` with `AntraColors.auroraNavy`
- Add glass border using `AntraColors.glassBorderOpacity`

In `_TabButton.build`:

- Replace active `cs.primaryContainer.withValues(alpha: 0.8)` with `Colors.white.withValues(alpha: 0.10)`
- Replace active icon color `cs.primary` with `Colors.white`
- Replace inactive icon color with `Colors.white38`
- Remove `item.label` text rendering if currently shown (the widget uses icon-only in center; confirm no label `Text` widget is present — it isn't in current code)

The tab bar can remove the dependency on `Theme.of(context).colorScheme` entirely for the container and button styling, making it fully aurora-native.
