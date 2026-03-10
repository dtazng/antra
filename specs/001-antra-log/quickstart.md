# Quickstart: Antra Log (Flutter + AWS Go Backend)

**Branch**: `001-antra-log` | **Date**: 2026-03-09

Development environment setup and end-to-end validation guide.

---

## Prerequisites

| Tool | Version | Purpose |
| ---- | ------- | ------- |
| Flutter SDK | 3.19+ | Cross-platform framework |
| Dart | 3.3+ | Language |
| Xcode | 16.0+ | iOS simulator + signing |
| Android Studio | 2024.1+ | Android emulator (Phase 2) |
| Go | 1.22+ | Lambda function runtime |
| AWS CLI | 2.x | AWS service management |
| Node.js | 20+ | CDK CLI runtime |
| AWS CDK CLI | 2.x | Infrastructure deploy (`npm i -g aws-cdk`) |
| AWS SAM CLI | 1.x | Local Lambda invocation (optional, via CDK synth output) |

---

## Project Structure

```text
antra/
├── app/                          # Flutter cross-platform application
│   ├── lib/
│   │   ├── main.dart             # Entry point; Amplify init, Riverpod scope
│   │   ├── database/
│   │   │   ├── app_database.dart # drift DatabaseConnection setup + SQLCipher
│   │   │   ├── tables/           # drift @DataClassName table definitions
│   │   │   │   ├── bullets.dart
│   │   │   │   ├── people.dart
│   │   │   │   ├── day_logs.dart
│   │   │   │   ├── tags.dart
│   │   │   │   ├── collections.dart
│   │   │   │   ├── reviews.dart
│   │   │   │   ├── pending_sync.dart
│   │   │   │   └── conflict_records.dart
│   │   │   └── daos/             # drift Data Access Objects
│   │   │       ├── bullets_dao.dart
│   │   │       ├── people_dao.dart
│   │   │       └── sync_dao.dart
│   │   ├── services/
│   │   │   ├── sync_engine.dart          # Orchestrates pull + push
│   │   │   ├── sync_queue_manager.dart   # pending_sync CRUD
│   │   │   └── api_client.dart           # HTTP calls to API Gateway
│   │   ├── providers/                    # Riverpod providers
│   │   │   ├── database_provider.dart
│   │   │   ├── sync_status_provider.dart
│   │   │   ├── bullets_provider.dart
│   │   │   ├── people_provider.dart
│   │   │   └── search_provider.dart
│   │   └── screens/
│   │       ├── root_tab_screen.dart
│   │       ├── auth/
│   │       ├── daily_log/
│   │       ├── people/
│   │       ├── collections/
│   │       ├── search/
│   │       └── review/
│   └── pubspec.yaml
│
├── backend/                      # AWS Lambda functions (Go) + CDK (TypeScript)
│   ├── cmd/
│   │   ├── pull_sync/main.go     # Lambda entry point
│   │   └── push_sync/main.go     # Lambda entry point
│   ├── internal/
│   │   ├── auth/auth.go          # Cognito JWT verification (keyfunc + jwt/v5)
│   │   ├── conflicts/conflicts.go # LWW ApplyLWW (DynamoDB ConditionalExpression)
│   │   └── pagination/pagination.go # DynamoDB cursor encode/decode
│   ├── tests/
│   │   ├── pull_sync_test.go
│   │   └── push_sync_test.go
│   ├── go.mod                    # module antra/backend · go 1.22
│   ├── go.sum
│   ├── Makefile                  # make build → dist/*/bootstrap
│   ├── bin/antra.ts              # CDK App entry point
│   ├── lib/antra-stack.ts        # CDK Stack (DynamoDB, Lambda, Cognito, API GW)
│   ├── cdk.json
│   └── package.json              # aws-cdk-lib dependencies
│
└── specs/
    └── 001-antra-log/
```

---

## Step 1: Flutter App Setup

```bash
# 1. Clone repo
git clone <repo-url>
cd antra

# 2. Install Flutter dependencies
cd app
flutter pub get

# 3. Generate drift database code
dart run build_runner build --delete-conflicting-outputs

# 4. Run on iOS simulator
flutter run -d "iPhone 16"   # or flutter run -d chrome for web

# 5. Run tests
flutter test
```

**Required pubspec.yaml dependencies**:

```yaml
dependencies:
  drift: ^2.18.0
  drift_flutter: ^0.2.0          # Flutter-specific drift integration
  sqlcipher_flutter_libs: ^0.7.0 # AES-256 encryption
  riverpod: ^2.5.0
  flutter_riverpod: ^2.5.0
  riverpod_annotation: ^2.3.0
  amplify_flutter: ^2.0.0        # AWS Amplify core
  amplify_auth_cognito: ^2.0.0   # Cognito auth
  flutter_secure_storage: ^9.2.0 # Keychain / Keystore token storage
  http: ^1.2.0                   # API Gateway REST calls
  workmanager: ^0.5.0            # Background sync scheduling
  flutter_local_notifications: ^17.0.0 # Check-in reminders

dev_dependencies:
  drift_dev: ^2.18.0
  build_runner: ^2.4.0
  flutter_test:
    sdk: flutter
```

---

## Step 2: AWS Backend Setup

```bash
# 1. Configure AWS CLI
aws configure
# Enter: Access Key ID, Secret Access Key, region (e.g. us-east-1), output format (json)

# 2. Install AWS CDK CLI (once per machine)
npm install -g aws-cdk

# 3. Install CDK project dependencies
cd backend
npm install

# 4. Build Go Lambda binaries (required before cdk deploy)
make build
# Produces: dist/pull_sync/bootstrap  dist/push_sync/bootstrap
# Build flags: GOOS=linux GOARCH=arm64 CGO_ENABLED=0

# 5. Bootstrap CDK in your AWS account/region (once per account)
cdk bootstrap aws://ACCOUNT_ID/us-east-1

# 6. Preview changes before deploying
cdk diff

# 7. Deploy infrastructure
cdk deploy --outputs-file outputs.json
# Outputs written to outputs.json:
#   - AntraStack.ApiGatewayUrl
#   - AntraStack.CognitoUserPoolId
#   - AntraStack.CognitoUserPoolClientId

# 8. Configure app constants from CDK outputs
#    Copy values from outputs.json into app/lib/config.dart
#    or pass via --dart-define at flutter run time (see Step 3)

# 9. Local Lambda testing (optional — requires SAM CLI)
cdk synth --output cdk.out
sam local start-api -t cdk.out/AntraStack.template.json --port 3001
# Test pull: POST http://localhost:3001/sync/pull
# Test push: POST http://localhost:3001/sync/push
```

**`backend/Makefile`**:

```makefile
.PHONY: build test clean

build:
    GOOS=linux GOARCH=arm64 CGO_ENABLED=0 \
      go build -o dist/pull_sync/bootstrap ./cmd/pull_sync
    GOOS=linux GOARCH=arm64 CGO_ENABLED=0 \
      go build -o dist/push_sync/bootstrap ./cmd/push_sync

test:
    go test ./...

clean:
    rm -rf dist/
```

---

## Step 3: Configure App Constants

`app/lib/config.dart`:

```dart
class AppConfig {
  static const apiGatewayBaseUrl =
    String.fromEnvironment('API_GATEWAY_URL',
      defaultValue: 'http://localhost:3001');
  static const cognitoUserPoolId =
    String.fromEnvironment('COGNITO_USER_POOL_ID');
  static const cognitoClientId =
    String.fromEnvironment('COGNITO_CLIENT_ID');
}
```

Run with environment variables:

```bash
flutter run \
  --dart-define=API_GATEWAY_URL=https://xyz.execute-api.us-east-1.amazonaws.com/prod \
  --dart-define=COGNITO_USER_POOL_ID=us-east-1_XXXXX \
  --dart-define=COGNITO_CLIENT_ID=XXXXXXXXXXXXXXXXXXXXXXXX
```

---

## Step 4: Validate Core Behaviors

### 4.1 — Bullet Capture (FR-001 through FR-009)

```text
1. Launch app: flutter run -d "iPhone 16"
2. Verify: today's daily log screen appears within 2 seconds of launch
3. Tap the capture input
4. Type "Buy groceries" → select type "task" → confirm
5. Verify: bullet appears in list within 500ms
6. Add a note and an event bullet
7. Navigate to yesterday's log
8. Verify: previous day is empty (correct)
9. Kill app and relaunch
10. Verify: all bullets still present (local persistence confirmed)
```

### 4.2 — Offline Capture (FR-007, SC-007)

```text
1. iOS Simulator → Features → Network Link Conditioner → 100% Loss
2. Create 5 bullets
3. Verify: all visible immediately (offline-first confirmed)
4. Relaunch app
5. Verify: bullets persist
6. Restore network → verify sync icon briefly appears
7. On second device: sign in → verify bullets appear after sync
```

### 4.3 — People Profiles (FR-010 through FR-015)

```text
1. Navigate to People tab → Create person: "Alice"
2. Return to Daily Log → type "Coffee with @Alice" → confirm
3. Navigate to Alice's profile
4. Verify: bullet appears in interaction timeline
5. Verify: "Last interaction" shows today
6. Set check-in reminder: 14 days
7. Verify: reminder notification scheduled (check iOS notification settings)
```

### 4.4 — Full-Text Search (FR-024 through FR-026, SC-006)

```text
1. Create 50+ bullets with varied content
2. Navigate to Search tab
3. Search "coffee" → verify matching bullets appear
4. Filter by tag "#work" → verify narrowed results
5. Filter by person "Alice" → verify only Alice-linked bullets
6. Measure: results must appear within 2 seconds
```

### 4.5 — Sync Conflict (FR-029, SC-009)

```text
1. Create bullet "Initial content" on Device A → sync
2. Without syncing, edit to "Device A version" on Device A
3. On Device B (synced): edit same bullet to "Device B version" → sync Device B
4. Sync Device A
5. Verify: Device A shows "Device B version" (remote wins, LWW)
6. Verify: conflict_records table contains "Device A version" (no silent data loss)
7. Verify: conflict indicator visible in UI
```

---

## Step 5: Performance Validation (Physical Device)

Run with a seeded database of 10,000 entries:

```dart
// test/fixtures/test_data_seeder.dart
await TestDataSeeder(db).seed(bulletCount: 10000, peopleCount: 100);
```

| Check | Target | How |
| ----- | ------ | --- |
| Cold launch → log visible | < 2 s | Flutter DevTools → Performance |
| Bullet capture → visible | < 500 ms | DevTools → Timeline |
| FTS search (10K entries) | < 2 s | `flutter test --name fts_benchmark` |
| Scroll 60 fps | 0 drops | DevTools → Frame chart |
| Memory during journaling | < 150 MB | DevTools → Memory |

---

## Step 6: Backend Go Tests

```bash
cd backend

# Run all Go unit tests (interface-based DynamoDB mocks — no AWS needed)
go test ./...

# Run with verbose output
go test -v ./...

# Run a specific package
go test ./internal/conflicts/...

# Build check (catches compile errors before deploy)
make build
```

---

## Common Issues

| Issue | Cause | Fix |
| ----- | ----- | --- |
| `drift` codegen fails | Missing `build_runner` step | Run `dart run build_runner build` |
| SQLCipher key error on install | Key not initialized | Call `AppDatabase.open()` with key before any query |
| FTS5 returns empty | FTS table not populated | Verify `v1_fts_tables` migration ran; check `PRAGMA user_version` |
| `make build` produces wrong arch | CGO\_ENABLED not 0 or wrong GOARCH | Ensure `GOOS=linux GOARCH=arm64 CGO_ENABLED=0` in Makefile |
| `cdk deploy` fails — binaries missing | `make build` not run first | Always run `make build` before `cdk deploy` |
| `cdk deploy` fails — not bootstrapped | CDK bootstrap not run in account | Run `cdk bootstrap aws://ACCOUNT_ID/REGION` first |
| `cdk deploy` fails — missing credentials | AWS CLI not configured | Run `aws configure` and verify with `aws sts get-caller-identity` |
| Amplify sign-in fails | Cognito pool config mismatch | Verify `cognitoUserPoolId` / `cognitoClientId` from `outputs.json` |
| Lambda 401 on sync | JWT expired during test | Call `Amplify.Auth.fetchAuthSession()` before sync call |
| Go test `interface not implemented` | Mock missing method | Implement all interface methods in mock struct |
| Background sync never fires | Simulator limitation | Test on physical device only for workmanager tasks |
| DynamoDB ConditionalCheckFailed | Clock skew > 5 s between devices | Verify device time is NTP-synced |
| `sam local` fails against CDK output | Template not synthesized | Run `cdk synth --output cdk.out` first |
