DROP TABLE IF EXISTS address_types;
CREATE TABLE address_types (
    address_type_id INTEGER PRIMARY KEY AUTO_INCREMENT,
    address_type VARCHAR(20) NOT NULL
);

DROP TABLE IF EXISTS cities;
CREATE TABLE cities (
    city_id INTEGER PRIMARY KEY AUTO_INCREMENT,
    city_name VARCHAR(255) NOT NULL,
    city_state VARCHAR(255) NOT NULL
);

DROP TABLE IF EXISTS addresses;
CREATE TABLE addresses (
    address_id INTEGER PRIMARY KEY AUTO_INCREMENT,
    address_type_id INTEGER REFERENCES address_types ( address_type_id ),
    street VARCHAR(255) NOT NULL,
    city_id INTEGER REFERENCES cities ( city_id )
);
