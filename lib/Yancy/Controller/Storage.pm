package Yancy::Controller::Storage;
our $VERSION = '1.089';
# ABSTRACT: Interact with storage via routes

=head1 SYNOPSIS

    my $storage = Yancy::Storage->new(root => $app->home->child('storage'));

=head1 DESCRIPTION

This controller allows interacting with a L<Yancy::Storage> object via
routes.

=head1 SEE ALSO

L<Yancy::Storage>, L<Yancy::Plugin::Storage>

=cut

use Mojo::Base 'Mojolicious::Controller', -signatures;

sub _storage($c) {
  return $c->stash('storage') || $c->can('storage')->($c) || die "No storage?";
}

=method get

=cut

sub get( $c ) {
  my $asset = $c->_storage->get($c->param('id')) or return $c->reply->not_found;
  return $c->reply->asset($asset);
}

=method put

=cut

sub put( $c ) {
  $c->_storage->put( $c->param('id'), $c->req->body );
  $c->rendered(201);
}

=method post

=cut

sub post( $c ) {
  my $storage = $c->_storage;
  my $prefix = $c->param('prefix');
  for my $upload ( @{ $c->req->uploads } ) {
    my $id = $prefix ? join( '/', $prefix, $upload->filename ) : $upload->filename;
    $c->log->info("Uploading file $id");
    $storage->put( $id, $upload->asset );
  }
  $c->rendered(201);
}

=method delete

=cut

sub delete( $c ) {
  $c->_storage->delete($c->param('id'));
  return $c->rendered(201);
}

=method list

=cut

sub list( $c ) {
  return $c->render(json => $c->_storage->list($c->param('prefix')))
}

1;
