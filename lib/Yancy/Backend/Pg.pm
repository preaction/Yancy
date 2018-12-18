package Yancy::Backend::Pg;
our $VERSION = '1.018';
# ABSTRACT: A backend for Postgres using Mojo::Pg

=head1 SYNOPSIS

    ### URL string
    use Mojolicious::Lite;
    plugin Yancy => {
        backend => 'pg://user:pass@localhost/mydb',
        read_schema => 1,
    };

    ### Mojo::Pg object
    use Mojolicious::Lite;
    use Mojo::Pg;
    plugin Yancy => {
        backend => { Pg => Mojo::Pg->new( 'postgres:///myapp' ) },
        read_schema => 1,
    };

    ### Hashref
    use Mojolicious::Lite;
    plugin Yancy => {
        backend => {
            Pg => {
                dsn => 'dbi:Pg:dbname',
                username => 'fry',
                password => 'b3nd3r1sgr34t',
            },
        },
        read_schema => 1,
    };


=head1 DESCRIPTION

This Yancy backend allows you to connect to a Postgres database to manage
the data inside. This backend uses L<Mojo::Pg> to connect to Postgres.

See L<Yancy::Backend> for the methods this backend has and their return
values.

=head2 Backend URL

The URL for this backend takes the form C<<
pg://<user>:<pass>@<host>:<port>/<db> >>.

Some examples:

    # Just a DB
    pg:///mydb

    # User+DB (server on localhost:5432)
    pg://user@/mydb

    # User+Pass Host and DB
    mysql://user:pass@example.com/mydb

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
        backend => 'pg://user@/mydb',
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

=head2 Ignored Tables

By default, this backend will ignore some tables when using
C<read_schema>: Tables used by L<Mojo::Pg::Migrations>,
L<DBIx::Class::Schema::Versioned> (in case we're co-habitating with
a DBIx::Class schema), and all the tables used by the
L<Minion::Backend::Pg> Minion backend.

=head1 SEE ALSO

L<Mojo::Pg>, L<Yancy>

=cut

use Mojo::Base '-base';
use Mojo::Promise;
use Scalar::Util qw( looks_like_number blessed );
BEGIN {
    eval { require Mojo::Pg; Mojo::Pg->VERSION( 4.03 ); 1 }
        or die "Could not load Pg backend: Mojo::Pg version 4.03 or higher required\n";
}

our %IGNORE_TABLE = (
    mojo_migrations => 1,
    minion_jobs => 1,
    minion_workers => 1,
    minion_locks => 1,
    dbix_class_schema_versions => 1,
);

has pg =>;
has collections =>;

sub new {
    my ( $class, $backend, $collections ) = @_;
    if ( !ref $backend ) {
        my ( $connect ) = $backend =~ m{^[^:]+://(.+)$};
        $backend = Mojo::Pg->new( "postgresql://$connect" );
    }
    elsif ( !blessed $backend ) {
        my $attr = $backend;
        $backend = Mojo::Pg->new;
        for my $method ( keys %$attr ) {
            $backend->$method( $attr->{ $method } );
        }
    }
    my %vars = (
        pg => $backend,
        collections => $collections,
    );
    return $class->SUPER::new( %vars );
}

sub _id_field {
    my ( $self, $coll ) = @_;
    return $self->collections->{ $coll }{ 'x-id-field' } || 'id';
}

sub create {
    my ( $self, $coll, $params ) = @_;
    my $id_field = $self->_id_field( $coll );
    return $self->pg->db->insert( $coll, $params, { returning => $id_field } )->hash->{ $id_field };
}

sub create_p {
    my ( $self, $coll, $params ) = @_;
    my $id_field = $self->_id_field( $coll );
    return $self->pg->db->insert_p( $coll, $params, { returning => $id_field } )
        ->then( sub { shift->hash->{ $id_field } } );
}

sub get {
    my ( $self, $coll, $id ) = @_;
    my $id_field = $self->_id_field( $coll );
    return $self->pg->db->select( $coll, undef, { $id_field => $id } )->hash;
}

sub get_p {
    my ( $self, $coll, $id ) = @_;
    my $id_field = $self->_id_field( $coll );
    my $db = $self->pg->db;
    return $db->select_p( $coll, undef, { $id_field => $id } )
        ->then( sub { shift->hash } );
}

sub _list_sqls {
    my ( $self, $coll, $params, $opt ) = @_;
    my $pg = $self->pg;
    my ( $query, @params ) = $pg->abstract->select( $coll, undef, $params, $opt->{order_by} );
    my ( $total_query, @total_params ) = $pg->abstract->select( $coll, [ \'COUNT(*) as total' ], $params );
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

sub list {
    my ( $self, $coll, $params, $opt ) = @_;
    $params ||= {}; $opt ||= {};
    my $pg = $self->pg;
    my ( $query, $total_query, @params ) = $self->_list_sqls( $coll, $params, $opt );
    return {
        items => $pg->db->query( $query, @params )->hashes,
        total => $pg->db->query( $total_query, @params )->hash->{total},
    };
}

sub list_p {
    my ( $self, $coll, $params, $opt ) = @_;
    $params ||= {}; $opt ||= {};
    my $pg = $self->pg;
    my ( $query, $total_query, @params ) = $self->_list_sqls( $coll, $params, $opt );
    my $items_p = $pg->db->query_p( $query, @params )->then( sub { shift->hashes } );
    my $total_p = $pg->db->query_p( $total_query, @params )
        ->then( sub { shift->hash->{total} } );
    return Mojo::Promise->all( $items_p, $total_p )
        ->then( sub {
            my ( $items, $total ) = @_;
            return { items => $items->[0], total => $total->[0] };
        } );
}

sub set {
    my ( $self, $coll, $id, $params ) = @_;
    my $id_field = $self->_id_field( $coll );
    return !!$self->pg->db->update( $coll, $params, { $id_field => $id } )->rows;
}

sub set_p {
    my ( $self, $coll, $id, $params ) = @_;
    my $id_field = $self->_id_field( $coll );
    return $self->pg->db->update_p( $coll, $params, { $id_field => $id } )
        ->then( sub { !!shift->rows } );
}

sub delete {
    my ( $self, $coll, $id ) = @_;
    my $id_field = $self->_id_field( $coll );
    return !!$self->pg->db->delete( $coll, { $id_field => $id } )->rows;
}

sub delete_p {
    my ( $self, $coll, $id ) = @_;
    my $id_field = $self->_id_field( $coll );
    return $self->pg->db->delete_p( $coll, { $id_field => $id } )
        ->then( sub { !!shift->rows } );
}

sub read_schema {
    my ( $self, @table_names ) = @_;
    my $database = $self->pg->db->query( 'SELECT current_schema()' )->array->[0];

    my %schema;
    my $tables_q = <<ENDQ;
SELECT * FROM information_schema.tables
WHERE table_schema=?
ENDQ
    if ( @table_names ) {
        $tables_q .= sprintf ' AND table_name IN ( %s )', join ', ', ('?') x @table_names;
    }

    my $key_q = <<ENDQ;
SELECT c.column_name FROM information_schema.table_constraints as tc
JOIN information_schema.constraint_column_usage AS ccu
    USING (constraint_schema, constraint_name)
JOIN information_schema.columns AS c
    ON tc.table_schema=c.table_schema
        AND tc.table_name=c.table_name
        AND ccu.column_name=c.column_name
WHERE tc.table_schema=?
    AND tc.table_name=? 
    AND ( constraint_type = 'PRIMARY KEY' 
        OR constraint_type = 'UNIQUE' )
ORDER BY ordinal_position ASC
ENDQ

    my $tables = $self->pg->db->query( $tables_q, $database, @table_names )->hashes;
    my %keys;
    for my $t ( @$tables ) {
        my $table = $t->{table_name};
        my @keys = @{ $self->pg->db->query( $key_q, $database, $table )->hashes };
        $keys{ $table } = \@keys;
        #; use Data::Dumper;
        #; say Dumper \@keys;
        if ( @keys && !grep { $_->{column_name} eq 'id' } @keys ) {
            $schema{ $table }{ 'x-id-field' } = $keys[0]{column_name};
        }
        if ( $IGNORE_TABLE{ $table } ) {
            $schema{ $table }{ 'x-ignore' } = 1;
        }
    }

    my $columns_q = <<ENDQ;
SELECT * FROM information_schema.columns
WHERE table_schema=?
ORDER BY ordinal_position ASC
ENDQ

    my @columns = @{ $self->pg->db->query( $columns_q, $database )->hashes };
    for my $c ( @columns ) {
        my $table = $c->{table_name};
        my $column = $c->{column_name};
        #; use Data::Dumper;
        #; say Dumper $c;
        my ( $key ) = grep { $_->{column_name} eq $column } @{ $keys{ $table } };
        $schema{ $table }{ properties }{ $column } = {
            $self->_map_type( $c, $key ),
            'x-order' => $c->{ordinal_position},
        };
        if ( $c->{is_nullable} eq 'NO' && !$c->{column_default} ) {
            push @{ $schema{ $table }{ required } }, $column;
        }
        # The `oid` field is also a primary key, and may be the main key
        # if no other key exists
        if ( $c->{data_type} eq 'oid' && $column ne 'id' ) {
            $schema{ $table }{ 'x-id-field' } ||= $column;
        }
    }

    return @table_names ? @schema{ @table_names } : \%schema;
}

sub _map_type {
    my ( $self, $column, $key ) = @_;
    my %conf;
    my $db_type = $column->{data_type};
    if ( $db_type =~ /^(?:character|text)/ ) {
        %conf = ( type => 'string' );
    }
    elsif ( $db_type =~ /^(?:bool)/ ) {
        %conf = ( type => 'boolean' );
    }
    elsif ( $db_type =~ /^(?:oid|integer|smallint|bigint)/ ) {
        %conf = ( type => 'integer' );
    }
    elsif ( $db_type =~ /^(?:double|float|money|numeric|real)/ ) {
        %conf = ( type => 'number' );
    }
    elsif ( $db_type =~ /^(?:timestamp)/ ) {
        %conf = ( type => 'string', format => 'date-time' );
    }
    elsif ( $db_type eq 'USER-DEFINED' ) {
        my $vals = $self->pg->db->query(
            sprintf 'SELECT unnest(enum_range(NULL::%s))::text', $column->{udt_name},
        );
        %conf = ( type => 'string', enum => [ $vals->arrays->flatten->each ] );
    }
    else {
        # Default to string
        %conf = ( type => 'string' );
    }

    if ( $column->{is_nullable} eq 'YES' && $db_type ne 'oid'
        && ( !$key || !$key->{constraint_type} || $key->{constraint_type} ne 'PRIMARY KEY' )
    ) {
        $conf{ type } = [ $conf{ type }, 'null' ];
    }

    return %conf;
}

1;
