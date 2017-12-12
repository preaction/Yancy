package Yancy::Backend::Mysql;
our $VERSION = '0.006';
# ABSTRACT: A backend for MySQL using Mojo::mysql

=head1 SYNOPSIS

    # yancy.conf
    {
        backend => 'mysql://user:pass@localhost/mydb',
        collections => {
            table_name => { ... },
        },
    }

    # Plugin
    use Mojolicious::Lite;
    plugin Yancy => {
        backend => 'mysql://user:pass@localhost/mydb',
        collections => {
            table_name => { ... },
        },
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

=head1 SEE ALSO

L<Mojo::mysql>, L<Yancy>

=cut

use v5.24;
use Mojo::Base 'Mojo';
use experimental qw( signatures postderef );
use Scalar::Util qw( looks_like_number );
use Mojo::mysql 1.0;

has mysql =>;
has collections =>;

sub new( $class, $url, $collections ) {
    my ( $connect ) = $url =~ m{^[^:]+://(.+)$};
    my %vars = (
        mysql => Mojo::mysql->new( "mysql://$connect" ),
        collections => $collections,
    );
    return $class->SUPER::new( %vars );
}

sub create( $self, $coll, $params ) {
    my $id_field = $self->collections->{ $coll }{ 'x-id-field' } || 'id';
    my $id = $self->mysql->db->insert( $coll, $params )->last_insert_id;
    return $self->get( $coll, $params->{ $id_field } || $id );
}

sub get( $self, $coll, $id ) {
    my $id_field = $self->collections->{ $coll }{ 'x-id-field' } || 'id';
    return $self->mysql->db->select( $coll, undef, { $id_field => $id } )->hash;
}

sub list( $self, $coll, $params={}, $opt={} ) {
    my $mysql = $self->mysql;
    my ( $query, @params ) = $mysql->abstract->select( $coll, undef, $params, $opt->{order_by} );
    my ( $total_query, @total_params ) = $mysql->abstract->select( $coll, [ \'COUNT(*) as total' ], $params );
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
        rows => $mysql->db->query( $query, @params )->hashes,
        total => $mysql->db->query( $total_query, @total_params )->hash->{total},
    };
}

sub set( $self, $coll, $id, $params ) {
    my $id_field = $self->collections->{ $coll }{ 'x-id-field' } || 'id';
    return $self->mysql->db->update( $coll, $params, { $id_field => $id } );
}

sub delete( $self, $coll, $id ) {
    my $id_field = $self->collections->{ $coll }{ 'x-id-field' } || 'id';
    return $self->mysql->db->delete( $coll, { $id_field => $id } );
}

1;
