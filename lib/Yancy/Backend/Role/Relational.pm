package Yancy::Backend::Role::Relational;
our $VERSION = '1.024';
# ABSTRACT: A role to give a relational backend relational capabilities

=head1 SYNOPSIS

    package Yancy::Backend::RDBMS;
    with 'Yancy::Backend::Role::Relational';

=head1 DESCRIPTION

This role implements utility methods to make backend classes work with
entity relations, using L<DBI> methods such as
C<DBI/foreign_key_info>.

=head1 REQUIRED METHODS

The composing class must implement the following:

=head2 mojodb

The value must be a relative of L<Mojo::Pg> et al.

=head2 mojodb_class

String naming the C<Mojo::*> class.

=head2 mojodb_prefix

String with the value at the start of a L<DBI> C<dsn>.

=head2 filter_table

Called with a table name, returns a boolean of true to keep, false
to discard - typically for a system table.

=head2 column_info_extra

Called with a table-name, and the array-ref returned by
L<DBI/column_info>, returns a hash-ref mapping column names to an "extra
info" hash for that column, with possible keys:

=over

=item auto_increment

a boolean

=item enum

an array-ref of allowed values

=back

=head2 dbcatalog

Returns the L<DBI> "catalog" argument for e.g. L<DBI/column_info>.

=head2 dbschema

Returns the L<DBI> "schema" argument for e.g. L<DBI/column_info>.

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

=head2 get

Self-explanatory, implements L<Yancy::Backend/get>.

=head2 list

Self-explanatory, implements L<Yancy::Backend/list>.

=head2 read_schema

Self-explanatory, implements L<Yancy::Backend/read_schema>.

=head1 SEE ALSO

L<Yancy::Backend>

=cut

use Mojo::Base '-role';
use Scalar::Util qw( blessed looks_like_number );
use Mojo::JSON qw( true );

use DBI ':sql_types';
# only specify non-string - code-ref called with column_info row
my $maybe_boolean = sub {
    # how mysql does BOOLEAN - not a TINYINT, but INTEGER
    my ( $c ) = @_;
    ( ( $c->{mysql_type_name} // '' ) eq 'tinyint(1)' )
        ? { type => 'boolean' }
        : { type => 'integer' };
};
my %SQL2OAPITYPE = (
    SQL_BIGINT() => { type => 'integer' },
    SQL_BIT() => { type => 'boolean' },
    SQL_TINYINT() => $maybe_boolean,
    SQL_NUMERIC() => { type => 'number' },
    SQL_DECIMAL() => { type => 'number' },
    SQL_INTEGER() => $maybe_boolean,
    SQL_SMALLINT() => { type => 'integer' },
    SQL_FLOAT() => { type => 'number' },
    SQL_REAL() => { type => 'number' },
    SQL_DOUBLE() => { type => 'number' },
    SQL_DATETIME() => { type => 'string', format => 'date-time' },
    SQL_DATE() => { type => 'string', format => 'date' },
    SQL_TIME() => { type => 'string', format => 'date-time' },
    SQL_TIMESTAMP() => { type => 'string', format => 'date-time' },
    SQL_BOOLEAN() => { type => 'boolean' },
    SQL_TYPE_DATE() => { type => 'string', format => 'date' },
    SQL_TYPE_TIME() => { type => 'string', format => 'date-time' },
    SQL_TYPE_TIMESTAMP() => { type => 'string', format => 'date-time' },
    SQL_TYPE_TIME_WITH_TIMEZONE() => { type => 'string', format => 'date-time' },
    SQL_TYPE_TIMESTAMP_WITH_TIMEZONE() => { type => 'string', format => 'date-time' },
    SQL_LONGVARBINARY() => { type => 'string', format => 'binary' },
    SQL_VARBINARY() => { type => 'string', format => 'binary' },
    SQL_BINARY() => { type => 'string', format => 'binary' },
    SQL_BLOB() => { type => 'string', format => 'binary' },
);
# SQLite fallback
my %SQL2TYPENAME = (
    SQL_BOOLEAN() => [ qw(boolean) ],
    SQL_INTEGER() => [ qw(int integer smallint bigint tinyint rowid) ],
    SQL_REAL() => [ qw(double float money numeric real) ],
    SQL_TYPE_TIMESTAMP() => [ qw(timestamp datetime) ],
    SQL_BLOB() => [ qw(blob) ],
);
my %TYPENAME2SQL = map {
    my $sql = $_;
    map { $_ => $sql } @{ $SQL2TYPENAME{ $sql } };
} keys %SQL2TYPENAME;
my %IGNORE_TABLE = (
    mojo_migrations => 1,
    minion_jobs => 1,
    minion_workers => 1,
    minion_locks => 1,
    mojo_pubsub_listener => 1,
    mojo_pubsub_listen => 1,
    mojo_pubsub_notify => 1,
    mojo_pubsub_queue => 1,
    dbix_class_schema_versions => 1,
);

requires qw(
    mojodb mojodb_class mojodb_prefix
    dbcatalog dbschema
    filter_table column_info_extra
);

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
    return undef if !$data;
    my $schema = $self->collections->{ $coll }{ properties };
    my %replace;
    for my $key ( keys %$data ) {
        next if !defined $data->{ $key }; # leave nulls alone
        my $type = $schema->{ $key }{ type };
        next if !_is_type( $type, 'boolean' );
        # Boolean: true (1, "true"), false (0, "false")
        $replace{ $key }
            = $data->{ $key } && $data->{ $key } !~ /^false$/i
            ? 1 : 0;
    }
    +{ %$data, %replace };
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
    $params = $self->normalize( $coll, $params );
    my $id_field = $self->id_field( $coll );
    return !!$self->mojodb->db->update( $coll, $params, { $id_field => $id } )->rows;
}

sub get {
    my ( $self, $coll, $id ) = @_;
    my $id_field = $self->id_field( $coll );
    my $ret = $self->mojodb->db->select( $coll, undef, { $id_field => $id } )->hash;
    return $self->normalize( $coll, $ret );
}

sub list {
    my ( $self, $coll, $params, $opt ) = @_;
    $params ||= {}; $opt ||= {};
    my $mojodb = $self->mojodb;
    my ( $query, $total_query, @params ) = $self->list_sqls( $coll, $params, $opt );
    my $items = $mojodb->db->query( $query, @params )->hashes;
    return {
        items => [ map $self->normalize( $coll, $_ ), @$items ],
        total => $mojodb->db->query( $total_query, @params )->hash->{total},
    };
}

sub read_schema {
    my ( $self, @table_names ) = @_;
    my %schema;
    my $db = $self->mojodb->db;
    my $given_tables = @table_names;
    my ( $dbcatalog, $dbschema ) = ( scalar $self->dbcatalog, scalar $self->dbschema );
    @table_names = grep $self->filter_table($_), map $_->{TABLE_NAME}, @{ $db->dbh->table_info(
        $dbcatalog, $dbschema, undef, 'TABLE'
    )->fetchall_arrayref( { TABLE_NAME => 1 } ) } if !@table_names;
    s/\W//g for @table_names; # PostgreSQL quotes "user"
    for my $table ( @table_names ) {
        # ; say "Got table $table";
        $schema{ $table }{type} = 'object';
        my $stats_info = $db->dbh->statistics_info(
            $dbcatalog, $dbschema, $table, 1, 1
        )->fetchall_arrayref( { COLUMN_NAME => 1 } );
        my $columns = $db->dbh->column_info( $dbcatalog, $dbschema, $table, undef )->fetchall_arrayref( {} );
        my %is_pk = map {$_=>1} $db->dbh->primary_key( $dbcatalog, $dbschema, $table );
        my @unique_columns = grep !$is_pk{ $_ }, map $_->{COLUMN_NAME}, @$stats_info;
        my $col2info = $self->column_info_extra( $table, $columns );
        # ; say "Got columns";
        # ; use Data::Dumper;
        # ; say Dumper $columns;
        for my $c ( @$columns ) {
            my $column = $c->{COLUMN_NAME};
            my %info = %{ $col2info->{ $column } || {} };
            # the || is because SQLite doesn't give the DATA_TYPE
            my $sqltype = $c->{DATA_TYPE} || $TYPENAME2SQL{ lc $c->{TYPE_NAME} };
            my $typeref = $SQL2OAPITYPE{ $sqltype || '' } || { type => 'string' };
            $typeref = $typeref->( $c ) if ref $typeref eq 'CODE';
            my %oapitype = %$typeref;
            if ( !$is_pk{ $column } && $c->{NULLABLE} ) {
                $oapitype{ type } = [ $oapitype{ type }, 'null' ];
            }
            my $auto_increment = delete $info{auto_increment};
            $oapitype{readOnly} = true if $auto_increment;
            $schema{ $table }{ properties }{ $column } = {
                %info,
                %oapitype,
                'x-order' => $c->{ORDINAL_POSITION},
            };
            if ( ( !$c->{NULLABLE} || $is_pk{ $column } ) && !$auto_increment && !defined $c->{COLUMN_DEF} ) {
                push @{ $schema{ $table }{ required } }, $column;
            }
        }
        my ( $pk ) = keys %is_pk;
        if ( @unique_columns == 1 and $unique_columns[0] ne 'id' ) {
            # favour "natural" key over "surrogate" integer one, if exists
            $schema{ $table }{ 'x-id-field' } = $unique_columns[0];
        }
        elsif ( $pk && $pk ne 'id' ) {
            $schema{ $table }{ 'x-id-field' } = $pk;
        }
        if ( $IGNORE_TABLE{ $table } ) {
            $schema{ $table }{ 'x-ignore' } = 1;
        }
    }
    return $given_tables ? @schema{ @table_names } : \%schema;
}

1;
