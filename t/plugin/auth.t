
=head1 DESCRIPTION

This tests the auth module, which combines multiple auth plugins.

=head1 SEE ALSO

L<Yancy::Plugin::Auth>

=cut

use Mojo::Base '-strict';
use Test::More;
use Test::Mojo;
use FindBin qw( $Bin );
use Mojo::File qw( path );
use lib "".path( $Bin, '..', 'lib' );
use Local::Test qw( init_backend );
use Digest;

my ( $backend_url, $backend, %items ) = init_backend(
    \%Yancy::Backend::Test::SCHEMA,
    user => [
        {
            username => 'doug',
            email => 'doug@example.com',
            password => Digest->new( 'SHA-1' )->add( '123qwe' )->b64digest . '$SHA-1',
            plugin => 'password',
            access => 'admin',
        },
        {
            username => 'joel',
            email => 'joel@example.com',
            password => Digest->new( 'SHA-1' )->add( '456rty' )->b64digest . '$SHA-1',
            plugin => 'token',
        },
    ],
);

my $t = Test::Mojo->new( 'Mojolicious' );
$t->app->plugin( 'Yancy', {
    backend => $backend_url,
    schema => \%Yancy::Backend::Test::SCHEMA,
} );
$t->app->yancy->plugin( 'Auth', {
    schema => 'user',
    username_field => 'username',
    password_field => 'password',
    plugin_field => 'plugin',
    plugins => [
        [
            Password => {
                password_digest => {
                    type => 'SHA-1',
                },
            },
        ],
        'Token',
    ],
} );

subtest 'current_user' => sub {
    subtest 'password-only' => sub {
        my $c = $t->app->build_controller;
        $c->session->{yancy}{auth}{password} = $items{user}[0]{username};
        my %expect_user = %{ $items{user}[0] };
        delete $expect_user{ password };
        is_deeply $c->yancy->auth->current_user, \%expect_user,
            'current_user is correct';
    };

    subtest 'token-only' => sub {
        my $c = $t->app->build_controller;
        $c->tx->req->headers->authorization(
            sprintf 'Token %s', $items{user}[1]{password},
        );
        my %expect_user = %{ $items{user}[1] };
        delete $expect_user{ password };
        is_deeply $c->yancy->auth->current_user, \%expect_user,
            'current_user is correct';
    };

    subtest 'password and token (password comes first)' => sub {
        my $c = $t->app->build_controller;
        $c->session->{yancy}{auth}{password} = $items{user}[0]{username};
        $c->tx->req->headers->authorization(
            sprintf 'Token %s', $items{user}[1]{password},
        );
        my %expect_user = %{ $items{user}[0] };
        delete $expect_user{ password };
        is_deeply $c->yancy->auth->current_user, \%expect_user,
            'current_user is correct';
    };

};

subtest 'login' => sub {
    subtest 'all forms shown on the same page' => sub {
        $t->get_ok( '/yancy/auth' => { Referer => '/' } )
          ->status_is( 200 )
          ->element_exists(
              'form[method=POST][action=/yancy/auth/password]', 'form exists',
          )
          ->element_exists(
              'form[method=POST][action=/yancy/auth/password] input[name=username]',
              'username input exists',
          )
          ->element_exists(
              'form[method=POST][action=/yancy/auth/password] input[name=password]',
              'password input exists',
          )
          ->element_exists(
              'form[method=POST][action=/yancy/auth/password] input[name=return_to][value=/]',
              'return to field exists with correct value',
          )
          ;
    };

    subtest 'password login works' => sub {
        $t->post_ok( '/yancy/auth/password', form => { username => 'doug', password => '123qwe', } )
          ->status_is( 303 )
          ->header_is( location => '/' );
    };
};

subtest 'protect routes' => sub {
    my $t = Test::Mojo->new( 'Mojolicious' );
    $t->app->plugin( 'Yancy', {
        backend => $backend_url,
        schema => \%Yancy::Backend::Test::SCHEMA,
    } );
    $t->app->yancy->plugin( 'Auth', {
        schema => 'user',
        username_field => 'username',
        password_field => 'password',
        password_digest => { type => 'SHA-1' },
        plugins => [ 'Password' ],
    } );

    my $cb = $t->app->yancy->auth->require_user;
    is ref $cb, 'CODE', 'require_user returns a CODE ref';
    my $under = $t->app->routes->under( '', $cb );
    $under->get( '/' )->to( cb => sub {
        my ( $c ) = @_;
        $c->app->log->info( "Foo" );
        $c->render( data => 'Ok' );
    } );

    $cb = $t->app->yancy->auth->require_user( { access => 'admin' } );
    is ref $cb, 'CODE', 'require_user returns a CODE ref';
    $under = $t->app->routes->under( '/allow/admin', $cb );
    $under->get( '/' )->to( cb => sub {
        my ( $c ) = @_;
        $c->app->log->info( "Admin" );
        $c->render( data => 'Ok' );
    } );

    $cb = $t->app->yancy->auth->require_user( { username => [ 'doug', 'joel' ] } );
    is ref $cb, 'CODE', 'require_user returns a CODE ref';
    $under = $t->app->routes->under( '/allow/user', $cb );
    $under->get( '/' )->to( cb => sub {
        my ( $c ) = @_;
        $c->app->log->info( "Doug or Joel" );
        $c->render( data => 'Ok' );
    } );

    $cb = $t->app->yancy->auth->require_user( { access => 'moderator' } );
    is ref $cb, 'CODE', 'require_user returns a CODE ref';
    $under = $t->app->routes->under( '/deny/moderator', $cb );
    $under->get( '/' )->to( cb => sub {
        my ( $c ) = @_;
        $c->app->log->info( "Moderator" );
        $c->render( data => 'Ok' );
    } );

    $cb = $t->app->yancy->auth->require_user( { username => [ 'brittany', 'joel' ] } );
    is ref $cb, 'CODE', 'require_user returns a CODE ref';
    $under = $t->app->routes->under( '/deny/user', $cb );
    $under->get( '/' )->to( cb => sub {
        my ( $c ) = @_;
        $c->app->log->info( "Brittany or Joel" );
        $c->render( data => 'Ok' );
    } );

    subtest 'unauthorized' => sub {
        subtest 'html' => sub {
            $t->get_ok( '/' )->status_is( 401 )
              ->content_like( qr{You are not authorized} )
              ->text_is( 'a[href=/yancy/auth]', 'Please log in', 'login link exists' )
              ->or( sub { diag shift->tx->res->dom->find( 'a' )->each } )
              ;
        };
        subtest 'json' => sub {
            $t->get_ok( '/', { Accept => 'application/json' } )
              ->status_is( 401 )
              ->json_like( '/errors/0/message', qr{You are not authorized} )
              ->or( sub { diag shift->tx->res->dom->at( '#errors,#routes' ) } )
              ;
        };
    };

    subtest 'user can login' => sub {
        $t->get_ok( '/yancy/auth/password' => { Referer => '/' } )
          ->status_is( 200 )
          ->element_exists(
              'form[method=POST][action=/yancy/auth/password]', 'form exists',
          )
          ->element_exists(
              'form[method=POST][action=/yancy/auth/password] input[name=username]',
              'username input exists',
          )
          ->element_exists(
              'form[method=POST][action=/yancy/auth/password] input[name=password]',
              'password input exists',
          )
          ->element_exists(
              'form[method=POST][action=/yancy/auth/password] input[name=return_to][value=/]',
              'return to field exists with correct value',
          )
          ->element_exists_not(
              '.login-error',
              'login error alert box not shown',
          )
          ;

        $t->post_ok( '/yancy/auth/password', form => { username => 'doug', password => '123', return_to => '/' } )
          ->status_is( 400 )
          ->header_isnt( Location => '/yancy' )
          ->element_exists(
              'form[method=POST][action=/yancy/auth/password] input[name=username][value=doug]',
              'username input exists with value pre-filled',
          )
          ->element_exists(
              'form[method=POST][action=/yancy/auth/password] input[name=password]:not([value])',
              'password input exists without value',
          )
          ->element_exists(
              'form[method=POST][action=/yancy/auth/password] input[name=return_to][value=/]',
              'return to field exists with correct value',
          )
          ->text_like(
              '.login-error', qr{\s*Login failed: User or password incorrect!\s*},
              'login error alert box shown',
          )
          ;

        $t->post_ok( '/yancy/auth/password', form => { username => 'doug', password => '123qwe', } )
          ->status_is( 303 )
          ->header_is( location => '/' );
    };

    subtest 'authorized' => sub {
        $t->get_ok( '/' )->status_is( 200 )->content_is( 'Ok' );
        $t->get_ok( '/allow/admin' )->status_is( 200 )->content_is( 'Ok' );
        $t->get_ok( '/allow/user' )->status_is( 200 )->content_is( 'Ok' );
        $t->get_ok( '/deny/moderator' )->status_is( 401 )->text_is( h1 => 'Unauthorized' );
        $t->get_ok( '/deny/user' )->status_is( 401 )->text_is( h1 => 'Unauthorized' );
    };
};

subtest 'one user, multiple auth' => sub {
    my $t = Test::Mojo->new( 'Mojolicious' );
    $t->app->plugin( 'Yancy', {
        backend => $backend_url,
        schema => \%Yancy::Backend::Test::SCHEMA,
    } );
    $t->app->yancy->plugin( 'Auth', {
        schema => 'user',
        plugin_field => 'plugin',
        plugins => [
            [
                Password => {
                    moniker => 'user',
                    username_field => 'username',
                    password_field => 'password',
                    password_digest => {
                        type => 'SHA-1',
                    },
                },
            ],
            [
                Password => {
                    moniker => 'email',
                    username_field => 'email',
                    password_field => 'password',
                    password_digest => {
                        type => 'SHA-1',
                    },
                },
            ],
        ],
    } );

    subtest 'username login works' => sub {
        $t->post_ok( '/yancy/auth/user', form => {
            username => 'doug',
            password => '123qwe',
          } )
          ->status_is( 303 )
          ->or( sub { diag shift->tx->res->dom->at( '#errors,#routes' ) } )
          ->header_is( location => '/' );
    };
    subtest 'email login works' => sub {
        $t->post_ok( '/yancy/auth/email', form => {
            username => 'doug@example.com',
            password => '123qwe',
          } )
          ->status_is( 303 )
          ->or( sub { diag shift->tx->res->dom->at( '#errors,#routes' ) } )
          ->header_is( location => '/' );
    };
};

done_testing;
