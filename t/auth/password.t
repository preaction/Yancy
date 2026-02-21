
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
  $t->post_ok($auth->url_for($c), form => { login => 'doug@example.com', password => 'fake_password' })->status_is(303);
};

done_testing;
