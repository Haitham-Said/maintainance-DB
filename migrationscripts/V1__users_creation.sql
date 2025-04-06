CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(20) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    role VARCHAR(50) CHECK (role IN ('CUSTOMER', 'MAINTAINER', 'EMPLOYEE', 'ADMIN')) NOT NULL,
    status VARCHAR(20) CHECK (status IN ('ACTIVE', 'INACTIVE')) DEFAULT 'ACTIVE',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Ensure only one admin exists (Optional, uncomment if needed)
-- CREATE UNIQUE INDEX unique_admin ON users (role) WHERE role = 'ADMIN';

CREATE TABLE maintainers (
    user_id INT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    rate DECIMAL(3,2),
    availability BOOLEAN DEFAULT TRUE,
    latitude DECIMAL(9,6),  
    longitude DECIMAL(9,6),
    profile_status VARCHAR(20) CHECK (profile_status IN ('PENDING', 'ACTIVE', 'INACTIVE')) DEFAULT 'PENDING'
);

CREATE TABLE skillsets (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL
);

CREATE TABLE maintainer_skillset (
    maintainer_id INT REFERENCES maintainers(user_id) ON DELETE CASCADE,
    skillset_id INT REFERENCES skillsets(id) ON DELETE CASCADE,
    PRIMARY KEY (maintainer_id, skillset_id)
);
