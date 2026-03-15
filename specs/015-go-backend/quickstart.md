# Quickstart: 015-Go Backend

**Date**: 2026-03-15

---

## Prerequisites

- Docker Desktop installed and running
- `cd server/` (new Go backend directory)

---

## Start the full stack

```bash
# Copy env template
cp .env.example .env

# Start DB, API server, worker
docker compose up --build

# Apply migrations (in another terminal)
make migrate-up
# or: docker compose exec api goose -dir ./migrations postgres "$DATABASE_URL" up

# Load seed data
make seed
# or: docker compose exec api ./antra seed

# Verify health
curl http://localhost:8000/health
# → {"status":"ok","db":"ok"}
```

---

## Makefile commands

```bash
make run        # Start API server locally (requires local PG)
make worker     # Start worker process locally
make migrate-up # Apply all pending migrations
make migrate-down # Roll back last migration
make seed       # Load seed data
make test       # Run all tests
make build      # Build binary
make sqlc       # Regenerate sqlc query code
make lint       # Run golangci-lint
```

---

## Integration Scenarios

### Scenario 1: Register and login

```bash
# Register
curl -s -X POST http://localhost:8000/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"me@example.com","password":"password123"}' | jq .

# → {"access_token":"<jwt>","refresh_token":"<uuid>","token_type":"bearer"}

export TOKEN="<access_token>"
export REFRESH="<refresh_token>"
```

---

### Scenario 2: Refresh token

```bash
curl -s -X POST http://localhost:8000/v1/auth/refresh \
  -H "Content-Type: application/json" \
  -d "{\"refresh_token\":\"$REFRESH\"}" | jq .

# → {"access_token":"<new_jwt>","token_type":"bearer"}
```

---

### Scenario 3: Create a person

```bash
curl -s -X POST http://localhost:8000/v1/persons \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"id":"11111111-1111-1111-1111-111111111111","name":"Alex Chen","notes":"Met at conference"}' | jq .
```

---

### Scenario 4: Create a log linked to a person

```bash
curl -s -X POST http://localhost:8000/v1/logs \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "id":"22222222-2222-2222-2222-222222222222",
    "content":"Had coffee with Alex",
    "type":"interaction",
    "status":"open",
    "day_id":"2026-03-15",
    "device_id":"dev-local",
    "person_ids":["11111111-1111-1111-1111-111111111111"]
  }' | jq .
```

---

### Scenario 5: Push sync (persons)

```bash
curl -s -X POST http://localhost:8000/v1/sync/persons/push \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "device_id":"iphone-1",
    "changes":[{
      "id":"33333333-3333-3333-3333-333333333333",
      "operation":"upsert",
      "updated_at":"2026-03-15T10:00:00Z",
      "data":{"name":"Jordan Lee","notes":"Investor"}
    }]
  }' | jq .
# → {"accepted":1,"conflicts":[],"server_timestamp":"..."}
```

---

### Scenario 6: Pull sync since timestamp

```bash
curl -s "http://localhost:8000/v1/sync/persons/pull?since=2026-03-15T09:00:00Z" \
  -H "Authorization: Bearer $TOKEN" | jq .
# → {"records":[...],"next_cursor":null,"server_timestamp":"..."}
```

---

### Scenario 7: Sync conflict

```bash
# Push an old version of a record the server already has newer
curl -s -X POST http://localhost:8000/v1/sync/persons/push \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "device_id":"old-device",
    "changes":[{
      "id":"11111111-1111-1111-1111-111111111111",
      "operation":"upsert",
      "updated_at":"2020-01-01T00:00:00Z",
      "data":{"name":"Stale Name"}
    }]
  }' | jq .
# → {"accepted":0,"conflicts":[{"id":"...","reason":"server_newer","server_record":{...}}],...}
```

---

### Scenario 8: Create a past-due follow-up and trigger job

```bash
# Create follow-up due yesterday
curl -s -X POST http://localhost:8000/v1/follow-ups \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "id":"44444444-4444-4444-4444-444444444444",
    "title":"Follow up with Alex about contract",
    "due_date":"2026-03-14",
    "person_id":"11111111-1111-1111-1111-111111111111"
  }' | jq .

# Trigger worker job manually
docker compose exec worker ./antra run-job check-due-follow-ups

# List due follow-ups
curl -s "http://localhost:8000/v1/follow-ups?status=due" \
  -H "Authorization: Bearer $TOKEN" | jq .
```

---

### Scenario 9: Register a device token

```bash
curl -s -X POST http://localhost:8000/v1/devices \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"token":"fake-device-token","platform":"ios"}' | jq .
```

---

### Scenario 10: Notification inbox

```bash
curl -s http://localhost:8000/v1/notifications \
  -H "Authorization: Bearer $TOKEN" | jq .
```

---

### Scenario 11: Get and update settings

```bash
# Get
curl -s http://localhost:8000/v1/settings \
  -H "Authorization: Bearer $TOKEN" | jq .

# Disable notifications
curl -s -X PATCH http://localhost:8000/v1/settings \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"notifications_enabled":false}' | jq .
```

---

### Scenario 12: Logout

```bash
curl -s -X POST http://localhost:8000/v1/auth/logout \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"refresh_token\":\"$REFRESH\"}"
# → 204 No Content

# Verify token rejected
curl -s -X POST http://localhost:8000/v1/auth/refresh \
  -H "Content-Type: application/json" \
  -d "{\"refresh_token\":\"$REFRESH\"}" | jq .
# → {"error":"AUTH_REQUIRED","message":"..."}
```
