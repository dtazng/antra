# Feature Specification: Go Containerized Backend with PostgreSQL

**Feature Branch**: `015-go-backend`
**Created**: 2026-03-14
**Status**: Draft

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Secure Account Access (Priority: P1)

A new user downloads the mobile app, creates an account with their email and password, and immediately begins using the app. Returning users log in and remain authenticated across sessions without repeated logins. Logging out invalidates the session immediately and protects the user's data. If a session expires, the app silently refreshes the token without interrupting the user's workflow.

**Why this priority**: Authentication is the gateway to all other features. Without it, no user data is isolated or protected.

**Independent Test**: Can be fully tested by registering a new account, logging in, refreshing the session token, and logging out — confirming that data is inaccessible after logout.

**Acceptance Scenarios**:

1. **Given** a new email address, **When** the user registers, **Then** an account is created and a valid session is returned.
2. **Given** a valid account, **When** the user logs in with correct credentials, **Then** a session is returned.
3. **Given** a valid account, **When** the user logs in with wrong credentials, **Then** access is denied with a clear error.
4. **Given** an active session, **When** the access token expires, **Then** the user can exchange a refresh token for a new session token without re-entering credentials.
5. **Given** an active session, **When** the user logs out, **Then** the session is immediately invalidated and further requests are rejected.
6. **Given** an authenticated user, **When** the user requests account deletion with explicit confirmation, **Then** all their data is removed and further logins are rejected.

---

### User Story 2 - Offline-First Data Sync (Priority: P2)

A user captures logs and persons on their mobile device while offline. When connectivity is restored, the app pushes local changes to the backend and pulls down newer server data. Changes from a second device appear after a pull. Deletions propagate within one sync cycle.

**Why this priority**: The app's core value is offline-first capture that syncs reliably. This unlocks multi-device use and cloud durability.

**Independent Test**: Push persons and logs from device A, pull on device B, confirm all records appear. A conflicting edit (both devices edit the same record) resolves deterministically with the server's version winning.

**Acceptance Scenarios**:

1. **Given** locally created records, **When** the client pushes changes, **Then** the server stores them and returns a server timestamp.
2. **Given** a server record newer than the client's version, **When** the client pushes an older version, **Then** the server rejects the change and returns the server's current record.
3. **Given** new server records, **When** the client pulls since a timestamp, **Then** only records updated after that timestamp are returned.
4. **Given** a deleted record, **When** the client pushes a delete, **Then** the record is tombstoned and future pulls return it with a `deleted_at` marker.
5. **Given** a fresh device, **When** the client pulls with `since=epoch`, **Then** all of the user's current records are returned.

---

### User Story 3 - Follow-up Scheduling (Priority: P3)

A user creates a follow-up item linked to a person or log entry. The backend tracks the due date and automatically transitions the follow-up to "due" when the date arrives. The user can snooze, complete, or dismiss follow-ups. Recurring follow-ups automatically reschedule after completion.

**Why this priority**: Follow-up logic is the CRM's differentiating feature and must be backend-authoritative across all devices.

**Independent Test**: Create a past-due follow-up, run the scheduling job, confirm status becomes "due". Complete it and confirm it no longer appears in the due list.

**Acceptance Scenarios**:

1. **Given** a follow-up with a due date of today or in the past, **When** the background job runs, **Then** its status changes to "due".
2. **Given** a due follow-up, **When** the user snoozes it, **Then** it is suppressed until the snooze date.
3. **Given** a due follow-up, **When** the user marks it complete, **Then** it is removed from the active due list.
4. **Given** a recurring follow-up that is completed, **When** marked done, **Then** a new follow-up is automatically created for the next occurrence.
5. **Given** a user with notifications enabled, **When** a follow-up becomes due, **Then** a push notification is scheduled.

---

### User Story 4 - Push Notifications (Priority: P4)

A user registers their device for push notifications. When a follow-up becomes due, the backend sends a push notification to all of the user's registered devices. Failed deliveries are retried. A notification inbox in the app shows received notifications.

**Why this priority**: Notifications close the loop on follow-ups — without them, users must proactively open the app to discover what's due.

**Independent Test**: Register a device token, create a past-due follow-up, run the notification job, confirm a delivery record is created. Notification inbox API validates independently.

**Acceptance Scenarios**:

1. **Given** a registered device token, **When** a follow-up becomes due, **Then** a notification is created and push delivery is attempted.
2. **Given** a failed push attempt below the retry limit, **When** the job runs again, **Then** delivery is retried.
3. **Given** stored notifications, **When** the user fetches the inbox, **Then** all notifications are returned in reverse chronological order.
4. **Given** notifications disabled for a user, **When** a follow-up becomes due, **Then** no push is sent.

---

### User Story 5 - User Settings (Priority: P5)

A user opens the Settings tab in the mobile app to view their account, manage notification preferences, adjust default follow-up intervals, and log out or delete their account. Changes are persisted server-side and applied on the next sync.

**Why this priority**: Settings give users control over the product experience and support account lifecycle (logout, deletion).

**Independent Test**: Fetch settings, set `notifications_enabled` to false, run the notification job, confirm no notifications are created for that user.

**Acceptance Scenarios**:

1. **Given** an authenticated user, **When** they fetch settings, **Then** current preferences are returned.
2. **Given** a user who disables notifications, **When** the notification job runs, **Then** no push is sent to that user.
3. **Given** a user who sets a default follow-up interval, **When** a follow-up is created without specifying a due date, **Then** the due date is set using their preference.

---

### User Story 6 - Local Development Environment (Priority: P6)

A developer clones the repository, runs a single command to start the full stack (API, worker, database), applies migrations, loads seed data, and verifies the health endpoint. All features work identically to production. Tests run without cloud dependencies.

**Why this priority**: Developer experience directly impacts iteration speed and system maintainability.

**Independent Test**: `docker compose up` → apply migrations → load seed → `GET /health` returns `ok` → `make test` passes.

**Acceptance Scenarios**:

1. **Given** a fresh clone, **When** `docker compose up` is run, **Then** all services start and the health endpoint returns `ok`.
2. **Given** a running stack, **When** migrations are applied, **Then** all tables are created with correct schema.
3. **Given** a running stack with seed data, **When** a login request is made with seed credentials, **Then** a valid session is returned.
4. **Given** seed data loaded, **When** the test suite is run, **Then** all tests pass without cloud dependencies.

---

### Edge Cases

- What happens when two devices push conflicting edits to the same record simultaneously? (Server timestamp wins — last write wins.)
- What happens when a push token is invalidated by the OS? (Delivery failure recorded; token marked inactive after consecutive failures.)
- What happens when a user is deleted while a sync is in progress? (Subsequent authenticated requests return 401; partial sync data is discarded.)
- What happens when a recurring follow-up is deleted before completion? (No new occurrence is generated.)
- What happens when notifications are disabled mid-job run? (Job checks per-user setting before each notification; in-flight notifications for that run complete.)
- What happens when the database is unreachable? (Health endpoint reports error; API returns 503.)

---

## Requirements *(mandatory)*

### Functional Requirements

#### Authentication

- **FR-001**: System MUST allow users to register with an email address and password.
- **FR-002**: System MUST reject registration for email addresses already in use.
- **FR-003**: System MUST enforce a minimum password length.
- **FR-004**: System MUST issue a short-lived access token and a long-lived refresh token on successful registration or login.
- **FR-005**: System MUST allow refresh tokens to be exchanged for new access tokens without re-authentication.
- **FR-006**: System MUST invalidate a refresh token when the user logs out.
- **FR-007**: System MUST support soft deletion of a user account, making all data inaccessible after deletion.
- **FR-008**: All protected endpoints MUST require a valid access token.

#### Sync

- **FR-009**: System MUST accept batched record changes (upserts and deletes) per entity type from clients.
- **FR-010**: System MUST assign a canonical server timestamp to every accepted record.
- **FR-011**: System MUST apply latest-write-wins conflict resolution: if the server's `updated_at` is newer than the client's submitted `updated_at`, the change is rejected and the server record is returned.
- **FR-012**: System MUST support incremental pull sync, returning only records updated since a given timestamp.
- **FR-013**: System MUST track tombstones via `deleted_at` and include them in pull responses.
- **FR-014**: System MUST support sync for `persons`, `logs`, and `follow_ups` entity types.

#### Persons

- **FR-015**: System MUST allow authenticated users to create, update, soft-delete, and retrieve their persons.
- **FR-016**: System MUST support full-text search across person names and notes.
- **FR-017**: System MUST automatically update a person's last interaction date when a linked log is created or updated.

#### Logs

- **FR-018**: System MUST allow authenticated users to create, update, soft-delete, and retrieve their log entries.
- **FR-019**: System MUST allow multiple persons to be linked to a single log entry.

#### Follow-ups

- **FR-020**: System MUST allow authenticated users to create follow-ups optionally linked to a log and/or person.
- **FR-021**: System MUST automatically transition follow-up status to "due" when the due date is reached.
- **FR-022**: System MUST allow follow-ups to be snoozed, completed, or dismissed.
- **FR-023**: System MUST support recurring follow-ups with a configurable interval in days.
- **FR-024**: System MUST create the next occurrence of a recurring follow-up when the current one is completed.
- **FR-025**: System MUST expose an endpoint returning all "due" follow-ups for the authenticated user.

#### Notifications

- **FR-026**: System MUST allow users to register one or more device tokens.
- **FR-027**: System MUST create a notification record when a follow-up becomes due and the user has notifications enabled.
- **FR-028**: System MUST attempt push delivery to all active device tokens for the user.
- **FR-029**: System MUST retry failed deliveries up to a configurable limit.
- **FR-030**: System MUST record delivery outcomes (success, failure, error) for each attempt.
- **FR-031**: System MUST expose a notification inbox endpoint for the authenticated user.

#### Settings

- **FR-032**: System MUST create a default settings record for each new user automatically.
- **FR-033**: System MUST allow users to retrieve and update their notification preferences.
- **FR-034**: System MUST allow users to set a default follow-up interval in days.
- **FR-035**: System MUST suppress push notifications for users with notifications disabled.

#### Infrastructure

- **FR-036**: System MUST expose a health check endpoint reporting API and database status.
- **FR-037**: System MUST run as a containerized application with full local development support.
- **FR-038**: Background jobs MUST run as a separate worker process from the same codebase without a message broker.

### Key Entities

- **User**: Registered account with email, password, and soft-delete support.
- **Refresh Token**: Active session token; deleted on logout; expires on a set schedule.
- **Person**: A named contact with optional notes and last interaction date. Syncs with tombstones.
- **Log**: A dated journal entry or interaction record belonging to a user. Syncs with tombstones.
- **Log–Person Link**: Associates a log with one or more persons; updates last interaction date.
- **Follow-up**: A reminder item with due date, recurrence, and lifecycle status. References a log and/or person.
- **Notification**: A stored push notification message in the user's inbox. References a follow-up.
- **Notification Delivery**: Records outcome of each push delivery attempt.
- **Device Token**: Push notification token for a specific device belonging to a user.
- **User Settings**: Per-user preferences (notifications, follow-up defaults).
- **Sync Metadata**: Tracks last sync timestamp per entity type per device per user.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A new user can register, log in, create a log entry linked to a person, and receive a follow-up reminder notification in a single session without manual backend intervention.
- **SC-002**: A record pushed from device A is retrievable on device B after a pull sync with no additional configuration.
- **SC-003**: Follow-up status transitions (pending → due → complete) occur automatically without user-initiated backend calls.
- **SC-004**: A developer with Docker installed can start the full local stack with seed data and a passing test suite in under 5 minutes.
- **SC-005**: All API endpoints enforce per-user data isolation — no user can access another user's records under any condition.
- **SC-006**: Failed push notifications are retried automatically and all delivery outcomes are queryable for debugging.
- **SC-007**: Disabling notifications for a user immediately suppresses all future push deliveries for that user.

---

## Assumptions

- **A-001**: Email/password authentication is sufficient for v1. Social login (OAuth2) is explicitly out of scope.
- **A-002**: The mobile app generates client-side UUIDs for new records; the server accepts these as primary keys.
- **A-003**: DynamoDB-to-PostgreSQL migration is cold: users re-sync from local SQLite on first connection. No automated data migration is needed.
- **A-004**: Push notifications are delivered via FCM/APNs through a managed push gateway; the backend handles scheduling and retry, not guaranteed delivery.
- **A-005**: A single background worker process runs all scheduled jobs. Horizontal scaling of the worker is out of scope for v1.
- **A-006**: Full-text search is handled by the database; no external search service required for v1.
- **A-007**: Inactivity-based follow-ups ("no interaction for 90 days") are a stretch goal; v1 requires only manual and interval-based recurrence.

---

## Out of Scope

- OAuth2 / social login
- Email notifications (push only for v1)
- Multi-tenant or team accounts
- Real-time sync (WebSocket or SSE)
- Event sourcing or audit log
- Horizontal auto-scaling of the worker
- Admin dashboard or back-office tooling
- Data export or GDPR data portability (beyond account deletion)
