# Tasks: App UI Polish, Authentication Flow & Settings Tab

**Input**: Design documents from `/specs/016-ui-auth-settings/`
**Prerequisites**: plan.md ✅ spec.md ✅ research.md ✅ data-model.md ✅ contracts/ ✅ quickstart.md ✅

**Organization**: Tasks grouped by user story for independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this belongs to (US1–US5)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Add the `LinkedPerson` value object and `PersonChip` widget that are shared by all user stories. No existing files are modified in this phase.

- [X] T001 Create `app/lib/models/linked_person.dart` — `LinkedPerson` record class with `id: String` and `name: String` fields; no drift dependency
- [X] T002 Create `app/lib/widgets/person_chip.dart` — `PersonChip` stateless widget: compact rounded chip (height 20, horizontal padding 8, vertical padding 4, font 11px) rendering `LinkedPerson.name` with `overflow: TextOverflow.ellipsis` and `maxWidth` constraint of 120; accepts optional `onTap` callback

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure shared by all user stories — `AuthService`, `AuthNotifier`, `AuthGate`, `UserSettingsService`, `UserSettingsNotifier`, and the `AuthHttpClient` HTTP wrapper. These must be complete before any user story work begins.

**⚠️ CRITICAL**: No user story implementation begins until this phase is complete.

- [X] T003 Create `app/lib/models/auth_state.dart` — sealed class `AuthState` with variants `AuthLoading`, `Authenticated({userId, email})`, `Unauthenticated`; and `AuthResult` value class with `userId`, `email`, `accessToken`, `refreshToken`, `expiresIn` fields
- [X] T004 Create `app/lib/models/user_settings.dart` — `UserSettings` class with fields: `notificationsEnabled: bool`, `followUpRemindersEnabled: bool`, `defaultFollowUpDays: int?`; plus `UserSettingsPatch` with all nullable fields for partial updates; both with `toJson`/`fromJson`
- [X] T005 Create `app/lib/services/auth_service.dart` — `AuthService` class: `login(email, password)→AuthResult`, `register(email, password)→AuthResult`, `tryRefresh()→bool`, `logout(refreshToken)→void`, `changePassword(currentPassword, newPassword)→void`, `getAccessToken()→String?`, `clearSession()→void`; uses `flutter_secure_storage` keys `auth_access_token`, `auth_refresh_token`, `auth_user_id`, `auth_user_email`; calls backend endpoints from `contracts/api-contracts.md` using `http` package; base URL from `AppConfig.apiGatewayBaseUrl`
- [X] T006 Create `app/lib/services/user_settings_service.dart` — `UserSettingsService` class: `getSettings()→UserSettings` calls `GET /v1/settings`, `updateSettings(UserSettingsPatch)→UserSettings` calls `PATCH /v1/settings`; requires Bearer token injected via constructor
- [X] T007 Create `app/lib/services/auth_http_client.dart` — `AuthHttpClient extends http.BaseClient`: overrides `send()` to attach `Authorization: Bearer <token>` header; on 401 response attempts one refresh cycle via `AuthService.tryRefresh()`; on refresh failure calls `AuthService.clearSession()` and invokes `onAuthFailure` callback; on refresh success retries original request with new token
- [X] T008 Create `app/lib/providers/auth_provider.dart` — `@riverpod class AuthNotifier extends _$AuthNotifier`: `build()` reads tokens from secure storage and returns initial `AuthState`; exposes `login(email, password)`, `register(email, password)`, `logout()`, `signalSessionExpired()` methods that mutate state; uses `AuthService`
- [X] T009 Create `app/lib/providers/user_settings_provider.dart` — `@riverpod class UserSettingsNotifier extends _$UserSettingsNotifier`: `build()` calls `UserSettingsService.getSettings()`; exposes `update(UserSettingsPatch)` that calls `updateSettings` and refreshes local state; handles loading/error states
- [X] T010 Run `dart run build_runner build --delete-conflicting-outputs` in `app/` to generate `auth_provider.g.dart` and `user_settings_provider.g.dart`

**Checkpoint**: `dart analyze app/lib/providers/auth_provider.dart` passes; `AuthNotifier` can be instantiated in tests.

---

## Phase 3: US1 — Authentication Flow (Priority: P1) 🎯 MVP

**Goal**: Unauthenticated users land on a login/register screen. Authenticated users go directly to the main app. Sessions persist across restarts. Expired sessions redirect gracefully.

**Independent Test**: Fresh install → login screen shown. Register → main app. Force-quit + relaunch → main app (no login). Logout → login screen.

- [X] T011 [US1] Create `app/lib/screens/auth/auth_screen.dart` — full `AuthScreen` widget: two inline views switchable via tab or text link — Login view (email + password fields, "Log in" button, "Create account" link) and Register view (email + password + confirm-password fields, "Create account" button, "Log in" link); handles loading spinner on submit, inline error display for 401/409/422 responses, basic email format validation and min-8-char password validation; uses `AuthNotifier` via `ref.read`
- [X] T012 [US1] Create `app/lib/screens/auth/auth_gate.dart` — `AuthGate extends ConsumerWidget`: watches `authNotifierProvider`; returns `SplashScreen` while loading, `AuthScreen` when `Unauthenticated`, `RootTabScreen` when `Authenticated`; also shows non-blocking "Session expired" `SnackBar` when `signalSessionExpired` was the cause of transition to `Unauthenticated`
- [X] T013 [US1] Create `app/lib/screens/auth/splash_screen.dart` — `SplashScreen`: full-screen scaffold with centered app logo or aurora background plus a subtle loading indicator; no text; shown only during the brief async session check on cold launch
- [X] T014 [US1] Modify `app/lib/main.dart` — replace `home: const RootTabScreen()` (and `_SyncObserver` wrapper) with `home: const AuthGate()`; remove Amplify initialization block (lines that call `Amplify.addPlugin` and `Amplify.configure`); remove `amplify_flutter` and `amplify_auth_cognito` imports; keep `_SyncObserver` class but ensure it wraps inside `AuthGate` for the authenticated path
- [X] T015 [US1] Modify `app/lib/services/api_client.dart` — remove `amplify_auth_cognito` and `amplify_flutter` imports; replace `_accessToken()` method with call to `AuthService.getAccessToken()` (injected via constructor); wrap inner `http.Client` with `AuthHttpClient`; update constructor to accept optional `AuthService` parameter; keep all existing sync endpoint methods unchanged

---

## Phase 4: US2 — Settings Tab (Priority: P2)

**Goal**: Logged-in user taps Settings tab and navigates to all 6 section detail pages. Notification preferences sync to backend. Theme persists locally. Logout works with confirmation.

**Independent Test**: Tap Settings tab → all sections render. Toggle follow-up reminders off → relaunch → toggle still off. Logout → confirm → login screen shown.

- [X] T016 [US2] Create `app/lib/screens/settings/settings_screen.dart` — `SettingsScreen`: `Scaffold` with custom app bar ("Settings") and a `ListView` with grouped `Card` sections; Section 1 "Account" (email row + chevron); Section 2 "Notifications" (chevron); Section 3 "Appearance" (chevron); Section 4 "Privacy & Security" (chevron); Section 5 "Sync & Data" (chevron); Section 6 "About" (chevron); each row navigates to its detail screen via `Navigator.push`
- [X] T017 [P] [US2] Create `app/lib/screens/settings/account_settings_screen.dart` — `AccountSettingsScreen`: shows current email (read from `authNotifierProvider`); "Change Password" row that navigates to `ChangePasswordScreen`; visually separated "Logout" `ListTile` in red/destructive styling at bottom; logout taps show `AlertDialog` confirmation — confirm calls `authNotifier.logout()`
- [X] T018 [P] [US2] Create `app/lib/screens/settings/change_password_screen.dart` — `ChangePasswordScreen`: form with current password, new password, confirm new password fields; validates new password ≥ 8 chars and matches confirm; on submit calls `AuthService.changePassword()`; shows success `SnackBar` or inline error on 401 (wrong current password)
- [X] T019 [P] [US2] Create `app/lib/screens/settings/notifications_settings_screen.dart` — `NotificationsSettingsScreen`: watches `userSettingsNotifierProvider`; toggle "Push notifications" binds to `notificationsEnabled`; toggle "Follow-up reminders" binds to `followUpRemindersEnabled`; "Default follow-up days" row shows current value with number picker; any change calls `userSettingsNotifier.update(patch)`
- [X] T020 [P] [US2] Create `app/lib/screens/settings/appearance_settings_screen.dart` — `AppearanceSettingsScreen`: three-option selector (System / Light / Dark) that reads/writes `app_theme_mode` key in `flutter_secure_storage`; selected option highlighted; on change, calls a `themeNotifier` (see T021) to apply theme immediately
- [X] T021 [P] [US2] Create `app/lib/providers/theme_provider.dart` — `@riverpod class ThemeNotifier extends _$ThemeNotifier`: `build()` reads `app_theme_mode` from `flutter_secure_storage` and returns `ThemeMode`; exposes `setTheme(ThemeMode)` that writes to storage and updates state; no backend sync
- [X] T022 [P] [US2] Create `app/lib/screens/settings/sync_settings_screen.dart` — `SyncSettingsScreen`: displays last sync timestamp from `syncStatusNotifierProvider`; "Sync now" button calls `syncStatusNotifierProvider.notifier.triggerSync()`; shows loading spinner during sync; shows result snackbar on completion
- [X] T023 [P] [US2] Create `app/lib/screens/settings/privacy_settings_screen.dart` — `PrivacySettingsScreen`: static informational screen listing: "All data encrypted on device", "Sync uses your account credentials only", "No analytics or tracking"; includes "Delete Account" row (placeholder — shows "Contact support" dialog for now)
- [X] T024 [P] [US2] Create `app/lib/screens/settings/about_screen.dart` — `AboutScreen`: shows app name, version string (hard-coded from `pubspec.yaml` or `PackageInfo` if available), "Privacy Policy" `ListTile` (URL launcher placeholder), "Support" `ListTile` (mailto placeholder)
- [X] T025 [US2] Modify `app/lib/screens/root_tab_screen.dart` — add Settings as third tab: add `SettingsScreen()` to `_screens` list; add `_TabItem(icon: Icons.settings_outlined, label: 'Settings')` to `_tabs` list; update `_FloatingTabBar` to render all 3 tabs with equal spacing
- [X] T026 [US2] Modify `app/lib/main.dart` — wire `ThemeNotifier` into `MaterialApp`: watch `themeNotifierProvider` and bind result to `MaterialApp.themeMode`; use existing `app_theme.dart` themes for `theme` (light) and `darkTheme` (dark)

---

## Phase 5: US3 — Log Detail View Redesign (Priority: P3)

**Goal**: Tapping a log card opens a redesigned detail view showing content, type badge, timestamps, all linked persons as tappable chips, follow-up block, and action buttons. Long text scrollable. Dismissal returns to same timeline position.

**Independent Test**: Open any log → verify all sections present. Tap person chip → person detail opens. Edit → form pre-filled. Delete with confirm → log removed.

- [X] T027 [US3] Create `app/lib/models/bullet_detail.dart` — `BulletDetail` class: `bulletId`, `content`, `type`, `status`, `createdAt: DateTime`, `updatedAt: DateTime?`, `persons: List<LinkedPerson>`, `followUpDate: String?`, `followUpStatus: String?`; factory constructor `BulletDetail.fromBullet(BulletData bullet, List<LinkedPerson> persons)`
- [X] T028 [US3] Create `app/lib/providers/bullet_detail_provider.dart` — `@riverpod Future<BulletDetail> bulletDetail(ref, String bulletId)`: fetches bullet by id from `BulletsDao`, fetches linked persons via `PeopleDao.getLinkedPeopleForBullet(bulletId)` (see T030), constructs and returns `BulletDetail`
- [X] T029 [US3] Modify `app/lib/screens/daily_log/bullet_detail_screen.dart` — replace existing content layout with redesigned layout: (1) AppBar with log type badge (e.g. "note" pill) and edit `IconButton`; (2) `SingleChildScrollView` body containing: content section (`SelectableText`, 16px, generous padding), divider, persons section (`Wrap` of `PersonChip` widgets each with `onTap → PersonProfileScreen`), divider (if follow-up present), follow-up section (due date + status badge in `GlassSurface` card), divider, activity section (created/updated timestamps in muted 11px text); (3) floating `...` icon button opening bottom sheet with "Delete" destructive tile — delete shows `AlertDialog` confirmation then pops screen on confirm; reads data from `bulletDetailProvider`

---

## Phase 6: US4 — Linked Persons Tagging Fix (Priority: P4)

**Goal**: All linked persons render as chips on timeline cards and detail views. No silent drops. Chips wrap, truncate gracefully. Links persist across restarts.

**Independent Test**: Create log with 4 persons → all 4 chips on timeline card. Relaunch → still 4. Open detail → still 4. Tap chip → person detail.

- [X] T030 [US4] Modify `app/lib/database/daos/people_dao.dart` — add `getLinkedPeopleForBullet(String bulletId) → Future<List<PeopleData>>`: joins `bullet_person_links` and `people` tables where `bullet_id = bulletId` AND `is_deleted = 0`, ordered by `link_type` then `people.name`; this replaces/supplements the existing `getLinkedPersonForBullet` (singular) method
- [X] T031 [US4] Modify `app/lib/models/timeline_entry.dart` — replace `personId: String?` and `personName: String?` fields in `LogEntryItem` and `CompletionEventItem` with `persons: List<LinkedPerson>`; update all constructors and usages; keep backward-compatible if `persons` is empty
- [X] T032 [US4] Modify `app/lib/providers/timeline_provider.dart` — replace `peopleDao.getLinkedPersonForBullet(bullet.id)` call (line 52) with `peopleDao.getLinkedPeopleForBullet(bullet.id)`; map result to `List<LinkedPerson>`; pass to `LogEntryItem(persons: ...)` and `CompletionEventItem(persons: ...)`
- [X] T033 [US4] Modify `app/lib/screens/timeline/timeline_screen.dart` — in `_EntryCard.build()`: remove the `Text(personName)` display and replace with a `Wrap(spacing: 6, runSpacing: 4, children: entry.persons.map((p) => PersonChip(person: p)).toList())` below the content text; only render `Wrap` when `entry.persons.isNotEmpty`

---

## Phase 7: US5 — Timeline Card Cleanup (Priority: P5)

**Goal**: Remove the 6px dot from timeline log cards. Date separators remain distinct. Card spacing stays clean.

**Independent Test**: Open timeline → zero dots visible on any log card. Completion event checkmarks still present. Date separators still visually distinct.

- [X] T034 [US5] Modify `app/lib/screens/timeline/timeline_screen.dart` — in `_EntryCard.build()`: remove the `Padding` widget containing the dot `Container` (lines ~408–421 that render the `isCompletion` check-circle or 6px `Container`); remove the `right: 12` spacing from its enclosing padding; adjust `Row` children so content column expands to fill the freed space while time label remains right-aligned; keep the `check_circle_outline` icon for completion events only if desired, otherwise remove both

---

## Phase 8: US1 Backend — Change Password Endpoint (Go backend)

**Goal**: Add `POST /v1/auth/change-password` to the Go backend so the Flutter app's Change Password screen has a working endpoint.

**Independent Test**: `POST /v1/auth/change-password` with valid Bearer + correct current password → 204. With wrong current password → 401. With too-short new password → 422.

- [X] T035 [US1] Modify `server/internal/db/queries/users.sql` — add `UpdateUserPasswordHash` query: `UPDATE users SET password_hash = $2, updated_at = now() WHERE id = $1 AND deleted_at IS NULL RETURNING id`; add `DeleteAllUserRefreshTokens` query: `DELETE FROM refresh_tokens WHERE user_id = $1`
- [X] T036 [US1] Run `sqlc generate` in `server/` to regenerate `server/internal/db/sqlc/users.sql.go` with the two new queries
- [X] T037 [US1] Modify `server/internal/service/auth.go` — add `ChangePassword(ctx, userID uuid.UUID, currentPassword, newPassword string) error`: fetches user by ID, verifies current password with `VerifyPassword`, hashes new password with `HashPassword`, calls `UpdateUserPasswordHash`, then calls `DeleteAllUserRefreshTokens` to invalidate all sessions; returns `ErrInvalidCredentials` if current password wrong; returns `ErrPasswordTooShort` if new password < 8 chars
- [X] T038 [US1] Modify `server/internal/api/v1/auth.go` — add `changePassword` handler: `POST /auth/change-password` protected by `BearerAuth` middleware; reads `{current_password, new_password}` JSON body; calls `authSvc.ChangePassword`; returns 204 on success, 401 on wrong current password, 422 on validation failure; register route in `Routes()` with `r.With(middleware.BearerAuth(h.jwtSecret)).Post("/change-password", h.changePassword)`

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Wire all pieces together, run build\_runner, update CLAUDE.md, validate build.

- [X] T039 Run `dart run build_runner build --delete-conflicting-outputs` in `app/` to regenerate all `.g.dart` files after all provider additions and model changes
- [X] T040 Verify `app/lib/screens/auth/sign_in_screen.dart` — replace file contents with a simple redirect/stub that `Navigator.pushReplacement`s to `AuthScreen` (or delete file if no other references); confirm no dead Cognito code remains in the codebase via `grep -r "amplify_auth" app/lib/`
- [X] T041 Update `CLAUDE.md` Active Technologies section — add entry for `016-ui-auth-settings`: `flutter_secure_storage (JWT session), AuthHttpClient (http.BaseClient wrapper), AuthNotifier (Riverpod AsyncNotifier), no new packages`
- [X] T042 Run `flutter analyze app/` — fix all errors and warnings introduced by this feature; in particular check that `timeline_entry.dart` usages of the removed `personName`/`personId` fields are all updated
- [X] T043 Run `flutter build apk --debug` (or `flutter build ios --debug --no-codesign`) to confirm the release build compiles without errors

---

## Dependencies

```
Phase 1 (Setup — LinkedPerson, PersonChip)
    └── Phase 2 (Foundational — AuthService, AuthNotifier, UserSettingsNotifier)
            ├── Phase 3 (US1 Auth Flow) ← MVP deployable after this
            │       ├── Phase 4 (US2 Settings — depends on AuthNotifier + UserSettingsNotifier)
            │       └── Phase 8 (US1 Backend — change-password endpoint; depends on Phase 3 to use)
            ├── Phase 5 (US3 Log Detail — depends on Phase 6 for linked persons data)
            └── Phase 6 (US4 Linked Persons Fix — depends on Phase 1 for PersonChip + LinkedPerson)
                    └── Phase 5 (US3 Log Detail — uses getLinkedPeopleForBullet from Phase 6)

Phase 7 (US5 Timeline Cleanup — independent of all user stories after Phase 1)
Phase 9 (Polish — depends on all phases)
```

Note: US5 (Timeline Card Cleanup) is independent of all auth and settings work and can be implemented alongside any phase after Phase 1.

---

## Parallel Execution Opportunities

**Phase 4 (US2 Settings)**: T017–T024 are all independent detail screens — all 8 can run in parallel.

**Phase 5 + Phase 6**: Once Phase 6's T030–T032 are done, T033 (timeline card chips) and T029 (detail screen chips) can run in parallel.

**Phase 7**: T034 (dot removal) is a single-file change that can run at any time after Phase 1.

**Phase 8 (Backend)**: T035–T038 are all in separate files and can run in parallel after T035.

---

## Implementation Strategy (MVP First)

**MVP (Phases 1–3, T001–T015)**: Working auth flow — app routes to login screen for new users, session persists, expired sessions handled gracefully. Flutter app connects to the Go backend for login/register/refresh/logout. Deployable independently.

**Increment 2 (Phase 4, T016–T026)**: Full settings tab with all 6 sections, notification preferences synced to backend, theme persists locally, logout with confirmation.

**Increment 3 (Phases 5–6, T027–T033)**: Redesigned log detail view with full linked-persons chips, tappable to person detail. Person tagging bug fixed end-to-end.

**Increment 4 (Phase 7, T034)**: Timeline card dot removed. Cosmetic but instantly noticeable.

**Increment 5 (Phase 8, T035–T038)**: Change-password endpoint in Go backend, enabling the Change Password screen in Settings.

**Final (Phase 9, T039–T043)**: Wire, analyze, build-validate, document.

---

## Independent Test Criteria Per Story

| Story | Independent Test |
| ----- | --------------- |
| US1 Auth | Fresh install → login screen. Register → main app. Relaunch → main app. Logout → login screen. |
| US2 Settings | Settings tab renders all 6 sections. Toggle off → relaunch → still off. Logout with confirm → login. |
| US3 Log Detail | Open log → all sections render. Person chip tappable. Edit pre-filled. Delete with confirm. |
| US4 Linked Persons | 4-person log → all 4 chips on timeline card. Relaunch → still 4 chips present. |
| US5 Timeline Cleanup | No dots on timeline cards. Date separators still distinct. |
