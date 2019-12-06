#!/usr/bin/env perl
use Mojolicious::Lite;

helper sqlite => sub {
    state $path = $ENV{TEST_YANCY_EXAMPLES} ? ':temp:' : app->home->child( 'data.db' );
    state $sqlite = Mojo::SQLite->new( 'sqlite:' . $path );
    return $sqlite;
};
app->sqlite->auto_migrate(1)->migrations->from_data;

plugin Yancy => {
    backend => { Sqlite => app->sqlite },
    editor => {
        require_user => { is_admin => 1 },
    },
    schema => {
        users => {
            'x-id-field' => 'email',
            properties => {
                email => {
                    type => [ 'string', 'null' ],
                    format => 'email',
                },
                password => {
                    type => [ 'string', 'null' ],
                    format => 'password',
                },
                github_account => {
                    type => [ 'string', 'null' ],
                },
                is_admin => {
                    type => 'boolean',
                    default => 0,
                },
            },
        },
    },
};

app->yancy->plugin( 'Auth' => {
    # Configuration common to all plugins can be set once globally
    schema => 'users',
    allow_register => 1,
    # Here are the individual auth plugins to configure
    plugins => [
        [ Password => {
            username_field => 'email',
            password_field => 'password',
            password_digest => {
                type => 'SHA-1',
            },
        } ],
        [ Github => {
            username_field => 'github_account',
            # Get a client ID and secret by creating an app at
            # https://github.com/settings/apps/new
            client_id => 'dc09a416a5aee52c7e1f',
            client_secret => 'b8261a4daf222c03866de363a0bfbc0e35b23bbd',
        } ],
    ]
} );

app->start;
__DATA__
@@ migrations
-- 1 up
CREATE TABLE users (
    email VARCHAR UNIQUE,
    github_account VARCHAR UNIQUE,
    is_admin BOOLEAN DEFAULT FALSE,
    password VARCHAR
);
