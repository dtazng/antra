# Quickstart: Log UX Refinement

**Branch**: `008-log-ux-refine` | **Date**: 2026-03-13

---

## Integration Scenarios

These scenarios describe how the five user stories interact end-to-end, useful for integration testing and manual QA.

---

### Scenario A: Log a Note (Happy Path)

1. Launch app → navigate to Day View.
2. Observe composer at the bottom: type toggle shows "Note" / "Context or observation", all four corners of the card are rounded.
3. Tap text field, type "Quick sync with product team".
4. Tap the add (+) button.
5. **Expected**: Entry appears in timeline with a `•` dot leading indicator, no "TASK" label. Composer clears.

---

### Scenario B: Log a Task

1. In Day View composer, tap the type toggle area on the left.
2. Toggle switches to "Task" / "Follow-up or action".
3. Type "Follow up on design feedback".
4. Tap the add (+) button.
5. **Expected**: Entry appears in timeline with a `☐` checkbox leading indicator and a "TASK" label on the right side of the row.

---

### Scenario C: Log an Entry Linked to Two People

1. In Day View composer, tap the `@` icon button.
2. Person picker opens in multi-select mode.
3. Tap "Sarah Chen" (checkmark appears), tap "James Park" (checkmark appears).
4. Tap "Done".
5. Two chips appear above the text field: "Sarah Chen ×" and "James Park ×".
6. Type "Lunch at Figma HQ".
7. Tap the add (+) button.
8. **Expected**: Entry appears in timeline showing "Sarah Chen, James Park" as muted name suffix.
9. Navigate to Sarah Chen's person detail → entry "Lunch at Figma HQ" appears in her timeline.
10. Navigate to James Park's person detail → same entry appears in his timeline.

---

### Scenario D: @Mention Adds to Existing Linked People

1. In Day View composer, tap the `@` icon, select "Sarah Chen" via picker, tap Done.
2. "Sarah Chen ×" chip appears.
3. In the text field, type "Coffee with @James".
4. @mention autocomplete shows James Park.
5. Tap "James Park" in the suggestion list.
6. **Expected**: "@James" in text is replaced with "@James Park". A "James Park ×" chip also appears. Two chips total.
7. Submit.
8. **Expected**: Entry has both Sarah and James linked.

---

### Scenario E: Remove a Linked Person Before Saving

1. Follow Scenario C steps 1–5 (Sarah and James both linked as chips).
2. Tap "×" on the "James Park" chip.
3. **Expected**: James Park chip disappears. Only Sarah remains.
4. Submit entry.
5. **Expected**: Entry appears only in Sarah's timeline, not James's.

---

### Scenario F: Swipe to Delete a Log Entry

1. With at least one entry in the Day View timeline, swipe the entry to the left.
2. A red background with a trash icon is revealed.
3. Release finger (don't swipe all the way).
4. **Expected**: Card snaps back; entry is not deleted.
5. Swipe left again, this time swipe fully (past 40% threshold).
6. **Expected**: Entry disappears from the list. A snackbar "Entry deleted · Undo" appears.
7. Tap "Undo" in the snackbar within 4 seconds.
8. **Expected**: Entry reappears in its original position in the timeline.

---

### Scenario G: Swipe to Delete — No Undo

1. Swipe an entry to delete (full swipe past threshold).
2. Snackbar appears.
3. Wait 4 seconds without tapping Undo.
4. **Expected**: Snackbar dismisses. Entry remains gone from timeline. Soft delete is permanent.

---

### Scenario H: Corner Radius — All States

1. Open Day View without focusing the composer.
2. **Expected**: Composer card shows 4 rounded corners (`AntraRadius.card = 20`).
3. Tap the text field; keyboard opens.
4. **Expected**: Composer card still shows 4 rounded corners; no corner appears square.
5. Type 4+ lines of text.
6. **Expected**: Composer card expands vertically but corners remain rounded.

---

### Scenario I: Create Person Inline from @Mention

1. In Day View composer, type "@NewFriend".
2. Autocomplete overlay shows no matching people and a "Create 'NewFriend'" option.
3. Tap "Create 'NewFriend'".
4. `CreatePersonSheet` opens, pre-filled with "NewFriend".
5. Save the new person.
6. **Expected**: "@NewFriend" in text is replaced with the created person's name. A chip for the new person appears.
