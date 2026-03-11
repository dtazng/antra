# Feature Specification: Carried-Over Tasks and Quick-Action Cards

**Feature Branch**: `005-task-carryover`
**Created**: 2026-03-11
**Status**: Draft

---

## Feature Summary

When a user creates a task on a given day and does not resolve it, the task automatically surfaces on subsequent daily log views in a dedicated "Carried Over" section at the top of the Today screen. Each carried-over task card shows the task title, an age badge indicating how many days old it is, and a row of quick-action buttons — allowing the user to complete, defer, or dismiss the task in a single tap without opening a detail screen. Tasks that remain unresolved for more than 7 days stop appearing in the daily Carried Over section and move exclusively to a dedicated Weekly Review queue. This keeps the daily log clean, ensures no task is silently lost, and makes daily triage fast and low-friction.

---

## User Problem

Users who capture tasks in a daily bullet journal accumulate unfinished tasks across days. Without carry-over management:

- Tasks from previous days disappear from view and are forgotten.
- Users manually re-enter tasks each day, creating duplicates and extra cognitive load.
- There is no signal when a task has been pending too long and needs intentional attention.
- Stale tasks pile up in the daily view, making the list feel unmanageable over time.

This feature solves task continuity, friction-free daily triage, and long-term list hygiene — while keeping the interface fast and intentional.

---

## Primary User

A personal productivity user who uses Antra's daily log to capture tasks throughout the day, reviews them each morning, and needs to quickly decide what to carry forward, defer, or drop — without being forced into complex review flows.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Triage Carried-Over Tasks in Today's View (Priority: P1)

A user opens Antra on a new day. A "Carried Over" section appears at the top of today's log containing all tasks from previous days that were not resolved. Each card shows the task title, how many days it has been waiting, and a set of quick-action buttons. The user taps one button to resolve each task — or taps the card body to inspect the full detail.

**Why this priority**: This is the core daily behavior. Without it, tasks from previous days are invisible and the system does not exist.

**Independent Test**: Seed two unresolved tasks with createdAt dates in the past. Open today's daily log. Verify both appear in a "Carried Over" section with age badges. Tap a quick action on one. Verify it disappears from the section.

**Acceptance Scenarios**:

1. **Given** a task was created yesterday and is still open (not completed, not cancelled, not backlog, no future scheduled date), **When** the user opens today's daily log, **Then** the task appears in a "Carried Over" section above today's new entries.
2. **Given** a task is 3 days old and open, **When** the user opens today's log, **Then** the task card shows an age badge of "3d" and a visible carry-over indicator.
3. **Given** a task was completed yesterday, **When** the user opens today's log, **Then** the completed task does NOT appear in the Carried Over section.
4. **Given** a task was moved to backlog, **When** the user opens today's log, **Then** it does NOT appear in the Carried Over section.
5. **Given** a task has a scheduledDate set to a future date, **When** the user opens today's log, **Then** it does NOT appear in the Carried Over section.
6. **Given** the user opens today's log multiple times in the same day, **Then** the same task appears exactly once — no duplication.
7. **Given** all carried-over tasks have been resolved, **When** the user opens today's log, **Then** the "Carried Over" section header does not appear.

---

### User Story 2 — Quick-Action Task Cards Without Opening Detail Screen (Priority: P1)

When the user sees a carried-over task, they can tap any quick-action button on the card — Complete, Keep for Today, Schedule Later, Move to Backlog, Cancel, or Convert to Note — and the action is applied immediately. No navigation to a detail screen is required.

**Why this priority**: Fast triage is the primary value proposition. If every action requires opening a detail screen, the carry-over system loses its efficiency advantage.

**Independent Test**: Tap each of the six quick-action buttons on a different carried-over task card. For each, verify the correct state change occurs and the card is removed from (or updated in) the Carried Over section without navigation.

**Acceptance Scenarios**:

1. **Given** a carried-over task card is visible, **When** the user taps "Complete", **Then** the task status becomes complete, completedAt is recorded, a lifecycle event is logged, and the card is removed from the Carried Over section.
2. **Given** a carried-over task card is visible, **When** the user taps "Keep for Today", **Then** carryOverCount increments by 1, a lifecycle event of type `kept_for_today` is recorded, and the card remains in the Carried Over section.
3. **Given** a carried-over task card is visible, **When** the user taps "Schedule Later" and selects a future date, **Then** the task's scheduledDate is set, a `scheduled` lifecycle event is recorded, and the card is removed from the Carried Over section.
4. **Given** a carried-over task card is visible, **When** the user taps "Move to Backlog", **Then** the task status becomes backlog, a lifecycle event is recorded, and the card is removed from the Carried Over section.
5. **Given** a carried-over task card is visible, **When** the user taps "Cancel", **Then** task status becomes cancelled, cancelledAt is recorded, a lifecycle event is logged, and the card is removed from the Carried Over section.
6. **Given** a carried-over task card is visible, **When** the user taps "Convert to Note", **Then** the task type changes to note per the product decision (see Open Questions), a lifecycle event is recorded, and the item is removed from the Carried Over section.
7. **Given** a carried-over task card is visible, **When** the user taps the non-button area of the card, **Then** the task detail screen opens.

---

### User Story 3 — Weekly Review for Long-Running Tasks (Priority: P2)

A task that has been open and unresolved for more than 7 days stops appearing in the daily Carried Over section and moves to a dedicated Weekly Review queue. The user accesses Weekly Review from a visible entry point in the app and triages those tasks with the same quick actions.

**Why this priority**: This is the long-term hygiene mechanism. The daily carry-over (P1) delivers immediate value independently; Weekly Review is additive and prevents the daily view from becoming indefinitely crowded.

**Independent Test**: Create a task with createdAt 8 days in the past. Open today's daily log — verify it does NOT appear in Carried Over. Open the Weekly Review screen — verify it appears there with all quick-action options available.

**Acceptance Scenarios**:

1. **Given** a task is 8 days old, open, not scheduled, not in backlog, **When** the user opens today's log, **Then** the task does NOT appear in the Carried Over section.
2. **Given** a task is 8 days old, open, not scheduled, not in backlog, **When** the user opens the Weekly Review screen, **Then** the task appears there with quick-action buttons.
3. **Given** a task is exactly 7 days old today, **When** the user opens today's log, **Then** the task still appears in the daily Carried Over section (7 days is the final day in the daily view; 8+ days goes to Weekly Review).
4. **Given** a task is in Weekly Review, **When** the user taps "Keep Active", **Then** it remains in Weekly Review and a `kept_for_today` lifecycle event is recorded.
5. **Given** a task is in Weekly Review, **When** the user taps "Schedule" and picks a future date, **Then** the task is removed from Weekly Review and will surface on its scheduled date.
6. **Given** a task is in Weekly Review, **When** the user taps "Complete", **Then** it is marked complete and removed from Weekly Review.
7. **Given** no tasks are eligible for Weekly Review, **When** the user opens the Weekly Review screen, **Then** an empty state with a positive message is shown.

---

### Edge Cases

- **Task created today and unresolved**: Does not appear in Carried Over the same day it was created; it is a new today entry.
- **Task with scheduledDate set to today**: Appears in today's scheduled section, not in Carried Over.
- **Task with a scheduledDate that has passed**: If status is still open and the scheduled date is in the past, the task appears in Carried Over with age computed from createdAt.
- **App opened after multiple days offline**: All open, unscheduled, non-backlog tasks surface in Carried Over with correct age badges reflecting actual calendar days elapsed. Tasks older than 7 days appear in Weekly Review only.
- **User "Keeps for Today" every day for 8 days**: Task still graduates to Weekly Review after 8 days regardless of keep-for-today actions. The 7-day threshold is based on age from createdAt, not on user interaction count.
- **App first opened 10 days after a task was created with no action**: Task is in Weekly Review (age > 7 days).
- **Task modified via detail screen**: Any status change applied from the detail screen is reflected identically on the next Carried Over view refresh.
- **Convert to Note on a task linked to a person (CRM)**: The resulting note preserves all CRM links; the person's activity timeline reflects the converted entry correctly.
- **All carried-over tasks resolved in one session**: "Carried Over" section header disappears for the rest of that day.
- **Multiple tasks with the same content**: Each is treated as a distinct task object with its own lifecycle. No deduplication based on content.

---

## Requirements *(mandatory)*

### Functional Requirements

#### Daily Carry-Over Display

- **FR-001**: The system MUST display a "Carried Over" section in the today's daily log containing all tasks that meet all of: status=open, createdAt before today's calendar date, scheduledDate is null or in the past, status≠backlog, and age ≤ 7 calendar days.
- **FR-002**: Each qualifying task MUST appear in the Carried Over section exactly once, regardless of how many days have elapsed.
- **FR-003**: The original createdAt date of a task MUST never be modified by carry-over behavior.
- **FR-004**: Each carried-over task card MUST display an age badge showing days since createdAt, formatted as "1d", "2d", "7d", etc.
- **FR-005**: Each carried-over task card MUST display a visual indicator (label, icon, or badge) that distinguishes it as a carried-over item versus a new today entry.
- **FR-006**: The "Carried Over" section header MUST NOT appear if there are no carried-over tasks.
- **FR-007**: Tasks with age > 7 calendar days MUST NOT appear in the daily Carried Over section.

#### Quick Actions

- **FR-008**: Each carried-over task card MUST display the following quick-action buttons directly on the card without requiring navigation: Complete, Keep for Today, Schedule Later, Move to Backlog, Cancel.
- **FR-009**: Each carried-over task card MUST display a "Convert to Note" quick-action button. Tapping it MUST change the item's type to note in-place (same object, same id), clear task-specific status fields, preserve the full lifecycle history on the same record, log a `converted_to_note` lifecycle event, and remove the card from the Carried Over section.
- **FR-010**: Tapping "Complete" MUST: set status to complete, record completedAt timestamp, log a `completed` lifecycle event, and remove the card from the Carried Over section.
- **FR-011**: Tapping "Keep for Today" MUST: increment carryOverCount by 1, log a `kept_for_today` lifecycle event, and keep the card in the Carried Over section for the current day.
- **FR-012**: Tapping "Schedule Later" MUST: open a date picker for the user to select a future date, then set scheduledDate to that date, log a `scheduled` lifecycle event, and remove the card from the Carried Over section.
- **FR-013**: Tapping "Move to Backlog" MUST: set status to backlog, log a `moved_to_backlog` lifecycle event, and remove the card from the Carried Over section.
- **FR-014**: Tapping "Cancel" MUST: set status to cancelled, record cancelledAt timestamp, log a `cancelled` lifecycle event, and remove the card from the Carried Over section.
- **FR-015**: All quick actions MUST execute without requiring the user to navigate to the task detail screen.
- **FR-016**: Tapping the non-button area of a carried-over task card MUST open the task detail screen.

#### Passive Behavior (No Action Taken)

- **FR-017**: If no action is taken on a carried-over task, it MUST continue to appear in the Carried Over section on each subsequent day until it is resolved or exceeds the 7-day threshold.
- **FR-018**: The age badge MUST update each day to reflect the actual elapsed days since createdAt.
- **FR-019**: The task MUST NOT be duplicated, re-created, or copied to a new day log entry at any point.

#### Weekly Review

- **FR-020**: Tasks with status=open, age > 7 calendar days from createdAt, scheduledDate null or in the past, and status≠backlog MUST appear in the Weekly Review queue.
- **FR-021**: A task MUST appear in either the daily Carried Over section OR the Weekly Review queue — never both simultaneously.
- **FR-022**: The Weekly Review queue MUST be accessible from a dedicated entry point visible in the app's primary navigation when one or more tasks are eligible.
- **FR-023**: The Weekly Review screen MUST offer the same quick-action options as the daily Carried Over cards, with "Keep Active" as the equivalent of "Keep for Today".
- **FR-024**: Applying any action in Weekly Review MUST update the task's state identically to applying the same action in the daily Carried Over section.

#### Task Detail Screen

- **FR-025**: The task detail screen MUST display: task content, current status, createdAt date, scheduledDate (if set), carryOverCount, a chronological list of lifecycle history events, and all available actions.
- **FR-026**: The detail screen is for inspection and deeper editing; all daily triage actions MUST also be available from the card without requiring the detail screen.

### State and Lifecycle Rules

#### Task Status Values (explicit)

| Status      | Description                                                 |
|-------------|-------------------------------------------------------------|
| `open`      | Active, unresolved task                                     |
| `complete`  | Task marked done by the user                                |
| `cancelled` | Task dismissed as no longer relevant                        |
| `backlog`   | Deliberately parked; excluded from daily carry-over view    |

#### Derived Display States (computed, not stored)

| Derived State | Eligibility Rule |
| --- | --- |
| `carried-over` | status=open, createdAt < today, scheduledDate null or past, age ≤ 7 calendar days |
| `scheduled` | status=open, scheduledDate is a future calendar date |
| `weekly-review` | status=open, age > 7 calendar days, scheduledDate null or past, status≠backlog |

#### State Transitions

| From | Action | Result |
| --- | --- | --- |
| `carried-over` | Complete | status=complete, completedAt=now, removed from Carried Over |
| `carried-over` | Keep for Today | stays carried-over, carryOverCount+1, event logged |
| `carried-over` | Schedule Later | scheduledDate=selected, removed from Carried Over → scheduled |
| `carried-over` | Move to Backlog | status=backlog, removed from Carried Over |
| `carried-over` | Cancel | status=cancelled, cancelledAt=now, removed from Carried Over |
| `carried-over` | Convert to Note | type changed to note in-place, lifecycle history preserved, removed from Carried Over |
| `carried-over` | Age reaches day 8 | automatically moves to weekly-review (no stored state change) |
| `weekly-review` | Keep Active | stays weekly-review, carryOverCount+1, event logged |
| `weekly-review` | Schedule | scheduledDate=selected, removed from Weekly Review → scheduled |
| `weekly-review` | Complete | status=complete, completedAt=now, removed from Weekly Review |
| `weekly-review` | Move to Backlog | status=backlog, removed from Weekly Review |
| `weekly-review` | Cancel | status=cancelled, cancelledAt=now, removed from Weekly Review |
| `scheduled` | Scheduled date = today | surfaces as a today entry on scheduled date |
| `scheduled` | Scheduled date passes (still open) | returns to carried-over state next day |

#### Lifecycle Event Types

| Event Type              | Triggered When                                           |
|-------------------------|----------------------------------------------------------|
| `created`               | Task first captured                                      |
| `completed`             | Task marked complete                                     |
| `cancelled`             | Task cancelled                                           |
| `moved_to_backlog`      | Task moved to backlog                                    |
| `scheduled`             | scheduledDate set or changed                             |
| `kept_for_today`        | User tapped Keep for Today or Keep Active                |
| `converted_to_note`     | Task converted to note type                              |

#### Timing Rules

- A task becomes carried-over starting the calendar day after its createdAt date, based on the device's local midnight.
- A task becomes weekly-review-eligible when (today's date − createdAt date) > 7 calendar days.
- Age badge "7d" is the last day a task appears in the daily Carried Over section. "8d+" appears in Weekly Review.
- The 7-day threshold is measured in full calendar days, not 168-hour windows.
- "Keep for Today" does not reset the 7-day clock. Age is always computed from createdAt.

### UX Requirements

#### Carried Over Section

- **UXR-001**: The "Carried Over" section MUST appear at the top of today's daily log, above all new entries for the current day.
- **UXR-002**: If there are no carried-over tasks, the section header MUST NOT appear.
- **UXR-003**: Carried-over tasks MUST be displayed as compact rows to allow multiple items to be visible on screen simultaneously.

#### Task Card

- **UXR-004**: Each carried-over task card MUST show: task title (truncated with ellipsis if needed), age badge (e.g., "3d"), a "Carried Over" label or equivalent icon, and the six quick-action buttons.
- **UXR-005**: Quick-action buttons MUST meet minimum touch target size guidelines for mobile (44×44pt equivalent) and be accessible without expanding the card.
- **UXR-006**: The most commonly used actions — Complete and Keep for Today — MUST be visually prioritized (positioned first in the action row and/or given a distinct visual style).
- **UXR-007**: Tapping a quick-action button MUST provide immediate visual feedback (card updates or disappears) without full-screen navigation.

#### Weekly Review UX

- **UXR-008**: The Weekly Review entry point MUST be visible in the app's primary navigation whenever one or more tasks are eligible (e.g., a badge, indicator, or persistent button).
- **UXR-009**: The Weekly Review screen MUST use the same compact card layout and quick-action structure as the daily Carried Over section.

#### Detail Screen

- **UXR-010**: The detail screen MUST be reachable by tapping the non-button body area of any carried-over task card.
- **UXR-011**: The lifecycle history in the detail screen MUST be displayed in chronological order, oldest event first.

### Key Entities

- **Task (Bullet of type 'task')**: A single task object captured on a specific day. Key fields: id, content, type ('task'), status (open/complete/cancelled/backlog), createdAt, scheduledDate, completedAt, cancelledAt, carryOverCount, dayId (original day log it was captured in).
- **Lifecycle Event**: A time-stamped record of a state change or user action on a task. Key fields: id, taskId, eventType, occurredAt. Preserved indefinitely; never deleted when task state changes.
- **Day Log**: The daily container the task was originally captured in. The task always references its original dayId; it is never moved to a different day log by carry-over behavior.
- **Weekly Review Queue**: A derived list computed at runtime from task fields. Not a stored entity. Eligible tasks are those with status=open, age > 7 days, no future scheduledDate, status≠backlog.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user can triage a carried-over task (complete, defer, or dismiss) in 2 taps or fewer without navigating to a detail screen.
- **SC-002**: No task meeting the carry-over criteria is ever silently removed or absent from the user's view on a subsequent day.
- **SC-003**: A task never appears as a duplicate entry across multiple days in the daily log.
- **SC-004**: Tasks pending more than 7 days appear exclusively in the Weekly Review queue and not in the daily Carried Over section.
- **SC-005**: The "Carried Over" section and all quick-action buttons are fully interactive within 1 second of opening the daily log, regardless of how many carried-over tasks exist.
- **SC-006**: After a user resolves all carried-over tasks in a single session, the "Carried Over" section header disappears and does not reappear during that same day.

---

## Out of Scope

- Push notifications or reminders related to carried-over tasks.
- Carry-over behavior for notes or events (only tasks carry over).
- Recurring tasks or task templates.
- AI-powered triage suggestions or auto-resolution.
- Cloud sync behavior for carry-over state (handled by the sync engine separately).
- Drag-and-drop reordering within the Carried Over section.
- Collaborative or shared task carry-over.
- Bulk actions across multiple carried-over tasks simultaneously.

---

## Assumptions

- **A-001**: A "day" is defined by the device's local calendar date at midnight. Opening the app at 11:58 PM and again at 12:01 AM constitutes a new day with fresh carry-over evaluation.
- **A-002**: The 7-day threshold is measured in calendar days from createdAt. "Keep for Today" and "Keep Active" do not reset this clock.
- **A-003**: Age is always computed from createdAt, not from any scheduledDate. A task created 5 days ago always shows "5d" regardless of whether it was scheduled and the date passed.
- **A-004**: "Convert to Note" changes the task's type to note in-place on the same record. The full lifecycle history is preserved. Task-specific status fields (completedAt, cancelledAt, carryOverCount) are cleared. No separate note object is created.
- **A-005**: The Weekly Review entry point uses the existing Review tab or a clearly visible persistent button — not a new top-level navigation tab requiring significant redesign.
- **A-006**: All quick actions are applied locally and appear instantaneous to the user. Background sync is out of scope for this spec.
- **A-007**: There is no enforced upper limit on the number of tasks in the Carried Over section or Weekly Review queue.
- **A-008**: The `carryOverCount` field counts only explicit user actions (Keep for Today / Keep Active). Days that pass without any action do not increment this counter; age is the signal for passive carry-over.

---

## Open Questions

1. **Weekly Review entry point**: Where exactly in the app's navigation does Weekly Review live? Options include: (a) a badge on the existing Review tab, (b) a persistent banner or button at the bottom of today's daily log when tasks are eligible, or (c) a standalone Weekly Review screen accessible from the main tab bar. The choice significantly affects the navigation surface area required.
