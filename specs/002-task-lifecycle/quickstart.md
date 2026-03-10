# Quickstart: Task Lifecycle & Review Flow

**Branch**: `002-task-lifecycle` | **Date**: 2026-03-10

Integration scenarios for validating the feature end-to-end.

---

## Scenario 1: Basic daily carry-over

**Goal**: Verify that yesterday's unfinished task appears in "From Yesterday" and can be resolved.

1. Set device date to Day 1. Open app. Capture a task: "Call dentist."
2. Close app. Set device date to Day 2. Open app.
3. **Expected**: "From Yesterday" section appears below today's entries. "Call dentist" is shown with a carry-over indicator.
4. Tap "Keep for Today" on "Call dentist."
5. **Expected**: Task moves into today's active entries. "From Yesterday" section disappears (no more carry-overs).
6. Open the task detail. **Expected**: Lifecycle history shows two events: "Created" (Day 1) and "Kept for Today" (Day 2). Carry-over count: 1.

---

## Scenario 2: Carry-over count accumulates over days

**Goal**: Verify that repeated carries increment the count and surface a warning at 3+.

1. Create task on Day 1. Do nothing.
2. On Day 2: tap "Keep for Today." Count becomes 1.
3. On Day 3: it appears in carry-over again. Tap "Keep for Today." Count becomes 2.
4. On Day 4: it appears again. Tap "Keep for Today." Count becomes 3.
5. Open task detail. **Expected**: Carry-over count shows "Carried over 3×" in amber/warning color.

---

## Scenario 3: Schedule removes task from carry-over

**Goal**: Verify that a scheduled task disappears until its date.

1. Create task. On Day 2, it appears in "From Yesterday."
2. Tap "Schedule." Pick Day 5.
3. **Expected**: Task disappears from "From Yesterday" on Days 2, 3, 4.
4. On Day 5, task appears in the main today section as "due today."

---

## Scenario 4: Move to backlog

**Goal**: Verify backlog exclusion.

1. Create task on Day 1. On Day 2, tap "Move to Backlog."
2. **Expected**: Task disappears from all carry-over and review queues.
3. In task detail, tap "Reactivate."
4. **Expected**: Task re-enters today's active entries. Lifecycle history shows "Moved to Backlog" and "Reactivated."

---

## Scenario 5: Weekly Review eligibility

**Goal**: Verify that a task older than 7 days surfaces in Weekly Review, not carry-over.

1. Create task on Day 1. Do not act on it (no carry-over clicks).
2. On Day 8 (7 days later): open app.
3. **Expected**: Task does NOT appear in "From Yesterday" (it's 7 days old → Weekly Review).
4. Open Weekly Review screen.
5. **Expected**: Task appears in "Needs Attention" section with "7 days old" indicator.
6. Tap "This Week."
7. **Expected**: Task moves back into today's active log. Weekly Review queue is empty.

---

## Scenario 6: Convert to note

**Goal**: Verify terminal conversion.

1. Create task. In "From Yesterday," tap "Convert to Note."
2. **Expected**: Item type changes to note. It disappears from "From Yesterday."
3. Item appears in today's log as a note (circle bullet, not checkbox).
4. **Expected**: In task detail (before conversion), lifecycle event "Converted to Note" is the last entry.
5. **Expected**: The converted item never appears in carry-over or Weekly Review again.

---

## Scenario 7: Cancel with undo

**Goal**: Verify that cancel is reversible within the undo window.

1. In "From Yesterday," tap "Cancel Task."
2. **Expected**: Task disappears. A snackbar appears: "Task canceled. Undo" for 3 seconds.
3. Tap "Undo" within the 3-second window.
4. **Expected**: Task reappears in "From Yesterday." Its lifecycle history shows no canceled event (the cancel was reversed before being committed).

---

## Scenario 8: Mutual exclusion of carry-over and weekly review

**Goal**: Verify a task never appears in both sections simultaneously.

1. Create task 8 days ago (older than 7 days). Carry it over to yesterday via database seed.
2. Today: open app.
3. **Expected**: Task does NOT appear in "From Yesterday" (because `created_at > 7 days ago`).
4. Open Weekly Review.
5. **Expected**: Task appears here exactly once.
