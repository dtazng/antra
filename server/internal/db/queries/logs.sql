-- name: UpsertLog :one
INSERT INTO logs (id, user_id, content, type, status, day_id, device_id, created_at, updated_at)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, now())
ON CONFLICT (id) DO UPDATE
    SET content    = EXCLUDED.content,
        type       = EXCLUDED.type,
        status     = EXCLUDED.status,
        day_id     = EXCLUDED.day_id,
        device_id  = EXCLUDED.device_id,
        updated_at = now(),
        deleted_at = NULL
WHERE logs.updated_at <= EXCLUDED.updated_at
RETURNING id, user_id, content, type, status, day_id, device_id, created_at, updated_at, deleted_at;

-- name: SoftDeleteLog :one
UPDATE logs
SET deleted_at = now(), updated_at = now()
WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL
RETURNING id, user_id, content, type, status, day_id, device_id, created_at, updated_at, deleted_at;

-- name: GetLogsByUpdatedSince :many
SELECT id, user_id, content, type, status, day_id, device_id, created_at, updated_at, deleted_at
FROM logs
WHERE user_id = $1 AND updated_at > $2
ORDER BY updated_at ASC
LIMIT $3;

-- name: ListLogs :many
SELECT id, user_id, content, type, status, day_id, device_id, created_at, updated_at, deleted_at
FROM logs
WHERE user_id = $1 AND deleted_at IS NULL
ORDER BY day_id DESC
LIMIT $2 OFFSET $3;

-- name: GetLogByID :one
SELECT id, user_id, content, type, status, day_id, device_id, created_at, updated_at, deleted_at
FROM logs
WHERE id = $1 AND user_id = $2
LIMIT 1;

-- name: UpdateLog :one
UPDATE logs
SET content    = coalesce(sqlc.narg(content), content),
    type       = coalesce(sqlc.narg(type), type),
    status     = coalesce(sqlc.narg(status), status),
    updated_at = now()
WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL
RETURNING id, user_id, content, type, status, day_id, device_id, created_at, updated_at, deleted_at;
