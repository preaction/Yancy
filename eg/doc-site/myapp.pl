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
            'x-view-item-url' => '/{path}',
            properties => {
                id => {
                    readOnly => 1,
                },
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

# Start the app. Must be the last code of the script
app->start;
__DATA__

@@ layouts/default.html.ep
<!DOCTYPE html>
<html>
    <head>
        <link rel="stylesheet" href="/yancy/bootstrap.css">
        <style>
            pre {
                border: 1px solid #ccc;
                border-radius: 5px;
                background: #f6f6f6;
                padding: 0.6em;
            }
            h1 { font-size: 2.00rem }
            h2 { font-size: 1.75rem }
            h3 { font-size: 1.50rem }
            h1, h2, h3 {
                position: relative;
            }
            h1 .permalink, h2 .permalink, h3 .permalink { 
                position: absolute;
                top: auto;
                left: -0.7em;
                color: #ddd;
            }
            h1:hover .permalink, h2:hover .permalink, h3:hover .permalink {
                color: #212529;
            }
            .crumbs .more {
                font-size: small;
            }
        </style>
        <title><%= title %></title>
    </head>
    <body>
        <header>
            <nav class="navbar navbar-dark bg-dark navbar-expand-sm sticky-top">
                <a class="navbar-brand" href="/">Yancy</a>
                <div class="collapse navbar-collapse" id="navbar">
                    <ul class="navbar-nav ml-auto">
                        <li class="nav-item">
                            <a class="nav-link" href="/perldoc">
                                Documentation
                            </a>
                        </li>
                        <li class="nav-item">
                            <a class="nav-link" href="https://metacpan.org/pod/Yancy">
                                CPAN
                            </a>
                        </li>
                        <li class="nav-item">
                            <a class="nav-link" href="https://github.com/preaction/Yancy">
                                GitHub
                            </a>
                        </li>
                        <li class="nav-item">
                            <a class="nav-link" href="https://kiwiirc.com/nextclient/#irc://irc.perl.org/#yancy?nick=www-guest-?">
                                Chat
                            </a>
                        </li>
                    </ul>
                </div>
                <button class="navbar-toggler" type="button" data-toggle="collapse" data-target="#navbar" aria-controls="navbar" aria-expanded="false" aria-label="Toggle navigation">
                    <span class="navbar-toggler-icon"></span>
                </button>
            </nav>
        </header>
        <main class="container">
            <%= content %>
        </main>
        %= javascript '/yancy/jquery.js'
        %= javascript '/yancy/popper.js'
        %= javascript '/yancy/bootstrap.js'
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

