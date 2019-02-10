package Yancy::Backend::Sqlite;
our $VERSION = '1.023';
# ABSTRACT: A backend for SQLite using Mojo::SQLite

=head1 SYNOPSIS

    ### URL string
    use Mojolicious::Lite;
    plugin Yancy => {
        backend => 'sqlite:data.db',
        read_schema => 1,
    };

    ### Mojo::SQLite object
    use Mojolicious::Lite;
    use Mojo::SQLite;
    plugin Yancy => {
        backend => { Sqlite => Mojo::SQLite->new( 'sqlite:data.db' ) },
        read_schema => 1,
    };

    ### Hashref
    use Mojolicious::Lite;
    plugin Yancy => {
        backend => {
            Sqlite => {
                dsn => 'sqlite:data.db',
            },
        },
        read_schema => 1,
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
        id INTEGER PRIMARY KEY,
        name VARCHAR NOT NULL,
        email VARCHAR NOT NULL
    );
    CREATE TABLE business (
        id INTEGER PRIMARY KEY,
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

=head2 Ignored Tables

By default, this backend will ignore some tables when using
C<read_schema>: Tables used by L<Mojo::SQLite::Migrations>,
L<Mojo::SQLite::PubSub>, L<DBIx::Class::Schema::Versioned> (in case
we're co-habitating with a DBIx::Class schema), and all the tables used
by the L<Minion::Backend::SQLite> Minion backend.

=head1 SEE ALSO

L<Mojo::SQLite>, L<Yancy>

=cut

use Mojo::Base '-base';
use Role::Tiny qw( with );
with qw( Yancy::Backend::Role::Sync Yancy::Backend::Role::Relational );
use Text::Balanced qw( extract_bracketed );
BEGIN {
    eval { require Mojo::SQLite; Mojo::SQLite->VERSION( 3 ); 1 }
        or die "Could not load SQLite backend: Mojo::SQLite version 3 or higher required\n";
}

our %IGNORE_TABLE = (
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

has collections =>;
has mojodb =>;
use constant mojodb_class => 'Mojo::SQLite';
use constant mojodb_prefix => 'sqlite';

use constant q_tables => q{SELECT * FROM SQLITE_MASTER WHERE type='table'};
use constant q_column => q{PRAGMA table_info(%s)};

sub create {
    my ( $self, $coll, $params ) = @_;
    $params = $self->normalize( $coll, $params );
    my $id_field = $self->id_field( $coll );
    my $inserted_id = $self->mojodb->db->insert( $coll, $params )->last_insert_id;
    # SQLite does not have a 'returning' syntax. Assume id field is correct
    # if passed, created otherwise:
    return $params->{$id_field} || $inserted_id;
}

sub read_schema {
    my ( $self, @table_names ) = @_;
    my %schema;

    my $tables_q = q_tables;

    if ( @table_names ) {
        $tables_q .= sprintf ' AND name IN ( %s )', join ', ', ('?') x @table_names;
    }
    else {
        $tables_q .= q{ AND name NOT LIKE 'sqlite_%'};
    }

    my $tables = $self->mojodb->db->query( $tables_q, @table_names )->hashes;
    for my $t ( @$tables ) {
        my $table = $t->{name};
        # ; say "Got table $table";
        my @columns = @{ $self->mojodb->db->query( sprintf q_column, $table )->hashes };
        # ; say "Got columns";
        # ; use Data::Dumper;
        # ; say Dumper \@columns;
        my @unique_columns;
        for my $c ( @columns ) {
            my $column = $c->{name};
            # We are parsing SQL here, but not well. We may need to
            # actually parse the SQL here soon so we can divide this all
            # up into attributes
            my $is_auto = !!( $t->{sql} =~ /${column}[^,\)]+AUTOINCREMENT/i );
            my $is_unique = !!( $t->{sql} =~ /${column}[^,]+UNIQUE/i );
            if ( $is_unique ) {
                push @unique_columns, $column;
            }
            $schema{ $table }{ properties }{ $column } = {
                $self->_map_type( $c, $t ),
                'x-order' => $c->{cid}+1,
            };
            if ( ( $c->{notnull} || $c->{pk} ) && !$is_auto && !$c->{dflt_value} ) {
                push @{ $schema{ $table }{ required } }, $column;
            }
            if ( $c->{pk} == 1 && $column ne 'id' ) {
            }
        }

        my ( $pk ) = grep { $_->{pk} } @columns;
        if ( $pk && $pk->{name} ne 'id' ) {
            $schema{ $table }{ 'x-id-field' } = $pk->{name};
        }
        elsif ( !$pk && @unique_columns ) {
            $schema{ $table }{ 'x-id-field' } = $unique_columns[0];
        }

        if ( $IGNORE_TABLE{ $table } ) {
            $schema{ $table }{ 'x-ignore' } = 1;
        }
    }

    return @table_names ? @schema{ @table_names } : \%schema;
}

sub _map_type {
    my ( $self, $column, $table ) = @_;
    my %conf;
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
            %conf = ( type => 'string', enum => \@values );
        }
    }

    if ( !$conf{ type } ) {
        if ( $db_type =~ /^(?:text|varchar)/i ) {
            %conf = ( type => 'string' );
        }
        elsif ( $db_type =~ /^(?:boolean)/i ) {
            %conf = ( type => 'boolean' );
        }
        elsif ( $db_type =~ /^(?:int|integer|smallint|bigint|tinyint|rowid)/i ) {
            %conf = ( type => 'integer' );
        }
        elsif ( $db_type =~ /^(?:double|float|money|numeric|real)/i ) {
            %conf = ( type => 'number' );
        }
        elsif ( $db_type =~ /^(?:timestamp|datetime)/i ) {
            %conf = ( type => 'string', format => 'date-time' );
        }
        else {
            # Default to string
            %conf = ( type => 'string' );
        }
    }

    if ( !$column->{pk} && !$column->{notnull} ) {
        $conf{ type } = [ $conf{ type }, 'null' ];
    }

    return %conf;
}

1;
