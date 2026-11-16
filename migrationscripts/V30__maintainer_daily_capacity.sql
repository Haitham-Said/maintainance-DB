-- from add_urgency_capacity_scheduling.sql (capacity part)
ALTER TABLE company_workflow_config
    ADD COLUMN IF NOT EXISTS maintainer_daily_capacity INTEGER;
UPDATE company_workflow_config
SET maintainer_daily_capacity = 3
WHERE maintainer_daily_capacity IS NULL;


ALTER TABLE company_workflow_config
    ALTER COLUMN maintainer_daily_capacity SET DEFAULT 3;

    
ALTER TABLE company_workflow_config
    ALTER COLUMN maintainer_daily_capacity SET NOT NULL;