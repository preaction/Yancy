
=head1 DESCRIPTION

This tests the auth module, which combines multiple auth plugins.

=head1 SEE ALSO

L<Yancy::Plugin::Auth>

=cut

use Mojo::Base '-strict';
use Test::More;
use Test::Mojo;
use FindBin qw( $Bin );
use Mojo::File qw( path );
use lib "".path( $Bin, '..', 'lib' );
use Local::Test qw( init_backend );
use Digest;

my ( $backend_url, $backend, %items ) = init_backend(
    \%Yancy::Backend::Test::SCHEMA,
    user => [
        {
            username => 'doug',
            email => 'doug@example.com',
            password => Digest->new( 'SHA-1' )->add( '123qwe' )->b64digest . '$SHA-1',
            plugin => 'password',
        },
        {
            username => 'joel',
            email => 'joel@example.com',
            password => Digest->new( 'SHA-1' )->add( '456rty' )->b64digest . '$SHA-1',
            plugin => 'token',
        },
    ],
);

my $t = Test::Mojo->new( 'Mojolicious' );
$t->app->plugin( 'Yancy', {
    backend => $backend_url,
    collections => \%Yancy::Backend::Test::SCHEMA,
} );
$t->app->yancy->plugin( 'Auth', {
    collection => 'user',
    username_field => 'username',
    password_field => 'password',
    plugin_field => 'plugin',
    plugins => [
        {
            Password => {
                password_digest => {
                    type => 'SHA-1',
                },
            },
        },
        'Token',
    ],
} );

subtest 'current_user' => sub {
    subtest 'password-only' => sub {
        my $c = $t->app->build_controller;
        $c->session->{yancy}{auth}{password} = $items{user}[0]{username};
        my %expect_user = %{ $items{user}[0] };
        delete $expect_user{ password };
        is_deeply $c->yancy->auth->current_user, \%expect_user,
            'current_user is correct';
    };

    subtest 'token-only' => sub {
        my $c = $t->app->build_controller;
        $c->tx->req->headers->authorization(
            sprintf 'Token %s', $items{user}[1]{password},
        );
        my %expect_user = %{ $items{user}[1] };
        delete $expect_user{ password };
        is_deeply $c->yancy->auth->current_user, \%expect_user,
            'current_user is correct';
    };

    subtest 'password and token (password comes first)' => sub {
        my $c = $t->app->build_controller;
        $c->session->{yancy}{auth}{password} = $items{user}[0]{username};
        $c->tx->req->headers->authorization(
            sprintf 'Token %s', $items{user}[1]{password},
        );
        my %expect_user = %{ $items{user}[0] };
        delete $expect_user{ password };
        is_deeply $c->yancy->auth->current_user, \%expect_user,
            'current_user is correct';
    };

};


done_testing;
