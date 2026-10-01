
=head1 DESCRIPTION

This tests the editor backend, including route generation.

=head1 SEE ALSO

=cut

use Mojo::Base -strict;
use Test::More;
use Test::Mojo;
use FindBin qw( $Bin );
use Mojo::File qw( path );
use Yancy::Model;
use Yancy::User;
use Yancy::Auth::Password;
use Yancy::Backend::Memory;
use lib "".path( $Bin, '..', 'lib' );
use Local::Test qw( init_backend );
use Mojo::JSON qw( true false );
use Mojolicious;

local $ENV{MOJO_HOME} = path( $Bin, '..', 'share' );
my $schema = \%Local::Test::SCHEMA;
my ( $backend_url, $backend, %items ) = init_backend( $schema );
my $model = Yancy::Model->new(backend => $backend);

subtest 'editor handles all routes under given root' => sub {
    my $app = Mojolicious->new;
    $app->plugin( 'Yancy::Plugin::Editor' => { model => $model, allow_anonymous => 1 } );
    my $t = Test::Mojo->new( $app );

    subtest 'editor app routes' => sub {
      $t->get_ok( '/yancy/' )->status_is( 200 )
        ->text_is( title => 'Yancy Editor' )
        ->content_like(qr{Yancy\.base\s*=\s*"/yancy"}, 'contains base URL')
        ;
      $t->get_ok( '/yancy/website/about' )->status_is( 200 )
        ->text_is( title => 'Yancy Editor' )
        ->content_like(qr{Yancy\.base\s*=\s*"/yancy"}, 'contains base URL')
        ;
    };

    subtest 'API routes' => sub {
      $t->get_ok( '/yancy/api' )->status_is( 200 )
        ->json_has( '/people', 'model schema route' );
    };
};

subtest 'non-default backend' => sub {
    my $new_schema = {
        pets => {
            required => [qw( name type )],
            properties => {
                id => {
                    type => 'integer',
                    readOnly => true,
                },
                name => {
                    type => 'string',
                },
                is_good => {
                    type => 'boolean',
                },
                num_legs => {
                    type => 'integer',
                },
                equipment => {
                    type => 'array',
                },
                type => {
                    type => 'string',
                    enum => [qw( cat dog bird rat snake )],
                },
            },
        },
    };

    my $ted = {
        name => 'Theodore',
        type => 'cat',
        is_good => undef,
        num_legs => 4,
        equipment => [],
    };
    my $franklin = {
        name => 'Franklin',
        type => 'dog',
        is_good => 1, # All dogs are good
        num_legs => 4,
        equipment => ['blanket', 'collar'],
    };

    my $new_backend = Yancy::Backend::Memory->new( undef, $new_schema );
    $ted->{id} = $new_backend->create( pets => $ted );
    $franklin->{id} = $new_backend->create( pets => $franklin );
    my $new_model = Yancy::Model->new( backend => $new_backend );

    my $app = Mojolicious->new;
    # The "original" editor
    $app->plugin( 'Yancy::Plugin::Editor' => { model => $model, allow_anonymous => 1 } );
    # The "custom" editor
    $app->plugin( 'Yancy::Plugin::Editor' => {
        model => $new_model,
        route => '/pets/editor',
        allow_anonymous => 1,
    } );

    my $t = Test::Mojo->new( $app );
    $t->get_ok( '/yancy/api' )->status_is( 200 )
      ->json_has( '/people', 'got original schema at original url' )
      ->or( sub { diag explain shift->tx->res->json } )
      ->get_ok( '/pets/editor/api' )->status_is( 200 )
      ->json_has( '/pets', 'got new schema at new url' )
      ->or( sub { diag explain shift->tx->res->json } )
      ->get_ok( '/pets/editor/api/pets/' . $ted->{id} )->status_is( 200 )
      ->json_is( $ted )
      ->get_ok( '/pets/editor/api/pets/' . $franklin->{id} )->status_is( 200 )
      ->json_is( $franklin )
      ->or( sub { diag explain shift->tx->res->json } )
      ;
};

subtest 'editor requires users or allow_anonymous' => sub {
    my $app = Mojolicious->new;
    eval { $app->plugin( 'Yancy::Plugin::Editor' => { model => $model } ) };
    like $@, qr{requires a `users` model}, 'dies without users or allow_anonymous';
};

subtest 'editor requires login' => sub {
    my $user_backend = Yancy::Backend::Memory->new( undef, {
        users => {
            'x-id-field' => 'user_id',
            properties => {
                user_id => { type => 'integer' },
                login => { type => 'string' },
            },
        },
        auth_attributes => {
            'x-id-field' => 'auth_attribute_id',
            properties => {
                auth_attribute_id => { type => 'integer' },
                user_id => { type => 'integer' },
                provider_name => { type => 'string' },
                attribute => { type => 'string' },
                value => { type => 'string' },
            },
        },
        sessions => {
            'x-id-field' => 'session_id',
            properties => {
                session_id => { type => 'integer' },
                user_id => { type => 'integer' },
                created_datetime => { type => 'string' },
                last_activity_datetime => { type => 'string' },
                expired_datetime => { type => [qw( string null )] },
            },
        },
    } );
    my $users = Yancy::User->new( backend => $user_backend );

    my $app = Mojolicious->new;
    my $auth = Yancy::Auth::Password->new( $app,
        model => $users,
        # Fast settings for tests
        passphrase => { module => 'Argon2', memory_cost => '8M', time_cost => 1 },
    );
    $users->schema('users')->create({ user_id => 1, login => 'doug@example.com' });
    $auth->set_password( 'doug@example.com', 'fake_password' );

    $app->plugin( 'Yancy::Plugin::Editor' => { model => $model, users => $users } );
    $app->routes->get( '/logout', sub { my ( $c ) = @_; $users->end_session( $c ); $c->rendered( 204 ) } );

    my $t = Test::Mojo->new( $app );
    $t->get_ok( '/yancy/api' )->status_is( 401 )
      ->json_is( '/errors/0/message', 'Login required' );
    $t->get_ok( '/yancy/api/people' )->status_is( 401 );
    $t->post_ok( '/yancy/api/people', json => { name => 'Anonymous' } )->status_is( 401 );
    $t->get_ok( '/yancy/storage' )->status_is( 401 );
    $t->get_ok( '/yancy/' )->status_is( 302 )
      ->header_is( Location => '/auth/password?return_to=%2Fyancy%2F' );

    $t->post_ok( '/auth/password', form => { login => 'doug@example.com', password => 'wrong' } )
      ->status_is( 400 );
    $t->get_ok( '/yancy/api' )->status_is( 401, 'wrong password does not log in' );

    $t->post_ok( '/auth/password', form => {
        login => 'doug@example.com',
        password => 'fake_password',
        return_to => '/yancy/',
      } )
      ->status_is( 303 )
      ->header_is( Location => '/yancy/' );
    $t->get_ok( '/yancy/api' )->status_is( 200 )
      ->json_has( '/people', 'logged in user can use the editor API' );
    $t->get_ok( '/yancy/' )->status_is( 200 )
      ->text_is( title => 'Yancy Editor' );

    $t->get_ok( '/logout' )->status_is( 204 );
    $t->get_ok( '/yancy/api' )->status_is( 401, 'logged out user can not use the editor API' );
};

done_testing;
