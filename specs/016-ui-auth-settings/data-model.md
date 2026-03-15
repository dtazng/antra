# Data Model: App UI Polish, Authentication Flow & Settings Tab

**Branch**: `016-ui-auth-settings` | **Date**: 2026-03-15

---

## New Entities (In-Memory / Secure Storage)

### AuthState *(sealed class, in-memory via Riverpod)*

Represents the current authentication lifecycle state. Not persisted; reconstructed from secure storage on app launch.

| Variant | Fields | Description |
|---------|--------|-------------|
| `AuthLoading` | — | Initial state while secure storage is being read |
| `Authenticated` | `userId: String`, `email: String` | Valid session exists |
| `Unauthenticated` | — | No session or session cleared |

---

### Session *(flutter_secure_storage)*

Tokens persisted securely on-device. Keys scoped to `auth_` prefix.

| Key | Type | Description |
|-----|------|-------------|
| `auth_access_token` | String | Short-lived JWT (expires per backend config) |
| `auth_refresh_token` | String | Long-lived refresh token UUID |
| `auth_user_id` | String (UUID) | Cached user ID for provider initialisation |
| `auth_user_email` | String | Cached email for display in Settings > Account |
| `app_theme_mode` | String (`system`\|`light`\|`dark`) | Theme preference (local-only) |

---

### UserSettings *(in-memory via Riverpod, synced from backend)*

Fetched from `GET /v1/settings` and mutated via `PATCH /v1/settings`.

| Field | Type | Description |
|-------|------|-------------|
| `notificationsEnabled` | bool | Master push notification switch |
| `followUpRemindersEnabled` | bool | Follow-up / reminder notification toggle |
| `defaultFollowUpDays` | int? | Default days before a follow-up is considered due |
| `quietHoursStart` | String? | HH:mm quiet hours start (local-only in this iteration) |
| `quietHoursEnd` | String? | HH:mm quiet hours end (local-only in this iteration) |

Backed by `user_settings` table in the Go backend DB.

---

### LinkedPerson *(value object, in-memory)*

A minimal person record held inside `TimelineEntry` and `BulletDetail` to avoid coupling the timeline layer to the full `PeopleData` model.

| Field | Type | Description |
|-------|------|-------------|
| `id` | String | Person UUID |
| `name` | String | Display name for chip label |

---

## Modified Entities

### TimelineEntry (LogEntryItem, CompletionEventItem) *(in-memory)*

**Change**: Replace single `personId`/`personName` fields with a list of `LinkedPerson`.

| Before | After |
|--------|-------|
| `personId: String?` | `persons: List<LinkedPerson>` |
| `personName: String?` | *(removed)* |

---

### BulletDetail *(passed to detail screen, in-memory)*

A new model aggregating all data shown in the redesigned log detail view. Constructed by `BulletDetailProvider` from local DB queries.

| Field | Type | Description |
|-------|------|-------------|
| `bulletId` | String | Unique identifier |
| `content` | String | Main log text |
| `type` | String | `note` \| `task` \| `event` |
| `status` | String? | `open` \| `done` \| `carried_over` |
| `createdAt` | DateTime | Local creation timestamp |
| `updatedAt` | DateTime? | Last edit timestamp |
| `persons` | List\<LinkedPerson\> | All linked persons |
| `followUpDate` | String? | YYYY-MM-DD; null = no follow-up |
| `followUpStatus` | String? | `pending` \| `done` \| `snoozed` \| `dismissed` |

---

## Unchanged Entities (Referenced)

These entities are not modified by this feature. They are listed for context.

| Entity | Storage | Notes |
|--------|---------|-------|
| `Bullet` | drift/SQLite `bullets` table | Log entries; no schema change |
| `BulletPersonLink` | drift/SQLite `bullet_person_links` table | M2M junction; already complete |
| `PeopleData` | drift/SQLite `people` table | Person profiles; no schema change |
| `FollowUp` | Columns on `bullets` table | `follow_up_date`, `follow_up_status` |

---

## Validation Rules

| Entity | Rule |
|--------|------|
| Session | Access token stored only in platform secure enclave; never logged |
| AuthState | Only `Authenticated` state may initiate API requests |
| UserSettings | `defaultFollowUpDays` must be ≥ 1 if present |
| LinkedPerson | `name` truncated at 16 chars for chip display; full name shown in tooltip/detail |

---

## State Transitions

### AuthState

```
AuthLoading
    ↓ secure storage read
    ├─ tokens found + valid → Authenticated
    ├─ tokens found + expired → attempt refresh → Authenticated (success) | Unauthenticated (failure)
    └─ no tokens → Unauthenticated

Unauthenticated
    ↓ successful login or register
    → Authenticated

Authenticated
    ↓ logout called | refresh fails | account deleted
    → Unauthenticated
```

### UserSettings.followUpRemindersEnabled

```
true (default)
    ↓ user toggles off → PATCH /v1/settings { follow_up_reminders_enabled: false }
false
    ↓ user toggles on → PATCH /v1/settings { follow_up_reminders_enabled: true }
true
```
