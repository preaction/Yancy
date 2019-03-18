package Yancy::Backend::Test;
# ABSTRACT: A test backend for testing Yancy

use Mojo::Base '-base';
use List::Util qw( max );
use Mojo::JSON qw( from_json to_json encode_json );
use Mojo::File qw( path );
use Storable qw( dclone );
use Role::Tiny qw( with );
with 'Yancy::Backend::Role::Sync';

our %COLLECTIONS;
our %SCHEMA;
our @SCHEMA_ADDED_COLLS;

sub new {
    my ( $class, $url, $collections ) = @_;
    my ( $path ) = $url =~ m{^[^:]+://[^/]+(?:/(.+))?$};
    if ( $path ) {
        %COLLECTIONS = %{ from_json( path( ( $ENV{MOJO_HOME} || () ), $path )->slurp ) };
    } elsif ( %Yancy::Backend::Test::SCHEMA ) {
        # M::P::Y relies on "read_schema" to give back the "real" schema.
        # If given the micro thing, this is needed to make it actually
        # operate like it would with a real database
        $collections = \%Yancy::Backend::Test::SCHEMA;
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
    die "No refs allowed in '$coll': " . encode_json $params
        if grep ref, values %$params;
    my $props = $self->collections->{ $coll }{properties};
    $params->{ $_ } = $props->{ $_ }{default}
        for grep !exists $params->{ $_ } && exists $props->{ $_ }{default},
        keys %$props;
    my $id_field = $self->collections->{ $coll }{ 'x-id-field' } || 'id';
    if (
        ( !$params->{ $id_field } and $self->collections->{ $coll }{properties}{ $id_field }{type} eq 'integer' ) ||
        ( $id_field ne 'id' and exists $self->collections->{ $coll }{properties}{id} )
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
    my $schema = $self->collections->{ $coll };
    my $real_coll = ( $schema->{'x-view'} || {} )->{collection} // $coll;
    my $item = $COLLECTIONS{ $real_coll }{ $id // '' };
    return undef unless $item;
    $self->_viewise( $coll, $item );
}

sub _viewise {
    my ( $self, $coll, $item ) = @_;
    $item = dclone $item;
    my $schema = $self->collections->{ $coll };
    my $real_coll = ( $schema->{'x-view'} || {} )->{collection} // $coll;
    my $props = $schema->{properties}
        || $self->collections->{ $real_coll }{properties};
    delete $item->{$_} for grep !$props->{ $_ }, keys %$item;
    $item;
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
            return if ( $item->{ $key } // '' ) !~ qr{^$match->{$key}$};
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

sub _order_by {
    my ( $id_field, $order ) = @_;
    my $sort_field = $id_field;
    my $sort_order = '-asc';
    if ( $order ) {
        if ( ref $order eq 'ARRAY' ) {
            return _order_by( $id_field, $order->[0] );
        }
        elsif ( ref $order eq 'HASH' ) {
            $sort_field = [values %$order]->[0];
            $sort_order = [keys %$order]->[0];
        }
        else {
            $sort_field = $order;
        }
    }
    ( $sort_field, $sort_order );
}

sub list {
    my ( $self, $coll, $params, $opt ) = @_;
    my $schema = $self->collections->{ $coll };
    die "list attempted on non-existent collection '$coll'" unless $schema;
    $params ||= {}; $opt ||= {};
    my $id_field = $schema->{ 'x-id-field' } || 'id';
    my $real_coll = ( $schema->{'x-view'} || {} )->{collection} // $coll;
    my $props = $schema->{properties}
        || $self->collections->{ $real_coll }{properties};
    my ( $sort_field, $sort_order ) = _order_by( $id_field, $opt->{order_by} );
    for my $filter_param (keys %$params) {
        if ( $filter_param =~ /^-(not_)?bool/ ) {
            $filter_param = $params->{ $filter_param };
        }
        die "Can't filter by non-existent parameter '$filter_param'"
            if !exists $props->{ $filter_param };
    }

    my @rows = sort {
        $sort_order eq '-asc'
            ? $a->{$sort_field} cmp $b->{$sort_field}
            : $b->{$sort_field} cmp $a->{$sort_field}
        }
        grep { _match_all( $params, $_ ) }
        values %{ $COLLECTIONS{ $real_coll } };
    my $first = $opt->{offset} // 0;
    my $last = $opt->{limit} ? $opt->{limit} + $first - 1 : $#rows;
    if ( $last > $#rows ) {
        $last = $#rows;
    }
    my $retval = {
        items => [ map $self->_viewise( $coll, $_ ), @rows[ $first .. $last ] ],
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
    die "No refs allowed in '$coll'($id): " . encode_json $params
        if grep ref, values %$params;
    my $id_field = $self->collections->{ $coll }{ 'x-id-field' } || 'id';
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
    my $cloned = dclone $self->collections;
    delete @$cloned{@SCHEMA_ADDED_COLLS}; # ones not in the "database" at all
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
