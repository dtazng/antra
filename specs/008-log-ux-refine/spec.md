# Feature Specification: Log UX Refinement

**Feature Branch**: `008-log-ux-refine`
**Created**: 2026-03-13
**Status**: Draft
**Input**: Refine the logging and note/task UX of the personal CRM app with better linking, clearer task identity, improved gestures, and polished input card styling.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Fix Input Card Corners & Composer Polish (Priority: P1)

A user opens the Day View to log something. The journal composer at the bottom of the screen looks visually complete — all corners are rounded consistently, whether the keyboard is open or closed, whether the field is focused or idle. The card feels polished and intentional.

**Why this priority**: This is a visible regression — a broken UI element that is seen on every use of the app. It blocks trust in the interface before any new feature ships.

**Independent Test**: Open the app, navigate to Day View, focus and unfocus the text field, open and close the keyboard. The card should have uniform rounded corners in all states.

**Acceptance Scenarios**:

1. **Given** the app is on Day View, **When** the user has not tapped the input field, **Then** the input card has uniformly rounded corners on all four sides.
2. **Given** the user taps the text field, **When** the keyboard appears, **Then** the input card still shows rounded corners without any corner appearing square or clipped.
3. **Given** the user has entered multi-line text (3+ lines), **When** the card expands vertically, **Then** all corners remain consistently rounded.

---

### User Story 2 - Task vs Note Visual Distinction in Log Feed (Priority: P2)

A user who logged both tasks and notes in the same day can tell them apart at a glance in the Day View feed. Tasks show a distinct marker (hollow checkbox) while notes show a dot or circle. The distinction is obvious without needing to tap or expand.

**Why this priority**: The app already stores type ('note' vs 'task') but both are rendered identically in the feed. Users can't review what kind of item they logged. This is the minimum needed for the task type to have meaning.

**Independent Test**: Log a note and a task; both appear in the timeline with visually different leading indicators. Screenshot comparison reveals clear difference.

**Acceptance Scenarios**:

1. **Given** a logged note, **When** it appears in the Day View timeline, **Then** it shows a filled circle (○) or dot indicator.
2. **Given** a logged task, **When** it appears in the Day View timeline, **Then** it shows a hollow checkbox (☐) indicator.
3. **Given** a mix of notes and tasks, **When** viewing the timeline, **Then** the visual distinction is apparent without tapping any item.
4. **Given** a task entry, **When** viewed in the feed, **Then** the label "Task" or a distinct badge appears alongside the entry content.

---

### User Story 3 - Improved Type Switch in Composer (Priority: P3)

A user who wants to log a task instead of a note sees a clear, labeled switch in the composer. The switch shows the current mode (Note or Task) with a brief explanation of what each means, so the user understands the difference before committing.

**Why this priority**: The current toggle (a bare icon) has no label. New users do not know what it does. Labeling improves clarity and reduces mis-logs.

**Independent Test**: Open the composer, observe that the toggle has a visible label ("Note" or "Task") with subtitle text. Tap the toggle, confirm the label changes and the subtitle updates.

**Acceptance Scenarios**:

1. **Given** the composer is in default (Note) mode, **When** the user looks at the toggle area, **Then** they see the label "Note" and a brief subtitle like "Capture context or observation".
2. **Given** the user taps the toggle, **When** the mode switches to Task, **Then** the label reads "Task" and the subtitle reads "Capture a follow-up or action".
3. **Given** either mode is active, **When** the user submits, **Then** the log entry is saved with the correct type matching the toggle state.

---

### User Story 4 - Link Multiple People to One Log Entry (Priority: P4)

A user can attach multiple people to a single log entry — for example, "Caught up with Sarah and James over lunch." After saving, the entry appears in both Sarah's and James's person detail timelines. In the Day View feed, both names are shown compactly on the entry row.

**Why this priority**: The current composer only allows one person link per entry. Multi-person moments are common in CRM contexts. This requires a UI and data change.

**Independent Test**: Log an entry with two people linked (via picker or @mention). Navigate to each person's detail view and confirm the entry appears in both timelines.

**Acceptance Scenarios**:

1. **Given** the composer, **When** the user taps the people-link button, **Then** a person picker opens that supports selecting multiple people (not just one).
2. **Given** one or more people are selected, **When** they appear as chips in the composer input area, **Then** each chip shows the person's name with an individual remove (×) button.
3. **Given** the user types "@" in the text field, **When** they select a person from the autocomplete overlay, **Then** that person is added to the linked people list (not replacing any previously linked person).
4. **Given** a log entry linked to two people, **When** the entry is saved, **Then** it appears in the feed of each linked person's detail view.
5. **Given** two or more people are linked to a saved entry, **When** the entry is shown in the Day View timeline, **Then** all linked names are displayed compactly (e.g., "Sarah, James" or avatars) without excessive visual noise.
6. **Given** the user opens the people picker with one person already selected, **When** the picker opens, **Then** the already-selected person is visually indicated.

---

### User Story 5 - Swipe-to-Delete Log Entries (Priority: P5)

A user can swipe a log entry to the left to delete it. The deletion requires a deliberate confirmation step to prevent accidental removal. A brief undo opportunity follows the deletion.

**Why this priority**: There is currently no way to remove a logged entry. While lower priority than the above UX fixes, it is a necessary safety valve for mis-logs.

**Independent Test**: Swipe a log entry left, confirm a delete button is revealed, tap it, confirm entry disappears with an undo toast. Tap undo, confirm entry reappears.

**Acceptance Scenarios**:

1. **Given** a log entry in the timeline, **When** the user swipes it left past a threshold (≥ 40% of card width), **Then** a red "Delete" action button is revealed behind the card.
2. **Given** the delete button is revealed, **When** the user lifts their finger without tapping the button, **Then** the card snaps back to its original position.
3. **Given** the delete button is revealed, **When** the user taps "Delete", **Then** the entry is removed from the feed and an "Undo" snackbar appears for 4 seconds.
4. **Given** the undo snackbar is visible, **When** the user taps "Undo", **Then** the entry is restored to its original position.
5. **Given** the undo snackbar expires without tapping Undo, **When** 4 seconds pass, **Then** the entry is permanently deleted (soft delete in storage).
6. **Given** a task entry, **When** swiped left, **Then** the same delete flow applies as for notes.

---

### Edge Cases

- What happens when the user tries to link a person who does not yet exist in the CRM? The composer should offer an inline "Create person" option from the picker or @mention overlay.
- What happens when a linked person is later deleted from the CRM? The log entry should remain, but the person name should render as a tombstone placeholder (e.g., "Unknown person").
- What happens when the user swipes very slowly or partially? The card should snap back unless the swipe exceeds the reveal threshold.
- What happens when there are zero log entries in the timeline? The swipe gesture is not applicable; the empty state is shown instead.
- What happens when a multi-line entry causes the composer card to be taller than the screen minus the keyboard? The field must scroll internally rather than overflowing.
- What happens if the user submits while switching type rapidly? The type captured at submit time wins; no race condition.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The input composer card MUST display uniformly rounded corners in all states (idle, focused, keyboard open, multi-line expanded).
- **FR-002**: The type toggle MUST display a visible label ("Note" or "Task") indicating the current mode.
- **FR-003**: The type toggle MUST display a brief subtitle explaining the selected mode's purpose.
- **FR-004**: Log entries MUST be saved with the explicit type value corresponding to the toggle state at time of submit.
- **FR-005**: Log entries displayed in the timeline MUST render visually differently based on their type (note vs task), with a distinct leading indicator for each.
- **FR-006**: The people-linking UI MUST support attaching multiple people to a single log entry before saving.
- **FR-007**: Previously linked people MUST each be shown as a removable chip in the composer input area.
- **FR-008**: @mention selection in the text field MUST add to (not replace) the existing set of linked people.
- **FR-009**: A log entry linked to multiple people MUST appear in each linked person's detail view timeline.
- **FR-010**: All linked people's names MUST be shown on a saved log entry row in the Day View feed.
- **FR-011**: Swiping a log entry left past a threshold MUST reveal a "Delete" action button.
- **FR-012**: Tapping the revealed "Delete" button MUST remove the entry from the feed and display a 4-second "Undo" snackbar.
- **FR-013**: Tapping "Undo" within the snackbar window MUST restore the entry.
- **FR-014**: Entries not restored within 4 seconds MUST be permanently soft-deleted (is_deleted = 1) in storage.
- **FR-015**: A "Create person" affordance MUST be available inline when the @mention or people-picker finds no match for the entered name.

### Key Entities

- **BulletEntry (Log Entry)**: A journaled item with content, type ('note' | 'task'), creation timestamp, and day reference. Type is an explicit stored field, not inferred from UI.
- **BulletPersonLink**: A join record connecting one BulletEntry to one Person. Multiple links per BulletEntry are supported. Supports soft delete (is_deleted flag).
- **Person**: A CRM contact with a name and associated timeline. Appears in person detail views when linked to entries.

### Assumptions

- Soft delete (is_deleted = 1) is already the deletion pattern in the codebase; hard delete is not used.
- The `bullet_person_links` table already supports multiple person links per bullet at the database level; only the UI needs to expose this.
- The `BulletCaptureBar` widget is the single entry point for all log creation in Day View and Daily Log screens.
- The timeline in the person detail view already queries `bullet_person_links` to find entries for that person; adding new links to an existing bullet will automatically surface there.
- Undo is handled in-memory: the soft delete is delayed until the snackbar times out or the user navigates away.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The input card corner radius issue is eliminated — no square or clipped corners visible in any state (idle, focused, keyboard open, multi-line).
- **SC-002**: Users can identify whether a log entry is a note or a task at a glance without tapping or reading the content — visual distinction is present in all timeline entries.
- **SC-003**: Users can log an entry linked to two or more people in under 20 seconds from tap to saved.
- **SC-004**: The type toggle label and subtitle are readable without zooming — text is legible within the composer's existing visual constraints.
- **SC-005**: A deleted log entry can be undone within 4 seconds with a single tap — zero data loss for accidental deletions within the undo window.
- **SC-006**: Multi-person log entries appear in all linked persons' detail view timelines — no entries are missing from any person's history.
