# Implementation Plan: App UI Polish, Authentication Flow & Settings Tab

**Branch**: `016-ui-auth-settings` | **Date**: 2026-03-15 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/016-ui-auth-settings/spec.md`

---

## Summary

Replace the Cognito auth stub with a full JWT-based authentication flow connected to the Go backend (015-go-backend). Add an `AuthGate` widget that routes unauthenticated users to a new `AuthScreen` and authenticated users directly to the main app. Add a Settings tab as a third tab in the existing `RootTabScreen`. Fix the linked-persons bug by adding a plural DAO query and updating the `TimelineEntry` model to hold a list of linked persons. Remove the dot from timeline cards. Redesign the log detail view. No new packages are required.

---

## Technical Context

**Language/Version**: Dart 3.3+ / Flutter 3.19+
**Primary Dependencies**: flutter_riverpod 2.5 + riverpod_annotation 2.3, drift 2.18, flutter_secure_storage (existing), http (existing), intl 0.19, uuid 4.x — **no new packages**
**Storage**: SQLite via drift + SQLCipher (no schema change); flutter_secure_storage for session tokens (existing)
**Testing**: flutter_test (unit + widget); no new test packages
**Target Platform**: iOS 15+, Android 8+
**Project Type**: Mobile app (Flutter)
**Performance Goals**: Auth gate resolves in < 500ms on cold launch; timeline scroll at 60 fps; all existing performance budgets maintained
**Constraints**: No new packages; Amplify/Cognito references removed from auth path; local-first DB unchanged
**Scale/Scope**: Single-user app; settings are per-user; ~3 new screens, ~5 modified files, ~8 new files

---

## Constitution Check

*GATE: Must pass before implementation begins. Re-checked after Phase 1 design.*

### I. Code Quality

| Check | Status | Notes |
| ------- | -------- | ------- |
| Single responsibility | ✅ PASS | `AuthService` handles tokens only; `UserSettingsService` handles settings only; UI screens delegate to notifiers |
| No dead code | ✅ PASS | Cognito imports removed from `api_client.dart`; unused `sign_in_screen.dart` replaced, not supplemented |
| Consistency over cleverness | ✅ PASS | Follows existing Riverpod code-gen patterns; `AuthGate` mirrors how `appDatabaseProvider` is watched elsewhere |
| Error handling at boundaries | ✅ PASS | Auth errors handled in `AuthService` (boundary); UI consumes `AsyncValue` states; internal code not defensively guarded |

### II. Testing Standards

| Check | Status | Notes |
| ------- | -------- | ------- |
| Acceptance scenario coverage | ✅ PASS | Each user story has acceptance scenarios; happy path + edge cases defined in quickstart.md |
| Offline behavior | ✅ PASS | Theme preference and settings changes tolerate offline; token refresh failure routes to login |
| Test independence | ✅ PASS | Auth tests use clean secure storage; no shared state between tests |

### III. UX Consistency

| Check | Status | Notes |
| ------- | -------- | ------- |
| Capture speed sacred | ✅ PASS | Auth gate does not appear for returning users; session check is async and shows `SplashScreen` only during cold load |
| Calm by default | ✅ PASS | No new badges, streaks, or unsolicited prompts introduced |
| Consistent affordances | ✅ PASS | Person chips use same radius and typography system as existing chips; Settings rows follow existing `ListTile` patterns |
| Graceful empty states | ✅ PASS | Auth screen handles unauthenticated cleanly; Settings sections with no data show appropriate placeholders |
| Destructive actions require confirmation | ✅ PASS | Logout shows confirmation dialog; log delete shows confirmation dialog |
| Offline-transparent UX | ✅ PASS | App behaves identically offline for all local features; sync status surfaced passively |

### IV. Performance Requirements

| Check | Status | Notes |
| ------- | -------- | ------- |
| App launch ≤ 2s | ✅ PASS | Session check reads from secure storage asynchronously; `SplashScreen` renders immediately, no blocking |
| Capture latency ≤ 500ms | ✅ PASS | No changes to bullet capture path |
| 60 fps scroll | ✅ PASS | Person chips use `Wrap` which is O(n) layout; chip count is bounded; no new animations in scroll path |
| Sync transparency | ✅ PASS | No new background sync tasks introduced |

### Privacy & Data Integrity

| Check | Status | Notes |
| ------- | -------- | ------- |
| Data encrypted at rest | ✅ PASS | Tokens in flutter_secure_storage (platform keychain/keystore); existing SQLCipher encryption unchanged |
| No silent remote overwrites | ✅ PASS | Settings PATCH is explicit user action; no sync overwrites local data |
| No analytics without consent | ✅ PASS | No new analytics introduced |

**GATE RESULT: ALL CHECKS PASS — proceed to implementation.**

---

## Project Structure

### Documentation (this feature)

```text
specs/016-ui-auth-settings/
├── spec.md              # Feature specification
├── plan.md              # This file
├── research.md          # Technical decisions and rationale
├── data-model.md        # Entity definitions and state transitions
├── quickstart.md        # Integration scenarios
├── contracts/
│   └── api-contracts.md # Backend endpoint contracts (incl. new change-password)
└── tasks.md             # Generated by /speckit.tasks
```

### Source Code Changes

```text
app/lib/
├── main.dart                              # MODIFY: remove Amplify init; home: AuthGate()
├── config.dart                            # MODIFY: add goBackendBaseUrl config key
├── models/
│   ├── timeline_entry.dart               # MODIFY: LogEntryItem/CompletionEventItem: List<LinkedPerson>
│   ├── linked_person.dart                # NEW: {id: String, name: String} value object
│   └── user_settings.dart                # NEW: UserSettings + UserSettingsPatch
├── services/
│   ├── auth_service.dart                 # NEW: login/register/refresh/logout/changePassword + secure storage
│   └── user_settings_service.dart        # NEW: getSettings/updateSettings HTTP calls
├── providers/
│   ├── auth_provider.dart                # NEW: AuthNotifier (AsyncNotifier<AuthState>)
│   ├── user_settings_provider.dart       # NEW: UserSettingsNotifier
│   └── timeline_provider.dart            # MODIFY: call getLinkedPeopleForBullet (plural)
├── database/daos/
│   └── people_dao.dart                   # MODIFY: add getLinkedPeopleForBullet method
├── screens/
│   ├── auth/
│   │   ├── auth_gate.dart                # NEW: ConsumerWidget routing on AuthState
│   │   ├── auth_screen.dart              # NEW: login/register views with field validation
│   │   └── sign_in_screen.dart          # REPLACE: legacy Cognito stub → redirect to auth_screen.dart
│   ├── settings/
│   │   ├── settings_screen.dart          # NEW: grouped settings root (AccountTile, NotificationsTile, etc.)
│   │   ├── account_settings_screen.dart  # NEW: email, change-password, logout
│   │   ├── notifications_settings_screen.dart  # NEW: toggles + backend sync
│   │   ├── appearance_settings_screen.dart     # NEW: theme picker (local only)
│   │   ├── privacy_settings_screen.dart        # NEW: privacy info + session management
│   │   ├── sync_settings_screen.dart     # NEW: last sync time + manual trigger
│   │   └── about_screen.dart             # NEW: version + privacy policy + support
│   ├── timeline/
│   │   └── timeline_screen.dart         # MODIFY: _EntryCard — remove dot, replace personName with chips
│   └── daily_log/
│       └── bullet_detail_screen.dart    # MODIFY: full redesign with new layout
├── root_tab_screen.dart                  # MODIFY: add Settings tab (3rd item)
└── widgets/
    └── person_chip.dart                  # NEW: compact rounded chip for person display
```

**Structure Decision**: Flutter mobile app, single project. All changes are additive to `app/lib/`. The Go backend (`server/`) gets one new endpoint (`POST /v1/auth/change-password`) which is the only backend change.

---

## Backend Change Required

A new endpoint must be added to the Go backend as part of this feature:

**`POST /v1/auth/change-password`** — full contract in `contracts/api-contracts.md`.

Files to add/modify in `server/`:

- `server/internal/db/queries/users.sql` — add `UpdateUserPassword` and `DeleteAllUserRefreshTokens` queries
- `server/internal/api/v1/auth.go` — add `changePassword` handler
- `server/internal/service/auth.go` — add `ChangePassword(userID, currentPassword, newPassword)` method

---

## Complexity Tracking

No constitution violations. No complexity justification required.

---

## Key Technical Decisions (from research.md)

| Decision | Choice | Rationale |
| ---------- | ------ | --------- |
| Auth state model | Sealed class `AuthState` in `AsyncNotifier` | Exhaustive matching; idiomatic Riverpod 2.5 |
| Route gating | `AuthGate` widget as `MaterialApp.home` | Zero navigation refactor; leverages existing stack |
| Token refresh | `AuthHttpClient` wrapping `http.BaseClient` | Single responsibility; no new packages |
| Linked persons display | `Wrap` widget with `LinkedPerson` list | Handles arbitrary count; wraps naturally |
| Theme storage | `flutter_secure_storage` key `app_theme_mode` | Consistent with token storage pattern; no new persistence layer |
| Settings sync | `UserSettingsNotifier` with in-memory cache + `PATCH /v1/settings` | Minimal latency; tolerates offline via cache |
