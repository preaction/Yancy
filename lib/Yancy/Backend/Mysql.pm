package Yancy::Backend::Mysql;
our $VERSION = '0.001';
# ABSTRACT: A backend for MySQL using Mojo::mysql

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
