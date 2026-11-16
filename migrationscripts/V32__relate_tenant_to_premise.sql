ALTER TABLE customers ADD COLUMN IF NOT EXISTS premises_id BIGINT;
ALTER TABLE customers DROP CONSTRAINT IF EXISTS customers_premises_id_fkey;
ALTER TABLE customers DROP CONSTRAINT IF EXISTS customers_unit_id_fkey;
ALTER TABLE customers DROP COLUMN IF EXISTS unit_id;
ALTER TABLE customers ALTER COLUMN premises_id SET NOT NULL;
ALTER TABLE customers
  ADD CONSTRAINT customers_premises_id_fkey
  FOREIGN KEY (premises_id) REFERENCES premises (id);

