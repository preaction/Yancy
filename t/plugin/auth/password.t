
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

my ( $backend_url, $backend, %items ) = init_backend(
    \%Yancy::Backend::Test::SCHEMA,
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
    schema => \%Yancy::Backend::Test::SCHEMA,
} );
$t->app->yancy->plugin( 'Auth::Password', {
    schema => 'user',
    username_field => 'username',
    password_field => 'password',
    password_digest => { type => 'SHA-1' },
    allow_register => 1,
} );

subtest 'current_user' => sub {
    subtest 'success' => sub {
        my $c = $t->app->build_controller;
        $c->session->{yancy}{auth}{password} = $items{user}[0]{username};
        my %expect_user = %{ $items{user}[0] };
        delete $expect_user{ password };
        is_deeply $c->yancy->auth->current_user, \%expect_user,
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
        schema => \%Yancy::Backend::Test::SCHEMA,
    } );
    $t->app->yancy->plugin( 'Auth::Password', {
        schema => 'user',
        username_field => 'username',
        password_field => 'password',
        password_digest => { type => 'SHA-1' },
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
              ->content_like( qr{You are not authorized} )
              ->text_is( 'a[href=/yancy/auth/password]', 'Please log in', 'login link exists' )
              ->or( sub { diag shift->tx->res->dom->find( 'a' )->each } )
              ;
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

subtest 'errors' => sub {
    subtest 'user not found' => sub {
        $t->post_ok( '/yancy/auth/password', form => { username => 'NOT FOUND', password => '123', return_to => '/' } )
          ->status_is( 400 )
          ->header_isnt( Location => '/yancy' )
          ->element_exists(
              'form[method=POST][action=/yancy/auth/password] input[name=username][value=NOT FOUND]',
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
    };
};

subtest 'logout' => sub {
    $t->get_ok( '/yancy/auth/password/logout' )
      ->status_is( 302 )
      ->or( sub { diag shift->tx->res->body } )
      ->header_is( location => '/yancy/auth/password' )
      ->get_ok( '/yancy/auth/password' )
      ->content_like( qr{You have been logged out} )
      ;
};

subtest 'register' => sub {
    $t->get_ok( '/yancy/auth/password/register' )
      ->status_is( 200 )
      ->or( sub { diag shift->tx->res->body } )
      ->element_exists( 'input[name=username]', 'username field exists' )
      ->element_exists( 'input[name=password]', 'password field exists' )
      ->element_exists( 'input[name=password-verify]', 'password-verify field exists' )
      ->element_exists( 'input[name=email]', 'email field exists' )
      ->or( sub { diag shift->tx->res->dom->at( 'form' ) } )
      ->element_exists( 'form button', 'submit button exists' )
      ->post_ok( '/yancy/auth/password/register',
          form => {
              username => 'foo',
              password => 'bar',
              'password-verify' => 'baz',
              email => 'doug@example.com',
          }
      )
      ->status_is( 400 )
      ->content_like( qr{Passwords do not match} )
      ->post_ok( '/yancy/auth/password/register',
          form => {
              username => 'doug',
              password => 'haha',
              'password-verify' => 'haha',
              email => 'doug@example.com',
          }
      )
      ->status_is( 400 )
      ->content_like( qr{User already exists} )
      ->post_ok( '/yancy/auth/password/register',
          form => {
              username => 'mickey',
              password => 'metacpan',
              'password-verify' => 'metacpan',
          }
      )
      ->status_is( 400 )
      ->or( sub { diag shift->tx->res->body } )
      ->content_like( qr{Invalid data} )
      ->post_ok( '/yancy/auth/password/register',
          form => {
              username => 'mickey',
              password => 'metacpan',
              'password-verify' => 'metacpan',
              email => 'mickey@example.com',
          }
      )
      ->status_is( 302 )
      ->or( sub { diag shift->tx->res->body } )
      ->header_is( location => '/yancy/auth/password' )
      ->get_ok( '/yancy/auth/password' )
      ->content_like( qr{User created\. Please log in} )
      ->post_ok( '/yancy/auth/password',
          form => {
              username => 'mickey',
              password => 'metacpan',
              return_to => '/',
          }
      )
      ->status_is( 303 )
      ->header_is( location => '/' );
      ;
};

subtest 'login and change password digest' => sub {
    $t->post_ok( '/yancy/auth/password', form => { username => 'joel', password => '456rty', } )
      ->status_is( 303 )
      ->header_is( location => '/' );
    my $new_user = $backend->get( user => $items{user}[1]{username} );
    my $digest = Digest->new( 'SHA-1' )->add( '456rty' )->b64digest;
    is $new_user->{password}, join( '$', $digest, 'SHA-1' ),
        'user password is updated to new default config';
};

done_testing;
