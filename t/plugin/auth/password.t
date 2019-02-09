
=head1 DESCRIPTION

This tests the auth password module, which allows for password-based
logins.

=head1 SEE ALSO

L<Yancy::Plugin::Auth::Password>, L<Yancy::Plugin::Auth>

=cut

use Mojo::Base '-strict';
use Test::More;
use Test::Mojo;
use FindBin qw( $Bin );
use Mojo::File qw( path );
use lib "".path( $Bin, '..', '..', 'lib' );
use Local::Test qw( init_backend );
use Digest;

my $collections = {
    user => {
        properties => {
            id => { type => 'integer' },
            username => { type => 'string' },
            password => { type => 'string' },
        },
    },
};

my ( $backend_url, $backend, %items ) = init_backend(
    $collections,
    user => [
        {
            username => 'doug',
            email => 'doug@example.com',
            password => Digest->new( 'SHA-1' )->add( '123qwe' )->b64digest . '$SHA-1',
        },
        {
            username => 'joel',
            email => 'joel@example.com',
            password => Digest->new( 'SHA-256' )->add( '456rty' )->b64digest . '$SHA-256',
        },
    ],
);

my $t = Test::Mojo->new( 'Mojolicious' );
$t->app->plugin( 'Yancy', {
    backend => $backend_url,
    collections => $collections,
} );
$t->app->yancy->plugin( 'Auth::Password', {
    collection => 'user',
    username_field => 'username',
    password_field => 'password',
    password_digest => { type => 'SHA-1' },
} );

subtest 'current_user' => sub {
    subtest 'success' => sub {
        my $c = $t->app->build_controller;
        $c->session->{yancy}{auth}{password} = $items{user}[0]{username};
        is_deeply $c->yancy->auth->current_user, $items{user}[0],
            'current_user is correct';
    };

    subtest 'failure' => sub {
        my $c = $t->app->build_controller;
        is $c->yancy->auth->current_user, undef,
            'current_user is undef for invalid session';
    };

};

subtest 'protect routes' => sub {
    my $t = Test::Mojo->new( 'Mojolicious' );
    $t->app->plugin( 'Yancy', {
        backend => $backend_url,
        collections => $collections,
    } );
    $t->app->yancy->plugin( 'Auth::Password', {
        collection => 'user',
        username_field => 'username',
        password_field => 'password',
        password_digest => { type => 'SHA-1' },
    } );

    my $check = $t->app->yancy->auth->check_cb;
    is ref $check, 'CODE', 'check_cb returns a CODE ref';
    my $under = $t->app->routes->under( '', $check );
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
    };
};

subtest 'login and change password digest' => sub {
    $t->post_ok( '/yancy/auth/password', form => { username => 'joel', password => '456rty', } )
      ->status_is( 303 )
      ->header_is( location => '/' );
    my $new_user = $backend->get( user => $items{user}[1]{id} );
    my $digest = Digest->new( 'SHA-1' )->add( '456rty' )->b64digest;
    is $new_user->{password}, join( '$', $digest, 'SHA-1' ),
        'user password is updated to new default config';
};

done_testing;
