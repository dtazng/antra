# Feature Specification: Person Detail View

**Feature Branch**: `004-person-detail-view`
**Created**: 2026-03-10
**Status**: Draft
**Input**: Design and implement the Person Detail View for a Personal CRM app with a summary-first structure, relationship insights, recent activity preview, pinned notes, and a dedicated full activity timeline with pagination.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - At-a-Glance Relationship Overview (Priority: P1)

A user opens a person's detail screen and immediately understands the state of that relationship — who the person is, when they last talked, whether a follow-up is pending, and how active the relationship has been recently — without having to scroll through a log.

**Why this priority**: This is the primary reason a user taps into a person's profile. If the screen is just a long log, the feature delivers no value beyond the existing implementation. The summary-first layout is the core design bet of this feature.

**Independent Test**: Open a person who has 50+ linked interactions. Verify the screen loads structured sections (header, quick stats, recent activity preview) without showing more than 10 activity rows. Confirm the total count and 30-day count are visible above the fold on a standard phone screen.

**Acceptance Scenarios**:

1. **Given** a person with 80 linked interactions, **When** the user opens their detail screen, **Then** only the most recent 5–10 interactions are visible in the Recent Activity section, and a "View All Activity" entry point is clearly visible.
2. **Given** a person with a follow-up flag set, **When** the user opens the detail screen, **Then** the follow-up state (overdue, upcoming, or pending) is visible in the header area without scrolling.
3. **Given** a person with no interactions, **When** the user opens the detail screen, **Then** an empty state is shown for the Recent Activity section with a prompt to log an interaction.
4. **Given** any person, **When** the screen loads, **Then** the interaction summary stats (total count, last 30 days, last 90 days) are visible as a lightweight card above the activity list.

---

### User Story 2 - Quick Action Bar (Priority: P1)

A user can take the most important CRM actions directly from the person detail screen without navigating to another screen first: log a new interaction, add a note, set or update a follow-up reminder, and open the edit profile sheet.

**Why this priority**: A CRM detail screen that doesn't support fast logging is friction in the primary workflow. Quick actions must be immediately available. Shares P1 priority with the overview story because neither works without the other.

**Independent Test**: From a person's detail screen, tap each quick action button. Confirm: "Log interaction" opens the capture bar or a log sheet pre-linked to the person; "Add note" opens a note input pre-linked to the person; "Follow-up" opens the follow-up date/flag picker; "Edit" opens the EditPersonSheet.

**Acceptance Scenarios**:

1. **Given** a person detail screen is open, **When** the user taps "Log interaction", **Then** a log entry sheet opens with the person already attached.
2. **Given** a person detail screen is open, **When** the user taps "Add note", **Then** a plain-text note input opens and the saved note appears linked to this person.
3. **Given** a person with no follow-up set, **When** the user taps "Follow-up", **Then** a date picker and "Mark as needs follow-up" option appear; saving updates the header badge immediately.
4. **Given** a person detail screen is open, **When** the user taps "Edit", **Then** the full-field person edit sheet opens and changes are reflected on the detail screen after save.

---

### User Story 3 - Full Activity Timeline (Priority: P2)

A user who wants to review the complete history of their interactions with a person can navigate to a dedicated full activity timeline. This timeline groups entries by month/year, supports type-based filtering, and loads more entries as the user scrolls down.

**Why this priority**: The full history is essential for power users and for auditing the relationship, but it is not needed for every visit. Placing it on a separate screen keeps the main detail screen fast and clean.

**Independent Test**: From a person's detail screen, tap "View All Activity". A new screen opens showing all interactions grouped by month. Apply a filter (e.g. "notes only") and confirm only note-type entries remain. Scroll past the initial load boundary and confirm more entries load.

**Acceptance Scenarios**:

1. **Given** a person with 60 interactions across 3 years, **When** the user opens the full timeline, **Then** interactions are grouped under month–year headers in reverse chronological order.
2. **Given** the full timeline is open, **When** the user selects the "Notes" filter, **Then** only note-type entries remain visible and the count updates accordingly.
3. **Given** the full timeline has loaded 20 entries, **When** the user scrolls to the bottom, **Then** the next batch of entries loads automatically without a visible page-break.
4. **Given** a person with no interactions of the selected type, **When** a filter is applied, **Then** an empty state message is shown ("No [type] logged yet").

---

### User Story 4 - Pinned Notes / Key Facts (Priority: P2)

A user can create short pinned facts or highlights about a person — things like "met at ProductCon 2024", "prefers async communication", "has two kids: Maya and Liam" — and these pinned items appear near the top of the detail screen, always visible, never buried in the timeline.

**Why this priority**: The timeline captures events in order; pinned notes capture persistent knowledge. Without pinning, important context disappears into scroll history. This is what makes the CRM feel like a relationship memory rather than a log viewer.

**Independent Test**: Add a pinned fact to a person. Reopen the detail screen. Confirm the fact appears in the Pinned Notes section above the Recent Activity section. Add a second pinned fact. Unpin the first. Confirm only the second remains pinned.

**Acceptance Scenarios**:

1. **Given** a person with one pinned note, **When** the detail screen opens, **Then** the pinned note is visible in the Pinned Notes section before the Recent Activity section.
2. **Given** the user taps "Add note" and opts to pin it, **When** the note is saved, **Then** it appears immediately in the Pinned Notes section.
3. **Given** a pinned note, **When** the user long-presses or swipes it and selects "Unpin", **Then** the note moves to the regular timeline and disappears from the Pinned Notes section.
4. **Given** a person has no pinned notes, **When** the detail screen opens, **Then** the Pinned Notes section shows a subtle empty state or is collapsed/hidden.

---

### User Story 5 - Relationship Insights (Priority: P3)

An optional, low-prominence insights area shows the user helpful context about the relationship: how many days since the last interaction, whether the relationship is at risk of going stale based on cadence, whether there is an overdue follow-up, and a suggested next action if applicable.

**Why this priority**: This is a value-add layer, not core CRM functionality. It makes the app feel intelligent, but the app is fully functional without it. Implemented last to avoid adding complexity before the core structure is stable.

**Independent Test**: Open a person whose last interaction was 45 days ago and who has a 30-day reminder cadence set. Confirm the insights section shows "Overdue — last contact 45 days ago" and a suggested action. For a person with no cadence set and a recent interaction, confirm the insights section is empty or hidden.

**Acceptance Scenarios**:

1. **Given** a person with a 30-day cadence and last interaction 40 days ago, **When** the detail screen opens, **Then** the insights section shows an overdue warning and suggests logging a new interaction.
2. **Given** a person with no cadence and a recent interaction (within 7 days), **When** the detail screen opens, **Then** the insights section is collapsed or shows no warnings.
3. **Given** a person with a future follow-up date, **When** the detail screen opens, **Then** the insights section shows "Follow-up due in N days" in a calm, non-alarming style.

---

### Edge Cases

- **Person with zero interactions**: Each section (Recent Activity, Insights, Full Timeline) must show an appropriate empty state — no crashes, no phantom counts.
- **Person with 1,000+ interactions**: The main detail screen must not load all entries; the full timeline must paginate correctly and not freeze the UI.
- **Person deleted while detail screen is open**: Screen must detect the deletion (via reactive stream) and navigate back to the people list gracefully.
- **Pinned note edited to be empty**: System must either prevent saving an empty note or automatically unpin it.
- **Full timeline filter yields zero results**: Show a contextual empty state matching the active filter, not a generic "no data" message.
- **Follow-up date in the past**: Insights section shows "Overdue" in red, not "due in -N days".
- **Person with only pinned notes and no timeline interactions**: Recent Activity section shows empty state while Pinned Notes section is populated.
- **Very long pinned note content**: Pinned notes must truncate at 3 lines with a "Show more" affordance.

---

## Requirements *(mandatory)*

### Functional Requirements

#### Person Detail Screen — Structure

- **FR-001**: The main Person Detail screen MUST render in a fixed set of collapsible sections regardless of how many total interactions exist for the person.
- **FR-002**: The main Person Detail screen MUST NOT load more than 10 interaction records for display in the Recent Activity section.
- **FR-003**: The screen MUST display a "View All Activity" entry point that navigates to the Full Activity Timeline when tapped.
- **FR-004**: Section order MUST follow: Header → Quick Actions → Relationship Summary → Recent Activity → Pinned Notes → Relationship Insights → Full Timeline link.

#### Header / Identity

- **FR-005**: The header MUST display the person's full name, avatar (initial-based if no photo), and secondary metadata (company and/or role if set).
- **FR-006**: The header MUST show the follow-up state badge (overdue / upcoming / no follow-up) derived from the existing `needsFollowUp` and `followUpDate` fields.
- **FR-007**: The header MUST show the last interaction date in a human-readable relative format (e.g., "3 days ago", "Last month").

#### Quick Actions

- **FR-008**: The Quick Actions bar MUST include four actions: Log interaction, Add note, Follow-up, Edit.
- **FR-009**: Tapping "Log interaction" MUST open a log entry sheet with the person pre-attached.
- **FR-010**: Tapping "Add note" MUST open a note input sheet with the person pre-attached.
- **FR-011**: Tapping "Follow-up" MUST open the follow-up picker (date + needs-flag toggle), consistent with the existing `_FollowUpSection` behavior.
- **FR-012**: Tapping "Edit" MUST open the `EditPersonSheet` with all current person fields pre-filled.

#### Relationship Summary

- **FR-013**: The summary section MUST display: total interaction count, count in last 30 days, count in last 90 days.
- **FR-014**: The summary section SHOULD display a per-type breakdown (note, task, event) when the person has at least 3 interactions.
- **FR-015**: Counts MUST be computed from the `bullet_person_links` table joined with `bullets`, filtered by `isDeleted = 0` on both sides.

#### Recent Activity

- **FR-016**: Recent Activity MUST show the 5 most recent interactions by default, with a "Show more" affordance revealing up to 10 total before the "View All" link takes over.
- **FR-017**: Each activity row MUST display: type icon, truncated content preview (1 line), and relative date.
- **FR-018**: Tapping an activity row MUST navigate to the appropriate detail screen (BulletDetailScreen or TaskDetailScreen).

#### Full Activity Timeline

- **FR-019**: The Full Activity Timeline MUST be a separate screen navigated to from the detail screen.
- **FR-020**: The timeline MUST group entries under month–year section headers (e.g., "March 2026", "February 2026").
- **FR-021**: The timeline MUST support pagination: initial load of 20 entries, loading the next 20 when the user scrolls within 200px of the bottom.
- **FR-022**: The timeline MUST support type filters: All, Notes, Tasks, Events. Selecting a filter re-queries from offset 0 with the type constraint applied.
- **FR-023**: The timeline MUST display a per-type empty state when a filter is active and returns no results.

#### Pinned Notes

- **FR-024**: Notes MUST be individually pinnable. A pinned flag is stored per note/bullet record.
- **FR-025**: Pinned notes MUST appear in the Pinned Notes section on the main detail screen, in creation order (oldest first).
- **FR-026**: A pinned note MUST be unpinnable via a long-press or swipe action, moving it back to the regular timeline.
- **FR-027**: The Pinned Notes section MUST truncate note content at 3 lines with a "Show more" toggle.
- **FR-028**: When no notes are pinned, the Pinned Notes section MUST be hidden (not shown as empty).

#### Relationship Insights

- **FR-029**: The Insights section MUST be hidden when no insight condition applies (no cadence set, recent interaction, no overdue follow-up).
- **FR-030**: The Insights section MUST show an overdue-cadence warning when `lastInteractionAt` is more than `reminderCadenceDays` days ago.
- **FR-031**: The Insights section MUST show a follow-up countdown ("Due in N days") when `needsFollowUp = 1` and `followUpDate` is in the future.
- **FR-032**: The Insights section MUST show an overdue-follow-up warning ("Overdue — N days ago") when `needsFollowUp = 1` and `followUpDate` is in the past.
- **FR-033**: Insight messages MUST be calm and non-alarming in tone; no exclamation marks or urgency language.

### Key Entities

- **Person**: The contact whose detail screen is being displayed. Has identity fields (name, company, role), contact fields (email, phone, location), CRM fields (tags, relationshipType, reminderCadenceDays, needsFollowUp, followUpDate, lastInteractionAt), and notes. Existing entity — extended, not replaced.
- **Bullet / Interaction**: A log entry (note, task, or event) linked to a person via `bullet_person_links`. Has content, type, status (for tasks), and timestamps. Existing entity — no schema changes needed for the core timeline.
- **Pinned Note**: A bullet (of type "note") with a boolean `isPinned` flag. Appears in the Pinned Notes section when `isPinned = true`. Requires a new `isPinned` column on the `bullets` table (or `bullet_person_links`).
- **Interaction Summary**: A computed read-only aggregate (total count, 30-day count, 90-day count, per-type breakdown) derived from `bullet_person_links` for display in the Relationship Summary section. Not persisted — computed on demand.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The main Person Detail screen renders completely in under 500ms for a person with up to 500 linked interactions.
- **SC-002**: The main Person Detail screen contains at most 10 interaction rows regardless of how many total interactions exist.
- **SC-003**: Users can log a new interaction from the detail screen in 3 taps or fewer.
- **SC-004**: The Full Activity Timeline loads the next page of results within 300ms of the user reaching the scroll threshold.
- **SC-005**: Users with a pinned note can locate it on the main detail screen without scrolling past the Recent Activity section.
- **SC-006**: 100% of persons with `needsFollowUp = 1` display a follow-up indicator in the detail screen header without requiring a tap.
- **SC-007**: All type filters on the Full Activity Timeline return accurate results (zero false positives/negatives) verified against the source data.

---

## Assumptions

- A "note" bullet (type = "note") is the appropriate vehicle for pinned facts. A new `isPinned` boolean column will be added to `bullets` (or `bullet_person_links`). The schema implication is minimal and additive.
- "Log interaction" from the Quick Actions bar opens the existing `BulletCaptureBar` or a dedicated log sheet pre-filled with `@PersonName` — the exact mechanism will be decided during planning.
- Relationship strength / health indicator (mentioned as optional in the brief) is deferred to a future feature. The Insights section covers the behaviorally equivalent use case with days-since-last-contact and cadence warnings.
- Photo upload is out of scope. Avatars remain initial-based (consistent with the current design system).
- The Pinned Notes section is hidden when empty to avoid visual noise — there is no "add pinned note" affordance in the empty state of that section; pinning is done from the note itself.
- "Log interaction" and "Add note" are treated as distinct actions: "Log interaction" creates a generic note/event; "Add note" creates a note type specifically. They may collapse into one action if the capture sheet already handles type selection — deferred to planning.
- Pagination page size defaults to 20 entries. This can be tuned during implementation without spec changes.
