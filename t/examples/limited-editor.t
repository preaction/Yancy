
=head1 DESCRIPTION

This tests an example application in the C<eg/limited-editor> directory
to make sure it still works with the new version of Yancy.

=head1 SEE ALSO

C<eg/limited-editor>

=cut

use Mojo::Base '-strict';
use Test::More;

BEGIN {
    plan skip_all => 'Set TEST_YANCY_EXAMPLES to run these tests'
        if !$ENV{TEST_YANCY_EXAMPLES};
}

use Test::Mojo;
use FindBin qw( $Bin );
use Mojo::File qw( path );
use DateTime;

$ENV{MOJO_HOME} = path( $Bin, '..', '..', 'eg', 'limited-editor' );
my $app = path( $ENV{MOJO_HOME}, 'myapp.pl' );
eval { require $app };
if ( $@ && $@ =~ /Perl v5\.\d+\.\d+ required--this is only v\d+\.\d+\.\d+/ ) {
    plan skip_all => 'Could not load t/examples/todo-app.t: ' . $@;
}

my $t = Test::Mojo->new;

subtest 'visitor cannot see any editor' => sub {
    $t->get_ok( '/' )->status_is( 200 )
      ->text_is( 'article h1 a', 'Application Description' )
      ->element_exists( 'a[href=/yancy]', 'link to admin editor exists' )
      ->element_exists( 'a[href=/edit]', 'link to limited editor exists' )
      ->get_ok( '/yancy' )->status_is( 401, 'admin editor denied to visitors' )
      ->get_ok( '/edit' )->status_is( 401, 'limited editor denied to visitors' )
      ;
};

subtest 'normal user cannot see any editor' => sub {
    my %account = (
        username => 'user',
        password => 'user',
    );
    $t->post_ok( '/yancy/auth/password', form => \%account )->status_is( 303 )
      ->get_ok( '/yancy' )->status_is( 401, 'admin editor denied to normal user' )
      ->get_ok( '/edit' )->status_is( 401, 'limited editor denied to normal user' )
      ->get_ok( '/yancy/auth/password/logout' )->status_is( 303 )
      ;
};

subtest 'editor can see the editor app, but not the admin app' => sub {
    my %account = (
        username => 'editor',
        password => 'editor',
    );
    $t->post_ok( '/yancy/auth/password', form => \%account )->status_is( 303 )
      ->get_ok( '/yancy' )->status_is( 401, 'admin editor denied to editor user' )
      ->get_ok( '/edit' )->status_is( 200, 'limited editor allowed to editor user' )
      ->get_ok( '/yancy/auth/password/logout' )->status_is( 303 )
      ;
};

subtest 'admin can see the editor app and the admin app' => sub {
    my %account = (
        username => 'admin',
        password => 'admin',
    );
    $t->post_ok( '/yancy/auth/password', form => \%account )->status_is( 303 )
      ->get_ok( '/yancy' )->status_is( 200, 'admin editor allowed to admin user' )
      ->get_ok( '/edit' )->status_is( 200, 'limited editor allowed to admin user' )
      ->get_ok( '/yancy/auth/password/logout' )->status_is( 303 )
      ;
};

done_testing;
