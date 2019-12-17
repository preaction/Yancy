package Yancy::Backend::Mysql;
our $VERSION = '1.046';
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

=head2 Schema Names

The schema names for this backend are the names of the tables in the
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

You could map that to the following schema:

    {
        backend => 'mysql://user@/mydb',
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
C<read_schema>: Tables used by L<Mojo::mysql::Migrations>,
L<Mojo::mysql::PubSub>, L<DBIx::Class::Schema::Versioned> (in case we're
co-habitating with a DBIx::Class schema), and the
L<Minion::Backend::mysql> Minion backend.

=head1 SEE ALSO

L<Mojo::mysql>, L<Yancy>

=cut

use Mojo::Base '-base';
use Mojo::JSON qw( encode_json );
use Role::Tiny qw( with );
with qw( Yancy::Backend::Role::Relational Yancy::Backend::Role::MojoAsync );
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

has schema =>;
sub collections {
    require Carp;
    Carp::carp( '"collections" method is now "schema"' );
    shift->schema( @_ );
}

has mojodb =>;
use constant mojodb_class => 'Mojo::mysql';
use constant mojodb_prefix => 'mysql';

sub dbcatalog { undef }
sub dbschema {
    my ( $self ) = @_;
    $self->mojodb->db->query( 'SELECT database()' )->array->[0];
}
sub filter_table { 1 }

sub fixup_default {
    my ( $self, $value ) = @_;
    return undef if !defined $value;
    $value;
}

sub create {
    my ( $self, $coll, $params ) = @_;
    $params = $self->normalize( $coll, $params );
    die "No refs allowed in '$coll': " . encode_json $params
        if grep ref, values %$params;
    my $id_field = $self->id_field( $coll );
    my $id = $self->mojodb->db->insert( $coll, $params )->last_insert_id;
    # Assume the id field is correct in case we're using a different
    # unique ID (not the auto-increment column).
    return $params->{ $id_field } || $id;
}

sub create_p {
    my ( $self, $coll, $params ) = @_;
    $params = $self->normalize( $coll, $params );
    my $id_field = $self->id_field( $coll );
    return $self->mojodb->db->insert_p( $coll, $params )
        ->then( sub { $params->{ $id_field } || shift->last_insert_id } );
}

sub column_info_extra {
    my ( $self, $table, $columns ) = @_;
    my %col2info;
    for my $c ( @$columns ) {
        my $col_name = $c->{COLUMN_NAME};
        $col2info{ $col_name }{enum} = $c->{mysql_values}
            if $c->{mysql_values};
        $col2info{ $col_name }{auto_increment} = 1
            if $c->{mysql_is_auto_increment};
    }
    \%col2info;
}

1;
