# Implementation Plan: Carried-Over Tasks and Quick-Action Cards

**Branch**: `005-task-carryover` | **Date**: 2026-03-11 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/005-task-carryover/spec.md`

## Summary

Bring carried-over task triage fully in line with the spec: fix the carry-over query to surface tasks from any past day (not just yesterday), add an inline quick-action row and age badge directly on `CarryOverTaskItem`, add a "Complete" action to `WeeklyReviewTaskItem`, and surface a badge on the Review tab whenever Weekly Review tasks are eligible. No schema changes are required — all data model fields and service methods already exist.

## Technical Context

**Language/Version**: Dart 3.3+ / Flutter 3.19+
**Primary Dependencies**: drift 2.18 (SQLite ORM), flutter_riverpod 2.5 + riverpod_annotation 2.3, intl 0.19, uuid 4.x
**Storage**: SQLite via drift + SQLCipher. Schema version 4 (no migration needed for this feature).
**Testing**: flutter_test (widget tests), unit tests for DAO query logic
**Target Platform**: iOS + Android (mobile-first)
**Project Type**: Mobile app
**Performance Goals**: Carried-over section interactive within 1 second of daily log open; quick-action response instantaneous (local write, no network)
**Constraints**: Offline-capable, local-first; no UI blocking on quick actions; 60 fps scroll
**Scale/Scope**: Personal use; up to ~100 carried-over tasks realistic

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Check | Notes |
| --- | --- | --- |
| I. Code Quality | ✅ Pass | No dead code introduced; `TaskLifecycleService` single-responsibility maintained; existing conventions followed |
| II. Testing Standards | ✅ Pass | New DAO query, widget quick-action callbacks, and age badge logic must have unit/widget tests covering happy path + defined edge cases |
| III. UX Consistency | ✅ Pass | Quick-action chips follow same visual pattern as `WeeklyReviewTaskItem`; tapping non-button area opens detail screen; destructive actions have undo snackbar |
| IV. Performance | ✅ Pass | DAO query uses indexed columns; reactive Stream<> already in place; no N+1 queries introduced |
| Privacy & Data Integrity | ✅ Pass | No new data transmitted; all writes transactional via `TaskLifecycleService`; lifecycle events append-only |

No violations. Complexity Tracking table not required.

## Project Structure

### Documentation (this feature)

```text
specs/005-task-carryover/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
└── tasks.md             # Phase 2 output (/speckit.tasks — NOT created here)
```

### Source Code (repository root)

```text
app/lib/
├── database/
│   └── daos/
│       └── task_lifecycle_dao.dart     # Fix watchCarryOverTasks query
├── providers/
│   └── task_lifecycle_provider.dart    # Update carryOverTasksProvider date logic
├── screens/
│   ├── daily_log/
│   │   └── daily_log_screen.dart       # Update section header label; pass action callbacks
│   └── review/
│       └── weekly_review_screen.dart   # _UnresolvedTasksSection: move to primary position
├── widgets/
│   ├── carry_over_task_item.dart       # Add inline action row + age badge
│   ├── weekly_review_task_item.dart    # Add Complete action; unify age badge format
│   └── root_tab_screen.dart            # Add badge on Review tab when tasks eligible
└── (no new files needed)

app/test/
├── widgets/
│   ├── carry_over_task_item_test.dart  # New widget test
│   └── weekly_review_task_item_test.dart  # New/updated widget test
└── database/daos/
    └── task_lifecycle_dao_test.dart    # New unit test for date-range query
```

**Structure Decision**: Single Flutter app; no new files — all changes are additive modifications to existing files.

---

## Phase 0: Research

*Research conducted inline during plan generation. Findings documented below.*

See [research.md](research.md) for full findings.

---

## Phase 1: Design & Contracts

See [data-model.md](data-model.md) for entity model.

This feature has no external-facing API contracts (purely local UI + SQLite). No `contracts/` artifacts needed.

See [quickstart.md](quickstart.md) for developer onboarding.

---

## Design Decisions

### D-001: Fix Carry-Over Query to Use Date Range

**Problem**: `TaskLifecycleDao.watchCarryOverTasks` currently filters `dl.date = yesterday`. A task created 3 days ago with no user interaction has `dayId` pointing to its original 3-day-old DayLog. It never appears in the Carried Over section because its DayLog date is not "yesterday".

**Decision**: Change the query to `dl.date < today AND dl.date >= sevenDaysAgo` — a date range covering the past 1–7 days. This surfaces tasks from any past day log up to the 7-day threshold.

**Impact**: `watchCarryOverTasks` and `getCarryOverTasks` in `TaskLifecycleDao` need updated SQL. The `carryOverTasksProvider` in `task_lifecycle_provider.dart` passes `yesterday` as a fixed date — this parameter is removed; the provider now passes only `today` and `sevenDaysAgo`.

**Note**: `keepForToday` moves a task's `dayId` to today's DayLog. After "Keep for Today", the task appears in today's main log (not the Carried Over section), which is the correct behaviour.

### D-002: Add Inline Quick-Action Row to CarryOverTaskItem

**Problem**: `CarryOverTaskItem` currently requires a long-press to reveal actions via `TaskQuickActionsSheet`. The spec requires action buttons visible directly on the card without requiring long-press or navigation.

**Decision**: Replace `onLongPress: onQuickAction` with a scrollable `SingleChildScrollView(Axis.horizontal)` row of action chips below the task title — matching the pattern already used in `WeeklyReviewTaskItem`. Keep `onTap` for opening the detail screen.

The `onQuickAction` callback is removed from `CarryOverTaskItem`'s API. `TaskQuickActionsSheet` can remain for the detail screen's action menu.

**Action order**: Complete (primary), Keep for Today (primary), Schedule, Backlog, → Note, Cancel (destructive). Complete and Keep for Today are visually distinct (filled/tinted chip style).

### D-003: Add Age Badge ("Nd" Format) to CarryOverTaskItem

**Problem**: `CarryOverTaskItem` shows a carryOverCount badge ("Carried over 3×") but no calendar age badge. The spec requires "1d", "3d", "7d" displayed on every carried-over task card.

**Decision**: Compute age as `DateTime.now().toLocal().difference(DateTime.parse(bullet.createdAt).toLocal()).inDays` and display as a compact badge (e.g., `"3d"`) in the card header row alongside the carry-over icon. The carryOverCount sub-label is preserved as secondary metadata.

`WeeklyReviewTaskItem` already computes age — it shows "X days old" text. Unify both to use the same compact "Nd" badge for consistency.

### D-004: Add Complete Action to WeeklyReviewTaskItem

**Problem**: `WeeklyReviewTaskItem` has: This Week, Schedule, Backlog, → Note, Cancel — but is missing Complete. The spec requires Weekly Review to offer the same quick actions as the daily Carried Over section.

**Decision**: Add a `Complete` chip as the first action in `WeeklyReviewTaskItem`'s row. Use the same `svc.completeTask(bullet.id)` call already available from `TaskLifecycleService`.

### D-005: Review Tab Badge for Weekly Review Eligibility

**Problem**: The Review tab has no indicator when weekly review tasks are present. The spec (FR-022, UXR-008) requires a visible entry point in primary navigation whenever tasks are eligible.

**Decision**: In `RootTabScreen`, watch `weeklyReviewTasksProvider`. When the list is non-empty, overlay a numeric badge on the Review tab icon using a `Badge` widget (Material 3, Flutter 3.19+). The badge count shows the number of eligible tasks. This requires no new navigation tab — it uses the existing Review tab at index 4.

### D-006: Relocate Unresolved Tasks Section in WeeklyReviewScreen

**Problem**: In `WeeklyReviewScreen`, the "Needs Attention" (`_UnresolvedTasksSection`) is buried after "Open Tasks" and "Events". The "Unresolved Tasks older than 7 days" concept is the primary content of what the spec defines as Weekly Review.

**Decision**: Move `_UnresolvedTasksSection` to the top of `WeeklyReviewScreen`'s scroll view, above "Open Tasks" and "Events". This makes the spec-defined weekly review queue the primary focus.

### D-007: Section Header Label

**Problem**: Daily log currently shows "From Yesterday" header. With the date-range fix, tasks from multiple days will appear — the label should reflect this.

**Decision**: Change the header label from "From Yesterday" to "Carried Over". This matches the spec's language and is accurate for tasks from any of the past 1–7 days.
