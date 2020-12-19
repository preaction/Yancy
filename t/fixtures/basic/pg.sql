
DROP TABLE IF EXISTS employees;
DROP TYPE IF EXISTS department_type;

CREATE TYPE department_type AS ENUM ( 'unknown', 'admin', 'support', 'development', 'sales' );
CREATE TABLE employees (
    employee_id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    ssn VARCHAR(11) DEFAULT NULL,
    department department_type NOT NULL DEFAULT 'unknown',
    salary INTEGER NOT NULL DEFAULT 0,
    email VARCHAR(255) NOT NULL,
    desk_phone VARCHAR(12) DEFAULT NULL,
    bio TEXT DEFAULT NULL,
    "401k_percent" NUMERIC DEFAULT 0.0
);
