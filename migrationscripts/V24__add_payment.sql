-- Payment workflow (dev/staging — no legacy backfill).
-- Run on PostgreSQL after cleanup_mvp_workflow.sql.
-- Stripe Checkout: no card data stored locally; only session ids and status in payment_request.
--
-- APPLY:  psql -U postgres -d maintainance-db -f add_payment_workflow.sql
-- ROLLBACK: psql -U postgres -d maintainance-db -f rollback_payment_workflow.sql

-- ---------------------------------------------------------------------------
-- 1. Remove legacy ticket payment columns (payments live in payment_request)
-- ---------------------------------------------------------------------------
ALTER TABLE maintenance_requests DROP COLUMN IF EXISTS payment_ref;
ALTER TABLE maintenance_requests DROP COLUMN IF EXISTS payment_status;
ALTER TABLE maintenance_requests DROP COLUMN IF EXISTS payer_type;

-- ---------------------------------------------------------------------------
-- 2. Company payment policy (replace legacy payment_required)
-- ---------------------------------------------------------------------------
ALTER TABLE company_workflow_config DROP COLUMN IF EXISTS payment_required;
ALTER TABLE company_workflow_config DROP COLUMN IF EXISTS property_company_payment_mode;

ALTER TABLE company_workflow_config
    ADD COLUMN IF NOT EXISTS payment_policy VARCHAR(40) NOT NULL DEFAULT 'NO_PREPAYMENT';

ALTER TABLE company_workflow_config
    ADD COLUMN IF NOT EXISTS fixed_booking_fee_amount_minor BIGINT;

ALTER TABLE company_workflow_config
    ADD COLUMN IF NOT EXISTS currency VARCHAR(3) NOT NULL DEFAULT 'AED';

ALTER TABLE company_workflow_config
    ADD COLUMN IF NOT EXISTS onsite_payment_enabled BOOLEAN NOT NULL DEFAULT TRUE;

ALTER TABLE company_workflow_config DROP CONSTRAINT IF EXISTS company_workflow_config_payment_policy_check;
ALTER TABLE company_workflow_config ADD CONSTRAINT company_workflow_config_payment_policy_check CHECK (
    payment_policy IN ('NO_PREPAYMENT', 'FIXED_BOOKING_FEE')
);

ALTER TABLE company_workflow_config DROP CONSTRAINT IF EXISTS company_workflow_config_currency_check;
ALTER TABLE company_workflow_config ADD CONSTRAINT company_workflow_config_currency_check CHECK (
    currency ~ '^[A-Z]{3}$'
);

ALTER TABLE company_workflow_config DROP CONSTRAINT IF EXISTS company_workflow_config_fixed_fee_check;
ALTER TABLE company_workflow_config ADD CONSTRAINT company_workflow_config_fixed_fee_check CHECK (
    payment_policy <> 'FIXED_BOOKING_FEE'
    OR (fixed_booking_fee_amount_minor IS NOT NULL AND fixed_booking_fee_amount_minor > 0)
);

-- ---------------------------------------------------------------------------
-- 3. payment_request (Stripe Checkout session reference only — no PAN/CVV)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS payment_request (
    id                          BIGSERIAL PRIMARY KEY,
    company_id                  BIGINT NOT NULL REFERENCES companies(id),
    maintenance_request_id      BIGINT NOT NULL REFERENCES maintenance_requests(id),
    customer_id                 BIGINT NOT NULL REFERENCES customers(user_id),
    payment_type                VARCHAR(40) NOT NULL,
    amount_minor                BIGINT NOT NULL,
    currency                    VARCHAR(3) NOT NULL,
    status                      VARCHAR(40) NOT NULL,
    provider                    VARCHAR(40) NOT NULL DEFAULT 'STRIPE',
    merchant_reference          VARCHAR(64) NOT NULL,
    provider_payment_id         VARCHAR(128),
    checkout_url                VARCHAR(2048),
    idempotency_key             VARCHAR(128) NOT NULL,
    public_access_token         VARCHAR(64) NOT NULL,
    failure_code                VARCHAR(64),
    failure_message             TEXT,
    expires_at                  TIMESTAMP,
    paid_at                     TIMESTAMP,
    created_at                  TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at                  TIMESTAMP NOT NULL DEFAULT NOW(),
    version                     BIGINT NOT NULL DEFAULT 0,

    CONSTRAINT payment_request_amount_check CHECK (amount_minor > 0),
    CONSTRAINT payment_request_currency_check CHECK (currency ~ '^[A-Z]{3}$'),
    CONSTRAINT payment_request_type_check CHECK (
        payment_type IN ('BOOKING_FEE', 'ONSITE_REPAIR')
    ),
    CONSTRAINT payment_request_status_check CHECK (
        status IN ('CREATED', 'PENDING', 'PAID', 'FAILED', 'EXPIRED', 'CANCELLED')
    ),
    CONSTRAINT payment_request_provider_check CHECK (
        provider IN ('STRIPE', 'STUB')
    ),
    CONSTRAINT payment_request_merchant_reference_uq UNIQUE (merchant_reference),
    CONSTRAINT payment_request_idempotency_key_uq UNIQUE (idempotency_key),
    CONSTRAINT payment_request_public_access_token_uq UNIQUE (public_access_token)
);

CREATE UNIQUE INDEX IF NOT EXISTS payment_request_one_active_per_ticket_type_uq
    ON payment_request (maintenance_request_id, payment_type)
    WHERE status IN ('CREATED', 'PENDING');

CREATE INDEX IF NOT EXISTS payment_request_status_idx ON payment_request (status);
CREATE INDEX IF NOT EXISTS payment_request_maintenance_request_id_idx ON payment_request (maintenance_request_id);
CREATE INDEX IF NOT EXISTS payment_request_company_id_idx ON payment_request (company_id);

-- ---------------------------------------------------------------------------
-- 4. Webhook deduplication (Stripe event id)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS payment_webhook_event (
    id                   BIGSERIAL PRIMARY KEY,
    provider             VARCHAR(40) NOT NULL,
    provider_event_id    VARCHAR(128) NOT NULL,
    merchant_reference   VARCHAR(64),
    provider_payment_id  VARCHAR(128),
    payload_hash         VARCHAR(64) NOT NULL,
    processed_at         TIMESTAMP NOT NULL DEFAULT NOW(),

    CONSTRAINT payment_webhook_event_provider_check CHECK (provider IN ('STRIPE', 'STUB')),
    CONSTRAINT payment_webhook_event_provider_event_uq UNIQUE (provider, provider_event_id)
);

CREATE INDEX IF NOT EXISTS payment_webhook_event_merchant_reference_idx
    ON payment_webhook_event (merchant_reference);

-- ---------------------------------------------------------------------------
-- 5. Ticket status CHECK (remove AWAITING_TENANT_PAYMENT; add ONSITE flow)
-- ---------------------------------------------------------------------------
UPDATE maintenance_requests SET status = 'READY_TO_ASSIGN'
    WHERE status = 'AWAITING_TENANT_PAYMENT';

ALTER TABLE maintenance_requests DROP CONSTRAINT IF EXISTS maintenance_requests_status_check;
ALTER TABLE maintenance_requests ADD CONSTRAINT maintenance_requests_status_check CHECK (
    status IN (
        'NEEDS_ESTIMATION',
        'AWAITING_APPROVAL',
        'AWAITING_BOOKING_FEE_PAYMENT',
        'READY_TO_ASSIGN',
        'ASSIGNED',
        'ONSITE',
        'PAYMENT_PENDING',
        'IN_PROGRESS',
        'COMPLETED',
        'REJECTED',
        'MANUAL_ASSIGNMENT'
    )
);

-- ---------------------------------------------------------------------------
-- 6. WhatsApp maintainer payment conversation context (next phase)
-- ---------------------------------------------------------------------------
ALTER TABLE conversation_session ADD COLUMN IF NOT EXISTS context_ticket_id BIGINT;
ALTER TABLE conversation_session ADD COLUMN IF NOT EXISTS draft_amount_minor BIGINT;
ALTER TABLE conversation_session ADD COLUMN IF NOT EXISTS draft_currency VARCHAR(3);
