package Yancy::Backend::Pg;
our $VERSION = '0.009';
# ABSTRACT: A backend for Postgres using Mojo::Pg

=head1 SYNOPSIS

    # yancy.conf
    {
        backend => 'pg://user:pass@localhost/mydb',
        collections => {
            table_name => { ... },
        },
    }

    # Plugin
    use Mojolicious::Lite;
    plugin Yancy => {
        backend => 'pg://user:pass@localhost/mydb',
        collections => {
            table_name => { ... },
        },
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

=head1 SEE ALSO

L<Mojo::Pg>, L<Yancy>

=cut

use v5.24;
use Mojo::Base 'Mojo';
use experimental qw( signatures postderef );
use Scalar::Util qw( looks_like_number );
use Mojo::Pg 3.0;

has pg =>;
has collections =>;

sub new( $class, $url, $collections ) {
    my ( $connect ) = $url =~ m{^[^:]+://(.+)$};
    my %vars = (
        pg => Mojo::Pg->new( "postgresql://$connect" ),
        collections => $collections,
    );
    return $class->SUPER::new( %vars );
}

sub create( $self, $coll, $params ) {
    return $self->pg->db->insert( $coll, $params, { returning => '*' } )->hash;
}

sub get( $self, $coll, $id ) {
    my $id_field = $self->collections->{ $coll }{ 'x-id-field' } || 'id';
    return $self->pg->db->select( $coll, undef, { $id_field => $id } )->hash;
}

sub list( $self, $coll, $params={}, $opt={} ) {
    my $pg = $self->pg;
    my ( $query, @params ) = $pg->abstract->select( $coll, undef, $params, $opt->{order_by} );
    my ( $total_query, @total_params ) = $pg->abstract->select( $coll, [ \'COUNT(*) as total' ], $params );
    if ( scalar grep defined, $opt->@{qw( limit offset )} ) {
        die "Limit must be number" if $opt->{limit} && !looks_like_number $opt->{limit};
        $query .= ' LIMIT ' . ( $opt->{limit} // 2**32 );
        if ( $opt->{offset} ) {
            die "Offset must be number" if !looks_like_number $opt->{offset};
            $query .= ' OFFSET ' . $opt->{offset};
        }
    }
    #; say $query;
    return {
        rows => $pg->db->query( $query, @params )->hashes,
        total => $pg->db->query( $total_query, @total_params )->hash->{total},
    };

}

sub set( $self, $coll, $id, $params ) {
    my $id_field = $self->collections->{ $coll }{ 'x-id-field' } || 'id';
    return $self->pg->db->update( $coll, $params, { $id_field => $id } );
}

sub delete( $self, $coll, $id ) {
    my $id_field = $self->collections->{ $coll }{ 'x-id-field' } || 'id';
    return $self->pg->db->delete( $coll, { $id_field => $id } );
}

1;
