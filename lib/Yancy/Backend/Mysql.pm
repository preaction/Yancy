package Yancy::Backend::Mysql;
our $VERSION = '0.001';
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
                    id => { type => 'integer' },
                    name => { type => 'string' },
                    email => { type => 'string' },
                },
            },
            Business => {
                required => [ 'name' ],
                properties => {
                    id => { type => 'integer' },
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
use Mojo::mysql 1.0;

has mysql =>;
has schema =>;

sub new( $class, $url, $schema ) {
    my ( $connect ) = $url =~ m{^[^:]+://(.+)$};
    my %vars = (
        mysql => Mojo::mysql->new( "mysql://$connect" ),
        schema => $schema,
    );
    return $class->SUPER::new( %vars );
}

sub create( $self, $coll, $params ) {
    my $id = $self->mysql->db->insert( $coll, $params )->last_insert_id;
    return $self->get( $coll, $id );
}

sub get( $self, $coll, $id ) {
    return $self->mysql->db->select( $coll, undef, { id => $id } )->hash;
}

sub list( $self, $coll, $params={} ) {
    return $self->mysql->db->select( $coll, undef )->hashes;
}

sub set( $self, $coll, $id, $params ) {
    return $self->mysql->db->update( $coll, $params, { id => $id } );
}

sub delete( $self, $coll, $id ) {
    return $self->mysql->db->delete( $coll, { id => $id } );
}

1;
