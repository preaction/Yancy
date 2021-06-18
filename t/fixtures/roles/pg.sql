DROP TABLE IF EXISTS roles;
CREATE TABLE roles (
    username VARCHAR(255) NOT NULL,
    role VARCHAR(255) NOT NULL,
    PRIMARY KEY ( username, role )
);
