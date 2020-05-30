DROP TABLE IF EXISTS wiki_pages;
CREATE TABLE wiki_pages (
    wiki_page_id INTEGER,
    revision_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    title VARCHAR(255) NOT NULL,
    slug VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    PRIMARY KEY (wiki_page_id, revision_date)
);
