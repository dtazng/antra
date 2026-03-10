# Feature Specification: Personal CRM

**Feature Branch**: `003-personal-crm`
**Created**: 2026-03-10
**Status**: Draft

## Overview

Help Antra users track meaningful relationships by linking every log entry to a person. Each person has a dedicated profile with a full interaction timeline. The experience must feel like a lightweight personal journal — not a sales CRM — and fit naturally into the existing daily-log capture workflow.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Create a Person and Link a Log Entry (Priority: P1)

A user captures a note or event that relates to a person. They either type the person's name using `@mention` syntax in the capture bar, or manually attach a person from within the log detail view. If the person doesn't exist yet, they can create one in a fast, one-step flow (name only required). Once linked, the log appears in the person's timeline.

**Why this priority**: Core of the feature. Every downstream story depends on people and links existing. Without people and linking, the CRM has no data.

**Independent Test**: Create a person "Alice Ng", capture a note "Met with @Alice to discuss the proposal", and confirm the note appears in Alice's interaction timeline on her profile page.

**Acceptance Scenarios**:

1. **Given** no people exist, **When** a user types `@Alice` in the capture bar, **Then** the system suggests creating a new person named "Alice" and adds her to the people list upon confirmation.
2. **Given** "Alice Ng" exists, **When** a user creates a note containing "@Alice", **Then** the note is auto-linked to Alice and appears in her interaction timeline.
3. **Given** two people named "Alex" exist, **When** a user types "@Alex", **Then** the system shows a disambiguation picker rather than silently choosing one.
4. **Given** a log has been created without a person link, **When** the user opens the log detail and taps "Link person", **Then** they can search for and attach an existing person or create a new one.
5. **Given** a log is linked to a person, **When** the user views the log detail, **Then** the linked person is shown visibly with an option to remove or change the link.

---

### User Story 2 — View a Person's Full Interaction History (Priority: P2)

A user opens a person's profile and sees a reverse-chronological timeline of every log entry ever linked to them — notes, events, tasks, and follow-ups — with the most recent interaction at the top. The profile also shows key contact details, tags, relationship type, and a notes/about section.

**Why this priority**: The person detail page is the primary value of the Personal CRM. Without it, linking entries serves no purpose.

**Independent Test**: Link 5 log entries (spanning different days and types) to one person, open their profile, and verify all 5 entries appear in reverse chronological order with correct type labels and dates.

**Acceptance Scenarios**:

1. **Given** a person has 10 linked logs, **When** the user opens the person's profile, **Then** all 10 logs appear sorted most-recent-first, each showing date, type icon, and content preview.
2. **Given** a log in the person's timeline is tapped, **When** navigation completes, **Then** the original log detail view opens (task, note, or event detail as appropriate).
3. **Given** a person has no linked logs, **When** the user opens their profile, **Then** a clear empty state is shown with a prompt to add a first interaction.
4. **Given** a log is unlinked from a person, **When** the user views the person's timeline, **Then** the unlinked log no longer appears.
5. **Given** a person has a company, tags, and relationship type set, **When** the user opens their profile, **Then** all metadata fields are shown clearly in a header/about section above the timeline.

---

### User Story 3 — Browse and Search the People List (Priority: P2)

A user opens the People screen and can search by name, sort by last interaction date or name, and filter by relationship type or tags. Each row shows the person's name, role/company, and when they were last contacted.

**Why this priority**: Without a usable list, discovering and navigating to a person is impossible as the contact list grows.

**Independent Test**: Add 10 people with varied names and companies. Use the search field to filter by partial name, sort by "last interaction", and confirm the list reorders correctly.

**Acceptance Scenarios**:

1. **Given** 20 people exist, **When** the user types "sa" in the search field, **Then** only people whose name or company contains "sa" (case-insensitive) are shown.
2. **Given** people with varying last-interaction dates, **When** "Sort by last interaction" is selected, **Then** the most recently contacted person appears first.
3. **Given** people tagged with "work" and "family", **When** the user filters by "work", **Then** only people with the "work" tag are shown.
4. **Given** no people exist, **When** the user views the People screen, **Then** an empty state with a prompt to add the first person is shown.
5. **Given** the user selects "filter: needs follow-up", **When** the list renders, **Then** only people flagged for follow-up are displayed.

---

### User Story 4 — Create and Edit a Person Profile (Priority: P2)

A user can create a person with just a name, then optionally fill in contact details, tags, relationship type, and a freeform notes/about section. All fields can be edited later from the person's profile.

**Why this priority**: Rich profile data enables meaningful search, filtering, and relationship context — but must never block fast capture.

**Independent Test**: Create a person with only a name. Then edit the profile to add a company, tag, and relationship type. Verify all fields save correctly and reflect on the profile and people list row.

**Acceptance Scenarios**:

1. **Given** the "New Person" form is open, **When** the user enters only a name and saves, **Then** the person is created successfully without requiring any other fields.
2. **Given** a person named "Alex" already exists, **When** the user tries to create another person named "Alex", **Then** the system shows a warning and displays the existing record before allowing the user to proceed.
3. **Given** a person profile is open, **When** the user edits any field and saves, **Then** the change is reflected immediately on the profile and in the people list row.
4. **Given** a user opens a person profile, **When** they tap the notes/about field, **Then** they can edit freeform text about this person (separate from linked log entries).

---

### User Story 5 — Follow-up Reminders and Stale Relationship Surfacing (Priority: P3)

A user can mark a person as "needs follow-up" or set a specific follow-up date. The app surfaces people who haven't been contacted recently or who have a pending follow-up, helping the user stay intentional about maintaining relationships.

**Why this priority**: Follow-up is the feature that makes the CRM proactive rather than purely archival. It surfaces value passively.

**Independent Test**: Mark a person as "needs follow-up". Navigate to the People list and confirm that person is highlighted or surfaced with a visual indicator.

**Acceptance Scenarios**:

1. **Given** a person's profile is open, **When** the user taps "Mark as needs follow-up", **Then** the person is flagged and shown with a visual indicator in the people list.
2. **Given** a person has not been linked to any log in over 30 days, **When** the user views the people list, **Then** that person's row shows a stale indicator (e.g., "Last contact 45 days ago").
3. **Given** a person is marked "needs follow-up", **When** a new log is linked to them, **Then** the needs-follow-up flag is automatically cleared.
4. **Given** a follow-up date is set for a person, **When** that date passes, **Then** the person is surfaced with an overdue indicator in the people list.

---

### Edge Cases

- What happens when a log mentions two different people (e.g., "Met with Alice and Bob")? In v1, the user can link one primary person; multi-person linking is schema-ready but not exposed in the UI.
- What happens when the user deletes a log that is linked to a person? The log disappears from the person's timeline; the person record and all other links are unaffected.
- What happens when a person is deleted? All `PersonLogLink` records for that person are removed; the original log entries remain intact and unmodified.
- What happens when two people have nearly identical names (e.g., "Alex Chen" and "Alex Chan")? Both are shown as candidates during duplicate detection; the user decides whether to proceed.
- What happens when the user links a log to the wrong person and wants to fix it? From the log detail, the user removes the current link and reattaches to the correct person.
- What happens when a log is edited to no longer mention a person's name? Existing links are preserved unless the user explicitly removes them — links are intentional, not auto-removed on edit.
- What happens if a person has zero linked logs but has a follow-up date set? The follow-up indicator still surfaces correctly on the people list.

---

## Requirements *(mandatory)*

### Functional Requirements

#### Person Management

- **FR-001**: Users MUST be able to create a person record with name as the only required field.
- **FR-002**: Users MUST be able to edit all person fields (name, company, role, email, phone, birthday, location, tags, relationship type, notes) from the person profile.
- **FR-003**: The system MUST warn users when creating a person whose name exactly matches or closely resembles an existing person's name (case-insensitive).
- **FR-004**: Users MUST be able to delete a person; all associated log links MUST be removed, but the linked log entries themselves MUST remain intact.
- **FR-005**: Users MUST be able to tag people with free-form labels (e.g., "work", "family", "mentor").
- **FR-006**: Users MUST be able to assign a relationship type to a person from a defined set (Friend, Family, Colleague, Mentor, Acquaintance, Other).

#### Log Linking

- **FR-007**: When a user types `@name` in the capture bar, the system MUST suggest matching people from the existing people list in real time.
- **FR-008**: If exactly one confident name match is found, the system MUST auto-link that person to the log upon save and record the link type as "mention".
- **FR-009**: If multiple name matches exist, the system MUST show a disambiguation picker before linking.
- **FR-010**: If no match exists, the system MUST offer the user the option to create a new person, select an existing person, or continue without linking.
- **FR-011**: From the log detail view, users MUST be able to manually attach, change, or remove a person link at any time after creation.
- **FR-012**: Linked people MUST be visibly displayed on the log detail view (note, task, and event detail screens).
- **FR-013**: Unlinking a log from a person MUST remove it from the person's interaction timeline immediately.
- **FR-014**: `lastInteractionAt` on a person record MUST update automatically whenever a log is linked to them.

#### Person Detail View

- **FR-015**: The person profile MUST display: full name, company, role, email, phone, birthday, location, relationship type, tags, and freeform notes.
- **FR-016**: The person profile MUST show all linked logs in reverse-chronological order.
- **FR-017**: Each log entry in the person's timeline MUST show: date, type (note/task/event), content preview (truncated at 2 lines), and task status if relevant.
- **FR-018**: Tapping a log entry in the person's timeline MUST navigate to that log's full detail view.
- **FR-019**: The person profile MUST display the derived `lastInteractionAt` date.

#### People List

- **FR-020**: The people list MUST support real-time text search by name and company.
- **FR-021**: The people list MUST support sorting by: last interaction (default), name A–Z, recently created.
- **FR-022**: The people list MUST support filtering by: tags, relationship type, and "needs follow-up" status.
- **FR-023**: Each row in the people list MUST display: name, company/role subtitle, last interaction date, and follow-up indicator if applicable.

#### Follow-up

- **FR-024**: Users MUST be able to mark a person as "needs follow-up" from the person profile or people list.
- **FR-025**: Users MUST be able to set a specific follow-up date for a person.
- **FR-026**: When a new log is linked to a person marked "needs follow-up", the system MUST automatically clear that flag.
- **FR-027**: The people list MUST surface a stale-relationship indicator for people not linked to any log in more than 30 days.

#### Duplicate Prevention

- **FR-028**: Before finalizing creation of a new person, the system MUST perform a case-insensitive name-similarity check and display any matches found.
- **FR-029**: The user MUST be able to override a duplicate warning and proceed with creation if the names represent different people.

---

### Key Entities

- **Person**: A tracked individual. Key attributes: id, fullName, firstName, lastName, nickname, company, role, email, phone, birthday, location, tags (comma-separated or array), notes (freeform), relationshipType, needsFollowUp (boolean), followUpDate, lastInteractionAt (derived), createdAt, updatedAt, isDeleted.

- **PersonLogLink**: A join record connecting a log entry (bulletId) to a person. Attributes: id, personId, bulletId, linkType (mention | manual), createdAt. Designed to support multiple persons per log in future versions.

- **Bullet (existing, extended)**: The existing log entry. No schema change required — linked via PersonLogLink. The existing `BulletPersonLinks` table may be extended or replaced by PersonLogLink depending on migration strategy.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can capture a log entry and link it to a person using `@mention` in under 15 seconds from the capture bar.
- **SC-002**: A person's full interaction timeline loads and renders within 1 second for up to 200 linked log entries.
- **SC-003**: 95% of `@mention` lookups resolve to the correct person on the first autocomplete suggestion shown, for users with up to 100 people.
- **SC-004**: Duplicate person creation is flagged in 100% of exact-name-match cases before the record is saved.
- **SC-005**: Users can locate any person by partial name search within 2 seconds of typing, for a list of up to 500 people.
- **SC-006**: Stale relationships (no linked log in 30+ days) are surfaced automatically in the people list without any manual curation by the user.
- **SC-007**: The people list renders without perceptible lag for up to 500 person records.

---

## Assumptions

- The existing `@mention` capture flow and `BulletPersonLinks` table already present in the app are the foundation for this feature and will be extended rather than replaced.
- `lastInteractionAt` is derived from the most recently created `PersonLogLink` for a person and cached on the Person record for query performance.
- Follow-up date surfacing is in-app only (no push notifications) in v1; push notification support is a v2 enhancement.
- "Stale" threshold defaults to 30 days and is not user-configurable in v1.
- Multi-person linking per log (e.g., a note about two people simultaneously) is schema-ready in v1 but the capture UI only exposes linking to one person at a time.
- Relationship type is a fixed set in v1: Friend, Family, Colleague, Mentor, Acquaintance, Other.
- Deletion is always a soft-delete (`isDeleted` flag), consistent with existing log behavior in Antra.

---

## Out of Scope (v1)

- Push / local notification reminders for follow-up dates
- Merge UI for duplicate people (schema and service layer are merge-ready; UI deferred to v2)
- Multi-person simultaneous linking from the capture bar
- Import from device contacts or third-party address books
- People analytics or relationship strength scoring
- Shared / collaborative people lists beyond existing cloud sync
