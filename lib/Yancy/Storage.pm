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

Get a file's content. Returns a L<Mojo::Asset> to serve.

=cut

sub get( $self, $id ) {
  return Mojo::Asset::File->new( path => $self->root->child( $id ) );
}

=method put

Write a file into storage. C<$id> is a storage ID and C<$asset> is a
L<Mojo::Asset> object. Returns the storage ID of the uploaded file.

=cut

sub put( $self, $id, $asset ) {
    my @path_parts = grep $_, split m{/}, $id;
    my $name = pop @path_parts;
    my $root = $self->root;
    my $path = $root->child( @path_parts )->make_path;
    my $file_path = $path->child( $name );
    $file_path->spurt( blessed $asset ? $asset->slurp : $asset );
    return join '/', @path_parts, $name;
}

=method delete

Delete a file from storage. Returns true if there was a file to delete and it
was successfully deleted.

=cut

sub delete( $self, $id ) {
  unlink $self->root->child($id);
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
