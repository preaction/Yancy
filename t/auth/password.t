
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
  # Fast settings for tests
  passphrase => { module => 'Argon2', memory_cost => '8M', time_cost => 1 },
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

subtest 'password hashing' => sub {
  my $users = $model->schema('users');
  $users->create({ user_id => 2, login => 'alice@example.com' });
  $users->create({ user_id => 3, login => 'bob@example.com' });
  $auth->set_password('alice@example.com', 'same_password');
  $auth->set_password('bob@example.com', 'same_password');
  my $alice_hash = $auth->attribute(2, 'password');
  my $bob_hash = $auth->attribute(3, 'password');
  like $alice_hash, qr{^\$argon2id\$}, 'password is hashed with Argon2id';
  isnt $alice_hash, $bob_hash, 'same password gets a different salt';
  unlike $alice_hash, qr{same_password}, 'password is not stored';
};

subtest 'old Digest passwords are upgraded' => sub {
  my $c = $t->app->build_controller;
  $model->schema('users')->create({ user_id => 4, login => 'legacy@example.com' });
  my $legacy_hash = Digest->new('SHA-1')->add('legacy_password')->b64digest . '$SHA-1';
  $auth->attribute(4, password => $legacy_hash);

  $t->post_ok($auth->url_for($c), form => { login => 'legacy@example.com', password => 'wrong' })->status_is(400);
  is $auth->attribute(4, 'password'), $legacy_hash, 'failed login does not change hash';

  $t->post_ok($auth->url_for($c), form => { login => 'legacy@example.com', password => 'legacy_password' })->status_is(303);
  like $auth->attribute(4, 'password'), qr{^\$argon2id\$}, 'hash upgraded to Argon2id';

  $t->get_ok('/auth/logout')->status_is(303);
  $t->post_ok($auth->url_for($c), form => { login => 'legacy@example.com', password => 'legacy_password' })
    ->status_is(303, 'can log in with upgraded hash');
};

subtest 'old Digest passwords with non-ASCII characters' => sub {
  my $c = $t->app->build_controller;
  $model->schema('users')->create({ user_id => 5, login => 'soren@example.com' });
  # Old Digest hashes were made from Latin-1 bytes
  my $password = "bl\x{e5}b\x{e6}rgr\x{f8}d";
  my $legacy_hash = Digest->new('SHA-1')->add($password)->b64digest . '$SHA-1';
  $auth->attribute(5, password => $legacy_hash);

  $t->post_ok($auth->url_for($c), form => { login => 'soren@example.com', password => $password })
    ->status_is(303, 'can log in with non-ASCII legacy password');
  like $auth->attribute(5, 'password'), qr{^\$argon2id\$}, 'hash upgraded to Argon2id';
  $t->get_ok('/auth/logout')->status_is(303);
  $t->post_ok($auth->url_for($c), form => { login => 'soren@example.com', password => $password })
    ->status_is(303, 'can log in with upgraded non-ASCII password');
};

subtest 'Unicode passwords' => sub {
  my $c = $t->app->build_controller;
  my $users = $model->schema('users');

  # Old Digest hashes died on characters above U+00FF, so these could not be set
  $users->create({ user_id => 6, login => 'emoji@example.com' });
  my $password = "pass\x{1F600}\x{1F510}";
  $auth->set_password('emoji@example.com', $password);
  like $auth->attribute(6, 'password'), qr{^\$argon2id\$}, 'emoji password is hashed';
  $t->post_ok($auth->url_for($c), form => { login => 'emoji@example.com', password => $password })
    ->status_is(303, 'can log in with emoji password');
  $t->get_ok('/auth/logout')->status_is(303);
  $t->post_ok($auth->url_for($c), form => { login => 'emoji@example.com', password => "pass\x{1F600}" })
    ->status_is(400, 'missing emoji does not log in');

  # Passwords are normalized, so "å" as U+00E5 matches "a" + U+030A
  $users->create({ user_id => 7, login => 'nfc@example.com' });
  $auth->set_password('nfc@example.com', "bl\x{e5}b\x{e6}r");
  $t->post_ok($auth->url_for($c), form => { login => 'nfc@example.com', password => "bla\x{30a}b\x{e6}r" })
    ->status_is(303, 'decomposed characters match composed characters');
  $t->get_ok('/auth/logout')->status_is(303);

  # Old Digest hashes made from UTF-8 bytes, like SQL SHA1() on a UTF-8 string
  $users->create({ user_id => 8, login => 'utf8@example.com' });
  my $legacy_hash = Digest->new('SHA-1')->add("pass\xf0\x9f\x98\x80")->b64digest . '$SHA-1';
  $auth->attribute(8, password => $legacy_hash);
  $t->post_ok($auth->url_for($c), form => { login => 'utf8@example.com', password => "pass\x{1F600}" })
    ->status_is(303, 'can log in with old UTF-8 hash of emoji password');
  like $auth->attribute(8, 'password'), qr{^\$argon2id\$}, 'old UTF-8 hash upgraded to Argon2id';
};

done_testing;
