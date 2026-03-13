# Feature Specification: Day View — Bullet Journal Refinement

**Feature Branch**: `001-day-view-journal`
**Created**: 2026-03-13
**Status**: Draft
**Input**: Refine the Day View of the personal CRM app to remove gamification and return to a calm bullet-journal workflow.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Bullet Journal Log Composer (Priority: P1)

A user opens the Day View and wants to quickly capture what happened. Instead of tapping a fixed "Coffee" or "Call" shortcut, they tap into a freeform text field, type what they did, optionally pick a person to link it to, and save it as a bullet entry in their daily log. The interaction takes less than 10 seconds and feels like writing in a journal, not filling out a form.

**Why this priority**: This is the core daily habit loop. Every other improvement depends on users being able to log naturally. Removing the shortcut row and replacing it with a composer is the most impactful change in the feature.

**Independent Test**: Open the Day View. A log composer input is visible at the bottom of the screen. Type "Had coffee with Alex". Tap "link person", select or create Alex. Save the entry. A new bullet appears in the daily log for today. Alex was not previously in contacts — a new person record was created inline without leaving the Day View.

**Acceptance Scenarios**:

1. **Given** the Day View is open, **When** the user taps the log composer area, **Then** a text input activates and the keyboard appears with no predefined type selection required.
2. **Given** the composer is active, **When** the user types a log entry and saves without linking a person, **Then** the entry is saved as an unlinked bullet in today's log.
3. **Given** the composer is active, **When** the user taps "link person" and types a name that matches an existing contact, **Then** the matching contact is shown and can be selected with one tap.
4. **Given** the composer is active, **When** the user types a name that does not match any existing contact and confirms creation, **Then** a new person record is created and the log entry is linked to it — all without navigating away from Day View.
5. **Given** an entry was just saved, **When** the composer resets, **Then** it returns to its empty idle state within 300ms.

---

### User Story 2 — Remove Gamification Elements (Priority: P1)

A user opens the Day View and sees no outreach quota, no progress bar counting "0 / 3 completed", and no motivational copy about how many people they should reach out to. The screen is calm and reflective, not performance-oriented.

**Why this priority**: Equally P1 with the composer — this is a deliberate design philosophy change. The gamified card is the most visually dominant element to remove and sets the tone of the entire Day View.

**Independent Test**: Open the Day View with an account that previously showed the "Reach out to 3 people today" card. Confirm the card, any progress bar, any completion counter, and any outreach quota text are completely absent. Confirm no other goal, streak, score, or target has replaced them anywhere on the screen.

**Acceptance Scenarios**:

1. **Given** the app is opened and the Day View loads, **When** the screen renders, **Then** no card, widget, or text displaying an outreach goal, quota, streak, or completion count is visible.
2. **Given** the Day View is in any state (with or without follow-up cards), **When** the user scrolls the full screen, **Then** no progress bar related to a people-outreach goal is present at any scroll position.
3. **Given** the Day View is updated in the future, **When** a new feature is added, **Then** any motivational or performance metric element must be explicitly requested — absent-by-default is the new rule.

---

### User Story 3 — Single Follow-Up Surface Per Person (Priority: P2)

A user with two pending follow-ups opens the Day View. Each follow-up appears as one clean card tied to a specific person — with the person's name, the context of the follow-up, and a clear action. There is no separate summary card at the top saying "You have 2 things to do today", nor is the same follow-up repeated elsewhere on the screen.

**Why this priority**: Deduplication cleans the screen. Without the summary card and with the log composer as the new primary surface, the follow-up card becomes the main actionable element. Getting it right is P2 because it depends on the gamification removal (P1) to work without conflict.

**Independent Test**: Open the Day View with 2 pending follow-ups. Count the follow-up surfaces. There should be exactly 2 — one per person. Scroll the entire screen. The same follow-up should not appear twice. There is no summary card at the top aggregating the total count.

**Acceptance Scenarios**:

1. **Given** the user has one pending follow-up for person A, **When** the Day View renders, **Then** exactly one follow-up card for person A is shown — no summary card accompanies it.
2. **Given** the user has two pending follow-ups (person A and person B), **When** the Day View renders, **Then** two follow-up cards are shown (one each) and no aggregation header is visible.
3. **Given** a follow-up card for person A is shown, **When** the user scrolls the full screen, **Then** the same follow-up information for person A does not appear in any other section (e.g., not in a briefing card, not in a summary row).
4. **Given** the user has no pending follow-ups, **When** the Day View renders, **Then** the follow-up section is either hidden or shows an appropriate empty state — never a card with "0 things to do".

---

### User Story 4 — Today Navigation Boundary (Priority: P2)

A user navigating the Day View cannot accidentally move into the future. When viewing today's date, the forward (next day) button is hidden or visually disabled. When viewing a past date, the forward button is available — but only up to today.

**Why this priority**: A minor but high-polish fix. Prevents confusion when a user tries to log for a future date that doesn't exist. P2 because it's a self-contained navigation rule with no data implications.

**Independent Test**: Open the Day View on today's date. Confirm the forward button is absent or disabled. Navigate back one day. Confirm the forward button appears. Tap forward — confirm the date moves to today. Tap forward again — confirm nothing happens (button is hidden/disabled again).

**Acceptance Scenarios**:

1. **Given** the selected date is today, **When** the Day View renders, **Then** the next-day navigation button is either hidden or rendered in a disabled, non-interactive state.
2. **Given** the selected date is yesterday, **When** the user taps the forward button, **Then** the date advances to today and the forward button becomes hidden or disabled.
3. **Given** the selected date is 3 days ago, **When** the user taps forward repeatedly, **Then** the date increments one day at a time and stops advancing once today is reached.
4. **Given** the selected date is any past date, **When** the Day View renders, **Then** the back button remains enabled so the user can continue navigating further into the past.

---

### Edge Cases

- What happens when the user has no logs and no follow-ups for today? The screen shows an empty state with the log composer visible — the user can still add an entry.
- What happens when the user tries to create a new person inline but the name field is empty? The creation is blocked with an inline validation message; the log entry is not saved until the person has a name or the person link is removed.
- What happens if a follow-up card is dismissed (marked done or snoozed) while the Day View is open? The card removes itself immediately; if it was the last follow-up, the section collapses or shows the empty state.
- What happens when the device clock rolls over midnight while the Day View is open? The displayed date and "today" boundary should update on next interaction or app resume — not necessarily in real time.
- What happens when an unlinked log entry is saved? It appears in the daily log for today as a plain bullet with no person avatar or link.

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The Day View MUST NOT display any outreach quota, goal counter, streak, score, or progress bar related to reaching out to people.
- **FR-002**: The "Reach out to N people today" card MUST be removed and MUST NOT be replaced by any equivalent gamification element.
- **FR-003**: The fixed shortcut row (Coffee, Call, Message, Note buttons) MUST be removed from the Day View.
- **FR-004**: The Day View MUST include a log composer — a freeform text input for capturing bullet-style log entries.
- **FR-005**: The log composer MUST allow saving an entry without selecting an interaction type — plain text is sufficient.
- **FR-006**: The log composer MUST allow the user to optionally link a log entry to an existing person in their contacts.
- **FR-007**: The log composer MUST allow the user to create a new person inline if the name they type does not match any existing contact — without navigating away from the Day View.
- **FR-008**: Inline person creation MUST require at minimum a name; if the name field is empty, saving MUST be blocked with an informative message.
- **FR-009**: After a log entry is saved, the composer MUST reset to its idle/empty state within 300ms.
- **FR-010**: The Day View MUST NOT show a summary card that aggregates the count of follow-up items (e.g., "You have 2 things worth doing today").
- **FR-011**: Each pending follow-up MUST appear as exactly one card on the Day View — the same follow-up MUST NOT appear in more than one location on the screen.
- **FR-012**: Follow-up cards MUST be person-specific and MUST display the relevant context (e.g., reason for follow-up, due date if applicable) in a single surface.
- **FR-013**: When the selected date equals today, the forward (next-day) navigation control MUST be hidden or rendered in a non-interactive disabled state.
- **FR-014**: When the selected date is any date before today, the forward navigation control MUST be active and allow advancing the date one day at a time, stopping at today.
- **FR-015**: The back (previous-day) navigation control MUST always be active regardless of the selected date.

### Key Entities

- **Log Entry (Bullet)**: A freeform text record tied to a specific day. Attributes: text content, date, optional link to a person, creation timestamp. Has no required type field.
- **Follow-Up Card**: An actionable item surfaced on the Day View for a specific person. Attributes: person reference, context/reason, optional due date, completion/snooze state. Rendered exactly once per pending follow-up.
- **Person**: A contact record in the CRM. Can be linked to log entries. Can be created inline from the log composer without navigating away.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user can capture a freeform log entry (with optional person link) in under 10 seconds from opening the composer.
- **SC-002**: Zero instances of outreach quota, progress bar, streak, or score elements appear anywhere in the Day View after this change.
- **SC-003**: Each pending follow-up appears exactly once on the Day View — deduplication rate is 100%.
- **SC-004**: Creating a new person inline from the log composer takes no more than 2 additional taps beyond typing the name — no screen navigation required.
- **SC-005**: The forward navigation button is unreachable (hidden or disabled) when today is the selected date — verified across all device sizes.
- **SC-006**: Users report the Day View feels "calm" or "focused" in usability testing — target 80% positive sentiment on the design direction.
- **SC-007**: The log composer is visible without scrolling on first load of the Day View on a standard phone screen size.

---

## Assumptions

- The existing follow-up card component (per-person) is retained; only the summary/aggregation card on top is removed.
- Log entries without a type field are backwards-compatible with existing bullet data — the type field defaults to a generic "log" or becomes optional.
- Inline person creation only requires a name; additional profile fields (email, notes, etc.) can be filled in later from the People screen.
- The "today" boundary for navigation is determined by the user's local device date, not a server timestamp.
- The log composer replaces the quick-action shortcut row in the same visual area — it is persistently visible on the Day View, not hidden behind a floating action button.
- Past log entries and previously logged interaction types (Coffee, Call, etc.) continue to display correctly in the timeline — only the input method changes, not the data model.
