
=head1 DESCRIPTION

This test ensures that the Storage controller works

=head1 SEE ALSO

L<Yancy::Controller::Storage>

=cut

use Mojo::Base '-strict';
use Test::More;
use Test::Mojo;
use Mojo::JSON qw( true false );
use FindBin qw( $Bin );
use Mojo::File qw( path tempdir );
use Scalar::Util qw( blessed );
use lib "".path( $Bin, '..', 'lib' );
use Yancy::Storage;
use Yancy::Controller::Storage;

local $ENV{MOJO_HOME} = path( $Bin, '..', 'share' );

sub build_app {
  my $t = Test::Mojo->new( 'Mojolicious' );
  my $r = $t->app->routes;
  push @{ $r->namespaces}, 'Yancy::Controller';

  my $tempdir = tempdir;
  my $storage = Yancy::Storage->new( root => $tempdir );
  $r->get('/storage/*id', { storage => $storage })->to('storage#get');
  $r->get('/storage', { storage => $storage })->to('storage#list');
  $r->put('/storage/*id', { storage => $storage })->to('storage#put');
  $r->post('/storage/*prefix', { storage => $storage, prefix => '' })->to('storage#post');
  $r->delete('/storage/*id', { storage => $storage })->to('storage#delete');

  return $t, $tempdir;
}

subtest 'put' => sub {
  my ($t, $tempdir) = build_app();
  $t->put_ok('/storage/foobar', 'FOOBAR')->status_is(201);
  is $tempdir->child('foobar')->slurp, 'FOOBAR';
};

subtest 'post' => sub {
  my ($t, $tempdir) = build_app();
  $t->post_ok('/storage/', form => { foo => { content => 'FOOBAR', filename => 'foobar' }})->status_is(201);
  is $tempdir->child('foobar')->slurp, 'FOOBAR';
};

subtest 'get' => sub {
  my ($t, $tempdir) = build_app();
  $tempdir->child('foobar')->spurt('FOOBAR');
  $t->get_ok('/storage/foobar')->status_is(200)->content_is('FOOBAR');
};

subtest 'delete' => sub {
  my ($t, $tempdir) = build_app();
  $tempdir->child('foobar')->spurt('FOOBAR');
  $t->delete_ok('/storage/foobar')->status_is(201);
  ok !-e $tempdir->child('foobar');
};

subtest 'list' => sub {
  my ($t, $tempdir) = build_app();
  $tempdir->child('foobar')->spurt('FOOBAR');
  $tempdir->child('foo')->make_path->child('bar')->spurt('FOOBAR');

  $t->get_ok('/storage')->status_is(200)->json_is([qw( foo/bar foobar )]);
};

subtest 'get missing file' => sub {
  my ($t, $tempdir) = build_app();
  $t->get_ok('/storage/missing')->status_is(404);
};

subtest 'ids outside of root are rejected' => sub {
  my ($t, $tempdir) = build_app();
  my $outside_name = 'yancy-storage-test-' . $$;
  my $outside = $tempdir->dirname->child($outside_name);
  $outside->spew('SECRET');

  for my $id ( "..%2F$outside_name", "foo%2F..%2F..%2F$outside_name", '.', 'foo%5C..%5Cbar' ) {
    $t->get_ok("/storage/$id")->status_is(404, "get $id");
    $t->put_ok("/storage/$id", 'PWNED')->status_is(400, "put $id");
    $t->delete_ok("/storage/$id")->status_is(400, "delete $id");
  }
  is $outside->slurp, 'SECRET', 'file outside root not changed';

  $t->post_ok('/storage/', form => { foo => { content => 'PWNED', filename => "../$outside_name" }})
    ->status_is(201);
  is $outside->slurp, 'SECRET', 'upload path in filename is ignored';
  is $tempdir->child($outside_name)->slurp, 'PWNED', 'upload stored in root';

  $t->post_ok('/storage/..', form => { foo => { content => 'PWNED', filename => 'x' }})
    ->status_is(400, 'upload prefix outside root');
  $t->post_ok('/storage/', form => { foo => { content => 'PWNED', filename => '..' }})
    ->status_is(400, 'upload filename ..');
  ok !-e $tempdir->dirname->child('x'), 'no upload outside root';

  $outside->remove;
};

done_testing;
