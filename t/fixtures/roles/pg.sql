
DROP TABLE IF EXISTS employees;
CREATE TABLE employees (
    username VARCHAR(255) NOT NULL,
    role VARCHAR(255) NOT NULL,
    PRIMARY KEY ( username, role )
);
