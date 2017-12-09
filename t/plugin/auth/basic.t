
=head1 DESCRIPTION

This tests the basic auth module.

=head1 SEE ALSO

L<Yancy::Plugin::Auth::Basic>, L<Yancy::Backend::Test>

=cut

use v5.24;
use experimental qw( signatures postderef );
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
    $t->get_ok( '/admin' )
      ->status_is( 401, 'User is not authorized for admin app' )
      ->header_like( 'Content-Type' => qr{^text/html} )
      ;
    $t->get_ok( '/admin/api' )
      ->status_is( 401, 'User is not authorized for API spec' )
      ->header_like( 'Content-Type' => qr{^application/json} )
      ;
    $t->get_ok( '/admin/api/users' )
      ->status_is( 401, 'User is not authorized to list users' )
      ->header_like( 'Content-Type' => qr{^application/json} )
      ;
    $t->post_ok( '/admin/api/users', json => { } )
      ->status_is( 401, 'User is not authorized to add a user' )
      ->header_like( 'Content-Type' => qr{^application/json} )
      ;
    $t->get_ok( '/admin/api/users/doug' )
      ->status_is( 401, 'User is not authorized to get a user' )
      ->header_like( 'Content-Type' => qr{^application/json} )
      ;
    $t->put_ok( '/admin/api/users/doug', json => { } )
      ->status_is( 401, 'User is not authorized to set a user' )
      ->header_like( 'Content-Type' => qr{^application/json} )
      ;
    $t->delete_ok( '/admin/api/users/doug' )
      ->status_is( 401, 'User is not authorized to delete a user' )
      ->header_like( 'Content-Type' => qr{^application/json} )
      ;
};

subtest 'user can login' => sub {
    $t->get_ok( '/admin/login' )
      ->status_is( 200 )
      ->element_exists(
          'form[method=POST][action=/admin/login]', 'form exists',
      )
      ->element_exists(
          'form[method=POST][action=/admin/login] input[name=username]',
          'username input exists',
      )
      ->element_exists(
          'form[method=POST][action=/admin/login] input[name=password]',
          'password input exists',
      )
      ;

    $t->post_ok( '/admin/login', form => { username => 'doug', password => '123qwe' } )
      ->status_is( 303 )
      ->header_is( Location => '/admin' );
};

subtest 'logged-in user can admin' => sub {
    $t->get_ok( '/admin' )
      ->status_is( 200, 'User is authorized' );
    $t->get_ok( '/admin/api' )
      ->status_is( 200, 'User is authorized' );
    $t->get_ok( '/admin/api/users' )
      ->status_is( 200, 'User is authorized' );
    $t->get_ok( '/admin/api/users/doug' )
      ->status_is( 200, 'User is authorized' );

    subtest 'api allows saving user passwords' => sub {
        my $doug = {
            $Yancy::Backend::Test::COLLECTIONS{users}{doug}->%*,
            password => 'qwe123',
        };
        $t->put_ok( '/admin/api/users/doug', json => $doug )
          ->status_is( 200 );
        is $Yancy::Backend::Test::COLLECTIONS{users}{doug}{password},
            Digest->new( 'SHA-1' )->add( 'qwe123' )->b64digest,
            'new password is digested correctly'
    };
};

subtest 'user can logout' => sub {
    $t->get_ok( '/admin/logout' )
      ->status_is( 200, 'User is logged out successfully' );
    $t->get_ok( '/admin' )
      ->status_is( 401, 'User is not authorized anymore' );
};

done_testing;
