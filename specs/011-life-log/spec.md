# Feature Specification: Life Log & Follow-Up System

**Feature Branch**: `011-life-log`
**Created**: 2026-03-13
**Status**: Draft
**Input**: User description: "Implement a major UX and product model simplification for Antra. Remove the current task-centric and day-centric structure and replace it with a life log + follow-up system."

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Log an Entry (Priority: P1)

A user opens the app and immediately sees a fixed capture bar at the bottom of the screen. They type "Coffee with Anna" and press submit. The entry is saved instantly and appears at the top of their infinite scroll timeline, grouped under "Today". No mode selection, no extra screens, no confirmation dialogs.

**Why this priority**: The log entry is the single core entity of the entire product. Without the ability to create and view log entries, nothing else works. This replaces both the existing bullet note and task creation flows with one unified, frictionless capture experience.

**Independent Test**: Install the app. Type "Coffee with Anna" into the bottom capture bar. Press submit. Confirm the entry appears in the timeline under "Today". No other features are needed to validate this story.

**Acceptance Scenarios**:

1. **Given** the app is open on the home screen, **When** the user types into the bottom capture bar and presses submit, **Then** a new log entry is created and appears at the top of today's timeline group immediately.
2. **Given** a log entry exists in the timeline, **When** the user scrolls the timeline, **Then** the capture bar remains fixed at the bottom, the timeline scrolls freely above it, and there is no visual overlap.
3. **Given** the capture bar is focused, **When** the user presses submit on an empty input, **Then** nothing is saved and the capture bar remains open.
4. **Given** the user types "Coffee with Anna" into the capture bar, **When** they press submit, **Then** the input clears and focus is retained on the capture bar for follow-up logging.

---

### User Story 2 — View the Infinite Timeline (Priority: P2)

A user can scroll through their complete history of log entries and completion events. Entries are grouped by day with sticky date separators (Today, Yesterday, Mar 12). The timeline shows a subtle left-rail structure for visual rhythm. The home screen is this timeline — not a day-centric view.

**Why this priority**: The timeline is the primary screen. It must exist for all other features to be visible. It replaces the current Day View as the main home screen.

**Independent Test**: With several log entries across multiple days, open the app. Confirm entries appear grouped by date with sticky separators. Scroll past "Today" into "Yesterday" — confirm the sticky header updates. No empty-state logic or suggestions needed to validate this story.

**Acceptance Scenarios**:

1. **Given** log entries exist across multiple days, **When** the user opens the home screen, **Then** entries are displayed in reverse-chronological order grouped by day with sticky date separators.
2. **Given** the user is viewing today's entries, **When** they scroll past the boundary to yesterday, **Then** the sticky separator label changes from "Today" to "Yesterday".
3. **Given** an entry exists from 10 days ago, **When** the user scrolls to that section, **Then** the separator shows a formatted date (e.g., "Mar 3").
4. **Given** the timeline has zero log entries and zero completion events, **When** the user opens the home screen, **Then** a calm empty-state message is shown.

---

### User Story 3 — Link a Person to a Log Entry (Priority: P3)

While typing in the capture bar, the user types "@Anna" and sees a suggestion chip for matching people in their contacts. They tap to link Anna to the entry. If Anna doesn't exist yet, they can create her inline. The log entry is saved with the person link. The link is reflected in Anna's relationship timeline.

**Why this priority**: Person linking is what differentiates Antra from a plain notes app. It connects log entries to the People graph and enables relationship context.

**Independent Test**: With at least one person in the People list, type "@" in the capture bar. Confirm person suggestions appear. Select a person and submit. Confirm the entry appears in the timeline and on the person's detail page. Create a new person inline to verify the creation flow.

**Acceptance Scenarios**:

1. **Given** a person "Anna" exists in the People list, **When** the user types "@Ann" in the capture bar, **Then** a suggestion for "Anna" appears.
2. **Given** the suggestion appears, **When** the user taps "Anna", **Then** the text becomes "@Anna" as a linked token and the entry will be associated with Anna on submit.
3. **Given** no person matches "@Julia", **When** the user types "@Julia", **Then** an option to "Create Julia" appears.
4. **Given** "Create Julia" is tapped, **When** the entry is submitted, **Then** a new person record "Julia" is created and the entry is linked to her.
5. **Given** an entry linked to Anna is submitted, **When** the user views Anna's person detail, **Then** the entry appears in Anna's relationship timeline.

---

### User Story 4 — Attach a Follow-Up to a Log Entry (Priority: P4)

After logging "Coffee with Anna", the user wants to remember to follow up in one month. They attach a follow-up to the existing log entry. On the follow-up date, the item surfaces in the Needs Attention section. The original "Coffee with Anna" entry remains unchanged in the historical timeline.

**Why this priority**: Follow-ups are the replacement for tasks. They provide the forward-looking functionality without introducing task-management complexity.

**Independent Test**: Log "Coffee with Anna". Attach a follow-up date. Advance the date to the follow-up date in test mode. Open the app. Confirm the Needs Attention section shows a suggestion for "Coffee with Anna". Confirm the original log entry still appears in the historical timeline.

**Acceptance Scenarios**:

1. **Given** a log entry exists, **When** the user adds a follow-up date to it, **Then** a follow-up reminder is stored linked to that entry.
2. **Given** a follow-up date is reached, **When** the user opens the app, **Then** a suggestion for that log entry appears in the Needs Attention section.
3. **Given** a follow-up appears in Needs Attention, **When** the user marks it as Done, **Then** a completion event "Followed up with Anna" is inserted into the historical timeline at the current date/time.
4. **Given** a follow-up appears in Needs Attention, **When** the user taps Snooze, **Then** the suggestion is hidden and resurfaced at a later date (3 days default).
5. **Given** a follow-up appears in Needs Attention, **When** the user taps Dismiss, **Then** the suggestion is permanently removed without creating a completion event.
6. **Given** a follow-up is attached to a log entry, **When** the original log entry is viewed in the timeline, **Then** the entry itself is unchanged — only the Needs Attention section reflects the pending follow-up.

---

### User Story 5 — Needs Attention Section (Priority: P5)

At the top of the home screen, a "Needs Attention" section shows all open follow-up suggestions. Each suggestion displays enough context to remind the user why it exists (e.g., "Follow up with Anna — from Coffee with Anna"). The section stays focused and calm — not a stressful task list.

**Why this priority**: The Needs Attention section is the replacement for the task list. It makes pending follow-ups visible without cluttering the historical timeline.

**Independent Test**: Create two log entries with follow-up dates set to today. Open the app. Confirm both appear in the Needs Attention section with their source log entry context. Dismiss one. Confirm only one remains. The timeline below remains unchanged.

**Acceptance Scenarios**:

1. **Given** two pending follow-ups exist, **When** the user opens the home screen, **Then** both appear in the Needs Attention section above the timeline.
2. **Given** a suggestion is shown, **When** the user reads it, **Then** they can see the original log entry text as context (e.g., "From: Coffee with Anna").
3. **Given** zero pending follow-ups exist, **When** the user opens the home screen, **Then** the Needs Attention section is absent — it does not show as an empty card.
4. **Given** a suggestion is dismissed, **When** the user views the Needs Attention section, **Then** the dismissed suggestion no longer appears.
5. **Given** a suggestion is marked Done, **When** the user views the Needs Attention section, **Then** the completed suggestion is removed and the timeline shows a new completion event.

---

### User Story 6 — Person Relationship Timeline (Priority: P6)

When the user taps on a person's name anywhere in the app, they see that person's relationship timeline: a grouped chronological history of all log entries and completion events linked to them. The last interaction date is shown prominently. The view replaces the current flat list person detail.

**Why this priority**: The person detail view is a key navigation destination from both the People tab and tapped person links. It should reflect the new log entry model.

**Independent Test**: Link several log entries to a person across different dates. Open that person's detail view. Confirm entries appear grouped by date in chronological order. Confirm the last interaction date shown is accurate. Mark a follow-up as Done for that person. Confirm the completion event appears in their timeline.

**Acceptance Scenarios**:

1. **Given** a person has three log entries across three different days, **When** the user opens that person's detail view, **Then** entries appear grouped by date, oldest to newest.
2. **Given** a log entry was submitted today for a person, **When** the user views that person's detail, **Then** the last interaction date reflects today.
3. **Given** a follow-up for a person was marked Done, **When** the user views that person's timeline, **Then** the completion event (e.g., "Followed up with Anna") appears at the completion date.
4. **Given** a person has no linked log entries, **When** the user opens their detail view, **Then** an empty-state message is shown.

---

### User Story 7 — Simplified Navigation (Priority: P7)

The app has exactly two primary tabs: Timeline and People. The Day View tab and any task-specific navigation are removed. Tapping Timeline brings the user to the infinite scroll home screen. Tapping People shows the list of contacts. No other primary tabs exist.

**Why this priority**: Simplified navigation reduces cognitive load and makes the product feel focused. This is the lowest priority because it is a structural change that depends on all other user stories being complete.

**Independent Test**: Open the app. Confirm exactly two primary tabs are visible: Timeline and People. Confirm no Day View tab, no task tab, and no other primary navigation exists. Confirm tapping Timeline opens the infinite timeline and tapping People opens the contacts list.

**Acceptance Scenarios**:

1. **Given** the app is installed, **When** the user opens it, **Then** exactly two tabs are visible: Timeline and People.
2. **Given** the user is on the People tab, **When** they tap Timeline, **Then** they see the infinite scroll timeline with the Needs Attention section above it.
3. **Given** the Day View screen previously existed, **When** the user opens the new app version, **Then** no Day View tab or entry point is accessible.

---

### Edge Cases

- What happens when a user submits a log entry while offline? Entry is saved locally and synced when connectivity resumes, following the existing sync architecture.
- What happens when there are 50+ pending suggestions in Needs Attention? The section scrolls horizontally or uses a "show more" affordance — it must not grow into a full vertical task list that dominates the screen.
- What happens when two people share the same name? The person suggestion shows a disambiguating detail (e.g., last seen date or entry snippet).
- What happens when a follow-up date is in the past at the time of creation? The suggestion is immediately visible in Needs Attention when the entry is saved.
- What happens when the user deletes a log entry that has a pending follow-up? The follow-up suggestion is also removed.
- What happens when the capture bar is focused and the user navigates away? The input text is preserved when the user returns to the home screen.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST provide a single fixed capture bar at the bottom of the home screen for logging entries.
- **FR-002**: The system MUST save a log entry immediately on submit with no additional confirmation steps.
- **FR-003**: The system MUST display all log entries and completion events in a single infinite-scroll timeline as the primary home screen.
- **FR-004**: The timeline MUST group entries by day with sticky date separators (Today, Yesterday, or formatted date).
- **FR-005**: The system MUST support inline person linking via `@Name` syntax during entry capture.
- **FR-006**: The system MUST allow attaching a follow-up date to any existing log entry.
- **FR-007**: The system MUST surface pending follow-ups as suggestions in a Needs Attention section above the timeline when their follow-up date is reached.
- **FR-008**: Each suggestion in Needs Attention MUST support three actions: Done, Snooze, and Dismiss.
- **FR-009**: Marking a suggestion as Done MUST create a completion event in the historical timeline at the current timestamp.
- **FR-010**: The Needs Attention section MUST NOT appear when there are zero pending suggestions.
- **FR-011**: Each suggestion MUST display the original log entry text as context.
- **FR-012**: The person detail view MUST display a chronological grouped relationship timeline of log entries and completion events linked to that person.
- **FR-013**: The person detail view MUST show the last interaction date for that person.
- **FR-014**: The app MUST have exactly two primary navigation tabs: Timeline and People.
- **FR-015**: The Day View screen MUST be removed as a primary navigation destination.
- **FR-016**: Open suggestions MUST NOT appear inline in the historical timeline.
- **FR-017**: Deleting a log entry MUST also remove any pending follow-up suggestions linked to it.

### Key Entities

- **LogEntry**: A user-created record of a life event or interaction. Has content text, a creation timestamp, optional links to one or more people, and an optional follow-up date. Permanent in the historical timeline once created.
- **FollowUp**: A scheduled reminder attached to a single LogEntry. Has a due date and a status (pending, done, snoozed, dismissed). When the due date is reached and status is pending, it surfaces as a Suggestion.
- **Suggestion**: A derived view of a pending FollowUp. Displayed in the Needs Attention section. Carries context from the originating LogEntry. Supports Done, Snooze, and Dismiss actions.
- **CompletionEvent**: A timeline entry created when a Suggestion is marked Done. Records the completion timestamp and references the original LogEntry. Appears in both the historical timeline and the linked person's relationship timeline.
- **Person**: An existing entity. Gains a relationship timeline view showing all linked LogEntries and CompletionEvents grouped by date, with a last-interaction-date field.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user can log a new entry in under 5 seconds from app open to saved.
- **SC-002**: The infinite timeline loads and displays the first screen of entries in under 1 second on a mid-range device.
- **SC-003**: Sticky date separators update correctly as the user scrolls at any speed without visual glitching or lag.
- **SC-004**: A follow-up suggestion surfaces in the Needs Attention section on the correct due date without manual refresh.
- **SC-005**: All three suggestion actions (Done, Snooze, Dismiss) complete without errors and update the UI immediately.
- **SC-006**: The person relationship timeline correctly reflects all linked log entries and completion events, with an accurate last-seen date.
- **SC-007**: The app has exactly two primary tabs and no accessible navigation to removed screens (Day View, task-specific flows).

## Assumptions

- The existing `Bullet` entity and related DAOs will be migrated to a new `LogEntry` / `FollowUp` data model. A DB schema migration is expected (schema version bump).
- The `TodayInteraction`, `BulletCaptureBar`, and `TodayInteractionTimeline` widgets from the current Day View will be significantly refactored or replaced, not reused as-is.
- "Snooze" defers a suggestion by a fixed default interval (3 days) without requiring user input for the new date.
- Natural language date parsing for inputs like "follow up next week" is implemented as a best-effort client-side heuristic; no external NLP model is introduced.
- The `@mention` autocomplete pattern from the existing `BulletCaptureBar` is reused as the foundation for person linking.
- Offline-first behavior (save locally, sync later) follows the existing drift + sync architecture and requires no new sync infrastructure.
- The People tab and person list screen are preserved as-is; only the person detail view is redesigned.
