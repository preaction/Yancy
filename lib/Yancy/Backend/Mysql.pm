package Yancy::Backend::Mysql;
our $VERSION = '1.017';
# ABSTRACT: A backend for MySQL using Mojo::mysql

=head1 SYNOPSIS

    ### URL string
    use Mojolicious::Lite;
    plugin Yancy => {
        backend => 'mysql:///mydb',
        read_schema => 1,
    };

    ### Mojo::mysql object
    use Mojolicious::Lite;
    use Mojo::mysql;
    plugin Yancy => {
        backend => { Mysql => Mojo::mysql->new( 'mysql:///mydb' ) },
        read_schema => 1,
    };

    ### Hash reference
    use Mojolicious::Lite;
    plugin Yancy => {
        backend => {
            Mysql => {
                dsn => 'dbi:mysql:dbname',
                username => 'fry',
                password => 'b3nd3r1sgr34t',
            },
        },
        read_schema => 1,
    };

=head1 DESCRIPTION

This Yancy backend allows you to connect to a MySQL database to manage
the data inside. This backend uses L<Mojo::mysql> to connect to MySQL.

See L<Yancy::Backend> for the methods this backend has and their return
values.

=head2 Backend URL

The URL for this backend takes the form C<<
mysql://<user>:<pass>@<host>:<port>/<db> >>.

Some examples:

    # Just a DB
    mysql:///mydb

    # User+DB (server on localhost:3306)
    mysql://user@/mydb

    # User+Pass Host and DB
    mysql://user:pass@example.com/mydb

=head2 Collections

The collections for this backend are the names of the tables in the
database.

So, if you have the following schema:

    CREATE TABLE people (
        id INTEGER AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        email VARCHAR(255) NOT NULL
    );
    CREATE TABLE business (
        id INTEGER AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        email VARCHAR(255) NULL
    );

You could map that schema to the following collections:

    {
        backend => 'mysql://user@/mydb',
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
C<read_schema>: Tables used by L<Mojo::mysql::Migrations>,
L<Mojo::mysql::PubSub>, L<DBIx::Class::Schema::Versioned> (in case we're
co-habitating with a DBIx::Class schema), and the
L<Minion::Backend::mysql> Minion backend.

=head1 SEE ALSO

L<Mojo::mysql>, L<Yancy>

=cut

use Mojo::Base '-base';
use Mojo::Promise;
use Scalar::Util qw( blessed looks_like_number );
BEGIN {
    eval { require Mojo::mysql; Mojo::mysql->VERSION( 1.05 ); 1 }
        or die "Could not load Mysql backend: Mojo::mysql version 1.05 or higher required\n";
}

our %IGNORE_TABLE = (
    mojo_migrations => 1,
    minion_jobs => 1,
    minion_workers => 1,
    minion_locks => 1,
    minion_workers_inbox => 1,
    minion_jobs_depends => 1,
    mojo_pubsub_subscribe => 1,
    mojo_pubsub_notify => 1,
    dbix_class_schema_versions => 1,
);

has mysql =>;
has collections =>;

sub new {
    my ( $class, $backend, $collections ) = @_;
    if ( !ref $backend ) {
        my ( $connect ) = $backend =~ m{^[^:]+://(.+)$};
        $backend = Mojo::mysql->new( "mysql://$connect" );
    }
    elsif ( !blessed $backend ) {
        $backend = Mojo::mysql->new( %$backend );
    }
    my %vars = (
        mysql => $backend,
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
    $self->_normalize( $coll, $params );
    my $id_field = $self->_id_field( $coll );
    my $id = $self->mysql->db->insert( $coll, $params )->last_insert_id;
    # Assume the id field is correct in case we're using a different
    # unique ID (not the auto-increment column).
    return $params->{ $id_field } || $id;
}

sub create_p {
    my ( $self, $coll, $params ) = @_;
    $self->_normalize( $coll, $params );
    my $id_field = $self->_id_field( $coll );
    return $self->mysql->db->insert_p( $coll, $params )
        ->then( sub { $params->{ $id_field } || shift->last_insert_id } );
}

sub get {
    my ( $self, $coll, $id ) = @_;
    my $id_field = $self->_id_field( $coll );
    return $self->mysql->db->select( $coll, undef, { $id_field => $id } )->hash;
}

sub get_p {
    my ( $self, $coll, $id ) = @_;
    my $id_field = $self->_id_field( $coll );
    my $db = $self->mysql->db;
    return $db->select_p( $coll, undef, { $id_field => $id } )
        ->then( sub { shift->hash } );
}

sub _list_sqls {
    my ( $self, $coll, $params, $opt ) = @_;
    my $mysql = $self->mysql;
    my ( $query, @params ) = $mysql->abstract->select( $coll, undef, $params, $opt->{order_by} );
    my ( $total_query, @total_params ) = $mysql->abstract->select( $coll, [ \'COUNT(*) as total' ], $params );
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
    my $mysql = $self->mysql;
    my ( $query, $total_query, @params ) = $self->_list_sqls( $coll, $params, $opt );
    return {
        items => $mysql->db->query( $query, @params )->hashes,
        total => $mysql->db->query( $total_query, @params )->hash->{total},
    };
}

sub list_p {
    my ( $self, $coll, $params, $opt ) = @_;
    $params ||= {}; $opt ||= {};
    my $mysql = $self->mysql;
    my ( $query, $total_query, @params ) = $self->_list_sqls( $coll, $params, $opt );
    my $items_p = $mysql->db->query_p( $query, @params )->then( sub { shift->hashes } );
    my $total_p = $mysql->db->query_p( $total_query, @params )
        ->then( sub { shift->hash->{total} } );
    return Mojo::Promise->all( $items_p, $total_p )
        ->then( sub {
            my ( $items, $total ) = @_;
            return { items => $items->[0], total => $total->[0] };
        } );
}

sub set {
    my ( $self, $coll, $id, $params ) = @_;
    $self->_normalize( $coll, $params );
    my $id_field = $self->_id_field( $coll );
    return !!$self->mysql->db->update( $coll, $params, { $id_field => $id } )->rows;
}

sub set_p {
    my ( $self, $coll, $id, $params ) = @_;
    $self->_normalize( $coll, $params );
    my $id_field = $self->_id_field( $coll );
    return $self->mysql->db->update_p( $coll, $params, { $id_field => $id } )
        ->then( sub { !!shift->rows } );
}

sub delete {
    my ( $self, $coll, $id ) = @_;
    my $id_field = $self->_id_field( $coll );
    return !!$self->mysql->db->delete( $coll, { $id_field => $id } )->rows;
}

sub delete_p {
    my ( $self, $coll, $id ) = @_;
    my $id_field = $self->_id_field( $coll );
    return $self->mysql->db->delete_p( $coll, { $id_field => $id } )
        ->then( sub { !!shift->rows } );
}

sub _normalize {
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

sub read_schema {
    my ( $self ) = @_;
    my $database = $self->mysql->db->query( 'SELECT DATABASE()' )->array->[0];

    my %schema;
    my $tables_q = <<ENDQ;
SELECT * FROM INFORMATION_SCHEMA.TABLES
WHERE table_schema=?
ENDQ

    my $key_q = <<ENDQ;
SELECT * FROM information_schema.table_constraints as tc
JOIN information_schema.key_column_usage AS ccu USING ( table_name, table_schema )
WHERE tc.table_schema=? AND tc.table_name=? AND ( constraint_type = 'PRIMARY KEY' OR constraint_type = 'UNIQUE' )
    AND tc.table_schema NOT IN ('information_schema','performance_schema','mysql','sys')
ENDQ

    my @tables = @{ $self->mysql->db->query( $tables_q, $database )->hashes };
    for my $t ( @tables ) {
        my $table = $t->{TABLE_NAME};
        # ; say "Got table $table";
        my @keys = @{ $self->mysql->db->query( $key_q, $database, $table )->hashes };
        # ; say "Got keys";
        # ; use Data::Dumper;
        # ; say Dumper \@keys;
        if ( @keys && $keys[0]{COLUMN_NAME} ne 'id' ) {
            $schema{ $table }{ 'x-id-field' } = $keys[0]{COLUMN_NAME};
        }
        if ( $IGNORE_TABLE{ $table } ) {
            $schema{ $table }{ 'x-ignore' } = 1;
        }
    }

    my $columns_q = <<ENDQ;
SELECT * FROM information_schema.columns
WHERE table_schema=?
ORDER BY ORDINAL_POSITION
ENDQ

    my @columns = @{ $self->mysql->db->query( $columns_q, $database )->hashes };
    for my $c ( @columns ) {
        my $table = $c->{TABLE_NAME};
        my $column = $c->{COLUMN_NAME};
        # ; use Data::Dumper;
        # ; say Dumper $c;
        $schema{ $table }{ properties }{ $column } = {
            $self->_map_type( $c ),
            'x-order' => $c->{ORDINAL_POSITION},
        };
        # Auto_increment columns are allowed to be null
        if ( $c->{IS_NULLABLE} eq 'NO' && !$c->{COLUMN_DEFAULT} && $c->{EXTRA} !~ /auto_increment/ ) {
            push @{ $schema{ $table }{ required } }, $column;
        }
    }

    return \%schema;
}

sub _map_type {
    my ( $self, $column ) = @_;
    my %conf;
    my $db_type = $column->{DATA_TYPE};
    if ( $db_type =~ /^(?:character|text|varchar)/i ) {
        %conf = ( type => 'string' );
    }
    elsif ( $column->{COLUMN_TYPE} =~ /^(?:tinyint\(1\))/i ) {
        %conf = ( type => 'boolean' );
    }
    elsif ( $db_type =~ /^(?:int|integer|smallint|bigint|tinyint)/i ) {
        %conf = ( type => 'integer' );
    }
    elsif ( $db_type =~ /^(?:double|float|money|numeric|real)/i ) {
        %conf = ( type => 'number' );
    }
    elsif ( $db_type =~ /^(?:timestamp|datetime)/i ) {
        %conf = ( type => 'string', format => 'date-time' );
    }
    elsif ( $db_type =~ /^(?:enum)/i ) {
        my @values = $column->{COLUMN_TYPE} =~ /'([^']+)'/g;
        %conf = ( type => 'string', enum => \@values );
    }
    else {
        # Default to string
        %conf = ( type => 'string' );
    }

    if ( $column->{IS_NULLABLE} eq 'YES' ) {
        $conf{ type } = [ $conf{ type }, 'null' ];
    }

    return %conf;
}

1;
