
=head1 DESCRIPTION

This test ensures that the OpenAPI spec produced by Yancy is correct and the
API routes work as expected.

=head1 SEE ALSO

L<Yancy::Backend::Test>

=cut

use Mojo::Base '-strict';
use Test::More;
use Test::Mojo;
use Mojo::JSON qw( true false decode_json );
use FindBin qw( $Bin );
use Mojo::File qw( path );
use lib "".path( $Bin, 'lib' );
use Local::Test qw( init_backend );

my $collections = {
    people => {
        required => [qw( name )],
        properties => {
            id => {
                type => 'integer',
                'x-order' => 1,
            },
            name => {
                type => 'string',
                'x-order' => 2,
                description => 'The real name of the person',
            },
            email => {
                type => [ 'string', 'null' ],
                'x-order' => 3,
                format => 'email',
            },
            age => {
                type => [qw( integer null )],
                'x-order' => 4,
            },
            contact => {
                type => [qw( boolean null )],
                'x-order' => 5,
            },
            phone => {
                type => [ 'string', 'null' ],
                'x-order' => 6,
                format => 'tel',
            },
        },
    },
    user => {
        'x-id-field' => 'username',
        'x-list-columns' => [qw( username email )],
        required => [qw( username email password )],
        properties => {
            id => {
                'x-order' => 1,
                type => 'integer',
            },
            email => {
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
            username => {
                type => 'string',
                'x-order' => 5,
            },
            age => {
                type => [qw( integer null )],
                'x-order' => 6,
            },
        },
    },
    mojo_migrations => { 'x-ignore' => 1 },
};
my %data = (
    people => [
        {
            id => 1,
            name => 'Doug Bell',
            email => 'doug@example.com',
            age => 35,
            contact => 1,
        },
        {
            id => 2,
            name => 'Joel Berger',
            email => 'joel@example.com',
            age => 51,
            contact => 0,
        },
        {
            id => 3,
            name => 'Secret Person',
            contact => 0,
            age => undef, # exercise the deleting of nulls from returns
        },
    ],
    user => [
        {
            username => 'doug',
            email => 'doug@example.com',
            password => 'ignore',
            access => 'user',
            age => 35,
        },
        {
            username => 'joe/',
            email => 'joel@example.com',
            password => 'ignore',
            access => 'user',
            age => 32,
        },
    ],
);

my ( $backend_url, $backend, %items ) = init_backend( $collections, %data );
subtest 'declared collections' => \&test_api,
    Test::Mojo->new( 'Yancy', {
        backend => $backend_url,
        collections => $collections,
    } ),
    '/yancy/api';

( $backend_url, $backend, %items ) = init_backend( $collections, %data );
subtest 'read_schema collections' => \&test_api,
    Test::Mojo->new( 'Yancy', {
        backend => $backend_url,
        collections => $collections,
        read_schema => 1,
    } ),
    '/yancy/api';

( $backend_url, $backend, %items ) = init_backend( $collections, %data );
subtest 'different Yancy URL' => \&test_api,
    Test::Mojo->new( 'Yancy', {
        backend => $backend_url,
        collections => $collections,
        editor => { route => '/yancy2' },
    } ),
    '/yancy2/api';

my $openapi = decode_json path ( $Bin, 'share', 'openapi-spec.json' )->slurp;
( $backend_url, $backend, %items ) = init_backend( $collections, %data );
subtest 'pass openapi' => \&test_api,
    Test::Mojo->new( 'Yancy', {
        backend => $backend_url,
        openapi => $openapi,
    } ),
    '/yancy/api';

done_testing;

sub test_api {
    my ( $t, $api_path ) = @_;

    subtest 'fetch generated OpenAPI spec '.$api_path => sub {
        $t->get_ok( $api_path )
          ->status_is( 200 )
          ->content_type_like( qr{^application/json} )
          ->json_is( '/definitions/people' => {
            type => 'object',
            required => [qw( name )],
            properties => {
                id => {
                    'x-order' => 1,
                    type => 'integer',
                },
                name => {
                    'x-order' => 2,
                    type => 'string',
                    description => 'The real name of the person',
                },
                email => {
                    'x-order' => 3,
                    type => [ 'string', 'null' ],
                    format => 'email',
                },
                age => {
                    type => [qw( integer null )],
                    'x-order' => 4,
                },
                contact => {
                    type => [qw( boolean null )],
                    'x-order' => 5,
                },
                phone => {
                    type => [qw( string null )],
                    'x-order' => 6,
                    format => 'tel',
                },
            },
          } )

          ->json_is( '/definitions/user' => {
            type => 'object',
            'x-id-field' => 'username',
            'x-list-columns' => [qw( username email )],
            required => [qw( username email password )],
            properties => {
                id => {
                    'x-order' => 1,
                    type => 'integer',
                },
                email => {
                    'x-order' => 2,
                    type => 'string',
                },
                password => {
                    'x-order' => 3,
                    type => 'string',
                    format => 'password',
                },
                access => {
                    'x-order' => 4,
                    type => 'string',
                    enum => [qw( user moderator admin )],
                },
                username => {
                    'x-order' => 5,
                    type => 'string',
                },
                age => {
                    'x-order' => 6,
                    type => [ 'integer', 'null' ],
                },
            },
            'x-list-columns' => [qw( username email )],
          } )

          ->json_has( '/paths/~1people/get/responses/200' )
          ->json_has( '/paths/~1people/get/responses/default' )

          ->json_has( '/paths/~1people/post/parameters' )
          ->json_has( '/paths/~1people/post/responses/201' )
          ->json_has( '/paths/~1people/post/responses/400' )
          ->json_has( '/paths/~1people/post/responses/default' )

          ->json_has( '/paths/~1people~1{id}/parameters' )
          ->json_has( '/paths/~1people~1{id}/get/responses/200' )
          ->json_has( '/paths/~1people~1{id}/get/responses/404' )
          ->json_has( '/paths/~1people~1{id}/get/responses/default' )

          ->json_has( '/paths/~1people~1{id}/put/parameters' )
          ->json_has( '/paths/~1people~1{id}/put/responses/200' )
          ->json_has( '/paths/~1people~1{id}/put/responses/404' )
          ->json_has( '/paths/~1people~1{id}/put/responses/default' )

          ->json_has( '/paths/~1people~1{id}/delete/responses/204' )
          ->json_has( '/paths/~1people~1{id}/delete/responses/404' )
          ->json_has( '/paths/~1people~1{id}/delete/responses/default' )
          ;

    };

    subtest 'fetch list '.$api_path => sub {
        $t->get_ok( $api_path . '/people' )
          ->status_is( 200 )
          ->json_is( {
            items => [
                {
                    id => $items{people}[0]{id},
                    name => 'Doug Bell',
                    email => 'doug@example.com',
                    age => 35,
                    contact => 1,
                },
                {
                    id => $items{people}[1]{id},
                    name => 'Joel Berger',
                    email => 'joel@example.com',
                    age => 51,
                    contact => 0,
                },
                {
                    id => $items{people}[2]{id},
                    name => 'Secret Person',
                    contact => 0,
                },
            ],
            total => 3,
          } );

        subtest 'limit/offset' => sub {
            $t->get_ok( $api_path . '/people?$limit=1' )
              ->status_is( 200 )
              ->json_is( {
                items => [
                    {
                        id => $items{people}[0]{id},
                        name => 'Doug Bell',
                        email => 'doug@example.com',
                        age => 35,
                        contact => 1,
                    },
                ],
                total => 3,
              } );

            $t->get_ok( $api_path . '/people?$offset=1' )
              ->status_is( 200 )
              ->json_is( {
                items => [
                    {
                        id => $items{people}[1]{id},
                        name => 'Joel Berger',
                        email => 'joel@example.com',
                        age => 51,
                        contact => 0,
                    },
                    {
                        id => $items{people}[2]{id},
                        name => 'Secret Person',
                        contact => 0,
                    },
                ],
                total => 3,
              } );

        };

        subtest 'order_by' => sub {

            $t->get_ok( $api_path . '/people?$order_by=asc:name' )
              ->status_is( 200 )
              ->json_is( {
                items => [
                    {
                        id => $items{people}[0]{id},
                        name => 'Doug Bell',
                        email => 'doug@example.com',
                        age => 35,
                        contact => 1,
                    },
                    {
                        id => $items{people}[1]{id},
                        name => 'Joel Berger',
                        email => 'joel@example.com',
                        age => 51,
                        contact => 0,
                    },
                    {
                        id => $items{people}[2]{id},
                        name => 'Secret Person',
                        contact => 0,
                    },
                ],
                total => 3,
              } );

            $t->get_ok( $api_path . '/people?$order_by=desc:name' )
              ->status_is( 200 )
              ->json_is( {
                items => [
                    {
                        id => $items{people}[2]{id},
                        name => 'Secret Person',
                        contact => 0,
                    },
                    {
                        id => $items{people}[1]{id},
                        name => 'Joel Berger',
                        email => 'joel@example.com',
                        age => 51,
                        contact => 0,
                    },
                    {
                        id => $items{people}[0]{id},
                        name => 'Doug Bell',
                        email => 'doug@example.com',
                        age => 35,
                        contact => 1,
                    },
                ],
                total => 3,
              } );

        };

        subtest 'filter' => sub {
            $t->get_ok( $api_path . '/people?name=Doug*' )
              ->status_is( 200 )
              ->json_is( {
                items => [
                    {
                        id => $items{people}[0]{id},
                        name => 'Doug Bell',
                        email => 'doug@example.com',
                        age => 35,
                        contact => 1,
                    },
                ],
                total => 1,
              } );

            $t->get_ok( $api_path . '/people?name=*l' )
              ->status_is( 200 )
              ->json_is( {
                items => [
                    {
                        id => $items{people}[0]{id},
                        name => 'Doug Bell',
                        email => 'doug@example.com',
                        age => 35,
                        contact => 1,
                    },
                ],
                total => 1,
              } );

            $t->get_ok( $api_path . '/people?name=er' )
              ->status_is( 200 )
              ->json_is( {
                items => [
                    {
                        id => $items{people}[1]{id},
                        name => 'Joel Berger',
                        email => 'joel@example.com',
                        age => 51,
                        contact => 0,
                    },
                    {
                        id => $items{people}[2]{id},
                        name => 'Secret Person',
                        contact => 0,
                    },
                ],
                total => 2,
              } );

        };

    };

    subtest 'fetch one '.$api_path => sub {
        $t->get_ok( $api_path . '/people/' . $items{people}[0]{id} )
          ->status_is( 200 )
          ->json_is(
            {
                id => $items{people}[0]{id},
                name => 'Doug Bell',
                email => 'doug@example.com',
                age => 35,
                contact => 1,
            },
          );
        $t->get_ok( $api_path . '/people/' . $items{people}[2]{id} )
          ->status_is( 200 )
          ->json_is(
            {
                id => $items{people}[2]{id},
                name => 'Secret Person',
                contact => 0,
            },
          );
        $t->get_ok( $api_path . '/user/doug' )
          ->status_is( 200 )
          ->json_is(
            {
                id => $items{user}[0]{id},
                username => 'doug',
                email => 'doug@example.com',
                password => 'ignore',
                access => 'user',
                age => 35,
            },
          );

        subtest 'fetch one with / in ID' => sub {
            $t->get_ok( $api_path . '/user/joe/' )
              ->status_is( 200 )
              ->json_is(
                {
                    id => $items{user}[1]{id},
                    username => 'joe/',
                    email => 'joel@example.com',
                    password => 'ignore',
                    access => 'user',
                    age => 32,
                },
              );
        };
    };

    subtest 'set one '.$api_path => sub {
        my $new_person = {
            name => 'Foo',
            email => 'doug@example.com',
            id => 1,
            age => 35,
            contact => 1,
            phone => '555 555-0199',
        };
        $t->put_ok( $api_path . '/people/' . $items{people}[0]{id} => json => $new_person )
          ->status_is( 200 )
          ->json_is( $new_person );
        is_deeply $backend->get( people => $items{people}[0]{id} ), $new_person;

        my $new_user = {
            username => 'doug',
            email => 'douglas@example.com',
            password => 'ignore',
            access => 'user',
            age => 35,
        };
        $t->put_ok( $api_path . '/user/doug' => json => $new_user )
          ->status_is( 200 )->or( sub { diag shift->tx->res->body } );
        $t->json_is( { %$new_user, id => $items{user}[0]{id} } );
        is_deeply $backend->get( user => 'doug' ),
            { %$new_user, id => $items{user}[0]{id} };

        subtest 'change id in set' => sub {
            my $new_user = {
                username => 'douglas',
                email => 'douglas@example.com',
                password => 'ignore',
                access => 'user',
                age => 35,
            };
            $t->put_ok( $api_path . '/user/doug' => json => $new_user )
              ->status_is( 200 );
            $t->json_is( { %$new_user, id => $items{user}[0]{id} } );
            is_deeply $backend->get( user => 'douglas' ),
                { %$new_user, id => $items{user}[0]{id} };
            ok !$backend->get( user => 'doug' ), 'old id does not exist';
        };

    };

    subtest 'add one '.$api_path => sub {
        my $new_person = {
            name => 'Flexo',
            email => undef,
            id => 4,
            age => 3,
            contact => 0,
            phone => undef,
        };
        $t->post_ok( $api_path . '/people' => json => $new_person )
          ->status_is( 201 )
          ->json_is( $new_person->{id} )
          ;
        is_deeply $backend->get( people => 4 ), $new_person;

        my $new_user = {
            username => 'flexo',
            email => 'flexo@example.com',
            password => 'ignore',
            access => 'user',
        };
        $t->post_ok( $api_path . '/user' => json => $new_user )
          ->status_is( 201 )
          ->json_is( 'flexo' );
        my $got = $backend->get( user => 'flexo' );
        is $got->{username}, 'flexo', 'created username is correct';
        is $got->{email}, 'flexo@example.com', 'created email is correct';
        is $got->{password}, 'ignore', 'created password is correct';
        is $got->{access}, 'user', 'created access is correct';
        like $got->{id}, qr/^\d+$/, 'id is a number';
    };

    subtest 'delete one '.$api_path => sub {
        $t->delete_ok( $api_path . '/people/4' )
          ->status_is( 204 )
          ;
        ok !$backend->get( people => 4 ), 'person 4 not exists';

        $t->delete_ok( $api_path . '/user/flexo' )
          ->status_is( 204 )
          ;
        ok !$backend->get( user => 'flexo' ), 'flexo not exists';
    };
}

