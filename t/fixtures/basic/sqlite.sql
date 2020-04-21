DROP TABLE IF EXISTS employees;
CREATE TABLE employees (
    employee_id INTEGER PRIMARY KEY AUTOINCREMENT,
    name VARCHAR(255) NOT NULL,
    ssn VARCHAR(11) NOT NULL,
    department VARCHAR(50) NOT NULL CHECK( department IN ( 'unknown', 'admin', 'support', 'development', 'sales' ) ) DEFAULT 'unknown',
    salary INTEGER NOT NULL DEFAULT 0,
    email VARCHAR(255) NOT NULL,
    desk_phone VARCHAR(12) DEFAULT NULL,
    bio TEXT DEFAULT NULL,
    "401k_percent" DOUBLE DEFAULT 0.0
);
