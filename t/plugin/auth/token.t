
=head1 DESCRIPTION

This tests the auth token module, which allows for simple, zero-login
API usage.

=head1 SEE ALSO

L<Yancy::Plugin::Auth::Token>, L<Yancy::Plugin::Auth>

=cut

use Mojo::Base '-strict';
use Test::More;
use Test::Mojo;
use FindBin qw( $Bin );
use Mojo::File qw( path );
use lib "".path( $Bin, '..', '..', 'lib' );
use Local::Test qw( init_backend );
use Digest;

my $schema = \%Yancy::Backend::Test::SCHEMA;
my ( $backend_url, $backend, %items ) = init_backend(
    $schema,
    user => [
        {
            username => 'doug',
            email => 'doug@example.com',
            password => Digest->new( 'SHA-1' )->add( '123qwe' )->b64digest,
        },
        {
            username => 'joel',
            email => 'joel@example.com',
            password => Digest->new( 'SHA-1' )->add( '456rty' )->b64digest,
        },
    ],
);

my $t = Test::Mojo->new( 'Mojolicious' );
$t->app->plugin( 'Yancy', {
    backend => $backend_url,
    schema => $schema,
} );
$t->app->yancy->plugin( 'Auth::Token', {
    schema => 'user',
    username_field => 'username',
    token_field => 'password',
    token_digest => { type => 'SHA-1' },
} );

subtest 'current_user' => sub {
    subtest 'success' => sub {
        my $c = $t->app->build_controller;
        $c->tx->req->headers->authorization(
            sprintf 'Token %s', $items{user}[0]{password},
        );
        is_deeply
            {
                %{ $c->yancy->auth->current_user },
                password => $items{user}[0]{password},
            },
            $items{user}[0],
            'current_user is correct';
    };

    subtest 'failure' => sub {
        my $c = $t->app->build_controller;
        $c->tx->req->headers->authorization(
            sprintf 'Token %s', 'INCORRECT TOKEN',
        );
        is $c->yancy->auth->current_user, undef,
            'current_user is undef for invalid token';
    };

    subtest 'no token' => sub {
        my $c = $t->app->build_controller;
        is $c->yancy->auth->current_user, undef,
            'current_user is undef for missing token';
    };
};

subtest 'add_token' => sub {
    $t->app->secrets( [ 'a_super_secret_secret' ] );
    my $c = $t->app->build_controller;
    my $token = $c->yancy->auth->add_token( "foobar", email => 'doug@example.com' );
    ok $token, 'token is returned';
    my @users = @{ $backend->list( user => { username => "foobar" } )->{items} };
    is scalar @users, 1, 'one user with username "foobar"';
    is $users[0]{password}, $token, 'token is saved correctly';
};

subtest 'protect routes' => sub {
    my $t = Test::Mojo->new( 'Mojolicious' );
    $t->app->plugin( 'Yancy', {
        backend => $backend_url,
        schema => $schema,
    } );
    $t->app->yancy->plugin( 'Auth::Token', {
        schema => 'user',
        username_field => 'username',
        token_field => 'password',
        token_digest => { type => 'SHA-1' },
    } );

    my $cb = $t->app->yancy->auth->require_user;
    is ref $cb, 'CODE', 'require_user returns a CODE ref';
    my $under = $t->app->routes->under( '', $cb );
    $under->get( '/' )->to( cb => sub {
        my ( $c ) = @_;
        $c->app->log->info( "Foo" );
        $c->render( data => 'Ok' );
    } );

    subtest 'unauthorized' => sub {
        subtest 'html' => sub {
            $t->get_ok( '/' )->status_is( 401 )
              ->content_like( qr{You are not authorized} );
        };
        subtest 'json' => sub {
            $t->get_ok( '/', { Accept => 'application/json' } )
              ->status_is( 401 )
              ->json_like( '/errors/0/message', qr{You are not authorized} )
              ->or( sub { diag shift->tx->res->body } );
        };
    };

    subtest 'authorized' => sub {
        my $token = $items{user}[0]{password};
        $t->get_ok( '/', { Authorization => sprintf 'Token %s', $token } )
            ->status_is( 200 )
            ->content_is( 'Ok' );
    };
};

done_testing;
