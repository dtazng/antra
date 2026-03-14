# Quickstart / Integration Scenarios: Life Log & Follow-Up System

**Branch**: `011-life-log` | **Date**: 2026-03-13

---

## Scenario 1 — First launch: two tabs visible

**Setup**: Fresh install or existing app updated to this feature branch.

**Steps**:
1. Open the app.
2. Count the primary navigation tabs.

**Expected**: Exactly two tabs are visible — "Timeline" and "People". No Today/Collections/Search/Review tabs.

---

## Scenario 2 — Log entry creation: instant save

**Setup**: Open the Timeline tab.

**Steps**:
1. Tap the capture bar at the bottom.
2. Type "Coffee with Anna".
3. Press submit (return key or send button).

**Expected**: The input clears immediately. A new entry "Coffee with Anna" appears at the top of today's group in the timeline within 500 ms. No confirmation dialog. No navigation change.

---

## Scenario 3 — Empty state: no entries at all

**Setup**: A database with zero log entries.

**Steps**:
1. Open the Timeline tab.

**Expected**: A calm empty-state message is visible. The Needs Attention section is absent. The capture bar is present at the bottom.

---

## Scenario 4 — Empty state: suppressed when entries exist

**Setup**: At least one log entry exists.

**Steps**:
1. Open the Timeline tab.

**Expected**: No empty-state message. The entry appears in the timeline grouped under "Today". The capture bar is present.

---

## Scenario 5 — Sticky date header: today

**Setup**: Log several entries today.

**Steps**:
1. Open the Timeline tab.

**Expected**: A "Today" sticky header appears above today's entries. As the user scrolls down through today's entries, "Today" remains pinned at the top.

---

## Scenario 6 — Sticky date header: scrolling past today into yesterday

**Setup**: Log entries exist for today and yesterday.

**Steps**:
1. Open the Timeline tab.
2. Scroll past today's entries into yesterday's entries.

**Expected**: The sticky header changes from "Today" to "Yesterday" as the scroll crosses the day boundary.

---

## Scenario 7 — Sticky date header: older dates

**Setup**: Log entries exist from 10 days ago.

**Steps**:
1. Scroll to the section from 10 days ago.

**Expected**: The sticky header shows a formatted date (e.g., "Mar 3"), not "Yesterday" or "Today".

---

## Scenario 8 — Person linking via @mention

**Setup**: A person "Anna" exists in the People list.

**Steps**:
1. Tap the capture bar.
2. Type "Coffee with @Ann".

**Expected**: A suggestion chip for "Anna" appears above the keyboard. Tapping it links Anna to the entry. Submitting saves the entry linked to Anna.

---

## Scenario 9 — Inline person creation

**Setup**: No person named "Julia" exists.

**Steps**:
1. Type "@Julia" in the capture bar.
2. Tap "Create Julia".
3. Submit the entry.

**Expected**: A new person "Julia" is created. The entry is linked to her. Navigating to Julia's person detail shows the entry in her relationship timeline.

---

## Scenario 10 — Attach a follow-up to a log entry

**Setup**: A log entry "Coffee with Anna" exists in the timeline.

**Steps**:
1. Tap the entry to open detail.
2. Add a follow-up date of today.
3. Return to the Timeline tab.

**Expected**: The Needs Attention section appears at the top of the Timeline with a card reading "Coffee with Anna" and showing Anna's name. The original log entry is unchanged in the timeline below.

---

## Scenario 11 — Dismiss a suggestion

**Setup**: One suggestion appears in the Needs Attention section.

**Steps**:
1. Tap the Dismiss (×) button on the suggestion card.

**Expected**: The card disappears immediately. If no other suggestions remain, the Needs Attention section disappears entirely. No completion event is added to the timeline.

---

## Scenario 12 — Mark a suggestion as Done

**Setup**: A suggestion "Coffee with Anna" appears in Needs Attention.

**Steps**:
1. Tap the Done (✓) button on the suggestion card.

**Expected**: The card disappears from Needs Attention. A new completion event "Followed up with Anna" appears in the timeline at today's date. Anna's person detail timeline also shows this event.

---

## Scenario 13 — Snooze a suggestion

**Setup**: A suggestion appears in Needs Attention.

**Steps**:
1. Tap the Snooze (clock) button.

**Expected**: The suggestion disappears from Needs Attention. It reappears 3 days later (on the snoozed-until date). No completion event is created.

---

## Scenario 14 — Needs Attention absent when empty

**Setup**: All suggestions have been dismissed or completed.

**Steps**:
1. Open the Timeline tab.

**Expected**: The Needs Attention section is absent — no empty card, no "Nothing to do" message in that section. The timeline starts immediately.

---

## Scenario 15 — Person relationship timeline: grouped entries

**Setup**: Three log entries linked to "Anna" on three different days.

**Steps**:
1. Open Anna's person detail view.

**Expected**: Entries appear grouped by date, oldest to newest, with sticky date labels. The header shows "Last seen: [most recent date]".

---

## Scenario 16 — Person relationship timeline: completion event appears

**Setup**: A follow-up for a log entry linked to "Anna" was marked Done.

**Steps**:
1. Open Anna's person detail view.

**Expected**: The completion event "Followed up with Anna" appears at the completion date in her timeline, grouped with other entries from that day.

---

## Scenario 17 — Delete a log entry removes its follow-up

**Setup**: A log entry with a pending follow-up exists.

**Steps**:
1. Swipe the entry left in the timeline.
2. Confirm deletion.

**Expected**: The entry is removed from the timeline. The associated suggestion disappears from the Needs Attention section. An undo snackbar appears briefly.
