package Yancy::Backend::Test;
# ABSTRACT: A test backend for testing Yancy

use Mojo::Base '-base';
use List::Util qw( max );
use Mojo::JSON qw( from_json to_json );
use Mojo::File qw( path );
use Storable qw( dclone );
use Role::Tiny qw( with );
with 'Yancy::Backend::Role::Sync';

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

sub collections {
    my ( $self, $collections ) = @_;
    if ( $collections ) {
        $self->{collections} = $collections;
        return;
    }
    $self->{collections};
}

sub create {
    my ( $self, $coll, $params ) = @_;
    $params = $self->_normalize( $coll, $params ); # makes a copy
    my $props = $SCHEMA{ $coll }{properties};
    $params->{ $_ } = $props->{ $_ }{default}
        for grep !exists $params->{ $_ } && exists $props->{ $_ }{default},
        keys %$props;
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
    for my $key ( keys %$match ) {
        if ( $key =~ /^-(not_)?bool/ ) {
            my $want_false = $1;
            $key = $match->{ $key }; # the actual field
            return if
                ( $want_false and $item->{ $key } ) or
                ( !$want_false and !$item->{ $key } ) ;
        }
        elsif ( !ref $match->{ $key } ) {
            return if $item->{ $key } !~ qr{^$match->{$key}$};
        }
        elsif ( ref $match->{ $key } eq 'HASH' ) {
            if ( my $value = $match->{ $key }{ -like } || $match->{ $key }{like} ) {
                $value =~ s/%/.*/g;
                return if $item->{ $key } !~ qr{^$value$};
            }
            else {
                die "Unknown query type: " . to_json( $match->{ $key } );
            }
        }
        else {
            die "Unknown match ref type: " . to_json( $match->{ $key } );
        }
    }
    1;
}

sub list {
    my ( $self, $coll, $params, $opt ) = @_;
    $params ||= {}; $opt ||= {};
    my $id_field = $self->{collections}{ $coll }{ 'x-id-field' } || 'id';

    my $sort_field = $id_field;
    my $sort_order = '-asc';
    if ( my $order = $opt->{order_by} ) {
        if ( ref $order eq 'ARRAY' ) {
            $sort_field = [values %{ $order->[0] }]->[0];
            $sort_order = [keys %{ $order->[0] }]->[0];
        }
        elsif ( ref $order eq 'HASH' ) {
            $sort_field = [values %$order]->[0];
            $sort_order = [keys %$order]->[0];
        }
    }
    for my $filter_param (keys %$params) {
        if ( $filter_param =~ /^-(not_)?bool/ ) {
            $filter_param = $params->{ $filter_param };
        }
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
    return if !$COLLECTIONS{ $coll }{ $id };
    $params = $self->_normalize( $coll, $params );
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
    return undef if !$data;
    my $schema = $self->collections->{ $coll }{ properties };
    my %replace;
    for my $key ( keys %$data ) {
        next if !defined $data->{ $key }; # leave nulls alone
        my $type = $schema->{ $key }{ type };
        next if !_is_type( $type, 'boolean' );
        # Boolean: true (1, "true"), false (0, "false")
        $replace{ $key }
            = $data->{ $key } && $data->{ $key } !~ /^false$/i
            ? 1 : 0;
    }
    +{ %$data, %replace };
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
    my $cloned = dclone { %SCHEMA };
    # zap all things that DB can't know about
    for my $c ( values %$cloned ) {
        delete $c->{'x-list-columns'};
        for my $p ( values %{ $c->{properties} } ) {
            delete @$p{ qw(format description pattern title) };
        }
    }
    return @table_names ? @$cloned{ @table_names } : $cloned;
}

1;
