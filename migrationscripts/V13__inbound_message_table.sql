CREATE TABLE IF NOT EXISTS conversation_session (
    id                      BIGSERIAL PRIMARY KEY,
    from_phone              VARCHAR(255) NOT NULL UNIQUE,
    state                   VARCHAR(64) NOT NULL,
    company_id              BIGINT,
    tenant_id               BIGINT,
    apartment_id            BIGINT,
    building_id             BIGINT,
    selected_category       VARCHAR(128),
    description             TEXT,
    created_ticket_id       BIGINT,
    preferred_visit_date    DATE,
    preferred_time_slot     VARCHAR(64),
    last_interaction_at     TIMESTAMPTZ NOT NULL
);