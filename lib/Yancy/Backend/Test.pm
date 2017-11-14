package Yancy::Backend::Test;
our $VERSION = '0.001';
# ABSTRACT: A test backend for testing Yancy

use v5.24;
use Mojo::Base 'Mojo';
use experimental qw( signatures postderef );
use List::Util qw( max );

our %COLLECTIONS = ();

sub new( $class, $url ) {
    return bless {}, $class;
}

sub create( $self, $coll, $params ) {
    my $id = max( keys $COLLECTIONS{ $coll }->%* ) + 1;
    $COLLECTIONS{ $coll }{ $id } = $params;
}

sub get( $self, $coll, $id ) {
    return $COLLECTIONS{ $coll }{ $id };
}

sub list( $self, $coll, $params={} ) {
    return [ sort { $a->{id} <=> $b->{id} } values $COLLECTIONS{ $coll }->%* ];
}

sub set( $self, $coll, $id, $params ) {
    $COLLECTIONS{ $coll }{ $id } = $params;
}

sub delete( $self, $coll, $id ) {
    delete $COLLECTIONS{ $coll }{ $id };
}

1;
