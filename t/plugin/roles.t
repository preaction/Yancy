
=head1 DESCRIPTION

This tests the capabilities of the L<Yancy::Plugin::File> plugin.

=head1 SEE ALSO

L<Yancy>

=cut

use Mojo::Base -strict;
use Test::More;
use Test::Mojo;
use FindBin qw( $Bin );
use Mojo::File qw( path tempdir );
use lib "".path( $Bin, '..', 'lib' );
use Local::Test qw( init_backend load_fixtures );
use Digest;

my $schema = \%Local::Test::SCHEMA;
my %fixtures = load_fixtures( 'roles' );
$schema->{ $_ } = $fixtures{ $_ } for keys %fixtures;

my ( $backend_url, $backend, %items ) = init_backend(
    $schema,
    user => [
        {
            username => 'doug',
            email => 'doug@example.com',
            password => Digest->new( 'SHA-1' )->add( '123qwe' )->b64digest . '$SHA-1',
            plugin => 'password',
        },
        {
            username => 'admin',
            email => 'doug@example.com',
            password => Digest->new( 'SHA-1' )->add( '123qwe' )->b64digest . '$SHA-1',
            plugin => 'password',
        },
    ],
);

my $t = Test::Mojo->new( 'Mojolicious' );
$t->app->plugin( 'Yancy', {
    backend => $backend_url,
    schema => \%Local::Test::SCHEMA,
} );
$t->app->yancy->plugin( 'Auth::Password', {
    schema => 'user',
    username_field => 'username',
    password_field => 'password',
    password_digest => { type => 'SHA-1' },
    allow_register => 1,
} );
$t->app->yancy->plugin( 'Roles', {
    schema => 'roles',
    userid_field => 'username',
} );

$t->app->yancy->model('roles')->create( { username => 'doug', role => 'admin' } );

my $require_admin = $t->app->yancy->auth->require_role( 'admin' );
$t->app->routes->under( '/admin', $require_admin )->get( '' )->to( cb => sub { shift->rendered(204) } );

subtest 'has_role' => sub {
    my $c = $t->app->build_controller;
    ok !$c->yancy->auth->has_role( 'admin' ), 'no user has no role';
    $c->session->{yancy}{auth}{password} = $items{user}[0]{username};
    ok $c->yancy->auth->has_role( 'admin' ), 'current user has role';
    $c->session->{yancy}{auth}{password} = $items{user}[1]{username};
    ok !$c->yancy->auth->has_role( 'admin' ), 'current user does not have role';
};

subtest 'require_role' => sub {
    $t->get_ok( '/admin' )->status_is( 401 )
      ->content_like( qr{You are not authorized} )
      ->element_exists( 'form[action=/yancy/auth/password]', 'login form exists' )
      ;
    $t->post_ok( '/yancy/auth/password', form => { username => 'doug', password => '123qwe', } )
      ->status_is( 303 )
      ;
    $t->get_ok( '/admin' )->status_is( 204 );
};

done_testing;
