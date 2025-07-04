ALTER TABLE maintenance_requests ALTER COLUMN preferred_time TYPE VARCHAR(64);

ALTER TABLE maintenance_requests RENAME COLUMN created_at TO updated_at;
