package Yancy::Backend::Test;
our $VERSION = '0.001';
# ABSTRACT: A test backend for testing Yancy

use v5.24;
use Mojo::Base 'Mojo';
use experimental qw( signatures postderef );
use List::Util qw( max );
use Mojo::JSON qw( from_json );
use Mojo::File qw( path );

our %COLLECTIONS = ();

sub new( $class, $url, $collections ) {
    my ( $path ) = $url =~ m{^[^:]+://[^/]+(?:/(.+))?$};
    if ( $path ) {
        %COLLECTIONS = from_json( path( ( $ENV{MOJO_HOME} || () ), $path )->slurp )->%*;
    }
    return bless { collections => $collections }, $class;
}

sub create( $self, $coll, $params ) {
    my $id_field = $self->{collections}{ $coll }{ 'x-id-field' } || 'id';
    my $id = max( keys $COLLECTIONS{ $coll }->%* ) + 1;
    $params->{ $id_field } //= $id;
    $COLLECTIONS{ $coll }{ $id } = $params;
}

sub get( $self, $coll, $id ) {
    return $COLLECTIONS{ $coll }{ $id };
}

sub list( $self, $coll, $params={} ) {
    my $id_field = $self->{collections}{ $coll }{ 'x-id-field' } || 'id';
    return [ sort { $a->{$id_field} <=> $b->{$id_field} }
        values $COLLECTIONS{ $coll }->%* ];
}

sub set( $self, $coll, $id, $params ) {
    $COLLECTIONS{ $coll }{ $id } = $params;
}

sub delete( $self, $coll, $id ) {
    delete $COLLECTIONS{ $coll }{ $id };
}

1;
