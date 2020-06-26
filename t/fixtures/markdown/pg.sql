DROP TABLE IF EXISTS pages;
CREATE TABLE pages (
    page_id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    slug VARCHAR(255) NOT NULL,
    content TEXT,
    content_html TEXT
);
