-- Dead columns in runnable flows
ALTER TABLE maintenance_requests DROP COLUMN IF EXISTS customer_rate;
ALTER TABLE maintenance_requests DROP COLUMN IF EXISTS ticket_approval_actor;

-- Also drop legacy duplicates if still present
ALTER TABLE maintenance_requests DROP COLUMN IF EXISTS approval_actor;
ALTER TABLE maintenance_requests DROP COLUMN IF EXISTS approved;
ALTER TABLE maintenance_requests DROP COLUMN IF EXISTS paid;
ALTER TABLE maintenance_requests DROP COLUMN IF EXISTS company_id;

-- Update status CHECK (CREATED/CANCELLED removed from enum)
ALTER TABLE maintenance_requests DROP CONSTRAINT IF EXISTS maintenance_requests_status_check;
ALTER TABLE maintenance_requests ADD CONSTRAINT maintenance_requests_status_check CHECK (
    status IN (
        'NEEDS_ESTIMATION',
        'AWAITING_APPROVAL',
        'AWAITING_TENANT_PAYMENT',
        'READY_TO_ASSIGN',
        'ASSIGNED',
        'IN_PROGRESS',
        'COMPLETED',
        'REJECTED',
        'MANUAL_ASSIGNMENT'
    )
);

-- Recent change: align status CHECK with current TicketStatus enum (no AWAITING_TENANT_PAYMENT)
ALTER TABLE maintenance_requests DROP CONSTRAINT IF EXISTS maintenance_requests_status_check;
ALTER TABLE maintenance_requests ADD CONSTRAINT maintenance_requests_status_check CHECK (
    status IN (
        'NEEDS_ESTIMATION',
        'AWAITING_APPROVAL',
        'READY_TO_ASSIGN',
        'ASSIGNED',
        'IN_PROGRESS',
        'COMPLETED',
        'REJECTED',
        'MANUAL_ASSIGNMENT'
    )
);