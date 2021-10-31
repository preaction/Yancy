use Mojo::Base '-strict';

use Test::More;
use Test::Mojo;
use FindBin qw( $Bin );
use Mojo::File qw( path );
use lib "".path( $Bin, 'lib' );
use Local::Test qw( init_backend );
use Digest;
use Data::Dumper;

package MyApp::I18N;
use base 'Locale::Maketext';

package MyApp::I18N::ru;
use Mojo::Base 'MyApp::I18N';
our %Lexicon = ( 'Username' => 'Логин', 'Password' => 'Пароль', 'Login' => 'Вход', 'Create User' => 'Регистрация' );

package main;

my ( $backend_url, $backend, %items ) = init_backend(
    \%Local::Test::SCHEMA,
    user => [
        {
            username => 'pavelsr',
            password => Digest->new( 'SHA-1' )->add( '123qwe' )->b64digest . '$SHA-1',
            email => 'pavel@example.com',
        }
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

subtest 'Yancy && Mojolicious::Plugin::I18N integration' => sub {
  my $c = $t->app->build_controller;
	is 'Hello', $c->helpers->l('Hello'), 'Helper l is available';
};

subtest 'login_form with russian language' => sub {
    $t->app->plugin('Mojolicious::Plugin::I18N', { namespace => 'MyApp::I18N' } );
    my $c = $t->app->build_controller;
    $c->languages('ru');
    ok my $html = $c->yancy->auth->login_form, 'login form is returned';
    my $dom = Mojo::DOM->new( $html );
    is $dom->at( 'label[for=yancy-username]' )->text, 'Логин', 'username ru ok';
    is $dom->at( 'label[for=yancy-password]' )->text, 'Пароль', 'password ru ok';
};

done_testing();
