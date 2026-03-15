# API Contracts: App UI Polish, Authentication Flow & Settings Tab

**Branch**: `016-ui-auth-settings` | **Date**: 2026-03-15
**Backend**: Go backend (specs/015-go-backend), base URL configured in `app/lib/config.dart`

---

## Reused Endpoints (From 015-go-backend)

These endpoints are already implemented in the Go backend. The Flutter app will connect to them.

### POST /v1/auth/register

**Request**
```json
{
  "email": "user@example.com",
  "password": "securepassword"
}
```

**Success 201**
```json
{
  "user_id": "uuid",
  "email": "user@example.com",
  "access_token": "jwt-string",
  "refresh_token": "uuid-string",
  "expires_in": 900
}
```

**Error 409** — email already registered
```json
{ "error": "email_already_exists", "message": "An account with this email already exists." }
```

**Error 422** — validation failure
```json
{ "error": "validation_error", "message": "Password must be at least 8 characters." }
```

---

### POST /v1/auth/login

**Request**
```json
{
  "email": "user@example.com",
  "password": "securepassword"
}
```

**Success 200**
```json
{
  "user_id": "uuid",
  "email": "user@example.com",
  "access_token": "jwt-string",
  "refresh_token": "uuid-string",
  "expires_in": 900
}
```

**Error 401**
```json
{ "error": "invalid_credentials", "message": "Incorrect email or password." }
```

---

### POST /v1/auth/refresh

**Request**
```json
{ "refresh_token": "uuid-string" }
```

**Success 200**
```json
{
  "access_token": "new-jwt-string",
  "refresh_token": "new-uuid-string",
  "expires_in": 900
}
```

**Error 401**
```json
{ "error": "invalid_refresh_token", "message": "Refresh token is invalid or expired." }
```

---

### POST /v1/auth/logout

**Headers**: `Authorization: Bearer <access_token>`

**Request**
```json
{ "refresh_token": "uuid-string" }
```

**Success 204** — no body

---

### GET /v1/settings

**Headers**: `Authorization: Bearer <access_token>`

**Success 200**
```json
{
  "notifications_enabled": true,
  "follow_up_reminders_enabled": true,
  "default_follow_up_days": 7
}
```

---

### PATCH /v1/settings

**Headers**: `Authorization: Bearer <access_token>`

**Request** — partial update; omit fields that are not changing
```json
{
  "notifications_enabled": false,
  "follow_up_reminders_enabled": false,
  "default_follow_up_days": 3
}
```

**Success 200** — returns full updated settings object (same shape as GET /v1/settings)

---

## New Endpoint Required (Not In 015-go-backend)

### POST /v1/auth/change-password

**Purpose**: Allow an authenticated user to change their password.

**Headers**: `Authorization: Bearer <access_token>`

**Request**
```json
{
  "current_password": "oldpassword",
  "new_password": "newpassword123"
}
```

**Success 204** — no body; all existing refresh tokens for this user are invalidated

**Error 401** — current password incorrect
```json
{ "error": "invalid_current_password", "message": "Current password is incorrect." }
```

**Error 422** — new password too short
```json
{ "error": "validation_error", "message": "New password must be at least 8 characters." }
```

**Backend implementation notes**:
- Requires a new handler in `server/internal/api/v1/auth.go`
- Queries needed: `GetUserByID` (already exists), `UpdateUserPassword` (new sqlc query)
- After password update, call `DeleteRefreshToken` for all user tokens (or add `DeleteAllUserRefreshTokens` query)
- Apply `BearerAuth` middleware on this route

---

## Flutter Client Contracts (New Services)

### AuthService interface

```dart
abstract interface class AuthService {
  Future<AuthResult> login(String email, String password);
  Future<AuthResult> register(String email, String password);
  Future<bool> tryRefresh();
  Future<void> logout();
  Future<void> changePassword(String currentPassword, String newPassword);
  Future<String?> getAccessToken();
  Future<void> clearSession();
}
```

Where `AuthResult`:
```dart
class AuthResult {
  final String userId;
  final String email;
  final String accessToken;
  final String refreshToken;
  final int expiresIn;
}
```

### UserSettingsService interface

```dart
abstract interface class UserSettingsService {
  Future<UserSettings> getSettings();
  Future<UserSettings> updateSettings(UserSettingsPatch patch);
}
```

---

## Secure Storage Keys

| Key | Value Type | Description |
|-----|-----------|-------------|
| `auth_access_token` | String | Current JWT access token |
| `auth_refresh_token` | String | Current refresh token UUID |
| `auth_user_id` | String (UUID) | Logged-in user's ID |
| `auth_user_email` | String | Logged-in user's email |
| `app_theme_mode` | `system` \| `light` \| `dark` | Local theme preference |
| `db_encryption_key` | String (hex) | Existing SQLCipher key (unchanged) |

---

## Error Handling Contract (Client-Side)

| HTTP Status | Action |
|-------------|--------|
| 401 on any protected endpoint | Try refresh once; if refresh fails, clear session and route to login |
| 409 on register | Show "Email already in use" inline error |
| 422 | Show server `message` field as inline validation error |
| 5xx | Show generic "Something went wrong" snackbar with retry option |
| Network timeout | Show "No connection" snackbar; queue mutation for retry if applicable |
