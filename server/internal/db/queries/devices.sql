-- name: UpsertDeviceToken :one
INSERT INTO device_tokens (user_id, token, platform, is_active)
VALUES ($1, $2, $3, true)
ON CONFLICT (token) DO UPDATE
    SET user_id   = EXCLUDED.user_id,
        platform  = EXCLUDED.platform,
        is_active = true,
        updated_at = now()
RETURNING *;

-- name: DeactivateDeviceToken :exec
UPDATE device_tokens
SET is_active = false, updated_at = now()
WHERE id = $1 AND user_id = $2;

-- name: GetActiveDeviceTokens :many
SELECT * FROM device_tokens
WHERE user_id = $1 AND is_active = true;
