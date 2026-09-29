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

sub _invalid_id($c, $id) {
  return $c->render( status => 400, json => { errors => [ { message => qq{Invalid storage ID "$id"} } ] } );
}

sub _storage($c) {
  return $c->stash('storage') || $c->can('storage')->($c) || die "No storage?";
}

=method get

=cut

sub get( $c ) {
  my $storage = $c->_storage;
  my $id = $c->param('id');
  return $c->reply->not_found unless $storage->valid_id($id);
  my $asset = $storage->get($id) or return $c->reply->not_found;
  return $c->reply->asset($asset);
}

=method put

=cut

sub put( $c ) {
  my $storage = $c->_storage;
  my $id = $c->param('id');
  return $c->_invalid_id($id) unless $storage->valid_id($id);
  $storage->put( $id, $c->req->body );
  $c->rendered(201);
}

=method post

=cut

sub post( $c ) {
  my $storage = $c->_storage;
  my $prefix = $c->param('prefix');
  my @uploads;
  for my $upload ( @{ $c->req->uploads } ) {
    # Browsers may send a full client path, so only keep the file name
    my ( $name ) = $upload->filename =~ m{([^/\\]*)$};
    my $id = $prefix ? join( '/', $prefix, $name ) : $name;
    return $c->_invalid_id($id) unless $storage->valid_id($id);
    push @uploads, [ $id, $upload ];
  }
  for my $item ( @uploads ) {
    my ( $id, $upload ) = @$item;
    $c->log->info("Uploading file $id");
    $storage->put( $id, $upload->asset );
  }
  $c->rendered(201);
}

=method delete

=cut

sub delete( $c ) {
  my $storage = $c->_storage;
  my $id = $c->param('id');
  return $c->_invalid_id($id) unless $storage->valid_id($id);
  $storage->delete($id);
  return $c->rendered(201);
}

=method list

=cut

sub list( $c ) {
  return $c->render(json => $c->_storage->list($c->param('prefix')))
}

1;
