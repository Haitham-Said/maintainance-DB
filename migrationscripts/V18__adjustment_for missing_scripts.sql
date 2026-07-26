-- ============================================
-- PM / FM separation - idempotent migration
-- PostgreSQL
-- ============================================

BEGIN;

-- 1) companies: add company type
ALTER TABLE companies
    ADD COLUMN IF NOT EXISTS type VARCHAR(40) NOT NULL DEFAULT 'PROPERTY_MANAGEMENT';

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'chk_companies_type'
    ) THEN
        ALTER TABLE companies
            ADD CONSTRAINT chk_companies_type
            CHECK (type IN ('PROPERTY_MANAGEMENT', 'FACILITY_MANAGEMENT'));
    END IF;
END$$;

-- 2) company_workflow_config: rename columns safely
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'company_workflow_config' AND column_name = 'company_id'
    ) AND NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'company_workflow_config' AND column_name = 'pm_company_id'
    ) THEN
        ALTER TABLE company_workflow_config RENAME COLUMN company_id TO pm_company_id;
    END IF;
END$$;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'company_workflow_config' AND column_name = 'business_model'
    ) AND NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'company_workflow_config' AND column_name = 'business_maintenance_model'
    ) THEN
        ALTER TABLE company_workflow_config RENAME COLUMN business_model TO business_maintenance_model;
    END IF;
END$$;

ALTER TABLE company_workflow_config
    ADD COLUMN IF NOT EXISTS facility_management_company_id BIGINT;

-- normalize old rows
ALTER TABLE company_workflow_config
    ALTER COLUMN business_maintenance_model SET DEFAULT 'INTERNAL_MAINTENANCE';

UPDATE company_workflow_config
SET business_maintenance_model = 'INTERNAL_MAINTENANCE'
WHERE business_maintenance_model IS NULL;

ALTER TABLE company_workflow_config
    ALTER COLUMN business_maintenance_model SET NOT NULL;

-- PK safety (handles pre-existing PK with different name)
DO $$
DECLARE
    pk_col text;
BEGIN
    SELECT a.attname
      INTO pk_col
    FROM pg_constraint c
    JOIN pg_class t ON t.oid = c.conrelid
    JOIN pg_namespace n ON n.oid = t.relnamespace
    JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = ANY(c.conkey)
    WHERE c.contype = 'p'
      AND n.nspname = current_schema()
      AND t.relname = 'company_workflow_config'
    LIMIT 1;

    IF pk_col IS NULL THEN
        EXECUTE 'ALTER TABLE company_workflow_config ADD PRIMARY KEY (pm_company_id)';
    ELSIF pk_col <> 'pm_company_id' THEN
        RAISE EXCEPTION
            'company_workflow_config PK is on %, expected pm_company_id. Fix manually first.',
            pk_col;
    END IF;
END$$;

-- 3) maintenance_requests: routing columns
ALTER TABLE maintenance_requests
    ADD COLUMN IF NOT EXISTS pm_company_id BIGINT,
    ADD COLUMN IF NOT EXISTS executor_company_id BIGINT,
    ADD COLUMN IF NOT EXISTS facility_management_company_id BIGINT,
    ADD COLUMN IF NOT EXISTS ticket_estimation_actor VARCHAR(40),
    ADD COLUMN IF NOT EXISTS ticket_approval_actor VARCHAR(40);

-- backfill from old company_id
UPDATE maintenance_requests
SET pm_company_id = company_id
WHERE pm_company_id IS NULL AND company_id IS NOT NULL;

UPDATE maintenance_requests
SET executor_company_id = company_id
WHERE executor_company_id IS NULL AND company_id IS NOT NULL;

-- enforce required routing columns
ALTER TABLE maintenance_requests
    ALTER COLUMN pm_company_id SET NOT NULL,
    ALTER COLUMN executor_company_id SET NOT NULL;

-- 4) foreign keys
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_cfg_pm_company') THEN
        ALTER TABLE company_workflow_config
            ADD CONSTRAINT fk_cfg_pm_company
            FOREIGN KEY (pm_company_id) REFERENCES companies(id);
    END IF;
END$$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_cfg_fm_company') THEN
        ALTER TABLE company_workflow_config
            ADD CONSTRAINT fk_cfg_fm_company
            FOREIGN KEY (facility_management_company_id) REFERENCES companies(id);
    END IF;
END$$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_ticket_pm_company') THEN
        ALTER TABLE maintenance_requests
            ADD CONSTRAINT fk_ticket_pm_company
            FOREIGN KEY (pm_company_id) REFERENCES companies(id);
    END IF;
END$$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_ticket_executor_company') THEN
        ALTER TABLE maintenance_requests
            ADD CONSTRAINT fk_ticket_executor_company
            FOREIGN KEY (executor_company_id) REFERENCES companies(id);
    END IF;
END$$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_ticket_fm_company') THEN
        ALTER TABLE maintenance_requests
            ADD CONSTRAINT fk_ticket_fm_company
            FOREIGN KEY (facility_management_company_id) REFERENCES companies(id);
    END IF;
END$$;

-- 5) checks
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_cfg_model') THEN
        ALTER TABLE company_workflow_config
            ADD CONSTRAINT chk_cfg_model
            CHECK (business_maintenance_model IN ('INTERNAL_MAINTENANCE', 'FACILITY_MANAGEMENT'));
    END IF;
END$$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_cfg_fm_presence') THEN
        ALTER TABLE company_workflow_config
            ADD CONSTRAINT chk_cfg_fm_presence
            CHECK (
                (business_maintenance_model = 'INTERNAL_MAINTENANCE' AND facility_management_company_id IS NULL)
                OR
                (business_maintenance_model = 'FACILITY_MANAGEMENT' AND facility_management_company_id IS NOT NULL)
            );
    END IF;
END$$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_ticket_estimation_actor') THEN
        ALTER TABLE maintenance_requests
            ADD CONSTRAINT chk_ticket_estimation_actor
            CHECK (ticket_estimation_actor IS NULL OR ticket_estimation_actor IN ('PROPERTY_ADMIN', 'FACILITY_ADMIN', 'NONE'));
    END IF;
END$$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_ticket_approval_actor') THEN
        ALTER TABLE maintenance_requests
            ADD CONSTRAINT chk_ticket_approval_actor
            CHECK (ticket_approval_actor IS NULL OR ticket_approval_actor IN ('PROPERTY_ADMIN', 'NONE'));
    END IF;
END$$;

-- 6) indexes
CREATE INDEX IF NOT EXISTS idx_mr_pm_company_status
    ON maintenance_requests(pm_company_id, status);

CREATE INDEX IF NOT EXISTS idx_mr_executor_status
    ON maintenance_requests(executor_company_id, status);

CREATE INDEX IF NOT EXISTS idx_mr_fm_company
    ON maintenance_requests(facility_management_company_id);

CREATE INDEX IF NOT EXISTS idx_cfg_fm_company
    ON company_workflow_config(facility_management_company_id);

COMMIT;

-- Optional cleanup (only after code no longer references maintenance_requests.company_id):
-- ALTER TABLE maintenance_requests DROP COLUMN IF EXISTS company_id;