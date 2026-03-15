-- name: GetUserByEmail :one
SELECT * FROM users
WHERE email = $1 AND deleted_at IS NULL
LIMIT 1;

-- name: GetUserByID :one
SELECT * FROM users
WHERE id = $1 AND deleted_at IS NULL
LIMIT 1;

-- name: CreateUser :one
INSERT INTO users (id, email, password_hash)
VALUES (gen_random_uuid(), $1, $2)
RETURNING *;

-- name: SoftDeleteUser :exec
UPDATE users
SET deleted_at = now(), updated_at = now()
WHERE id = $1 AND deleted_at IS NULL;
