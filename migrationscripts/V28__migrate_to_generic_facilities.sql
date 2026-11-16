-- =============================================================================
-- Generic location model: Building/Apartment → Premises/Unit + type lookups
-- =============================================================================
-- APPLY (PostgreSQL), BEFORE starting the app with the new code:
--   psql -U postgres -d maintainance-db -f rename_building_apartment_to_premises_unit.sql
--
-- WHY BEFORE THE APP:
--   spring.jpa.hibernate.ddl-auto=update will CREATE empty `premises` / `units`
--   tables if the old `buildings` / `apartments` tables still exist under the
--   old names. Run this script first so existing data is renamed in place.
--
-- WHAT THIS DOES:
--   1) Creates premises_types / unit_types lookup tables and seeds them
--   2) Renames buildings → premises (building_code → premises_code)
--   3) Renames apartments → units (apartment_number → unit_label, building_id → premises_id)
--   4) Adds type_id FKs (existing rows → BUILDING / APARTMENT)
--   5) Renames FKs on customers, maintenance_requests, conversation_session
--
-- ROLLBACK: see rollback_rename_building_apartment_to_premises_unit.sql
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- 0) Safety: if Hibernate already created EMPTY new tables, drop them so rename
--    can proceed. Never drop if they already contain rows.
-- -----------------------------------------------------------------------------
DO $$
DECLARE
    premises_count bigint;
    units_count bigint;
BEGIN
    IF to_regclass('public.premises') IS NOT NULL AND to_regclass('public.buildings') IS NOT NULL THEN
        SELECT COUNT(*) INTO premises_count FROM premises;
        IF premises_count = 0 THEN
            DROP TABLE premises CASCADE;
            RAISE NOTICE 'Dropped empty Hibernate-created premises table so buildings can be renamed';
        ELSE
            RAISE EXCEPTION 'Both premises and buildings exist and premises is not empty. Resolve manually before migrating.';
        END IF;
    END IF;

    IF to_regclass('public.units') IS NOT NULL AND to_regclass('public.apartments') IS NOT NULL THEN
        SELECT COUNT(*) INTO units_count FROM units;
        IF units_count = 0 THEN
            DROP TABLE units CASCADE;
            RAISE NOTICE 'Dropped empty Hibernate-created units table so apartments can be renamed';
        ELSE
            RAISE EXCEPTION 'Both units and apartments exist and units is not empty. Resolve manually before migrating.';
        END IF;
    END IF;
END $$;

-- -----------------------------------------------------------------------------
-- 1) Lookup tables
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS premises_types (
    id           BIGSERIAL PRIMARY KEY,
    code         VARCHAR(64)  NOT NULL UNIQUE,
    display_name VARCHAR(128) NOT NULL,
    active       BOOLEAN      NOT NULL DEFAULT TRUE,
    sort_order   INTEGER
);

CREATE TABLE IF NOT EXISTS unit_types (
    id           BIGSERIAL PRIMARY KEY,
    code         VARCHAR(64)  NOT NULL UNIQUE,
    display_name VARCHAR(128) NOT NULL,
    active       BOOLEAN      NOT NULL DEFAULT TRUE,
    sort_order   INTEGER
);

INSERT INTO premises_types (code, display_name, active, sort_order) VALUES
    ('BUILDING',     'Building',     TRUE, 1),
    ('KINDERGARTEN', 'Kindergarten', TRUE, 2),
    ('RESTAURANT',   'Restaurant',   TRUE, 3),
    ('OTHER',        'Other',        TRUE, 99)
ON CONFLICT (code) DO UPDATE
SET display_name = EXCLUDED.display_name,
    active       = EXCLUDED.active,
    sort_order   = EXCLUDED.sort_order;

INSERT INTO unit_types (code, display_name, active, sort_order) VALUES
    ('APARTMENT',      'Apartment',       TRUE, 1),
    ('ROOM',           'Room',            TRUE, 2),
    ('WHOLE_PREMISES', 'Whole premises',  TRUE, 3)
ON CONFLICT (code) DO UPDATE
SET display_name = EXCLUDED.display_name,
    active       = EXCLUDED.active,
    sort_order   = EXCLUDED.sort_order;

-- -----------------------------------------------------------------------------
-- 2) buildings → premises
-- -----------------------------------------------------------------------------
DO $$
BEGIN
    IF to_regclass('public.buildings') IS NOT NULL AND to_regclass('public.premises') IS NULL THEN
        ALTER TABLE buildings RENAME TO premises;
        RAISE NOTICE 'Renamed buildings → premises';
    ELSIF to_regclass('public.premises') IS NOT NULL THEN
        RAISE NOTICE 'premises already exists — skip table rename';
    ELSE
        RAISE EXCEPTION 'Neither buildings nor premises exists';
    END IF;
END $$;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'premises' AND column_name = 'building_code'
    ) THEN
        ALTER TABLE premises RENAME COLUMN building_code TO premises_code;
        RAISE NOTICE 'Renamed premises.building_code → premises_code';
    END IF;
END $$;

ALTER TABLE premises ADD COLUMN IF NOT EXISTS type_id BIGINT;

UPDATE premises p
SET type_id = t.id
FROM premises_types t
WHERE p.type_id IS NULL
  AND t.code = 'BUILDING';

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM premises WHERE type_id IS NULL) THEN
        RAISE EXCEPTION 'premises.type_id still NULL after backfill — BUILDING seed missing?';
    END IF;
END $$;

ALTER TABLE premises ALTER COLUMN type_id SET NOT NULL;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'premises_type_id_fkey'
    ) THEN
        ALTER TABLE premises
            ADD CONSTRAINT premises_type_id_fkey
            FOREIGN KEY (type_id) REFERENCES premises_types (id);
    END IF;
END $$;

-- -----------------------------------------------------------------------------
-- 3) apartments → units
-- -----------------------------------------------------------------------------
DO $$
BEGIN
    IF to_regclass('public.apartments') IS NOT NULL AND to_regclass('public.units') IS NULL THEN
        ALTER TABLE apartments RENAME TO units;
        RAISE NOTICE 'Renamed apartments → units';
    ELSIF to_regclass('public.units') IS NOT NULL THEN
        RAISE NOTICE 'units already exists — skip table rename';
    ELSE
        RAISE EXCEPTION 'Neither apartments nor units exists';
    END IF;
END $$;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'units' AND column_name = 'building_id'
    ) THEN
        ALTER TABLE units RENAME COLUMN building_id TO premises_id;
        RAISE NOTICE 'Renamed units.building_id → premises_id';
    END IF;
END $$;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'units' AND column_name = 'apartment_number'
    ) THEN
        ALTER TABLE units RENAME COLUMN apartment_number TO unit_label;
        RAISE NOTICE 'Renamed units.apartment_number → unit_label';
    END IF;
END $$;

ALTER TABLE units ADD COLUMN IF NOT EXISTS type_id BIGINT;

UPDATE units u
SET type_id = t.id
FROM unit_types t
WHERE u.type_id IS NULL
  AND t.code = 'APARTMENT';

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM units WHERE type_id IS NULL) THEN
        RAISE EXCEPTION 'units.type_id still NULL after backfill — APARTMENT seed missing?';
    END IF;
END $$;

ALTER TABLE units ALTER COLUMN type_id SET NOT NULL;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'units_type_id_fkey'
    ) THEN
        ALTER TABLE units
            ADD CONSTRAINT units_type_id_fkey
            FOREIGN KEY (type_id) REFERENCES unit_types (id);
    END IF;
END $$;

-- Drop old unique (building_id, apartment_number) under whatever name Hibernate used,
-- then enforce (premises_id, unit_label).
DO $$
DECLARE
    r record;
BEGIN
    FOR r IN
        SELECT c.conname
        FROM pg_constraint c
        JOIN pg_class t ON t.oid = c.conrelid
        WHERE t.relname = 'units'
          AND c.contype = 'u'
          AND pg_get_constraintdef(c.oid) ILIKE '%apartment_number%'
    LOOP
        EXECUTE format('ALTER TABLE units DROP CONSTRAINT %I', r.conname);
        RAISE NOTICE 'Dropped old unique constraint %', r.conname;
    END LOOP;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'units_premises_id_unit_label_key'
    ) THEN
        ALTER TABLE units
            ADD CONSTRAINT units_premises_id_unit_label_key UNIQUE (premises_id, unit_label);
    END IF;
END $$;

-- Ensure units.premises_id still references premises(id)
DO $$
DECLARE
    r record;
BEGIN
    -- Drop any FK on units.premises_id that still points at buildings (shouldn't after rename,
    -- but recreate a clean named constraint).
    FOR r IN
        SELECT c.conname
        FROM pg_constraint c
        JOIN pg_class t ON t.oid = c.conrelid
        JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = ANY (c.conkey)
        WHERE t.relname = 'units'
          AND c.contype = 'f'
          AND a.attname = 'premises_id'
    LOOP
        EXECUTE format('ALTER TABLE units DROP CONSTRAINT %I', r.conname);
    END LOOP;

    ALTER TABLE units
        ADD CONSTRAINT units_premises_id_fkey
        FOREIGN KEY (premises_id) REFERENCES premises (id);
END $$;

-- -----------------------------------------------------------------------------
-- 4) customers.apartment_id → unit_id
-- -----------------------------------------------------------------------------
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'customers' AND column_name = 'apartment_id'
    ) THEN
        ALTER TABLE customers RENAME COLUMN apartment_id TO unit_id;
        RAISE NOTICE 'Renamed customers.apartment_id → unit_id';
    END IF;
END $$;

DO $$
DECLARE
    r record;
BEGIN
    FOR r IN
        SELECT c.conname
        FROM pg_constraint c
        JOIN pg_class t ON t.oid = c.conrelid
        JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = ANY (c.conkey)
        WHERE t.relname = 'customers'
          AND c.contype = 'f'
          AND a.attname = 'unit_id'
    LOOP
        EXECUTE format('ALTER TABLE customers DROP CONSTRAINT %I', r.conname);
    END LOOP;

    ALTER TABLE customers
        ADD CONSTRAINT customers_unit_id_fkey
        FOREIGN KEY (unit_id) REFERENCES units (id);
END $$;

-- -----------------------------------------------------------------------------
-- 5) maintenance_requests.building_id / apartment_id → premises_id / unit_id
-- -----------------------------------------------------------------------------
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'maintenance_requests' AND column_name = 'building_id'
    ) THEN
        ALTER TABLE maintenance_requests RENAME COLUMN building_id TO premises_id;
        RAISE NOTICE 'Renamed maintenance_requests.building_id → premises_id';
    END IF;
END $$;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'maintenance_requests' AND column_name = 'apartment_id'
    ) THEN
        ALTER TABLE maintenance_requests RENAME COLUMN apartment_id TO unit_id;
        RAISE NOTICE 'Renamed maintenance_requests.apartment_id → unit_id';
    END IF;
END $$;

DO $$
DECLARE
    r record;
BEGIN
    FOR r IN
        SELECT c.conname
        FROM pg_constraint c
        JOIN pg_class t ON t.oid = c.conrelid
        JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = ANY (c.conkey)
        WHERE t.relname = 'maintenance_requests'
          AND c.contype = 'f'
          AND a.attname IN ('premises_id', 'unit_id')
    LOOP
        EXECUTE format('ALTER TABLE maintenance_requests DROP CONSTRAINT %I', r.conname);
    END LOOP;

    ALTER TABLE maintenance_requests
        ADD CONSTRAINT maintenance_requests_premises_id_fkey
        FOREIGN KEY (premises_id) REFERENCES premises (id);

    ALTER TABLE maintenance_requests
        ADD CONSTRAINT maintenance_requests_unit_id_fkey
        FOREIGN KEY (unit_id) REFERENCES units (id);
END $$;

-- -----------------------------------------------------------------------------
-- 6) conversation_session.building_id / apartment_id → premises_id / unit_id
--    (plain Long columns — may or may not have FKs)
-- -----------------------------------------------------------------------------
DO $$
BEGIN
    IF to_regclass('public.conversation_session') IS NOT NULL THEN
        IF EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'public' AND table_name = 'conversation_session' AND column_name = 'building_id'
        ) THEN
            ALTER TABLE conversation_session RENAME COLUMN building_id TO premises_id;
            RAISE NOTICE 'Renamed conversation_session.building_id → premises_id';
        END IF;

        IF EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'public' AND table_name = 'conversation_session' AND column_name = 'apartment_id'
        ) THEN
            ALTER TABLE conversation_session RENAME COLUMN apartment_id TO unit_id;
            RAISE NOTICE 'Renamed conversation_session.apartment_id → unit_id';
        END IF;
    END IF;
END $$;

COMMIT;

-- -----------------------------------------------------------------------------
-- Quick verification (run manually if useful):
--   SELECT code, display_name FROM premises_types ORDER BY sort_order;
--   SELECT code, display_name FROM unit_types ORDER BY sort_order;
--   SELECT COUNT(*) AS premises_count, COUNT(type_id) AS with_type FROM premises;
--   SELECT COUNT(*) AS units_count, COUNT(type_id) AS with_type FROM units;
--   \d premises
--   \d units
--   \d customers
--   \d maintenance_requests
-- -----------------------------------------------------------------------------
