begin;

ALTER TABLE maintenance_requests DROP CONSTRAINT IF EXISTS maintenance_requests_status_check;
ALTER TABLE maintenance_requests ADD CONSTRAINT maintenance_requests_status_check
    CHECK (status::text = ANY (ARRAY[
        'CREATED',
        'NEEDS_ESTIMATION',
        'AWAITING_APPROVAL',
        'AWAITING_TENANT_PAYMENT',
        'READY_TO_ASSIGN',
        'ASSIGNED',
        'IN_PROGRESS',
        'COMPLETED',
        'CANCELLED',
        'REJECTED',
        'MANUAL_ASSIGNMENT'
    ]::text[]));
COMMIT;
