CREATE TABLE IF NOT EXISTS company_workflow_config (
    company_id BIGINT PRIMARY KEY REFERENCES companies (id),
    business_model VARCHAR(40) NOT NULL DEFAULT 'INTERNAL_MAINTENANCE',
    estimation_actor VARCHAR(40) NOT NULL DEFAULT 'NONE',
    estimation_required BOOLEAN NOT NULL DEFAULT FALSE,
    approval_required BOOLEAN NOT NULL DEFAULT FALSE,
    payment_required BOOLEAN NOT NULL DEFAULT FALSE,
    workflow_approval_actor VARCHAR(40) NOT NULL DEFAULT 'NONE',
    approval_threshold NUMERIC(12, 2) NULL,
    property_company_payment_mode VARCHAR(40) NOT NULL DEFAULT 'NOT_REQUIRED_FOR_MVP',
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW()
);
