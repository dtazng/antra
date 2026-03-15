# Tasks: Go Containerized Backend with PostgreSQL

**Input**: Design documents from `/specs/015-go-backend/`
**Prerequisites**: plan.md ✅ spec.md ✅ research.md ✅ data-model.md ✅ contracts/ ✅ quickstart.md ✅

**Organization**: Tasks grouped by user story for independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this belongs to (US1–US6)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Initialize the Go project, Docker configuration, and developer tooling.

- [X] T001 Create server/ directory tree per plan.md structure (cmd/api, cmd/worker, internal/*, tests/*)
- [X] T002 Initialize Go module in server/ with `go mod init` and add all dependencies to go.mod
- [X] T003 [P] Create server/sqlc.yaml with pgx/v5 driver, schema path internal/db/migrations, queries path internal/db/queries, output internal/db/sqlc
- [X] T004 [P] Create server/Makefile with targets: run, worker, build, test, migrate-up, migrate-down, seed, sqlc, lint
- [X] T005 [P] Create server/Dockerfile with multi-stage build (builder + distroless/scratch runtime, single binary ./antra)
- [X] T006 [P] Create server/docker-compose.yml with db (postgres:16-alpine), api, worker services
- [X] T007 [P] Create server/docker-compose.override.yml with hot-reload via air for local dev
- [X] T008 [P] Create server/.env.example with DATABASE_URL, JWT_SECRET_KEY, JWT_ACCESS_EXPIRE_MINUTES, JWT_REFRESH_EXPIRE_DAYS, FIREBASE_CREDENTIALS_JSON, ENVIRONMENT

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure shared by all user stories — config, DB pool, sqlc models, migration, HTTP skeleton, middleware.

**⚠️ CRITICAL**: No user story work begins until this phase is complete.

- [X] T009 Create server/internal/config/config.go — Config struct with fields loaded from os.Getenv (DatabaseURL, JWTSecretKey, AccessExpireMinutes, RefreshExpireDays, FirebaseCredentialsJSON, Environment) and a Load() constructor
- [X] T010 Create server/internal/db/pool.go — pgx/v5 pool factory: NewPool(ctx, databaseURL) returning *pgxpool.Pool with connect/ping
- [X] T011 Create server/internal/db/migrations/00001_initial_schema.sql — goose migration creating all 11 tables (users, refresh_tokens, persons, logs, log_person_links, follow_ups, notifications, notification_deliveries, device_tokens, user_settings, sync_metadata) with indexes and generated tsvector columns per data-model.md
- [X] T012 Create server/internal/db/queries/users.sql — sqlc queries: GetUserByEmail, CreateUser, SoftDeleteUser, GetUserByID
- [X] T013 [P] Create server/internal/db/queries/persons.sql — sqlc queries: UpsertPerson, SoftDeletePerson, GetPersonsByUpdatedSince, ListPersons, SearchPersons, GetPersonByID
- [X] T014 [P] Create server/internal/db/queries/logs.sql — sqlc queries: UpsertLog, SoftDeleteLog, GetLogsByUpdatedSince, ListLogs, GetLogByID
- [X] T015 [P] Create server/internal/db/queries/follow_ups.sql — sqlc queries: UpsertFollowUp, SoftDeleteFollowUp, GetFollowUpsByUpdatedSince, ListFollowUps, GetFollowUpByID, MarkFollowUpsDue, GetDueFollowUps
- [X] T016 [P] Create server/internal/db/queries/notifications.sql — sqlc queries: CreateNotification, GetPendingNotifications, GetNotificationsByUser, UpdateNotificationStatus
- [X] T017 [P] Create server/internal/db/queries/devices.sql — sqlc queries: UpsertDeviceToken, DeactivateDeviceToken, GetActiveDeviceTokens
- [X] T018 [P] Create server/internal/db/queries/settings.sql — sqlc queries: GetOrCreateUserSettings, UpdateUserSettings
- [X] T019 [P] Create server/internal/db/queries/sync.sql — sqlc queries: UpsertSyncMetadata, ReplaceLogPersonLinks, CreateDeliveryRecord
- [X] T020 Run `sqlc generate` to produce server/internal/db/sqlc/*.go (db.go, models.go, *.sql.go)
- [X] T021 Create server/internal/token/jwt.go — CreateAccessToken(userID, secret, expireMinutes), ParseAccessToken(token, secret), HashPassword(plain), VerifyPassword(plain, hash) using golang-jwt/jwt v5 and argon2id
- [X] T022 Create server/internal/api/middleware/auth.go — BearerAuth middleware: extract Authorization header, ParseAccessToken, inject userID uuid into chi context
- [X] T023 Create server/internal/api/middleware/logger.go — structured slog request/response logger middleware
- [X] T024 Create server/internal/api/v1/router.go — chi router with /health, /v1 sub-router, middleware stack (logger, auth on protected routes), mount all v1 handler groups
- [X] T025 Create server/cmd/api/main.go — load Config, create pgxpool, create chi router, start HTTP server with graceful shutdown on SIGTERM/SIGINT
- [X] T026 Create server/cmd/worker/main.go — load Config, create pgxpool, create robfig/cron scheduler, register jobs, start, graceful shutdown on SIGTERM/SIGINT

**Checkpoint**: `docker compose up` → `make migrate-up` → `GET /health` returns `{"status":"ok","db":"ok"}`

---

## Phase 3: US1 — Secure Account Access (Priority: P1) 🎯 MVP

**Goal**: Users can register, log in, refresh tokens, and log out. All subsequent endpoints are protected.

**Independent Test**: Register → login → refresh → logout → confirm refresh rejected (401).

- [X] T027 [US1] Create server/internal/db/queries/refresh_tokens.sql — sqlc queries: CreateRefreshToken, GetRefreshToken, DeleteRefreshToken, DeleteExpiredTokens
- [X] T028 [US1] Run `sqlc generate` to add refresh_token queries to server/internal/db/sqlc/
- [X] T029 [US1] Create server/internal/service/auth.go — Register(email, password), Login(email, password), Refresh(tokenID), Logout(tokenID, userID), DeleteAccount(userID) using sqlc Queries and token package
- [X] T030 [US1] Create server/internal/api/v1/auth.go — chi handlers: POST /auth/register (201), POST /auth/login (200), POST /auth/refresh (200), POST /auth/logout (204), DELETE /auth/account (200); wire to auth service
- [X] T031 [US1] Create server/tests/integration/auth_test.go — integration tests covering all 6 acceptance scenarios from spec.md US1 using testcontainers-go
- [X] T032 [US1] Create server/tests/testutil/db.go — testcontainers-go helper: spin up postgres:16, run goose migrations, return *pgxpool.Pool; teardown after test

---

## Phase 4: US2 — Offline-First Data Sync (Priority: P2)

**Goal**: Clients can push/pull persons, logs, and follow_ups with LWW conflict resolution.

**Independent Test**: Push persons from device A, pull on device B, confirm records appear. Push old updated_at → get conflict response.

- [X] T033 [P] [US2] Create server/internal/service/person.go — SyncUpsert(userID, id, data, clientUpdatedAt), SyncDelete(userID, id, clientUpdatedAt), Pull(userID, since, limit), List(userID, limit, offset), Search(userID, q), Get(userID, id), Create(userID, req), Update(userID, id, req), Delete(userID, id)
- [X] T034 [P] [US2] Create server/internal/service/log.go — SyncUpsert, SyncDelete, Pull, List, Get, Create (with person link replacement), Update, Delete
- [X] T035 [P] [US2] Create server/internal/service/follow_up.go — SyncUpsert, SyncDelete, Pull, List, Get, Create, Update (status transitions), Delete
- [X] T036 [US2] Create server/internal/service/sync.go — Push(userID, entityType, changes, deviceID) orchestrating per-entity service calls; Pull(userID, entityType, since, limit); UpsertSyncMetadata after each push
- [X] T037 [US2] Create server/internal/api/v1/sync.go — chi handlers: POST /sync/{entityType}/push, GET /sync/{entityType}/pull; validate entityType ∈ {persons, logs, follow_ups}; wire to sync service
- [X] T038 [P] [US2] Create server/internal/api/v1/persons.go — chi handlers: GET /persons, GET /persons/search, GET /persons/{id}, POST /persons (201), PATCH /persons/{id}, DELETE /persons/{id}
- [X] T039 [P] [US2] Create server/internal/api/v1/logs.go — chi handlers: GET /logs, GET /logs/{id}, POST /logs (201), PATCH /logs/{id}, DELETE /logs/{id}
- [X] T040 [US2] Create server/tests/integration/sync_test.go — integration tests for all 5 sync acceptance scenarios from spec.md US2 (push, conflict, pull since, tombstone, first sync/epoch)

---

## Phase 5: US3 — Follow-up Scheduling (Priority: P3)

**Goal**: Background job marks follow-ups as due; users can snooze/complete/dismiss; recurring follow-ups reschedule.

**Independent Test**: Create past-due follow-up → run job → GET /follow-ups?status=due confirms it appears. Complete recurring follow-up → new one created.

- [X] T041 [US3] Create server/internal/worker/follow_up_job.go — CheckDueFollowUps(db *sqlc.Queries): run MarkFollowUpsDue SQL, for each newly-due follow-up check user notifications_enabled, INSERT notification; handle recurring completion (INSERT next follow_up with due_date + recurrence_interval_days)
- [X] T042 [US3] Create server/internal/api/v1/follow_ups.go — chi handlers: GET /follow-ups?status=, GET /follow-ups/{id}, POST /follow-ups (201), PATCH /follow-ups/{id} (handles snooze/complete/dismiss transitions), DELETE /follow-ups/{id}
- [X] T043 [US3] Create server/tests/integration/follow_up_test.go — integration tests for all 5 acceptance scenarios from spec.md US3 (status=due after job, snooze, complete, recurring reschedule, notification creation trigger)

---

## Phase 6: US4 — Push Notifications (Priority: P4)

**Goal**: Firebase-admin-go sends push to registered devices; delivery tracked; inbox API accessible.

**Independent Test**: Register device, create past-due follow-up, run notification job, confirm notification delivery record exists and status=sent. GET /notifications returns inbox.

- [X] T044 [US4] Create server/internal/push/firebase.go — FirebaseClient wrapper: NewFirebaseClient(credentialsJSON), SendToTokens(tokens []string, title, body string) returning (sent int, failures []DeliveryResult); graceful no-op if credentials not set
- [X] T045 [US4] Create server/internal/worker/notification_job.go — DispatchNotifications(db, pushClient): query pending/retry-eligible notifications, fetch active device tokens per user, call pushClient.SendToTokens, INSERT delivery records, UPDATE notification status (sent/failed), increment retry_count
- [X] T046 [US4] Create server/internal/service/notification.go — List(userID, limit, offset), Dismiss(userID, notificationID)
- [X] T047 [US4] Create server/internal/api/v1/notifications.go — chi handlers: GET /notifications, POST /notifications/{id}/dismiss
- [X] T048 [US4] Wire follow_up_job.go and notification_job.go into server/internal/worker/scheduler.go with @every 5m intervals
- [X] T049 [US4] Create server/tests/integration/notification_test.go — integration tests for all 4 acceptance scenarios from spec.md US4 (notification created on due follow-up, retry on failure, inbox API, notifications suppressed when disabled)

---

## Phase 7: US5 — User Settings (Priority: P5)

**Goal**: Users can retrieve and update notification preferences and follow-up defaults.

**Independent Test**: GET /settings → PATCH notifications_enabled=false → run notification job → confirm no new notifications for that user.

- [X] T050 [P] [US5] Create server/internal/service/settings.go — Get(userID) returning UserSettings (create default if missing), Update(userID, patch)
- [X] T051 [P] [US5] Create server/internal/service/device.go — Register(userID, token, platform), Deactivate(userID, deviceID)
- [X] T052 [US5] Create server/internal/api/v1/settings.go — chi handlers: GET /settings, PATCH /settings
- [X] T053 [P] [US5] Create server/internal/api/v1/devices.go — chi handlers: POST /devices (201), DELETE /devices/{id}

---

## Phase 8: US6 — Local Development Environment (Priority: P6)

**Goal**: Developer can cold-start the full stack, run migrations, load seed data, and run all tests in under 5 minutes.

**Independent Test**: `docker compose up` → `make migrate-up` → `make seed` → `GET /health` → `make test` all pass.

- [X] T054 [US6] Create server/cmd/api/seed.go (or server/internal/seed/seed.go) — seed function: INSERT 1 user (seed@example.com / password123), 2 persons, 3 logs, 1 follow-up due yesterday; idempotent (upsert)
- [X] T055 [US6] Add `seed` make target to server/Makefile invoking `./antra seed` inside docker compose exec api
- [X] T056 [US6] Verify docker-compose.yml healthcheck on db service; verify api and worker depend_on db condition: service_healthy
- [X] T057 [US6] Create server/tests/testutil/db.go (if not already created in T032) — testcontainers-go PG helper used by all integration test files

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Wire everything together, validate full stack, update documentation.

- [X] T058 Verify server/internal/api/v1/router.go mounts all handler groups (auth, persons, logs, follow_ups, notifications, devices, settings, sync) and confirm all routes match api-contracts.md
- [X] T059 Add structured slog JSON logging to all service errors and worker job runs (startup, job start/end, error counts)
- [X] T060 Update CLAUDE.md Active Technologies section to include Go 1.23+, chi v5, pgx/v5, sqlc, goose, golang-jwt, argon2id, robfig/cron, firebase-admin-go
- [X] T061 Run `go build ./...` and `go vet ./...` — fix all errors and vet warnings
- [X] T062 Run `make test` — confirm all integration tests pass against testcontainers-go PostgreSQL instance

---

## Dependencies

```
Phase 1 (Setup)
    └── Phase 2 (Foundational — config, pool, migration, sqlc, middleware, router, main)
            ├── Phase 3 (US1 Auth) ← MVP deployable after this
            │       └── Phase 4 (US2 Sync — depends on auth middleware)
            │               └── Phase 5 (US3 Follow-ups — uses sync models)
            │                       └── Phase 6 (US4 Notifications — uses follow-ups)
            ├── Phase 7 (US5 Settings — independent after Phase 2)
            └── Phase 8 (US6 Local Dev — independent, validates full stack)
                        └── Phase 9 (Polish)
```

US5 (Settings) and US6 (Local Dev) are independent of US2–US4 and can be implemented in parallel with those phases.

---

## Parallel Execution Opportunities

**Phase 1**: T003–T008 all parallelizable (separate config files).

**Phase 2**: T013–T019 all parallelizable (separate SQL query files). T020 (sqlc generate) depends on T012–T019. T022–T024 parallelizable after T021.

**Phase 4 (US2)**: T033–T035 (person/log/follow_up services) parallelizable. T038–T039 (person/log handlers) parallelizable after services.

**Phase 7 (US5)**: T050–T051 (settings/device services) parallelizable. T052–T053 (handlers) parallelizable after services.

---

## Implementation Strategy (MVP First)

**MVP (Phases 1–3, T001–T032)**: Working authenticated API deployed to local Docker. Mobile app can register, login, and refresh tokens. Foundation for all other features.

**Increment 2 (Phase 4, T033–T040)**: Full sync — mobile app can push/pull persons, logs, and follow-ups.

**Increment 3 (Phases 5–6, T041–T049)**: Follow-up scheduling and push notifications — the CRM's core value proposition is complete.

**Increment 4 (Phases 7–8, T050–T057)**: Settings and polished local dev experience.

**Final (Phase 9, T058–T062)**: Wire, vet, test, document.

---

## Independent Test Criteria Per Story

| Story | Independent Test |
|-------|-----------------|
| US1 Auth | Register → login → refresh → logout → verify refresh rejected (401) |
| US2 Sync | Push persons from device A → pull on device B → confirm records. Push old updated_at → get conflict. |
| US3 Follow-ups | Create past-due follow-up → run job → GET ?status=due confirms it. Complete recurring → new one created. |
| US4 Notifications | Register device → create past-due follow-up → run jobs → confirm delivery record exists. GET /notifications returns inbox. |
| US5 Settings | GET /settings → PATCH notifications_enabled=false → run job → no new notifications for user. |
| US6 Local Dev | docker compose up → make migrate-up → make seed → GET /health ok → make test passes. |
