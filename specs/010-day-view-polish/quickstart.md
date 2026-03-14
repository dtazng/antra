# Quickstart / Integration Scenarios: Day View Polish

**Branch**: `010-day-view-polish` | **Date**: 2026-03-13

---

## Scenario 1 — Empty state: no entries at all

**Setup**: A day with zero logs and zero open tasks.

**Steps**:
1. Navigate to a day with no entries.
2. View the Day View.

**Expected**: The "Nothing to do — you're all caught up." message appears. The timeline shows nothing.

---

## Scenario 2 — Empty state: suppressed when entries exist

**Setup**: Today has one logged note.

**Steps**:
1. Log a note for today.
2. View the Day View.

**Expected**: No empty-state message appears anywhere on screen. The timeline shows the note entry.

---

## Scenario 3 — Empty state: suppressed when only suggestions empty

**Setup**: Today has one logged note. No relationship suggestions are pending.

**Steps**:
1. Ensure all relationship suggestions are dismissed.
2. View the Day View.

**Expected**: No empty-state message. The timeline shows the note. The suggestions section is absent or empty.

---

## Scenario 4 — Empty state: suppressed for completed-only day

**Setup**: Today has one task, and it was completed.

**Steps**:
1. Log a task and mark it complete.
2. View the Day View.

**Expected**: No empty-state message. The completed task entry appears in the timeline with its filled checkmark and reduced-opacity text.

---

## Scenario 5 — Timestamp reading flow

**Setup**: Log a note at 09:30.

**Steps**:
1. View the entry in the Day View timeline.
2. Scan the entry from left to right.

**Expected**: The eye lands on the content text ("Your note text") before the timestamp ("09:30"). The timestamp appears right-aligned in the row, after the content.

---

## Scenario 6 — Multiline entry indentation

**Setup**: Log a note with 4 lines of text.

**Steps**:
1. View the entry in the timeline.
2. Inspect the left edge of each text line.

**Expected**: All wrapped lines are horizontally aligned with the first character of the first line. No line wraps under the leading icon or marker.

---

## Scenario 7 — @Mention inline styling

**Setup**: Log a note: "Caught up with @Alex about the project launch."

**Steps**:
1. View the entry in the Day View.

**Expected**: "@Alex" appears with slightly brighter or bolder text than the surrounding body text. The rest of the sentence appears at normal weight. Tapping the card navigates to the bullet detail as usual.

---

## Scenario 8 — @Mention styling: completed task

**Setup**: Log a task containing "@Alex". Mark the task complete.

**Steps**:
1. View the completed task in the timeline.

**Expected**: The entire content (including "@Alex") appears at reduced emphasis (`Colors.white38`). The mention is not separately emphasized — it blends with the completed state styling.

---

## Scenario 9 — Section header: label matches navigation context

**Setup**: Navigate to Yesterday.

**Steps**:
1. View the Day View for yesterday.

**Expected**: The section header reads "Yesterday", not "TODAY". It uses quiet, non-uppercase typography.

---

## Scenario 10 — Card breathing room

**Setup**: Log 5 entries for today.

**Steps**:
1. View the Day View.

**Expected**: Cards have visible internal padding and are visibly separated from each other. The timeline feels lighter and easier to scan compared to before.

---

## Scenario 11 — Composer above tab bar

**Setup**: View the Day View with keyboard hidden.

**Steps**:
1. Observe the bottom of the screen.

**Expected**: The `BulletCaptureBar` sits visually above the floating tab bar with no overlap or gap. They appear as a single coherent bottom zone.

---

## Scenario 12 — Composer with keyboard open

**Setup**: Tap the text field in the `BulletCaptureBar`.

**Steps**:
1. Keyboard slides up.

**Expected**: The tab bar is hidden (keyboard covers it). Only the `BulletCaptureBar` is visible at the bottom. The composer is fully accessible without interference from the tab bar.

---

## Scenario 13 — Swipe-to-delete on multiline card

**Setup**: Log a note with 5 lines of text.

**Steps**:
1. Swipe the card left.

**Expected**: The red delete background appears across the full card height. The entry is deleted. An undo snackbar appears.
