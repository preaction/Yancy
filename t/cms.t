
=head1 DESCRIPTION

This test ensures that the standalone Yancy CMS works as expected,
including the default welcome page and the template handlers.

This test uses the config file located in C<t/lib/share/config.pl>.

=head1 SEE ALSO

L<Yancy::Backend::Test>

=cut

use Mojo::Base '-strict';
use Test::More;
use Test::Mojo;
use Mojo::JSON qw( true false );
use FindBin qw( $Bin );
use Mojo::File qw( path );
use lib "".path( $Bin, 'lib' );
use Local::Test qw( init_backend );

my $collections = {
    people => {
        required => [qw( name )],
        properties => {
            id => {
                'x-order' => 1,
            },
            name => {
                'x-order' => 2,
                description => 'The real name of the person',
            },
            email => {
                'x-order' => 3,
                pattern => '^[^@]+@[^@]+$',
            },
        },
    },
    user => {
        'x-id-field' => 'username',
        'x-list-columns' => [qw( username email )],
        required => [qw( username email password )],
        properties => {
            username => {
                type => 'string',
                'x-order' => 1,
            },
            email => {
                type => 'string',
                'x-order' => 2,
            },
            password => {
                type => 'string',
                format => 'password',
                'x-order' => 3,
            },
            access => {
                type => 'string',
                enum => [qw( user moderator admin )],
                'x-order' => 4,
            },
        },
    },
};
my ( $backend_url, $backend, %items ) = init_backend(
    $collections,
    people => [
        {
            id => 1,
            name => 'Doug Bell',
            email => 'doug@example.com',
        },
        {
            id => 2,
            name => 'Joel Berger',
            email => 'joel@example.com',
        },
    ],
    user => [
        {
            username => 'doug',
            email => 'doug@example.com',
            password => 'ignore',
        },
        {
            username => 'joel',
            email => 'joel@example.com',
            password => 'ignore',
        },
    ],
);

$ENV{MOJO_HOME} = path( $Bin, 'share' );
my $t = Test::Mojo->new( 'Yancy', {
    plugins => [
        [ 'PODRenderer' ],
        [ 'Test', { args => "one" } ],
    ],
    backend => $backend_url,
    collections => $collections,
    read_schema => 1,
} );

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

        my $t = Test::Mojo->new( 'Yancy', {
            backend => $backend_url,
            collections => $collections,
            read_schema => 1,
        } );
        $t->get_ok( '/' )
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
