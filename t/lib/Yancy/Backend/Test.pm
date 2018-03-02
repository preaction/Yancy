package Yancy::Backend::Test;
our $VERSION = '0.018';
# ABSTRACT: A test backend for testing Yancy

use Mojo::Base 'Mojo';
use List::Util qw( max );
use Mojo::JSON qw( from_json );
use Mojo::File qw( path );
use Storable qw( dclone );

our %COLLECTIONS = ();
our %SCHEMA = ();

sub new {
    my ( $class, $url, $collections ) = @_;
    my ( $path ) = $url =~ m{^[^:]+://[^/]+(?:/(.+))?$};
    if ( $path ) {
        %COLLECTIONS = %{ from_json( path( ( $ENV{MOJO_HOME} || () ), $path )->slurp ) };
    }
    return bless { collections => $collections }, $class;
}

sub create {
    my ( $self, $coll, $params ) = @_;
    my $id_field = $self->{collections}{ $coll }{ 'x-id-field' } || 'id';
    if ( !$params->{ $id_field } ) {
        my $id = ( max( keys %{ $COLLECTIONS{ $coll } } ) // 0 ) + 1;
        $params->{ $id_field } = $id;
    }
    $COLLECTIONS{ $coll }{ $params->{ $id_field } } = $params;
}

sub get {
    my ( $self, $coll, $id ) = @_;
    return $COLLECTIONS{ $coll }{ $id };
}

sub _match_all {
    my ( $match, $item ) = @_;
    return ( grep { $match->{ $_ } eq $item->{ $_ } } keys %$match ) == keys %$match;
}

sub list {
    my ( $self, $coll, $params, $opt ) = @_;
    $params ||= {}; $opt ||= {};
    my $id_field = $self->{collections}{ $coll }{ 'x-id-field' } || 'id';

    my $sort_field = $id_field;
    my $sort_order = '-asc';
    if ( my $order = $opt->{order_by} ) {
        if ( ref $order eq 'ARRAY' ) {
            $sort_field = [values %{ $opt->{order_by}[0] }]->[0];
            $sort_order = [keys %{ $opt->{order_by}[0] }]->[0];
        }
        elsif ( ref $order eq 'HASH' ) {
            $sort_field = [values %{ $opt->{order_by} }]->[0];
            $sort_order = [keys %{ $opt->{order_by} }]->[0];
        }
    }

    my @rows = sort {
        $sort_order eq '-asc'
            ? $a->{$sort_field} cmp $b->{$sort_field}
            : $b->{$sort_field} cmp $a->{$sort_field}
        }
        grep { _match_all( $params, $_ ) }
        values %{ $COLLECTIONS{ $coll } };
    my $first = $opt->{offset} // 0;
    my $last = $opt->{limit} ? $opt->{limit} + $first - 1 : $#rows;
    if ( $last > $#rows ) {
        $last = $#rows;
    }
    my $retval = {
        items => [ @rows[ $first .. $last ] ],
        total => scalar @rows,
    };
    #; use Data::Dumper;
    #; say Dumper $retval;
    return $retval;
}

sub set {
    my ( $self, $coll, $id, $params ) = @_;
    my $id_field = $self->{collections}{ $coll }{ 'x-id-field' } || 'id';
    $params->{ $id_field } = $id;
    $COLLECTIONS{ $coll }{ $id } = { %{ $COLLECTIONS{ $coll }{ $id } || {} }, %$params };
    return;
}

sub delete {
    my ( $self, $coll, $id ) = @_;
    delete $COLLECTIONS{ $coll }{ $id };
    return;
}

sub read_schema {
    my ( $self ) = @_;
    return dclone { %SCHEMA };
}

1;
