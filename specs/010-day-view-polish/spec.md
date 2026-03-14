# Feature Specification: Day View Polish — Clarity, Hierarchy & Visual Cohesion

**Feature Branch**: `010-day-view-polish`
**Created**: 2026-03-13
**Status**: Draft
**Input**: Refine the Day View of the personal CRM app to improve clarity, hierarchy, and visual cohesion while keeping the calm bullet-journal style.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Fix Empty-State Logic (Priority: P1)

A user with entries logged for today opens the Day View. The empty-state "Nothing to do — you're all caught up" message does not appear alongside a populated timeline. The empty state only shows when there are truly no logs and no open tasks for the selected day.

**Why this priority**: A contradictory empty-state is a correctness bug. It undermines trust and causes confusion. No other polish work matters if the UI is factually wrong about its own content.

**Independent Test**: Log one entry for today. Open the Day View. Confirm no empty-state message appears. Delete all entries and confirm the message then appears.

**Acceptance Scenarios**:

1. **Given** the day has one or more log entries, **When** the user opens the Day View, **Then** the empty-state message is not shown anywhere on screen.
2. **Given** the day has no logs and no open tasks, **When** the user opens the Day View, **Then** the empty-state message is shown.
3. **Given** the day has only completed tasks and no notes, **When** the user opens the Day View, **Then** the empty-state message is hidden (completed entries are still entries).

---

### User Story 2 — Stronger Task vs Note Distinction (Priority: P2)

A user scanning the Day View timeline can immediately distinguish a task from a note by their leading markers — without reading the content. Open tasks use a hollow circle with a tappable affordance. Completed tasks use a filled checkmark. Notes use a simple non-interactive dot.

**Why this priority**: The distinction between tasks and notes is the core semantic difference in the bullet-journal model. Without clear visual separation, the timeline is an undifferentiated list.

**Independent Test**: Log one note and one task. Without reading their text, distinguish them at a glance by leading icon. Complete the task and confirm the visual state changes clearly.

**Acceptance Scenarios**:

1. **Given** a note entry in the timeline, **When** viewed, **Then** its leading marker is a small dot with no tappable affordance.
2. **Given** an open task entry, **When** viewed, **Then** its leading marker is a hollow circle that signals interactivity.
3. **Given** a completed task, **When** viewed, **Then** its leading marker is a filled checkmark and its text appears at visually reduced emphasis.
4. **Given** a note and a task on screen at the same time, **When** the user scans the timeline, **Then** the two types are immediately distinguishable without reading content.

---

### User Story 3 — Timestamp as Secondary Metadata (Priority: P3)

A user reading a timeline entry scans the content text before the timestamp. The timestamp does not sit inline between the leading icon and the content text. It is positioned as trailing right-aligned metadata within the row, or below the content as a sub-line label.

**Why this priority**: Timestamps interrupting the icon-to-content reading flow hurt scanability for every entry. Moving them to a secondary position improves readability across the entire timeline.

**Independent Test**: Log three entries at different times. Scan the timeline. Confirm the eye naturally reaches content text before timestamp for each entry. Confirm timestamp is still visible.

**Acceptance Scenarios**:

1. **Given** any timeline entry, **When** viewed, **Then** the content text is visually primary and the timestamp is visually secondary (right-aligned or below content).
2. **Given** a multiline entry, **When** viewed, **Then** the timestamp remains in a consistent secondary position and does not interrupt any content line.

---

### User Story 4 — Multiline Text Indentation (Priority: P4)

A user who has logged a multi-sentence entry sees all lines of text aligned consistently with the beginning of the first line of content — not with the leading icon or marker. Wrapped lines form a clean, consistently indented text block.

**Why this priority**: Misaligned wrapped text makes dense entries visually untidy and hard to read. Correct indentation is required for longer-form journaling use cases.

**Independent Test**: Log a note with 4+ lines of text. Confirm all wrapped lines start at the same horizontal position as the first character of the first line.

**Acceptance Scenarios**:

1. **Given** a note with 3 or more lines, **When** viewed in the timeline, **Then** all wrapped lines are left-aligned with the start of the first line of text, not the leading icon.
2. **Given** a task with a long description, **When** viewed, **Then** the text block is consistently indented and the completion icon is top-aligned with the first line.

---

### User Story 5 — Spacing, Card Styling & Section Header (Priority: P5)

A user scrolling the Day View experiences a lighter, more breathable feed. Cards have slightly more internal padding, are separated by more vertical whitespace, have softer borders, and are headed by a quiet editorial section label.

**Why this priority**: Spacing and visual weight are the foundation of the bulletin-journal aesthetic. Without breathing room, even well-designed entries feel dense and low-quality.

**Independent Test**: View a Day View with 5+ entries. Cards feel well-separated. Borders are subtle. The section header is legible but understated.

**Acceptance Scenarios**:

1. **Given** a populated Day View, **When** viewed, **Then** cards have visible internal breathing room and are not visually cramped.
2. **Given** card borders are rendered, **When** viewed, **Then** they appear at reduced opacity or softer contrast compared to the current state.
3. **Given** the section header, **When** viewed, **Then** it uses quiet typography — not all-caps heavy — while remaining legible.

---

### User Story 6 — @Mention Styling (Priority: P6)

A user scanning a timeline entry containing a person mention such as "@Alex" can identify the mention at a glance. The mention text has subtle visual emphasis relative to surrounding body text, without overwhelming the entry.

**Why this priority**: Mention recognition reinforces the relationship-first identity of the app. It helps users scan for social context without needing to parse every word.

**Independent Test**: Log a note containing "@Alex". View the entry in the timeline. Confirm "@Alex" is visually distinct from surrounding text.

**Acceptance Scenarios**:

1. **Given** an entry containing "@Name", **When** viewed in the timeline, **Then** the mention text has subtle visual differentiation from body text.
2. **Given** an entry with multiple mentions, **When** viewed, **Then** all mentions are styled consistently and remain visually subordinate to the entry content.

---

### User Story 7 — Composer and Tab Bar Integration (Priority: P7)

A user viewing the Day View sees the composer and tab bar as one coherent bottom region, not two separate floating layers competing for attention. When the keyboard opens, the tab bar is hidden so only the composer is visible at the bottom.

**Why this priority**: The bottom area is the most frequently touched region of the app. When it feels fragmented, it signals low polish and increases visual complexity at the moment of capture.

**Independent Test**: View the Day View with the keyboard hidden. The bottom region reads as a unified zone. Open the composer and confirm the tab bar disappears cleanly.

**Acceptance Scenarios**:

1. **Given** the Day View with keyboard hidden, **When** viewed, **Then** the composer and tab bar form a visually unified bottom region with no competing visual weight.
2. **Given** the composer is focused and the keyboard is visible, **When** the keyboard is open, **Then** only the composer is visible at the bottom — the tab bar is not shown.

---

### Edge Cases

- What happens when a day has only completed tasks and no notes? → Empty-state must be hidden; completed tasks count as entries.
- What happens when a note contains an @mention for a person not in contacts? → Mention is styled consistently; no error or fallback state.
- What happens when an entry's text wraps to 6+ lines? → Card grows vertically; swipe-to-delete still works on the full card height.
- What happens when the empty-state and entries coexist briefly during load? → Empty-state disappears as soon as any entry is present; it must not flash and persist.
- What happens when the day label is today vs a past date? → Section header styling is consistent regardless of which day is selected.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The empty-state message MUST only appear when the selected day has zero log entries and zero open tasks.
- **FR-002**: When one or more entries are present (any type, any status), the empty-state message MUST be completely hidden.
- **FR-003**: Task entries in the timeline MUST display a hollow circle leading icon when open and a filled checkmark icon when completed.
- **FR-004**: Note entries in the timeline MUST display a simple dot leading marker with no interactive affordance.
- **FR-005**: The timestamp for each entry MUST be positioned as visually secondary — either right-aligned in the entry row or placed below the content text.
- **FR-006**: The timestamp MUST NOT appear between the leading icon and the content text in the reading flow.
- **FR-007**: Wrapped lines of multiline entries MUST align horizontally with the start of the first line of content, not with the leading icon.
- **FR-008**: Card internal padding MUST be increased relative to the current state to create visible breathing room.
- **FR-009**: Vertical spacing between timeline cards MUST be increased so the feed feels lighter and easier to scan.
- **FR-010**: Card borders MUST be rendered at reduced opacity or with softer contrast so they feel premium rather than harsh.
- **FR-011**: The section header MUST use quiet, editorial typography — readable but visually subdued.
- **FR-012**: Person mentions matching the `@Name` pattern within log entries MUST be rendered with subtle visual differentiation from surrounding body text.
- **FR-013**: The composer and tab bar MUST visually integrate as a unified bottom region when the keyboard is hidden.
- **FR-014**: When the keyboard is open, the tab bar MUST be hidden so only the composer is visible at the bottom of the screen.
- **FR-015**: Timeline cards MUST continue to grow vertically to show full content without truncation.
- **FR-016**: Swipe-to-delete MUST continue to function correctly on cards of any height.

### Key Entities

- **TimelineEntry**: A single log or task displayed in the Day View. Has a type (note or task), a status (open or complete), content text, a timestamp, and optional person mention links.
- **EmptyState**: A UI state that is shown only when no TimelineEntry objects exist for the selected day.
- **SectionHeader**: The date or day label displayed above the timeline entry list.
- **ComposerBottomRegion**: The unified bottom zone comprising the quick-capture composer and the tab navigation bar.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The empty-state message never co-exists with visible timeline entries — 0 contradictory-state occurrences across all test scenarios.
- **SC-002**: A user can distinguish a task from a note without reading entry text — differentiation is achievable by leading icon alone in under 1 second.
- **SC-003**: For any multiline entry, all wrapped lines are horizontally aligned with the first character of the first content line — verifiable by visual inspection.
- **SC-004**: The composer and tab bar render as a visually unified bottom zone when the keyboard is hidden — no visible gap, competing shadow, or layering conflict between the two elements.
- **SC-005**: Person @mentions are visually distinguishable from surrounding body text in 100% of entries containing mentions.
- **SC-006**: All existing functionality (logging, task completion, swipe-to-delete, navigation, dynamic card height) continues without regression after the changes.

## Assumptions

- Completed tasks remain inline in the Day View at their original position — no separate completed section is introduced by this feature.
- The timestamp secondary position defaults to right-aligned trailing in the same row. Below-content positioning is an acceptable alternative if right-alignment creates layout issues for long or multiline entries.
- @mention detection uses the existing `@Name` text pattern stored in the content field — no new data model changes are needed.
- The composer and tab bar integration is a visual layout change only; navigation behavior and capture behavior are unchanged.
- Dynamic card height (introduced in 009-ui-polish) is preserved and extended — this feature refines it rather than replacing it.
- No animations, confetti, or gamification elements are introduced alongside these polish changes — the calm, reflective identity is non-negotiable.
- The optional timeline connector treatment (subtle vertical line or dot connector between entries) is in scope only if it can be implemented without adding visual noise; it is not a required deliverable.
