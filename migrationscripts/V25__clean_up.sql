-- MVP payment cleanup: remove estimation/approval leftovers; align policies and statuses.
-- Run after add_payment_workflow.sql (or include with a fresh apply).
--
-- APPLY:  psql -U postgres -d <db> -f cleanup_mvp_payment.sql

-- Drop estimation / approval columns from tickets
ALTER TABLE maintenance_requests DROP COLUMN IF EXISTS estimated_amount;
ALTER TABLE maintenance_requests DROP COLUMN IF EXISTS estimation_note;
ALTER TABLE maintenance_requests DROP COLUMN IF EXISTS ticket_approval_status;
ALTER TABLE maintenance_requests DROP COLUMN IF EXISTS approved_by;
ALTER TABLE maintenance_requests DROP COLUMN IF EXISTS approved_at;
ALTER TABLE maintenance_requests DROP COLUMN IF EXISTS ticket_estimation_actor;

-- Drop estimation / approval / threshold / onsite flag from company config
ALTER TABLE company_workflow_config DROP COLUMN IF EXISTS estimation_required;
ALTER TABLE company_workflow_config DROP COLUMN IF EXISTS approval_required;
ALTER TABLE company_workflow_config DROP COLUMN IF EXISTS workflow_approval_actor;
ALTER TABLE company_workflow_config DROP COLUMN IF EXISTS approval_threshold;
ALTER TABLE company_workflow_config DROP COLUMN IF EXISTS onsite_payment_enabled;
ALTER TABLE company_workflow_config DROP COLUMN IF EXISTS booking_fee_deduction_policy;

-- Ensure payment policy columns exist
ALTER TABLE company_workflow_config
    ADD COLUMN IF NOT EXISTS payment_policy VARCHAR(40) NOT NULL DEFAULT 'NO_TENANT_PAYMENT';
ALTER TABLE company_workflow_config
    ADD COLUMN IF NOT EXISTS fixed_booking_fee_amount_minor BIGINT;
ALTER TABLE company_workflow_config
    ADD COLUMN IF NOT EXISTS currency VARCHAR(3) NOT NULL DEFAULT 'AED';

-- Rename legacy policy value if present
UPDATE company_workflow_config SET payment_policy = 'NO_TENANT_PAYMENT'
 WHERE payment_policy IN ('NO_PREPAYMENT');
UPDATE company_workflow_config SET payment_policy = 'MAINTAINER_REQUESTED'
 WHERE payment_policy = 'MAINTAINER_REQUESTED';

ALTER TABLE company_workflow_config DROP CONSTRAINT IF EXISTS company_workflow_config_payment_policy_check;
ALTER TABLE company_workflow_config ADD CONSTRAINT company_workflow_config_payment_policy_check CHECK (
    payment_policy IN ('NO_TENANT_PAYMENT', 'MAINTAINER_REQUESTED', 'FIXED_BOOKING_FEE')
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

-- Normalize ticket statuses removed from MVP
UPDATE maintenance_requests SET status = 'READY_TO_ASSIGN'
 WHERE status IN ('NEEDS_ESTIMATION', 'AWAITING_APPROVAL', 'AWAITING_TENANT_PAYMENT', 'ONSITE');

ALTER TABLE maintenance_requests DROP CONSTRAINT IF EXISTS maintenance_requests_status_check;
ALTER TABLE maintenance_requests ADD CONSTRAINT maintenance_requests_status_check CHECK (
    status IN (
        'AWAITING_BOOKING_FEE_PAYMENT',
        'READY_TO_ASSIGN',
        'ASSIGNED',
        'PAYMENT_PENDING',
        'IN_PROGRESS',
        'COMPLETED',
        'REJECTED',
        'MANUAL_ASSIGNMENT'
    )
);

-- Conversation payment draft columns
ALTER TABLE conversation_session ADD COLUMN IF NOT EXISTS context_ticket_id BIGINT;
ALTER TABLE conversation_session ADD COLUMN IF NOT EXISTS draft_amount_minor BIGINT;
ALTER TABLE conversation_session ADD COLUMN IF NOT EXISTS draft_currency VARCHAR(3);
