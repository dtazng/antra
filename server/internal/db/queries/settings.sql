-- name: GetOrCreateUserSettings :one
INSERT INTO user_settings (user_id)
VALUES ($1)
ON CONFLICT (user_id) DO UPDATE
    SET user_id = EXCLUDED.user_id
RETURNING *;

-- name: UpdateUserSettings :one
UPDATE user_settings
SET notifications_enabled         = coalesce(sqlc.narg(notifications_enabled), notifications_enabled),
    default_follow_up_days        = coalesce(sqlc.narg(default_follow_up_days), default_follow_up_days),
    inactivity_follow_ups_enabled = coalesce(sqlc.narg(inactivity_follow_ups_enabled), inactivity_follow_ups_enabled),
    inactivity_threshold_days     = coalesce(sqlc.narg(inactivity_threshold_days), inactivity_threshold_days),
    updated_at                    = now()
WHERE user_id = $1
RETURNING *;
