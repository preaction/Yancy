
=head1 DESCRIPTION

This tests the OAuth2 auth module.

=head1 SEE ALSO

L<Yancy::Plugin::Auth::OAuth2>

=cut

use Mojo::Base '-strict';
use Test::More;
use Test::Mojo;
use FindBin qw( $Bin );
use Mojo::File qw( path );
use lib "".path( $Bin, '..', '..', 'lib' );
use Local::Test qw( init_backend );

my ( $backend_url, $backend, %items ) = init_backend(
    \%Yancy::Backend::Test::SCHEMA,
);

my $t = Test::Mojo->new( 'Mojolicious' );
$t->app->plugin( 'Yancy', {
    backend => $backend_url,
    schema => \%Yancy::Backend::Test::SCHEMA,
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
    $c->redirect_to( '/yancy/auth/oauth2?code=' . $mock_data{ code } );
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
$mock_app->routes->get( '/test', sub {
    my ( $c ) = @_;
    $c->render( text => $c->session->{ yancy }{ oauth2 }{ access_token } );
} );

# Add the plugin
$t->app->yancy->plugin( 'Auth::OAuth2', {
    ua => $mock_ua,
    authorize_url => '/mock/auth',
    token_url => '/mock/token',
    client_id => 'CLIENT_ID',
    client_secret => 'SECRET',
    login_label => 'Login with OAuth2',
} );

subtest 'login_form' => sub {
    my $c = $t->app->build_controller;
    ok my $html = $c->yancy->auth->login_form, 'login form is returned';
    my $dom = Mojo::DOM->new( $html );
    if ( ok my $button = $dom->at( 'a[href=/yancy/auth/oauth2]' ), 'button to login exists' ) {
        like $button->text, qr{\s*Login with OAuth2\s*}, 'button text is correct';
    }
};

$t->get_ok( '/yancy/auth/oauth2?return_to=/test' )
  ->status_is( 302 )
  ->or( sub { diag shift->tx->res->body } )
  ->header_is( location => '/mock/auth?client_id=CLIENT_ID' )
  ->get_ok( $t->tx->res->headers->location )
  ->status_is( 302 )
  ->or( sub { diag shift->tx->res->body } )
  ->header_like( location => qr{/yancy/auth/oauth2\?code=(.+)} )
  ->get_ok( $t->tx->res->headers->location )
  ->status_is( 302 )
  ->or( sub { diag shift->tx->res->body } )
  ->header_like( location => qr{/test} )
  ->get_ok( $t->tx->res->headers->location )
  ->content_is( $mock_data{ access_token } )
  ->or( sub { diag shift->tx->res->body } )
  ;

subtest 'logout' => sub {
    $t->get_ok( '/yancy/auth/oauth2/logout', { Referer => '/yancy' } )
      ->status_is( 303 )
      ->header_is( location => '/yancy' )
      ->get_ok( '/yancy/auth/oauth2/logout' )
      ->status_is( 303 )
      ->header_is( location => '/' )
      ->get_ok( '/yancy/auth/oauth2/logout?redirect_to=/', { Referer => '/yancy' } )
      ->status_is( 303 )
      ->header_is( location => '/' )
      ;
};

done_testing;
