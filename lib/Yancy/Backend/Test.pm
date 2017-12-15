package Yancy::Backend::Test;
our $VERSION = '0.007';
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
    if ( !$params->{ $id_field } ) {
        my $id = max( keys $COLLECTIONS{ $coll }->%* ) + 1;
        $params->{ $id_field } = $id;
    }
    $COLLECTIONS{ $coll }{ $params->{ $id_field } } = $params;
}

sub get( $self, $coll, $id ) {
    return $COLLECTIONS{ $coll }{ $id };
}

sub list( $self, $coll, $params={}, $opt={} ) {
    my $id_field = $self->{collections}{ $coll }{ 'x-id-field' } || 'id';
    my $sort_field = $opt->{order_by} ? [values $opt->{order_by}[0]->%*]->[0] : $id_field;
    my $sort_order = $opt->{order_by} ? [keys $opt->{order_by}[0]->%*]->[0] : '-asc';
    my @rows = sort {
        $sort_order eq '-asc'
            ? $a->{$sort_field} cmp $b->{$sort_field}
            : $b->{$sort_field} cmp $a->{$sort_field}
        }
        values $COLLECTIONS{ $coll }->%*;
    my $first = $opt->{offset} // 0;
    my $last = $opt->{limit} ? $opt->{limit} + $first - 1 : $#rows;
    if ( $last > $#rows ) {
        $last = $#rows;
    }
    my $retval = {
        rows => [ @rows[ $first .. $last ] ],
        total => scalar keys $COLLECTIONS{ $coll }->%*,
    };
    #; use Data::Dumper;
    #; say Dumper $retval;
    return $retval;
}

sub set( $self, $coll, $id, $params ) {
    $COLLECTIONS{ $coll }{ $id } = $params;
}

sub delete( $self, $coll, $id ) {
    delete $COLLECTIONS{ $coll }{ $id };
}

1;
