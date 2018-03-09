
CREATE TABLE people (
    id INTEGER AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    `email` VARCHAR(255)
);
CREATE TABLE `user` (
    `username` VARCHAR(255) PRIMARY KEY,
    `email` VARCHAR(255) NOT NULL,
    `password` VARCHAR(255) NOT NULL,
    `access` ENUM ( 'user', 'moderator', 'admin' ) NOT NULL DEFAULT 'user'
);
CREATE TABLE blog (
    id INTEGER AUTO_INCREMENT PRIMARY KEY,
    user_id VARCHAR(255),
    title VARCHAR(255),
    slug VARCHAR(255),
    markdown VARCHAR(255),
    html VARCHAR(255)
);
