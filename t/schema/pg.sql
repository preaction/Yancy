
CREATE TYPE access_level AS ENUM ( 'user', 'moderator', 'admin' );
CREATE TABLE people (
    id SERIAL PRIMARY KEY,
    name VARCHAR NOT NULL,
    email VARCHAR,
    age INTEGER,
    contact BOOLEAN DEFAULT false,
    phone VARCHAR(50)
);
CREATE TABLE "user" (
    id SERIAL PRIMARY KEY,
    username VARCHAR UNIQUE NOT NULL,
    email VARCHAR NOT NULL,
    password VARCHAR NOT NULL,
    access access_level NOT NULL DEFAULT 'user',
    age INTEGER DEFAULT NULL,
    plugin VARCHAR(50) NOT NULL DEFAULT 'password',
    avatar VARCHAR NOT NULL DEFAULT ''
);
CREATE TABLE blog (
    id SERIAL PRIMARY KEY,
    username VARCHAR REFERENCES "user" (username) ON UPDATE CASCADE,
    title TEXT NOT NULL,
    slug TEXT,
    markdown TEXT NOT NULL,
    html TEXT,
    is_published BOOLEAN NOT NULL DEFAULT FALSE
);
CREATE TABLE IF NOT EXISTS mojo_migrations (
    name TEXT UNIQUE NOT NULL,
    version BIGINT NOT NULL CHECK (version >= 0)
);
