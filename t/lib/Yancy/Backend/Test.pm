package Yancy::Backend::Test;
# ABSTRACT: A test backend for testing Yancy

use Mojo::Base '-base';
use List::Util qw( max );
use Mojo::JSON qw( true false from_json to_json encode_json );
use Mojo::File qw( path );
use Storable qw( dclone );
use Role::Tiny qw( with );
with 'Yancy::Backend::Role::Sync';
use Yancy::Util qw( match is_type );

our %DATA;
our %SCHEMA;
our @SCHEMA_ADDED_COLLS;

sub new {
    my ( $class, $url, $schema ) = @_;
    my ( $path ) = $url =~ m{^[^:]+://[^/]+(?:/(.+))?$};
    if ( $path ) {
        %DATA = %{ from_json( path( ( $ENV{MOJO_HOME} || () ), $path )->slurp ) };
    } elsif ( %Yancy::Backend::Test::SCHEMA ) {
        # M::P::Y relies on "read_schema" to give back the "real" schema.
        # If given the micro thing, this is needed to make it actually
        # operate like it would with a real database
        $schema = \%Yancy::Backend::Test::SCHEMA;
    }
    return bless { init_arg => $url, schema => $schema }, $class;
}

sub schema {
    my ( $self, $schema ) = @_;
    if ( $schema ) {
        $self->{schema} = $schema;
        return;
    }
    $self->{schema};
}
sub collections;
*collections = *schema;

sub create {
    my ( $self, $schema_name, $params ) = @_;
    $params = $self->_normalize( $schema_name, $params ); # makes a copy
    die "No refs allowed in '$schema_name': " . encode_json $params
        if grep ref, values %$params;
    my $props = $self->schema->{ $schema_name }{properties};
    $params->{ $_ } = $props->{ $_ }{default} // undef
        for grep !exists $params->{ $_ },
        keys %$props;
    my $id_field = $self->schema->{ $schema_name }{ 'x-id-field' } || 'id';
    if (
        ( !$params->{ $id_field } and $self->schema->{ $schema_name }{properties}{ $id_field }{type} eq 'integer' ) ||
        ( $id_field ne 'id' and exists $self->schema->{ $schema_name }{properties}{id} )
    ) {
        my @existing_ids = $id_field eq 'id'
            ? keys %{ $DATA{ $schema_name } }
            : map { $_->{ id } } values %{ $DATA{ $schema_name } }
            ;
        my $id = ( max( @existing_ids ) // 0 ) + 1;
        $params->{id} = $id;
    }
    $DATA{ $schema_name }{ $params->{ $id_field } } = $params;
    return $params->{ $id_field };
}

sub get {
    my ( $self, $schema_name, $id ) = @_;
    my $schema = $self->schema->{ $schema_name };
    my $real_coll = ( $schema->{'x-view'} || {} )->{schema} // $schema_name;
    my $item = $DATA{ $real_coll }{ $id // '' };
    return undef unless $item;
    $self->_viewise( $schema_name, $item );
}

sub _viewise {
    my ( $self, $schema_name, $item ) = @_;
    $item = dclone $item;
    my $schema = $self->schema->{ $schema_name };
    my $real_coll = ( $schema->{'x-view'} || {} )->{schema} // $schema_name;
    my $props = $schema->{properties}
        || $self->schema->{ $real_coll }{properties};
    delete $item->{$_} for grep !$props->{ $_ }, keys %$item;
    $item;
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
    my ( $self, $schema_name, $params, $opt ) = @_;
    my $schema = $self->schema->{ $schema_name };
    die "list attempted on non-existent schema '$schema_name'" unless $schema;
    $params ||= {}; $opt ||= {};
    my $id_field = $schema->{ 'x-id-field' } || 'id';
    my $real_coll = ( $schema->{'x-view'} || {} )->{schema} // $schema_name;
    my $props = $schema->{properties}
        || $self->schema->{ $real_coll }{properties};
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
        grep { match( $params, $_ ) }
        values %{ $DATA{ $real_coll } };
    my $first = $opt->{offset} // 0;
    my $last = $opt->{limit} ? $opt->{limit} + $first - 1 : $#rows;
    if ( $last > $#rows ) {
        $last = $#rows;
    }
    my $retval = {
        items => [ map $self->_viewise( $schema_name, $_ ), @rows[ $first .. $last ] ],
        total => scalar @rows,
    };
    #; use Data::Dumper;
    #; say Dumper $retval;
    return $retval;
}

sub set {
    my ( $self, $schema_name, $id, $params ) = @_;
    return if !$DATA{ $schema_name }{ $id };
    $params = $self->_normalize( $schema_name, $params );
    die "No refs allowed in '$schema_name'($id): " . encode_json $params
        if grep ref, values %$params;
    my $id_field = $self->schema->{ $schema_name }{ 'x-id-field' } || 'id';
    my $old_item = $DATA{ $schema_name }{ $id };
    if ( !$params->{ $id_field } ) {
        $params->{ $id_field } = $id;
    }
    if ( $params->{ $id_field } ne $id ) {
        delete $DATA{ $schema_name }{ $id };
        $id = $params->{ $id_field };
    }
    $DATA{ $schema_name }{ $id } = { %{ $old_item || {} }, %$params };
    return 1;
}

sub delete {
    my ( $self, $schema_name, $id ) = @_;
    return !!delete $DATA{ $schema_name }{ $id };
}

sub _normalize {
    my ( $self, $schema_name, $data ) = @_;
    return undef if !$data;
    my $schema = $self->schema->{ $schema_name }{ properties };
    my %replace;
    for my $key ( keys %$data ) {
        next if !defined $data->{ $key }; # leave nulls alone
        my $type = $schema->{ $key }{ type };
        next if !is_type( $type, 'boolean' );
        # Boolean: true (1, "true"), false (0, "false")
        $replace{ $key }
            = $data->{ $key } && $data->{ $key } !~ /^false$/i
            ? 1 : 0;
    }
    +{ %$data, %replace };
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
