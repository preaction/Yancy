use Mojo::Base '-strict';

use Test::More;
use Test::Mojo;
use FindBin qw( $Bin );
use Mojo::File qw( path );
use lib "".path( $Bin, 'lib' );
use Local::Test qw( init_backend );
use Yancy::User;
use Yancy::Auth::Password;

package MyApp::I18N;
use base 'Locale::Maketext';

package MyApp::I18N::ru;
use Mojo::Base 'MyApp::I18N';
our %Lexicon = ( 'Username' => 'Логин', 'Password' => 'Пароль', 'Login' => 'Вход', 'Create User' => 'Регистрация' );

package main;

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
$t->app->plugin( 'Yancy', {
    backend => $backend_url,
    schema => \%Local::Test::SCHEMA,
} );
my $auth = Yancy::Auth::Password->new( $t->app,
  model => Yancy::User->new( backend => $backend ),
  digest => { type => 'SHA-1' },
);

subtest 'Yancy && Mojolicious::Plugin::I18N integration' => sub {
  my $c = $t->app->build_controller;
	is 'Hello', $c->helpers->l('Hello'), 'Helper l is available';
};

subtest 'login form with russian language' => sub {
    $t->app->plugin('Mojolicious::Plugin::I18N', { namespace => 'MyApp::I18N' } );
    my $c = $t->app->build_controller;
    $c->languages('ru');
    ok my $html = $auth->form_for( $c ), 'login form is returned';
    my $dom = Mojo::DOM->new( $html );
    is $dom->at( 'label[for=yancy-login]' )->text, 'Вход', 'login ru ok';
    is $dom->at( 'label[for=yancy-password]' )->text, 'Пароль', 'password ru ok';
    is $dom->at( 'button' )->text, 'Вход', 'button ru ok';
};

done_testing();
