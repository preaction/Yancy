
use Mojolicious::Lite;
use Mojo::SQLite;
use Mojo::File qw( curfile );
use lib "".curfile->dirname->dirname->sibling( 'lib' );

helper sqlite => sub {
    state $path = $ENV{TEST_YANCY_EXAMPLES} ? ':temp:' : app->home->child( 'data.db' );
    state $sqlite = Mojo::SQLite->new( 'sqlite:' . $path );
    return $sqlite;
};
app->sqlite->auto_migrate(1)->migrations->from_data;

app->defaults({ layout => 'default' });

plugin AutoReload =>;
plugin Yancy => {
    backend => { Sqlite => app->sqlite },
    read_schema => 1,
};

my @running_jobs;
$SIG{INT} = $SIG{TERM} = sub {
    app->log->info( 'Cancelling jobs...' );
    for my $job ( grep { $_->{steps} > $_->{steps_finished} } @running_jobs ) {
        app->log->debug( 'Cancelling job ' . $_->{job_id} );
        app->yancy->backend->set(
            jobs => $job->{job_id},
            { %$job, state => 'cancelled', steps_finished => $job->{steps} },
        );
    }
    exit 0;
};

my %MESSAGES = (
    error => [
        q{Windmills do not work that way!},
        q{I don’t want to live on this planet anymore.},
        q{Please don't cry. I can't stand to see a living thing feel pain.},
        q{We hope to see you soon for tea.},
    ],

    warn => [
        q{Did everything just taste purple for a second?},
        q{I'm not giving up yet.},
        q{It's not that bad. It's just laden with toxic minerals.},
        q{I'm going to bam you up a dinner you'll never forget.},
    ],

    info => [
        q{I took the liberty of fertilizing your caviar.},
        q{I don’t have emotions & sometimes that makes me very sad.},
        q{You can crush me, but you can't crush my spirit!},
        q{Don't you wish you were flawless like me?},
    ],

    debug => [
        q{The big brain am winning again!},
        q{The post office meter is for business mail only.},
        q{You want to dump the corpses out of theres, it's yourses.},
        q{It's a humiliating and biased system. But it works.},
        q{Roller Derby is not a society.},
    ],
);

helper start_job => sub {
    my ( $c ) = @_;

    # Create the job record
    my %job = (
        steps => int rand( 50 ) + 50,
        steps_finished => 0,
        state => 'running',
    );
    push @running_jobs, \%job;
    $job{ job_id } = $c->yancy->backend->create( jobs => \%job );

    # Start a timer to add regular log messages
    my $timer_id; $timer_id = Mojo::IOLoop->recurring( 1, sub {
        my $rand = rand() * 100;
        my $log_level = $rand < 10 ? 'error'
            : $rand < 25 ? 'warn'
            : $rand < 50 ? 'info'
            : 'debug';
        $c->yancy->backend->create( logs => {
            job_id => $job{ job_id },
            log_level => $log_level,
            message => $MESSAGES{ $log_level }[ int rand scalar @{ $MESSAGES{ $log_level } } ],
        } );

        if ( $rand < 0.3 ) {
            $job{ state } = 'failed';
            $job{ steps_finished } = $job{ steps };
            Mojo::IOLoop->remove( $timer_id );
        }
        else {
            # Finish a step
            $job{ steps_finished } += int( rand 8 ) + 1;
            if ( $job{ steps_finished } >= $job{ steps } ) {
                $job{ steps_finished } = $job{ steps };
                $job{ state } = 'finished';
                Mojo::IOLoop->remove( $timer_id );
            }
        }
        $c->yancy->backend->set( jobs => $job{ job_id }, \%job );
    } );
};

post '/start', sub {
    my ( $c ) = @_;
    $c->start_job;
    $c->redirect_to( '/' );
}, 'job.start';

get '/log/:job_id', {
    controller => 'yancy',
    action => 'get',
    schema => 'jobs',
    template => 'job_logs',
} => 'logs.list';

websocket '/feed/log/:job_id', {
    controller => 'yancy',
    action => 'feed',
    schema => 'logs',
    interval => 2,
    limit => 100,
    order_by => { -desc => 'timestamp' },
    filter => sub {
        my ( $c ) = @_;
        return { job_id => $c->stash( 'job_id' ) };
    },
} => 'logs.feed';

get '/<page:num>', {
    controller => 'yancy',
    action => 'list',
    page => 1,
    schema => 'jobs',
    template => 'job_list',
} => 'jobs.list';

websocket '/feed/jobs', {
    controller => 'yancy',
    action => 'feed',
    schema => 'jobs',
    limit => 100,
    order_by => { -desc => 'started' },
    interval => 2,
} => 'jobs.feed';

app->start;
__DATA__

@@ layouts/default.html.ep
<!DOCTYPE html>
<html>
    <head>
        <title><%= title %></title>
        %= stylesheet '/yancy/bootstrap.css'
        %= stylesheet '/site.css'
    </head>
    <body>
        <main class="container">
            %= content
        </main>
    </body>
</html>

@@ site.css

.log-line {
    display: flex;
    font: 14px "Courier New", monospace;
}
.log-line :nth-child(1) {
    flex: 0 0 auto;
    margin-right: 1em;
}
.log-line :nth-child(2) {
    flex: 0 0 4em;
    text-align: center;
    margin-right: 1em;
}
.log-line :nth-child(3) {
}

@@ job_list.html.ep
<template id="running-jobs-tmpl">
    <div>
        <table class="table table-striped">
            <thead>
                <tr>
                    <th>ID</th>
                    <th>Started</th>
                    <th class="w-75"></th>
                </tr>
            </thead>
            <tbody>
                <tr v-for="item in $data.items">
                    <td><a :href="'/log/' + item.job_id">{{ item.job_id }}</a></td>
                    <td>{{ item.started }}</td>
                    <td>
                        <div class="progress">
                            <div class="progress-bar" role="progressbar"
                                :class="stateClass( item.state )"
                                :style="'width: ' + ( 100 * ( item.steps_finished / item.steps ) ) + '%'"
                                :aria-valuenow="item.steps_finished" aria-valuemin="0"
                                :aria-valuemax="item.steps"
                            >
                                {{ item.steps_finished }} / {{ item.steps }}
                            </div>
                        </div>
                    </td>
                </tr>
            </tbody>
        </table>

    </div>
</template>

<!-- on the first page, show auto-updating list -->
<div id="app">
    <div class="d-flex justify-content-end">
        <button class="btn btn-primary" @click="startJob" :disabled="startingJob">Start Job</button>
    </div>
    <running-jobs src="<%= url_for( 'jobs.feed' )->to_abs->scheme( 'ws' ) %>"></running-jobs>
</div>
%= javascript '/yancy/jquery.js'
%= javascript '/yancy/popper.js'
%= javascript '/yancy/bootstrap.js'
%= javascript '/yancy/vue.js'
%= javascript '/yancy/component/table.js'
%= javascript begin
    Vue.component( 'running-jobs', Vue.component('yancy-table').extend( {
        template: '#running-jobs-tmpl',
        methods: {
            stateClass( state ) {
                return {
                    running: 'bg-info',
                    cancelled: 'bg-warning',
                    finished: 'bg-success',
                    failed: 'bg-danger',
                }[ state ];
            },
        },
    } ) );
    let vm = new Vue({
        el: '#app',
        data() {
            return {
                startingJob: false,
            };
        },
        methods: {
            startJob() {
                this.startingJob = true;
                $.ajax({
                    method: 'POST',
                    url: '<%= url_for "job.start" %>',
                    success: () => this.startingJob = false,
                    error: () => this.startingJob = false,
                });
            },
        },
    });
% end

@@ job_logs.html.ep
<%
    use Mojo::JSON qw( j );
    my %log_level_class = (
        info => 'badge badge-info',
        warn => 'badge badge-warning',
        debug => 'badge badge-secondary',
        error => 'badge badge-danger',
    );
%>

%= link_to '< Job List', 'jobs.list', class => 'btn btn-secondary'

<section id="log">
    % for my $log ( $c->yancy->list( logs => { job_id => stash 'job_id' } ) ) {
        <div class="log-line">
            <datetime><%= $log->{ timestamp } %></datetime>
            <span class="<%= $log_level_class{ $log->{ log_level } } %>">
                <%= $log->{ log_level } %>
            </span>
            <span><%= $log->{ message } %></span>
        </div>
    % }
    <div id="app">
        <div v-for="log in items" class="log-line">
            <datetime>{{ log.timestamp }}</datetime>
            <span :class="logLevelClass( log.log_level )">
                {{ log.log_level }}
            </span>
            <span>{{ log.message }}</span>
        </div>
    </div>
</section>

%= javascript '/yancy/jquery.js'
%= javascript '/yancy/vue.js'
%= javascript begin
    let vm = new Vue({
        el: '#app',
        data() {
            return {
                items: [],
                url: "<%= url_for( 'logs.feed' )->to_abs->scheme( 'ws' ) %>",
            };
        },
        mounted() {
            this.ws = new WebSocket( this.url );
            this.ws.onmessage = ( msg ) => this.recv( msg );
        },
        methods: {
            recv( msg ) {
                let res = JSON.parse( msg.data );
                if ( res.method == 'create' ) {
                    console.log( 'Got new item: ', res.item );
                    // If we get more than one log message, we want to put them in the
                    // right order.
                    this.items.splice( this.items.length - res.index, 0, res.item );
                }
            },
            logLevelClass( level ) {
                return <%== j \%log_level_class %>[ level ];
            },
        },
    });
% end

@@ migrations
-- 1 up
CREATE TABLE jobs (
    job_id INTEGER PRIMARY KEY AUTOINCREMENT,
    started TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    finished TIMESTAMP DEFAULT NULL,
    steps INTEGER NOT NULL,
    steps_finished INTEGER DEFAULT 0,
    state VARCHAR DEFAULT "inactive"
);
CREATE TABLE logs (
    log_id INTEGER PRIMARY KEY AUTOINCREMENT,
    job_id INTEGER NOT NULL,
    log_level VARCHAR NOT NULL,
    "timestamp" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "message" TEXT NOT NULL
);

-- 1 down
DROP TABLE jobs;
DROP TABLE logs;
