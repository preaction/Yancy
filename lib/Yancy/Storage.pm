package Yancy::Storage;
our $VERSION = '1.089';
# ABSTRACT: Manage file uploads, attachments, and other assets

=head1 SYNOPSIS

    my $storage = Yancy::Storage->new(
      root => $app->home->child('storage'),
    );

=head1 DESCRIPTION

This class manages file storage. This can be given to a L<Yancy::Editor> to
allow file management and/or you can wire up route handlers using the
L<Yancy::Controller::Storage> class. You can quickly set up a global storage
for your site using L<Yancy::Plugin::Storage>.

This API is meant to be subclassed by other asset storage mechanisms such as
Hadoop or Amazon S3.

=head2 Storage IDs

Storage IDs are simply strings, but they may include C</> characters to
form (or simulate) a directory structure.

=head1 SEE ALSO

L<Yancy::Plugin::Storage>, L<Yancy::Controller::Storage>, L<Yancy>

=cut

use Mojo::Base -base, -signatures;
use Scalar::Util qw( blessed );
use Mojo::File qw( path );
use Mojo::Asset::File;

=attr root

The root directory to store files.

=cut

has root => sub { die "root is required" };

sub new($class, @attrs) {
  my %attrs;
  if (@attrs > 1) {
    %attrs = @attrs;
  }
  elsif (!ref $attrs[0] || blessed $attrs[0]) {
    $attrs{root} = $attrs[0];
  }
  else {
    %attrs = %{$attrs[0]};
  }

  if (!blessed $attrs{root}) {
    $attrs{root} = path($attrs{root});
  }
  return $class->SUPER::new(%attrs);
}

=method get

Get a file's content. Returns a L<Mojo::Asset> to serve, or C<undef>
if the file does not exist. Dies if the ID is not L<valid|/valid_id>.

=cut

sub get( $self, $id ) {
  my $file = $self->_file( $id );
  return undef unless -f $file;
  return Mojo::Asset::File->new( path => $file );
}

=method put

Write a file into storage. C<$id> is a storage ID and C<$asset> is a
L<Mojo::Asset> object. Returns the storage ID of the uploaded file.

=cut

sub put( $self, $id, $asset ) {
    my $file_path = $self->_file( $id );
    $file_path->dirname->make_path;
    $file_path->spew( blessed $asset ? $asset->slurp : $asset );
    return $file_path->to_rel( $self->root )->to_string;
}

=method delete

Delete a file from storage. Returns true if there was a file to delete and it
was successfully deleted.

=cut

sub delete( $self, $id ) {
  unlink $self->_file( $id );
}

=method valid_id

Returns true if the given storage ID is safe to use. Storage IDs must not be
empty and must not contain C<.> or C<..> path parts, backslashes, or NUL
characters, so they cannot refer to files outside of the L</root>.

=cut

sub valid_id( $self, $id ) {
  return 0 if !defined $id || $id =~ m{[\\\0]};
  my @parts = grep { length } split m{/}, $id;
  return 0 if !@parts || grep { $_ eq '.' || $_ eq '..' } @parts;
  return 1;
}

sub _file( $self, $id ) {
  die qq{Invalid storage ID "$id"\n} unless $self->valid_id( $id );
  return $self->root->child( grep { length } split m{/}, $id );
}

=method list

List files in storage, optionally limited to an ID prefix. Returns a L<Mojo::Collection>
of storage ID strings.

=cut

sub list( $self, $prefix ) {
  $prefix //= '';
  return $self->root->list_tree->map(sub { $_->to_rel( $self->root ) })->grep(qr{^\Q$prefix});
}

1;
