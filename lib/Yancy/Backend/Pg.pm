package Yancy::Backend::Pg;
our $VERSION = '1.026';
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
    pg://user:pass@example.com/mydb

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
use Mojo::JSON qw( encode_json );
use Role::Tiny qw( with );
with qw( Yancy::Backend::Role::Relational Yancy::Backend::Role::MojoAsync );
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

has collections =>;
has mojodb =>;
use constant mojodb_class => 'Mojo::Pg';
use constant mojodb_prefix => 'postgresql';

sub dbcatalog { undef }
sub dbschema {
    my ( $self ) = @_;
    $self->mojodb->db->query( 'SELECT current_schema()' )->array->[0];
}
sub filter_table { 1 }

sub fixup_default {
    my ( $self, $value ) = @_;
    return undef if !defined $value or $value =~ /^nextval/i or $value eq 'NULL';
    $self->mojodb->db->query( 'SELECT ' . $value )->array->[0];
}

sub create {
    my ( $self, $coll, $params ) = @_;
    $params = $self->normalize( $coll, $params );
    die "No refs allowed in '$coll': " . encode_json $params
        if grep ref, values %$params;
    my $id_field = $self->id_field( $coll );
    return $self->mojodb->db->insert( $coll, $params, { returning => $id_field } )->hash->{ $id_field };
}

sub create_p {
    my ( $self, $coll, $params ) = @_;
    $params = $self->normalize( $coll, $params );
    my $id_field = $self->id_field( $coll );
    return $self->mojodb->db->insert_p( $coll, $params, { returning => $id_field } )
        ->then( sub { shift->hash->{ $id_field } } );
}

sub column_info_extra {
    my ( $self, $table, $columns ) = @_;
    my %col2info;
    for my $c ( @$columns ) {
        my $col_name = $c->{COLUMN_NAME};
        $col2info{ $col_name }{enum} = $c->{pg_enum_values}
            if $c->{pg_enum_values};
        $col2info{ $col_name }{auto_increment} = 1
            if $c->{COLUMN_DEF} and $c->{COLUMN_DEF} =~ /nextval/i;
    }
    \%col2info;
}

1;
