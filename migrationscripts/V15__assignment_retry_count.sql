ALTER TABLE maintenance_requests
    ADD COLUMN IF NOT EXISTS assignment_retry_count INTEGER NOT NULL DEFAULT 0;
ALTER TABLE maintenance_requests
    ADD COLUMN IF NOT EXISTS last_assignment_attempt_at TIMESTAMP NULL;