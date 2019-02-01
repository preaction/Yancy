package Yancy::Backend::Role::Relational;
our $VERSION = '1.023';
# ABSTRACT: A role to give a relational backend relational capabilities

=head1 SYNOPSIS

    package Yancy::Backend::RDBMS;
    with 'Yancy::Backend::Role::Relational';

=head1 DESCRIPTION

This role implements utility methods to make backend classes work with
entity relations, using L<DBI> methods such as
C<DBI/foreign_key_info>.

=head1 REQUIRED METHODS

The composing class must implement the following methods either as
L<constant>s or attributes:

=head2 mojodb

The value must be a relative of L<Mojo::Pg> et al.

=head2 mojodb_class

String naming the C<Mojo::*> class.

=head2 mojodb_prefix

String with the value at the start of a L<DBI> C<dsn>.

=head1 METHODS

=head2 new

Self-explanatory, implements L<Yancy::Backend/new>.

=head2 id_field

Given a collection, returns the string name of its ID field.

=head2 list_sqls

Given a collection, parameters and options, returns SQL to generate the
actual results, the count results, and the bind-parameters.

=head2 normalize

Given a collection and data, normalises any boolean values to 1 and 0.

=head2 delete

Self-explanatory, implements L<Yancy::Backend/delete>.

=head2 set

Self-explanatory, implements L<Yancy::Backend/set>.

=head1 SEE ALSO

L<Yancy::Backend>

=cut

use Mojo::Base '-role';
use Scalar::Util qw( blessed looks_like_number );

requires qw( mojodb mojodb_class mojodb_prefix );

sub new {
    my ( $class, $backend, $collections ) = @_;
    if ( !ref $backend ) {
        my $found = (my $connect = $backend) =~ s#^.*?:##;
        $backend = $class->mojodb_class->new( $found ? $class->mojodb_prefix.":$connect" : () );
    }
    elsif ( !blessed $backend ) {
        my $attr = $backend;
        $backend = $class->mojodb_class->new;
        for my $method ( keys %$attr ) {
            $backend->$method( $attr->{ $method } );
        }
    }
    my %vars = (
        mojodb => $backend,
        collections => $collections,
    );
    Mojo::Base::new( $class, %vars );
}

sub id_field {
    my ( $self, $coll ) = @_;
    return $self->collections->{ $coll }{ 'x-id-field' } || 'id';
}

sub list_sqls {
    my ( $self, $coll, $params, $opt ) = @_;
    my $mojodb = $self->mojodb;
    my ( $query, @params ) = $mojodb->abstract->select( $coll, undef, $params, $opt->{order_by} );
    my ( $total_query, @total_params ) = $mojodb->abstract->select( $coll, [ \'COUNT(*) as total' ], $params );
    if ( scalar grep defined, @{ $opt }{qw( limit offset )} ) {
        die "Limit must be number" if $opt->{limit} && !looks_like_number $opt->{limit};
        $query .= ' LIMIT ' . ( $opt->{limit} // 2**32 );
        if ( $opt->{offset} ) {
            die "Offset must be number" if !looks_like_number $opt->{offset};
            $query .= ' OFFSET ' . $opt->{offset};
        }
    }
    #; say $query;
    return ( $query, $total_query, @params );
}

sub normalize {
    my ( $self, $coll, $data ) = @_;
    my $schema = $self->collections->{ $coll }{ properties };
    for my $key ( keys %$data ) {
        my $type = $schema->{ $key }{ type };
        # Boolean: true (1, "true"), false (0, "false")
        if ( _is_type( $type, 'boolean' ) ) {
            $data->{ $key }
                = $data->{ $key } && $data->{ $key } !~ /^false$/i
                ? 1 : 0;
        }
    }
}

sub _is_type {
    my ( $type, $is_type ) = @_;
    return unless $type;
    return ref $type eq 'ARRAY'
        ? !!grep { $_ eq $is_type } @$type
        : $type eq $is_type;
}

sub delete {
    my ( $self, $coll, $id ) = @_;
    my $id_field = $self->id_field( $coll );
    return !!$self->mojodb->db->delete( $coll, { $id_field => $id } )->rows;
}

sub set {
    my ( $self, $coll, $id, $params ) = @_;
    $self->normalize( $coll, $params );
    my $id_field = $self->id_field( $coll );
    return !!$self->mojodb->db->update( $coll, $params, { $id_field => $id } )->rows;
}

1;
