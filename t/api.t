
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

my $schema = \%Yancy::Backend::Test::SCHEMA;
my $schema_micro = \%Yancy::Backend::Test::SCHEMA_MICRO;
my %data = (
    people => [
        {
            name => 'Doug Bell',
            email => 'doug@example.com',
            age => 35,
            contact => true,
        },
        {
            name => 'Joel Berger',
            email => 'joel@example.com',
            age => 51,
            contact => false,
        },
        {
            name => 'Secret Person',
            contact => false,
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
            avatar => '',
        },
        {
            username => 'joe/',
            email => 'joel@example.com',
            password => 'ignore',
            access => 'user',
            age => 32,
            avatar => '',
        },
    ],
);

my ( $backend_url, $backend, %items ) = init_backend( $schema, %data );
subtest 'declared schema' => \&test_api,
    Test::Mojo->new( 'Yancy', {
        backend => $backend_url,
        schema => $schema,
        editor => { require_user => undef, },
    } ),
    '/yancy/api';

( $backend_url, $backend, %items ) = init_backend( $schema, %data );
subtest 'read_schema schema' => \&test_api,
    Test::Mojo->new( 'Yancy', {
        backend => $backend_url,
        schema => $schema_micro,
        read_schema => 1,
        editor => { require_user => undef, },
    } ),
    '/yancy/api';

my $openapi = decode_json path ( $Bin, 'share', 'openapi-spec.json' )->slurp;
( $backend_url, $backend, %items ) = init_backend( $schema, %data );
subtest 'pass openapi' => \&test_api,
    Test::Mojo->new( 'Yancy', {
        backend => $backend_url,
        openapi => $openapi,
        editor => { require_user => undef, },
    } ),
    '/yancy/api';

$openapi = decode_json path ( $Bin, 'share', 'openapi-spec.json' )->slurp;
$openapi->{paths}{"/people"}{"badmethod"} = {};
subtest 'exception on unknown HTTP method' => sub {
    eval {Test::Mojo->new( 'Yancy', {
        backend => $backend_url,
        openapi => $openapi,
        editor => { require_user => undef, },
    } ) };
    isnt $@, '', 'threw exception ok';
};

$openapi = decode_json path ( $Bin, 'share', 'openapi-spec.json' )->slurp;
$openapi->{paths}{"/nonexistent"} = {};
subtest 'exception on non-inferrable schema' => sub {
    eval {Test::Mojo->new( 'Yancy', {
        backend => $backend_url,
        openapi => $openapi,
        editor => { require_user => undef, },
    } ) };
    isnt $@, '', 'threw exception ok';
};

$openapi = decode_json path ( $Bin, 'share', 'openapi-spec.json' )->slurp;
$openapi->{paths}{"/people"} = {};
subtest 'inferrable schema' => sub {
    eval {Test::Mojo->new( 'Yancy', {
        backend => $backend_url,
        openapi => $openapi,
        editor => { require_user => undef, },
    } ) };
    is $@, '', 'no exception';
};

done_testing;

sub test_api {
    my ( $t, $api_path ) = @_;

    subtest 'fetch generated OpenAPI spec '.$api_path => sub {
        $t->get_ok( $api_path )
          ->status_is( 200 )
          ->or( sub { diag shift->tx->res->body } )
          ->content_type_like( qr{^application/json} )
          ->json_is( '/definitions/people' => {
            type => 'object',
            required => [qw( name )],
            properties => {
                id => {
                    'x-order' => 1,
                    readOnly => true,
                    type => 'integer',
                },
                name => {
                    'x-order' => 2,
                    type => 'string',
                },
                email => {
                    'x-order' => 3,
                    type => [ 'string', 'null' ],
                },
                age => {
                    type => [qw( integer null )],
                    'x-order' => 4,
                },
                contact => {
                    type => [qw( boolean null )],
                    default => 0,
                    'x-order' => 5,
                },
                phone => {
                    type => [qw( string null )],
                    'x-order' => 6,
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
                    readOnly => true,
                    type => 'integer',
                },
                username => {
                    'x-order' => 2,
                    type => 'string',
                },
                email => {
                    'x-order' => 3,
                    type => 'string',
                    title => 'E-mail Address',
                    format => 'email',
                    pattern => '^[^@]+@[^@]+$',
                },
                password => {
                    'x-order' => 4,
                    type => 'string',
                    format => 'password',
                },
                access => {
                    'x-order' => 5,
                    type => 'string',
                    enum => [qw( user moderator admin )],
                    default => 'user',
                },
                age => {
                    'x-order' => 6,
                    type => [ 'integer', 'null' ],
                    description => 'The person\'s age',
                },
                plugin => {
                    'x-order' => 7,
                    type => 'string',
                    default => 'password',
                },
                avatar => {
                    'x-order' => 8,
                    type => 'string',
                    format => 'filepath',
                    default => '',
                },
            },
          } )

          ->json_is( '/definitions/usermini' => {
            type => 'object',
            'x-id-field' => 'username',
            'x-list-columns' => [qw( username email )],
            'x-view' => { schema => 'user' },
            properties => {
                id => {
                    'x-order' => 1,
                    readOnly => true,
                    type => 'integer',
                },
                username => {
                    'x-order' => 2,
                    type => 'string',
                },
                email => {
                    'x-order' => 3,
                    type => 'string',
                    title => 'E-mail Address',
                    format => 'email',
                    pattern => '^[^@]+@[^@]+$',
                },
            },
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
                    phone => undef,
                },
                {
                    id => $items{people}[1]{id},
                    name => 'Joel Berger',
                    email => 'joel@example.com',
                    age => 51,
                    contact => 0,
                    phone => undef,
                },
                {
                    id => $items{people}[2]{id},
                    name => 'Secret Person',
                    email => undef,
                    age => undef,
                    contact => 0,
                    phone => undef,
                },
            ],
            offset => 0,
            total => 3,
          } )
          ->or( sub { diag explain shift->tx->res->json } )
          ;

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
                        phone => undef,
                    },
                ],
                offset => 0,
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
                        phone => undef,
                    },
                    {
                        id => $items{people}[2]{id},
                        name => 'Secret Person',
                        email => undef,
                        age => undef,
                        contact => 0,
                        phone => undef,
                    },
                ],
                offset => 1,
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
                        phone => undef,
                    },
                    {
                        id => $items{people}[1]{id},
                        name => 'Joel Berger',
                        email => 'joel@example.com',
                        age => 51,
                        contact => 0,
                        phone => undef,
                    },
                    {
                        id => $items{people}[2]{id},
                        name => 'Secret Person',
                        email => undef,
                        age => undef,
                        contact => 0,
                        phone => undef,
                    },
                ],
                offset => 0,
                total => 3,
              } );

            $t->get_ok( $api_path . '/people?$order_by=desc:name' )
              ->status_is( 200 )
              ->json_is( {
                items => [
                    {
                        id => $items{people}[2]{id},
                        name => 'Secret Person',
                        email => undef,
                        age => undef,
                        contact => 0,
                        phone => undef,
                    },
                    {
                        id => $items{people}[1]{id},
                        name => 'Joel Berger',
                        email => 'joel@example.com',
                        age => 51,
                        contact => 0,
                        phone => undef,
                    },
                    {
                        id => $items{people}[0]{id},
                        name => 'Doug Bell',
                        email => 'doug@example.com',
                        age => 35,
                        contact => 1,
                        phone => undef,
                    },
                ],
                offset => 0,
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
                        phone => undef,
                    },
                ],
                offset => 0,
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
                        phone => undef,
                    },
                ],
                offset => 0,
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
                        phone => undef,
                    },
                    {
                        id => $items{people}[2]{id},
                        name => 'Secret Person',
                        email => undef,
                        age => undef,
                        contact => 0,
                        phone => undef,
                    },
                ],
                offset => 0,
                total => 2,
              } );

            $t->get_ok( $api_path . '/people?id=' . $items{people}[1]{id} )
              ->status_is( 200 )
              ->json_is( {
                items => [
                    {
                        id => $items{people}[1]{id},
                        name => 'Joel Berger',
                        email => 'joel@example.com',
                        age => 51,
                        contact => 0,
                        phone => undef,
                    }
                ],
                offset => 0,
                total => 1,
              } );

            $t->get_ok( $api_path . '/people?contact=' )
              ->status_is( 200 )
              ->json_is( {
                items => [
                    {
                        id => $items{people}[1]{id},
                        name => 'Joel Berger',
                        email => 'joel@example.com',
                        age => 51,
                        contact => 0,
                        phone => undef,
                    },
                    {
                        id => $items{people}[2]{id},
                        name => 'Secret Person',
                        email => undef,
                        age => undef,
                        contact => 0,
                        phone => undef,
                    },
                ],
                offset => 0,
                total => 2,
              } )
              ->or( sub { diag explain shift->tx->res->json } );

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
                phone => undef,
            },
          );
        $t->get_ok( $api_path . '/people/' . $items{people}[2]{id} )
          ->status_is( 200 )
          ->json_is(
            {
                id => $items{people}[2]{id},
                name => 'Secret Person',
                email => undef,
                age => undef,
                contact => 0,
                phone => undef,
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
                plugin => 'password',
                avatar => '',
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
                    plugin => 'password',
                    avatar => '',
                },
              );
        };
    };

    subtest 'set one '.$api_path => sub {
        my $new_person = {
            name => 'Foo',
            email => 'doug@example.com',
            age => 35,
            contact => 1,
            phone => '555 555-0199',
        };
        $t->put_ok( $api_path . '/people/' . $items{people}[0]{id} => json => $new_person )
          ->status_is( 200 )
          ->json_is( { %$new_person, id => $items{people}[0]{id} } );
        $new_person->{ contact } = 1;
        is_deeply $backend->get( people => $items{people}[0]{id} ), { %$new_person, id => $items{people}[0]{id} };

        my $new_user = {
            username => 'doug',
            email => 'douglas@example.com',
            password => 'ignore',
            access => 'user',
            age => 35,
        };
        $t->put_ok( $api_path . '/user/doug' => json => $new_user )
          ->status_is( 200 )->or( sub { diag shift->tx->res->body } );
        is_deeply $backend->get( user => 'doug' ),
            { %$new_user, id => $items{user}[0]{id}, plugin => 'password', avatar => '' };
        delete $new_user->{password};
        $t->json_is( { %$new_user, id => $items{user}[0]{id}, plugin => 'password', avatar => '' } );

        subtest 'change id in set' => sub {
            my $new_user = {
                username => 'douglas',
                email => 'douglas@example.com',
                password => 'ignore',
                access => 'user',
                age => 35,
                plugin => 'password',
            };
            $t->put_ok( $api_path . '/user/doug' => json => $new_user )
              ->status_is( 200 )
              ;
            is_deeply $backend->get( user => 'douglas' ),
                { %$new_user, id => $items{user}[0]{id}, avatar => '' },
                'new user is correct';
            delete $new_user->{password};
            $t->json_is( '', { %$new_user, id => $items{user}[0]{id}, avatar => '' }, 'json response is correct' );
            ok !$backend->get( user => 'doug' ), 'old id does not exist';
        };

    };

    subtest 'add one '.$api_path => sub {
        my $new_person = {
            name => 'Flexo',
            age => 3,
            contact => 0,
            phone => undef,
        };
        $t->post_ok( $api_path . '/people' => json => $new_person )
          ->status_is( 201 )
          ;
        my $id = $t->tx->res->json( '/id' );
        $t->json_is( { %$new_person, id => $id, email => undef } );
        is_deeply $backend->get( people => $id ), { %$new_person, id => $id, email => undef }
          or diag "got for id '$id', ", explain $backend->get( people => $id );

        my $new_user = {
            username => 'flexo',
            email => 'flexo@example.com',
            password => 'ignore',
            access => 'user',
        };
        $t->post_ok( $api_path . '/user' => json => $new_user )
          ->status_is( 201 )
          ->json_is( '/username', 'flexo', 'created username is correct' )
          ->json_is( '/email', 'flexo@example.com', 'created email is correct' )
          ->json_hasnt( '/password', 'password not returned' )
          ->json_is( '/access', 'user', 'created access is correct' )
          ->json_like( '/id', qr/^\d+$/, 'id is a number' )
          ;
        my $got = $backend->get( user => 'flexo' );
        is $got->{password}, 'ignore', 'created password is correct';
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

