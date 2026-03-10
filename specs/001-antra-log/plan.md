# Implementation Plan: Antra Log — Digital Bullet Journal with Personal CRM

**Branch**: `001-antra-log` | **Date**: 2026-03-09 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/001-antra-log/spec.md`

## Summary

Antra Log is a local-first digital bullet journal with personal CRM built as a Flutter
cross-platform app (iOS primary). All writes persist to an on-device SQLCipher-encrypted
drift database; background sync propagates changes to AWS via two Go Lambda functions
(pull\_sync, push\_sync) fronted by API Gateway and DynamoDB. Conflict resolution uses
Last-Write-Wins with preserved local conflict copies. Infrastructure is defined in
TypeScript via AWS CDK v2. Go replaces Python as the Lambda runtime for type safety,
sub-50 ms cold starts, and no-layer shared code.

---

## Technical Context

**Client language/version**: Dart 3.3+ / Flutter 3.19+

**Backend language/version**: Go 1.22+ (Lambda `provided.al2023`, ARM64 Graviton2)

**Infrastructure**: TypeScript 5.x / AWS CDK v2 (`aws-cdk-lib ^2`, `constructs ^10`)

**Primary client dependencies**:

- `drift ^2.18` + `drift_flutter ^0.2` — SQLite ORM, reactive streams, FTS5
- `sqlcipher_flutter_libs ^0.7` — AES-256 encryption at rest
- `flutter_riverpod ^2.5` + `riverpod_annotation ^2.3` — state management + DI
- `amplify_flutter ^2.0` + `amplify_auth_cognito ^2.0` — Cognito auth client
- `flutter_secure_storage ^9.2` — Keychain / Keystore token + key storage
- `http ^1.2` — API Gateway REST calls
- `workmanager ^0.5` — background sync scheduling
- `flutter_local_notifications ^17.0` — check-in reminder notifications

**Primary backend dependencies**:

- `github.com/aws/aws-lambda-go v1.47+` — Lambda handler interface
- `github.com/aws/aws-sdk-go-v2` — DynamoDB client + expression builder
- `github.com/golang-jwt/jwt/v5` — JWT parsing + claims extraction
- `github.com/MicahParks/keyfunc/v3` — JWKS caching + automatic refresh
- `github.com/google/uuid` — syncId generation
- `github.com/stretchr/testify` — test assertions

**Storage**: SQLite (drift + SQLCipher, on-device) · DynamoDB single-table (cloud sync)

**Auth**: AWS Cognito User Pools · Amplify Auth (client) · Cognito JWT (Lambda)

**Testing**: `flutter test` · Go `testing` + `testify` · interface-based DynamoDB mocks

**Target platform**: iOS 17+ (Phase 1) · Android · Flutter Web (Phase 2/3)

**Performance goals**:

- Cold launch → daily log visible: < 2 s
- Bullet capture → persisted + visible: < 500 ms
- FTS search (10 K entries): < 2 s
- Scroll: 60 fps, no jank
- Lambda cold start: < 50 ms (Go ARM64 `provided.al2023`)
- Memory: < 150 MB during journaling session

**Constraints**: Offline-first (local DB is source of truth) · No silent data loss · AES-256 at rest

**Scale/scope**: 10 K users · 50 syncs/user/month · 500 records/sync batch

---

## Constitution Check

### Principle I — Code Quality

| Gate | Status | Notes |
| ---- | ------ | ----- |
| Single responsibility | ✅ PASS | Each Go `internal/` package has one concern (auth, conflicts, pagination) |
| No dead code | ✅ PASS | Go compiler rejects unused variables; `golangci-lint` enforces on CI |
| Error handling at boundaries | ✅ PASS | All DynamoDB calls, JWT decodes, JSON unmarshals use explicit `error` returns |
| Consistency | ✅ PASS | Go `internal/` packages follow standard layout; CDK stack in single file |

### Principle II — Testing Standards

| Gate | Status | Notes |
| ---- | ------ | ----- |
| Acceptance scenario coverage | ✅ PASS | Go table-driven tests cover pull pagination + push LWW conflict path |
| Offline behavior | ✅ PASS | Flutter drift tests exercise offline write → pending\_sync → reload |
| Independence | ✅ PASS | Go tests inject mock DynamoDB via interface; no shared state |
| Meaningful assertions | ✅ PASS | Tests assert response payloads and DynamoDB item state, not call counts |

### Principle III — UX Consistency

| Gate | Status | Notes |
| ---- | ------ | ----- |
| Capture speed (< 1 s) | ✅ PASS | Write path: drift insert + pending\_sync enqueue; no network on critical path |
| Offline-transparent UX | ✅ PASS | Sync state via `SyncStatusNotifier`; never blocks capture or navigation |
| Destructive actions | ✅ PASS | Soft-delete pattern; conflict copies preserved; no silent removal |
| Empty states | ✅ PASS | Every list screen has a defined empty-state widget |

### Principle IV — Performance

| Gate | Status | Notes |
| ---- | ------ | ----- |
| Launch < 2 s | ✅ PASS | Flutter cold launch 1.2–1.8 s; DB opens in background isolate |
| Capture < 500 ms | ✅ PASS | drift write + pending\_sync: 51–55 ms measured |
| Search < 2 s | ✅ PASS | FTS5 across 10 K entries: 200–500 ms |
| Lambda cold start | ✅ PASS | Go `provided.al2023` ARM64: 5–50 ms vs Python 300–500 ms |

### Privacy & Data Integrity

| Gate | Status | Notes |
| ---- | ------ | ----- |
| Encryption at rest | ✅ PASS | SQLCipher AES-256; key in platform Keychain/Keystore |
| No silent data loss | ✅ PASS | LWW conflict copies written to `conflict_records` before local overwrite |
| E2E encryption (Pro) | ✅ PASS | `encryptionEnabled` flag on records; Pro-tier AES-GCM before push |
| No telemetry | ✅ PASS | No analytics SDK; no opt-out needed |

---

## Phase 0: Research Summary

All technical unknowns resolved. See [research.md](research.md).

| Ref | Decision |
| --- | -------- |
| R-001 | Flutter (Dart) for cross-platform client — 85–90% code reuse, 60 fps |
| R-002 | drift + sqlcipher\_flutter\_libs — reactive SQLite ORM with AES-256 |
| R-003 | AWS API Gateway REST + Lambda — pull/push RPC sync pattern |
| R-004 | DynamoDB single-table, GSI1 on (userId, updatedAt) for delta sync |
| R-005 | AWS Cognito + Amplify Auth + flutter\_secure\_storage |
| R-006 | LWW timestamp conflicts via DynamoDB ConditionalExpression + workmanager |
| R-007 | AWS CDK v2 (TypeScript) over SAM — full TypeScript, L2 constructs, cdk diff |
| R-008 | **Go 1.22+ on `provided.al2023` ARM64** — replaces Python 3.12 Lambda |

---

## Phase 1: Data Model & Contracts

See [data-model.md](data-model.md) and [contracts/sync-api.md](contracts/sync-api.md).

### Local drift schema (10 tables)

| Table | Purpose |
| ----- | ------- |
| `day_logs` | Container for bullets per calendar date |
| `bullets` | Atomic log entries (task / note / event) |
| `people` | CRM profiles |
| `tags` | Implicit labels created on first use |
| `bullet_person_links` | M:M junction (bullets ↔ people) |
| `bullet_tag_links` | M:M junction (bullets ↔ tags) |
| `collections` | Named dynamic filter views |
| `reviews` | Weekly / monthly reflection records |
| `pending_sync` | Durable offline queue (survives process kill) |
| `conflict_records` | Losing version of every LWW conflict (local audit log only) |

**FTS5 virtual tables** (created in `MigrationStrategy.onCreate`):

- `bullets_fts` — `MATCH` queries over `bullets.content`
- `people_fts` — `MATCH` queries over `people.name` + `people.notes`

### DynamoDB single-table design

```text
PK: USER#{userId}
SK: ENTITY#{entityType}#{entityId}
GSI1PK: userId  |  GSI1SK: updatedAt#{entityType}#{entityId}
```

---

## Phase 2: Application Architecture

### Flutter app structure

```text
app/lib/
├── main.dart                    # ProviderScope · Amplify init · auth gate · lifecycle observer
├── config.dart                  # AppConfig — dart-define constants (API URL, Cognito IDs)
├── database/
│   ├── app_database.dart        # @DriftDatabase · SQLCipher · FTS5 migrations · WAL mode
│   ├── tables/                  # 10 drift table definitions
│   └── daos/
│       ├── bullets_dao.dart     # CRUD + tag parsing + FTS search methods
│       ├── people_dao.dart      # CRUD + bullet_person_links + @mention support
│       ├── sync_dao.dart        # pending_sync queue management
│       ├── collections_dao.dart # collection CRUD
│       └── reviews_dao.dart     # review CRUD + period queries
├── services/
│   ├── api_client.dart          # HTTP POST /sync/pull + /sync/push
│   ├── sync_engine.dart         # Pull loop (pagination) + push batch + conflict recording
│   ├── sync_queue_manager.dart  # pending_sync drain/confirm/fail
│   └── reminder_service.dart    # flutter_local_notifications scheduling
├── providers/
│   ├── database_provider.dart   # @Riverpod AppDatabase (SQLCipher key from secure storage)
│   ├── bullets_provider.dart    # Stream<List<Bullet>> for date
│   ├── people_provider.dart     # Stream<List<Person>> · Stream<List<Bullet>> per person
│   ├── search_provider.dart     # SearchNotifier (FTS + filter composition + debounce)
│   ├── collections_provider.dart
│   ├── reviews_provider.dart
│   ├── sync_status_provider.dart # SyncStatusNotifier (idle/syncing/error + conflictCount)
│   └── reminder_provider.dart
└── screens/
    ├── root_tab_screen.dart      # 5-tab NavigationBar scaffold
    ├── auth/sign_in_screen.dart  # Amplify email/password sign-in + sign-up
    ├── daily_log/daily_log_screen.dart
    ├── people/people_screen.dart + person_profile_screen.dart + create_person_sheet.dart
    ├── collections/collections_screen.dart + collection_detail_screen.dart
    ├── search/search_screen.dart
    └── review/review_screen.dart
```

### AWS backend structure (Go)

```text
backend/
├── cmd/
│   ├── pull_sync/main.go        # Lambda entry point — calls internal/handler
│   └── push_sync/main.go        # Lambda entry point — calls internal/handler
├── internal/
│   ├── auth/auth.go             # verify_cognito_jwt → keyfunc + jwt/v5 + JWKS cache
│   ├── conflicts/conflicts.go   # ApplyLWW → DynamoDB PutItem + ConditionalExpression
│   └── pagination/pagination.go # EncodeCursor / DecodeCursor (base64 JSON)
├── go.mod                       # module antra/backend · go 1.22
├── go.sum
├── Makefile                     # make build → dist/pull_sync/bootstrap + dist/push_sync/bootstrap
├── bin/antra.ts                 # CDK App entry point (TypeScript)
├── lib/antra-stack.ts           # CDK Stack — Runtime.PROVIDED_AL2023, Architecture.ARM_64
├── cdk.json
├── package.json                 # aws-cdk-lib ^2, constructs ^10
├── tsconfig.json
└── tests/
    ├── pull_sync_test.go         # Table-driven: delta query, pagination, 401
    └── push_sync_test.go         # Table-driven: create, conflict, batch limit 401
```

### Sync protocol (sequence)

```text
App resume / workmanager wake
  └─► SyncEngine.sync()
        ├─► Pull loop
        │     ├── ApiClient.pull(lastSyncTimestamp, cursor?)
        │     │     └── Go pull_sync: GSI1 query → records + nextCursor
        │     ├── Apply each record to local drift (upsert)
        │     └── Repeat until hasMore=false; save serverTimestamp
        └─► Push batch
              ├── SyncQueueManager.drainQueue() → pending_sync rows
              ├── ApiClient.push(records)
              │     └── Go push_sync: ApplyLWW per record
              │           ├── No conflict → applied; syncId returned
              │           └── Conflict → (clientItem, serverItem) returned
              ├── On conflict: write to conflict_records; upsert server version locally
              └── SyncQueueManager.confirmSynced(appliedIds)
```

---

## Phase 3: Sync Infrastructure Detail

### Go Lambda — `pull_sync`

```text
POST /sync/pull
  Auth: verify_cognito_jwt(header) → userId
  Body: { lastSyncTimestamp, cursor? }
  DynamoDB: GSI1 query (userId = :uid AND updatedAt > :ts, Limit=500)
  Response: { records[], serverTimestamp, hasMore, nextCursor }
```

Handler: `cmd/pull_sync/main.go` → `internal/auth` + `internal/pagination`
Memory: 512 MB · Timeout: 10 s · IAM: `dynamodb:Query` on GSI1

### Go Lambda — `push_sync`

```text
POST /sync/push
  Auth: verify_cognito_jwt(header) → userId
  Body: { records[] } (max 500)
  Per record: internal/conflicts.ApplyLWW(pk, sk, item)
    Condition: attribute_not_exists(updatedAt) OR updatedAt < :ts
    Conflict: fetch server item → return (clientItem, serverItem)
  Response: { appliedCount, conflicts[], syncIds{} }
```

Handler: `cmd/push_sync/main.go` → `internal/auth` + `internal/conflicts`
Memory: 1024 MB · Timeout: 10 s · IAM: `dynamodb:PutItem`, `dynamodb:GetItem`

### CDK stack key changes (Go migration)

- **Removed**: `lambda.LayerVersion` for `sync_utils` (no layers needed in Go)
- **Removed**: `lambda.Runtime.PYTHON_3_12`
- **Added**: `lambda.Runtime.PROVIDED_AL2023` + `lambda.Architecture.ARM_64`
- **Added**: `Code.fromAsset('dist/pull_sync')` referencing pre-built `bootstrap` binary
- **Build step**: `make build` must run before `cdk deploy`

---

## Risk Register

| Risk | Likelihood | Impact | Mitigation |
| ---- | ---------- | ------ | ---------- |
| Go `provided.al2023` cold start regression | Low | Medium | Benchmark with `aws lambda invoke`; add provisioned concurrency at >500 DAU |
| `make build` forgotten before `cdk deploy` | Medium | High | Add pre-deploy check in CDK (`BundlingOptions` custom command or Makefile guard) |
| Keyfunc JWKS cache stale on key rotation | Low | High | keyfunc auto-refreshes on unknown `kid`; fallback: `RefreshInterval: 1h` |
| DynamoDB ConditionalExpression clock skew | Low | High | Devices must be NTP-synced; Lambda uses AWS time (always authoritative) |
| CDK bootstrap not run in new account | Low | Medium | Document in quickstart; CI checks `aws cloudformation describe-stacks AntraCDKToolkit` |
| Flutter cold launch > 2 s on older devices | Low | High | Open DB in `driftDatabase` background isolate; warm Riverpod providers lazily |

---

## Complexity Tracking

| Item | Complexity | Justification |
| ---- | ---------- | ------------- |
| Go Lambda (vs Python) | Medium | Type safety + cold start + no layers outweigh Go learning curve |
| drift FTS5 + triggers | Medium | Required for < 2 s search over 10 K entries; SQL escape hatch is stable |
| DynamoDB LWW ConditionalExpression | Medium | Atomic conflict detection without transactions; only viable approach at scale |
| AWS CDK v2 (TypeScript) | Low–Medium | CDK L2 constructs reduce IAM boilerplate vs SAM; `cdk diff` prevents surprises |
| SQLCipher key management | Low | `flutter_secure_storage` abstracts Keychain/Keystore; one key per install |
| Riverpod code-gen providers | Low | Eliminates manual `Provider` wiring; standard Flutter pattern |
