DROP TABLE IF EXISTS address_types CASCADE;
CREATE TABLE address_types (
    address_type_id SERIAL PRIMARY KEY,
    address_type VARCHAR(20) NOT NULL
);

DROP TABLE IF EXISTS cities CASCADE;
CREATE TABLE cities (
    city_id SERIAL PRIMARY KEY,
    city_name VARCHAR(255) NOT NULL,
    city_state VARCHAR(255) NOT NULL
);

DROP TABLE IF EXISTS addresses CASCADE;
CREATE TABLE addresses (
    address_id SERIAL PRIMARY KEY,
    address_type_id INTEGER REFERENCES address_types ( address_type_id ),
    street VARCHAR(255) NOT NULL,
    city_id INTEGER REFERENCES cities ( city_id )
);

DROP TABLE IF EXISTS districts CASCADE;
CREATE TABLE districts (
    district_id SERIAL PRIMARY KEY,
    district_code VARCHAR(255) NOT NULL
);

DROP TABLE IF EXISTS address_districts CASCADE;
CREATE TABLE address_districts (
    address_id INTEGER REFERENCES addresses ( address_id ),
    district_id INTEGER REFERENCES districts ( district_id )
);

