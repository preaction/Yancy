
=head1 DESCRIPTION

This tests the basic auth module.

=head1 SEE ALSO

L<Yancy::Plugin::Auth::Basic>, L<Yancy::Backend::Test>

=cut

use Mojo::Base '-strict';
use Test::More;
use Test::Mojo;
use Mojo::JSON qw( true false );
use FindBin qw( $Bin );
use Mojo::File qw( path );
use lib "".path( $Bin, '..', '..', 'lib' );
use Digest;

use Yancy::Backend::Test;
%Yancy::Backend::Test::COLLECTIONS = (
    users => {
        doug => {
            username => 'doug',
            email => 'doug@example.com',
            password => Digest->new( 'SHA-1' )->add( '123qwe' )->b64digest,
        },
        joel => {
            username => 'joel',
            email => 'joel@example.com',
            password => Digest->new( 'SHA-1' )->add( '456rty' )->b64digest,
        },
    },
);

$ENV{MOJO_CONFIG} = path( $Bin, '..', '..', 'share', 'config.pl' );
$ENV{MOJO_HOME} = path( $Bin, '..', '..', 'share' );

my $t = Test::Mojo->new( 'Yancy' );
$t->app->plugin( 'Auth::Basic', {
    collection => 'users',
    username_field => 'username',
    password_field => 'password', # default
    password_digest => {
        type => 'SHA-1',
    },
});

subtest 'unauthenticated user cannot admin' => sub {
    $t->get_ok( '/yancy' )
      ->status_is( 401, 'User is not authorized for admin app' )
      ->header_like( 'Content-Type' => qr{^text/html} )
      ;
    $t->get_ok( '/yancy/api' )
      ->status_is( 401, 'User is not authorized for API spec' )
      ->header_like( 'Content-Type' => qr{^application/json} )
      ;
    $t->get_ok( '/yancy/api/users' )
      ->status_is( 401, 'User is not authorized to list users' )
      ->header_like( 'Content-Type' => qr{^application/json} )
      ;
    $t->post_ok( '/yancy/api/users', json => { } )
      ->status_is( 401, 'User is not authorized to add a user' )
      ->header_like( 'Content-Type' => qr{^application/json} )
      ;
    $t->get_ok( '/yancy/api/users/doug' )
      ->status_is( 401, 'User is not authorized to get a user' )
      ->header_like( 'Content-Type' => qr{^application/json} )
      ;
    $t->put_ok( '/yancy/api/users/doug', json => { } )
      ->status_is( 401, 'User is not authorized to set a user' )
      ->header_like( 'Content-Type' => qr{^application/json} )
      ;
    $t->delete_ok( '/yancy/api/users/doug' )
      ->status_is( 401, 'User is not authorized to delete a user' )
      ->header_like( 'Content-Type' => qr{^application/json} )
      ;
};

subtest 'user can login' => sub {
    $t->get_ok( '/yancy/login' => { Referer => '/' } )
      ->status_is( 200 )
      ->element_exists(
          'form[method=POST][action=/yancy/login]', 'form exists',
      )
      ->element_exists(
          'form[method=POST][action=/yancy/login] input[name=username]',
          'username input exists',
      )
      ->element_exists(
          'form[method=POST][action=/yancy/login] input[name=password]',
          'password input exists',
      )
      ->element_exists(
          'form[method=POST][action=/yancy/login] input[name=return_to][value=/]',
          'return to field exists with correct value',
      )
      ;

    $t->post_ok( '/yancy/login', form => { username => 'doug', password => '123', } )
      ->status_is( 400 )
      ->header_isnt( Location => '/yancy' );

    $t->post_ok( '/yancy/login', form => { username => 'doug', password => '123qwe', } )
      ->status_is( 303 )
      ->header_is( Location => '/yancy' );
};

subtest 'logged-in user can admin' => sub {
    $t->get_ok( '/yancy' )
      ->status_is( 200, 'User is authorized' );
    $t->get_ok( '/yancy/api' )
      ->status_is( 200, 'User is authorized' );
    $t->get_ok( '/yancy/api/users' )
      ->status_is( 200, 'User is authorized' );
    $t->get_ok( '/yancy/api/users/doug' )
      ->status_is( 200, 'User is authorized' );

    subtest 'api allows saving user passwords' => sub {
        my $doug = {
            %{ $Yancy::Backend::Test::COLLECTIONS{users}{doug} },
            password => 'qwe123',
        };
        $t->put_ok( '/yancy/api/users/doug', json => $doug )
          ->status_is( 200 );
        is $Yancy::Backend::Test::COLLECTIONS{users}{doug}{password},
            Digest->new( 'SHA-1' )->add( 'qwe123' )->b64digest,
            'new password is digested correctly'
    };
};

subtest 'user can logout' => sub {
    $t->get_ok( '/yancy/logout' )
      ->status_is( 200, 'User is logged out successfully' );
    $t->get_ok( '/yancy' )
      ->status_is( 401, 'User is not authorized anymore' );
};

subtest 'standalone plugin' => sub {
    my $t = Test::Mojo->new( Mojolicious->new );

    my $base_route = $t->app->routes->any( '' );
    $base_route->get( '/' )->to( cb => sub { shift->render( data => 'Hello' ) } );

    $t->app->plugin( 'Config' );
    $t->app->plugin( 'Yancy', {
        %{ $t->app->config },
        route => $base_route->any( '/yancy' ),
    } );

    unshift @{$t->app->plugins->namespaces}, 'Yancy::Plugin';

    $t->app->plugin( 'Auth::Basic', {
        collection => 'users',
        username_field => 'username',
        password_field => 'password', # default
        password_digest => {
            type => 'SHA-1',
        },
        route => $base_route,
    });

    my $auth_route = $t->app->yancy->auth->route;
    $auth_route->get( '/authed', sub { shift->render( data => 'Authed' ) } );

    $t->get_ok( '/' )
      ->status_is( 401, 'User is not authorized for root' )
      ->header_like( 'Content-Type' => qr{^text/html} )
      ;
    $t->get_ok( '/authed' )
      ->status_is( 401, 'User is not authorized for route added via helper' )
      ->header_like( 'Content-Type' => qr{^text/html} )
      ;
    $t->get_ok( '/yancy' )
      ->status_is( 401, 'User is not authorized for admin app' )
      ->header_like( 'Content-Type' => qr{^text/html} )
      ;
    $t->get_ok( '/yancy/api' )
      ->status_is( 401, 'User is not authorized for API spec' )
      ->header_like( 'Content-Type' => qr{^application/json} )
      ;
    $t->post_ok( '/login', form => {
            username => 'doug',
            password => 'qwe123',
            return_to => '/',
        } )
      ->status_is( 303 )
      ->header_is( Location => '/' );

    $t->get_ok( '/' )
      ->status_is( 200, 'User is authorized for root' )
      ->content_is( 'Hello' )
      ->header_like( 'Content-Type' => qr{^text/html} )
      ;
    $t->get_ok( '/authed' )
      ->status_is( 200, 'User is authorized for route added via helper' )
      ->content_is( 'Authed' )
      ->header_like( 'Content-Type' => qr{^text/html} )
      ;
    $t->get_ok( '/yancy' )
      ->status_is( 200, 'User is authorized for admin app' )
      ->header_like( 'Content-Type' => qr{^text/html} )
      ;
    $t->get_ok( '/yancy/api' )
      ->status_is( 200, 'User is authorized for API spec' )
      ->header_like( 'Content-Type' => qr{^application/json} )
      ;
};

done_testing;
