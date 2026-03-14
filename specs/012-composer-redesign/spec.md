# Feature Specification: Composer Redesign & Timeline Polish

**Feature Branch**: `012-composer-redesign`
**Created**: 2026-03-14
**Status**: Draft
**Input**: User description: "Adjust the Day View composer and timeline behavior for a cleaner and more focused logging experience."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Collapsible Composer with Action Row (Priority: P1)

A user opens the app and sees the timeline with a minimal capture bar at the bottom — just the text input, nothing extra. When they tap the input, the composer expands to reveal a second row of actions: link a person, add a follow-up, cancel, and done. After tapping Done or Cancel, the composer collapses back to its minimal state.

**Why this priority**: This is the core interaction loop. Every log entry flows through the composer. Getting it right — minimal by default, fast to expand, easy to dismiss — defines the quality of the entire logging experience.

**Independent Test**: Open the timeline, verify only the text input is visible. Tap the input, verify the action row animates in. Tap Cancel, verify the composer collapses, keyboard dismisses, and the input clears.

**Acceptance Scenarios**:

1. **Given** the timeline is open and the composer is idle, **When** the user views the bottom of the screen, **Then** only the text input row is visible — the action row is hidden.
2. **Given** the composer is idle, **When** the user taps the text input, **Then** the action row animates in beneath the input, completing within 250ms.
3. **Given** the composer is expanded with unsaved text, **When** the user taps Cancel, **Then** the action row hides, the keyboard dismisses, and the input text is cleared.
4. **Given** the composer is expanded and the input is empty or whitespace, **When** the user taps Done, **Then** nothing is saved and the composer collapses.
5. **Given** the composer is expanded with valid text, **When** the user taps Done, **Then** a log entry is saved, the composer collapses, and the input clears.
6. **Given** the action row is visible, **Then** the left side shows a "Person" action and a "Follow-up" action; the right side shows "Cancel" and "Done".

---

### User Story 2 - Follow-Up Scheduling from Composer (Priority: P2)

A user writes a log entry such as "Coffee with Sarah" and wants to schedule a follow-up reminder. They tap Follow-up in the action row and choose from preset options (Later today, Tomorrow, In 3 days, Next week, Custom date). After tapping Done, the log entry is saved with a follow-up attached. The follow-up surfaces in the Needs Attention section on the chosen future date.

**Why this priority**: Follow-ups are the core value-add over a plain notes app. Making follow-up scheduling fast and inline — without leaving the composer — is key to the product's frictionless promise.

**Independent Test**: Write an entry, tap Follow-up, select "Tomorrow", tap Done. Verify the entry appears in the timeline. Verify that on the follow-up date a Needs Attention item appears referencing the original entry.

**Acceptance Scenarios**:

1. **Given** the composer is expanded, **When** the user taps "Follow-up", **Then** a time-picker appears with the options: Later today, Tomorrow, In 3 days, Next week, Custom date.
2. **Given** a follow-up time is selected and text is entered, **When** the user taps Done, **Then** the log entry is saved with the follow-up date attached.
3. **Given** a follow-up was attached and the entry is linked to a person, **When** the follow-up date arrives, **Then** the Needs Attention section shows the suggestion with context from the original entry and that person's name.
4. **Given** the user opens the follow-up picker, **When** they choose Custom date, **Then** a date picker restricts selection to future dates only.
5. **Given** a follow-up time is selected, **When** the user taps Cancel instead of Done, **Then** no entry or follow-up is saved.

---

### User Story 3 - Back to Today Navigation (Priority: P3)

A user has scrolled far down the timeline to read older entries. After reading, they want to jump back to today's entries without manually scrolling. A "Back to today" button appears once they have scrolled a meaningful distance away from today. Tapping it smoothly scrolls the view back to today's entries.

**Why this priority**: As the timeline grows, navigating back to today becomes a common action. Without a shortcut, users waste time scrolling, degrading perceived speed and focus.

**Independent Test**: Scroll the timeline more than one full screen past today's entries. Verify the button appears. Tap it and verify the scroll position returns to today.

**Acceptance Scenarios**:

1. **Given** the user is near the top of the timeline (today is visible), **When** they view the screen, **Then** the "Back to today" button is not visible.
2. **Given** the user has scrolled more than one full screen below today's entries, **When** they view the screen, **Then** a "Back to today" button is visible in a consistent, accessible position that does not cover timeline entries.
3. **Given** the "Back to today" button is visible, **When** the user taps it, **Then** the timeline smoothly animates back to today's entries.
4. **Given** the timeline has scrolled back to today, **When** today's entries are in the viewport, **Then** the "Back to today" button disappears.

---

### User Story 4 - Timeline Bottom Fade (Priority: P4)

A user scrolling the timeline notices that the content near the composer gracefully fades out rather than cutting off abruptly. The bottom of the visible content area transitions to transparent before reaching the composer, making the layout feel intentional and polished.

**Why this priority**: This is a visual refinement with no functional dependencies. It improves perceived quality but does not affect logging speed or usability directly.

**Independent Test**: Open the timeline with several entries. Verify that the bottom ~72px of the scrollable content area fades to transparent above the composer rather than hard-cutting.

**Acceptance Scenarios**:

1. **Given** the timeline has entries visible near the composer, **When** the user views the bottom of the content area, **Then** a gradient fade-out is visible between the last visible entry and the composer.
2. **Given** the timeline is empty, **When** the user views the screen, **Then** no distracting fade overlay appears in the content area.
3. **Given** the keyboard is open and the composer has grown taller, **When** the user views the timeline, **Then** the fade remains correctly aligned above the composer's top edge.

---

### Edge Cases

- What happens if the user taps Done with only whitespace? No entry is saved; the composer collapses silently.
- What happens if the user selects a past date via the custom follow-up date picker? The picker must disallow past dates.
- What happens if the composer is expanded and the app is backgrounded then foregrounded? The composer remains in its expanded state; unsaved text is preserved.
- What happens when the user links a person after selecting a follow-up time, then taps Cancel? Nothing is saved.
- What happens on devices without a home indicator safe area? The composer must still anchor cleanly to the bottom without overlapping content.
- What happens when "Back to today" is tapped while the scroll is already mid-animation? The in-progress animation is interrupted and a new animation to today begins smoothly.
- What happens if the timeline is empty and the user taps the input? The composer still expands normally (it is not blocked by an empty state).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The composer MUST display only the text input row when idle; the action row MUST be hidden.
- **FR-002**: The composer MUST expand to reveal the action row when the text input receives focus, with the animation completing within 250ms.
- **FR-003**: The action row MUST contain on the left: a Person-linking action and a Follow-up action; on the right: a Cancel button and a Done button.
- **FR-004**: The text input MUST support multi-line entry and grow vertically as content increases, up to a defined maximum height before the input becomes internally scrollable.
- **FR-005**: Tapping Cancel MUST collapse the action row, dismiss the keyboard, and clear the input text.
- **FR-006**: Tapping Done with non-empty, non-whitespace text MUST save a log entry, collapse the composer, and clear the input.
- **FR-007**: Tapping Done with empty or whitespace-only input MUST collapse the composer without saving.
- **FR-008**: The Follow-up action MUST present five time options: Later today, Tomorrow, In 3 days, Next week, Custom date.
- **FR-009**: Selecting a follow-up time and tapping Done MUST attach the chosen future date to the saved log entry as a follow-up suggestion.
- **FR-010**: The custom date option MUST restrict selection to dates that are strictly in the future.
- **FR-011**: A follow-up saved with linked persons MUST surface in the Needs Attention section on the follow-up date, referencing both the original entry text and any linked person names.
- **FR-012**: The "Back to today" button MUST remain hidden while today's entries are within the visible viewport.
- **FR-013**: The "Back to today" button MUST appear after the user has scrolled the equivalent of at least one full screen height below today's last visible entry.
- **FR-014**: Tapping "Back to today" MUST animate the timeline scroll to today's entries.
- **FR-015**: The timeline content area MUST display a gradient fade-out in the bottom portion (approximately 72px) above the composer.
- **FR-016**: The fade overlay MUST reposition correctly when the composer changes height (e.g., keyboard open, action row visible).

### Key Entities

- **Composer State**: Collapsed (text input only) or Expanded (text input + action row). Resets to Collapsed after each successful save or Cancel action.
- **Follow-up Attachment**: A future date linked to a log entry at creation time. Created only when Done is tapped with a follow-up time selected. Optionally associated with one or more linked persons.
- **Log Entry**: A user-written note created via the composer. May carry zero or more person links and an optional follow-up date.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user can write and save a log entry in under 5 seconds from tapping the input to the entry appearing in the timeline.
- **SC-002**: The action row expand animation completes within 250ms from when the text input receives focus.
- **SC-003**: The Cancel action collapses the composer, dismisses the keyboard, and clears input within 150ms — no confirmation step required.
- **SC-004**: All 5 follow-up time options plus the custom date picker are accessible within 2 taps from the composer (one to open action row, one to open follow-up picker).
- **SC-005**: The "Back to today" button appears within one scroll event after the threshold distance is exceeded — no perceptible delay.
- **SC-006**: The timeline bottom fade is visible and correctly positioned on all supported screen sizes without hiding any entry content.

## Assumptions

- The existing person-linking flow (mention chips, picker sheet) is reused in the expanded action row without a separate redesign.
- "Later today" resolves to the end of the current calendar day in local time.
- The follow-up time picker is a lightweight bottom sheet or inline popover — not a full-screen navigation.
- "One full screen height" for the Back-to-today threshold is defined as the device's visible viewport height in logical pixels.
- The fade gradient uses the existing aurora background color family to ensure visual consistency with the rest of the app.
- No changes are required to how existing entries are edited, deleted, or displayed — this spec covers the entry creation flow only.
- The composer remains anchored to the bottom of the screen in both collapsed and expanded states regardless of keyboard visibility.

## Out of Scope

- Editing or deleting existing log entries from within the composer.
- Scheduling a follow-up without first writing a log entry.
- Push or local notification delivery for follow-ups (surfacing in Needs Attention on the correct date is sufficient).
- Changes to the People tab, person detail screens, or the Needs Attention section layout.
- Swipe-to-dismiss or drag gestures on the composer.
- Any changes to the timeline header, sticky date labels, or entry card design.
