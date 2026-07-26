CREATE TABLE IF NOT EXISTS session_attachment (
    id              BIGSERIAL PRIMARY KEY,
    session_id      BIGINT NOT NULL REFERENCES conversation_session (id) ON DELETE CASCADE,
    storage_url     TEXT NOT NULL,
    mime_type       VARCHAR(128),
    created_at      TIMESTAMPTZ NOT NULL
);