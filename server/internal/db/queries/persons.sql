-- name: UpsertPerson :one
INSERT INTO persons (id, user_id, name, notes, created_at, updated_at)
VALUES ($1, $2, $3, $4, $5, now())
ON CONFLICT (id) DO UPDATE
    SET name       = EXCLUDED.name,
        notes      = EXCLUDED.notes,
        updated_at = now(),
        deleted_at = NULL
WHERE persons.updated_at <= EXCLUDED.updated_at
RETURNING id, user_id, name, notes, last_interaction_date, created_at, updated_at, deleted_at;

-- name: SoftDeletePerson :one
UPDATE persons
SET deleted_at = now(), updated_at = now()
WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL
RETURNING id, user_id, name, notes, last_interaction_date, created_at, updated_at, deleted_at;

-- name: GetPersonsByUpdatedSince :many
SELECT id, user_id, name, notes, last_interaction_date, created_at, updated_at, deleted_at
FROM persons
WHERE user_id = $1 AND updated_at > $2
ORDER BY updated_at ASC
LIMIT $3;

-- name: ListPersons :many
SELECT id, user_id, name, notes, last_interaction_date, created_at, updated_at, deleted_at
FROM persons
WHERE user_id = $1 AND deleted_at IS NULL
ORDER BY name ASC
LIMIT $2 OFFSET $3;

-- name: SearchPersons :many
SELECT id, user_id, name, notes, last_interaction_date, created_at, updated_at, deleted_at
FROM persons
WHERE user_id = $1
  AND deleted_at IS NULL
  AND search_vector @@ plainto_tsquery('english', $2)
ORDER BY ts_rank(search_vector, plainto_tsquery('english', $2)) DESC
LIMIT 50;

-- name: GetPersonByID :one
SELECT id, user_id, name, notes, last_interaction_date, created_at, updated_at, deleted_at
FROM persons
WHERE id = $1 AND user_id = $2
LIMIT 1;

-- name: UpdatePerson :one
UPDATE persons
SET name       = coalesce(sqlc.narg(name), name),
    notes      = coalesce(sqlc.narg(notes), notes),
    updated_at = now()
WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL
RETURNING id, user_id, name, notes, last_interaction_date, created_at, updated_at, deleted_at;
