package Yancy::Backend::Dbic;
our $VERSION = '0.001';
# ABSTRACT: A backend for DBIx::Class schemas

use v5.24;
use Mojo::Base 'Mojo';
use experimental qw( signatures postderef );
use Module::Runtime qw( use_module );

has schema =>;

sub new( $class, $url ) {
    my ( $schema, $dsn, $optstr ) = $url =~ m{^[^:]+://([^/]+)/([^?]+)(?:\?(.+))?$};
    my %vars = (
        schema => use_module( $schema )->connect( $dsn ),
    );
    return $class->SUPER::new( %vars );
}

sub _rs( $self, $coll ) {
    my $rs = $self->schema->resultset( $coll );
    $rs->result_class( 'DBIx::Class::ResultClass::HashRefInflator' );
    return $rs;
}

sub create( $self, $coll, $params ) {
    my $created = $self->schema->resultset( $coll )->create( $params );
    return { $created->get_columns };
}

sub get( $self, $coll, $id ) {
    return $self->_rs( $coll )->find( $id );
}

sub list( $self, $coll, $params={} ) {
    return [ $self->_rs( $coll )->all ];
}

sub set( $self, $coll, $id, $params ) {
    return $self->schema->resultset( $coll )->find( $id )->set_columns( $params )->update;
}

sub delete( $self, $coll, $id ) {
    $self->schema->resultset( $coll )->find( $id )->delete;
}

1;
