-- Remove duplicate / legacy columns from maintenance_requests.
-- Approval and payment state live in ticket_approval_status and payment_status only.
-- Run before restarting the app after pulling code changes.
BEGIN;

ALTER TABLE maintenance_requests DROP COLUMN IF EXISTS approved;
ALTER TABLE maintenance_requests DROP COLUMN IF EXISTS paid;
-- Pre PM/FM split column; replaced by pm_company_id / executor_company_id / facility_management_company_id
ALTER TABLE maintenance_requests DROP COLUMN IF EXISTS company_id;
COMMIT;
