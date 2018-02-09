package Yancy::Backend::Sqlite;
our $VERSION = '0.015';
# ABSTRACT: A backend for SQLite using Mojo::SQLite

=head1 SYNOPSIS

    # yancy.conf
    {
        backend => 'sqlite:filename.db',
        collections => {
            table_name => { ... },
        },
    }

    # Plugin
    use Mojolicious::Lite;
    plugin Yancy => {
        backend => 'sqlite:filename.db',
        collections => {
            table_name => { ... },
        },
    };

=head1 DESCRIPTION

This Yancy backend allows you to connect to a SQLite database to manage
the data inside. This backend uses L<Mojo::SQLite> to connect to SQLite.

See L<Yancy::Backend> for the methods this backend has and their return
values.

=head2 Backend URL

The URL for this backend takes the form C<<
sqlite:<filename.db> >>.

Some examples:

    # A database file in the current directory
    sqlite:filename.db

    # In a specific location
    sqlite:/tmp/filename.db

=head2 Collections

The collections for this backend are the names of the tables in the
database.

So, if you have the following schema:

    CREATE TABLE people (
        id SERIAL,
        name VARCHAR NOT NULL,
        email VARCHAR NOT NULL
    );
    CREATE TABLE business (
        id SERIAL,
        name VARCHAR NOT NULL,
        email VARCHAR NULL
    );

You could map that schema to the following collections:

    {
        backend => 'sqlite:filename.db',
        collections => {
            People => {
                required => [ 'name', 'email' ],
                properties => {
                    id => {
                        type => 'integer',
                        readOnly => 1,
                    },
                    name => { type => 'string' },
                    email => { type => 'string' },
                },
            },
            Business => {
                required => [ 'name' ],
                properties => {
                    id => {
                        type => 'integer',
                        readOnly => 1,
                    },
                    name => { type => 'string' },
                    email => { type => 'string' },
                },
            },
        },
    }

=head1 SEE ALSO

L<Mojo::SQLite>, L<Yancy>

=cut

use Mojo::Base 'Mojo';
use Scalar::Util qw( looks_like_number );
use Text::Balanced qw( extract_bracketed );
BEGIN {
    eval { require Mojo::SQLite; Mojo::SQLite->VERSION( 3 ); 1 }
        or die "Could not load SQLite backend: Mojo::SQLite version 3 or higher required\n";
}

has sqlite =>;
has collections =>;

sub new {
    my ( $class, $backend, $collections ) = @_;
    if ( !ref $backend ) {
        my ( $connect ) = ( defined $backend && length $backend ) ? $backend =~ m{^[^:]+:(.+)$} : undef;
        $backend = Mojo::SQLite->new( defined $connect ? "sqlite:$connect" : () );
    }
    my %vars = (
        sqlite => $backend,
        collections => $collections,
    );
    return $class->SUPER::new( %vars );
}

sub create {
    my ( $self, $coll, $params ) = @_;
    my $id_field = $self->collections->{ $coll }{ 'x-id-field' } || 'id';
    my $inserted_id = $self->sqlite->db->insert( $coll, $params )->last_insert_id;
    # SQLite does not have a 'returning' syntax. Assume id field is correct
    # if passed, created otherwise:
    return $self->get( $coll, $params->{$id_field} // $inserted_id );
}

sub get {
    my ( $self, $coll, $id ) = @_;
    my $id_field = $self->collections->{ $coll }{ 'x-id-field' } || 'id';
    return $self->sqlite->db->select( $coll, undef, { $id_field => $id } )->hash;
}

sub list {
    my ( $self, $coll, $params, $opt ) = @_;
    $params ||= {}; $opt ||= {};
    my $sqlite = $self->sqlite;
    my ( $query, @params ) = $sqlite->abstract->select( $coll, undef, $params, $opt->{order_by} );
    my ( $total_query, @total_params ) = $sqlite->abstract->select( $coll, [ \'COUNT(*) as total' ], $params );
    if ( scalar grep defined, @{ $opt }{qw( limit offset )} ) {
        die "Limit must be number" if $opt->{limit} && !looks_like_number $opt->{limit};
        $query .= ' LIMIT ' . ( $opt->{limit} // 2**32 );
        if ( $opt->{offset} ) {
            die "Offset must be number" if !looks_like_number $opt->{offset};
            $query .= ' OFFSET ' . $opt->{offset};
        }
    }
    #; say $query;
    return {
        rows => $sqlite->db->query( $query, @params )->hashes,
        total => $sqlite->db->query( $total_query, @total_params )->hash->{total},
    };

}

sub set {
    my ( $self, $coll, $id, $params ) = @_;
    my $id_field = $self->collections->{ $coll }{ 'x-id-field' } || 'id';
    return $self->sqlite->db->update( $coll, $params, { $id_field => $id } );
}

sub delete {
    my ( $self, $coll, $id ) = @_;
    my $id_field = $self->collections->{ $coll }{ 'x-id-field' } || 'id';
    return $self->sqlite->db->delete( $coll, { $id_field => $id } );
}

sub read_schema {
    my ( $self ) = @_;
    my %schema;
    my $tables_q = <<ENDQ;
SELECT * FROM SQLITE_MASTER
WHERE type='table' AND name NOT LIKE 'sqlite_%'
ENDQ

    my $column_q = <<ENDQ;
PRAGMA table_info(%s)
ENDQ

    my $seq_q = <<ENDQ;
SELECT * FROM sqlite_sequence
ENDQ

    my @tables = @{ $self->sqlite->db->query( $tables_q )->hashes };
    for my $t ( @tables ) {
        my $table = $t->{name};
        # ; say "Got table $table";
        my @columns = @{ $self->sqlite->db->query( sprintf $column_q, $table )->hashes };
        # ; say "Got columns";
        # ; use Data::Dumper;
        # ; say Dumper \@columns;
        for my $c ( @columns ) {
            my $column = $c->{name};
            my $is_auto = !!( $t->{sql} =~ /${column}[^,\)]+AUTOINCREMENT/ );
            $schema{ $table }{ properties }{ $column } = {
                $self->_map_type( $c, $t ),
            };
            if ( ( $c->{notnull} || $c->{pk} ) && !$is_auto && !$c->{dflt_value} ) {
                push @{ $schema{ $table }{ required } }, $column;
            }
            if ( $c->{pk} == 1 && $column ne 'id' ) {
                $schema{ $table }{ 'x-id-field' } = $column;
            }
        }
    }

    return \%schema;
}

sub _map_type {
    my ( $self, $column, $table ) = @_;
    my $db_type = $column->{type};
    # ; use Data::Dumper;
    # ; say Dumper $column;
    # ; say $table->{sql};
    my $col_name = $column->{name};
    if ( $table->{sql} =~ /${col_name}[^,\)]+CHECK\s*(.+)\)\s*$/si ) {
        # Column has a check constraint, see if it's an enum-like
        my $check = $1;
        my ( $constraint, $remainder ) = extract_bracketed( $check, '(' );
        if ( $constraint =~ /${col_name}\s+in\s*\([^)]+\)/i ) {
            $constraint = substr $constraint, 1, -1;
            $constraint =~ s/\s*${col_name}\s+in\s+//i;
            $constraint =~ s/\s*$//;
            my @values = split ',', substr $constraint, 1, -1;
            s/^\s*'|'\s*$//g for @values;
            return ( type => 'string', enum => \@values );
        }
    }

    if ( $db_type =~ /^(?:text|varchar)/i ) {
        return ( type => 'string' );
    }
    elsif ( $db_type =~ /^(?:int|integer|smallint|bigint|tinyint|rowid)/i ) {
        return ( type => 'integer' );
    }
    elsif ( $db_type =~ /^(?:double|float|money|numeric|real)/i ) {
        return ( type => 'number' );
    }
    elsif ( $db_type =~ /^(?:timestamp)/i ) {
        return ( type => 'string', format => 'date-time' );
    }
    # Default to string
    return ( type => 'string' );
}

1;
