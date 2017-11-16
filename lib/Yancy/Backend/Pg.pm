package Yancy::Backend::Pg;
our $VERSION = '0.001';
# ABSTRACT: A backend for Postgres using Mojo::Pg

use v5.24;
use Mojo::Base 'Mojo';
use experimental qw( signatures postderef );
use Mojo::Pg 3.0;

has pg =>;

sub new( $class, $url ) {
    my ( $connect ) = $url =~ m{^[^:]+://(.+)$};
    my %vars = (
        pg => Mojo::Pg->new( "postgresql://$connect" ),
    );
    return $class->SUPER::new( %vars );
}

sub create( $self, $coll, $params ) {
    return $self->pg->db->insert( $coll, $params, { returning => '*' } )->hash;
}

sub get( $self, $coll, $id ) {
    return $self->pg->db->select( $coll, undef, { id => $id } )->hash;
}

sub list( $self, $coll, $params={} ) {
    return $self->pg->db->select( $coll, undef )->hashes;
}

sub set( $self, $coll, $id, $params ) {
    return $self->pg->db->update( $coll, $params, { id => $id } );
}

sub delete( $self, $coll, $id ) {
    return $self->pg->db->delete( $coll, { id => $id } );
}

1;
