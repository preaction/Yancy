package Yancy::Backend::MojoDB;
our $VERSION = '1.075';
# ABSTRACT: Abstract base class for drivers based on Mojo DB drivers

=head1 SYNOPSIS

    package Yancy::Backend::RDBMS;
    use Mojo::Base 'Yancy::Backend::MojoDB';

=head1 DESCRIPTION

This is an abstract base class for the Mojo database drivers:

=over
=item L<Mojo::Pg> (L<Yancy::Backend::Pg>)
=item L<Mojo::mysql> (L<Yancy::Backend::Mysql>)
=item L<Mojo::SQLite> (L<Yancy::Backend::Sqlite>)
=back

=head1 SEE ALSO

L<Yancy::Backend::Role::DBI>, L<Yancy::Backend>

=cut

use Mojo::Base 'Yancy::Backend';
use Role::Tiny 'with';
use Scalar::Util qw( blessed looks_like_number );
use Mojo::JSON qw( true encode_json );
use Carp qw( croak );
use Yancy::Util qw( is_type is_format );

with 'Yancy::Backend::Role::DBI', 'Yancy::Backend::Role::Async';
has driver =>;
sub sql_abstract { shift->driver->abstract }
sub dbh { shift->driver->db->dbh }

sub create_p {
    my ( $self, $schema_name, $params ) = @_;
    $params = $self->normalize( $schema_name, $params );
    die "No refs allowed in '$schema_name': " . encode_json $params
        if grep ref && ref ne 'SCALAR', values %$params;
    my $id_field = $self->id_field( $schema_name );
    # For databases that do not have a 'RETURNING' syntax, we must pass in all
    # parts of a composite key. In the future, we could add a surrogate
    # key which is auto-increment that could be used to find the
    # newly-created row so that we can return the correct key fields
    # here. For now, assume id field is correct if passed, created
    # otherwise.
    die "Missing composite ID parts: " . join( ', ', grep !exists $params->{$_}, @$id_field )
        if ref $id_field eq 'ARRAY' && @$id_field > grep exists $params->{$_}, @$id_field;
    return $self->driver->db->insert_p( $schema_name, $params )
        ->then( sub {
            my $inserted_id = shift->last_insert_id;
            return ref $id_field eq 'ARRAY'
                ? { map { $_ => $params->{$_} // $inserted_id } @$id_field }
                : $params->{ $id_field } // $inserted_id
                ;
        } );
}

sub delete_p {
    my ( $self, $schema_name, $id ) = @_;
    my %where = $self->id_where( $schema_name, $id );
    $self->driver->db->delete_p( $schema_name, \%where )
        ->catch(sub { croak "Error on delete '$schema_name'=$id: $_[0]" })
        ->then(sub { !!shift->rows } );
}

sub set_p {
    my ( $self, $schema_name, $id, $params ) = @_;
    $params = $self->normalize( $schema_name, $params );
    die "No refs allowed in '$schema_name'($id): " . encode_json $params
        if grep ref && ref ne 'SCALAR', values %$params;
    my %where = $self->id_where( $schema_name, $id );
    $self->driver->db->update_p( $schema_name, $params, \%where )
        ->catch(sub { croak "Error on set '$schema_name'=$id: $_[0]" })
        ->then(sub { !!shift->rows } );
}

sub get_p {
    my ( $self, $schema_name, $id ) = @_;
    my %where = $self->id_where( $schema_name, $id );
    my $schema = $self->schema->{ $schema_name };
    my $real_schema_name = ( $schema->{'x-view'} || {} )->{schema} // $schema_name;
    my $props = $schema->{properties}
        || $self->schema->{ $real_schema_name }{properties};
    $self->driver->db->select_p(
        $real_schema_name,
        [ keys %$props ],
        \%where,
    )->then( sub {
        my ( $res ) = @_;
        my $row = $res->hash;
        return undef if !$row;
        return $self->normalize( $schema_name, $row );
    } );
}

# XXX: If needed, this can be broken out into its own role based on
# SQL::Abstract.
sub list_sqls {
    my ( $self, $schema_name, $params, $opt ) = @_;
    my $schema = $self->schema->{ $schema_name };
    my $real_schema_name = ( $schema->{'x-view'} || {} )->{schema} // $schema_name;
    my $sqla = $self->sql_abstract;
    my $props = $schema->{properties}
        || $self->schema->{ $real_schema_name }{properties};
    my ( $query, @params ) = $sqla->select(
        $real_schema_name,
        [ keys %$props ],
        $params,
        $opt->{order_by},
    );
    my ( $total_query, @total_params ) = $sqla->select(
        $real_schema_name,
        [ \'COUNT(*) as total' ],
        $params,
    );
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

sub list_p {
    my ( $self, $schema_name, $params, $opt ) = @_;
    $params ||= {}; $opt ||= {};
    my $driver = $self->driver;
    my ( $query, $total_query, @params ) = $self->list_sqls( $schema_name, $params, $opt );
    $driver->db->query_p( $query, @params )->then(
        sub {
            my ( $res ) = @_;
            my $items = $res->hashes;
            return {
                items => [ map $self->normalize( $schema_name, $_ ), @$items ],
                total => $driver->db->query( $total_query, @params )->hash->{total},
            };
        },
    );
}

1;
