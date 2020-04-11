
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
use Yancy::Plugin::Auth::Github;

my $schema = { %Yancy::Backend::Test::SCHEMA };
$schema->{user}{properties}{email}{default} = 'doug@example.com';
$schema->{user}{properties}{password}{default} = 'DEFAULT_PASSWORD';

my ( $backend_url, $backend, %items ) = init_backend( $schema );

my $t = Test::Mojo->new( 'Mojolicious' );
# A route to verify the Github username
$t->app->routes->get( '/test', sub {
    my ( $c ) = @_;
    my $user = $c->yancy->auth->current_user;
    $c->render(
        text => $user ? $user->{username} : 'ERROR',
    );
} );
$t->app->plugin( 'Yancy', {
    backend => $backend_url,
    schema => $schema,
} );

# Add mock routes for handling auth
my $mock_ua = Mojo::UserAgent->new;
my %mock_data = (
    github_login => 'preaction',
);
$mock_ua->server->app( Mojolicious->new );
my $mock_app = $mock_ua->server->app;
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
            login => $mock_data{ github_login },
        },
    );
} );

# Test plugin defaults
my $plugin = Yancy::Plugin::Auth::Github->new;
isa_ok $plugin->authorize_url, 'Mojo::URL';
isa_ok $plugin->api_url, 'Mojo::URL';
isa_ok $plugin->token_url, 'Mojo::URL';

# Add the plugin
$t->app->yancy->plugin( 'Auth::Github', {
    ua => $mock_ua,
    authorize_url => '/mock/auth',
    token_url => '/mock/token',
    client_id => 'CLIENT_ID',
    client_secret => 'SECRET',
    api_url => '/github',
    schema => 'user',
    username_field => 'username',
    allow_register => 1,
} );

subtest 'login_form' => sub {
    my $c = $t->app->build_controller;
    ok my $html = $c->yancy->auth->login_form, 'login form is returned';
    my $dom = Mojo::DOM->new( $html );
    if ( ok my $button = $dom->at( 'a[href=/yancy/auth/github]' ), 'button to login exists' ) {
        like $button->text, qr{\s*Login with Github\s*}, 'button text is correct';
    }
};

$t->get_ok( '/yancy/auth/github?return_to=/test' )
  ->status_is( 302 )
  ->or( sub { diag shift->tx->res->body } )
  ->header_like( location => qr{^/mock/auth} )
  ->header_like( location => qr{[?&]client_id=CLIENT_ID} )
  ->header_like( location => qr{[?&]state=.+} )
  ;

my $tx = $mock_ua->get( $t->tx->res->headers->location );

$t->get_ok( $tx->res->headers->location )
  ->status_is( 302 )
  ->or( sub { diag shift->tx->res->body } )
  ->header_like( location => qr{/test} )
  ->get_ok( $t->tx->res->headers->location )
  ->content_is( 'preaction' )
  ->or( sub { diag shift->tx->res->body } )
  ;

subtest 'register a new user' => sub {
    local $mock_data{ github_login } = 'example';
    $t->get_ok( '/yancy/auth/github?return_to=/test' )
      ->status_is( 302 )
      ->or( sub { diag shift->tx->res->body } )
      ->header_like( location => qr{^/mock/auth} )
      ->header_like( location => qr{[?&]client_id=CLIENT_ID} )
      ->header_like( location => qr{[?&]state=.+} )
      ;

    my $tx = $mock_ua->get( $t->tx->res->headers->location );

    $t->get_ok( $tx->res->headers->location )
      ->status_is( 302 )
      ->or( sub { diag shift->tx->res->body } )
      ->header_like( location => qr{/test} )
      ->get_ok( $t->tx->res->headers->location )
      ->content_is( 'example' )
      ->or( sub { diag shift->tx->res->body } )
      ;

    my $user = $backend->get( user => 'example' );
    ok $user, 'user is created';
};

subtest 'disallow register' => sub {
    local $mock_data{ github_login } = 'forbidden';

    my $t = Test::Mojo->new( 'Mojolicious' );
    $t->app->plugin( 'Yancy', {
        backend => $backend_url,
        schema => $schema,
    } );

    # Add the plugin
    $t->app->yancy->plugin( 'Auth::Github', {
        ua => $mock_ua,
        authorize_url => '/mock/auth',
        token_url => '/mock/token',
        client_id => 'CLIENT_ID',
        client_secret => 'SECRET',
        api_url => '/github',
        schema => 'user',
        username_field => 'username',
        # Default is to disallow registration
        #allow_register => 0,
    } );

    $t->get_ok( '/yancy/auth/github?return_to=/test' )
      ->status_is( 302 )
      ->or( sub { diag shift->tx->res->body } )
      ->header_like( location => qr{^/mock/auth} )
      ->header_like( location => qr{[?&]client_id=CLIENT_ID} )
      ->header_like( location => qr{[?&]state=.+} )
      ;

    my $tx = $mock_ua->get( $t->tx->res->headers->location );

    $t->get_ok( $tx->res->headers->location )
      ->status_is( 403 )
      ->or( sub { diag shift->tx->res->body } )
      ;

    my $user = $backend->get( user => 'forbidden' );
    ok !$user, 'user is not created';
};

done_testing;
