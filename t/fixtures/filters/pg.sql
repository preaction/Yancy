DROP TABLE IF EXISTS rolodex;
CREATE TABLE rolodex (
    rolodex_id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255),
    phone VARCHAR(30)
);
