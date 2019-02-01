package Yancy::Backend::Role::MojoAsync;
our $VERSION = '1.023';
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

=head1 SEE ALSO

L<Yancy::Backend>

=cut

use Mojo::Base '-role';

requires qw( mojodb );

sub delete_p {
    my ( $self, $coll, $id ) = @_;
    my $id_field = $self->_id_field( $coll );
    return $self->mojodb->db->delete_p( $coll, { $id_field => $id } )
        ->then( sub { !!shift->rows } );
}

sub get_p {
    my ( $self, $coll, $id ) = @_;
    my $id_field = $self->id_field( $coll );
    my $db = $self->mojodb->db;
    return $db->select_p( $coll, undef, { $id_field => $id } )
        ->then( sub { shift->hash } );
}

1;
