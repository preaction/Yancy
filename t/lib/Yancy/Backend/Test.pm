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
    return bless { init_arg => $url, collections => $collections }, $class;
}

sub create {
    my ( $self, $coll, $params ) = @_;
    $self->_normalize( $coll, $params );
    my $id_field = $self->{collections}{ $coll }{ 'x-id-field' } || 'id';
    if (
        ( !$params->{ $id_field } and $self->{collections}{ $coll }{properties}{ $id_field }{type} eq 'integer' ) ||
        ( $id_field ne 'id' and exists $self->{collections}{ $coll }{properties}{id} )
    ) {
        my @existing_ids = $id_field eq 'id'
            ? keys %{ $COLLECTIONS{ $coll } }
            : map { $_->{ id } } values %{ $COLLECTIONS{ $coll } }
            ;
        my $id = ( max( @existing_ids ) // 0 ) + 1;
        $params->{id} = $id;
    }
    $COLLECTIONS{ $coll }{ $params->{ $id_field } } = $params;
    return $params->{ $id_field };
}

sub get {
    my ( $self, $coll, $id ) = @_;
    my $item = $COLLECTIONS{ $coll }{ $id // '' };
    return undef unless $item;
    return { %$item };
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
    for my $filter_param (keys %$params) {
        die "Can't filter by non-existent parameter '$filter_param'"
            if !exists $SCHEMA{ $coll }{properties}{ $filter_param };
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
        items => [ map { +{ %$_ } } @rows[ $first .. $last ] ],
        total => scalar @rows,
    };
    #; use Data::Dumper;
    #; say Dumper $retval;
    return $retval;
}

sub set {
    my ( $self, $coll, $id, $params ) = @_;
    $self->_normalize( $coll, $params );
    my $id_field = $self->{collections}{ $coll }{ 'x-id-field' } || 'id';
    my $old_item = $COLLECTIONS{ $coll }{ $id };
    if ( !$params->{ $id_field } ) {
        $params->{ $id_field } = $id;
    }
    if ( $params->{ $id_field } ne $id ) {
        delete $COLLECTIONS{ $coll }{ $id };
        $id = $params->{ $id_field };
    }
    $COLLECTIONS{ $coll }{ $id } = { %{ $old_item || {} }, %$params };
    return 1;
}

sub delete {
    my ( $self, $coll, $id ) = @_;
    return !!delete $COLLECTIONS{ $coll }{ $id };
}

sub _normalize {
    my ( $self, $coll, $data ) = @_;
    my $schema = $self->{collections}{ $coll }{ properties };
    for my $key ( keys %$data ) {
        my $type = $schema->{ $key }{ type };
        # Boolean: true (1, "true"), false (0, "false")
        if ( _is_type( $type, 'boolean' ) ) {
            $data->{ $key }
                = $data->{ $key } && $data->{ $key } !~ /^false$/i
                ? 1 : 0;
        }
    }
}

sub _is_type {
    my ( $type, $is_type ) = @_;
    return unless $type;
    return ref $type eq 'ARRAY'
        ? !!grep { $_ eq $is_type } @$type
        : $type eq $is_type;
}

sub read_schema {
    my ( $self, @table_names ) = @_;
    return @table_names
        ? map { dclone $_ } @SCHEMA{ @table_names }
        : dclone { %SCHEMA }
        ;
}

1;
