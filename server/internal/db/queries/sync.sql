-- name: UpsertSyncMetadata :one
INSERT INTO sync_metadata (user_id, entity_type, device_id, last_sync_at)
VALUES ($1, $2, $3, $4)
ON CONFLICT (user_id, entity_type, device_id) DO UPDATE
    SET last_sync_at = EXCLUDED.last_sync_at,
        updated_at   = now()
RETURNING *;

-- name: ReplaceLogPersonLinks :exec
WITH deleted AS (
    DELETE FROM log_person_links
    WHERE log_id = $1
)
INSERT INTO log_person_links (log_id, person_id, user_id)
SELECT $1, unnest($2::uuid[]), $3;

-- name: CreateDeliveryRecord :one
INSERT INTO notification_deliveries (notification_id, device_token_id, status, error_message)
VALUES ($1, $2, $3, $4)
RETURNING *;
