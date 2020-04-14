package Yancy::Backend::Sqlite;
our $VERSION = '1.053';
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
use Mojo::JSON qw( true false encode_json );
BEGIN {
    eval { require DBD::SQLite; DBD::SQLite->VERSION( 1.56 ); 1 }
        or die "Could not load SQLite backend: DBD::SQLite version 1.56 or higher required\n";
    eval { require Mojo::SQLite; Mojo::SQLite->VERSION( 3 ); 1 }
        or die "Could not load SQLite backend: Mojo::SQLite version 3 or higher required\n";
}

has schema =>;
sub collections {
    require Carp;
    Carp::carp( '"collections" method is now "schema"' );
    shift->schema( @_ );
}

has mojodb =>;
use constant mojodb_class => 'Mojo::SQLite';
use constant mojodb_prefix => 'sqlite';

use constant q_tables => q{SELECT sql FROM SQLITE_MASTER WHERE type='table' and name = ?};

sub dbcatalog { undef }
sub dbschema { undef }

sub create {
    my ( $self, $schema_name, $params ) = @_;
    $params = $self->normalize( $schema_name, $params );
    die "No refs allowed in '$schema_name': " . encode_json $params
        if grep ref && ref ne 'SCALAR', values %$params;
    my $id_field = $self->id_field( $schema_name );
    my $inserted_id = $self->mojodb->db->insert( $schema_name, $params )->last_insert_id;
    # SQLite does not have a 'returning' syntax. Assume id field is correct
    # if passed, created otherwise:
    return $params->{$id_field} || $inserted_id;
}

sub filter_table { return $_[1] !~ /^sqlite_/ }

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
    $self->mojodb->db->query( 'SELECT ' . $value )->array->[0];
}

sub column_info_extra {
    my ( $self, $table, $columns ) = @_;
    my $sql = $self->mojodb->db->query( q_tables, $table )->array->[0];
    # ; use Data::Dumper;
    # ; say Dumper $columns;
    my %col2info;
    for my $c ( @$columns ) {
        my $col_name = $c->{COLUMN_NAME};
        my %conf;
        $conf{auto_increment} = 1 if $sql =~ /${col_name}\s+[^,\)]+AUTOINCREMENT/i;
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
                %conf = ( %conf, type => 'string', enum => \@values );
            }
        }
        $col2info{ $col_name } = \%conf;
    }
    return \%col2info;
}

1;
