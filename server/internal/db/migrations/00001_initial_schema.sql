-- +goose Up
-- +goose StatementBegin

-- ── users ────────────────────────────────────────────────────────────────────
CREATE TABLE users (
    id           UUID        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    email        TEXT        NOT NULL UNIQUE,
    password_hash TEXT       NOT NULL,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at   TIMESTAMPTZ
);

CREATE UNIQUE INDEX ix_users_email ON users (email) WHERE deleted_at IS NULL;

-- ── refresh_tokens ───────────────────────────────────────────────────────────
CREATE TABLE refresh_tokens (
    id         UUID        NOT NULL PRIMARY KEY, -- token IS the UUID
    user_id    UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX ix_refresh_tokens_user_id   ON refresh_tokens (user_id);
CREATE INDEX ix_refresh_tokens_expires_at ON refresh_tokens (expires_at);

-- ── persons ──────────────────────────────────────────────────────────────────
CREATE TABLE persons (
    id                    UUID        NOT NULL PRIMARY KEY, -- client-generated
    user_id               UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name                  TEXT        NOT NULL,
    notes                 TEXT,
    last_interaction_date DATE,
    search_vector         TSVECTOR GENERATED ALWAYS AS (
        to_tsvector('english', coalesce(name,'') || ' ' || coalesce(notes,''))
    ) STORED,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at  TIMESTAMPTZ
);

CREATE INDEX ix_persons_user_deleted    ON persons (user_id, deleted_at);
CREATE INDEX ix_persons_user_name       ON persons (user_id, name);
CREATE INDEX ix_persons_user_interaction ON persons (user_id, last_interaction_date);
CREATE INDEX ix_persons_search          ON persons USING GIN (search_vector);

-- ── logs ─────────────────────────────────────────────────────────────────────
CREATE TABLE logs (
    id            UUID        NOT NULL PRIMARY KEY, -- client-generated
    user_id       UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    content       TEXT        NOT NULL,
    type          TEXT        NOT NULL DEFAULT 'note',
    status        TEXT        NOT NULL DEFAULT 'open',
    day_id        DATE        NOT NULL,
    device_id     TEXT        NOT NULL,
    search_vector TSVECTOR GENERATED ALWAYS AS (
        to_tsvector('english', coalesce(content,''))
    ) STORED,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX ix_logs_user_day    ON logs (user_id, day_id DESC);
CREATE INDEX ix_logs_user_deleted ON logs (user_id, deleted_at);
CREATE INDEX ix_logs_user_updated ON logs (user_id, updated_at);
CREATE INDEX ix_logs_search       ON logs USING GIN (search_vector);

-- ── log_person_links ─────────────────────────────────────────────────────────
CREATE TABLE log_person_links (
    id        UUID        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    log_id    UUID        NOT NULL REFERENCES logs(id) ON DELETE CASCADE,
    person_id UUID        NOT NULL REFERENCES persons(id) ON DELETE CASCADE,
    user_id   UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    link_type TEXT        NOT NULL DEFAULT 'mention',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (log_id, person_id)
);

CREATE INDEX ix_lpl_log_id    ON log_person_links (log_id);
CREATE INDEX ix_lpl_person_id ON log_person_links (person_id);

-- ── follow_ups ───────────────────────────────────────────────────────────────
CREATE TABLE follow_ups (
    id                        UUID        NOT NULL PRIMARY KEY, -- client-generated
    user_id                   UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    log_id                    UUID        REFERENCES logs(id) ON DELETE SET NULL,
    person_id                 UUID        REFERENCES persons(id) ON DELETE SET NULL,
    title                     TEXT        NOT NULL,
    due_date                  DATE        NOT NULL,
    status                    TEXT        NOT NULL DEFAULT 'pending',
    snoozed_until             DATE,
    completed_at              TIMESTAMPTZ,
    is_recurring              BOOLEAN     NOT NULL DEFAULT false,
    recurrence_interval_days  INTEGER,
    recurrence_type           TEXT,
    source_type               TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at  TIMESTAMPTZ
);

CREATE INDEX ix_fu_user_status_due ON follow_ups (user_id, status, due_date);
CREATE INDEX ix_fu_user_deleted    ON follow_ups (user_id, deleted_at);
CREATE INDEX ix_fu_user_updated    ON follow_ups (user_id, updated_at);
CREATE INDEX ix_fu_person_id       ON follow_ups (person_id);

-- ── device_tokens ─────────────────────────────────────────────────────────────
CREATE TABLE device_tokens (
    id         UUID        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id    UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token      TEXT        NOT NULL UNIQUE,
    platform   TEXT        NOT NULL,
    is_active  BOOLEAN     NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX ix_dt_user_active ON device_tokens (user_id, is_active);

-- ── notifications ─────────────────────────────────────────────────────────────
CREATE TABLE notifications (
    id           UUID        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id      UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    follow_up_id UUID        REFERENCES follow_ups(id) ON DELETE SET NULL,
    title        TEXT        NOT NULL,
    body         TEXT        NOT NULL,
    status       TEXT        NOT NULL DEFAULT 'scheduled',
    retry_count  INTEGER     NOT NULL DEFAULT 0,
    max_retries  INTEGER     NOT NULL DEFAULT 3,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX ix_notif_user_status     ON notifications (user_id, status);
CREATE INDEX ix_notif_user_created    ON notifications (user_id, created_at DESC);
CREATE INDEX ix_notif_status_retry    ON notifications (status, retry_count);

-- ── notification_deliveries ──────────────────────────────────────────────────
CREATE TABLE notification_deliveries (
    id               UUID        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    notification_id  UUID        NOT NULL REFERENCES notifications(id) ON DELETE CASCADE,
    device_token_id  UUID        REFERENCES device_tokens(id) ON DELETE SET NULL,
    status           TEXT        NOT NULL,
    error_message    TEXT,
    attempted_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX ix_nd_notification_id ON notification_deliveries (notification_id);

-- ── user_settings ──────────────────────────────────────────────────────────────
CREATE TABLE user_settings (
    id                           UUID        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id                      UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE UNIQUE,
    notifications_enabled        BOOLEAN     NOT NULL DEFAULT true,
    default_follow_up_days       INTEGER     NOT NULL DEFAULT 7,
    inactivity_follow_ups_enabled BOOLEAN    NOT NULL DEFAULT false,
    inactivity_threshold_days    INTEGER     NOT NULL DEFAULT 90,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ── sync_metadata ─────────────────────────────────────────────────────────────
CREATE TABLE sync_metadata (
    id           UUID        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id      UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    entity_type  TEXT        NOT NULL,
    device_id    TEXT        NOT NULL,
    last_sync_at TIMESTAMPTZ NOT NULL,
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, entity_type, device_id)
);

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE IF EXISTS sync_metadata;
DROP TABLE IF EXISTS user_settings;
DROP TABLE IF EXISTS device_tokens;
DROP TABLE IF EXISTS notification_deliveries;
DROP TABLE IF EXISTS notifications;
DROP TABLE IF EXISTS follow_ups;
DROP TABLE IF EXISTS log_person_links;
DROP TABLE IF EXISTS logs;
DROP TABLE IF EXISTS persons;
DROP TABLE IF EXISTS refresh_tokens;
DROP TABLE IF EXISTS users;
-- +goose StatementEnd
