
CREATE TABLE people (
    id INTEGER AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    `email` VARCHAR(255),
    `age` INTEGER,
    `contact` BOOLEAN,
    `phone` VARCHAR(50)
);
CREATE TABLE `user` (
    id INTEGER AUTO_INCREMENT PRIMARY KEY,
    `username` VARCHAR(255) UNIQUE NOT NULL,
    `email` VARCHAR(255) NOT NULL,
    `password` VARCHAR(255) NOT NULL,
    `access` ENUM ( 'user', 'moderator', 'admin' ) NOT NULL DEFAULT 'user',
    `age` INTEGER DEFAULT NULL
);
CREATE TABLE blog (
    id INTEGER AUTO_INCREMENT PRIMARY KEY,
    user_id INTEGER,
    title VARCHAR(255) NOT NULL,
    slug VARCHAR(255),
    markdown VARCHAR(255) NOT NULL,
    html VARCHAR(255),
    is_published BOOLEAN NOT NULL DEFAULT FALSE
);
CREATE TABLE mojo_migrations (
    name VARCHAR(255) UNIQUE NOT NULL,
    version BIGINT NOT NULL
);
