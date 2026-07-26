-- PM / FM company separation: company type, workflow config per PM, ticket routing columns.
ALTER TABLE companies ADD COLUMN IF NOT EXISTS type VARCHAR(40) NOT NULL DEFAULT 'PROPERTY_MANAGEMENT';
-- Workflow config keyed by PM company
ALTER TABLE company_workflow_config RENAME COLUMN company_id TO pm_company_id;
ALTER TABLE company_workflow_config ADD COLUMN IF NOT EXISTS facility_management_company_id BIGINT NULL;
ALTER TABLE company_workflow_config RENAME COLUMN business_model TO business_maintenance_model;
-- Tickets: PM owner + executor (maintainer pool) + optional FM vendor
ALTER TABLE maintenance_requests ADD COLUMN IF NOT EXISTS pm_company_id BIGINT;
ALTER TABLE maintenance_requests ADD COLUMN IF NOT EXISTS executor_company_id BIGINT;
ALTER TABLE maintenance_requests ADD COLUMN IF NOT EXISTS facility_management_company_id BIGINT;
ALTER TABLE maintenance_requests ADD COLUMN IF NOT EXISTS ticket_estimation_actor VARCHAR(40);
ALTER TABLE maintenance_requests ADD COLUMN IF NOT EXISTS ticket_approval_actor VARCHAR(40);
UPDATE maintenance_requests
SET pm_company_id = company_id,
    executor_company_id = company_id
WHERE pm_company_id IS NULL AND company_id IS NOT NULL;
-- Drop legacy single company_id on tickets after backfill (optional — uncomment when JPA no longer maps company_id)
-- ALTER TABLE maintenance_requests DROP COLUMN IF EXISTS company_id;
