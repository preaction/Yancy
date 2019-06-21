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
    app->sessions->cookie_path( $ENV{MOJO_REVERSE_PROXY} );
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
    schema => {
        todo_item => {
            title => 'To-Do Item',
            description => unindent( trim q{
                A recurring task to do. Tasks are available during a `period`, and
                should be completed `per_period` times.
            }),
            example => {
                period => "day",
                title => "Did you brush your teeth?",
                per_period => 1,
            },
            properties => {
                period => {
                    description => 'How long a task is available to do.',
                    enum => [qw( day week month )],
                },
                per_period => {
                    description => 'The number of times to do this item per period.',
                },
                target_percent => {
                    description => 'The percentage of times we want to reach',
                },
                start_date => {
                    description => 'The date to start using this item. Defaults to today.',
                },
            },
            'x-list-columns' => [qw( title period per_period target_percent )],
        },
        todo_log => {
            title => 'To-Do Log',
            'x-list-columns' => [qw( id start_date end_date )],
            description => unindent( trim q{
                A log of the to-do items that have been completed.
            } ),
            properties => {
                date => {
                    type => [qw( string null )],
                    description => 'The date which this item was logged.',
                },
            },
        },
    },
};

app->yancy->plugin( 'Auth', {
    schema => 'users',
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

get '/api/todo/:date' => (
    controller => 'yancy',
    action => 'list',
    schema => 'todo_item',
), 'todo.list';

get '/api/log/:date' => {
    controller => 'yancy',
    action => 'list',
    schema => 'todo_log',
    filter => sub {
        my ( $c ) = @_;
        my $date = $c->stash( 'date' ) // DateTime->today( time_zone => 'US/Central' );
        return {
            start_date => { '<=', $date },
            end_date => { '>=', $date },
        };
    },
}, 'log.list';

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

get '/' => sub {
    my ( $c ) = @_;
    $c->redirect_to( 'todo.list',
        date => DateTime->today( time_zone => 'US/Central' )->ymd( '-' ),
    );
};

app->start;
__DATA__

@@ todo/list.html.ep
% layout 'default';
% title 'Todo List';

<div class="row" id="app">
    <div class="col-md-12">

        <h1 class="text-center">{{ date }}</h1>

        <ul class="list-group" id="todo-items">
            % for my $i ( 1..4 ) {
            <li class="list-group-item d-flex flex-column" id="todo-item-<%= $i %>">
                <div class="todo-item d-flex align-items-center">
                    <span class="todo-text flex-grow-1">Did you brush your teeth today?</span>
                    <button class="btn btn-success mx-1" type="button"
                        data-toggle="collapse" data-target="#todo-expanded-<%= $i %>-1"
                        aria-expanded="false" aria-controls="todo-expanded-<%= $i %>-1"
                    >
                        1
                    </button>
                    <button class="btn btn-outline-secondary mx-1" type="button"
                        data-toggle="collapse" data-target="#todo-expanded-<%= $i %>-2"
                        aria-expanded="false" aria-controls="todo-expanded-<%= $i %>-2"
                    >
                        2
                    </button>
                    <button class="btn btn-primary mx-1" type="button">Complete</button>
                </div>

                <div class="todo-expanded collapse" id="todo-expanded-<%= $i %>-1"
                    data-parent="#todo-items"
                >
                    <div class="d-flex m-1 align-items-center justify-content-end">
                        <%= text_field 'notes',
                            style => 'flex: 1 1 50%',
                            value => 'This is the note for number 1',
                            readonly => 1, disabled => 1,
                        %>
                    </div>
                </div>
                <div class="todo-expanded collapse" id="todo-expanded-<%= $i %>-2"
                    data-parent="#todo-items"
                >
                    <div class="d-flex m-1 align-items-center justify-content-end">
                        <%= text_field 'notes',
                            style => 'flex: 1 1 50%',
                            value => 'This is the note for number 2',
                        %>
                    </div>
                </div>
            </li>
            % }
        </ul>

        %= javascript begin
            Vue.use(Vuex);

            var store = new Vuex.Store({
                % use Mojo::JSON qw( encode_json );
                strict: <%= encode_json app->mode eq 'development' %>,
                state: {
                    date: new Date().toISOString().substring( 0, 10 ),
                    todoItems: {
                    },
                    logItems: {
                    },
                },
                mutations: {
                    setDate: function ( state, newDate ) {
                        state.date = newDate;
                    },
                    setLogItems: function ( state, newItems ) {
                        state.logItems = newItems;
                    },
                },
                actions: {
                    fetchItemsForDate: function ( context, date ) {
                        return $.ajax({
                            url: "<%= url_for 'log.list', date => undef %>" + date,
                            headers: {
                                "Accept": "application/json",
                            },
                        })
                        .then(
                            function ( msg ) {
                                context.commit( 'setDate', date );
                                context.commit( 'setLogItems', msg );
                            },
                            function ( xhr, status ) {
                            }
                        );
                    },
                    updateLog: function ( context, logItem, update ) {
                    },
                },
            });

            var vm = new Vue({
                el: '#app',
                store: store,
                data: function () {
                    return { };
                },
                methods: {
                },
                computed: {
                    date: function () { return this.$store.state.date; },
                },
                mounted: function () {
                    this.$store.dispatch( 'fetchItemsForDate', this.$store.state.date );
                },
            });
        % end

    </div>
</div>

@@ layouts/default.html.ep
<!DOCTYPE html>
<html>
    <head>
        <title><%= title %></title>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        %= stylesheet '/yancy/bootstrap.css'
        %= javascript '/yancy/jquery.js'
        %= javascript '/yancy/bootstrap.js'
        %= javascript '/yancy/vue.js'
        %= javascript 'https://cdnjs.cloudflare.com/ajax/libs/vuex/3.1.1/vuex.min.js'
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
-- 3 up
ALTER TABLE todo_log RENAME COLUMN completed TO date;
ALTER TABLE todo_item RENAME COLUMN interval TO per_period;
ALTER TABLE todo_item ADD COLUMN target_percent INTEGER DEFAULT 80;
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
