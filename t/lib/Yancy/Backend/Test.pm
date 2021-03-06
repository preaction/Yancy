package Yancy::Backend::Test;
# ABSTRACT: A test backend for testing Yancy

use Mojo::Base '-base';
use List::Util qw( max );
use Mojo::JSON qw( true false from_json to_json encode_json );
use Mojo::File qw( path );
use Storable qw( dclone );
use Role::Tiny qw( with );
with 'Yancy::Backend::Role::Sync';
use Yancy::Util qw( match is_type order_by is_format );
use Time::Piece;

our %DATA;
our %SCHEMA;
our @SCHEMA_ADDED_COLLS;

sub new {
    my ( $class, $url, $schema ) = @_;
    if ( $url ) {
        my ( $path ) = $url =~ m{^[^:]+://[^/]+(?:/(.+))?$};
        if ( $path ) {
            %DATA = %{ from_json( path( ( $ENV{MOJO_HOME} || () ), $path )->slurp ) };
        }
    }
    $schema //= \%SCHEMA;
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
    $params = { %$params };
    my $props = $self->schema->{ $schema_name }{properties};
    $params->{ $_ } = $props->{ $_ }{default} // undef
        for grep !exists $params->{ $_ },
        keys %$props;
    $params = $self->_normalize( $schema_name, $params ); # makes a copy

    my $id_field = $self->schema->{ $schema_name }{ 'x-id-field' } || 'id';
    my @id_fields = ref $id_field eq 'ARRAY' ? @$id_field : ( $id_field );

    # Fill in any auto-increment data...
    for my $id_field ( @id_fields ) {
        # We haven't provided a value for an integer ID, assume it's autoinc
        if ( !$params->{ $id_field } and $self->schema->{ $schema_name }{properties}{ $id_field }{type} eq 'integer' ) {
            my @existing_ids = keys %{ $DATA{ $schema_name } };
            $params->{ $id_field} = ( max( @existing_ids ) // 0 ) + 1;
        }
        # We have provided another ID, make 'id' another autoinc
        elsif ( $params->{ $id_field }
            && $id_field ne 'id'
            && exists $self->schema->{ $schema_name }{properties}{id}
        ) {
            my @existing_ids = map { $_->{ id } } values %{ $DATA{ $schema_name } };
            $params->{id} = ( max( @existing_ids ) // 0 ) + 1;
        }
    }

    my $store = $DATA{ $schema_name } //= {};
    for my $i ( 0 .. $#id_fields-1 ) {
        $store = $store->{ $params->{ $id_fields[$i] } } //= {};
    }
    $store->{ $params->{ $id_fields[-1] } } = $params;

    return @id_fields > 1 ? { map {; $_ => $params->{ $_ } } @id_fields } : $params->{ $id_field };
}

sub get {
    my ( $self, $schema_name, $id ) = @_;
    my $schema = $self->schema->{ $schema_name };
    my $real_coll = ( $schema->{'x-view'} || {} )->{schema} // $schema_name;

    my $id_field = $self->schema->{ $schema_name }{ 'x-id-field' } || 'id';
    my @ids = ref $id_field eq 'ARRAY' ? map { $id->{ $_ } } @$id_field : ( $id );
    die "Missing composite ID parts" if @ids > 1 && ( !ref $id || keys %$id < @ids );

    my $item = $DATA{ $real_coll };
    for my $id ( @ids ) {
        return undef if !defined $id;
        $item = $item->{ $id } // return undef;
    }

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

sub list {
    my ( $self, $schema_name, $params, $opt ) = @_;
    my $schema = $self->schema->{ $schema_name };
    die "list attempted on non-existent schema '$schema_name'" unless $schema;
    $params ||= {}; $opt ||= {};

    my $id_field = $self->schema->{ $schema_name }{ 'x-id-field' } || 'id';
    my @id_fields = ref $id_field eq 'ARRAY' ? @$id_field : ( $id_field );

    my $real_coll = ( $schema->{'x-view'} || {} )->{schema} // $schema_name;
    my $props = $schema->{properties}
        || $self->schema->{ $real_coll }{properties};
    my @rows = values %{ $DATA{ $real_coll } };
    for my $id_field ( 1..$#id_fields ) {
        @rows = map values %$_, @rows;
    }
    my $matched_rows = order_by(
        $opt->{order_by} // \@id_fields,
        [ grep { match( $params, $_ ) } @rows ],
    );
    # ; use Data::Dumper;
    # ; say Dumper $matched_rows;
    my $first = $opt->{offset} // 0;
    my $last = $opt->{limit} ? $opt->{limit} + $first - 1 : $#$matched_rows;
    if ( $last > $#$matched_rows ) {
        $last = $#$matched_rows;
    }
    my $retval = {
        items => [ map $self->_viewise( $schema_name, $_ ), @$matched_rows[ $first .. $last ] ],
        total => scalar @$matched_rows,
    };
    #; use Data::Dumper;
    #; say Dumper $retval;
    return $retval;
}

sub set {
    my ( $self, $schema_name, $id, $params ) = @_;
    my $id_field = $self->schema->{ $schema_name }{ 'x-id-field' } || 'id';
    my @id_fields = ref $id_field eq 'ARRAY' ? @$id_field : ( $id_field );
    die "Missing composite ID parts" if @id_fields > 1 && ( !ref $id || keys %$id < @id_fields );

    # Fill in any missing params from the ID
    for my $id_field ( @id_fields ) {
        my $id_part = ref $id eq 'HASH' ? $id->{ $id_field } : $id;
        if ( !$params->{ $id_field } ) {
            $params->{ $id_field } = $id_part;
        }
    }

    $params = $self->_normalize( $schema_name, $params );

    my $store = $DATA{ $schema_name };
    for my $i ( 0..$#id_fields-1 ) {
        my $id_field = $id_fields[ $i ];
        my $id_part = ref $id eq 'HASH' ? $id->{ $id_field } : $id;
        return 0 if !$store->{ $id_part };
        # Update the item's ID if it changes
        my $item = delete $store->{ $id_part };
        $store->{ $params->{ $id_field } } = $item;
        $store = $item;
    }
    my $id_part = ref $id eq 'HASH' ? $id->{ $id_fields[-1] } : $id;
    return 0 if !$store->{ $id_part };
    $store->{ $params->{ $id_fields[-1] } } = {
        %{ delete $store->{ $id_part } },
        %$params,
    };

    return 1;
}

sub delete {
    my ( $self, $schema_name, $id ) = @_;
    return 0 if !$id;
    my $id_field = $self->schema->{ $schema_name }{ 'x-id-field' } || 'id';
    my @id_fields = ref $id_field eq 'ARRAY' ? @$id_field : ( $id_field );
    die "Missing composite ID parts" if @id_fields > 1 && ( !ref $id || keys %$id < @id_fields );
    my $store = $DATA{ $schema_name };
    for my $i ( 0..$#id_fields-1 ) {
        my $id_field = $id_fields[ $i ];
        my $id_part = ref $id eq 'HASH' ? $id->{ $id_field } : $id;
        $store = $store->{ $id_part } // return 0;
    }
    my $id_part = ref $id eq 'HASH' ? $id->{ $id_fields[-1] } : $id;
    return 0 if !$store->{ $id_part };
    return !!delete $store->{ $id_part };
}

sub _normalize {
    my ( $self, $schema_name, $data ) = @_;
    return undef if !$data;
    my $schema = $self->schema->{ $schema_name }{ properties };
    my %replace;
    for my $key ( keys %$data ) {
        next if !defined $data->{ $key }; # leave nulls alone
        my ( $type, $format ) = @{ $schema->{ $key } }{qw( type format )};
        if ( is_type( $type, 'boolean' ) ) {
            # Boolean: true (1, "true"), false (0, "false")
            $replace{ $key }
                = $data->{ $key } && $data->{ $key } !~ /^false$/i
                ? 1 : 0;
        }
        elsif ( is_type( $type, 'string' ) && is_format( $format, 'date-time' ) ) {
            if ( $data->{ $key } eq 'now' ) {
                $replace{ $key } = Time::Piece->new->datetime;
            }
        }
    }
    +{ %$data, %replace };
}

# Some databases can know other formats
my %db_formats = map { $_ => 1 } qw( date time date-time binary );

sub read_schema {
    my ( $self, @table_names ) = @_;
    my $schema = %SCHEMA ? \%SCHEMA : $self->schema;
    my $cloned = dclone $schema;
    delete @$cloned{@SCHEMA_ADDED_COLLS}; # ones not in the "database" at all
    # zap all things that DB can't know about
    for my $c ( values %$cloned ) {
        delete $c->{'x-list-columns'};
        for my $p ( values %{ $c->{properties} } ) {
            delete @$p{ qw(description pattern title) };
            if ( $p->{format} && !$db_formats{ $p->{format} } ) {
                delete $p->{format};
            }
        }
    }
    return @table_names ? @$cloned{ @table_names } : $cloned;
}

sub supports { grep { $_[1] eq $_ } 'complex-type' }

1;
