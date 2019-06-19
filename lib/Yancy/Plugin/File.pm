package Yancy::Plugin::File;
our $VERSION = '1.033';
# ABSTRACT: Manage file uploads, attachments, and other assets

=head1 SYNOPSIS

    # XXX

=head1 DESCRIPTION

B<Note:> This module is C<EXPERIMENTAL> and its API may change before
Yancy v2.000 is released.

XXX

This plugin API is meant to be subclassed by other asset storage
mechanisms such as Hadoop or Amazon S3.

=head1 CONFIGURATION

This plugin has the following configuration options.

XXX

=head1 SEE ALSO

L<Yancy>

=cut

use Mojo::Base 'Mojolicious::Plugin';
use Yancy::Util qw( currym );
use Digest;
use Mojo::Asset::File;
use Mojo::File;

has file_root =>;
has url_root =>;
has temp_ttl => 60 * 60; # An hour
has digest_type => 'SHA-1';
has moniker => 'file';

sub register {
    my ( $self, $app, $config ) = @_;
    my $file_root = $config->{file_root} ? Mojo::File->new( $config->{file_root} ) : $app->home->child( 'public/uploads' );
    $self->file_root( $file_root );
    my $url_root = $config->{url_root} // '/uploads';
    $self->url_root( $url_root );
    my $moniker = $config->{moniker} // 'file';
    $self->moniker( $moniker );
    $app->helper( 'yancy.' . $moniker, sub { $self } );
}

sub write {
    my ( $self, $name, $asset ) = @_;
    my $digest = $self->_digest_file( $asset );
    my @path_parts = grep $_, split /(..)/, $digest, 3;
    my $root = $self->file_root;
    my $path = $root->child( @path_parts )->make_path;
    my $file_path = $path->child( $name );
    $file_path->spurt( $asset->slurp );
    return join '/', $self->url_root, $file_path->to_rel( $root );
}

sub read {
    my ( $self, $path ) = @_;
    my $asset = Mojo::Asset::File->new( path => $self->file_root->child( $path ) );
    return $asset;
}

sub exists {
    my ( $self, $path ) = @_;
    return -e $self->file_root->child( $path );
}

sub cleanup {
    my ( $self, $c ) = @_;
    # Clean up any unlinked files by scanning the entire database for
    # files and then leaving only those files.
    my ( %files, %linked );

    # List all the files
    for my $path ( $self->file_root->list_tree->each ) {
        $files{ $path }++;
    }

    # Find all the linked files
    my $schema = $c->yancy->schema;
    for my $schema_name ( keys %$schema ) {
        my @path_fields;
        for my $property_name ( keys %{ $schema->{$schema_name} } ) {
            my $prop = $schema->{$schema_name}{$property_name};
            next unless
                $prop->{type} eq 'string' && $prop->{format} eq 'filepath';
            push @path_fields, $property_name;
        }

        # Fetch the rows with values in the path
        # XXX
        # Add to linked records
        # XXX
    }

    # Any file that does not have a link must be deleted
    # XXX

    return;
}

sub _digest_file {
    my ( $self, $asset ) = @_;
    # Using hex instead of base64 to support case-insensitive file
    # systems
    my $digest = Digest->new( $self->digest_type )->add( $asset->slurp )->hexdigest;
    return $digest;
}

1;
