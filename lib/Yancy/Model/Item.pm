package Yancy::Model::Item;
our $VERSION = '1.078';
# ABSTRACT: Interface to a single item

=head1 SYNOPSIS

    my $schema = $model->schema( 'foo' );
    my $item = $schema->get( $id );

    $item->set( $data );
    $item->delete;

=head1 DESCRIPTION

B<NOTE>: This module is experimental and it's API may change before
Yancy v2!

For information on how to extend this module to add your own schema
and item methods, see L<Yancy::Guides::Model>.

=head1 SEE ALSO

L<Yancy::Guides::Model>

=cut

use Mojo::Base -base;
use overload
    '%{}' => \&_hashref,
    fallback => 1;

sub _hashref {
    my ( $self ) = @_;
    # If we're not being called by ourselves or one of our superclasses,
    # we want to pretend we're a hashref of plain data.
    if ( !$self->isa( scalar caller ) ) {
        return $self->{data};
    }
    return $self;
}

=attr schema

The L<Yancy::Model::Schema> object containing this item.

=cut

has schema => sub { die 'schema is required' };

=attr data

The row data for this item.

=cut

has data => sub { die 'data is required' };

=method model

The L<Yancy::Model> object that contains this item.

=cut

sub model { shift->schema->model }

=method id

The ID field for the item. Returns a string or a hash-reference (for composite keys).

=cut

sub id {
    my ( $self ) = @_;
    my $id_field = $self->schema->id_field;
    my $data = $self->data;
    if ( ref $id_field eq 'ARRAY' ) {
        return { map { $_ => $data->{$_} } @$id_field };
    }
    return $data->{ $id_field };
}

=method set

Set data in this item. Returns true if successful.

=cut

sub set {
    my ( $self, $data ) = @_;
    if ( $self->schema->set( $self->id, $data ) ) {
        $self->data->{ $_ } = $data->{ $_ } for keys %$data;
        return 1;
    }
    return 0;
}

=method delete

Delete this item from the database. Returns true if successful.

=cut

sub delete {
    my ( $self ) = @_;
    return $self->schema->delete( $self->id );
}

1;

