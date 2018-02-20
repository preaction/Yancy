
CREATE TYPE access_level AS ENUM ( 'user', 'moderator', 'admin' );
CREATE TABLE people ( id SERIAL, name VARCHAR NOT NULL, email VARCHAR );
CREATE TABLE "user" (
    username VARCHAR PRIMARY KEY,
    email VARCHAR NOT NULL,
    password VARCHAR NOT NULL,
    access access_level NOT NULL DEFAULT 'user'
);
CREATE TABLE blog (
    id SERIAL PRIMARY KEY,
    user_id INTEGER,
    title TEXT,
    slug TEXT,
    markdown TEXT,
    html TEXT
);
