
=head1 DESCRIPTION

This tests an example application in the C<eg/doc-site> directory to
make sure it still works with the new version of Yancy.

These tests require Mojo::SQLite, Mojolicious::Plugin::PODViewer, and
Mojolicious::Command::export.

=head1 SEE ALSO

C<eg/doc-site>

=cut

use Mojo::Base '-strict';
use Test::More;

BEGIN {
    plan skip_all => 'Set TEST_YANCY_EXAMPLES to run these tests'
        if !$ENV{TEST_YANCY_EXAMPLES};
}

use Test::Mojo;
use FindBin qw( $Bin );
use Mojo::File qw( path tempdir );
use Mojolicious::Command::export;

$ENV{MOJO_HOME} = path( $Bin, '..', '..', 'eg', 'doc-site' );
my $app = path( $ENV{MOJO_HOME}, 'myapp.pl' );
require $app;

my $t = Test::Mojo->new;

$t->get_ok( '/yancy/api' )
    ->status_is( 200 )
    ->json_has( '/definitions' )
    ;

subtest 'test pages' => sub {
    $t->get_ok( '/' )->status_is( 200 )
      ->text_is( 'h1', 'Yancy' );
};

subtest 'test pod viewer' => sub {
    $t->get_ok( '/perldoc' )->status_is( 200 )
      ->element_exists( 'h1#SEE-ALSO', 'doc section SEE ALSO exists' )
      ->element_exists( 'h2#Mojolicious-Plugin', 'doc section Mojolicious Plugin exists' );
};

subtest 'test export' => sub {
    my $tmp = tempdir;
    my $cmd = Mojolicious::Command::export->new(
        quiet => 1,
        app => $t->app,
    );
    $cmd->run( '--to', "$tmp" );
    ok -e $tmp->child( 'perldoc', 'Mojolicious', 'Plugin', 'Yancy', 'index.html' ),
        'Mojolicious::Plugin::Yancy is exported';
    ok -e $tmp->child( 'perldoc', 'Yancy', 'Backend', 'index.html' ),
        'Yancy::Backend is exported';
    ok !-e $tmp->child( 'perldoc', 'Mojolicious', 'index.html' ),
        'Mojolicious is not exported';
};

done_testing;
