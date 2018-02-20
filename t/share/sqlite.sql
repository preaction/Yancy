
CREATE TABLE people (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255)
);
CREATE TABLE "user" (
    username VARCHAR(255) PRIMARY KEY,
    email VARCHAR(255) NOT NULL,
    password VARCHAR(255) NOT NULL,
    access TEXT NOT NULL CHECK( access IN ( 'user', 'moderator', 'admin' ) ) DEFAULT 'user'
);
CREATE TABLE blog (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER,
    title VARCHAR(255),
    slug VARCHAR(255),
    markdown VARCHAR(255),
    html VARCHAR(255)
);
