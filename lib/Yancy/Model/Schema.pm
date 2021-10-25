package Yancy::Model::Schema;
our $VERSION = '1.081';
# ABSTRACT: Interface to a single schema

=head1 SYNOPSIS

    my $schema = $app->model->schema( 'foo' );

    my $id = $schema->create( $data );
    my $item = $schema->get( $id );
    my $count = $schema->delete( $id );
    my $count = $schema->delete( $where );
    my $count = $schema->set( $id, $data );
    my $count = $schema->set( $where, $data );

    my $res = $schema->list( $where, $opts );
    for my $item ( @{ $res->{items} } ) { ... }

=head1 DESCRIPTION

B<NOTE>: This module is experimental and its API may change before
Yancy v2!

For information on how to extend this module to add your own schema
and item methods, see L<Yancy::Guides::Model>.

=head1 SEE ALSO

L<Yancy::Guides::Model>, L<Yancy::Model>

=cut

use Mojo::Base -base;

=attr model

The L<Yancy::Model> object that created this schema object.

=cut

has model => sub { die 'model is required' };

=attr name

The name of the schema.

=cut

has name => sub { die 'name is required' };

sub _backend { shift->model->backend };
has _item_class => sub {
    my $self = shift;
    return $self->model->find_class( Item => $self->name );
};

=method info

The JSON Schema for this schema.

=cut

sub info {
    my ( $self ) = @_;
    return $self->_backend->schema->{ $self->name };
}

=method id_field

The ID field for this schema. Either a single string, or an arrayref of
strings (for composite keys).

=cut

sub id_field {
    my ( $self ) = @_;
    return $self->info->{'x-id-field'} // 'id';
}

=method build_item

Turn a hashref of row data into a L<Yancy::Model::Item> object using
L<Yancy::Model/find_class> to find the correct class.

=cut

sub build_item {
    my ( $self, $data ) = @_;
    return $self->_item_class->new( { data => $data, schema => $self } );
}

=method get

Get an item by its ID. Returns a L<Yancy::Model::Item> object.

=cut

sub get {
    my ( $self, $id, %opt ) = @_;
    return $self->build_item( $self->_backend->get( $self->name, $id, %opt ) // return undef );
}

=method list

List items. Returns a hash reference with C<items> and C<total> keys. The C<items> is
an array ref of L<Yancy::Model::Item> objects. C<total> is the total number of items
that would be returned without any C<offset> or C<limit> options.

=cut

sub list {
    my ( $self, $where, $opt ) = @_;
    my $res = $self->_backend->list( $self->name, $where, $opt );
    return { items => [ map { $self->build_item( $_ ) } @{ $res->{items} } ], total => $res->{total} };
}

=method create

Create a new item. Returns the ID of the created item.

=cut

sub create {
    my ( $self, $data ) = @_;
    return $self->_backend->create( $self->name, $data );
}

=method set

Set the given fields in an item. See also L<Yancy::Model::Item/set>.

=cut

sub set {
    my ( $self, $id, $data ) = @_;
    # XXX: Use get() to get the item instance first? Then they could
    # override set() to do things...
    return $self->_backend->set( $self->name, $id, $data );
}

=method delete

Delete an item. See also L<Yancy::Model::Item/delete>.

=cut

sub delete {
    my ( $self, $id ) = @_;
    # XXX: Use get() to get the item instance first? Then they could
    # override delete() to do things...
    return $self->_backend->delete( $self->name, $id );
}

1;
