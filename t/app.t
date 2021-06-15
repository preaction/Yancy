
=head1 DESCRIPTION

This tests the base Yancy application class.

=cut

use Mojo::Base '-strict';
use Test::More;
use Test::Mojo;
use FindBin qw( $Bin );
use Mojo::File qw( path );
use lib "".path( $Bin, 'lib' );
use Local::Test qw( init_backend );

my $schema = \%Yancy::Backend::Test::SCHEMA;
$schema->{yancy_logins} = {
    'x-id-field' => 'login_name',
    properties => {
        login_id => { type => 'integer' },
        login_name => { type => 'string' },
        password => { type => 'string', format => 'password' },
    },
};

my ( $backend_url, $backend, %items ) = init_backend( $schema );

my $t = Test::Mojo->new( 'Yancy', {
    backend => $backend_url,
} );

subtest 'default auth plugin' => sub {
    ok $t->app->yancy->can( 'auth' ), 'an auth plugin is loaded' or return;
    # Create a login
    $t->app->yancy->create( yancy_logins => { login_name => 'admin', password => 'admin' } );
    # Test that editor is protected
    $t->get_ok( '/yancy' )->status_is( 401, 'editor is protected' );
    $t->post_ok( '/yancy/auth/password', form => { username => 'admin', password => 'admin' } )
      ->status_is( 303, 'login successful' );
    $t->get_ok( '/yancy' )->status_is( 200, 'can login and see editor' );
};

done_testing;
