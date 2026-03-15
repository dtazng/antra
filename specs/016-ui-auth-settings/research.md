# Research: App UI Polish, Authentication Flow & Settings Tab

**Branch**: `016-ui-auth-settings` | **Date**: 2026-03-15

---

## 1. Authentication State Architecture in Flutter + Riverpod

**Decision**: Use an `AsyncNotifier<AuthState>` backed by `flutter_secure_storage` for session persistence. `AuthState` is a sealed class with three variants: `AuthLoading`, `Authenticated(user)`, `Unauthenticated`.

**Rationale**: `AsyncNotifier` handles the async session-check on first load naturally. The sealed class makes the three states exhaustive and eliminates null-checking. This is the idiomatic Riverpod 2.5 approach for auth.

**Alternatives considered**:
- `StateProvider<AuthState>` — simpler but no built-in async loading support; loading state is awkward to model
- `ChangeNotifier` — not idiomatic with code-gen Riverpod; rejected per constitution
- `FutureProvider` — read-only, no ability to mutate (login/logout); rejected

**Session storage keys** (all in `flutter_secure_storage`):
- `auth_access_token` — short-lived JWT
- `auth_refresh_token` — long-lived refresh token UUID
- `auth_user_id` — UUID, stored locally for quick access
- `auth_user_email` — email, stored locally for display in settings

---

## 2. Route Gating Without go_router

**Decision**: Use a `MaterialApp.home` that points to an `AuthGate` widget. `AuthGate` is a `ConsumerWidget` that watches the auth provider and returns either the `AuthScreen` or `RootTabScreen` based on the current state.

**Rationale**: The app does not use named routes or `go_router`. A simple `AuthGate` widget in the `home` slot is the lowest-friction way to add auth gating without restructuring navigation.

**Pattern**:
```dart
// In main.dart:
home: const AuthGate(),

// AuthGate widget:
class AuthGate extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    return authState.when(
      loading: () => const SplashScreen(),
      data: (state) => switch (state) {
        Authenticated() => const RootTabScreen(),
        Unauthenticated() => const AuthScreen(),
      },
      error: (_, __) => const AuthScreen(),
    );
  }
}
```

**Alternatives considered**:
- `go_router` with `redirect` — clean but would require refactoring all navigation in the app; too much scope creep
- `Navigator` guards via `WidgetsBindingObserver` — complex lifecycle coupling; rejected

---

## 3. JWT Token Handling in Plain `http` Package

**Decision**: Wrap `http.Client` in an `AuthHttpClient` that adds the `Authorization: Bearer <token>` header to every request. On 401, it attempts one refresh cycle using the stored refresh token; if refresh fails, it calls `authNotifier.logout()` to clear session and returns the 401.

**Rationale**: The app already uses the `http` package (`api_client.dart`). Adding a wrapper client avoids touching every call site and keeps token management in one place.

**Pattern**:
```dart
class AuthHttpClient extends http.BaseClient {
  final http.Client _inner;
  final AuthService _authService;

  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final token = await _authService.getAccessToken();
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    final response = await _inner.send(request);
    if (response.statusCode == 401) {
      final refreshed = await _authService.tryRefresh();
      if (refreshed) {
        // Retry once with new token
        final newToken = await _authService.getAccessToken();
        final retryRequest = _copyRequest(request, newToken);
        return _inner.send(retryRequest);
      } else {
        // Session dead — signal notifier
        await _authService.clearSession();
      }
    }
    return response;
  }
}
```

**Alternatives considered**:
- `dio` with interceptors — cleaner interceptor API but adds a new package; constitution prefers no unnecessary packages
- Manual token injection per call site — error-prone and brittle; rejected

---

## 4. Linked Persons Bug Root Cause

**Finding**: `PeopleDao.getLinkedPersonForBullet(bulletId)` returns a single `PeopleData?` — the first match only. The `TimelineEntry` model stores a single `personName`/`personId`. This is the root cause of person tags being dropped.

**Decision**: Add `getLinkedPeopleForBullet(bulletId) → Future<List<PeopleData>>` to `PeopleDao`. Update `TimelineEntry` models to store `List<LinkedPerson>` (where `LinkedPerson` is a minimal `{id, name}` record). Update timeline provider and card renderer accordingly.

**Chip layout decision**: Use Flutter's `Wrap` widget with `spacing: 6` and `runSpacing: 4` to lay out person chips. Each chip is a compact rounded container (height 20px, padding 6x4, font 11px). Long names truncate at 16 chars with ellipsis (`overflow: TextOverflow.ellipsis`, `maxWidth` constraint).

**Alternatives considered**:
- `SingleChildScrollView` (horizontal chip row) — hides overflow, violates spec; rejected
- Fixed-count display + "+N more" — hides data, violates spec; rejected

---

## 5. Backend Auth Integration

**Finding**: The existing `api_client.dart` uses AWS Amplify Cognito for authentication (`amplify_flutter`, `amplify_auth_cognito`). The new Go backend (specs/015-go-backend) uses JWT with email/password — a completely different auth system.

**Decision**:
- Replace Cognito auth in `api_client.dart` with `AuthHttpClient` (JWT Bearer tokens).
- `AuthService` handles all calls to the Go backend's auth endpoints.
- The `config.dart` `apiGatewayBaseUrl` will be reused as the base URL for the Go backend.
- The existing sync endpoints (`/sync/pull`, `/sync/push`) in `api_client.dart` will be migrated to the new Go backend URL format (`/v1/sync/{entityType}/pull` and `/v1/sync/{entityType}/push`) in a separate sync migration story; for this feature, only the auth and settings endpoints are wired.
- `amplify_flutter` and `amplify_auth_cognito` imports are removed from `api_client.dart`; Amplify init in `main.dart` is removed or guarded.

**New backend auth endpoint not in 015 spec**: `POST /v1/auth/change-password` must be added to the Go backend (documented in contracts/).

---

## 6. Settings Architecture

**Decision**:
- `UserSettingsNotifier` (`AsyncNotifier<UserSettings>`) fetches from `GET /v1/settings` on first read and caches in memory. Mutations call `PATCH /v1/settings` and update local cache.
- Theme preference stored locally in `flutter_secure_storage` (key: `app_theme_mode`); not synced to backend.
- Settings sub-screens are standard `Scaffold`-based screens pushed via `Navigator.push`.
- The Settings tab screen is a `ListView` with `ListTile`-based grouped rows using `Card` containers for visual grouping.

**Alternatives considered**:
- Storing all settings in local drift DB — adds schema complexity for simple key/value preferences; rejected
- Single flat settings screen — violates spec (requires dedicated detail pages per section); rejected

---

## 7. Log Detail View Design Decision

**Decision**: Replace `BulletDetailScreen` content area with a new layout:
- Header: type badge + time on one row
- Main content: full-width `SelectableText` with generous padding, supporting long text via scroll
- Metadata section: divider + linked persons (`Wrap` of chips) + follow-up card (if present)
- Activity footer: created/updated timestamps in muted text
- Actions: edit icon button in AppBar + bottom sheet triggered by overflow menu containing delete

**Quick actions** available in AppBar: Edit (pencil icon). Destructive action (Delete) in bottom sheet accessible via `...` menu to separate it visually from non-destructive actions.

**Transition**: Existing `MaterialPageRoute` is sufficient; no Hero animation needed as cards don't have a unique hero tag. The sheet-like presentation can be achieved with `DraggableScrollableSheet` or a standard full-screen Scaffold with soft background.

---

## Summary of New Packages Required

No new packages required. All functionality uses existing dependencies:
- `flutter_secure_storage` — already in `pubspec.yaml` (used for SQLCipher key)
- `http` — already in `pubspec.yaml` (used in `api_client.dart`)
- `flutter_riverpod` + `riverpod_annotation` — already in `pubspec.yaml`
- `drift` — no schema changes; already in `pubspec.yaml`
