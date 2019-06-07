
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

done_testing;
