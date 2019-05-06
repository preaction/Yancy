
=head1 DESCRIPTION

This tests the Github auth module.

=head1 SEE ALSO

L<Yancy::Plugin::Auth::Github>

=cut

use Mojo::Base '-strict';
use Test::More;
use Test::Mojo;
use FindBin qw( $Bin );
use Mojo::File qw( path );
use lib "".path( $Bin, '..', '..', 'lib' );
use Local::Test qw( init_backend );

my $collections = { %Yancy::Backend::Test::SCHEMA };
$collections->{user}{properties}{email}{default} = 'doug@example.com';
$collections->{user}{properties}{password}{default} = 'DEFAULT_PASSWORD';

my ( $backend_url, $backend, %items ) = init_backend( $collections );

my $t = Test::Mojo->new( 'Mojolicious' );
$t->app->plugin( 'Yancy', {
    backend => $backend_url,
    collections => $collections,
} );

# Add mock routes for handling auth
my $mock_ua = Mojo::UserAgent->new;
my %mock_data;
$mock_ua->server->app( $t->app );
my $mock_app = $t->app;
$mock_app->routes->get( '/mock/auth', sub {
    my ( $c ) = @_;
    $mock_data{ client_id } = $c->param( 'client_id' );
    $mock_data{ code } = int rand 1000;
    $mock_data{ state } = $c->param( 'state' );
    $c->redirect_to(
        '/yancy/auth/github?code=' . $mock_data{ code }
        . '&state=' . $mock_data{ state }
    );
} );
$mock_app->routes->post( '/mock/token', sub {
    my ( $c ) = @_;
    my $got_code = $c->param( 'code' );
    my $got_client_id = $mock_data{ client_id } = $c->param( 'client_id' );
    my $got_client_secret = $mock_data{ client_secret } = $c->param( 'client_secret' );
    is $got_code, $mock_data{ code }, 'got correct code';
    $mock_data{ access_token } = int rand 1000;
    $c->res->headers->content_type( 'application/x-www-form-urlencoded' );
    $c->render(
        text => 'access_token=' . $mock_data{ access_token },
    );
} );
$mock_app->routes->get( '/github/user', sub {
    my ( $c ) = @_;
    $mock_data{ authorization } = $c->req->headers->authorization;
    $c->render(
        json => {
            login => 'preaction',
        },
    );
} );
$mock_app->routes->get( '/test', sub {
    my ( $c ) = @_;
    my $user = $c->yancy->auth->current_user;
    $c->render(
        text => $user ? $user->{username} : 'ERROR',
    );
} );

# Add the plugin
$t->app->yancy->plugin( 'Auth::Github', {
    ua => $mock_ua,
    authorize_url => '/mock/auth',
    token_url => '/mock/token',
    client_id => 'CLIENT_ID',
    client_secret => 'SECRET',
    api_url => '/github',
    collection => 'user',
    username_field => 'username',
} );

$t->get_ok( '/yancy/auth/github?return_to=/test' )
  ->status_is( 302 )
  ->or( sub { diag shift->tx->res->body } )
  ->header_like( location => qr{^/mock/auth} )
  ->header_like( location => qr{[?&]client_id=CLIENT_ID} )
  ->header_like( location => qr{[?&]state=.+} )
  ->get_ok( $t->tx->res->headers->location )
  ->status_is( 302 )
  ->or( sub { diag shift->tx->res->body } )
  ->header_like( location => qr{/yancy/auth/github\?code=(.+)} )
  ->get_ok( $t->tx->res->headers->location )
  ->status_is( 302 )
  ->or( sub { diag shift->tx->res->body } )
  ->header_like( location => qr{/test} )
  ->get_ok( $t->tx->res->headers->location )
  ->content_is( 'preaction' )
  ->or( sub { diag shift->tx->res->body } )
  ;

done_testing;
