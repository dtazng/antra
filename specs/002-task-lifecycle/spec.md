# Feature Specification: Task Lifecycle & Review Flow

**Feature Branch**: `002-task-lifecycle`
**Created**: 2026-03-10
**Status**: Draft
**Input**: User description: "Build the task lifecycle and review flow for Antra"

---

## Overview

Antra's task system should feel intentional rather than mechanical. Tasks do not silently disappear when left unfinished, but they also do not silently accumulate into an unmanageable graveyard. The system guides users through two review rituals — a lightweight daily carry-over for yesterday's unfinished work, and a weekly review for older tasks — so that every task either gets acted on or consciously dismissed.

The key design principle is that tasks are never duplicated. A task is a single object with a full lifecycle history. Its appearance in Today or in the Weekly Review queue is a function of its current state and age, not a copy.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Daily Carry-Over: Yesterday's Unfinished Tasks (Priority: P1)

A user opens the app in the morning. Today's log is ready for new entries. Below today's bullets, a "From Yesterday" section surfaces any tasks that were active yesterday and not completed. The user can quickly act on each one — mark it done, keep it, schedule it forward, send it to the backlog, cancel it, or convert it to a plain note — all from the task row without opening a detail screen.

**Why this priority**: This is the core daily ritual that prevents task debt from silently accumulating. It must work before weekly review or task detail are useful.

**Independent Test**: Create two tasks on "yesterday." Leave them unfinished. Open the app today. Verify both appear in a "From Yesterday" section. Perform each available quick action on a task and verify the task reflects the correct state.

**Acceptance Scenarios**:

1. **Given** a task was created yesterday and remains active, **When** the user opens Today, **Then** that task appears in a "From Yesterday" section, visually distinct from today's entries, with a carry-over indicator.
2. **Given** a task was completed yesterday, **When** the user opens Today, **Then** it does NOT appear in the "From Yesterday" section.
3. **Given** a task has a future scheduled date, **When** the user opens Today, **Then** it does NOT appear as a carry-over item.
4. **Given** a task is in the "From Yesterday" section, **When** the user taps "Mark Complete," **Then** the task is marked complete and removed from the section.
5. **Given** a task is in the "From Yesterday" section, **When** the user taps "Keep for Today," **Then** the task moves into today's active entries with a carry-over event recorded.
6. **Given** a task is in the "From Yesterday" section, **When** the user taps "Move to Backlog," **Then** the task enters backlog state and is removed from the daily view.
7. **Given** a task is in the "From Yesterday" section, **When** the user taps "Cancel," **Then** the task is marked canceled and removed from carry-over.
8. **Given** a task is in the "From Yesterday" section, **When** the user taps "Convert to Note," **Then** the item becomes a note-type bullet, retaining its content and losing task status.
9. **Given** a task is in the "From Yesterday" section, **When** the user taps "Schedule," **Then** they can select a future date and the task disappears from carry-over until that date.

---

### User Story 2 — Task Detail View with Lifecycle History (Priority: P2)

A user taps on any task to open its detail view. The detail view shows the full task content, current status, optional scheduled date, and the complete sequence of lifecycle events — when the task was created, when it was carried over, when it was rescheduled, and so on. All task actions are also available from this screen.

**Why this priority**: Without history visibility, users cannot tell if a task has been silently migrating for two weeks or was just created today. History is essential to the intentional character of the system.

**Independent Test**: Create a task. Carry it over once. Reschedule it. Open the detail view. Verify the history shows three events in order: created, carried over, rescheduled.

**Acceptance Scenarios**:

1. **Given** a task exists, **When** the user taps it, **Then** a detail view opens showing the task content, status, and scheduled date (if any).
2. **Given** a task has been carried over and rescheduled, **When** the user views its detail, **Then** the lifecycle history lists each event in chronological order with dates.
3. **Given** a task has been migrated multiple times, **When** the user views its detail, **Then** the carry-over count is prominently shown (e.g., "Carried over 3 times").
4. **Given** a user is in the task detail view, **When** they select any action, **Then** the action executes and the lifecycle history updates immediately.
5. **Given** a task is in backlog state, **When** the user views its detail, **Then** a "Reactivate" action is available to return it to active.

---

### User Story 3 — Weekly Review Queue (Priority: P3)

At any point, a user can open the Weekly Review screen to see all tasks that are unfinished, active, and older than 7 days. These tasks are too old for daily carry-over but have not been consciously resolved. The weekly review screen presents them and prompts the user to make a decision on each.

**Why this priority**: Without weekly review, old unresolved tasks become invisible noise. The weekly review is what prevents silent task debt from building up beyond the daily carry-over window.

**Independent Test**: Create tasks 8+ days old. Leave them unfinished. Open Weekly Review. Verify each appears. Perform each review action and verify the task state changes and the task is removed from the queue.

**Acceptance Scenarios**:

1. **Given** a task was created more than 7 days ago and is still active, **When** the user opens Weekly Review, **Then** that task appears in the review queue.
2. **Given** a task is in Weekly Review, **When** the user selects "Move to This Week," **Then** the task becomes active and leaves the review queue.
3. **Given** a task is in Weekly Review, **When** the user selects "Schedule a Day," **Then** they can pick a date and the task leaves the review queue until that date.
4. **Given** a task is in Weekly Review, **When** the user selects "Move to Backlog," **Then** the task enters backlog and leaves the queue.
5. **Given** a task is in Weekly Review, **When** the user selects "Cancel," **Then** the task is marked canceled and removed.
6. **Given** a task is in Weekly Review, **When** the user selects "Convert to Note," **Then** the item becomes a note and is removed from the queue.
7. **Given** a task appears in Weekly Review, **When** the user checks Today, **Then** that same task does NOT appear in Today's carry-over section.
8. **Given** a backlog task exists, **When** the user opens Weekly Review, **Then** it does NOT appear.
9. **Given** no tasks meet the 7-day criteria, **When** the user opens Weekly Review, **Then** an empty state is shown confirming nothing needs review.

---

### Edge Cases

- What happens if a task has a scheduled date that is now in the past? It surfaces in Today's carry-over section as an overdue item, not in Weekly Review.
- What happens if the user converts a task to a note? The carry-over history is preserved on the item; the item type changes to note and it is excluded from all task review flows permanently.
- What happens if a backlog task is reactivated? It re-enters active state with a "Reactivated" lifecycle event and becomes eligible for daily carry-over or weekly review again.
- What happens if no tasks are eligible for Weekly Review? An empty state is shown.
- What happens if a task is completed while visible in Weekly Review? It is immediately removed from the queue.
- What happens if the user opens the app after multiple days offline? Tasks are correctly surfaced based on their creation and scheduled dates — no missed carry-over events.
- What happens if a task has been carried over 3 or more times? A visible indicator appears in the detail view to draw the user's attention to the repeated deferral.

---

## Requirements *(mandatory)*

### Functional Requirements

#### Daily View

- **FR-001**: The Today screen MUST display a "From Yesterday" section below today's entries when unfinished tasks exist from the prior calendar day.
- **FR-002**: A task MUST appear in "From Yesterday" only if: it is active, it was created or last made active on the previous calendar day, and it has no future scheduled date.
- **FR-003**: Tasks in "From Yesterday" MUST display a carry-over indicator (visual marker showing the task has migrated from the previous day).
- **FR-004**: Each task in "From Yesterday" MUST support six quick actions without opening a detail view: Mark Complete, Keep for Today, Schedule, Move to Backlog, Cancel, Convert to Note.
- **FR-005**: "Keep for Today" MUST record a carry-over lifecycle event and move the task into today's active entries.
- **FR-006**: Tasks MUST NOT be duplicated at any point. All actions update the original task record.
- **FR-007**: Tasks with a future scheduled date MUST NOT appear in daily carry-over until that date arrives.

#### Task States

- **FR-008**: Every task MUST have one base state: active, completed, canceled, or backlog.
- **FR-009**: The following display states MUST be derived from base state and dates: "due today" (active, scheduled for today), "carried from yesterday" (active, last active date is yesterday with no future scheduled date), "pending weekly review" (active, older than 7 days, no future scheduled date).
- **FR-010**: Completed and canceled tasks MUST be excluded from all carry-over and review queues permanently.
- **FR-011**: Backlog tasks MUST be excluded from daily carry-over and weekly review unless explicitly reactivated.

#### Task Lifecycle History

- **FR-012**: Every task MUST maintain an ordered log of lifecycle events. Supported event types: Created, Carried Over, Kept for Today, Scheduled (with target date), Moved to Backlog, Reactivated, Entered Weekly Review, Completed, Canceled, Converted to Note.
- **FR-013**: Each lifecycle event MUST record the event type and the timestamp it occurred.
- **FR-014**: The total carry-over count MUST be stored on the task and increment each time the task is carried over or kept for today.
- **FR-015**: Task creation date and original content MUST be preserved regardless of state transitions.

#### Task Detail View

- **FR-016**: Tapping any task MUST open a detail view showing: task content, current state, scheduled date (if any), carry-over count, and full chronological lifecycle history.
- **FR-017**: All task actions MUST be accessible from the detail view: Complete, Cancel, Schedule, Move to Backlog, Reactivate (if in backlog).
- **FR-018**: After any action in the detail view, the lifecycle history MUST update immediately without requiring a reload.
- **FR-019**: Tasks with a carry-over count of 3 or more MUST display a visual emphasis on the count in the detail view.

#### Weekly Review

- **FR-020**: The Weekly Review screen MUST collect all tasks that are: active, not in backlog, not completed, not canceled, and whose creation or last-active date is more than 7 days ago.
- **FR-021**: A task MUST NOT appear in both Today's "From Yesterday" section and the Weekly Review queue simultaneously.
- **FR-022**: Each task in Weekly Review MUST support: Move to This Week, Schedule a Specific Day, Move to Backlog, Cancel, Convert to Note.
- **FR-023**: "Move to This Week" MUST record a lifecycle event and make the task eligible for daily carry-over again.
- **FR-024**: Acting on any task in Weekly Review MUST remove it from the queue immediately.

### Key Entities

- **Task**: A captured item of type "task." Has a base state (active, completed, canceled, backlog), creation date, optional scheduled date, completion timestamp, cancellation timestamp, carry-over count, and an ordered list of lifecycle events. The original content is always preserved.
- **Lifecycle Event**: A single state transition record on a task. Contains an event type and a timestamp. Events are append-only.
- **Derived Display State**: A computed property based on a task's base state, creation date, scheduled date, and carry-over history. Determines which section of the UI (today, carry-over, weekly review, backlog) the task appears in. Never stored — always computed.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can act on any carry-over task from the Today screen in under 5 seconds without opening a detail view.
- **SC-002**: Zero tasks appear simultaneously in both Today's carry-over section and the Weekly Review queue.
- **SC-003**: Every lifecycle event is recorded accurately — the event type and timestamp are always correct and the sequence is never out of order.
- **SC-004**: Tasks with a carry-over count of 3 or more always surface a visible indicator in their detail view.
- **SC-005**: After any quick action (complete, keep, backlog, cancel, schedule, convert), the task's section updates immediately with no full-screen reload.
- **SC-006**: All task data, including full lifecycle history, is fully accessible offline with no degradation.
- **SC-007**: No task older than 7 days remains silently active in the daily view without surfacing in Weekly Review.

---

## Assumptions

- The 7-day threshold for Weekly Review is measured from the task's creation date, not from the last carry-over event. A task cannot be kept in daily carry-over indefinitely to avoid the review queue.
- "Yesterday" is defined as the prior calendar day in the user's local timezone, not a rolling 24-hour window.
- "Convert to Note" is a terminal action — the item can no longer re-enter the task lifecycle.
- Scheduling a task for a specific future date removes it from all carry-over and review views until that date arrives.
- The Weekly Review screen is accessible at any time; it is not locked to a specific day of the week.
- Backlog is a manual, intentional deferral. Backlog tasks are never surfaced automatically unless the user reactivates them.
- The "From Yesterday" section only shows tasks from the immediately previous calendar day. Tasks from two or more days ago that were not acted on appear in Weekly Review once they cross the 7-day threshold; between day 2 and day 7 they are surfaced via the scheduled date logic or are treated as pending review.
