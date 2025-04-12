CREATE TABLE companies (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) UNIQUE NOT NULL,
    email VARCHAR(255),
    phone VARCHAR(20),
    address TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    company_id INT REFERENCES companies(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(20) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    role VARCHAR(50) CHECK (role IN ('CUSTOMER', 'MAINTAINER', 'EMPLOYEE', 'ADMIN')) NOT NULL,
    status VARCHAR(20) CHECK (status IN ('ACTIVE', 'INACTIVE')) DEFAULT 'ACTIVE',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

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



CREATE TABLE buildings (
    id SERIAL PRIMARY KEY,
    company_id INT REFERENCES companies(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    address TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE apartments (
    id SERIAL PRIMARY KEY,
    building_id INT REFERENCES buildings(id) ON DELETE CASCADE,
    apartment_number VARCHAR(50) NOT NULL,
    floor_number INT,
    UNIQUE (building_id, apartment_number)
);

CREATE TABLE customers (
    user_id INT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    apartment_id INT REFERENCES apartments(id) ON DELETE SET NULL,
    -- other potential fields
    move_in_date DATE
);