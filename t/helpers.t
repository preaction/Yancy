
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

my $t = Test::Mojo->new( 'Yancy', {
    backend => $backend_url,
    collections => $collections,
    read_schema => 1,
} );
$t->app->yancy->filter->add( foobar => sub { 'foobar' } );
$backend = $t->app->yancy->backend;

subtest 'list' => sub {
    my @got_list = $t->app->yancy->list( 'people' );
    is_deeply
        \@got_list,
        [ @{ $backend->list( people => {}, {} )->{rows} } ]
            or diag explain \@got_list;

    @got_list = $t->app->yancy->list( 'people', {}, { limit => 1, offset => 1 } );
    is_deeply
        \@got_list,
        [ $backend->get( people => 2 ) ]
            or diag explain \@got_list;
};

subtest 'get' => sub {
    my $got = $t->app->yancy->get( people => 1 );
    is_deeply
        $got,
        $backend->get( people => 1 )
            or diag explain $got;
};

subtest 'set' => sub {
    my $new_person = { name => 'Foo', email => 'doug@example.com', id => 1 };
    $t->app->yancy->set( people => 1 => { %{ $new_person } });
    $new_person->{name} = 'foobar'; # filters are executed
    is_deeply $backend->get( people => 1 ), $new_person;

    subtest 'set dies with missing fields' => sub {
        eval { $t->app->yancy->set( people => 1 => {} ) };
        ok $@, 'set() dies';
        is blessed $@->[0], 'JSON::Validator::Error' or diag explain $@;
        is_deeply $backend->get( people => 1 ), $new_person,
            'person is not saved';
    };
};

my $added_id;
subtest 'create' => sub {
    my $new_person = { name => 'Bar', email => 'bar@example.com' };
    my $got = $t->app->yancy->create( people => { %{ $new_person } });
    $new_person->{name} = 'foobar'; # filters are executed
    $added_id = $new_person->{id} = $got->{id};
    is_deeply $backend->get( people => $got->{id} ), $new_person;

    my $count = $backend->list( 'people' )->{total};
    subtest 'create dies with missing fields' => sub {
        eval { $t->app->yancy->create( people => {} ) };
        ok $@, 'create() dies';
        is blessed $@->[0], 'JSON::Validator::Error' or diag explain $@;
        is $backend->list( 'people' )->{total},
            $count, 'no new person was added';
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

done_testing;
