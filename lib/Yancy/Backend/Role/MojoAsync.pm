package Yancy::Backend::Role::MojoAsync;
our $VERSION = '1.053';
# ABSTRACT: A role to give a relational backend relational capabilities

=head1 SYNOPSIS

    package Yancy::Backend::RDBMS;
    with 'Yancy::Backend::Role::MojoAsync';

=head1 DESCRIPTION

This role provides utility methods to give backend classes, that
compose in L<Yancy::Backend::Role::Relational>, implementing asynchronous
database-access methods.

It is separate from that role in order to be available only for classes
that do not use L<Yancy::Backend::Role::Sync>, avoiding clashes.

=head1 REQUIRED METHODS

The composing class must implement the following methods either as
L<constant>s or attributes:

=head2 mojodb

The value must be a relative of L<Mojo::Pg> et al.

=head1 METHODS

=head2 delete_p

Implements L<Yancy::Backend/delete_p>.

=head2 get_p

Implements L<Yancy::Backend/get_p>.

=head2 list_p

Implements L<Yancy::Backend/list_p>.

=head2 set_p

Implements L<Yancy::Backend/set_p>.

=head1 SEE ALSO

L<Yancy::Backend>

=cut

use Mojo::Base '-role';
use Mojo::Promise;

requires qw( mojodb );

sub delete_p {
    my ( $self, $coll, $id ) = @_;
    my $id_field = $self->id_field( $coll );
    return $self->mojodb->db->delete_p( $coll, { $id_field => $id } )
        ->then( sub { !!shift->rows } );
}

sub get_p {
    my ( $self, $schema_name, $id ) = @_;
    my $id_field = $self->id_field( $schema_name );
    my $schema = $self->schema->{ $schema_name };
    my $real_schema_name = ( $schema->{'x-view'} || {} )->{schema} // $schema_name;
    my $props = $schema->{properties}
        || $self->schema->{ $real_schema_name }{properties};
    my $db = $self->mojodb->db;
    return $db->select_p(
        $real_schema_name,
        [ keys %$props ],
        { $id_field => $id },
    )->then( sub { $self->normalize( $schema_name, shift->hash ) } );
}

sub list_p {
    my ( $self, $coll, $params, $opt ) = @_;
    $params ||= {}; $opt ||= {};
    my $mojodb = $self->mojodb;
    my ( $query, $total_query, @params ) = $self->list_sqls( $coll, $params, $opt );
    my $items_p = $mojodb->db->query_p( $query, @params )->then( sub {
        [ map $self->normalize( $coll, $_ ), @{ shift->hashes } ]
    } );
    my $total_p = $mojodb->db->query_p( $total_query, @params )
        ->then( sub { shift->hash->{total} } );
    return Mojo::Promise->all( $items_p, $total_p )
        ->then( sub {
            my ( $items, $total ) = @_;
            return { items => $items->[0], total => $total->[0] };
        } );
}

sub set_p {
    my ( $self, $coll, $id, $params ) = @_;
    $self->normalize( $coll, $params );
    my $id_field = $self->id_field( $coll );
    return $self->mojodb->db->update_p( $coll, $params, { $id_field => $id } )
        ->then( sub { !!shift->rows } );
}

1;
