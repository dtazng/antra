-- +goose Up
-- +goose StatementBegin

-- ── person_important_dates ────────────────────────────────────────────────────
CREATE TABLE person_important_dates (
    id                   UUID        NOT NULL PRIMARY KEY,  -- client-generated
    user_id              UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    person_id            UUID        NOT NULL REFERENCES persons(id) ON DELETE CASCADE,
    label                TEXT        NOT NULL,
    is_birthday          BOOLEAN     NOT NULL DEFAULT false,
    month                INTEGER     NOT NULL CHECK (month BETWEEN 1 AND 12),
    day                  INTEGER     NOT NULL CHECK (day BETWEEN 1 AND 31),
    year                 INTEGER,
    reminder_offset_days INTEGER,
    reminder_recurrence  TEXT        CHECK (reminder_recurrence IN ('yearly', 'once')),
    note                 TEXT,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at           TIMESTAMPTZ
);

CREATE INDEX ix_pid_person_deleted ON person_important_dates (person_id, deleted_at);
CREATE INDEX ix_pid_user_updated   ON person_important_dates (user_id, updated_at);

-- ── logs: voice log columns ───────────────────────────────────────────────────
ALTER TABLE logs
    ADD COLUMN audio_file_path        TEXT,
    ADD COLUMN audio_duration_seconds INTEGER,
    ADD COLUMN transcript_text        TEXT,
    ADD COLUMN transcription_status   TEXT CHECK (transcription_status IN ('pending', 'transcribing', 'complete', 'failed')),
    ADD COLUMN source_type            TEXT CHECK (source_type IN ('typed', 'voice'));

CREATE INDEX ix_logs_source_type ON logs (source_type) WHERE source_type IS NOT NULL;

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin

ALTER TABLE logs
    DROP COLUMN IF EXISTS source_type,
    DROP COLUMN IF EXISTS transcription_status,
    DROP COLUMN IF EXISTS transcript_text,
    DROP COLUMN IF EXISTS audio_duration_seconds,
    DROP COLUMN IF EXISTS audio_file_path;

DROP TABLE IF EXISTS person_important_dates;

-- +goose StatementEnd
