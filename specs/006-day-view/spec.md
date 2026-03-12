# Feature Specification: AI-style Day View with Relationship Briefing and Morphing Cards

**Feature Branch**: `006-day-view`
**Created**: 2026-03-11
**Status**: Draft

---

## Feature Summary

A redesigned primary screen — the Day View — that acts as a calm daily relationship command center. It surfaces the most relevant relationship actions for the day through a structured layout: a personalized briefing, a daily progress goal, expandable suggestion cards, a quick interaction logger, and a today timeline. Users can triage and log their most important relationship actions without leaving the screen.

---

## User Problem

Users who care about maintaining meaningful relationships have no easy way to know, at a glance, who they should be reaching out to today. They either rely on memory, miss important moments (birthdays, follow-ups), or let relationships drift because the friction of logging interactions is too high. A relationship management tool that requires navigation and deliberate effort fails to build a daily habit. Users need a single screen that tells them what matters and lets them act immediately.

---

## Primary User

An individual managing a personal or professional network who wants to maintain warm, consistent relationships with 20–200 people. They open the app daily — ideally in the morning — and want to spend 2–5 minutes identifying who to reach out to and logging recent interactions. They are not looking for a full CRM dashboard; they want a lightweight daily ritual.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 — See Today's Relationship Priorities at a Glance (Priority: P1)

A user opens the app in the morning and within seconds understands who they should reach out to today. The Relationship Briefing at the top of the Day View shows 2–4 personalized suggestions based on birthdays, long gaps in contact, and pending follow-ups.

**Why this priority**: This is the core value proposition of the Day View. Without the briefing, the screen is just a list. This is the moment the app proves its value every single day.

**Independent Test**: Can be fully tested by seeding relationship data (one contact with a birthday tomorrow, one with last contact 30+ days ago, one with a recent meeting) and verifying the briefing renders correctly with accurate, human-readable suggestions.

**Acceptance Scenarios**:

1. **Given** a user has a contact with a birthday tomorrow, **When** they open the Day View, **Then** the briefing mentions that contact's birthday in the 2–4 suggestions shown.
2. **Given** a user has a contact not contacted in 28 days, **When** they open the Day View, **Then** the briefing includes a suggestion to reconnect with that contact.
3. **Given** a user has a contact they met last week with no logged follow-up, **When** they open the Day View, **Then** the briefing includes a follow-up suggestion for that contact.
4. **Given** no meaningful relationship signals exist, **When** the user opens the Day View, **Then** the briefing shows an encouraging neutral message rather than blank content.
5. **Given** more than 4 qualifying signals exist, **When** the briefing is generated, **Then** only 2–4 are shown, prioritized by: birthday first, follow-up second, long contact gap third.

---

### User Story 2 — Triage Suggestion Cards Without Leaving the Screen (Priority: P1)

A user sees a feed of actionable suggestion cards below the daily goal. Each card is initially compact, showing the contact name and the reason for the suggestion. Tapping a card expands it in place to reveal notes, context, and action buttons. The user can act — log a message, mark a meeting, schedule a follow-up — entirely within the Day View.

**Why this priority**: This is the core interaction loop. A Day View that requires navigating away for every card action defeats the "minimal navigation" principle. Morphing cards keep the user in flow.

**Independent Test**: Can be fully tested by rendering a suggestion feed with one card of each type (Reconnect, Birthday, Follow-up, Memory), verifying the collapsed state shows minimal info, the expanded state shows notes and actions, and tapping an action button dismisses or collapses the card with success feedback.

**Acceptance Scenarios**:

1. **Given** the suggestion feed is visible, **When** the user taps a collapsed card, **Then** the card expands in place with an animation revealing notes and action buttons, without navigating away from the Day View.
2. **Given** a card is expanded, **When** the user taps an action button (e.g., "Log meeting"), **Then** the interaction is recorded, a brief success indicator is shown, and the card collapses or is removed from the feed.
3. **Given** a card is expanded, **When** the user taps the card header again or taps outside the card, **Then** the card collapses back to its compact state.
4. **Given** the feed contains multiple cards, **When** the user expands a new card, **Then** any previously expanded card collapses automatically (only one card open at a time).
5. **Given** a Birthday card is expanded, **When** the user views the actions, **Then** the actions include "Send greeting" and "Log call."
6. **Given** a Reconnect card is expanded, **When** the user views the actions, **Then** actions include "Message," "Call," and "Log meeting."
7. **Given** a Follow-up card is expanded, **When** the user views the actions, **Then** actions include "Follow up" (log), "Schedule later," and any relevant notes from the last meeting.

---

### User Story 3 — Log an Interaction in Under 3 Seconds (Priority: P1)

A user wants to quickly record that they had a coffee with someone. They tap the Quick Log Interaction Bar (always visible), select the interaction type (Coffee, Call, Message, Note), select the person, optionally add a short note, and save. The interaction appears in the today timeline immediately.

**Why this priority**: Fast capture is a stated product principle. If logging takes more than 3 seconds, users will skip it and the relationship data becomes stale. This is the primary data-entry path.

**Independent Test**: Can be fully tested by opening the Quick Log bar, selecting "Call," choosing a contact, and saving with no note — measuring steps to completion as 3 taps or fewer (type → person → save).

**Acceptance Scenarios**:

1. **Given** the Day View is open, **When** the user taps an interaction type in the Quick Log bar, **Then** a person-selection UI appears without full-screen navigation.
2. **Given** a type and person are selected, **When** the user taps Save, **Then** the interaction is logged and appears at the top of the today timeline within the same session.
3. **Given** an interaction is logged, **When** the daily goal is not yet complete, **Then** the goal progress increments by 1.
4. **Given** an interaction is logged for a contact who has a suggestion card, **When** the interaction is saved, **Then** that contact's suggestion card is removed from or deprioritized in the feed.
5. **Given** the user types an optional note before saving, **Then** the note is saved with the interaction and is visible in the timeline detail view.

---

### User Story 4 — Track Daily Relationship Goal Progress (Priority: P2)

A user sees a daily goal (e.g., "Reach out to 3 people today") with a progress bar. As they log interactions or complete card actions, the count increments. When the goal is reached, a completion message appears.

**Why this priority**: The daily goal creates a lightweight habit loop. It is motivating but not the primary functionality — the screen functions without it.

**Independent Test**: Can be fully tested by logging 3 interactions and verifying the progress bar updates from 0/3 → 1/3 → 2/3 → 3/3 and the completion state appears.

**Acceptance Scenarios**:

1. **Given** the user has not logged any interactions today, **When** the Day View loads, **Then** the goal shows 0 of 3 progress with an empty progress bar.
2. **Given** the goal target is 3, **When** the user logs 3 interactions, **Then** the progress bar fills completely and a completion message replaces the goal indicator.
3. **Given** the goal is already completed today, **When** the user reopens the app later that day, **Then** the completion state persists.
4. **Given** a suggestion card action that logs an interaction is taken, **Then** it counts toward the daily goal.

---

### User Story 5 — Review Today's Interaction Timeline (Priority: P2)

A user wants to see what relationship actions they have already taken today. The today timeline shows a reverse-chronological list of logged interactions with timestamps. Tapping an entry opens the interaction detail.

**Why this priority**: The timeline gives users confidence that their logging is working and serves as a daily relationship journal. It is secondary to the forward-looking features.

**Independent Test**: Can be fully tested by logging 3 interactions and verifying they appear in the timeline in reverse chronological order with correct contact name, interaction type, and timestamp.

**Acceptance Scenarios**:

1. **Given** 3 interactions have been logged today, **When** the user scrolls to the timeline, **Then** they see 3 entries in reverse chronological order (newest first).
2. **Given** a timeline entry is visible, **When** the user taps it, **Then** an interaction detail view opens showing contact, type, time, and any notes.
3. **Given** no interactions have been logged today, **When** the user views the timeline, **Then** an empty-state message is shown (e.g., "No interactions logged yet today.").

---

### Edge Cases

- When a contact has both a birthday tomorrow AND has not been contacted in 60 days, both signals could appear — the system should show only one card per contact in the suggestion feed.
- On first launch with no contacts or relationship data, the briefing and suggestion feed must show helpful empty states, not blank areas.
- If the user logs an interaction for a contact not in the suggestion feed, the goal still increments.
- If a card is expanded and the user scrolls, the card should remain expanded and scroll with the list.
- If the daily goal target is not yet set (new user), the goal section shows a default target of 3.
- When the user crosses midnight while the app is open, the timeline should refresh to the new day without requiring an app restart.
- If the optional note step in Quick Log is skipped, the interaction saves with no note — the 3-tap minimum path must still work.

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The Day View MUST display a Relationship Briefing section containing 2–4 personalized suggestions generated from local relationship data.
- **FR-002**: Briefing suggestions MUST be prioritized in order: upcoming birthdays first, pending follow-ups second, long contact gaps third.
- **FR-003**: The briefing MUST display a contextual, human-readable sentence per suggestion (e.g., "Anna has a birthday tomorrow," not just "Anna — birthday").
- **FR-004**: When no suggestion signals exist, the briefing MUST show a neutral encouragement message rather than empty or hidden content.
- **FR-005**: The Day View MUST display a Daily Relationship Goal section with a numeric progress count and a visual progress bar.
- **FR-006**: Goal progress MUST increment by 1 each time any interaction is logged from the Day View (Quick Log bar or card action).
- **FR-007**: When the daily goal count equals the target, the goal section MUST display a completion message and the progress indicator MUST stop incrementing.
- **FR-008**: The Day View MUST display a vertically scrollable Suggestion Card feed.
- **FR-009**: Each Suggestion Card MUST have a collapsed state showing: contact name, card type (Reconnect / Birthday / Follow-up / Memory / Recent interaction), and primary signal text.
- **FR-010**: Tapping a collapsed card MUST expand it in place with an animation, revealing additional contact notes and 2–4 contextually appropriate action buttons.
- **FR-011**: Only one Suggestion Card MAY be expanded at a time; expanding a new card MUST automatically collapse any currently expanded card.
- **FR-012**: Completing a card action that logs an interaction MUST show a brief success indicator, then collapse or remove the card.
- **FR-013**: The Suggestion Card feed MUST show at most one card per contact at any time.
- **FR-014**: The Quick Log Interaction Bar MUST be persistently visible on the Day View and MUST support 4 interaction types: Coffee, Call, Message, Note.
- **FR-015**: The Quick Log flow MUST be completable in 3 taps or fewer via the path: select type → select person → save.
- **FR-016**: An optional note field MUST be available in Quick Log without breaking the 3-tap minimum path (i.e., note is skippable).
- **FR-017**: A logged interaction MUST appear at the top of the Today Timeline immediately after saving, within the same screen session.
- **FR-018**: The Today Timeline MUST display entries in reverse chronological order showing: timestamp, contact name, and interaction type.
- **FR-019**: Tapping a timeline entry MUST open an interaction detail view.
- **FR-020**: Logging an interaction for a contact with an active suggestion card MUST remove or deprioritize that card from the feed.
- **FR-021**: The Day View MUST handle empty states for each section individually without showing blank or broken areas.

### Key Entities

- **Suggestion**: A derived action item with a type (Reconnect, Birthday, Follow-up, Memory, Recent Interaction), linked contact, signal data (e.g., last contact date, birthday date, last meeting date), and a priority score. Not persisted — regenerated each session from contact data.
- **Interaction**: A logged event between the user and a contact, with a type (Coffee, Call, Message, Note, Meeting), timestamp, optional note, and linked contact.
- **Daily Goal**: A per-day record tracking the interaction target count and the current count of interactions logged that day.
- **Contact**: An existing entity with at minimum: name, birthday (optional), last contacted date, and relationship notes.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can log an interaction in 3 taps or fewer — verifiable by counting the minimum interaction steps from Quick Log bar to saved confirmation.
- **SC-002**: The Relationship Briefing loads and displays within 1 second of the Day View opening.
- **SC-003**: Suggestion card expand and collapse animations complete in under 300 milliseconds.
- **SC-004**: The Day View answers the three questions — Who to connect with today? What happened today? How close am I to the goal? — without requiring navigation away from the screen.
- **SC-005**: Zero navigations away from the Day View are required to complete a suggestion card action or log an interaction.
- **SC-006**: Users who open the Day View daily log at least 1 interaction per day at a rate of 70% or higher, measured over a 7-day active cohort.

---

## Out of Scope

- AI or large language model-generated briefing text — suggestions are generated from local relationship data rules, not external services.
- Push notifications or scheduled reminders — this spec covers only the in-app Day View screen.
- Configuring the daily goal target — default is 3; changing the target is a separate settings feature.
- Contact creation or editing from within the Day View.
- Multi-day timeline history — the timeline shows today's interactions only.
- Social media, email, or calendar integrations for auto-detecting interactions.
- Native app launching (e.g., opening the Phone or Messages app) — actions log within the app only.

---

## Assumptions

- The app already has a contact/person data model with: name, birthday (optional), last contacted date, and notes.
- The app already has an interaction logging capability; this feature redesigns the entry point, not the underlying data model.
- The daily goal target defaults to 3 interactions per day for all users.
- Taking a card action that logs an interaction counts as a full interaction (contributes to goal, appears in timeline).
- Suggestion cards are generated on-device from existing relationship data — no external service is required.
- Memory cards (e.g., "You met Alex 1 year ago today") are based on the date of the first logged interaction with that contact.
- At most one suggestion card per contact appears in the feed at a time.
- The Quick Log person-selection step shows a searchable list of existing contacts only — no new contact creation.

---

## Open Questions

- Should the daily goal target (default: 3) be configurable per user, and if so, is that a Day View setting or an app-level preference?
- What is the dismissal behavior for suggestion cards the user explicitly skips — do they return the next day or disappear until the signal changes?
- When a card action is taken from the suggestion feed, should a confirmation dialog appear before logging, or should it log immediately with an undo option?
