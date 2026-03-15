-- name: UpsertFollowUp :one
INSERT INTO follow_ups (
    id, user_id, log_id, person_id, title, due_date, status,
    snoozed_until, is_recurring, recurrence_interval_days, recurrence_type,
    created_at, updated_at
)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, now())
ON CONFLICT (id) DO UPDATE
    SET title                    = EXCLUDED.title,
        due_date                 = EXCLUDED.due_date,
        status                   = EXCLUDED.status,
        snoozed_until            = EXCLUDED.snoozed_until,
        is_recurring             = EXCLUDED.is_recurring,
        recurrence_interval_days = EXCLUDED.recurrence_interval_days,
        recurrence_type          = EXCLUDED.recurrence_type,
        updated_at               = now(),
        deleted_at               = NULL
WHERE follow_ups.updated_at <= EXCLUDED.updated_at
RETURNING *;

-- name: SoftDeleteFollowUp :one
UPDATE follow_ups
SET deleted_at = now(), updated_at = now()
WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL
RETURNING *;

-- name: GetFollowUpsByUpdatedSince :many
SELECT * FROM follow_ups
WHERE user_id = $1 AND updated_at > $2
ORDER BY updated_at ASC
LIMIT $3;

-- name: ListFollowUps :many
SELECT * FROM follow_ups
WHERE user_id = $1
  AND deleted_at IS NULL
  AND ($2::text = '' OR status = $2)
ORDER BY due_date ASC
LIMIT $3 OFFSET $4;

-- name: GetFollowUpByID :one
SELECT * FROM follow_ups
WHERE id = $1 AND user_id = $2
LIMIT 1;

-- name: UpdateFollowUp :one
UPDATE follow_ups
SET title                    = coalesce(sqlc.narg(title), title),
    due_date                 = coalesce(sqlc.narg(due_date), due_date),
    status                   = coalesce(sqlc.narg(status), status),
    snoozed_until            = coalesce(sqlc.narg(snoozed_until), snoozed_until),
    completed_at             = coalesce(sqlc.narg(completed_at), completed_at),
    updated_at               = now()
WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL
RETURNING *;

-- name: MarkFollowUpsDue :many
UPDATE follow_ups
SET status = 'due', updated_at = now()
WHERE status IN ('pending', 'snoozed')
  AND due_date <= CURRENT_DATE
  AND (snoozed_until IS NULL OR snoozed_until <= CURRENT_DATE)
  AND deleted_at IS NULL
RETURNING *;

-- name: GetDueFollowUps :many
SELECT * FROM follow_ups
WHERE status = 'due' AND deleted_at IS NULL;

-- name: CreateFollowUp :one
INSERT INTO follow_ups (
    id, user_id, log_id, person_id, title, due_date, status,
    is_recurring, recurrence_interval_days, recurrence_type
)
VALUES ($1, $2, $3, $4, $5, $6, 'pending', $7, $8, $9)
RETURNING *;
