-- name: CreateNotification :one
INSERT INTO notifications (user_id, follow_up_id, title, body, status)
VALUES ($1, $2, $3, $4, 'scheduled')
RETURNING *;

-- name: GetPendingNotifications :many
SELECT * FROM notifications
WHERE status = 'scheduled'
   OR (status = 'failed' AND retry_count < max_retries)
ORDER BY created_at ASC;

-- name: GetNotificationsByUser :many
SELECT * FROM notifications
WHERE user_id = $1
ORDER BY created_at DESC
LIMIT $2 OFFSET $3;

-- name: UpdateNotificationStatus :one
UPDATE notifications
SET status      = $2,
    retry_count = $3,
    updated_at  = now()
WHERE id = $1
RETURNING *;

-- name: DismissNotification :one
UPDATE notifications
SET status = 'dismissed', updated_at = now()
WHERE id = $1 AND user_id = $2
RETURNING *;
