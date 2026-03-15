# Quickstart & Integration Scenarios

**Branch**: `016-ui-auth-settings` | **Date**: 2026-03-15

---

## Prerequisites

```bash
# Backend running (from specs/015-go-backend)
cd server && docker compose up -d
make migrate-up

# Flutter app
cd app && flutter pub get
dart run build_runner build --delete-conflicting-outputs

# Run on iOS simulator
flutter run -d "iPhone 16"
```

---

## Scenario 1: Fresh Install → Register → Main App

**Goal**: Verify the auth gate routes an unauthenticated user to login, and registration works end-to-end.

```
1. Launch app on fresh simulator (no keychain data)
   → Expected: AuthScreen shows with Login view

2. Tap "Create account"
   → Expected: Register view shows

3. Enter email: test@example.com, password: password123
   Tap "Create account"
   → Expected: Loading state visible briefly
   → Expected: RootTabScreen appears with Timeline tab active

4. Force-quit app and relaunch
   → Expected: RootTabScreen appears directly (no auth screen)
   → Expected: app_theme_mode not set → uses system theme
```

---

## Scenario 2: Logout → Session Cleared

**Goal**: Verify logout clears session and routes back to login.

```
1. App is open in authenticated state (from Scenario 1)

2. Tap Settings tab (rightmost tab icon)
   → Expected: SettingsScreen with Account, Notifications, Appearance, ... sections

3. Tap "Account"
   → Expected: AccountDetailScreen with email shown

4. Tap "Logout"
   → Expected: Confirmation dialog appears

5. Confirm logout
   → Expected: AuthScreen shown, session cleared
   → Verify: flutter_secure_storage keys auth_access_token, auth_refresh_token cleared

6. Relaunch app
   → Expected: AuthScreen shown (not main app)
```

---

## Scenario 3: Expired Session → Graceful Redirect

**Goal**: Verify that a 401 response triggers token refresh, and if refresh fails, routes to login.

```
1. Start app with valid session

2. Simulate expired access token:
   - Manually delete auth_access_token from secure storage
   - Or wait for token to expire (15 min by default)

3. Navigate to any screen that triggers an API call (e.g., Settings tab)
   → Expected: App attempts refresh using auth_refresh_token
   → If refresh succeeds: request retried, screen loads normally
   → If refresh fails (or token deleted): AuthScreen shown with
     "Your session has expired. Please log in again." message
```

---

## Scenario 4: Linked Persons — All Tags Shown

**Goal**: Verify all linked persons render as chips with no silent drops.

```
1. Create a log entry linked to 4 persons:
   - "Alice" (short name)
   - "Bob Smith" (medium name)
   - "Dr. Christopher Wellington III" (long name — truncates)
   - "Maria" (short name)

2. View the timeline
   → Expected: All 4 chips visible on card, wrapping to second line if needed
   → "Dr. Christopher Wellington..." truncated with ellipsis

3. Tap the log card
   → Expected: Log detail view shows all 4 chips

4. Tap "Alice" chip in detail view
   → Expected: PersonProfileScreen opens for Alice

5. Force-quit and relaunch
   → Expected: All 4 links still present
```

---

## Scenario 5: Timeline Card — No Dot

**Goal**: Confirm the dot is removed and cards still feel structured.

```
1. Open the timeline with multiple log entries
   → Expected: No 6px dot appears to the left of any log card content
   → Expected: Completion event cards still show checkmark icon
   → Expected: Cards still visually distinct from date separators
   → Expected: Spacing around content is clean and intentional
```

---

## Scenario 6: Log Detail View — Redesigned Layout

**Goal**: Verify the redesigned detail view shows all sections correctly.

```
1. Create a log with:
   - Content: "Long text that should be fully readable..."
   - Type: note
   - 2 linked persons
   - A follow-up set for tomorrow

2. Tap the log on the timeline
   → Expected: Detail view opens with smooth transition
   → Expected: Content section shows full text
   → Expected: Type badge visible (e.g. "note")
   → Expected: Created timestamp shown
   → Expected: Both person chips shown (tappable)
   → Expected: Follow-up section shows due date and status
   → Expected: Edit button in AppBar
   → Expected: "..." overflow menu available

3. Tap "..." → Tap "Delete"
   → Expected: Confirmation dialog
   → Confirm → log removed from timeline
```

---

## Scenario 7: Settings — Notification Preference Sync

**Goal**: Verify notification settings are persisted and synced to backend.

```
1. Navigate to Settings → Notifications

2. Toggle "Follow-up reminders" off
   → Expected: Toggle switches off immediately
   → Expected: PATCH /v1/settings called with follow_up_reminders_enabled: false

3. Navigate away and back to Settings → Notifications
   → Expected: Toggle still off (loaded from cache)

4. Force-quit and relaunch → Settings → Notifications
   → Expected: Toggle still off (loaded from backend via GET /v1/settings on next auth)
```

---

## Scenario 8: Theme Selection

**Goal**: Verify theme preference persists locally.

```
1. Navigate to Settings → Appearance

2. Select "Light" theme
   → Expected: App switches to light theme immediately
   → Expected: app_theme_mode = 'light' written to secure storage

3. Force-quit and relaunch
   → Expected: App opens in light theme
```

---

## Scenario 9: Password Change

**Goal**: Verify password change works and session is maintained.

```
1. Navigate to Settings → Account → Change Password

2. Enter current password (correct) and new password
   Tap "Save"
   → Expected: 204 response, snackbar "Password updated"
   → Expected: User remains logged in with new tokens if server re-issues

3. Repeat with incorrect current password
   → Expected: Inline error "Current password is incorrect"
```
