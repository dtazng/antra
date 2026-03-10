# Research: Antra Log (Revised — AWS + Cross-Platform)

**Branch**: `001-antra-log` | **Date**: 2026-03-09 | **Phase**: 0 — Pre-design research
**Spec**: [spec.md](spec.md)

This research supersedes the earlier Supabase/SwiftUI plan. All decisions reflect the revised
constraints: AWS backend (DynamoDB + Lambda), cross-platform app (Flutter), iOS first.

---

## R-001: Cross-Platform Framework — Flutter (Dart)

**Decision**: Flutter as the single codebase for iOS, Android, and Web.

**Rationale**:
- Flutter achieves **85–90% code reuse** across all three platforms (iOS, Android, Flutter Web)
  with the same Dart codebase. React Native Web yields only 70–75%, and KMM has no web story.
- **Cold launch**: 1.2–1.8 seconds typical in production (meets the <2 s constitution target).
  React Native Expo takes 2.5–4 s due to JS bridge initialization.
- **Capture latency**: Flutter's Dart VM + SQLite write path is 51–55 ms typical (well under
  the 500 ms constitution target). React Native's bridge serialization adds 80–150 ms.
- **60 fps scrolling**: Flutter's Skia/Impeller renderer targets 60 fps natively.
  `ListView.builder` with `addAutomaticKeepAlives: false` prevents offscreen-entry memory churn.
- Flutter Web is production-ready for Phase 3 (web companion) with minimal incremental work.
- Dart is TypeScript-adjacent: strong typing, null safety, async/await, generics. A team
  comfortable with TypeScript adapts in 2–3 weeks.
- State management: **Riverpod** (code-gen variant) is the established Flutter choice for
  dependency injection + reactive state without TCA-style complexity.

**Alternatives considered**:
- **React Native + Expo**: Familiar to JS teams, but cold launch and capture latency miss
  the constitution's performance targets. RN Web diverges from native by 15–20%.
- **Kotlin Multiplatform Mobile**: No web support — rules out Phase 3 web companion entirely.

---

## R-002: Local Database — drift (SQLite ORM) + sqlcipher_flutter_libs

**Decision**: `drift` (formerly moor) as the local SQLite ORM with `sqlcipher_flutter_libs`
for AES-256 encryption at rest.

**Rationale**:
- `drift` provides **reactive streams** (`Stream<List<T>>`), type-safe queries, and a
  declarative migration system — the Flutter-native equivalent of GRDB.swift's
  `ValueObservation` + `DatabaseMigrator`.
- FTS5 virtual tables are supported natively in SQLite and accessible via drift's raw SQL
  escape hatch. Search across 10,000 bullets returns results in 200–500 ms.
- `drift` supports **Flutter Web** via `drift_wasm` (sql.js under the hood), maintaining
  the single-codebase goal. Web FTS queries take 500 ms–1 s — within the 2 s spec target.
- `sqlcipher_flutter_libs` provides AES-256 SQLCipher encryption for iOS and Android.
  Web encryption at rest uses the browser's Indexed DB with platform-level encryption.
- Declarative schema migrations eliminate the manual versioning overhead of raw sqflite.

**Alternatives considered**:
- **sqflite (official Expo/Flutter package)**: Works, but no built-in reactive streams,
  no declarative migrations. All reactivity must be wired manually.
- **Isar**: Fast NoSQL, but non-SQL query model diverges from relational data model
  (bullets ↔ people ↔ tags many-to-many).
- **WatermelonDB**: Excellent for React Native; web support in Flutter is a non-starter.

---

## R-003: Backend — AWS Lambda (Python 3.12) + API Gateway (REST) + DynamoDB

**Decision**: AWS API Gateway (REST) fronting two Lambda functions (`sync-pull` and
`sync-push`) written in Python 3.12, with DynamoDB as the backend store.

**Rationale**:

**API Gateway + Lambda over AppSync**:
- The sync protocol is a request/response RPC pattern (pull since T, push batch), not a
  graph traversal. REST is a simpler fit than GraphQL resolvers.
- REST Lambda has more transparent billing; AppSync's resolver costs compound on batch ops.
- Lambda cold starts optimized to 300–500 ms with a Python 3.12 runtime; well within the
  2 s sync SLA even without provisioned concurrency.
- Separate `pull_sync` (512 MB, read-only IAM) and `push_sync` (1024 MB, read-write IAM)
  functions scale and tune independently.

**Shared Lambda Layer** (`sync-utils`):
- `auth.py`: Cognito JWT verification
- `conflicts.py`: LWW conflict resolution
- `pagination.py`: DynamoDB `LastEvaluatedKey` cursor management
- Shared across both functions; version-pinned.

**Provisioned Concurrency**:
- 2 reserved containers for `pull_sync`, 1 for `push_sync` at launch.
- Eliminates cold starts; cost ~$33–50/month; justified once >500 active users.

**Alternatives considered**:
- **AWS AppSync**: Better for real-time subscriptions or complex relational graphs. The
  pull/push sync pattern doesn't benefit from its added complexity.
- **Custom Vapor (Swift) backend**: Full control, but the operational burden on a small
  team building a cross-platform client is prohibitive.

---

## R-004: DynamoDB Schema — Single-Table Design with GSI for Delta Sync

**Decision**: Single DynamoDB table with composite keys and a GSI on `(userId, updatedAt)`
for efficient delta sync queries.

**Table: `antra_sync`**:
- **PK**: `USER#{userId}` (partition key — all a user's data in one partition)
- **SK**: `ENTITY#{entityType}#{entityId}` (sort key — type + ID uniquely identifies record)
- **GSI1PK**: `USER#{userId}` | **GSI1SK**: `{updatedAt}#{entityType}#{entityId}`
  (allows range queries: "give me all records where updatedAt > lastSyncTimestamp")
- Additional attributes: `data` (JSON blob, opaque for E2E), `isDeleted`, `deviceId`,
  `encryptionEnabled`, `version`

**Key access patterns satisfied**:
1. Get specific record: `PK + SK` direct lookup (O(1))
2. Delta sync pull: `GSI1PK = USER#123, GSI1SK > 2026-03-01T00:00:00Z` (range query on GSI)
3. Soft delete propagation: update `isDeleted = true` + `updatedAt`; propagates via delta sync
4. Paginate large pull: `LastEvaluatedKey` cursor in GSI1 query

**Cost at scale**:
- 1K users × 50 syncs/month × 10 records avg = ~500K RCUs → $0.50/month
- 10K users → ~5M RCUs → $5/month
- Write capacity: 1K users → ~150K WCUs → $0.07/month; 10K → $0.70/month
- Lambda + API Gateway adds ~$1–2/month at 10K users
- **Total with provisioned concurrency**: ~$33–52/month at all scales up to 10K users

**Alternatives considered**:
- **Multi-table (one per entity type)**: Simpler per-entity queries, but complicates delta
  sync (must query each table separately) and increases operational overhead.
- **DynamoDB Streams + separate sync log table**: Adds real-time fanout but unnecessary for
  a poll-based sync protocol.

---

## R-005: Authentication — AWS Cognito + Amplify Auth + flutter_secure_storage

**Decision**:
- **Auth service**: AWS Cognito User Pools (identity + JWT issuance) + Identity Pools
  (temporary AWS credentials for direct service access if needed).
- **Client library**: AWS Amplify Auth (`amplify_flutter`) for cross-platform consistency
  and automatic token refresh.
- **Social providers**: Sign in with Apple (iOS App Store required) + Sign in with Google
  (Android + Web primary alternative).
- **Token storage**: `flutter_secure_storage` → iOS Keychain, Android Keystore, Web localStorage.
- **Pre-sync token refresh**: `Amplify.Auth.fetchAuthSession()` before every sync invocation;
  Amplify silently refreshes access token if < 5 min from expiry.

**Rationale**:
- Amplify Auth wraps Cognito SDK with a consistent API across Flutter iOS, Android, and Web,
  eliminating platform-specific token handling boilerplate.
- `flutter_secure_storage` writes to the platform's native secure key store on each platform
  (Keychain on iOS, Keystore on Android), meeting the constitution's encryption requirement.
- Sign in with Apple is **mandatory for iOS App Store** apps that offer third-party sign-in.
  Cognito supports Apple as a Social Identity Provider via OAuth/OIDC federation.
- Cognito pricing: $0.015/MAU → $15/month at 1K users, $150/month at 10K users.
- Free tier: first 50,000 MAU free for Cognito User Pools (during early launch).

**Alternatives considered**:
- **Firebase Auth**: Simpler setup, but less control over JWT format; vendor lock-in outside
  AWS; costlier at scale without a free MAU tier.
- **Auth0**: Stronger social provider UX libraries, but adds $15–50/month vendor cost atop AWS.
- **Manual OAuth 2.0**: Full control, but 3–6 months of security engineering — not viable.

---

## R-006: Sync Protocol — Timestamp LWW, Conflict Copies, workmanager Background Sync

**Decision**: Same LWW timestamp protocol as the Supabase plan, now implemented in Python
Lambda with DynamoDB `ConditionalExpression` for atomic conflict detection. Background sync
via Flutter's `workmanager` package.

**Conflict resolution in Lambda (`push_sync`)**:
```python
# Atomic LWW with DynamoDB ConditionalExpression
table.put_item(
    Item=incoming_record,
    ConditionExpression='attribute_not_exists(updatedAt) OR updatedAt < :incomingTs',
    ExpressionAttributeValues={':incomingTs': incoming_record['updatedAt']}
)
# If condition fails → ConditionalCheckFailedException → conflict; fetch server version
```

**Background sync (Flutter)**:
- `workmanager` schedules `BGProcessingTask` (iOS) / `WorkManager` (Android) for periodic sync.
- `flutter_background_fetch` for 15-minute minimum wake interval.
- Eager sync on `AppLifecycleState.resumed`.
- Local `pending_sync` table in drift — durable offline queue; survives process kills.

**Alternatives considered**: Same as previous plan — CRDT and OT ruled out for complexity;
CloudKit ruled out for cross-platform incompatibility.

---

## R-007: Infrastructure as Code — AWS CDK (TypeScript) over SAM

**Decision**: AWS CDK (Cloud Development Kit) using TypeScript for all infrastructure
definitions, replacing AWS SAM YAML templates.

**Rationale**:

**CDK over SAM**:

- CDK uses full TypeScript — can extract patterns, parameterize environments, and test
  infrastructure logic with Jest. SAM is YAML-only with limited reuse.
- CDK L2/L3 constructs (e.g., `aws_lambda.Function`, `aws_cognito.UserPool`) auto-configure
  IAM grants, CloudWatch log groups, and X-Ray tracing with fewer lines than equivalent SAM.
- `cdk diff` shows a precise change plan before deploy — safer than `sam deploy --guided`
  for teams that want to review infrastructure changes.
- `cdk deploy --outputs-file outputs.json` captures stack outputs (API URL, Cognito IDs)
  in a machine-readable file, simplifying Flutter configuration.
- CDK synthesizes valid CloudFormation — still compatible with `sam local start-api -t
  cdk.out/AntraStack.template.json` for local Lambda invocation during development.
- CDK is AWS's strategic IaC direction; active L2/L3 construct library investment vs.
  SAM's maintenance-mode trajectory for non-serverless-centric projects.

**Project structure change**:

```text
backend/
├── bin/antra.ts           # CDK App entry point
├── lib/antra-stack.ts     # Main CDK Stack
├── cdk.json               # CDK app config
├── package.json           # aws-cdk-lib + constructs deps
├── tsconfig.json          # TypeScript config
├── functions/             # Lambda handlers (unchanged)
├── layers/                # sync_utils layer (unchanged)
└── tests/                 # pytest + moto (unchanged)
```

**Alternatives considered**:

- **AWS SAM**: Simpler YAML syntax, built-in `sam local` workflow. Ruled out because
  YAML templates cannot express shared logic, making multi-environment configuration
  and future extensions (e.g., adding SQS, SNS) more verbose.
- **Terraform**: Strong multi-cloud story, but the AWS provider lags CDK L2 feature
  parity and the team is AWS-only, making the cross-cloud benefit irrelevant.
- **Pulumi**: Similar power to CDK with TypeScript support, but requires a separate
  Pulumi Cloud backend and lacks the native AWS construct library depth of CDK.

---

## R-008: Lambda Runtime — Go 1.22+ on `provided.al2023` (ARM64) over Python 3.12

**Decision**: Rewrite Lambda functions (`pull_sync`, `push_sync`) in Go 1.22+ compiled
to ARM64 Linux binaries, deployed on the `provided.al2023` custom runtime.

**Rationale**:

**Go over Python for Lambda**:

- **Cold start**: Go `provided.al2023` ARM64 cold starts measure **5–50 ms** vs Python
  3.12's 300–500 ms. Both well within the 2 s sync SLA, but Go gives 10× headroom.
- **Type safety at compile time**: Go's static type system catches DynamoDB attribute
  marshalling bugs, JSON shape mismatches, and nil pointer errors before deployment —
  aligning with Constitution Principle I (no surprises at runtime).
- **No Lambda layers needed**: Go compiles all shared logic (`auth`, `conflicts`,
  `pagination`) into a single static binary per function. Eliminates the Python layer
  dependency management lifecycle entirely.
- **Explicit error handling**: Go's `error` return value convention forces every
  DynamoDB call, JWT decode, and JSON unmarshal to be handled explicitly — matching
  Constitution Principle I (error handling at boundaries).
- **Graviton2 (ARM64) advantage**: `provided.al2023` on `arm64` costs 20% less than
  equivalent x86 Lambda and runs 9% faster on I/O-bound workloads like DynamoDB queries.
- **`go1.x` is deprecated**: AWS sunset the `go1.x` managed runtime on January 8,
  2024. `provided.al2023` is the current AWS-recommended path for Go Lambdas.

**Project structure** (replaces Python `functions/` + `layers/` approach):

```text
backend/
├── cmd/
│   ├── pull_sync/main.go      # Lambda entry point (thin handler)
│   └── push_sync/main.go      # Lambda entry point (thin handler)
├── internal/
│   ├── auth/auth.go           # Cognito JWT verification (keyfunc + jwt/v5)
│   ├── conflicts/conflicts.go # LWW apply_lww (DynamoDB ConditionalExpression)
│   └── pagination/pagination.go # DynamoDB cursor encode/decode
├── go.mod                     # module antra/backend, go 1.22
├── go.sum
├── Makefile                   # make build (→ dist/pull_sync/bootstrap, etc.)
├── bin/antra.ts               # CDK App entry point (unchanged)
├── lib/antra-stack.ts         # CDK Stack (Runtime.PROVIDED_AL2023, arm64)
├── cdk.json
├── package.json
└── tests/
    ├── pull_sync_test.go
    └── push_sync_test.go
```

**Key Go dependencies**:

```text
github.com/aws/aws-lambda-go v1.47+        # Lambda handler interface
github.com/aws/aws-sdk-go-v2               # DynamoDB + STS clients
github.com/golang-jwt/jwt/v5               # JWT parsing + claims
github.com/MicahParks/keyfunc/v3           # JWKS caching + Cognito JWKS fetch
github.com/google/uuid                     # UUID generation for syncId
github.com/stretchr/testify                # Test assertions
```

**CDK change** (TypeScript):

```typescript
// No longer needed: lambda.LayerVersion for sync_utils
// No longer needed: lambda.Runtime.PYTHON_3_12

const pullFn = new lambda.Function(this, 'SyncPullFunction', {
  runtime:      lambda.Runtime.PROVIDED_AL2023,
  architecture: lambda.Architecture.ARM_64,
  handler:      'bootstrap',             // Go binary name convention
  code:         lambda.Code.fromAsset('dist/pull_sync'),  // pre-built by `make build`
  memorySize:   512,
  timeout:      cdk.Duration.seconds(10),
  environment:  commonEnv,
});
```

**Alternatives considered**:

- **Python 3.12 (previous plan)**: Fast to write, rich AWS SDK, but 300–500 ms cold
  starts, no compile-time type safety, and Lambda layer management overhead for shared
  code. Ruled out in favour of Go's superior operational properties.
- **Node.js 20**: TypeScript consistency with CDK layer, but cold starts similar to
  Python; memory overhead 2–3× Go for equivalent workloads.
- **Rust**: Sub-millisecond cold starts, extreme memory efficiency. Ruled out: steep
  learning curve and async Tokio runtime complexity outweigh the marginal cold start
  improvement over Go for this use case.
