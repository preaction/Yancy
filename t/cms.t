
=head1 DESCRIPTION

This test ensures that the standalone Yancy CMS works as expected,
including the default welcome page and the template handlers.

This test uses the config file located in C<t/lib/share/config.pl>.

=head1 SEE ALSO

L<Yancy::Backend::Test>

=cut

use v5.24;
use experimental qw( signatures postderef );
use Test::More;
use Test::Mojo;
use Mojo::JSON qw( true false );
use FindBin qw( $Bin );
use Mojo::File qw( path );
use lib "".path( $Bin, 'lib' );

use Yancy::Backend::Test;
%Yancy::Backend::Test::COLLECTIONS = (
    people => {
        1 => {
            id => 1,
            name => 'Doug Bell',
            email => 'doug@example.com',
        },
        2 => {
            id => 2,
            name => 'Joel Berger',
            email => 'joel@example.com',
        },
    },
    users => {
        doug => {
            username => 'doug',
            email => 'doug@example.com',
        },
        joel => {
            username => 'joel',
            email => 'joel@example.com',
        },
    },
);

$ENV{MOJO_CONFIG} = path( $Bin, 'share/config.pl' );
$ENV{MOJO_HOME} = path( $Bin, 'share' );

my $t = Test::Mojo->new( 'Yancy' );

subtest 'default page' => sub {
    my $orig_mode = $t->app->mode;

    $t->app->mode( 'development' );
    $t->get_ok( '/' )
      ->status_is( 404 )
      ->text_is( h1 => 'Welcome to Yancy' )
      ;

    $t->app->mode( 'testing' );
    $t->get_ok( '/' )
      ->status_is( 404 )
      ->text_isnt( h1 => 'Welcome to Yancy' )
      ;

    $t->app->mode( $orig_mode );

    $t->get_ok( '/yancy' )
      ->status_is( 200 )
      ;
};

subtest 'template handler' => sub {
    #diag "Home: " . $t->app->home;
    $t->get_ok( '/people' )
      ->status_is( 200 )
      ->text_is( h1 => 'People' )
      ->text_is( 'li:first-child' => 'Doug Bell' )
      ->text_is( 'li:nth-child(2)' => 'Joel Berger' )
      ;
    $t->get_ok( '/people/1' )
      ->status_is( 200 )
      ->text_is( h1 => 'Doug Bell' )
      ;
    $t->get_ok( '/people/1/doug/bell/is/great' )
      ->status_is( 404 )
      ;

    subtest 'default index' => sub {
        local $ENV{MOJO_HOME} = "".path( $Bin, 'share/withindex' );

        Test::Mojo->new( 'Yancy' )->get_ok( '/' )
          ->status_is( 200 )
          ->text_is( h1 => 'Index' )
          ;
    };
};

subtest 'plugins' => sub {
    $t->get_ok( '/perldoc' )
      ->status_is( 200, 'PODRenderer returns 200 OK' )
      ->get_ok( '/test' )
      ->status_is( 200 )
      ->json_is( [ { args => "one" } ] )
      ;
};

done_testing;
