#!/usr/bin/env perl
use v5.24;
use experimental qw( signatures postderef );
use Mojolicious::Lite;
use Mojo::SQLite;
use Mojo::Util qw( trim unindent );
use DateTime;
use DateTime::Event::Recurrence;
use Scalar::Util qw( looks_like_number );

helper sqlite => sub {
    state $path = $ENV{TEST_YANCY_EXAMPLES} ? ':temp:' : app->home->child( 'data.db' );
    state $sqlite = Mojo::SQLite->new( 'sqlite:' . $path );
    return $sqlite;
};
app->sqlite->auto_migrate(1)->migrations->from_data;

# Login sessions expire after one week
app->sessions->default_expiration( 60 * 60 * 24 * 7 );

if ( my $path = $ENV{MOJO_REVERSE_PROXY} ) {
    my @parts = grep { $_ } split m{/}, $path;
    app->hook( before_dispatch => sub {
        my ( $c ) = @_;
        my $url = $c->req->url;
        my $base = $url->base;
        # Append to the base path
        push @{ $base->path }, @parts;
        # The base must end with a slash, making http://example.com/todo/
        $base->path->trailing_slash(1);
        # and the URL must not, so that relative links on the home page work
        # correctly
        $url->path->leading_slash(0);
    });
}

plugin Yancy => {
    backend => { Sqlite => app->sqlite },
    read_schema => 1,
    collections => {
        todo_item => {
            title => 'To-Do Item',
            description => unindent( trim q{
                A recurring task to do. Tasks are available during a `period`, and
                recur after an `interval`. For example:

                * A task with an interval of `1` and a period of `day` should be
                  completed once every day.
                * A task with an interval of `1` and a period of `week` should be
                  completed once every week.
                * A task with an interval of `2` and a period of `day` will show up
                  once every 2 days and should be completed that day.
                * A task with an interval of `2` and a period of `week` will show up
                  once every 2 weeks and should be completed that week.
            }),
            example => {
                period => "day",
                title => "Did you brush your teeth?",
                interval => 1,
            },
            properties => {
                period => {
                    description => 'How long a task is available to do.',
                    enum => [qw( day week month )],
                },
                interval => {
                    description => 'The number of periods each between each instance.',
                },
                start_date => {
                    description => 'The date to start using this item. Defaults to today.',
                },
            },
            'x-list-columns' => [qw( title interval period )],
        },
        todo_log => {
            title => 'To-Do Log',
            'x-list-columns' => [qw( id start_date end_date complete )],
            description => unindent( trim q{
                A log of the to-do items that have passed. Items can either be completed
                or uncompleted.
            } ),
            properties => {
                complete => {
                    type => [qw( string null )],
                    description => 'The date which this item was completed, if any.',
                },
            },
        },
    },
};

app->yancy->plugin( 'Auth', {
    collection => 'users',
    plugins => [
        [ Password => {
            username_field => 'username',
            password_digest => {
                type => 'SHA-1',
            },
            allow_register => 1,
        } ],
    ],
} );

under app->yancy->auth->require_user;

my %RECUR_METHOD = (
    day => 'daily',
    week => 'weekly',
    month => 'monthly',
);

sub _build_recurrence {
    my ( $todo_item ) = @_;
    my $method = $RECUR_METHOD{ $todo_item->{ period } };
    return DateTime::Event::Recurrence->$method(
        interval => $todo_item->{ interval },
    );
}

sub _build_end_dt {
    my ( $todo_item, $start_dt ) = @_;
    if ( $todo_item->{period} eq 'day' ) {
        return $start_dt->clone;
    }
    elsif ( $todo_item->{period} eq 'week' ) {
        return $start_dt->clone->add( days => 6 );
    }
    elsif ( $todo_item->{period} eq 'month' ) {
        return $start_dt->clone->add( months => 1 )->add( days => -1 );
    }
}

sub _parse_ymd {
    my ( $date ) = @_;
    my ( $y, $m, $d ) = split /-/, $date;
    die sprintf "Invalid date %s-%s-%s", $y, $m, $d
        if grep { !looks_like_number $_ } $y, $m, $d;
    return DateTime->new( year => $y, month => $m, day => $d );
}

helper ensure_log_item_exists => sub {
    my ( $c, $todo_item, $start_dt ) = @_;
    my $exists_sql = <<'    SQL';
        SELECT COUNT(*) FROM todo_log
        WHERE todo_item_id = ? AND start_date = ?
    SQL
    my $result = $c->sqlite->db->query( $exists_sql, $todo_item->{id}, $start_dt->ymd );
    my $exists = !!$result->array->[0];
    if ( !$exists ) {
        my $end_dt = _build_end_dt( $todo_item, $start_dt );
        my $insert_sql = <<'        SQL';
            INSERT INTO todo_log ( todo_item_id, start_date, end_date )
            VALUES ( ?, ?, ? )
        SQL
        $c->sqlite->db->query( $insert_sql,
            $todo_item->{id}, $start_dt->ymd, $end_dt->ymd,
        );
    }
};

helper build_todo_log => sub {
    my ( $c, $dt ) = @_;
    $dt //= DateTime->today( time_zone => 'US/Central' );

    # Fetch all to-do items
    my $sql = 'SELECT * FROM todo_item WHERE start_date <= ?';
    my $result = $c->sqlite->db->query( $sql, $dt->ymd );
    my $todo_items = $result->hashes;
    for my $todo_item ( @$todo_items ) {
        my $series = _build_recurrence( $todo_item );
        if ( my $start_dt = $series->current( $dt ) ) {
            $c->ensure_log_item_exists( $todo_item, $start_dt );
        }
    }
};

get '/' => sub {
    my ( $c ) = @_;
    $c->redirect_to( 'todo.list',
        date => DateTime->today( time_zone => 'US/Central' )->ymd( '-' ),
    );
};

get '/:date' => sub {
    my ( $c ) = @_;
    my $dt = _parse_ymd( $c->stash( 'date' ) );
    $c->build_todo_log( $dt );
    my $sql = <<'    SQL';
        SELECT log.id, item.title, log.complete, item.show_notes, log.notes
        FROM todo_log log
        JOIN todo_item item
            ON log.todo_item_id = item.id
        WHERE log.start_date <= ?
            AND log.end_date >= ?
    SQL
    my $result = $c->sqlite->db->query( $sql, ($dt->ymd) x 2 );
    my $items = $result->hashes;
    return $c->render(
        template => 'todo/list',
        date => $dt,
        next_date => $dt->clone->add( days => 1 ),
        prev_date => $dt->clone->add( days => -1 ),
        items => $items,
    );
} => 'todo.list';

post '/log/:log_id' => sub {
    my ( $c ) = @_;
    my $id = $c->stash( 'log_id' );
    my $complete = $c->param( 'complete' )
        ? DateTime->today( time_zone => 'US/Central' )->ymd
        : undef;
    my @params = ( $complete );
    my $has_notes = '';
    if ( exists $c->req->params->to_hash->{ notes } ) {
        $has_notes = ', notes = ?';
        my $notes = $c->param( 'notes' );
        push @params, $notes;
    }
    my $sql = "UPDATE todo_log SET complete = ?$has_notes WHERE id = ?";
    $c->sqlite->db->query( $sql, @params, $id );
    my $start_date =
        $c->sqlite->db->query( 'SELECT start_date FROM todo_log WHERE id = ?', $id )
        ->hash->{start_date};
    return $c->redirect_to( 'todo.list', date => $start_date );
} => 'update_log';

app->start;
__DATA__

@@ todo/list.html.ep
% layout 'default';
% title 'Welcome';

<div class="row">
    <div class="col-md-12">

        <h1 class="text-center"><%= $date->ymd %></h1>

        <ul class="list-group">
        % for my $log ( @$items ) {

            <li class="list-group-item <%= $log->{complete} ? 'list-group-item-success' : '' %>">
                %= form_for 'update_log', { log_id => $log->{id} }, ( class => 'd-flex align-items-center justify-content-start' ), begin
                    <span style="flex: 1 1 auto"><%= $log->{title} %></span>
                    % if ( $log->{show_notes} ) {
                        <%= text_field 'notes',
                            value => $log->{notes},
                            $log->{complete} ? ( disabled => $log->{complete} ) : (),
                            style => 'margin-right: 0.4em; flex: 1 1 50%',
                        %>
                    % }
                    % if ( !$log->{complete} ) {
                        <button class="btn btn-success" name="complete" value="1">
                            Complete
                        </button>
                    % }
                    % else {
                        <button class="btn btn-danger" name="complete" value="0">
                            Undo
                        </button>
                    % }
                % end
            </li>

        % }
        </ul>

        <div class="d-flex flex-wrap mt-2 justify-content-between align-items-center">
            <a class="btn btn-outline-dark" href="<%= url_for 'todo.list' => ( date => $prev_date->ymd ) %>">
                &lt; <%= $prev_date->ymd %>
            </a>
            <a href="<%= url_for '/' %>" class="btn btn-secondary">Today</a>
            <a class="btn btn-outline-dark" href="<%= url_for 'todo.list' => ( date => $next_date->ymd ) %>">
                <%= $next_date->ymd %> &gt;
            </a>
        </div>

    </div>
</div>

@@ layouts/default.html.ep
<!DOCTYPE html>
<html>
    <head>
        <title><%= title %></title>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        %= stylesheet '/yancy/bootstrap.css'
    </head>
    <body>
        <main class="container">
            <%= content %>
        </main>
        <footer class="container mt-4 mb-2 d-flex justify-content-center">
            <a href="<%= url_for '/yancy' %>">Edit Content</a>
        </footer>
    </body>
</html>

@@ migrations
-- 2 up
ALTER TABLE todo_item ADD COLUMN show_notes BOOLEAN DEFAULT 0;
ALTER TABLE todo_log ADD COLUMN notes TEXT DEFAULT NULL;
-- 2 down
ALTER TABLE todo_item DROP COLUMN show_notes;
ALTER TABLE todo_log DROP COLUMN notes;
-- 1 up
CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username VARCHAR(100) NOT NULL,
    password VARCHAR(100) NOT NULL
);
CREATE TABLE todo_item (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT,
    period VARCHAR(20) NOT NULL,
    interval INTEGER DEFAULT 1 CHECK ( interval >= 1 ) NOT NULL,
    start_date DATE NOT NULL DEFAULT CURRENT_DATE
);
CREATE TABLE todo_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    todo_item_id INTEGER REFERENCES todo_item ( id ) NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    complete DATE DEFAULT NULL
);
-- 1 down
DROP TABLE todo_log;
DROP TABLE todo_item;
DROP TABLE users;
