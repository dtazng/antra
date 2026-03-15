# API Contracts: 015-Go Backend

**Base URL**: `/v1`
**Content-Type**: `application/json`
**Auth**: `Authorization: Bearer <access_token>` required on all endpoints except `/health`, `/v1/auth/register`, `/v1/auth/login`, `/v1/auth/refresh`.

**Standard error format**:
```json
{ "error": "ERROR_CODE", "message": "human readable description" }
```

Common error codes: `AUTH_REQUIRED` (401), `EMAIL_TAKEN` (409), `NOT_FOUND` (404), `INVALID_INPUT` (400), `CONFIRMATION_REQUIRED` (400).

---

## Health

### GET /health

No auth. Returns `200` always; `db` field reflects database connectivity.

```json
{ "status": "ok", "db": "ok" }
```

---

## Auth — `/v1/auth`

### POST /v1/auth/register

```json
// Request
{ "email": "user@example.com", "password": "minlength8" }

// 201 Response
{ "access_token": "<jwt>", "refresh_token": "<uuid>", "token_type": "bearer" }

// Errors: 409 EMAIL_TAKEN, 400 INVALID_INPUT (password too short)
```

### POST /v1/auth/login

```json
// Request
{ "email": "user@example.com", "password": "..." }

// 200 Response
{ "access_token": "<jwt>", "refresh_token": "<uuid>", "token_type": "bearer" }

// Errors: 401 AUTH_REQUIRED
```

### POST /v1/auth/refresh

No auth header required.

```json
// Request
{ "refresh_token": "<uuid>" }

// 200 Response
{ "access_token": "<jwt>", "token_type": "bearer" }

// Errors: 401 AUTH_REQUIRED
```

### POST /v1/auth/logout

Auth required.

```json
// Request
{ "refresh_token": "<uuid>" }

// 204 No Content
```

### DELETE /v1/auth/account

Auth required.

```json
// Request
{ "confirm": "DELETE" }

// 200 Response
{ "message": "Account scheduled for deletion" }

// Errors: 400 CONFIRMATION_REQUIRED
```

---

## Persons — `/v1/persons`

**PersonResponse**:
```json
{
  "id": "uuid",
  "name": "Alex Chen",
  "notes": "Met at conference",
  "last_interaction_date": "2026-03-14",
  "created_at": "2026-03-14T10:00:00Z",
  "updated_at": "2026-03-14T10:00:00Z",
  "deleted_at": null
}
```

### GET /v1/persons?limit=50&offset=0
Returns `PersonResponse[]` sorted by name, excluding deleted.

### GET /v1/persons/search?q=text
Returns `PersonResponse[]` via FTS, limit 50.

### GET /v1/persons/{id}
Returns `PersonResponse` or 404.

### POST /v1/persons
```json
// Request
{ "id": "uuid", "name": "Alex Chen", "notes": "optional", "created_at": "2026-03-14T10:00:00Z" }
// 201 Response: PersonResponse
```

### PATCH /v1/persons/{id}
```json
// Request (all optional)
{ "name": "Alex Chen", "notes": "updated" }
// 200 Response: PersonResponse
```

### DELETE /v1/persons/{id}
204 No Content. Soft deletes.

---

## Logs — `/v1/logs`

**LogResponse**:
```json
{
  "id": "uuid",
  "content": "Had coffee with Alex",
  "type": "interaction",
  "status": "open",
  "day_id": "2026-03-14",
  "device_id": "device-abc",
  "created_at": "2026-03-14T10:00:00Z",
  "updated_at": "2026-03-14T10:00:00Z",
  "deleted_at": null
}
```

### GET /v1/logs?limit=50&offset=0
Returns `LogResponse[]` sorted by `day_id DESC`.

### GET /v1/logs/{id}
Returns `LogResponse` or 404.

### POST /v1/logs
```json
// Request
{
  "id": "uuid",
  "content": "Had coffee with Alex",
  "type": "interaction",
  "status": "open",
  "day_id": "2026-03-14",
  "device_id": "device-abc",
  "person_ids": ["person-uuid"],
  "created_at": "2026-03-14T10:00:00Z"
}
// 201 Response: LogResponse
```

### PATCH /v1/logs/{id}
```json
// Request (all optional)
{ "content": "updated", "type": "note", "status": "done", "person_ids": ["uuid"] }
// 200 Response: LogResponse
```

### DELETE /v1/logs/{id}
204 No Content. Soft deletes.

---

## Follow-ups — `/v1/follow-ups`

**FollowUpResponse**:
```json
{
  "id": "uuid",
  "title": "Follow up with Alex",
  "due_date": "2026-03-21",
  "status": "pending",
  "snoozed_until": null,
  "completed_at": null,
  "is_recurring": false,
  "recurrence_interval_days": null,
  "recurrence_type": null,
  "log_id": null,
  "person_id": "uuid-or-null",
  "created_at": "2026-03-14T10:00:00Z",
  "updated_at": "2026-03-14T10:00:00Z",
  "deleted_at": null
}
```

### GET /v1/follow-ups?status=due&limit=50&offset=0
Returns `FollowUpResponse[]` filtered by status.

### GET /v1/follow-ups/{id}
Returns `FollowUpResponse` or 404.

### POST /v1/follow-ups
```json
// Request
{
  "id": "uuid",
  "title": "Follow up with Alex",
  "due_date": "2026-03-21",
  "log_id": null,
  "person_id": "uuid-or-null",
  "is_recurring": false,
  "recurrence_interval_days": null,
  "recurrence_type": null
}
// 201 Response: FollowUpResponse
```

### PATCH /v1/follow-ups/{id}
```json
// Request (all optional)
{ "title": "updated", "due_date": "2026-03-28", "status": "snoozed", "snoozed_until": "2026-03-18" }
// 200 Response: FollowUpResponse
```

### DELETE /v1/follow-ups/{id}
204 No Content.

---

## Notifications — `/v1/notifications`

**NotificationResponse**:
```json
{
  "id": "uuid",
  "title": "Follow up with Alex today",
  "body": "1 follow-up is due",
  "status": "sent",
  "follow_up_id": "uuid-or-null",
  "created_at": "2026-03-14T10:00:00Z"
}
```

### GET /v1/notifications?limit=50&offset=0
Returns `NotificationResponse[]` sorted by `created_at DESC`.

### POST /v1/notifications/{id}/dismiss
```json
// 200 Response: NotificationResponse with status="dismissed"
```

---

## Devices — `/v1/devices`

### POST /v1/devices
```json
// Request
{ "token": "fcm-or-apns-token", "platform": "ios" }
// 201 Response
{ "id": "uuid", "token": "...", "platform": "ios", "is_active": true }
```

### DELETE /v1/devices/{id}
204 No Content. Marks `is_active = false`.

---

## Settings — `/v1/settings`

**SettingsResponse**:
```json
{
  "notifications_enabled": true,
  "default_follow_up_days": 7,
  "inactivity_follow_ups_enabled": false,
  "inactivity_threshold_days": 90
}
```

### GET /v1/settings
Returns `SettingsResponse`.

### PATCH /v1/settings
```json
// Request (all optional)
{ "notifications_enabled": false, "default_follow_up_days": 14 }
// 200 Response: SettingsResponse
```

---

## Sync — `/v1/sync`

### POST /v1/sync/{entity_type}/push

`entity_type` ∈ `persons`, `logs`, `follow_ups`.

```json
// Request
{
  "device_id": "device-abc",
  "changes": [
    {
      "id": "uuid",
      "operation": "upsert",
      "updated_at": "2026-03-14T10:00:00Z",
      "data": { "name": "Alex Chen", "notes": "..." }
    },
    {
      "id": "uuid",
      "operation": "delete",
      "updated_at": "2026-03-14T10:01:00Z",
      "data": null
    }
  ]
}

// 200 Response
{
  "accepted": 2,
  "conflicts": [
    {
      "id": "uuid",
      "reason": "server_newer",
      "server_record": { "id": "...", "updated_at": "...", "deleted_at": null, "data": {...} }
    }
  ],
  "server_timestamp": "2026-03-14T10:02:00Z"
}
```

### GET /v1/sync/{entity_type}/pull?since=ISO8601&limit=200

`since` defaults to epoch for first sync.

```json
// 200 Response
{
  "records": [
    { "id": "uuid", "updated_at": "...", "deleted_at": null, "data": {...} },
    { "id": "uuid", "updated_at": "...", "deleted_at": "2026-03-14T09:00:00Z", "data": null }
  ],
  "next_cursor": null,
  "server_timestamp": "2026-03-14T10:02:00Z"
}
```

Tombstoned records have `deleted_at` set and `data: null`.
