
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

my $collections = \%Yancy::Backend::Test::SCHEMA;
$collections->{people}{properties}{name}{'x-filter'} = [ 'foobar' ];

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
    user => [
        {
            username => 'preaction',
            password => 'secret',
            email => 'doug@example.com',
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

subtest 'yancy.filters' => sub {
    my $filters = $t->app->yancy->filters;
    isa_ok $filters, 'HASH';
    isa_ok $filters->{foobar}, 'CODE';
};

subtest 'list' => sub {
    my @got_list = $t->app->yancy->list( 'people' );
    is_deeply
        \@got_list,
        [ @{ $items{people} } ]
            or diag explain \@got_list;

    @got_list = $t->app->yancy->list( 'people', {}, { limit => 1, offset => 1 } );
    is scalar @got_list, 1, 'one person returned';
    is $got_list[0]{email}, 'joel@example.com', 'correct person returned';

    @got_list = $t->app->yancy->list( 'user' );
    my $got = $got_list[0];
    is $got->{username}, $items{user}[0]{username}, 'got username from list() helper';
    ok !exists $got->{password}, 'format=>"password" field removed by list() helper';
};

subtest 'get' => sub {
    my $got = $t->app->yancy->get( people => $items{people}[0]{id} );
    is_deeply
        $got,
        $items{people}[0]
            or diag explain $got;
    $got = $t->app->yancy->get( user => $items{user}[0]{username} );
    is $got->{username}, $items{user}[0]{username}, 'got username from get() helper';
    ok !exists $got->{password}, 'format=>"password" field removed by get() helper';
};

subtest 'set' => sub {
    my $set_id = $items{people}[0]{id};
    my $new_person = {
        name => 'Foo',
        email => 'doug@example.com',
        age => 35,
        contact => 0,
        phone => '555 555-0199',
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
        like $t->app->log->history->[-1][2], qr{Error validating item with ID "$set_id" in schema "people": $message \($path\)},
            'error message is logged with JSON validation error';

        is_deeply $backend->get( people => $set_id ), $new_person,
            'person is not saved';

        $message = $@->[0]{message};
        $path = $@->[0]{path};
        is $t->app->log->history->[-1][1], 'error',
            'error message is logged at error level';
        like $t->app->log->history->[-1][2], qr{Error validating item with ID "$set_id" in schema "people": $message \($path\)},
            'error message is logged with JSON validation error';
    };

    subtest 'set numeric field with string containing number' => sub {
        eval {
            $t->app->yancy->set( people =>
                $items{people}[0]{id},
                { age => "20" },
                properties => [ 'age' ]
            )
        };
        ok !$@, 'set() lives'
            or diag "Errors: \n" . join "\n", map { "\t$_" } @{ $@ };
        is $backend->get( people => $items{people}[0]{id} )->{age}, 20;
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
            phone => '555 555-0199',
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

    subtest 'set boolean field' => sub {
        subtest 'with 1 as true' => sub {
            eval {
                $t->app->yancy->set( people =>
                    $items{people}[0]{id},
                    { contact => 1 },
                    properties => [ 'contact' ]
                )
            };
            ok !$@, 'set() lives'
                or diag "Errors: \n" . join "\n", map { "\t$_" } ref $@ ? @{$@} : $@;
            is $backend->get( people => $items{people}[0]{id} )->{contact}, 1;
        };

        subtest 'with "true" as true' => sub {
            eval {
                $t->app->yancy->set( people =>
                    $items{people}[0]{id},
                    { contact => 'true' },
                    properties => [ 'contact' ]
                )
            };
            ok !$@, 'set() lives'
                or diag "Errors: \n" . join "\n", map { "\t$_" } ref $@ ? @{$@} : $@;
            is $backend->get( people => $items{people}[0]{id} )->{contact}, 1;
        };

        subtest 'with "0" as false' => sub {
            eval {
                $t->app->yancy->set( people =>
                    $items{people}[0]{id},
                    { contact => "0" },
                    properties => [ 'contact' ]
                )
            };
            ok !$@, 'set() lives'
                or diag "Errors: \n" . join "\n", map { "\t$_" } ref $@ ? @{$@} : $@;
            is $backend->get( people => $items{people}[0]{id} )->{contact}, 0;
        };

        subtest 'with "false" as false' => sub {
            eval {
                $t->app->yancy->set( people =>
                    $items{people}[0]{id},
                    { contact => "false" },
                    properties => [ 'contact' ]
                )
            };
            ok !$@, 'set() lives'
                or diag "Errors: \n" . join "\n", map { "\t$_" } ref $@ ? @{$@} : $@;
            is $backend->get( people => $items{people}[0]{id} )->{contact}, 0;
        };
    };

    subtest 'set email field to test openapi "format"' => sub {
        eval {
            $t->app->yancy->set( user =>
                0,
                { email => "" },
                properties => [ 'email' ]
            )
        };
        ok $@, 'set() dies';
        like $@->[0]{path}, qr{/email}, 'email is invalid';
        like $@->[0]{message}, qr{Does not match email format}, 'format error correct';
    };

    subtest 'backend method dies' => sub {
        no strict 'refs';
        no warnings 'redefine';
        local *{$backend_class . '::set'} = sub { die "Died" };
        my %new_person_noid = %$new_person;
        delete $new_person_noid{id};
        eval {
            $t->app->yancy->set( people => $set_id => \%new_person_noid );
        };
        ok $@, 'set dies';
        like $@, qr{Died}, 'set dies with same error';
        is $t->app->log->history->[-1][1], 'error',
            'error message is logged at error level';
        like $t->app->log->history->[-1][2],
            qr{Error setting item with ID "$set_id" in schema "people": Died},
            'error message is logged with backend error';
    };

};

my $added_id;
subtest 'create' => sub {
    my $new_person = {
        name => 'Bar',
        email => 'bar@example.com',
        age => 28,
        phone => undef,
    };
    my $got_id = $t->app->yancy->create( people => { %{ $new_person } });
    $new_person->{name} = 'foobar'; # filters are executed
    $new_person->{contact} = 0; # "default" is added
    $added_id = $new_person->{id} = $got_id;
    is_deeply $backend->get( people => $got_id ), $new_person;

    # Test 'markdown' format
    my $new_blog = {
        user_id => $items{user}[0]{id},
        title => 'Bar',
        slug => '/index',
        markdown => '# Bar',
        html => '',
        is_published => 0,
    };
    my $blog_id = eval { $t->app->yancy->create( blog => { %{ $new_blog } }) };
    ok !$@, 'create() lives' or diag explain $@;
    $new_blog->{id} = $blog_id;
    is_deeply $backend->get( blog => $blog_id ), $new_blog;

    my $count = $backend->list( 'people' )->{total};
    subtest 'create dies with missing fields' => sub {
        eval { $t->app->yancy->create( people => {} ) };
        ok $@, 'create() dies';
        is blessed $@->[0], 'JSON::Validator::Error' or diag explain $@;
        my $message = $@->[0]{message};
        my $path = $@->[0]{path};
        is $t->app->log->history->[-1][1], 'error',
            'error message is logged at error level';
        like $t->app->log->history->[-1][2], qr{Error validating new item in schema "people": $message \($path\)},
            'error message is logged with JSON validation error';

        is $backend->list( 'people' )->{total},
            $count, 'no new person was added';
    };

    subtest 'backend method dies' => sub {
        no strict 'refs';
        no warnings 'redefine';
        local *{$backend_class . '::create'} = sub { die "Died" };
        my %new_person_noid = %$new_person;
        delete $new_person_noid{id};
        eval {
            $t->app->yancy->create( people => \%new_person_noid );
        };
        ok $@, 'create dies';
        like $@, qr{Died}, 'create dies with same error';
        is $t->app->log->history->[-1][1], 'error',
            'error message is logged at error level';
        like $t->app->log->history->[-1][2],
            qr{Error creating item in schema "people": Died},
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
    eval { $t->app->yancy->plugin( 'Notfound' ) };
    like $@, qr/Could not find/, 'plugin not found = error';
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
            'schema( $coll ) is correct'
            or diag explain $t->app->yancy->schema( 'user' );
    };

    subtest 'get all schemas' => sub {
        is_deeply $t->app->yancy->schema, $collections,
            'schema() gets all collections'
            or diag explain $t->app->yancy->schema;

        my $t = Test::Mojo->new( Mojolicious->new );
        $t->app->plugin( Yancy => {
            backend => $backend_url,
            read_schema => 1,
        });
        my $collection_keys = [ sort keys %{ $t->app->yancy->schema } ];
        is_deeply $collection_keys,
            [qw{ blog mojo_migrations people user }],
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
