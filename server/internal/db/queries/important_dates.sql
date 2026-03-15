-- name: CreateImportantDate :one
INSERT INTO person_important_dates (
    id, user_id, person_id, label, is_birthday,
    month, day, year,
    reminder_offset_days, reminder_recurrence, note,
    created_at, updated_at
) VALUES (
    $1, $2, $3, $4, $5,
    $6, $7, $8,
    $9, $10, $11,
    now(), now()
)
RETURNING *;

-- name: GetImportantDate :one
SELECT * FROM person_important_dates
WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL;

-- name: ListImportantDatesByPerson :many
SELECT * FROM person_important_dates
WHERE person_id = $1 AND user_id = $2 AND deleted_at IS NULL
ORDER BY is_birthday DESC, month ASC, day ASC;

-- name: UpdateImportantDate :one
UPDATE person_important_dates
SET label                = $3,
    is_birthday          = $4,
    month                = $5,
    day                  = $6,
    year                 = $7,
    reminder_offset_days = $8,
    reminder_recurrence  = $9,
    note                 = $10,
    updated_at           = now()
WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL
RETURNING *;

-- name: SoftDeleteImportantDate :exec
UPDATE person_important_dates
SET deleted_at = now(), updated_at = now()
WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL;

-- name: ListImportantDatesByUserSince :many
SELECT * FROM person_important_dates
WHERE user_id = $1 AND updated_at > $2
ORDER BY updated_at ASC;
