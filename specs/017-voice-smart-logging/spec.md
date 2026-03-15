# Feature Specification: Person Special Dates, Compact UI, Voice Logging, and Intelligent Logging UX

**Feature Branch**: `017-voice-smart-logging`
**Created**: 2026-03-15
**Status**: Draft

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Person Important Dates (Priority: P1)

A user wants to record a contact's birthday and anniversary so they receive timely reminders and never miss an important moment. They open a person's detail page, add a birthday with a "2 weeks before" reminder, add an anniversary with an "on the day" reminder, and see both listed compactly under an "Important Dates" section. When the reminder threshold is reached, a card appears in Needs Attention: "Anna's birthday in 2 weeks — maybe send her a message."

**Why this priority**: Structured important dates are the highest-value missing feature for a personal CRM. Without them, users must remember dates externally. This delivers immediate, tangible relationship management value independently of all other stories.

**Independent Test**: Can be fully tested by adding a birthday to an existing person and verifying the date appears in the person detail view with the correct reminder label, and a suggestion card surfaces in Needs Attention at the configured threshold.

**Acceptance Scenarios**:

1. **Given** a person with no important dates, **When** the user taps "+ Add date" and enters "Birthday", date May 12, reminder "2 weeks before", **Then** the date appears first in Important Dates as "🎂 Birthday — May 12" with "Reminder: 2 weeks before".
2. **Given** a person with a birthday already added, **When** the user adds an anniversary with reminder "On the day", **Then** it appears below the birthday in a compact row.
3. **Given** an important date with "2 weeks before" reminder and today is 14 days before the date, **When** the user opens the day view, **Then** a Needs Attention card reads "[Name]'s birthday in 2 weeks".
4. **Given** a Needs Attention card for an important date, **When** the user taps "Log interaction", **Then** the logging bar opens with the person pre-linked.
5. **Given** a Needs Attention card, **When** the user taps "Done", **Then** the card dismisses for this year's occurrence only and will reappear next year.
6. **Given** an important date row, **When** the user swipes left, **Then** a delete confirmation appears; on confirm the date is removed.
7. **Given** an important date row, **When** the user taps it, **Then** the add/edit sheet opens pre-filled with existing values.

---

### User Story 2 — Voice Logging (Priority: P2)

A user is on the go and wants to capture a note in under 2 seconds without typing. They tap the microphone button in the logging bar, speak their note, and the audio is recorded. After stopping, the audio is transcribed and automatically saved as a log entry with transcript text, audio duration, and a small voice badge. The log appears immediately in the timeline. If offline, the recording is saved locally and transcription completes when connectivity is restored.

**Why this priority**: Voice logging is the fastest input method and directly serves the core product principle. It is fully independent of smart detection and important dates features.

**Independent Test**: Can be tested by recording a voice note and confirming a log entry appears in the timeline with transcript text and an audio indicator badge.

**Acceptance Scenarios**:

1. **Given** the logging bar is open, **When** the user taps the microphone, **Then** recording starts with a visible indicator and elapsed time counter.
2. **Given** recording is active in tap mode, **When** the user taps the microphone again, **Then** recording stops and transcription begins.
3. **Given** the microphone button is pressed and held, **When** the user holds it, **Then** recording starts; **When** released, **Then** recording stops.
4. **Given** recording is active, **When** the user taps Cancel, **Then** the recording is discarded and no log entry is created.
5. **Given** recording has stopped, **When** transcription completes, **Then** a log entry is created with transcript as body text and "Voice note • [N] sec" label.
6. **Given** transcription fails, **When** the log is saved, **Then** the audio is preserved and the log shows "Transcription failed — tap to retry".
7. **Given** the device is offline when recording ends, **When** connectivity is restored, **Then** transcription completes and the log updates. The audio is never lost.
8. **Given** a voice log in the timeline, **When** the user opens the detail view, **Then** both the transcript and an audio player are visible.

---

### User Story 3 — Smart Person Detection (Priority: P3)

After saving a log entry — typed or voice — the system detects names matching existing contacts and surfaces tappable suggestion chips inline: "Link persons? Anna · Ben". The user taps a chip to link that person in one tap. Ignoring the suggestion has no side effects.

**Why this priority**: Person detection eliminates the most common friction in logging: remembering to manually link contacts. It is additive and non-intrusive.

**Independent Test**: Can be tested by creating a log containing the exact name of an existing person, verifying a link suggestion chip appears, accepting it, and confirming the person appears linked to the log.

**Acceptance Scenarios**:

1. **Given** a saved log containing "Met Anna" and "Anna" is an existing person, **When** the log is created, **Then** a "Link persons? Anna" suggestion appears near the entry.
2. **Given** a suggestion chip, **When** the user taps it, **Then** the person is linked to the log and the chip disappears.
3. **Given** a suggestion the user ignores, **When** they scroll past, **Then** no link is created and no error occurs.
4. **Given** a log containing no names matching existing persons, **When** saved, **Then** no suggestion appears.
5. **Given** a log containing two matching names, **When** saved, **Then** both appear as separate tappable chips.

---

### User Story 4 — Compact Card Layout and Swipe Gestures (Priority: P4)

The user opens the day view and sees noticeably more entries on screen. Cards feel denser, closer to a messaging app. Swiping right reveals quick actions (Add follow-up, Edit, Link person). Swiping left reveals delete. No action buttons are visible at rest.

**Why this priority**: Compact layout improves the core timeline experience on every session. Gesture actions reduce visual clutter while keeping power actions accessible.

**Independent Test**: Can be tested by creating several log entries and confirming more fit on screen than before, and swipe-right exposes quick actions while swipe-left exposes delete.

**Acceptance Scenarios**:

1. **Given** timeline cards at rest, **When** the user views them, **Then** no action buttons are visible inside the cards.
2. **Given** a log card, **When** the user swipes right, **Then** quick action buttons appear: Add follow-up, Edit, Link person.
3. **Given** a log card, **When** the user swipes left, **Then** a delete affordance appears.
4. **Given** the compact layout, **When** compared to the previous design, **Then** at least 20% more entries are visible per screen.

---

### User Story 5 — Smart Follow-Up Prompts (Priority: P5)

The Needs Attention section surfaces cards based on interaction gaps: "You haven't talked to Anna in 3 months" or "You met Ben last week — follow up?" Each card offers Log interaction, Snooze, and Dismiss. Dismissing suppresses the card for 30 days.

**Why this priority**: Proactive prompts turn the app from a journal into an active relationship assistant without requiring manual effort from the user.

**Independent Test**: Can be tested by having a person with no logged interaction for 90+ days and verifying a "Haven't talked to X" card surfaces in Needs Attention.

**Acceptance Scenarios**:

1. **Given** a person with no logged interaction in 90+ days, **When** the user opens the day view, **Then** a card reads "You haven't talked to [Name] in [N] months."
2. **Given** a person with an interaction logged 7 days ago, **When** the user opens the day view, **Then** a follow-up prompt may appear.
3. **Given** a smart prompt card, **When** the user taps "Log interaction", **Then** the logging bar opens with the person pre-linked.
4. **Given** a smart prompt card, **When** the user taps "Snooze", **Then** a picker offers tomorrow, 3 days, next week.
5. **Given** a smart prompt card, **When** the user taps "Dismiss", **Then** the card is removed and does not reappear for 30 days.

---

### Edge Cases

- What happens if voice recording is interrupted by a phone call? Audio captured so far is preserved; transcription proceeds on available audio with an "interrupted" label.
- What happens if two contacts share the same first name? Smart detection suggests both with full names as disambiguation chips — e.g., "Anna Chen" and "Anna Lee".
- What happens if the birthday year is unknown? Year is optional; reminder recurs annually based on month and day only.
- What happens if a reminder date has already passed this year? The reminder skips to the following year's occurrence.
- What happens if transcription fails after 3 retries? The log is marked "Audio only — transcription unavailable" and no further automatic retries occur.
- What happens if person detection suggests the wrong person? The user ignores the chip — no side effects.
- What happens if the logging bar is dismissed mid-recording? The recording is cancelled and discarded; no partial log is created.

## Requirements *(mandatory)*

### Functional Requirements

#### Important Dates

- **FR-001**: A person MUST support zero or more important dates, each with a label, date (month and day required, year optional), optional note, and optional reminder rule.
- **FR-002**: Birthday MUST be treated as a special important date that appears first in the list with a distinct visual treatment.
- **FR-003**: The reminder rule MUST support these presets: No reminder, On the day, 1 day before, 3 days before, 1 week before, 2 weeks before, 1 month before, Custom.
- **FR-004**: Custom reminder MUST allow: direction (before/after), value (integer), unit (days or weeks), recurrence (yearly or once). Recurrence options MUST NOT be shown until Custom is selected.
- **FR-005**: Yearly reminder rules MUST generate a new Needs Attention card each year automatically.
- **FR-006**: Important date reminder cards MUST offer: Log interaction (opens logging bar with person pre-linked), Snooze (tomorrow / 3 days / next week), Done (dismisses current occurrence only).
- **FR-007**: Important dates MUST be editable via tap and deletable via swipe-left with a confirmation step.
- **FR-008**: The add/edit important date flow MUST be a modal sheet with fields: Label, Date, Reminder, Optional note.

#### Voice Logging

- **FR-009**: The logging bar MUST include a microphone button supporting both tap-to-toggle and press-and-hold recording modes.
- **FR-010**: While recording, the UI MUST show a recording indicator and elapsed time. A cancel control MUST always be visible.
- **FR-011**: After recording stops, the system MUST automatically transcribe and create a log entry without requiring user review.
- **FR-012**: A voice log MUST store: transcript text, audio file reference, audio duration in seconds, and transcription status (recording / transcribing / complete / failed).
- **FR-013**: Voice logs in the timeline MUST display a "Voice note • [N] sec" label and a distinct audio badge icon.
- **FR-014**: The voice log detail view MUST display the transcript and an inline audio player.
- **FR-015**: If transcription fails, the audio MUST be preserved and the log MUST show a manual retry option.
- **FR-016**: Voice recording MUST work offline. Audio is saved locally, transcription is queued, and no recording may be lost.

#### Smart Person Detection

- **FR-017**: When a log is saved, the system MUST attempt to match words in the log text against the user's existing person names.
- **FR-018**: Matched names MUST be presented as tappable suggestion chips near the log entry.
- **FR-019**: Tapping a chip MUST link the person to the log immediately with no confirmation step.
- **FR-020**: Person detection suggestions MUST be entirely optional — ignoring them MUST produce no side effects.

#### Compact Card Layout

- **FR-021**: Timeline log cards MUST use vertical padding of 10–12px and horizontal padding of 14–16px.
- **FR-022**: Cards MUST follow the structure: body text, then a compact metadata row (linked persons + timestamp).
- **FR-023**: No action buttons MUST be visible inside cards at rest.

#### Timeline Gesture UX

- **FR-024**: Swiping right on a card MUST reveal quick actions: Add follow-up, Edit, Link person.
- **FR-025**: Swiping left on a card MUST reveal a delete affordance.

#### Smart Follow-Up Prompts

- **FR-026**: The system MUST generate a Needs Attention card for any person with no logged interaction in 90 or more days.
- **FR-027**: The system MUST generate a follow-up prompt 7 days after a logged interaction with a person.
- **FR-028**: Smart prompt cards MUST offer: Log interaction, Snooze (tomorrow / 3 days / next week), Dismiss (suppresses for 30 days).

#### Person Detail Layout

- **FR-029**: The person detail view MUST display sections in order: person header, last interaction, important dates, notes, recent interactions (max 10), "View full history" button.
- **FR-030**: "View full history" MUST navigate to a full paginated list of all interactions for that person.

#### Logging Bar Design

- **FR-031**: The logging bar MUST display only the text input field by default (second row hidden).
- **FR-032**: The second row — Link person, Follow up, Voice log — MUST appear only after the user taps the text input.
- **FR-033**: A Done button MUST be visible on the right when the logging bar is active.

### Key Entities

- **ImportantDate**: Belongs to a person. Attributes: label, date (month + day, year optional), reminder rule, optional note, created/updated timestamps. Birthday is a special-case type.
- **ReminderRule**: Defines when a reminder fires. Attributes: direction (before/after), value (integer), unit (days/weeks), recurrence (yearly/once).
- **VoiceLog**: Extension of a log entry. Additional attributes: audio file reference, audio duration (seconds), transcript text, transcription status (recording/transcribing/complete/failed).
- **PersonDetectionSuggestion**: Transient — a suggested person link derived from log text analysis. Not persisted if ignored.
- **SmartPrompt**: A generated Needs Attention item. Attributes: type (inactivity/follow-up/important-date), person reference, trigger date, snooze-until date, dismissed-at date.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can add a birthday to a contact in under 5 seconds from the person detail view.
- **SC-002**: A typed log entry can be created in under 3 seconds from tapping the input to the entry appearing in the timeline.
- **SC-003**: A voice log recording can be started in under 2 seconds from the logging bar being open.
- **SC-004**: After recording ends, a log entry appears in the timeline within 1 second (transcription may still be in progress).
- **SC-005**: At least 20% more timeline entries are visible per screen compared to the layout before this change.
- **SC-006**: Person detection correctly suggests the right contact for at least 90% of log entries containing an exact name match.
- **SC-007**: Important date reminders surface in Needs Attention within 24 hours of crossing the configured threshold.
- **SC-008**: 100% of completed voice recordings are recoverable after app restart, regardless of transcription status.
- **SC-009**: Smart inactivity prompts appear for all persons with 90+ days of no interaction, with no duplicate cards per person within a 30-day window.

## Assumptions

- Transcription is performed by an external speech-to-text service. On-device transcription is out of scope for this release.
- Person detection uses exact and near-exact name matching against the user's existing contact list. AI inference for unknown names is out of scope.
- Smart follow-up thresholds (90-day inactivity, 7-day post-interaction) are fixed values in this release; user-configurable thresholds are out of scope.
- Audio files are stored locally and synced to backend storage when online. End-to-end encryption of audio is out of scope for this release.
- The year component of an important date is optional; annual recurrence computes from month and day only.
- Swipe gestures replace all persistent in-card action buttons. The at-rest card state shows no interactive controls.
