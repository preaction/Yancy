package Yancy::Backend::Sqlite;
our $VERSION = '1.088';
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

=head2 Schema Names

The schema names for this backend are the names of the tables in the
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

You could map that to the following schema:

    {
        backend => 'sqlite:filename.db',
        schema => {
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

use Mojo::Base 'Yancy::Backend::MojoDB';
use Text::Balanced qw( extract_bracketed );
use Scalar::Util qw( blessed );
BEGIN {
    eval { require DBD::SQLite; DBD::SQLite->VERSION( 1.56 ); 1 }
        or die "Could not load SQLite backend: DBD::SQLite version 1.56 or higher required\n";
    eval { require Mojo::SQLite; Mojo::SQLite->VERSION( 3.005 ); 1 }
        or die "Could not load SQLite backend: Mojo::SQLite version 3.005 or higher required\n";
}

sub new {
    my ( $class, $driver, $schema ) = @_;
    if ( blessed $driver ) {
        die "Need a Mojo::SQLite object. Got " . blessed( $driver )
            if !$driver->isa( 'Mojo::SQLite' );
        return $class->SUPER::new( $driver, $schema );
    }
    elsif ( ref $driver eq 'HASH' ) {
        my $sqlite = Mojo::SQLite->new;
        for my $method ( keys %$driver ) {
            $sqlite->$method( $driver->{ $method } );
        }
        return $class->SUPER::new( $sqlite, $schema );
    }
    my $found = (my $connect = $driver) =~ s{^.*?:}{};
    return $class->SUPER::new(
        Mojo::SQLite->new( $found ? "sqlite:$connect" : () ),
        $schema,
    );
}

sub ignore_table {
    my ( $self, $table ) = @_;
    return +( $table =~ /^sqlite_/ ) || $self->SUPER::ignore_table( $table );
}

my %DEFAULT2FIXUP = (
    NULL => undef,
    TRUE => 1,
    FALSE => 0,
    CURRENT_TIME => 'now',
    CURRENT_DATE => 'now',
    CURRENT_TIMESTAMP => 'now',
);
sub fixup_default {
    my ( $self, $value ) = @_;
    return undef if !defined $value;
    return $DEFAULT2FIXUP{ $value } if exists $DEFAULT2FIXUP{ $value };
    $self->driver->db->query( 'SELECT ' . $value )->array->[0];
}

sub table_info {
    my ( $self ) = @_;
    my $dbh = $self->dbh;
    my $tables = $dbh->table_info( undef, undef, '%', undef )->fetchall_arrayref({});
    return [ grep { $_->{TABLE_NAME} !~ /^sqlite_/ } @$tables ];
}

sub column_info {
    my ( $self, $table ) = @_;
    my $row = $self->driver->db->query(
        q{SELECT sql FROM SQLITE_MASTER WHERE type='table' and name = ?},
        $table->{TABLE_NAME},
    )->array || return [];
    my $sql = $row->[0];
    my $columns = $self->dbh->column_info( @{$table}{qw( TABLE_CAT TABLE_SCHEM TABLE_NAME )}, '%' )->fetchall_arrayref({});
    # ; use Data::Dumper;
    # ; say Dumper $columns;
    for my $c ( @$columns ) {
        my $col_name = $c->{COLUMN_NAME};
        $c->{AUTO_INCREMENT} = 1 if $sql =~ /${col_name}\s+[^,\)]+AUTOINCREMENT/i;
        if ( $sql =~ /${col_name}[^,\)]+CHECK\s*(.+)\)\s*$/si ) {
            # Column has a check constraint, see if it's an enum-like
            my $check = $1;
            my ( $constraint, $remainder ) = extract_bracketed( $check, '(' );
            if ( $constraint =~ /${col_name}\s+in\s*\([^)]+\)/i ) {
                $constraint = substr $constraint, 1, -1;
                $constraint =~ s/\s*${col_name}\s+in\s+//i;
                $constraint =~ s/\s*$//;
                my @values = split ',', substr $constraint, 1, -1;
                s/^\s*'|'\s*$//g for @values;
                $c->{ENUM} = \@values;
            }
        }
        $c->{COLUMN_DEF} = $self->fixup_default( $c->{COLUMN_DEF} );
    }
    return $columns;
}

1;
