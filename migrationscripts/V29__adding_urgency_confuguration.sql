-- Add scheduling_policy to company_workflow_config (run manually in Postgres).
-- Existing rows keep TENANT_SELECTED_SLOT (current WhatsApp date/slot intake).

ALTER TABLE company_workflow_config
    ADD COLUMN IF NOT EXISTS scheduling_policy VARCHAR(40);

UPDATE company_workflow_config
SET scheduling_policy = 'TENANT_SELECTED_SLOT'
WHERE scheduling_policy IS NULL;

ALTER TABLE company_workflow_config
    ALTER COLUMN scheduling_policy SET DEFAULT 'TENANT_SELECTED_SLOT';

ALTER TABLE company_workflow_config
    ALTER COLUMN scheduling_policy SET NOT NULL;

ALTER TABLE company_workflow_config
    DROP CONSTRAINT IF EXISTS company_workflow_config_scheduling_policy_check;

ALTER TABLE company_workflow_config
    ADD CONSTRAINT company_workflow_config_scheduling_policy_check
        CHECK (scheduling_policy IN ('TENANT_SELECTED_SLOT', 'URGENCY_BASED'));
