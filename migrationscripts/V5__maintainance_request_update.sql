ALTER TABLE maintainance_request ALTER COLUMN preferred_time TYPE VARCHAR(64);

ALTER TABLE maintainance_request RENAME COLUMN created_at TO updated_at;
