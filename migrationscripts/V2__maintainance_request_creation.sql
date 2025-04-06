CREATE TABLE maintenance_requests (
    id SERIAL PRIMARY KEY,
    customer_id INT REFERENCES customers(user_id) ON DELETE CASCADE,
    apartment_id INT REFERENCES apartments(id) ON DELETE SET NULL,
    building_id INT REFERENCES buildings(id) ON DELETE SET NULL,
    description TEXT NOT NULL,
    picture_url TEXT,
    preferred_time TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    skillset_id INT REFERENCES skillsets(id),
    status VARCHAR(50) CHECK (status IN ('PENDING', 'ASSIGNED', 'IN_PROGRESS', 'COMPLETED', 'CLOSED', 'CANCELLED')) DEFAULT 'PENDING',
    maintainer_id INT REFERENCES maintainers(user_id),
    customer_rate INT CHECK (customer_rate BETWEEN 1 AND 5)
);
