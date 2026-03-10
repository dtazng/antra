# Feature Specification: Antra Log — Digital Bullet Journal with Personal CRM

**Feature Branch**: `001-antra-log`
**Created**: 2026-03-09
**Status**: Draft
**Input**: User description: "Antra Log - digital bullet journal with personal CRM for daily logging and relationship tracking"

---

## Overview

Antra Log is a calm, private, and intentional digital bullet journal that helps users capture daily thoughts, tasks, and interactions while nurturing meaningful relationships. It combines bullet journaling philosophy with a lightweight personal CRM, enabling users to remember what matters and reflect on their life and connections over time.

The app addresses a gap in the market: no existing tool combines daily life logging with meaningful relationship tracking in a simple, reflective system. It is built for individuals who want a personal life log that is local-first, private, and focused on reflection rather than gamified productivity.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Daily Bullet Capture (Priority: P1)

A user opens the app and lands directly in today's daily log. They can immediately type and capture a bullet — a task, note, or event — with a single tap and minimal friction. They can tag entries, link them to people, and move on with their day in under 10 seconds per entry.

**Why this priority**: This is the core loop of the app. If fast, frictionless capture doesn't work, nothing else matters. All other features build on the existence of captured bullets.

**Independent Test**: Can be fully tested by opening the app and creating bullets of each type (task, note, event) with tags and people links, then verifying they appear in today's log.

**Acceptance Scenarios**:

1. **Given** a user opens the app, **When** the app finishes loading, **Then** today's daily log is displayed and the capture input is visible and ready within 1 second.
2. **Given** a user types a bullet and selects a type (task/note/event), **When** they confirm the entry, **Then** it is saved to today's daily log instantly and appears in the list.
3. **Given** a user creates a bullet, **When** they add a # tag or link a person (@mention), **Then** the tag and person association is saved alongside the bullet.
4. **Given** a task bullet exists, **When** the user marks it complete, cancelled, or migrated, **Then** the bullet updates to reflect the new state without losing original content.
5. **Given** no internet connection is available, **When** a user captures a bullet, **Then** it is saved locally and remains accessible without degradation.

---

### User Story 2 — People Profiles & Relationship Memory (Priority: P2)

A user creates a profile for a person they want to remember (a friend, colleague, mentor). Over time, they link bullets to that person when they have interactions, note context about the relationship, and can quickly recall when they last connected and what was discussed.

**Why this priority**: The personal CRM layer is what differentiates Antra Log from generic journaling apps. It enables intentional relationship nurturing and is explicitly listed as a core V1 feature.

**Independent Test**: Can be fully tested by creating a person profile, linking several bullets to them across different days, and viewing their interaction history timeline.

**Acceptance Scenarios**:

1. **Given** a user wants to add a person, **When** they create a People Profile, **Then** they can save a name and optional context notes about that person.
2. **Given** a bullet is being created, **When** the user links it to a person, **Then** that bullet appears on the person's interaction history timeline.
3. **Given** a user views a People Profile, **When** they view the interaction timeline, **Then** all bullets linked to that person appear in reverse chronological order.
4. **Given** a person profile exists with interactions, **When** the user opens the profile, **Then** they can immediately see the date of the last logged interaction.
5. **Given** a user has enabled check-in reminders for a person, **When** the configured time period passes without a logged interaction, **Then** the user receives a gentle reminder to reconnect.

---

### User Story 3 — Search & Retrieval (Priority: P3)

A user wants to find past entries — by keyword, by person, by tag, or by date range. They can search across their entire log and navigate directly to matching entries.

**Why this priority**: As the log grows over months, retrieval becomes essential for reflection and relationship memory. Without search, the log becomes a write-only archive.

**Independent Test**: Can be fully tested by creating entries with various tags and person links, then searching by keyword, tag, person name, and time range.

**Acceptance Scenarios**:

1. **Given** a user enters a keyword in the search field, **When** results appear, **Then** all bullets containing that keyword are shown, ranked by recency.
2. **Given** a user searches by person name, **When** results appear, **Then** only bullets linked to that person are shown.
3. **Given** a user searches by tag, **When** results appear, **Then** all bullets tagged with that label are shown.
4. **Given** a user applies a date filter, **When** results appear, **Then** only bullets from within that date range are displayed.
5. **Given** the user has many entries, **When** they perform any search, **Then** results appear within 2 seconds.

---

### User Story 4 — Collections & Filtered Views (Priority: P4)

A user creates a Collection — a named, dynamic view that filters bullets by tag, person, or other criteria. This lets them maintain topic-specific journals (e.g., "Work Ideas", "Books", "Gratitude") without abandoning the daily log as their primary capture surface.

**Why this priority**: Collections add organizational power without adding friction to capture. They are powerful enough to differentiate the app but don't block MVP if absent on day one.

**Independent Test**: Can be tested by creating a collection based on a tag filter, adding tagged bullets in the daily log, and verifying they auto-populate in the collection view.

**Acceptance Scenarios**:

1. **Given** a user creates a Collection with a tag filter, **When** a bullet with that tag is added to the daily log, **Then** it automatically appears in that collection.
2. **Given** a user views a Collection, **When** they tap an entry, **Then** they navigate to that entry in context of the day it was created.
3. **Given** a user wants a collection filtered by person, **When** they set the filter to a person's name, **Then** all bullets linked to that person appear in the collection.

---

### User Story 5 — Weekly & Monthly Reviews (Priority: P5)

At the end of a week or month, a user is prompted through a structured reflection ritual. They review open tasks, key events, and relationship interactions from the period. They can migrate tasks forward, add summary notes, and complete the review.

**Why this priority**: Reviews are the reflective backbone of bullet journaling. They build habit and long-term value. As a Pro-tier feature, they come after core capture and CRM are solid.

**Independent Test**: Can be tested by completing a full week of entries then initiating a weekly review, verifying that open tasks and events are surfaced with migration options.

**Acceptance Scenarios**:

1. **Given** a week has passed, **When** the user initiates a weekly review, **Then** all open tasks, events, and notes from that week are surfaced with prompts for each.
2. **Given** a user is reviewing open tasks, **When** they mark a task for migration, **Then** a new bullet is created in the current day's log with a migration marker.
3. **Given** a user completes a weekly review, **When** they finish, **Then** the week is marked as reviewed and a summary note is saved.
4. **Given** a month has passed, **When** the user initiates a monthly reflection, **Then** key themes, top interactions, and unresolved tasks are surfaced in a summary format.

---

### Edge Cases

- What happens when a user creates a bullet with no type selected? Default to "note" type.
- What happens when a person is deleted who has bullets linked to them? Bullets are retained; the person link is cleared with a note that the person was removed.
- What happens when two devices sync and the same bullet was edited on both? Last-write-wins with a local conflict copy preserved for the user to review.
- What happens when a search query returns no results? Empty state is shown with suggestions to broaden the filter or check spelling.
- What happens when a check-in reminder fires but the user has already logged an interaction that day? The reminder is suppressed for that day.
- What happens when the app is opened for the first time with no prior entries? An empty daily log is shown with a brief onboarding prompt to capture the first bullet.

---

## Requirements *(mandatory)*

### Functional Requirements

**Daily Log**

- **FR-001**: The app MUST open directly to today's daily log as the primary landing screen.
- **FR-002**: Users MUST be able to create a bullet with a type of task, note, or event.
- **FR-003**: Users MUST be able to add one or more tags to any bullet using a consistent tagging convention (e.g., #tag).
- **FR-004**: Users MUST be able to link a bullet to one or more People Profiles at time of creation or via edit.
- **FR-005**: Users MUST be able to edit any existing bullet.
- **FR-006**: Users MUST be able to mark a task bullet as complete, cancelled, or migrated.
- **FR-007**: The app MUST persist all bullet data locally so that it is fully accessible without an internet connection.
- **FR-008**: The daily log MUST display bullets in the order they were created within the current day.
- **FR-009**: Users MUST be able to navigate to any previous day's log.

**People Profiles & Relationship Memory**

- **FR-010**: Users MUST be able to create a People Profile with a name and optional context notes.
- **FR-011**: Users MUST be able to edit or delete any People Profile.
- **FR-012**: Each People Profile MUST display an interaction history timeline showing all bullets linked to that person in reverse chronological order.
- **FR-013**: Each People Profile MUST display the date of the most recent logged interaction.
- **FR-014**: Users MUST be able to set an optional check-in reminder cadence per person (e.g., every 2 weeks, every month).
- **FR-015**: When a check-in reminder fires, the app MUST deliver a gentle notification identifying the person and the time since last interaction.

**Collections**

- **FR-016**: Users MUST be able to create named Collections.
- **FR-017**: Collections MUST support filtering by tag, person, bullet type, or a combination of these criteria.
- **FR-018**: Collections MUST dynamically update to include any bullets that match the filter criteria.
- **FR-019**: Users MUST be able to navigate from a Collection entry to the original daily log entry.

**Reviews (Pro Tier)**

- **FR-020**: The app MUST surface a weekly review prompt at the end of each week, listing open tasks, events, and interactions from that period.
- **FR-021**: Users MUST be able to migrate open tasks from a review into the current day's log.
- **FR-022**: The app MUST surface a monthly reflection summary highlighting key themes, top interactions, and unresolved tasks.
- **FR-023**: Completed reviews MUST be saved as summary entries accessible from the relevant time period.

**Search**

- **FR-024**: Users MUST be able to perform full-text search across all bullets.
- **FR-025**: Search MUST support filtering by person, tag, and date range.
- **FR-026**: Search results MUST appear within 2 seconds for a personal log of up to 10,000 entries.

**Sync**

- **FR-027**: The local database MUST be the source of truth; all writes occur locally first before any sync attempt.
- **FR-028**: The app MUST support background sync across devices when an internet connection is available.
- **FR-029**: Sync conflicts MUST be resolved without silent data loss; a local conflict copy MUST be preserved when the same item is edited on two devices simultaneously.

**Privacy & Security**

- **FR-030**: All user data MUST be encrypted at rest on-device.
- **FR-031**: End-to-end encryption for sync MUST be available as a Pro-tier option, ensuring sync data cannot be read server-side.

### Key Entities

- **Bullet**: The atomic unit of the log. Has a type (task, note, event), content text, creation timestamp, day reference, tags, linked people, and a status (for tasks: open/complete/cancelled/migrated).
- **Day Log**: A container for all bullets created on a specific calendar date. Belongs to the user's journal.
- **Person**: A profile entry representing a relationship. Has a name, context notes, creation date, and an optional check-in reminder cadence. Related to bullets via a many-to-many link.
- **Tag**: A label attached to bullets for thematic organization. Defined implicitly when first used in a bullet.
- **Collection**: A named, saved filter view. Has a name, description, and one or more filter rules (by tag, person, bullet type, or date range).
- **Review**: A structured reflection record tied to a time period (week or month). Contains summary notes, migrated task references, and a completion status.
- **Sync Record**: Metadata tracking the sync state, device identity, timestamp, and conflict status for a given data entity.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can open the app and capture their first bullet within 5 seconds of launch.
- **SC-002**: Each bullet capture (type and save) completes in under 10 seconds for standard use.
- **SC-003**: 80% of active users log at least one bullet per day during their first 30 days of use.
- **SC-004**: Weekly review completion rate reaches 50% among users active for more than 2 weeks.
- **SC-005**: 60% of users with 30 or more days of data have created at least one People Profile with a linked interaction.
- **SC-006**: Search returns results in under 2 seconds for a personal log of up to 10,000 entries.
- **SC-007**: Users retain full access to all previously captured data when offline, with zero data loss.
- **SC-008**: 30-day retention rate reaches 40% or above among users who complete their first week of logging.
- **SC-009**: Sync conflicts result in zero silent data loss; all conflicts produce a recoverable local copy.
- **SC-010**: Pro tier conversion reaches 8% of active users within 90 days of general availability.

---

## Assumptions

- The primary platform for V1 is iOS (iPhone). iPad and Android are Phase 2.
- Users can use the app locally without creating an account; account creation is required only to enable sync.
- The default bullet type when none is explicitly selected is "note."
- Tags are user-defined and created implicitly on first use; there is no predefined tag taxonomy.
- The check-in reminder system uses the device's native notification layer; no server-side push infrastructure is required for V1 reminders.
- The weekly review prompt appears at the end of the user's configured week-end day (defaulting to Sunday) as a passive prompt, not a blocking flow.
- Sync uses a cloud service; the exact sync backend is deferred to the planning phase.
- End-to-end encryption for sync is a Pro-tier feature that encrypts data on-device before transmission so the sync server stores only ciphertext.
- Narrative exports (Pro) produce a human-readable document (e.g., plain text or markdown) from a selected date range of the user's log.
- The app is designed for single-user personal use only; data is not shared between users.

---

## Out of Scope (V1)

- Team collaboration or shared journals
- Social sharing or public profiles
- Complex project management (task dependencies, subtasks, Gantt views)
- Heavy analytics dashboards or productivity scoring
- Android, iPad, or web companion (Phase 2+)
- AI-assisted reflection summaries (future opportunity)
- Voice journaling (future opportunity)
- Calendar integration (future opportunity)
- Life timeline visualization (future opportunity)
- Relationship health scoring or AI-generated insights (future opportunity)
