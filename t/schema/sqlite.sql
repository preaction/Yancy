
CREATE TABLE people (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255),
    age INTEGER DEFAULT NULL,
    contact BOOLEAN DEFAULT '0',
    phone VARCHAR(50)
);
CREATE TABLE "user" (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username VARCHAR(255) UNIQUE NOT NULL,
    email VARCHAR(255) NOT NULL,
    password VARCHAR(255) NOT NULL,
    access TEXT NOT NULL CHECK( access IN ( 'user', 'moderator', 'admin' ) ) DEFAULT 'user',
    age INTEGER DEFAULT NULL,
    plugin VARCHAR(50) NOT NULL DEFAULT 'password',
    avatar VARCHAR(255) NOT NULL DEFAULT ''
);
CREATE TABLE blog (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER,
    title VARCHAR(255) NOT NULL,
    slug VARCHAR(255),
    markdown VARCHAR(255) NOT NULL,
    html VARCHAR(255),
    is_published BOOLEAN NOT NULL DEFAULT FALSE
);
CREATE TABLE mojo_migrations (
    name VARCHAR(255) UNIQUE NOT NULL,
    version INTEGER NOT NULL
);
