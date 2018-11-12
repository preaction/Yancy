#!/usr/bin/env perl

use Mojolicious::Lite;
use Mojo::SQLite;

helper db => sub {
    state $db = Mojo::SQLite->new( 'sqlite:' . app->home->child( 'docs.db' ) );
    return $db;
};
app->db->auto_migrate(1)->migrations->from_data( 'main' );

plugin 'PODViewer', {
    default_module => 'Yancy',
    allow_modules => [qw( Yancy Mojolicious::Plugin::Yancy )],
    layout => 'default',
};

plugin 'Yancy', {
    backend => { Sqlite => app->db },
    read_schema => 1,
    collections => {
        pages => {
            'x-id-field' => 'path',
            'x-list-columns' => [qw( path )],
            properties => {
                markdown => {
                    format => 'markdown',
                    'x-html-field' => 'html',
                },
            },
        },
    },
};

get '/*id' => {
    id => 'index', # Default to index page
    controller => 'yancy',
    action => 'get',
    collection => 'pages',
    template => 'pages',
};

app->start;
__DATA__

@@ layouts/default.html.ep
<!DOCTYPE html>
<html>
    <head>
        <link rel="stylesheet" href="/yancy/bootstrap.css">
        <title><%= title %></title>
    </head>
    <body>
        <main class="container">
            <%= content %>
        </main>
    </body>
</html>

@@ pages.html.ep
% layout 'default';
%== $item->{html}

@@ migrations
-- 1 up
CREATE TABLE pages (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    path VARCHAR UNIQUE NOT NULL,
    markdown TEXT,
    html TEXT
);

