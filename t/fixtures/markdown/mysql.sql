DROP TABLE IF EXISTS pages;
CREATE TABLE pages (
    page_id INTEGER PRIMARY KEY AUTO_INCREMENT,
    title VARCHAR(255) NOT NULL,
    slug VARCHAR(255) NOT NULL,
    content TEXT,
    content_html TEXT
);
