
=head1 DESCRIPTION

This test ensures that the OpenAPI spec produced by Yancy is correct and the
API routes work as expected.

=head1 SEE ALSO

L<Yancy::Backend::Test>

=cut

use Mojo::Base '-strict';
use Test::More;
use Test::Mojo;
use Mojo::JSON qw( true false );
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
                pattern => '^[^@]+@[^@]+$',
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
            id => 1,
            name => 'Doug Bell',
            email => 'doug@example.com',
        },
        {
            id => 2,
            name => 'Joel Berger',
            email => 'joel@example.com',
        },
    ],
    user => [
        {
            username => 'doug',
            email => 'doug@example.com',
            password => 'ignore',
            access => 'user',
        },
        {
            username => 'joel',
            email => 'joel@example.com',
            password => 'ignore',
            access => 'user',
        },
    ],
);

my $t = Test::Mojo->new( 'Yancy', {
    backend => $backend_url,
    collections => $collections,
    read_schema => 1,
} );

subtest 'fetch generated OpenAPI spec' => sub {
    $t->get_ok( '/yancy/api' )
      ->status_is( 200 )
      ->content_type_like( qr{^application/json} )
      ->json_is( '/definitions/peopleItem' => {
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
                pattern => '^[^@]+@[^@]+$',
            },
        },
      } )

      ->json_is( '/definitions/userItem' => {
        type => 'object',
        'x-id-field' => 'username',
        'x-list-columns' => [qw( username email )],
        required => [qw( username email password )],
        properties => {
            username => {
                'x-order' => 1,
                type => 'string',
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
            id => {
                'x-order' => 1,
                type => 'integer',
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

    subtest 'schema completely from database' => sub {

        my $t = Test::Mojo->new( Yancy => {
            read_schema => 1,
            backend => $backend_url,
            collections => {},
        });
        $t->get_ok( '/yancy/api' )
          ->status_is( 200 )
          ->content_type_like( qr{^application/json} )
          ->json_is( '/definitions/peopleItem' => {
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
                },
                email => {
                    'x-order' => 3,
                    type => [ 'string', 'null' ],
                },
            },
          } )
          ->or( sub { diag explain shift->tx->res->json( '/definitions/peopleItem' ) } )

          ->json_is( '/definitions/userItem' => {
            type => 'object',
            required => [qw( username email password )],
            properties => {
                id => {
                    'x-order' => 1,
                    type => 'integer',
                },
                username => {
                    'x-order' => 2,
                    type => 'string',
                },
                email => {
                    'x-order' => 3,
                    type => 'string',
                },
                password => {
                    'x-order' => 4,
                    type => 'string',
                },
                access => {
                    'x-order' => 5,
                    type => 'string',
                    enum => [qw( user moderator admin )],
                },
            },
          } )
          ->or( sub { diag explain shift->tx->res->json( '/definitions/userItem' ) } )

    };
};

subtest 'fetch list' => sub {
    $t->get_ok( '/yancy/api/people' )
      ->status_is( 200 )
      ->json_is( {
        items => [
            {
                id => 1,
                name => 'Doug Bell',
                email => 'doug@example.com',
            },
            {
                id => 2,
                name => 'Joel Berger',
                email => 'joel@example.com',
            },
        ],
        total => 2,
      } );

    subtest 'limit/offset' => sub {
        $t->get_ok( '/yancy/api/people?limit=1' )
          ->status_is( 200 )
          ->json_is( {
            items => [
                {
                    id => 1,
                    name => 'Doug Bell',
                    email => 'doug@example.com',
                },
            ],
            total => 2,
          } );

        $t->get_ok( '/yancy/api/people?offset=1' )
          ->status_is( 200 )
          ->json_is( {
            items => [
                {
                    id => 2,
                    name => 'Joel Berger',
                    email => 'joel@example.com',
                },
            ],
            total => 2,
          } );

    };

    subtest 'order_by' => sub {

        $t->get_ok( '/yancy/api/people?order_by=asc:name' )
          ->status_is( 200 )
          ->json_is( {
            items => [
                {
                    id => 1,
                    name => 'Doug Bell',
                    email => 'doug@example.com',
                },
                {
                    id => 2,
                    name => 'Joel Berger',
                    email => 'joel@example.com',
                },
            ],
            total => 2,
          } );

        $t->get_ok( '/yancy/api/people?order_by=desc:name' )
          ->status_is( 200 )
          ->json_is( {
            items => [
                {
                    id => 2,
                    name => 'Joel Berger',
                    email => 'joel@example.com',
                },
                {
                    id => 1,
                    name => 'Doug Bell',
                    email => 'doug@example.com',
                },
            ],
            total => 2,
          } );

    };
};

subtest 'fetch one' => sub {
    $t->get_ok( '/yancy/api/people/1' )
      ->status_is( 200 )
      ->json_is(
        {
            id => 1,
            name => 'Doug Bell',
            email => 'doug@example.com',
        },
      );
    $t->get_ok( '/yancy/api/user/doug' )
      ->status_is( 200 )
      ->json_is(
        {
            id => 1,
            username => 'doug',
            email => 'doug@example.com',
            password => 'ignore',
            access => 'user',
        },
      );
};

subtest 'set one' => sub {
    my $new_person = { name => 'Foo', email => 'doug@example.com', id => 1 };
    $t->put_ok( '/yancy/api/people/1' => json => $new_person )
      ->status_is( 200 )
      ->json_is( $new_person );
    is_deeply $backend->get( people => 1 ), $new_person;

    my $new_user = {
        username => 'doug',
        email => 'douglas@example.com',
        password => 'ignore',
        access => 'user',
    };
    $t->put_ok( '/yancy/api/user/doug' => json => $new_user )
      ->status_is( 200 );
    $t->json_is( { %$new_user, id => $items{user}[0]{id} } );
    is_deeply $backend->get( user => 'doug' ), { %$new_user, id => $items{user}[0]{id} };
};

subtest 'add one' => sub {
    my $new_person = { name => 'Flexo', email => 'flexo@example.com', id => 3 };
    $t->post_ok( '/yancy/api/people' => json => $new_person )
      ->status_is( 201 )
      ->json_is( $new_person->{id} )
      ;
    is_deeply $backend->get( people => 3 ), $new_person;

    my $new_user = {
        username => 'flexo',
        email => 'flexo@example.com',
        password => 'ignore',
        access => 'user',
    };
    $t->post_ok( '/yancy/api/user' => json => $new_user )
      ->status_is( 201 )
      ->json_is( 'flexo' );
    my $got = $backend->get( user => 'flexo' );
    is $got->{username}, 'flexo', 'created username is correct';
    is $got->{email}, 'flexo@example.com', 'created email is correct';
    is $got->{password}, 'ignore', 'created password is correct';
    is $got->{access}, 'user', 'created access is correct';
    like $got->{id}, qr/^\d+$/, 'id is a number';
};

subtest 'delete one' => sub {
    $t->delete_ok( '/yancy/api/people/3' )
      ->status_is( 204 )
      ;
    ok !$backend->get( people => 3 ), 'person 3 not exists';

    $t->delete_ok( '/yancy/api/user/flexo' )
      ->status_is( 204 )
      ;
    ok !$backend->get( user => 'flexo' ), 'flexo not exists';
};

done_testing;
