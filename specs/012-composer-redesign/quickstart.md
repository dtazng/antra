# Quickstart: Composer Redesign & Timeline Polish

**Feature**: `012-composer-redesign`
**Date**: 2026-03-14

---

## Integration Scenarios

These scenarios can be run manually or drive widget test setup. Each is independently verifiable against the spec acceptance criteria.

---

### Scenario 1 — Composer: Idle State

**Setup**: Open the app on the Timeline tab with any number of entries (including zero).

**Steps**:
1. View the bottom of the screen.

**Expected**:
- Only the text input row is visible.
- No action row (no Person, Follow-up, Cancel, or Done buttons).
- The text input shows the placeholder "Log an entry…".

---

### Scenario 2 — Composer: Expand on Tap

**Setup**: Timeline is open; composer is in collapsed (idle) state.

**Steps**:
1. Tap the text input field.

**Expected**:
- The keyboard appears.
- The action row animates in below the input within ~250ms.
- Left side shows "@ Person" and "Follow-up" buttons.
- Right side shows "Cancel" and "Done" buttons.

---

### Scenario 3 — Composer: Cancel Clears and Collapses

**Setup**: Composer is expanded; user has typed "Coffee with Sarah" in the input.

**Steps**:
1. Tap **Cancel**.

**Expected**:
- The action row animates out.
- The keyboard dismisses.
- The text input is cleared (empty).
- No entry is saved to the timeline.

---

### Scenario 4 — Composer: Done Saves Entry

**Setup**: Composer is expanded; user has typed "Sent intro email to Mark".

**Steps**:
1. Tap **Done**.

**Expected**:
- A new entry "Sent intro email to Mark" appears at the top of the timeline under today's date.
- The composer collapses to idle state.
- The text input is cleared.

---

### Scenario 5 — Composer: Done with Empty Input

**Setup**: Composer is expanded; the text input is empty.

**Steps**:
1. Tap **Done**.

**Expected**:
- No entry is saved.
- The composer collapses to idle state (same as Cancel).

---

### Scenario 6 — Follow-Up: Select a Preset

**Setup**: Composer is expanded; user has typed "Coffee with Anna".

**Steps**:
1. Tap **Follow-up**.
2. In the picker sheet, tap **Tomorrow**.

**Expected**:
- The picker sheet closes.
- The Follow-up button in the action row now shows "Tomorrow" (or the date label).
3. Tap **Done**.

**Expected**:
- The entry "Coffee with Anna" is saved.
- A follow-up is attached with tomorrow's date and status `pending`.
- On tomorrow's date, the entry appears in the Needs Attention section.

---

### Scenario 7 — Follow-Up: Custom Date

**Setup**: Composer is expanded with some text; Follow-up picker is open.

**Steps**:
1. Tap **Custom date**.
2. The platform date picker opens.
3. Attempt to select today's date.

**Expected**: Today is not selectable (greyed out or past the minimum).

4. Select a date 5 days from now.
5. Confirm the date picker.

**Expected**:
- The Follow-up picker sheet shows the selected date.
6. Tap the date row (or it auto-closes).

**Expected**:
- Sheet closes; action row shows the chosen date.

---

### Scenario 8 — Follow-Up: Cancel After Selecting

**Setup**: Composer is expanded; a follow-up date has been selected (shown on Follow-up button).

**Steps**:
1. Tap **Cancel**.

**Expected**:
- No entry is saved.
- No follow-up suggestion is created.

---

### Scenario 9 — Back to Today: Button Appearance

**Setup**: Timeline has entries spanning multiple days. User is at the top (today visible).

**Steps**:
1. Verify the "Back to today" button is **not** visible.
2. Scroll down until today's entries have scrolled fully off screen AND an additional screen-height of content is below.

**Expected**: The "Back to today" button appears (fades in) in the bottom-right corner above the composer.

---

### Scenario 10 — Back to Today: Scroll to Top

**Setup**: "Back to today" button is visible (user has scrolled far down).

**Steps**:
1. Tap **Back to today**.

**Expected**:
- The timeline animates smoothly to the top.
- Today's entries are visible.
- The "Back to today" button disappears (fades out).

---

### Scenario 11 — Timeline Bottom Fade

**Setup**: Timeline has at least 3 entries visible.

**Steps**:
1. View the bottom portion of the timeline content, just above the composer.

**Expected**:
- The last visible entry fades to transparent as it approaches the composer area.
- No hard cutoff between the timeline and the composer.
- The fade is clearly visible but subtle — it does not obscure readable content.

---

### Scenario 12 — Fade Repositions with Keyboard

**Setup**: Timeline is visible with the bottom fade.

**Steps**:
1. Tap the composer input to expand it and raise the keyboard.

**Expected**:
- The fade gradient shifts upward to remain above the now-taller composer area.
- No content is shown "through" or below the composer.
