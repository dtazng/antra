# antra Development Guidelines

Auto-generated from all feature plans. Last updated: 2026-03-09

## Active Technologies
- SQLite (drift + SQLCipher, on-device) · DynamoDB single-table (cloud sync) (001-antra-log)
- Dart 3.3+ / Flutter 3.19+ + drift 2.18 (SQLite ORM), flutter_riverpod 2.5 + riverpod_annotation 2.3, uuid 4.x (002-task-lifecycle)
- SQLite via drift + SQLCipher. Schema version bumped 1 → 2. (002-task-lifecycle)
- Dart 3.3+ / Flutter 3.19+ + drift 2.18, flutter_riverpod 2.5, riverpod_annotation 2.3, uuid 4.x, intl 0.19, flutter_local_notifications 17 (existing) (003-personal-crm)
- SQLite via drift + SQLCipher. Schema version 2 → 3 (additive migration, no data loss). (003-personal-crm)
- Dart 3.3+ / Flutter 3.19+ + flutter_riverpod 2.5 (existing), drift 2.18 (existing) — **no new packages** (007-aurora-design-system)
- N/A — no DB changes; design tokens are compile-time constants (007-aurora-design-system)

- Flutter 3.19+ / Dart 3.3+ (client — iOS, Android, Web) (001-antra-log)
- Python 3.12 (AWS Lambda backend) (001-antra-log)
- TypeScript 5.x / AWS CDK v2 (infrastructure as code) (001-antra-log)

## Project Structure

```text
app/                          # Flutter cross-platform application (iOS → Android → Web)
  lib/
    main.dart                 # Entry point; Amplify init, Riverpod scope
    database/
      app_database.dart       # drift DatabaseConnection + SQLCipher
      tables/                 # drift @DataClassName table definitions
      daos/                   # drift Data Access Objects
    services/
      sync_engine.dart        # Orchestrates pull + push
      sync_queue_manager.dart # pending_sync CRUD
      api_client.dart         # HTTP calls to API Gateway
      encryption_service.dart # AES-GCM key derivation
    providers/                # Riverpod providers (@riverpod code-gen)
    screens/                  # 5 tabs: Daily Log, People, Collections, Search, Review
    widgets/
  test/                       # flutter_test unit + widget tests
  pubspec.yaml
backend/                      # AWS Lambda functions (Python 3.12)
  functions/
    pull_sync/index.py        # Read-only DynamoDB sync pull
    push_sync/index.py        # Read-write DynamoDB sync push with LWW conflict
  layers/sync_utils/python/   # Shared layer: auth.py, conflicts.py, pagination.py
  template.yaml               # AWS SAM template (DynamoDB, Lambda, Cognito, API GW)
  tests/                      # pytest + moto unit tests
specs/001-antra-log/          # Feature specification and design artifacts
```

## Commands

```bash
# Install Flutter dependencies
cd app && flutter pub get

# Generate drift database code (run after schema changes)
dart run build_runner build --delete-conflicting-outputs

# Run Flutter app on iOS simulator
flutter run -d "iPhone 16"

# Run Flutter tests
flutter test

# Install CDK project dependencies
cd backend && npm install

# Bootstrap CDK in AWS account (once per account/region)
cdk bootstrap aws://ACCOUNT_ID/REGION

# Preview infrastructure changes
cd backend && cdk diff

# Deploy AWS backend
cd backend && cdk deploy --outputs-file outputs.json

# Run Lambda locally (requires cdk synth first)
cd backend && cdk synth --output cdk.out && sam local start-api -t cdk.out/AntraStack.template.json --port 3001

# Run Lambda unit tests
cd backend && pytest tests/
```

## Code Style

- **Architecture**: Riverpod (code-gen `@riverpod`) for state management; no GetX or BLoC.
- **Database**: `drift` with typed DAOs and `Stream<List<T>>` for reactive UI. FTS5 via raw SQL migrations only.
- **Sync**: `SyncEngine` is a plain Dart class with no Flutter imports — injectable with `MockApiClient` in tests.
- **Error handling**: Handle at system boundaries (`ApiClient`, `AppDatabase`). Do not defensively guard internal invariants.
- **Naming**: Use snake_case for files and directories; `Provider` suffix for Riverpod providers; `Dao` suffix for drift DAOs.
- **Dart**: Prefer `async/await`. Annotate `@riverpod` providers; avoid manual `ChangeNotifier`.
- **Lambda**: Pure functions. `auth.py` verify-then-proceed pattern. All DynamoDB calls use `ConditionalExpression` for atomicity on write.
- **CDK**: All infrastructure in `backend/lib/antra-stack.ts`. Use L2 constructs and grant methods (`table.grantReadData(fn)`) — never hand-roll IAM JSON. Run `cdk diff` before every `cdk deploy`.

## Recent Changes
- 007-aurora-design-system: Added Dart 3.3+ / Flutter 3.19+ + flutter_riverpod 2.5 (existing), drift 2.18 (existing) — **no new packages**
- 005-task-carryover: Added [if applicable, e.g., PostgreSQL, CoreData, files or N/A]
- 004-person-detail-view: Added [if applicable, e.g., PostgreSQL, CoreData, files or N/A]


<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
