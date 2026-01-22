#!/usr/bin/env perl
use v5.24;
use experimental qw( signatures postderef );
use Mojolicious::Lite;
use Mojo::SQLite;
use Mojo::JSON qw( true false );

helper sqlite => sub {
    state $path = $ENV{TEST_YANCY_EXAMPLES} ? ':temp:' : app->home->child( 'data.db' );
    state $sqlite = Mojo::SQLite->new( 'sqlite:' . $path );
    return $sqlite;
};
app->sqlite->auto_migrate(1)->migrations->from_data;

plugin Yancy => {
    backend => { Sqlite => app->sqlite },
    read_schema => 1,
    schema => {
        blog_posts => {
            title => 'Blog Posts',
            properties => {
                blog_post_id => {
                    readOnly => true,
                },
                title => {
                    title => 'Title',
                },
                slug => {
                    title => 'Slug',
                    description => 'The final URL part for this blog post',
                },
                content => {
                    title => 'Content',
                    description => 'Post content, in Markdown',
                    format => 'markdown',
                    'x-html-field' => 'content_html',
                },
                content_html => { 'x-hidden' => 1 },
                published_date => {
                    title => 'Published Date',
                    description => 'Date this post will appear on the blog',
                },
            },
        },
    },
    editor => {
        require_user => {
            -bool => 'is_admin',
        },
    },
};

app->plugin( 'Yancy::Plugin::Auth::Password', {
    schema => 'users',
    username_field => 'username',
    password_digest => {
        type => 'SHA-1',
    },
} );

# Allow content editors to only edit the title, content, and
# content_html of blog posts
my $schema = app->yancy->model->json_schema;
my $editable_properties = {
    %{ $schema->{blog_posts}{properties} }{qw(
        blog_post_id title content content_html
    )},
};
app->plugin( 'Yancy::Plugin::Editor' => {
    model => app->yancy->model,
    route => '/edit',
    require_user => {
        -bool => 'is_editor',
    },
    schema => {
        blog_posts => {
            %{ $schema->{blog_posts} },
            properties => $editable_properties,
        },
    },
} );

get '/blog/:blog_post_id/:slug' => {
    controller => 'yancy',
    action => 'get',
    schema => 'blog_posts',
    id_field => 'blog_post_id',
    template => 'blog/get',
};

get '/' => {
    controller => 'yancy',
    action => 'list',
    schema => 'blog_posts',
    template => 'blog/list',
};

app->start;
__DATA__

@@ migrations
-- 1 up
CREATE TABLE users (
    user_id INTEGER PRIMARY KEY AUTOINCREMENT,
    username VARCHAR(100) NOT NULL,
    password VARCHAR(100) NOT NULL,
    is_admin BOOLEAN DEFAULT FALSE,
    is_editor BOOLEAN DEFAULT FALSE
);

CREATE TABLE blog_posts (
    blog_post_id INTEGER PRIMARY KEY AUTOINCREMENT,
    title VARCHAR(255) NOT NULL,
    slug VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    content_html TEXT NOT NULL,
    published_date DATE NOT NULL DEFAULT CURRENT_DATE
);

INSERT INTO users ( username, password, is_admin, is_editor )
    VALUES ( 'admin', '0DPiKuNIrrVmD8IUCuw1hQxNqZc', 1, 1 );
INSERT INTO users ( username, password, is_editor )
    VALUES ( 'editor', 'q0GUmCVgbaF523yJ3c7cwWe2SEc', 1 );
INSERT INTO users ( username, password )
    VALUES ( 'user', 'Et6pb+wgWTVmq3VpLJlJWWgzrck' );

INSERT INTO blog_posts ( title, slug, content, content_html )
    VALUES (
        'Application Description',
        'application-description',
        'This application demonstrates multiple instances of the Yancy editor. The "editor" user can use the editor at [/edit](/edit). The "admin" user can use the primary editor at [/yancy](/yancy).

See <https://github.com/preaction/Yancy/tree/master/eg/limited-editor> for more information.',
        '<p>This application demonstrates multiple instances of the Yancy editor. The "editor" user can use the editor at <a href="/edit">/edit</a>. The "admin" user can use the primary editor at <a href="/yancy">/yancy</a>.</p><p>See <a href="https://github.com/preaction/Yancy/tree/master/eg/limited-editor"> https://github.com/preaction/Yancy/tree/master/eg/limited-editor</a> for more information.</p>'
    );

-- 1 down
DROP TABLE blog_posts;
DROP TABLE users;

@@ blog/list.html.ep
% for my $item ( @$items ) {
    <article>
        <h1><%= link_to $item->{title}, 'blog.get', $item %></h1>
        %== $item->{content_html}
    </article>
% }

@@ blog/get.html.ep
%= tag h1 => $item->{title}
%== $item->{content_html}
%= link_to 'Back to blog', 'blog.list'
