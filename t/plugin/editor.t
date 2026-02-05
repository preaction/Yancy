
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
use lib "".path( $Bin, '..', 'lib' );
use Local::Test qw( init_backend );
use Mojo::JSON qw( true false );
use Mojolicious;

local $ENV{MOJO_HOME} = path( $Bin, '..', 'share' );
my $schema = \%Local::Test::SCHEMA;
my ( $backend_url, $backend, %items ) = init_backend( $schema );
my $model = Yancy::Model->new(backend => $backend);

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
    $app->plugin( 'Yancy::Plugin::Editor' => { model => $model } );
    # The "custom" editor
    $app->plugin( 'Yancy::Plugin::Editor' => {
        model => $new_model,
        route => '/pets/editor',
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

done_testing;
