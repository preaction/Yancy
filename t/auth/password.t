
=head1 DESCRIPTION

This tests the auth password module, which allows for password-based
logins.

=head1 SEE ALSO

L<Yancy::Auth::Password>, L<Yancy::Auth>

=cut

use Mojo::Base '-strict';
use Test::More;
use Test::Mojo;
use FindBin qw( $Bin );
use Mojo::File qw( path );
use lib "".path( $Bin, '..', 'lib' );
use Local::Test qw( init_backend );
use Digest;
use Yancy::User;
use Yancy::Auth::Password;

my ( $backend_url, $backend, %items ) = init_backend( \%Local::Test::SCHEMA );

$backend->{schema}{users} = {
  'x-id-field' => 'user_id',
  properties => {
    user_id => { type => 'integer' },
    login => { type => 'string' },
  },
};
$backend->{schema}{auth_attributes} = {
  'x-id-field' => 'auth_attribute_id',
  properties => {
    auth_attribute_id => { type => 'integer' },
    user_id => { type => 'integer' },
    provider_name => { type => 'string' },
    attribute => { type => 'string' },
    value => { type => 'string' },
  },
};
$backend->{schema}{sessions} = {
  'x-id-field' => 'session_id',
  properties => {
    session_id => { type => 'integer' },
    user_id => { type => 'integer' },
    created_datetime => { type => 'string' },
    last_activity_datetime => { type => 'string' },
    expired_datetime => { type => [qw( string null )] },
  },
};

my $t = Test::Mojo->new( 'Mojolicious' );
my $model = Yancy::User->new( backend => $backend );
my $auth = Yancy::Auth::Password->new( $t->app,
  model => $model,
  digest => { type => 'SHA-1' },
);

subtest 'form_for' => sub {
    my $c = $t->app->build_controller;
    ok my $html = $auth->form_for($c), 'login form is returned';
    my $dom = Mojo::DOM->new( $html );
    ok $dom->at( 'input[name=login]' ), 'login field exists';
    ok $dom->at( 'input[name=password]' ), 'password field exists';
};

subtest 'url_for' => sub {
    my $c = $t->app->build_controller;
    ok my $url = $auth->url_for($c), 'url returned';
    is $url, '/auth/password';
};

subtest 'login' => sub {
  my $c = $t->app->build_controller;
  $model->schema('users')->create({
    user_id => 1,
    login => 'doug@example.com',
  });
  $auth->set_password('doug@example.com', 'fake_password');
  $t->app->routes->get('/whoami', sub {
    my ( $c ) = @_;
    my $user = $model->current_user($c);
    $c->render(json => { login => $user ? $user->{login} : undef });
  });
  $t->get_ok('/whoami')->json_is('/login', undef, 'not logged in yet');
  $t->post_ok($auth->url_for($c), form => { login => 'doug@example.com', password => 'wrong' })->status_is(400);
  $t->post_ok($auth->url_for($c), form => { login => 'nobody@example.com', password => 'fake_password' })->status_is(400);
  $t->get_ok('/whoami')->json_is('/login', undef, 'failed logins do not start a session');
  $t->post_ok($auth->url_for($c), form => { login => 'doug@example.com', password => 'fake_password' })->status_is(303);
  $t->get_ok('/whoami')->json_is('/login', 'doug@example.com', 'login starts a session');
};

subtest 'return_to must be a local path' => sub {
  my $c = $t->app->build_controller;
  my @unsafe = ( 'https://evil.example', '//evil.example', '/\\evil.example', "/\t/evil.example", 'evil.example' );

  for my $to ( @unsafe ) {
    $t->post_ok($auth->url_for($c), form => { login => 'doug@example.com', password => 'fake_password', return_to => $to })
      ->status_is(303)->header_is(Location => '/', "login does not redirect to $to");
  }
  $t->post_ok($auth->url_for($c), form => { login => 'doug@example.com', password => 'fake_password', return_to => '/yancy/?page=2' })
    ->status_is(303)->header_is(Location => '/yancy/?page=2', 'login redirects to local path');

  for my $to ( @unsafe ) {
    $t->get_ok($auth->url_for($c)->query(return_to => $to))->status_is(200)
      ->element_exists('input[name=return_to][value=/auth/password]', "login form does not use $to");
  }
};

subtest 'logout' => sub {
  my $c = $t->app->build_controller;
  $t->post_ok($auth->url_for($c), form => { login => 'doug@example.com', password => 'fake_password' })->status_is(303);
  $t->get_ok('/whoami')->json_is('/login', 'doug@example.com', 'logged in');
  $t->get_ok('/auth/logout?return_to=/bye')->status_is(303)->header_is(Location => '/bye');
  $t->get_ok('/whoami')->json_is('/login', undef, 'logout ends the session');

  for my $to ( 'https://evil.example', '//evil.example', '/\\evil.example' ) {
    $t->get_ok(Mojo::URL->new('/auth/logout')->query(return_to => $to))
      ->status_is(303)->header_is(Location => '/', "logout does not redirect to $to");
  }
};

done_testing;
