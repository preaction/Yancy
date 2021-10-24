package Yancy::Backend::MojoDB;
our $VERSION = '1.080';
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

with 'Yancy::Backend::Role::DBI';
has driver =>;
sub sql_abstract { shift->driver->abstract }
sub dbh { shift->driver->db->dbh }

sub create {
    my ( $self, $schema_name, $params ) = @_;
    $params = $self->normalize( $schema_name, $params );
    my $id_field = $self->id_field( $schema_name );
    # For databases that do not have a 'RETURNING' syntax, we must pass in all
    # parts of a composite key. In the future, we could add a surrogate
    # key which is auto-increment that could be used to find the
    # newly-created row so that we can return the correct key fields
    # here. For now, assume id field is correct if passed, created
    # otherwise.
    die "Missing composite ID parts: " . join( ', ', grep !exists $params->{$_}, @$id_field )
        if ref $id_field eq 'ARRAY' && @$id_field > grep exists $params->{$_}, @$id_field;
    my $res = $self->driver->db->insert( $schema_name, $params );
    my $inserted_id = $res->last_insert_id;
    return ref $id_field eq 'ARRAY'
        ? { map { $_ => $params->{$_} // $inserted_id } @$id_field }
        : $params->{ $id_field } // $inserted_id
        ;
}

sub delete {
    my ( $self, $schema_name, $id ) = @_;
    my %where = $self->id_where( $schema_name, $id );
    my $res = eval { $self->driver->db->delete( $schema_name, \%where ) };
    if ( $@ ) {
        croak "Error on delete '$schema_name'=$id: $@";
    }
    return !!$res->rows;
}

sub set {
    my ( $self, $schema_name, $id, $params ) = @_;
    $params = $self->normalize( $schema_name, $params );
    my %where = $self->id_where( $schema_name, $id );
    my $res = eval { $self->driver->db->update( $schema_name, $params, \%where ) };
    if ( $@ ) {
        croak "Error on set '$schema_name'=$id: $@";
    }
    return !!$res->rows;
}

sub _sql_select {
    my ( $self, $schema_name, $where, $opt ) = @_;
    my $schema = $self->schema->{ $schema_name };
    my $from = ( $schema->{'x-view'} || {} )->{schema} // $schema_name;
    my %props = %{ $schema->{properties} || $self->schema->{ $from }{properties} };
    my @cols = keys %props;

    if ( my $join = $opt->{join} ) {
        # Make sure everything is fully-qualified
        @cols = map { "$schema_name.$_" } @cols;
        $where->{ "$schema_name.$_" } = delete $where->{ $_ } for grep !/\./, keys %$where;

        $from = [ $from ];
        my @joins = ref $join eq 'ARRAY' ? @$join : ( $join );
        for my $j ( @joins ) {
            if ( exists $props{ $j } ) {
                my $join_prop = $props{ $j };
                my $join_schema_name = $join_prop->{'x-foreign-key'};
                my $join_schema = $self->schema->{ $join_schema_name };
                my $join_props = $join_schema->{properties};
                my $join_key_field = $join_schema->{'x-id-field'} // 'id';
                push @{ $from }, [ -left => \("$join_prop->{'x-foreign-key'} AS $j"), "$j.$j", $join_key_field ];
                push @cols, map { [ "${j}.$_", "${j}_$_" ] } keys %{ $join_props };
            }
            elsif ( exists $self->schema->{ $j } ) {
                my $join_schema_name = $j;
                my $join_schema = $self->schema->{ $j };
                my $join_props = $join_schema->{properties};
                my ( $join_prop_name ) = grep { ($join_props->{$_}{'x-foreign-key'}//'') eq $schema_name } keys %$join_props;
                my $join_key_field = $schema->{'x-id-field'} // 'id';
                push @{ $from }, [ -left => $join_schema_name, $join_key_field, $join_prop_name ];
                push @cols, map { [ "$join_schema_name.$_", "${j}_$_" ] } keys %{ $join_props };
            }
        }
    }
    return $from, \@cols, $where;
}

sub _expand_join {
    my ( $self, $schema_name, $res, $joins ) = @_;
    my @joins = ref $joins eq 'ARRAY' ? @$joins : ( $joins );
    my $id_field = $self->id_field( $schema_name );
    my %props = %{ $self->schema->{ $schema_name }{properties} };
    my ( @rows, %rows );
    while ( my $r = $res->hash ) {
        my $row = $rows{ $r->{$id_field} };
        if ( !$row ) {
            $row = $r;
            push @rows, $row;
            $rows{ $r->{ $id_field } } = $row;
            # First instance of the row fills in all one-to-one
            # relationships
            for my $j ( @joins ) {
                my $j_id = $self->schema->{ $j } ? ($self->schema->{$j}{'x-id-field'}//'id') : $j;
                # If the ID field isn't defined, then there was no row
                # to join. So just remove the columns for the join
                if ( !defined $row->{ "${j}_${j_id}" } ) {
                    %$row = (
                        # Keys not in the join
                        ( map { $_ => $row->{$_} } grep !/^${j}_/, keys %$row ),
                        # Empty array, if needed
                        ( $j => [] )x!!$self->schema->{ $j },
                    );
                    next;
                }
                %$row = (
                    # Keys not in the join
                    ( map { $_ => $row->{$_} } grep !/^${j}_/, keys %$row ),
                    # Keys in the join
                    $j => exists $props{ $j }
                        # One-to-one relationship
                        ? { map { s/^${j}_//r => $row->{$_} } grep /^${j}_/, keys %$row }
                        # One-to-many relationship
                        : [{ map { s/^${j}_//r => $row->{$_} } grep /^${j}_/, keys %$row }]
                );
            }
            next;
        }
        # Subsequent rows add to one-to-many relationship
        for my $j ( grep !exists $props{ $_ }, @joins ) {
            my $j_id = $self->schema->{$j}{'x-id-field'}//'id';
            # If the ID field isn't defined, then there was no row
            # to join. So just skip this.
            next if !defined $r->{ "${j}_${j_id}" };
            push @{ $row->{ $j } }, { map { s/^${j}_//r => $r->{$_} } grep /^${j}_/, keys %$r };
        }
    }
    return wantarray ? @rows : $rows[-1];
}

sub get {
    my ( $self, $schema_name, $id, %opt ) = @_;
    my %where = $self->id_where( $schema_name, $id );
    my ( $from, $cols, $where ) = $self->_sql_select( $schema_name, \%where, \%opt );
    my ( $sql, @params ) = $self->driver->abstract->select( $from, $cols, $where );
    my $res = $self->driver->db->query( $sql, @params );
    my $row = $opt{join} ? $self->_expand_join( $schema_name, $res, $opt{join} ) : $res->hash;
    return $row if !$row;
    return $self->normalize( $schema_name, $row );
}

sub get_p {
    my ( $self, $schema_name, $id, %opt ) = @_;
    my %where = $self->id_where( $schema_name, $id );
    my ( $from, $cols, $where ) = $self->_sql_select( $schema_name, \%where, \%opt );
    my ( $sql, @params ) = $self->driver->abstract->select( $from, $cols, $where );
    my $p = $self->driver->db->query_p( $sql, @params );
    return $p->then( sub {
        my ( $res ) = @_;
        my $row = $opt{join} ? $self->_expand_join( $schema_name, $res, $opt{join} ) : $res->hash;
        return $self->normalize( $schema_name, $row );
    });
}

sub list {
    my ( $self, $schema_name, $params, @opt ) = @_;
    my $opt = @opt % 2 == 0 ? {@opt} : $opt[0];
    $params ||= {}; $opt ||= {};
    my $driver = $self->driver;
    my ( $query, $total_query, @params ) = $self->list_sqls( $schema_name, $params, $opt );
    my $res = $driver->db->query( $query, @params );
    my @items = $opt->{join} ? $self->_expand_join( $schema_name, $res, $opt->{join} ) : @{$res->hashes};
    return {
        items => [ map $self->normalize( $schema_name, $_ ), @items ],
        total => $driver->db->query( $total_query, @params )->hash->{total},
    };
}

sub create_p {
    my ( $self, $schema_name, $params ) = @_;
    $params = $self->normalize( $schema_name, $params );
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
    my %where = $self->id_where( $schema_name, $id );
    $self->driver->db->update_p( $schema_name, $params, \%where )
        ->catch(sub { croak "Error on set '$schema_name'=$id: $_[0]" })
        ->then(sub { !!shift->rows } );
}

# XXX: If needed, this can be broken out into its own role based on
# SQL::Abstract.
sub list_sqls {
    my ( $self, $schema_name, $where, $opt ) = @_;
    my $schema = $self->schema->{ $schema_name };
    my $id_field = $schema->{'x-id-field'} // 'id';
    my $real_schema_name = ( $schema->{'x-view'} || {} )->{schema} // $schema_name;
    my $sqla = $self->sql_abstract;

    ( my $from, my $cols, $where ) = $self->_sql_select( $schema_name, $where, $opt );
    my ( $query, @params ) = $sqla->select(
        $from, $cols, $where,
        {
            order_by => $opt->{order_by},
        },
    );

    # XXX: SQL::Abstract::mysql destroys the $from joined table arrays
    ( $from, $cols, $where ) = $self->_sql_select( $schema_name, $where, $opt );
    my ( $total_query, @total_params ) = $sqla->select(
        $from,
        [ grep { !ref && ( /^$schema_name\./ || !/\./ ) } @$cols ],
        $where,
    );
    $total_query =~ s/SELECT/SELECT DISTINCT/i;
    $total_query = 'SELECT COUNT(*) AS total FROM (' . $total_query . ') total_query';

    if ( scalar grep defined, @{ $opt }{qw( limit offset )} ) {
        # XXX: SQL::Abstract now handles this, so we should move this.
        die "Limit must be number" if $opt->{limit} && !looks_like_number $opt->{limit};
        $query .= ' LIMIT ' . ( $opt->{limit} // 2**32 );
        if ( $opt->{offset} ) {
            die "Offset must be number" if !looks_like_number $opt->{offset};
            $query .= ' OFFSET ' . $opt->{offset};
        }
    }
    #; say $query;
    #; say $total_query;
    return ( $query, $total_query, @params );
}

sub list_p {
    my ( $self, $schema_name, $params, @opt ) = @_;
    my $opt = @opt % 2 == 0 ? {@opt} : $opt[0];
    $params ||= {};
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
