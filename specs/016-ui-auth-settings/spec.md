# Feature Specification: App UI Polish, Authentication Flow & Settings Tab

**Feature Branch**: `016-ui-auth-settings`
**Created**: 2026-03-15
**Status**: Draft
**Input**: User description: "Implement product, UX, and app structure changes: timeline card cleanup, linked person tagging fix, log detail redesign, authentication flow with backend integration, and full settings tab."

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Authentication Flow (Priority: P1)

A new user opens the app and is routed to a login or register screen rather than directly into the main experience. After registering with email and password, they are authenticated and taken to the main app. On subsequent launches, a valid session is detected and the main app opens directly without requiring login. When the session expires or the user logs out, they are returned to the auth flow.

**Why this priority**: Without authentication, no user data is protected and backend sync is meaningless. This is the architectural prerequisite for all personalised and synced experiences.

**Independent Test**: Install the app fresh → launch → lands on login screen. Register a new account → lands on main app. Force-quit and relaunch → skips auth (session valid). Tap logout in settings → returns to login screen.

**Acceptance Scenarios**:

1. **Given** a fresh install with no stored session, **When** the app launches, **Then** the login screen is displayed instead of the main timeline.
2. **Given** the login screen is displayed, **When** the user taps "Create account", **Then** the register screen is displayed.
3. **Given** the register screen, **When** the user submits a valid email and password (min 8 chars), **Then** their account is created, a session is established, and the main app opens.
4. **Given** the login screen, **When** the user submits correct credentials, **Then** a session is established and the main app opens.
5. **Given** the login screen, **When** the user submits incorrect credentials, **Then** a clear inline error is displayed and they remain on the login screen.
6. **Given** a valid stored session, **When** the app launches, **Then** the main app opens directly without showing auth screens.
7. **Given** the user is in the main app, **When** they tap logout in settings, **Then** the session is cleared and the login screen is shown.
8. **Given** a stored session that has expired, **When** the app launches or makes an authenticated request, **Then** the user is redirected to the login screen with a non-alarming "session expired" notice.

---

### User Story 2 — Settings Tab (Priority: P2)

A logged-in user taps the Settings tab in the main navigation and sees a comprehensive, grouped settings screen. They can navigate to dedicated detail pages for Account, Notifications, Appearance, Privacy & Security, Sync & Data, and About. Changes in settings are persisted and immediately reflected in app behaviour.

**Why this priority**: Settings hosts the logout action and notification preferences that affect backend behaviour — both critical for production readiness.

**Independent Test**: Navigate to Settings tab → verify all section groups render with rows. Tap "Account" → verify profile and logout available. Toggle a notification setting off → close and reopen the app → confirm toggle still off.

**Acceptance Scenarios**:

1. **Given** the user is logged in, **When** they tap the Settings tab, **Then** a grouped settings screen appears with sections: Account, Notifications, Appearance, Privacy & Security, Sync & Data, and About.
2. **Given** the settings screen, **When** the user taps "Account", **Then** a detail page shows the current email, a change-password option, and a visually separated logout button.
3. **Given** the Account detail page, **When** the user taps logout, **Then** a confirmation dialog appears before the session is cleared.
4. **Given** the Notifications detail page, **When** the user toggles "Follow-up reminders" off, **Then** the preference is saved and synced to the backend.
5. **Given** the Sync & Data detail page, **When** the user views the page, **Then** they can see the last sync time and trigger a manual sync.
6. **Given** the Appearance detail page, **When** the user selects light/dark/system theme, **Then** the app theme changes immediately and persists across launches.
7. **Given** the About page, **When** the user views it, **Then** the app version, a privacy policy link, and a support contact are displayed.

---

### User Story 3 — Log Detail View Redesign (Priority: P3)

A user taps a log card on the timeline and is taken to a redesigned detail view that feels premium, minimal, and consistent with the timeline. The detail view shows all relevant content in a clear hierarchy: main text, log type, timestamps, linked persons as tappable chips, and any follow-up information. Quick actions are available at the top or in a bottom sheet.

**Why this priority**: The detail view is the most-visited screen after the timeline itself. A polished detail experience directly impacts perceived quality.

**Independent Test**: Open any log from the timeline → verify content, metadata, linked person chips, and action buttons render correctly. Tap a linked person chip → verify person detail opens. Tap "Edit" → verify edit form opens. Trigger delete → verify confirmation appears.

**Acceptance Scenarios**:

1. **Given** a log on the timeline, **When** the user taps the card, **Then** a detail view opens with a smooth transition showing the full log content.
2. **Given** the log detail view, **When** the log has linked persons, **Then** all linked persons appear as tappable chips.
3. **Given** the log detail view, **When** the user taps a linked person chip, **Then** the person detail screen opens.
4. **Given** the log detail view, **When** the log has an associated follow-up, **Then** the follow-up is displayed with its due date and status.
5. **Given** the log detail view, **When** the user taps "Edit", **Then** the compose/edit form opens pre-filled with the current log data.
6. **Given** the log detail view, **When** the user triggers the delete action, **Then** a confirmation dialog appears before deletion.
7. **Given** a log with very long content, **When** the detail view opens, **Then** the full text is readable via scroll without overflow.
8. **Given** the log detail view is dismissed, **When** the timeline is shown, **Then** it returns to the same scroll position as before.

---

### User Story 4 — Linked Persons Tagging Fix (Priority: P4)

When a log is linked to multiple persons, all linked persons are displayed as chips on both the timeline card and the detail view. Chips wrap to the next line when they overflow available width. Long names truncate gracefully. Person links are correctly persisted when creating or editing a log and loaded from both local and backend state.

**Why this priority**: Displaying only some linked persons is a data integrity issue that erodes trust. Fixing it restores correctness across all surfaces.

**Independent Test**: Create a log linked to 4 persons with a mix of short and long names → verify all 4 chips appear on the timeline card. Relaunch the app → verify all 4 links persist.

**Acceptance Scenarios**:

1. **Given** a log linked to 3 or more persons, **When** it is displayed on the timeline card, **Then** all linked person names appear as chips with none silently dropped.
2. **Given** chips that exceed the card width, **When** rendered on the timeline card, **Then** chips wrap to the next line without clipping or overflow.
3. **Given** a person name longer than 20 characters, **When** shown as a chip, **Then** the name truncates with an ellipsis within the chip boundary.
4. **Given** a log is created with linked persons, **When** the app is restarted, **Then** all person links are present in both local storage and reflected in backend sync.
5. **Given** the log edit screen, **When** a person is added or removed as a tag, **Then** the change is persisted and immediately reflected on the timeline card and detail view.

---

### User Story 5 — Timeline Card Cleanup (Priority: P5)

The timeline cards no longer display a dot indicator. The visual hierarchy of date separators, timeline items, and card content remains clear and intentional without the dot. Spacing and alignment are adjusted so cards look clean and polished.

**Why this priority**: This is a targeted visual improvement; lower priority as it is cosmetic and does not affect data or functionality.

**Independent Test**: Open the timeline → verify no dots appear on any log cards. Verify date separators remain visually distinct. Verify card spacing and alignment look intentional.

**Acceptance Scenarios**:

1. **Given** the timeline is displayed, **When** any log card is visible, **Then** no dot indicator appears on the card.
2. **Given** the timeline is displayed, **When** multiple cards are shown, **Then** date separators remain visually distinct from card content.
3. **Given** a log card with or without linked persons, **When** displayed on the timeline, **Then** the card spacing and alignment are consistent and intentional.

---

### Edge Cases

- What happens when the user registers with an email that already exists? → Show "Email already in use" error with a hint to log in instead.
- What happens when session token refresh fails due to network being offline? → Cache last valid session; show offline indicator; prompt re-auth when back online.
- What happens when a log has zero linked persons? → The person chip area is not rendered; no empty space is left.
- What happens when the app is offline and the user changes notification settings? → Save the change locally and sync to the backend when connectivity is restored.
- What happens when the user attempts to change their password but enters the wrong current password? → Show an inline error without clearing the new-password field.
- What happens when a log detail is opened for a record that no longer exists locally? → Show a brief error message and return to the timeline.

---

## Requirements *(mandatory)*

### Functional Requirements

#### Authentication

- **FR-001**: The app MUST route unauthenticated users to the login screen on launch; users with a valid session go directly to the main app.
- **FR-002**: The login screen MUST support email + password authentication and provide clear error messages for invalid credentials.
- **FR-003**: The register screen MUST validate that the email is well-formed and the password is at least 8 characters.
- **FR-004**: Sessions MUST be persisted securely on-device and restored automatically on subsequent launches.
- **FR-005**: The app MUST detect an expired session and redirect to the login screen with a non-alarming informational message.
- **FR-006**: All authenticated requests MUST include the current access token; on a 401 response the app MUST attempt a token refresh before redirecting to login.
- **FR-007**: Logout MUST clear all session tokens and user state from device memory.

#### Settings

- **FR-008**: The settings tab MUST display grouped sections: Account, Notifications, Appearance, Privacy & Security, Sync & Data, About.
- **FR-009**: The Account section MUST allow viewing the current email, initiating a password change, and logging out.
- **FR-010**: Logout in settings MUST require a confirmation step before executing.
- **FR-011**: The Notifications section MUST expose a toggle for push notifications and follow-up reminder controls; changes MUST be synced to the backend user settings.
- **FR-012**: The Appearance section MUST allow selecting system/light/dark theme and apply the selection immediately and persistently.
- **FR-013**: The Sync & Data section MUST display the last sync timestamp and allow triggering a manual sync.
- **FR-014**: The About section MUST display the app version number and links to privacy policy and support.

#### Log Detail View

- **FR-015**: The log detail view MUST display: main content text, log type badge, created and updated timestamps, linked person chips, follow-up information (if present), an edit action, and a delete action.
- **FR-016**: Linked person chips in the detail view MUST be tappable and navigate to the respective person detail screen.
- **FR-017**: The delete action MUST be gated behind a confirmation dialog.
- **FR-018**: Long log content MUST be fully readable via scrolling without text being clipped.
- **FR-019**: Dismissing the detail view MUST return the user to the same timeline scroll position.

#### Linked Persons

- **FR-020**: All linked persons MUST be rendered on the timeline card regardless of count.
- **FR-021**: Person chips MUST wrap to additional lines when they exceed the available width on any surface.
- **FR-022**: Person chip names longer than 20 characters MUST truncate with an ellipsis.
- **FR-023**: Person links created or edited on a log MUST be persisted locally and synced to the backend.

#### Timeline Card Cleanup

- **FR-024**: Dot indicators MUST be removed from timeline log cards.
- **FR-025**: Date separators MUST remain visually distinct from cards after dot removal.

### Key Entities

- **Session**: Stores access token, refresh token, and expiry metadata; persisted securely on-device.
- **User**: Email address, display name; loaded from backend after successful login.
- **UserSettings**: Notifications enabled, follow-up reminders enabled, quiet hours (future), theme preference; synced with backend for notification fields.
- **Log**: Content, type, status, timestamps, linked person IDs; existing entity with display and persistence fixes applied.
- **Person**: Name, notes; existing entity — serves as navigation target from person chips.
- **FollowUp**: Title, due date, status; existing entity — displayed within the log detail view.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A new user can complete registration and reach the main app in under 60 seconds from first launch.
- **SC-002**: A returning user with a valid session is in the main app within 2 seconds of launch with no auth screen shown.
- **SC-003**: 100% of linked persons are displayed as chips on the timeline card — zero silent drops regardless of count.
- **SC-004**: All 6 settings sections are navigable; all detail pages are reachable within 2 taps from the settings root.
- **SC-005**: The log detail view displays all defined metadata fields without horizontal scroll.
- **SC-006**: Notification preference changes are reflected in backend user settings within one sync cycle.
- **SC-007**: Zero dot indicators appear on timeline cards after the change.
- **SC-008**: Theme selection persists correctly across app restarts.

---

## Assumptions

- The backend Go API (specs/015-go-backend) provides: `POST /v1/auth/register`, `POST /v1/auth/login`, `POST /v1/auth/refresh`, `POST /v1/auth/logout`, `GET /v1/settings`, `PATCH /v1/settings`.
- A password-change endpoint (`PATCH /v1/auth/password`) is not in the 015 spec and must be added as a new backend contract.
- Social sign-in (Google, Apple) is out of scope; the UI must not block adding it later.
- Quiet hours in notification settings will be stored locally only; backend support is a future iteration.
- Data export in Sync & Data is a UI placeholder; no export functionality is implemented in this iteration.
- Secure session storage uses the platform keychain/keystore.
- The existing drift/SQLite local database retains all log and person data; no schema changes are required for this feature.
- The app currently has a tab navigator; a Settings tab is added as an additional tab.
- Theme preference is stored locally only and is not synced to the backend.
