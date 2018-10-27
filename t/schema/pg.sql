
CREATE TYPE access_level AS ENUM ( 'user', 'moderator', 'admin' );
CREATE TABLE people (
    id SERIAL,
    name VARCHAR NOT NULL,
    email VARCHAR,
    age INTEGER,
    contact BOOLEAN
);
CREATE TABLE "user" (
    id SERIAL PRIMARY KEY,
    username VARCHAR UNIQUE NOT NULL,
    email VARCHAR NOT NULL,
    password VARCHAR NOT NULL,
    access access_level NOT NULL DEFAULT 'user',
    age INTEGER DEFAULT NULL
);
CREATE TABLE blog (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES "user" ON DELETE CASCADE,
    title TEXT,
    slug TEXT,
    markdown TEXT,
    html TEXT
);
CREATE TABLE IF NOT EXISTS mojo_migrations (
    name TEXT UNIQUE NOT NULL,
    version BIGINT NOT NULL CHECK (version >= 0)
);
