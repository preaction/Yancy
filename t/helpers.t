
=head1 DESCRIPTION

This test makes sure the backend helpers registered by L<Mojolicious::Plugin::Yancy>
work correctly.

=head1 SEE ALSO

L<Yancy::Backend::Test>

=cut

use Mojo::Base '-strict';
use Test::More;
use Test::Mojo;
use Mojo::JSON qw( true false );
use FindBin qw( $Bin );
use Mojo::File qw( path );
use Scalar::Util qw( blessed );
use lib "".path( $Bin, 'lib' );
use Local::Test qw( init_backend );

my $collections = {
    people => {
        required => [qw( name )],
        properties => {
            id => {
                'x-order' => 1,
            },
            name => {
                'x-order' => 2,
                description => 'The real name of the person',
                'x-filter' => [ 'foobar' ],
            },
            email => {
                'x-order' => 3,
                pattern => '^[^@]+@[^@]+$',
            },
            age => {
                'x-order' => 4,
                type => 'integer',
            },
            contact => {
                'x-order' => 5,
                type => 'boolean',
            },
            birthdate => {
                'x-order' => 6,
                type => 'string',
                format => 'date',
            },
        },
    },
    user => {
        'x-id-field' => 'username',
        'x-list-columns' => [qw( username email )],
        required => [qw( username email password )],
        properties => {
            username => {
                type => 'string',
                'x-order' => 1,
            },
            email => {
                type => 'string',
                'x-order' => 2,
            },
            password => {
                type => 'string',
                format => 'password',
                'x-order' => 3,
            },
            access => {
                type => 'string',
                enum => [qw( user moderator admin )],
                'x-order' => 4,
            },
        },
    },
};
my ( $backend_url, $backend, %items ) = init_backend(
    $collections,
    people => [
        {
            name => 'Doug Bell',
            email => 'doug@example.com',
        },
        {
            name => 'Joel Berger',
            email => 'joel@example.com',
        },
    ],
);
my $backend_class = blessed $backend;

my $t = Test::Mojo->new( 'Yancy', {
    backend => $backend_url,
    collections => $collections,
    read_schema => 1,
} );
# We must still set the envvar so Test::Mojo doesn't reset it to "fatal"
$t->app->log->level( $ENV{MOJO_LOG_LEVEL} = 'error' );

# do not log to std(out,err)
open my $logfh, '>', \my $logbuf;
$t->app->log->handle( $logfh );

$t->app->yancy->filter->add( foobar => sub { 'foobar' } );
$backend = $t->app->yancy->backend;

subtest 'list' => sub {
    my @got_list = $t->app->yancy->list( 'people' );
    is_deeply
        \@got_list,
        [ @{ $items{people} } ]
            or diag explain \@got_list;

    @got_list = $t->app->yancy->list( 'people', {}, { limit => 1, offset => 1 } );
    is scalar @got_list, 1, 'one person returned';
    is $got_list[0]{email}, 'joel@example.com', 'correct person returned';
};

subtest 'get' => sub {
    my $got = $t->app->yancy->get( people => $items{people}[0]{id} );
    is_deeply
        $got,
        $items{people}[0]
            or diag explain $got;
};

subtest 'set' => sub {
    my $set_id = $items{people}[0]{id};
    my $new_person = {
        name => 'Foo',
        email => 'doug@example.com',
        age => 35,
        contact => 0,
    };
    $t->app->yancy->set( people => $set_id => { %{ $new_person } });
    $new_person->{id} = $set_id;
    $new_person->{name} = 'foobar'; # filters are executed
    is_deeply $backend->get( people => $set_id ), $new_person;

    subtest 'set dies with missing fields' => sub {
        eval { $t->app->yancy->set( people => $set_id => {} ) };
        ok $@, 'set() dies';
        is blessed $@->[0], 'JSON::Validator::Error' or diag explain $@;
        my $message = $@->[0]{message};
        my $path = $@->[0]{path};
        #; print explain $t->app->log->history;
        is $t->app->log->history->[-1][1], 'error',
            'error message is logged at error level';
        like $t->app->log->history->[-1][2], qr{Error validating item with ID "$set_id" in collection "people": $message \($path\)},
            'error message is logged with JSON validation error';

        is_deeply $backend->get( people => $set_id ), $new_person,
            'person is not saved';

        $message = $@->[0]{message};
        $path = $@->[0]{path};
        is $t->app->log->history->[-1][1], 'error',
            'error message is logged at error level';
        like $t->app->log->history->[-1][2], qr{Error validating item with ID "$set_id" in collection "people": $message \($path\)},
            'error message is logged with JSON validation error';
    };

    subtest 'set numeric field with string containing number' => sub {
        my $set_id = $items{people}[0]{id};
        my $new_person = {
            name => 'foobar',
            email => 'doug@example.com',
            age => 20,
            contact => 0,
        };
        eval { $t->app->yancy->set( people => $set_id => { %{ $new_person } } ) };
        ok !$@, 'set() lives'
            or diag "Errors: \n" . join "\n", map { "\t$_" } @{ $@ };
        $new_person->{id} = $set_id;
        is_deeply $backend->get( people => $set_id ), $new_person;
    };

    subtest 'set boolean field' => sub {
        subtest 'with "1" as true' => sub {
            my $set_id = $items{people}[0]{id};
            my $new_person = { name => 'foobar', email => 'doug@example.com', contact => 1 };
            eval { $t->app->yancy->set( people => $set_id => { %{ $new_person } } ) };
            ok !$@, 'set() lives'
                or diag "Errors: \n" . join "\n", map { "\t$_" } ref $@ ? @{$@} : $@;
            $new_person->{id} = $set_id;
            $new_person->{age} = 20;
            is_deeply $backend->get( people => $set_id ), $new_person;
        };

        subtest 'with "true" as true' => sub {
            my $set_id = $items{people}[0]{id};
            my $new_person = { name => 'foobar', email => 'doug@example.com', contact => "true" };
            eval { $t->app->yancy->set( people => $set_id => { %{ $new_person } } ) };
            ok !$@, 'set() lives'
                or diag "Errors: \n" . join "\n", map { "\t$_" } ref $@ ? @{$@} : $@;
            $new_person->{id} = $set_id;
            $new_person->{age} = 20;
            $new_person->{contact} = 1;
            is_deeply $backend->get( people => $set_id ), $new_person;
        };

        subtest 'with "0" as false' => sub {
            my $set_id = $items{people}[0]{id};
            my $new_person = { name => 'foobar', email => 'doug@example.com', contact => 0 };
            eval { $t->app->yancy->set( people => $set_id => { %{ $new_person } } ) };
            ok !$@, 'set() lives'
                or diag "Errors: \n" . join "\n", map { "\t$_" } ref $@ ? @{$@} : $@;
            $new_person->{id} = $set_id;
            $new_person->{age} = 20;
            is_deeply $backend->get( people => $set_id ), $new_person;
        };

        subtest 'with "false" as false' => sub {
            my $set_id = $items{people}[0]{id};
            my $new_person = { name => 'foobar', email => 'doug@example.com', contact => "false" };
            eval { $t->app->yancy->set( people => $set_id => { %{ $new_person } } ) };
            ok !$@, 'set() lives'
                or diag "Errors: \n" . join "\n", map { "\t$_" } ref $@ ? @{$@} : $@;
            $new_person->{id} = $set_id;
            $new_person->{age} = 20;
            $new_person->{contact} = 0;
            is_deeply $backend->get( people => $set_id ), $new_person;
        };
    };

    subtest 'set date field with "" is an error' => sub {
        my $set_id = $items{people}[0]{id};
        my $new_person = { name => 'foobar', email => 'doug@example.com', birthdate => '' };
        eval { $t->app->yancy->set( people => $set_id => { %{ $new_person } } ) };
        ok $@, 'set() dies';
        like $@->[0]{path}, qr{/birthdate}, 'birthdate is invalid';
        like $@->[0]{message}, qr{Does not match date format}, 'format error correct';
    };

    subtest 'set partial (assume required fields are already set)' => sub {
        my $set_id = $items{people}[0]{id};
        my $new_email = { email => 'doug@example.com' };
        eval {
            $t->app->yancy->set(
                people => $set_id => { %{ $new_email } },
                properties => [qw( email )],
            );
        };
        ok !$@, 'set() lives'
            or diag "Errors: \n" . join "\n", map { "\t$_" } @{ $@ };
        my $new_person = {
            id => $set_id,
            name => 'foobar',
            email => 'doug@example.com',
            contact => '0',
            age => 20,
            %$new_email,
        };
        is_deeply $backend->get( people => $set_id ), $new_person;

        subtest 'required fields are still required' => sub {
            eval {
                $t->app->yancy->set(
                    people => $set_id => {},
                    properties => [qw( name )],
                );
            };
            ok $@, 'set() dies';
            like $@->[0]{path}, qr{/name}, 'name is missing';
            like $@->[0]{message}, qr{Missing}, 'missing error correct';
        };
    };

    subtest 'backend method dies' => sub {
        no strict 'refs';
        no warnings 'redefine';
        local *{$backend_class . '::set'} = sub { die "Died" };
        eval {
            $t->app->yancy->set( people => $set_id => { %{ $new_person } });
        };
        ok $@, 'set dies';
        like $@, qr{Died}, 'set dies with same error';
        is $t->app->log->history->[-1][1], 'error',
            'error message is logged at error level';
        like $t->app->log->history->[-1][2],
            qr{Error setting item with ID "$set_id" in collection "people": Died},
            'error message is logged with backend error';
    };

};

my $added_id;
subtest 'create' => sub {
    my $new_person = {
        name => 'Bar',
        email => 'bar@example.com',
        age => 28,
        contact => 0,
    };
    my $got_id = $t->app->yancy->create( people => { %{ $new_person } });
    $new_person->{name} = 'foobar'; # filters are executed
    $added_id = $new_person->{id} = $got_id;
    is_deeply $backend->get( people => $got_id ), $new_person;

    my $count = $backend->list( 'people' )->{total};
    subtest 'create dies with missing fields' => sub {
        eval { $t->app->yancy->create( people => {} ) };
        ok $@, 'create() dies';
        is blessed $@->[0], 'JSON::Validator::Error' or diag explain $@;
        my $message = $@->[0]{message};
        my $path = $@->[0]{path};
        is $t->app->log->history->[-1][1], 'error',
            'error message is logged at error level';
        like $t->app->log->history->[-1][2], qr{Error validating new item in collection "people": $message \($path\)},
            'error message is logged with JSON validation error';

        is $backend->list( 'people' )->{total},
            $count, 'no new person was added';
    };

    subtest 'backend method dies' => sub {
        no strict 'refs';
        no warnings 'redefine';
        local *{$backend_class . '::create'} = sub { die "Died" };
        eval {
            $t->app->yancy->create( people => { %{ $new_person } });
        };
        ok $@, 'create dies';
        like $@, qr{Died}, 'create dies with same error';
        is $t->app->log->history->[-1][1], 'error',
            'error message is logged at error level';
        like $t->app->log->history->[-1][2],
            qr{Error creating item in collection "people": Died},
            'error message is logged with backend error';
    };

};

subtest 'delete' => sub {
    $t->app->yancy->delete( people => $added_id );
    ok !$backend->get( people => $added_id ), "person $added_id not exists";
};

subtest 'plugin' => sub {
    my $t = Test::Mojo->new( Mojolicious->new );
    $t->app->plugin( 'Yancy', {
        backend => $backend_url,
        collections => $collections,
        read_schema => 1,
    } );
    $t->app->yancy->plugin( 'Test', { route => '/plugin', args => 1 } );
    $t->get_ok( '/plugin' )
      ->status_is( 200 )
      ->json_is( [ { route => '/plugin', args => 1 } ] );
};

subtest 'openapi' => sub {
    my $t = Test::Mojo->new( Mojolicious->new );
    $t->app->plugin( 'Yancy', {
        backend => $backend_url,
        collections => $collections,
        read_schema => 1,
    } );
    my $openapi = $t->app->yancy->openapi;
    ok $openapi->validator, 'openapi helper returned meaningful object';
};

subtest 'schema' => sub {
    my $t = Test::Mojo->new( Mojolicious->new );
    $t->app->plugin( 'Yancy', {
        backend => $backend_url,
        collections => { %$collections },
        read_schema => 1,
    } );

    subtest 'get schema' => sub {
        is_deeply $t->app->yancy->schema( 'user' ), $collections->{user},
            'schema( $coll ) is correct';
    };

    subtest 'get all schemas' => sub {
        is_deeply $t->app->yancy->schema, $collections,
            'schema() gets all collections';

        my $t = Test::Mojo->new( Mojolicious->new );
        $t->app->plugin( Yancy => {
            backend => $backend_url,
            read_schema => 1,
        });
        my $collection_keys = [ sort keys %{ $t->app->yancy->schema } ];
        is_deeply $collection_keys,
            [qw{ mojo_migrations people user }],
            'schema() gets correct collections from read_schema'
            or diag explain $collection_keys;
    };

    subtest 'add schema' => sub {
        my $collection = {
            properties => {
                foo => {
                    type => 'string',
                },
            },
        };
        $t->app->yancy->schema( 'new_schema', $collection );
        is_deeply $t->app->yancy->schema( 'new_schema' ),
            $collection,
            'schema( $name, $schema ) sets schema';
    };
};

done_testing;
