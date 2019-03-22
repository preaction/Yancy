
=head1 DESCRIPTION

This test ensures that the standalone Yancy CMS works as expected,
including the default welcome page and the template handlers.

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

my $collections = \%Yancy::Backend::Test::SCHEMA;
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
    $t->get_ok( '/test' )
      ->status_is( 200 )
      ->json_is( [ { args => "one" } ] )
      ;
};

subtest 'with openapi spec file' => sub {
    my $t = Test::Mojo->new( 'Yancy', {
        backend => $backend_url,
        openapi => 'openapi-spec.json',
    } );
    $t->get_ok( '/yancy/api' )
      ->status_is( 200 )
      ;
};

subtest 'default home directory is cwd' => sub {
    delete $ENV{MOJO_HOME};
    my $cwd = path;
    chdir path( $Bin, 'share' );

    my $t = Test::Mojo->new( 'Yancy', {
        backend => $backend_url,
        collections => $collections,
        read_schema => 1,
    } );
    #diag "Home: " . $t->app->home;
    $t->get_ok( '/people' )
      ->status_is( 200 );
    $t->get_ok( '/people/1' )
      ->status_is( 200 );
    $t->get_ok( '/people/1/doug/bell/is/great' )
      ->status_is( 404 );

    chdir $cwd;
};

done_testing;
