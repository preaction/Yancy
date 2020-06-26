DROP TABLE IF EXISTS icons;
CREATE TABLE icons (
    icon_id SERIAL PRIMARY KEY,
    icon_name VARCHAR(255) NOT NULL,
    icon_data BYTEA
);
