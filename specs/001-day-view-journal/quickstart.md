# Quickstart: Day View — Bullet Journal Refinement

**Feature**: `001-day-view-journal`
**Date**: 2026-03-13

These scenarios describe end-to-end verification flows for each user story. Use these to validate the implementation after tasks are complete.

---

## Scenario 1: Capture a freeform journal entry (US1 — happy path)

**Precondition**: App is open on Day View, today selected, at least one contact exists ("Alex").

1. Tap the journal composer at the bottom of the screen.
2. Keyboard appears. Composer activates.
3. Type "Had a great chat with Alex @Alex".
4. After typing "@", the `@mention` overlay appears showing "Alex" as a match.
5. Tap "Alex" in the overlay. The mention resolves to "@Alex" in the text.
6. Tap the submit button.
7. **Expected**: Spinner shows briefly (< 500ms), then the composer clears and the keyboard hides. The entry "Had a great chat with Alex @Alex" does NOT appear in the follow-up card section — it appears in the timeline (if the timeline shows person-linked bullets).

---

## Scenario 2: Create a new person inline (US1 — inline creation)

**Precondition**: App is open on Day View. The name "Jordan" does not exist in contacts.

1. Tap the journal composer.
2. Type "Ran into Jordan @Jord".
3. The `@mention` overlay shows "Create 'Jord'" (no match found).
4. Tap "Create 'Jord'".
5. `CreatePersonSheet` slides up as a modal. Pre-filled with name "Jord".
6. Edit name to "Jordan". Tap Save.
7. Sheet dismisses. The mention resolves to "@Jordan" in the text.
8. Tap submit.
9. **Expected**: Entry saved. Jordan now exists in contacts. No navigation away from Day View occurred.

---

## Scenario 3: Save an unlinked journal entry (US1 — no person)

**Precondition**: App is open on Day View.

1. Tap the journal composer.
2. Type "Morning reflection — quiet day ahead."
3. Do not type `@` or tap any person.
4. Tap submit.
5. **Expected**: Entry saved. Composer clears. No person link created. Entry does not appear in the `TodayInteractionTimeline` (which only shows person-linked bullets). No error shown.

---

## Scenario 4: Gamification elements absent (US2)

**Precondition**: App is open on Day View. Account may or may not have pending follow-ups.

1. Scroll the entire Day View from top to bottom.
2. **Expected** (all must be true):
   - No card with "Reach out to N people today" visible.
   - No progress bar of any kind on the screen.
   - No text like "0 / 3 completed" or similar quota copy.
   - No streak counter, score, or badge.

---

## Scenario 5: Single follow-up per person, no summary card (US3)

**Precondition**: Account has 2 pending follow-ups: "Alex" (overdue) and "Sam" (birthday soon).

1. Open Day View.
2. **Expected**:
   - Exactly two follow-up cards visible — one for Alex, one for Sam.
   - No card saying "Here are 2 things worth doing today" or equivalent summary.
   - Scrolling the full screen reveals no duplicate follow-up for Alex or Sam in any other section.

---

## Scenario 6: Follow-up dismiss removes card cleanly (US3 — edge case)

**Precondition**: One follow-up card visible for "Alex".

1. On Alex's follow-up card, tap the dismiss/done action.
2. **Expected**: Card fades/removes from the screen immediately. The "Nothing to do — you're all caught up." empty state is displayed. No count, progress, or quota appears.

---

## Scenario 7: Today navigation boundary — forward button hidden (US4)

**Precondition**: App is open on Day View showing today's date.

1. Look at the AppBar date navigator.
2. **Expected**: Only the left (previous) arrow is visible. The right (next) arrow is absent.
3. Swipe right (fast horizontal drag to the left edge).
4. **Expected**: Date does not advance (swipe right = go to next day, which is blocked).

---

## Scenario 8: Forward button reappears on past dates (US4)

**Precondition**: App is open on Day View showing today.

1. Tap the left arrow to navigate to yesterday.
2. **Expected**: Both left and right arrows are now visible.
3. Tap the right arrow.
4. **Expected**: Date returns to today. Right arrow disappears again.
5. Tap the right arrow (or swipe) again.
6. **Expected**: Date does not advance past today.

---

## Scenario 9: Submit blocked on empty text (US1 — edge case)

**Precondition**: Journal composer is visible.

1. Tap into the composer field.
2. Do not type anything (or type whitespace only).
3. Observe the submit button.
4. **Expected**: Submit button is disabled (not tappable, visually dimmed). Nothing happens if tapped.

---

## Scenario 10: Composer resets quickly after save (US1 — constitution perf check)

**Precondition**: Journal composer has text entered.

1. Type "Quick note."
2. Tap submit.
3. **Expected**: Text field is cleared and keyboard is dismissed within 300ms of the save completing. The composer returns to Idle state without visible layout jank.
