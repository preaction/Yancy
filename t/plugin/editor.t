
=head1 DESCRIPTION

This tests the editor backend, including route generation and menu helpers.

=head1 SEE ALSO

C<t/selenium/editor.t>

=cut

use Mojo::Base -strict;
use Test::More;
use Test::Mojo;
use FindBin qw( $Bin );
use Mojo::File qw( path );
use lib "".path( $Bin, '..', 'lib' );
use Local::Test qw( init_backend );
use Mojolicious;

local $ENV{MOJO_HOME} = path( $Bin, '..', 'share' );
my $schema = \%Yancy::Backend::Test::SCHEMA;
my ( $backend_url, $backend, %items ) = init_backend( $schema );
my %backend_conf = (
    backend => $backend_url,
    read_schema => 1,
);

subtest 'includes' => sub {
    my $app = Mojolicious->new;
    $app->plugin( Yancy => { %backend_conf } );
    $app->yancy->editor->include( 'plugin/editor/custom_element' );
    my $t = Test::Mojo->new( $app );
    $t->get_ok( '/yancy' )
      ->element_exists( '#custom-element-template', 'include is included' );
};

subtest 'menu' => sub {
    my $app = Mojolicious->new;
    $app->plugin( Yancy => { %backend_conf } );
    $app->yancy->editor->menu( Plugins => 'My Menu Item', { component => 'foo' } );
    my $t = Test::Mojo->new( $app );
    $t->get_ok( '/yancy' )
      ->element_exists( '#sidebar-collapse h6:nth-of-type(1) + ul li a', 'menu item is included' )
      ->text_like( '#sidebar-collapse h6:nth-of-type(1) + ul li a', qr{^\s*My Menu Item\s*$} )
      ->element_exists( '#sidebar-collapse h6:nth-of-type(1) + ul li a[@click.prevent^=setComponent' )
      ;
};

subtest 'non-default backend' => sub {
    my $new_schema = {
        pets => {
            required => [qw( name type )],
            properties => {
                id => {
                    type => 'integer',
                    readOnly => 1,
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

    my $new_backend = Yancy::Backend::Test->new( undef, $new_schema );
    $ted->{id} = $new_backend->create( pets => $ted );
    $franklin->{id} = $new_backend->create( pets => $franklin );

    my $app = Mojolicious->new;
    $app->plugin( Yancy => { %backend_conf } );
    $app->yancy->plugin( Editor => {
        backend => $new_backend,
        schema => $new_schema,
        moniker => 'pets',
        require_user => undef,
        route => '/pets/editor',
    } );

    my $t = Test::Mojo->new( $app );
    $t->get_ok( '/yancy/api' )->status_is( 200 )
      ->json_has( '/definitions/people', 'got original schema at original url' )
      ->or( sub { diag explain shift->tx->res->json } )
      ->get_ok( '/pets/editor/api' )->status_is( 200 )
      ->json_has( '/definitions/pets', 'got new schema at new url' )
      ->or( sub { diag explain shift->tx->res->json } )
      ->get_ok( '/pets/editor/api/pets/' . $ted->{id} )->status_is( 200 )
      ->json_is( $ted )
      ->get_ok( '/pets/editor/api/pets/' . $franklin->{id} )->status_is( 200 )
      ->json_is( $franklin )
      ->or( sub { diag explain shift->tx->res->json } )
      ;
};

subtest 'config sanity checks' => sub {

    subtest q{x-list-columns that don't exist} => sub {
        eval {
            Yancy->new( config => {
                backend => $backend_url,
                schema => {
                    blog => {
                        'x-list-columns' => [qw( title slag )],
                    },
                },
                read_schema => 1,
                editor => { require_user => undef },
            } );
        };
        ok $@, 'x-list-columns with bad columns should die';
        like $@, qr{Column "[^']+" in x-list-columns does not exist},
            'error message is useful';

        eval {
            Yancy->new( config => {
                backend => $backend_url,
                schema => {
                    blog => {
                        'x-list-columns' => [
                            {
                                title => 'Title',
                                template => '{title} /{slag}',
                            },
                        ],
                    },
                },
                read_schema => 1,
                editor => { require_user => undef },
            } );
        };
        ok $@, 'x-list-columns with bad columns should die';
        like $@, qr{Column "[^"]+" in x-list-columns template does not exist},
            'error message is useful';
    };

};

done_testing;
