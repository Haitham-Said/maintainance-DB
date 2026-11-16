ALTER TABLE customers
    ADD COLUMN IF NOT EXISTS unit_id BIGINT;

ALTER TABLE customers
    DROP CONSTRAINT IF EXISTS customers_unit_id_fkey;

ALTER TABLE customers
    ADD CONSTRAINT customers_unit_id_fkey
        FOREIGN KEY (unit_id) REFERENCES units (id);