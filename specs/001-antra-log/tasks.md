# Tasks: Antra Log — Digital Bullet Journal with Personal CRM

**Input**: Design documents from `/specs/001-antra-log/`
**Prerequisites**: plan.md ✅ | spec.md ✅ | data-model.md ✅ | contracts/ ✅ | research.md ✅ | quickstart.md ✅

**Stack**: Flutter 3.19+ / Dart 3.3+ (client) · Go 1.22+ (Lambda, `provided.al2023`, ARM64) · TypeScript / AWS CDK v2 (IaC) · drift + SQLCipher · AWS Lambda + DynamoDB + Cognito

**Organization**: Tasks are grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: Which user story (US1–US5) this task belongs to
- Every task includes the exact file path

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create project directory structure and initialize both the Flutter app and AWS backend projects.

- [X] T001 Create `app/` Flutter project directory structure: `lib/database/tables/`, `lib/database/daos/`, `lib/services/`, `lib/providers/`, `lib/screens/`, `lib/widgets/`, `test/`
- [X] T002 Create `backend/` Go + CDK project directory structure: `backend/cmd/pull_sync/`, `backend/cmd/push_sync/`, `backend/internal/auth/`, `backend/internal/conflicts/`, `backend/internal/pagination/`, `backend/tests/`, `backend/bin/`, `backend/lib/`, `backend/dist/`
- [X] T003 [P] Initialize Flutter project: write `app/pubspec.yaml` with all dependencies from plan.md (drift 2.18, sqlcipher_flutter_libs 0.7, riverpod 2.5, flutter_riverpod 2.5, riverpod_annotation 2.3, amplify_flutter 2.0, amplify_auth_cognito 2.0, flutter_secure_storage 9.2, http 1.2, workmanager 0.5, flutter_local_notifications 17.0; dev: drift_dev 2.18, build_runner 2.4)
- [X] T004 [P] Initialize AWS CDK project in `backend/`: write `backend/package.json` (aws-cdk-lib ^2, constructs ^10, typescript dev dep), `backend/tsconfig.json`, `backend/cdk.json` (`{"app": "npx ts-node bin/antra.ts"}`), `backend/bin/antra.ts` (CDK App entry point instantiating `AntraStack`), `backend/lib/antra-stack.ts` (empty Stack class stub)
- [X] T005 [P] Configure Dart analysis: write `app/analysis_options.yaml` (strict mode: `avoid_print`, `prefer_final_fields`, `always_use_package_imports`)
- [X] T006 [P] Initialize Go module: write `backend/go.mod` (module `antra/backend`, go 1.22) with dependencies: `github.com/aws/aws-lambda-go v1.47+`, `github.com/aws/aws-sdk-go-v2`, `github.com/golang-jwt/jwt/v5`, `github.com/MicahParks/keyfunc/v3`, `github.com/google/uuid`, `github.com/stretchr/testify`; write `backend/Makefile` with `build` (GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build for each cmd), `test` (go test ./...), `clean` (rm -rf dist/) targets

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure all user stories depend on — drift database, SQLCipher, all table definitions, code generation, navigation scaffold, and app entry point.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [X] T007 Implement `app/lib/database/app_database.dart`: drift `@DriftDatabase` class referencing all tables, `NativeDatabase.createInBackground` with SQLCipher passphrase from `flutter_secure_storage`, and `DatabaseConnection.fromExecutor` setup
- [X] T008 [P] Create drift table `DayLogs` in `app/lib/database/tables/day_logs.dart`: columns `id`, `date` (UNIQUE), `createdAt`, `updatedAt`, `syncId`, `deviceId`, `isDeleted` (INTEGER default 0); index on `date` and `updatedAt`
- [X] T009 [P] Create drift table `Bullets` in `app/lib/database/tables/bullets.dart`: columns `id`, `dayId` (FK), `type` (task/note/event), `content`, `status` (open/complete/cancelled/migrated), `position`, `migratedToId` (nullable FK), `encryptionEnabled` (INTEGER default 0), `createdAt`, `updatedAt`, `syncId`, `deviceId`, `isDeleted`; indexes on `dayId`, `updatedAt`, `type`, `status`
- [X] T010 [P] Create drift table `People` in `app/lib/database/tables/people.dart`: columns `id`, `name`, `notes` (nullable), `reminderCadenceDays` (nullable INTEGER), `lastInteractionAt` (nullable), `createdAt`, `updatedAt`, `syncId`, `deviceId`, `isDeleted`; indexes on `name`, `updatedAt`, `lastInteractionAt`
- [X] T011 [P] Create drift table `Tags` in `app/lib/database/tables/tags.dart`: columns `id`, `name` (NOT NULL UNIQUE, lowercase normalized), `createdAt`, `syncId`, `deviceId`, `isDeleted`
- [X] T012 [P] Create drift table `BulletPersonLinks` in `app/lib/database/tables/bullet_person_links.dart`: composite PK (`bulletId`, `personId`), `createdAt`, `syncId`, `deviceId`, `isDeleted`
- [X] T013 [P] Create drift table `BulletTagLinks` in `app/lib/database/tables/bullet_tag_links.dart`: composite PK (`bulletId`, `tagId`), `createdAt`, `syncId`, `deviceId`, `isDeleted`
- [X] T014 [P] Create drift table `Collections` in `app/lib/database/tables/collections.dart`: columns `id`, `name`, `description` (nullable), `filterRules` (TEXT JSON array), `position`, `createdAt`, `updatedAt`, `syncId`, `deviceId`, `isDeleted`
- [X] T015 [P] Create drift table `Reviews` in `app/lib/database/tables/reviews.dart`: columns `id`, `periodType` (week/month), `startDate`, `endDate`, `summaryNotes` (nullable), `completedAt` (nullable), `createdAt`, `updatedAt`, `syncId`, `deviceId`, `isDeleted`
- [X] T016 [P] Create drift table `PendingSync` in `app/lib/database/tables/pending_sync.dart`: columns `id`, `entityType`, `entityId`, `operation` (create/update/delete), `payload` (TEXT JSON), `createdAt`, `retryCount` (INTEGER default 0), `lastError` (nullable), `isSynced` (INTEGER default 0)
- [X] T017 [P] Create drift table `ConflictRecords` in `app/lib/database/tables/conflict_records.dart`: columns `id`, `entityType`, `entityId`, `localSnapshot` (TEXT JSON), `remoteSnapshot` (TEXT JSON), `detectedAt`, `resolvedAt` (nullable), `resolution` (nullable: kept_remote/restored_local/dismissed)
- [X] T018 Register all 10 tables in `app/lib/database/app_database.dart` `@DriftDatabase(tables: [...])` annotation and implement the full drift migration plan: `v1_core_tables`, `v1_link_tables`, `v1_fts_tables` (raw SQL for `bullets_fts` and `people_fts` FTS5 virtual tables), `v1_collections`, `v1_reviews`, `v1_sync_tables`, `v1_indexes` — in `app/lib/database/app_database.dart` (depends on T008–T017)
- [X] T019 Run drift code generation: `cd app && dart run build_runner build --delete-conflicting-outputs` — produces `app/lib/database/app_database.g.dart` and all table companion classes (depends on T018)
- [X] T020 Implement `app/lib/config.dart`: `AppConfig` class with `static const apiGatewayBaseUrl`, `cognitoUserPoolId`, `cognitoClientId` read from `String.fromEnvironment`
- [X] T021 Implement `app/lib/providers/database_provider.dart`: `@Riverpod` `AppDatabase appDatabase(ref)` that opens the drift database with SQLCipher key (fetched from `flutter_secure_storage`, generated on first launch)
- [X] T022 Implement `app/lib/main.dart`: `runApp` with `ProviderScope`, call `Amplify.addPlugins([AmplifyAuthCognito()])` stub, and root `MaterialApp` pointing to `RootTabScreen`
- [X] T023 Implement `app/lib/screens/root_tab_screen.dart`: `Scaffold` with bottom `NavigationBar` — 5 tabs: Daily Log, People, Collections, Search, Review — each tab showing a placeholder screen widget

**Checkpoint**: Foundation ready — all tables created, codegen complete, app launches to 5-tab navigation. User story implementation can now begin.

---

## Phase 3: User Story 1 — Daily Bullet Capture (Priority: P1) 🎯 MVP

**Goal**: User opens the app to today's daily log, captures bullets of any type, tags entries, marks task status, navigates to past days — all persisted locally with no network dependency.

**Independent Test**: Launch app on iOS simulator → today's log appears → create task/note/event bullets → add #tags → mark task complete → navigate to yesterday (empty) → kill + relaunch → verify all bullets persist.

- [X] T024 [P] [US1] Implement `BulletsDao` in `app/lib/database/daos/bullets_dao.dart`: methods `watchBulletsForDay(String dayId)` (Stream), `insertBullet(BulletsCompanion)`, `updateBulletStatus(String id, String status)`, `updateBulletContent(String id, String content)`, `softDeleteBullet(String id)`, `getOrCreateDayLog(String date)` — all writes set `updatedAt` and enqueue `PendingSync`
- [X] T025 [P] [US1] Implement `SyncDao` in `app/lib/database/daos/sync_dao.dart`: methods `enqueuePendingSync(entityType, entityId, operation, payload)`, `getPendingItems()`, `markSynced(String id)`, `markFailed(String id, String error)`
- [X] T026 [US1] Implement `BulletsProvider` in `app/lib/providers/bullets_provider.dart`: `@riverpod Stream<List<Bullet>> bulletsForDay(ref, String date)` — calls `BulletsDao.watchBulletsForDay` (depends on T024)
- [X] T027 [US1] Implement `DailyLogScreen` in `app/lib/screens/daily_log/daily_log_screen.dart`: shows today's date as header, `ListView.builder` of `BulletListItem` widgets from `bulletsForDayProvider`, and the `BulletCaptureBar` pinned at bottom (depends on T026)
- [X] T028 [US1] Implement `BulletCaptureBar` widget in `app/lib/widgets/bullet_capture_bar.dart`: `TextField` for content, segmented control for type (task/note/event), submit button — calls `BulletsDao.insertBullet` and `SyncDao.enqueuePendingSync` on submit
- [X] T029 [US1] Implement `BulletListItem` widget in `app/lib/widgets/bullet_list_item.dart`: displays type icon, content text, tags chips, status badge (for tasks); long-press menu for edit/delete; swipe to toggle task status (depends on T024)
- [X] T030 [US1] Wire `BulletCaptureBar` into `DailyLogScreen`: on submit, call `getOrCreateDayLog(today)`, then `insertBullet` with the returned `dayId`, dismiss keyboard (depends on T027, T028, T024)
- [X] T031 [US1] Implement day navigation in `DailyLogScreen`: left/right swipe and prev/next arrow buttons change the displayed date, updating the `bulletsForDayProvider` watch parameter (depends on T027, T026)
- [X] T032 [US1] Implement task status flow in `BulletListItem`: tapping the status icon cycles through open → complete; long-press menu offers cancelled and migrated options; calls `BulletsDao.updateBulletStatus` (depends on T029, T024)
- [X] T033 [US1] Implement inline tag parsing in `BulletCaptureBar.submit`: extract `#word` tokens from content using regex, upsert each to `tags` table (lowercase), insert `bullet_tag_links` rows — all in a single drift transaction in `app/lib/database/daos/bullets_dao.dart` (depends on T024)

**Checkpoint**: User Story 1 fully functional — open app → today's log appears → capture bullets of all types → add tags → change task status → navigate past days → kill/relaunch retains all data.

---

## Phase 4: User Story 2 — People Profiles & Relationship Memory (Priority: P2)

**Goal**: User creates people profiles, links bullets to them via @mention, views interaction timelines, sees last interaction date, and configures check-in reminders.

**Independent Test**: Create person "Alice" → add bullet "Coffee with @Alice" → open Alice's profile → timeline shows the bullet → "Last interaction: today" is displayed → set 14-day reminder → verify notification scheduled.

- [X] T034 [P] [US2] Implement `PeopleDao` in `app/lib/database/daos/people_dao.dart`: methods `watchAllPeople()` (Stream), `insertPerson(PeopleCompanion)`, `updatePerson(PeopleCompanion)`, `softDeletePerson(String id)`, `updateLastInteractionAt(String personId, String timestamp)`, `getPersonByName(String name)`
- [X] T035 [P] [US2] Implement `BulletPersonLinksDao` in `app/lib/database/daos/people_dao.dart` (same file): methods `insertLink(bulletId, personId)`, `watchBulletsForPerson(String personId)` (Stream returning joined Bullet rows), `softDeleteLinksForBullet(String bulletId)`
- [X] T036 [US2] Implement `PeopleProvider` in `app/lib/providers/people_provider.dart`: `@riverpod Stream<List<Person>> allPeople(ref)` and `@riverpod Stream<List<Bullet>> bulletsForPerson(ref, String personId)` (depends on T034, T035)
- [X] T037 [US2] Implement `PeopleScreen` in `app/lib/screens/people/people_screen.dart`: `ListView` of people cards showing name and last interaction date, FAB to open `CreatePersonSheet` (depends on T036)
- [X] T038 [US2] Implement `CreatePersonSheet` in `app/lib/screens/people/create_person_sheet.dart`: form with name field and optional context notes, saves via `PeopleDao.insertPerson` and queues `PendingSync`
- [X] T039 [US2] Implement `PersonProfileScreen` in `app/lib/screens/people/person_profile_screen.dart`: shows name, context notes (editable), "Last interaction: {date}" computed from `lastInteractionAt`, reverse-chronological `ListView` of linked bullets (depends on T034, T035, T036)
- [X] T040 [US2] Implement @mention person linking in `BulletCaptureBar`: detect `@word` token on space/submit, fuzzy-match against `PeopleDao.getPersonByName`, show inline suggestion dropdown, on selection insert `bullet_person_links` row and call `PeopleDao.updateLastInteractionAt` in `app/lib/widgets/bullet_capture_bar.dart` (depends on T028, T034, T035)
- [X] T041 [US2] Implement `ReminderService` in `app/lib/services/reminder_service.dart`: `scheduleReminder(Person p)` uses `flutter_local_notifications` to schedule a notification `p.reminderCadenceDays` days after `p.lastInteractionAt`; `cancelReminder(String personId)` cancels existing notification
- [X] T042 [US2] Implement reminder cancellation when interaction logged: after `PeopleDao.updateLastInteractionAt`, call `ReminderService.scheduleReminder` to reset the countdown in `app/lib/database/daos/people_dao.dart` (depends on T041, T034)
- [X] T043 [US2] Add reminder cadence UI to `PersonProfileScreen`: dropdown selector for check-in reminder (None / 7 / 14 / 30 / 60 days), calls `PeopleDao.updatePerson` and `ReminderService.scheduleReminder` on change (depends on T039, T041)
- [X] T044 [US2] Initialize `flutter_local_notifications` and `workmanager` in `app/lib/main.dart`: register notification channels, call `Workmanager().initialize()` (depends on T022, T041)

**Checkpoint**: User Story 2 fully functional — create people, link via @mention, view timeline, see last interaction, reminders scheduled.

---

## Phase 5: Sync Infrastructure — Go Backend + Flutter Client (Cross-Cutting: FRs 027–029)

**Purpose**: Go Lambda backend + client sync engine enabling cross-device synchronization with offline-first guarantees and LWW conflict resolution.

**Note**: Go compiles shared logic (`internal/`) into each binary — no Lambda layers needed. Run `make build` before `cdk deploy`.

- [X] T045 Implement `backend/internal/auth/auth.go`: `VerifyCognitoJWT(authHeader string) (string, error)` — strips `Bearer` prefix, calls `keyfunc.Get(jwksURL, keyfunc.Options{RefreshInterval: time.Hour})` to cache Cognito JWKS, calls `jwt.ParseWithClaims`, returns `sub` claim as user ID (depends on T006)
- [X] T046 [P] Implement `backend/internal/conflicts/conflicts.go`: `ApplyLWW(ctx context.Context, client DynamoDBAPI, tableName, pk, sk string, incoming map[string]types.AttributeValue) (clientItem, serverItem map[string]types.AttributeValue, err error)` — calls `client.PutItem` with `ConditionExpression: "attribute_not_exists(updatedAt) OR updatedAt < :ts"`; on `*types.ConditionalCheckFailedException` calls `client.GetItem` and returns both items; define `DynamoDBAPI` interface with `PutItem`/`GetItem` methods for testability (depends on T006)
- [X] T047 [P] Implement `backend/internal/pagination/pagination.go`: `EncodeCursor(lastEvaluatedKey map[string]types.AttributeValue) string` — JSON marshal then base64 encode, return empty string for nil; `DecodeCursor(cursor string) (map[string]types.AttributeValue, error)` — base64 decode then JSON unmarshal, return nil for empty string (depends on T006)
- [X] T048 Implement `backend/cmd/pull_sync/main.go`: Go Lambda handler — call `auth.VerifyCognitoJWT`, unmarshal `SyncPullRequest` body, call `pagination.DecodeCursor`, call `dynamoClient.Query` on GSI1 (`userId = :uid AND updatedAt > :ts`, `Limit=500`, `ExclusiveStartKey`), marshal `SyncPullResponse` with `records`, `serverTimestamp` (`time.Now().UTC()`), `hasMore` (`result.LastEvaluatedKey != nil`), `nextCursor`; call `lambda.Start(handler)` in `main()` (depends on T045, T047)
- [X] T049 Implement `backend/cmd/push_sync/main.go`: Go Lambda handler — call `auth.VerifyCognitoJWT`, unmarshal `SyncPushRequest` (max 500 records, return 413 if exceeded), for each record call `conflicts.ApplyLWW`, assign `uuid.New()` as `syncId` for new records, accumulate `appliedCount`/`conflicts`/`syncIds`, marshal `SyncPushResponse`; call `lambda.Start(handler)` in `main()` (depends on T045, T046)
- [X] T050 Complete `backend/lib/antra-stack.ts` CDK stack: define `AntraSyncTable` (DynamoDB PAY_PER_REQUEST, PK `pk` String, SK `sk` String, GSI1 on `userId`+`updatedAt` ALL projection, TTL attribute `ttl`, `removalPolicy: RETAIN`); define `pullFn` (512 MB, 10 s, `lambda.Runtime.PROVIDED_AL2023`, `lambda.Architecture.ARM_64`, `handler: 'bootstrap'`, `code: lambda.Code.fromAsset('dist/pull_sync')`, `syncTable.grantReadData`); define `pushFn` (1024 MB, 10 s, same runtime/arch, `code: lambda.Code.fromAsset('dist/push_sync')`, `syncTable.grantReadWriteData`); define `CognitoUserPool` (email sign-in, auto-verify email, 8-char password, `selfSignUpEnabled`); add `AntraFlutterClient` (userPassword + userSrp auth flows); define REST API with `CognitoUserPoolsAuthorizer` on POST /sync/pull and POST /sync/push; add `CfnOutput` for `ApiGatewayUrl`, `CognitoUserPoolId`, `CognitoUserPoolClientId` (depends on T004, T048, T049)
- [X] T051 [P] Write `backend/tests/pull_sync_test.go`: Go table-driven tests using the `DynamoDBAPI` interface mock — test delta query returns only records after `lastSyncTimestamp`; test pagination cursor threads through two pages; test 401 returned when JWT verification fails; use `github.com/stretchr/testify/assert` for assertions (depends on T048, T047)
- [X] T052 [P] Write `backend/tests/push_sync_test.go`: Go table-driven tests — test new record creates with assigned `syncId`; test conflict: mock returns `ConditionalCheckFailedException` + server item with later `updatedAt`, assert response `conflicts` array contains both versions; test 413 returned for 501 records; test 401 for missing JWT (depends on T049, T046)
- [X] T053 Implement `app/lib/services/api_client.dart`: `ApiClient` class with `Future<SyncPullResponse> pull(SyncPullRequest)` and `Future<SyncPushResponse> push(SyncPushRequest)` — both call `http.post` to `AppConfig.apiGatewayBaseUrl`, set `Authorization: Bearer {cognitoAccessToken}`, JSON encode/decode
- [X] T054 Implement `app/lib/services/sync_queue_manager.dart`: `SyncQueueManager` wrapping `SyncDao` — `enqueue(entityType, entityId, operation, payload)`, `drainQueue()` returns list of pending items (max 500), `confirmSynced(List<String> ids)`, `reportFailed(String id, String error)`
- [X] T055 Implement `app/lib/services/sync_engine.dart`: `SyncEngine.sync()` — (1) call `ApiClient.pull` with pagination loop until `hasMore=false`, apply each record to local drift tables via upsert; (2) call `SyncQueueManager.drainQueue`, batch into `ApiClient.push`, handle `ConflictInfo` by writing to `conflict_records` table and overwriting local entity with server version; (3) call `SyncDao.markSynced` for applied items (depends on T053, T054, T025)
- [X] T056 Implement `app/lib/providers/sync_status_provider.dart`: `@riverpod class SyncStatusNotifier` — exposes `SyncState` (idle/syncing/error) and `conflictCount`; called by `SyncEngine` before and after sync (depends on T055)
- [X] T057 Complete Amplify Auth setup in `app/lib/main.dart`: call `Amplify.configure(amplifyconfig)` with Cognito pool/client IDs from `AppConfig`; implement `SignInScreen` and `SignUpScreen` in `app/lib/screens/auth/`; redirect unauthenticated users to sign-in (depends on T022)
- [X] T058 Implement background sync in `app/lib/main.dart` and `app/lib/services/sync_engine.dart`: register `workmanager` periodic task calling `SyncEngine.sync()`; also call `SyncEngine.sync()` on `AppLifecycleState.resumed` via `WidgetsBindingObserver` (depends on T055, T044)

**Checkpoint**: Run `make build && cdk deploy --outputs-file outputs.json` — Go Lambda endpoints live; app signs in, pushes local bullets to DynamoDB, pulls on next launch.

---

## Phase 6: User Story 3 — Search & Retrieval (Priority: P3)

**Goal**: Full-text search across all bullets with filters by person, tag, and date range — results in under 2 seconds for 10,000 entries.

**Independent Test**: Seed 50+ bullets with varied content → search "coffee" → matching bullets appear → filter by #work tag → results narrow → filter by person Alice → only Alice-linked bullets → date filter narrows further → all within 2 s.

- [X] T059 [US3] Add FTS5 migration to `app/lib/database/app_database.dart` `v1_fts_tables`: run `CREATE VIRTUAL TABLE bullets_fts USING fts5(content, content='bullets', content_rowid='rowid')` and `CREATE VIRTUAL TABLE people_fts USING fts5(name, notes, content='people', content_rowid='rowid')`; add triggers (`AFTER INSERT/UPDATE/DELETE ON bullets`) to keep FTS in sync (depends on T018, T019)
- [X] T060 [US3] Implement FTS search methods in `BulletsDao` in `app/lib/database/daos/bullets_dao.dart`: `searchBullets(String query)` using `bullets_fts MATCH ?`, `filterByTag(String tagName)` via `bullet_tag_links JOIN tags`, `filterByPerson(String personId)` via `bullet_person_links`, `filterByDateRange(String from, String to)` via `day_logs.date BETWEEN` — all return `Stream<List<Bullet>>` (depends on T059, T024)
- [X] T061 [P] [US3] Implement `SearchProvider` in `app/lib/providers/search_provider.dart`: `@riverpod class SearchNotifier` holding `query`, `tagFilter`, `personFilter`, `dateRange`; combines FTS results with active filters; debounce 200 ms (depends on T060)
- [X] T062 [P] [US3] Implement `SearchScreen` in `app/lib/screens/search/search_screen.dart`: `TextField` search bar at top, `ListView` of `BulletListItem` results from `SearchProvider`, empty state widget when no results (depends on T061)
- [X] T063 [US3] Add filter chips to `SearchScreen`: person picker (from `allPeopleProvider`), tag picker (from all tags), date range picker — each chip updates `SearchNotifier` state (depends on T062, T036)
- [X] T064 [US3] Implement navigation from `SearchScreen` result tap to `DailyLogScreen` at the bullet's date, scrolled to the bullet's position in `app/lib/screens/search/search_screen.dart` (depends on T062, T027)

**Checkpoint**: User Story 3 fully functional — search returns results in < 2 s for 10 K entries, all filter combinations work, tapping result navigates to source log entry.

---

## Phase 7: User Story 4 — Collections & Filtered Views (Priority: P4)

**Goal**: User creates named dynamic views (Collections) that auto-populate from filter rules (tag, person, bullet type, date range) and navigate back to the source daily log entry.

**Independent Test**: Create "Work Ideas" collection with `#work` tag filter → add bullet tagged #work in daily log → bullet auto-appears in collection → tap it → navigates to daily log at that date.

- [X] T065 [P] [US4] Implement `CollectionsDao` in `app/lib/database/daos/collections_dao.dart`: methods `watchAllCollections()` (Stream), `insertCollection(CollectionsCompanion)`, `updateCollection(CollectionsCompanion)`, `softDeleteCollection(String id)`
- [X] T066 [US4] Implement `CollectionFilterEngine` in `app/lib/services/collection_filter_engine.dart`: `Stream<List<Bullet>> applyRules(List<FilterRule> rules)` — parses `filterRules` JSON array (tag/person/bullet_type/date_range rule objects), composes drift queries using `BulletsDao` FTS and join methods (depends on T065, T024, T060)
- [X] T067 [US4] Implement `CollectionsProvider` in `app/lib/providers/collections_provider.dart`: `@riverpod Stream<List<Collection>> allCollections(ref)` (depends on T065)
- [X] T068 [US4] Implement `CollectionsScreen` in `app/lib/screens/collections/collections_screen.dart`: `ListView` of collection cards showing name, description, and bullet count badge; FAB to open `CreateCollectionSheet` (depends on T067)
- [X] T069 [US4] Implement `CreateCollectionSheet` in `app/lib/screens/collections/create_collection_sheet.dart`: name field, description field, filter rule builder (add rule: tag selector / person selector / type selector / date range); saves via `CollectionsDao.insertCollection` and queues `PendingSync`
- [X] T070 [US4] Implement `CollectionDetailScreen` in `app/lib/screens/collections/collection_detail_screen.dart`: displays collection name, shows `ListView` of bullets from `CollectionFilterEngine.applyRules(collection.filterRules)` — reactive stream auto-updates as new bullets are added (depends on T066)
- [X] T071 [US4] Implement navigation from `CollectionDetailScreen` bullet tap to `DailyLogScreen` at the bullet's originating date in `app/lib/screens/collections/collection_detail_screen.dart` (depends on T070, T027)

**Checkpoint**: User Story 4 fully functional — create collections, add tagged bullets in daily log, collections auto-populate, tap navigates to source.

---

## Phase 8: User Story 5 — Weekly & Monthly Reviews (Priority: P5)

**Goal**: At end of week/month, user is prompted through a structured review — sees open tasks and events, migrates tasks forward, adds summary notes, and completes the review. Monthly view surfaces top interactions.

**Independent Test**: Complete one week of entries → initiate weekly review → all open tasks appear → migrate one task → verify new bullet created in today's log → complete review → summary saved → review accessible from past logs.

- [X] T072 [P] [US5] Implement `ReviewsDao` in `app/lib/database/daos/reviews_dao.dart`: methods `watchReviews()` (Stream), `insertReview(ReviewsCompanion)`, `getOrCreateReview(periodType, startDate, endDate)`, `updateSummaryNotes(String id, String notes)`, `markComplete(String id)`
- [X] T073 [US5] Add `getOpenTasksForPeriod(String from, String to)` and `getEventsForPeriod(String from, String to)` to `BulletsDao` in `app/lib/database/daos/bullets_dao.dart`: query bullets where `type=task AND status=open` (or `type=event`) and `day_logs.date BETWEEN from AND to` (depends on T024)
- [X] T074 [US5] Implement `ReviewsProvider` in `app/lib/providers/reviews_provider.dart`: `@riverpod Stream<List<Review>> allReviews(ref)` and `@riverpod Future<List<Bullet>> openTasksForPeriod(ref, String from, String to)` (depends on T072, T073)
- [X] T075 [US5] Implement `WeeklyReviewScreen` in `app/lib/screens/review/weekly_review_screen.dart`: shows current week's date range header, lists open tasks (each with migrate/dismiss action), lists events; `TextFormField` for summary notes at bottom; "Complete Review" button (depends on T074)
- [X] T076 [US5] Implement task migration in `BulletsDao`: `migrateBullet(String bulletId)` — sets source bullet `status=migrated`, `migratedToId=newId`; inserts a new bullet in today's log with same content and type=task, status=open in `app/lib/database/daos/bullets_dao.dart` (depends on T024)
- [X] T077 [US5] Wire migrate action in `WeeklyReviewScreen` to call `BulletsDao.migrateBullet` and remove the task from the review list (depends on T075, T076)
- [X] T078 [US5] Implement "Complete Review" action in `WeeklyReviewScreen`: call `ReviewsDao.markComplete` with summary notes, queue `PendingSync`, show confirmation — navigates back to daily log (depends on T075, T072, T025)
- [X] T079 [US5] Implement `MonthlyReflectionScreen` in `app/lib/screens/review/monthly_review_screen.dart`: shows top people by interaction count (`PeopleDao` ranked by `lastInteractionAt`), lists unresolved tasks, lists all events for the month; reuses `ReviewsDao.getOrCreateReview` for monthly period (depends on T074, T034)
- [X] T080 [US5] Implement passive weekly review prompt banner in `DailyLogScreen`: on app launch/resume, check if current ISO week has a completed `Review` — if not, show dismissable banner linking to `WeeklyReviewScreen` in `app/lib/screens/daily_log/daily_log_screen.dart` (depends on T075, T027, T072)

**Checkpoint**: User Story 5 fully functional — weekly review prompt surfaces, open tasks list, migrate creates new bullet, complete saves summary, monthly view shows top interactions.

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: End-to-end encryption (Pro tier), UI completeness, performance validation, and final integration checks.

- [X] T081 [P] Implement `EncryptionService` in `app/lib/services/encryption_service.dart`: `encrypt(String plaintext, Uint8List key)` → AES-256-GCM ciphertext (base64); `decrypt(String ciphertext, Uint8List key)` → plaintext; `deriveKey(String passphrase, Uint8List salt)` → 256-bit key using PBKDF2
- [X] T082 [P] Wire E2E encryption into `SyncEngine.push` path: if `encryptionEnabled=true` for a record, call `EncryptionService.encrypt(payload, userKey)` before passing to `ApiClient.push`; set `encryptionEnabled=true` on `SyncRecord` in `app/lib/services/sync_engine.dart` (depends on T055, T081)
- [X] T083 [P] Implement conflict UI: add conflict badge (!) to `BulletListItem` when bullet has an entry in `conflict_records`; add `ConflictReviewSheet` showing local snapshot vs remote snapshot with "Keep Remote" / "Restore Local" / "Dismiss" actions in `app/lib/widgets/` (depends on T029, T056)
- [X] T084 [P] Implement empty state widgets in `app/lib/widgets/empty_state.dart`: first-launch daily log (prompt to capture first bullet), empty people tab (prompt to add a person), search no-results (suggest broadening filter), empty collection (explain auto-population) — used across all screens
- [X] T085 [P] Implement sync status indicator in `app/lib/widgets/sync_status_bar.dart`: shows spinning indicator while syncing, "Last synced {time}" when idle, red badge with conflict count when conflicts exist — integrated into `DailyLogScreen` app bar (depends on T056)
- [X] T086 Implement `app/test/fixtures/test_data_seeder.dart`: `TestDataSeeder(AppDatabase db).seed(bulletCount: 10000, peopleCount: 100)` — generates realistic bullet content, people, tags, links across 365 days of `day_logs`
- [ ] T087 [P] Run performance validation (requires physical device): seed 10,000 entries via `TestDataSeeder`, measure cold launch < 2 s via Flutter DevTools Performance, bullet capture < 500 ms via Timeline, FTS search < 2 s via `flutter test --name fts_benchmark`, 60 fps scroll via Frame chart (depends on T086)
- [ ] T088 [P] Run quickstart.md validation scenarios: 4.1 Bullet Capture, 4.2 Offline Capture (Network Link Conditioner), 4.3 People Profiles, 4.4 Full-Text Search, 4.5 Sync Conflict (two-device LWW) — CDK stack must be deployed (`cdk deploy --outputs-file outputs.json`) before sync scenarios (depends on T058, T064, T055)
- [X] T089 [P] Run full test suite: `cd app && flutter test` (pass); `cd backend && go test ./...` (pass); fix any regressions (depends on T051, T052)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 — **BLOCKS** all user stories
- **US1 (Phase 3)**: Depends on Phase 2 only — no story dependencies
- **US2 (Phase 4)**: Depends on Phase 2; integrates with US1 (@mention links bullets) — US1 should be complete first
- **Sync (Phase 5)**: Go backend (T045–T052) depends on T006 (go.mod); Flutter client (T053–T058) depends on Phase 2; CDK (T050) depends on T004 and Go binaries built via `make build`
- **US3 (Phase 6)**: Depends on Phase 2 — FTS independently testable offline; sync adds cross-device validation
- **US4 (Phase 7)**: Depends on US1 (bullets), US2 (people as filter), US3 (filter engine reuse)
- **US5 (Phase 8)**: Depends on US1 (bullets for review) and US2 (people interaction data)
- **Polish (Phase 9)**: Depends on all prior phases complete

### User Story Dependencies

- **US1 (P1)**: Depends on Foundational only
- **US2 (P2)**: Depends on Foundational + US1 (@mention capture widget)
- **US3 (P3)**: Depends on Foundational + FTS migration (T059); Sync adds cross-device validation
- **US4 (P4)**: Depends on US1 (bullets), US2 (people filter), US3 (filter engine)
- **US5 (P5)**: Depends on US1 (bullets query) + US2 (top interactions)

### Within Each Phase

- Table definitions (T008–T017) all parallelizable — different files
- DAO implementations (T024–T025, T034–T035, T072) all parallelizable — different files
- Go internal packages (T045–T047) parallelizable after T006
- Screen implementations parallelizable unless they share a dependency being actively built

---

## Parallel Opportunities per Phase

```text
Phase 1 (Setup) — Run T003–T006 simultaneously:
  T003  pubspec.yaml (Flutter)
  T004  CDK project (TypeScript)
  T005  analysis_options.yaml (Dart)
  T006  go.mod + Makefile (Go)

Phase 2 (Foundational) — Run T008–T017 simultaneously:
  T008  DayLogs table      T013  BulletTagLinks table
  T009  Bullets table      T014  Collections table
  T010  People table       T015  Reviews table
  T011  Tags table         T016  PendingSync table
  T012  BulletPersonLinks  T017  ConflictRecords table

Phase 3 (US1) — Run T024 + T025 simultaneously, then proceed:
  T024  BulletsDao
  T025  SyncDao

Phase 4 (US2) — Run T034 + T035 simultaneously:
  T034  PeopleDao
  T035  BulletPersonLinksDao

Phase 5 (Sync) — Go internal packages T045–T047 simultaneously, then T048+T049, then T050+T051+T052:
  T045  internal/auth/auth.go
  T046  internal/conflicts/conflicts.go
  T047  internal/pagination/pagination.go

Phase 6 (US3) — Run T061 + T062 simultaneously after T060:
  T061  SearchProvider
  T062  SearchScreen
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL — blocks all stories)
3. Complete Phase 3: User Story 1 (T024–T033)
4. **STOP and VALIDATE**: Launch app → capture bullets of all types → tags work → task status works → day navigation works → kill/relaunch retains all data
5. Ship or demo the local-only MVP

### Incremental Delivery

1. Phase 1 + 2 → Foundation ready
2. Phase 3 → US1 complete → **Local-first MVP** (capture, persist, offline)
3. Phase 4 → US2 complete → **People CRM** added
4. Phase 5 → Go backend + sync live → **Cross-device sync** (requires `make build && cdk deploy`)
5. Phase 6 → US3 complete → **Search** added
6. Phase 7 → US4 complete → **Collections** added
7. Phase 8 → US5 complete → **Reviews / Pro tier** added
8. Phase 9 → Polish + validation → **App Store ready**

### Solo Developer Strategy

Work sequentially in priority order: Phase 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9. Stop at any checkpoint to validate independently before proceeding. Use `[P]` tasks to batch work in parallel file sessions.

---

## Summary

| Phase | Tasks | User Story | Parallelizable |
| ----- | ----- | ---------- | -------------- |
| 1: Setup | T001–T006 | — | T003–T006 |
| 2: Foundational | T007–T023 | — | T008–T017 |
| 3: US1 Daily Capture | T024–T033 | P1 🎯 MVP | T024–T025 |
| 4: US2 People | T034–T044 | P2 | T034–T035 |
| 5: Sync Infrastructure | T045–T058 | Cross-cutting | T045–T047, T051–T052 |
| 6: US3 Search | T059–T064 | P3 | T061–T062 |
| 7: US4 Collections | T065–T071 | P4 | T065 |
| 8: US5 Reviews | T072–T080 | P5 | T072 |
| 9: Polish | T081–T089 | Cross-cutting | T081–T089 |
| **Total** | **89 tasks** | **5 stories** | **~35 tasks parallelizable** |

**MVP Scope**: Phases 1–3 (T001–T033, 33 tasks) deliver a fully functional local-first bullet journal for iOS.

**Remaining**: T002, T004, T006 (Go/CDK setup) + T045–T052 (Go backend) + T059–T089 (Search, Collections, Reviews, Polish) = **37 tasks pending**

---

## Notes

- **[P]** = different files, no blocking dependencies — safe to run as parallel agent tasks
- **[Story]** label maps each task to its user story for traceability
- Drift codegen (T019) must re-run after any schema change to tables
- All writes to local drift tables MUST also enqueue a `PendingSync` row (via `SyncDao.enqueuePendingSync`) — this is the offline queue contract
- `migrated_to_id` MUST only be set when `status = 'migrated'` — enforced in `BulletsDao.migrateBullet`
- **Go backend**: run `cd backend && make build` before `cdk deploy`; the `dist/pull_sync/bootstrap` and `dist/push_sync/bootstrap` binaries must exist before CDK synthesizes
- Run `cd app && flutter test` and `cd backend && go test ./...` after every phase to catch regressions early
- Go `DynamoDBAPI` interface (defined in `internal/conflicts/conflicts.go`) enables unit tests with mock implementations — no AWS credentials needed for `go test ./...`
