package Yancy::Backend::Test;
# ABSTRACT: A test backend for testing Yancy

use Mojo::Base '-base';
use List::Util qw( max );
use Mojo::JSON qw( from_json to_json );
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
    if ( !$params->{ $id_field } || $id_field ne 'id' ) {
        my @existing_ids = $id_field eq 'id'
            ? keys %{ $COLLECTIONS{ $coll } }
            : map { $_->{ id } } values %{ $COLLECTIONS{ $coll } }
            ;
        my $id = ( max( @existing_ids ) // 0 ) + 1;
        $params->{ $id_field ne 'id' ? 'id' : $id_field } = $id;
    }
    $COLLECTIONS{ $coll }{ $params->{ $id_field } } = $params;
    return $params->{ $id_field };
}

sub get {
    my ( $self, $coll, $id ) = @_;
    return $COLLECTIONS{ $coll }{ $id // '' };
}

sub _match_all {
    my ( $match, $item ) = @_;
    my %regex;
    for my $key ( keys %$match ) {
        if ( !ref $match->{ $key } ) {
            $regex{ $key } = qr{^$match->{$key}$};
        }
        elsif ( ref $match->{ $key } eq 'HASH' ) {
            if ( my $value = $match->{ $key }{ -like } ) {
                $value =~ s/%/.*/g;
                $regex{ $key } = qr{^$value$};
            }
            else {
                die "Unknown query type: " . to_json( $match->{ $key } );
            }
        }
        else {
            die "Unknown match ref type: " . to_json( $match->{ $key } );
        }
    }
    return ( grep { $item->{ $_ } =~ $regex{ $_ } } keys %regex ) == keys %regex;
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
    return 1;
}

sub delete {
    my ( $self, $coll, $id ) = @_;
    return !!delete $COLLECTIONS{ $coll }{ $id };
}

sub read_schema {
    my ( $self ) = @_;
    return dclone { %SCHEMA };
}

1;
