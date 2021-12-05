package Yancy::Backend::Role::DBI;
our $VERSION = '1.086';
# ABSTRACT: Role for backends that use DBI

=head1 SYNOPSIS

    package Yancy::Backend::RDBMS;
    use Role::Tiny 'with';
    with 'Yancy::Backend::Role::DBI';
    # Return a database handle
    sub dbh { ... } 

=head1 DESCRIPTION

This is a role that adds the below methods based on a C<dbh> method
that returns a L<DBI> object and a C<table_info> method that calls
L<DBI/table_info> with the correct arguments for the current database.

=head1 SEE ALSO

L<Yancy::Backend>

=cut

use Mojo::Base '-role';
use List::Util qw( any );
use DBI ':sql_types';
use Mojo::JSON qw( true );

requires 'dbh', 'table_info';

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
    SQL_VARCHAR() => sub {
        my ( $c ) = @_;
        # MySQL uses this type for BLOBs, too...
        return { type => 'string', format => 'binary' }
            if ( $c->{mysql_type_name} // '' ) =~ /blob/i;
        return { type => 'string' };
    },
);
# SQLite fallback
my %SQL2TYPENAME = (
    SQL_BOOLEAN() => [ qw(boolean) ],
    SQL_INTEGER() => [ qw(int integer smallint bigint tinyint rowid) ],
    SQL_REAL() => [ qw(double float money numeric real) ],
    SQL_TYPE_TIMESTAMP() => [ qw(timestamp datetime) ],
    SQL_BLOB() => [ qw(blob longblob mediumblob tinyblob) ],
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

sub fixup_default {
}

sub column_info {
    my ( $self, $table ) = @_;
    return $self->dbh->column_info( @{$table}{qw( TABLE_CAT TABLE_SCHEM TABLE_NAME )}, '%' )->fetchall_arrayref({});
}

sub read_schema {
    my ( $self, @table_names ) = @_;
    my %schema;
    my $dbh = $self->dbh;
    my @tables = @{ $self->table_info };
    $_->{TABLE_NAME} =~ s/\W//g for @tables;
    my %tables = map { $_->{TABLE_NAME} => $_ } @tables;
    my $given_tables = !!@table_names;
    @table_names = keys %tables if !@table_names;

    for my $table_name ( @table_names ) {
        my $table = $tables{ $table_name };
        my @table_id = @{$table}{qw( TABLE_CAT TABLE_SCHEM TABLE_NAME )};
        # ; say "Got table $table_name";
        $schema{ $table_name }{type} = 'object';
        my $stats_info = $dbh->statistics_info( @table_id, 1, 1 )->fetchall_arrayref( {} );
        my $columns = $self->column_info( $table );
        my %is_pk = map {$_=>1} $dbh->primary_key( @table_id );
        # ; use Data::Dumper;
        # ; say Dumper $stats_info;
        # ; say Dumper \%is_pk;
        my @unique_columns = grep !$is_pk{ $_ },
            map $_->{COLUMN_NAME},
            grep !$_->{NON_UNIQUE}, # mysql
            @$stats_info;
        # ; say "Got columns";
        # ; use Data::Dumper;
        # ; say Dumper $columns;
        for my $c ( @$columns ) {
            # COLUMN_NAME DATA_TYPE TYPE_NAME IS_NULLABLE AUTO_INCREMENT
            # COLUMN_DEF ORDINAL_POSITION ENUM
            my $column = $c->{COLUMN_NAME} =~ s/['"`]//gr;
            # the || is because SQLite doesn't give the DATA_TYPE
            my $sqltype = $c->{DATA_TYPE} || $TYPENAME2SQL{ lc $c->{TYPE_NAME} };
            my $typeref = $SQL2OAPITYPE{ $sqltype || '' } || { type => 'string' };
            $typeref = $typeref->( $c ) if ref $typeref eq 'CODE';
            my %oapitype = %$typeref;
            if ( !$is_pk{ $column } && $c->{NULLABLE} ) {
                $oapitype{ type } = [ $oapitype{ type }, 'null' ];
            }
            my $auto_increment = $c->{AUTO_INCREMENT};
            my $default = $c->{COLUMN_DEF};
            if ( defined $default ) {
                $oapitype{ default } = $default;
            }
            $oapitype{readOnly} = true if $auto_increment;
            $schema{ $table_name }{ properties }{ $column } = {
                %oapitype,
                'x-order' => $c->{ORDINAL_POSITION},
                ( enum => $c->{ENUM} )x!!$c->{ENUM},
            };
            if ( ( $c->{IS_NULLABLE} eq 'NO' || $is_pk{ $column } ) && !$auto_increment && !defined $default ) {
                push @{ $schema{ $table_name }{ required } }, $column;
            }
        }
        # ; say "Got PKs for table $table_name: " . join ', ', keys %is_pk;
        # ; say "Got uniques for table $table_name: " . join ', ', @unique_columns;
        my ( $pk ) = keys %is_pk;
        if ( @unique_columns == 1 and $unique_columns[0] ne 'id' ) {
            # favour "natural" key over "surrogate" integer one, if exists
            $schema{ $table_name }{ 'x-id-field' } = $unique_columns[0];
        }
        elsif ( $pk && $pk ne 'id' ) {
            $schema{ $table_name }{ 'x-id-field' } = $pk;
        }
        if ( $IGNORE_TABLE{ $table_name } ) {
            $schema{ $table_name }{ 'x-ignore' } = 1;
        }
    }

    # Foreign keys
    for my $table_name ( @table_names ) {
        my $table = $tables{ $table_name };
        my @table_id = @{$table}{qw( TABLE_CAT TABLE_SCHEM TABLE_NAME )};
        my @foreign_keys;
        if ( my $sth = $dbh->foreign_key_info( (undef)x3, @table_id ) ) {
            @foreign_keys = @{ $sth->fetchall_arrayref( {} ) };
        }

        for my $fk ( @foreign_keys ) {
            next unless $fk->{PKTABLE_NAME} || $fk->{UK_TABLE_NAME}; # ??? MySQL adds these?
            # ; use Data::Dumper;
            # ; say Dumper $fk;
            s/\W//g for grep defined, values %$fk; # PostgreSQL quotes "user"
            my $foreign_table = $fk->{PKTABLE_NAME} || $fk->{UK_TABLE_NAME};
            my $foreign_column = $fk->{PKCOLUMN_NAME} || $fk->{UK_COLUMN_NAME};
            next unless $schema{ $foreign_table }; # XXX Can't resolve a foreign key we can't find
            my $foreign_id = $schema{ $foreign_table }{ 'x-id-field' } // 'id';
            my $column = $fk->{FKCOLUMN_NAME} || $fk->{UK_COLUMN_NAME};
            # XXX: We cannot do relationships with multiple keys yet
            $schema{ $table_name }{ properties }{ $column }{ 'x-foreign-key' } = join '.', $foreign_table, $foreign_id;
        }
    }

    return $given_tables ? @schema{ @table_names } : \%schema;
}

1;
