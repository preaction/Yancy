package Yancy::Controller::Yancy::API;
our $VERSION = '1.030';
# ABSTRACT: An OpenAPI REST controller for the Yancy editor

=head1 DESCRIPTION

B<DEPRECATED>: This module has been merged into the
L<Yancy::Controller::Yancy> class and the editor now uses that class by
default.

This module contains the routes that L<Yancy> uses to work with the
backend data. This API is used by the Yancy editor.

=head1 SUBCLASSING

To change how the API provides access to the data in your database, you
can create a custom controller. To do so, you should extend
L<Yancy::Controller::Yancy> and override the desired methods to provide
the desired functionality.

    package MyApp::Controller::CustomYancyAPI;
    use Mojo::Base 'Yancy::Controller::Yancy';
    sub list {
        my ( $c ) = @_;
        return unless $c->openapi->valid_input;
        my $items = $c->yancy->backend->list( $c->stash( 'schema' ) );
        return $c->render(
            status => 200,
            openapi => $items,
        );
    }

    package main;
    use Mojolicious::Lite;
    push @{ app->routes->namespaces }, 'MyApp::Controller';
    plugin Yancy => {
        editor => {
            default_controller => 'CustomYancyAPI',
        },
    };

For an example, you could extend this class to add authorization based
on your own requirements.

=head1 SEE ALSO

L<Yancy>, L<Mojolicious::Controller>

=cut

use Mojo::Base 'Mojolicious::Controller';
use Mojo::JSON qw( to_json );
use Yancy::Util qw( derp );

=method list

List the items in a schema. The schema name should be in the
stash key C<schema>.

Each returned item will be filtered by filters conforming with
L<Mojolicious::Plugin::Yancy/yancy.filter.add> that are passed in the
array-ref in stash key C<filters_out>.

C<$limit>, C<$offset>, and C<$order_by> may be provided as query parameters.

=cut

sub list {
    my ( $c ) = @_;
    return unless $c->openapi->valid_input;
    my $args = $c->validation->output;

    my %opt = (
        limit => delete $args->{'$limit'},
        offset => delete $args->{'$offset'},
    );
    if ( my $order_by = delete $args->{'$order_by'} ) {
        $opt{order_by} = [
            map +{ "-$_->[0]" => $_->[1] },
            map +[ split /:/ ],
            split /,/, $order_by
        ];
    }

    my %filter;
    if ( $c->stash( 'collection' ) ) {
        derp '"collection" stash key is now "schema" in controller configuration';
    }
    my $schema_name = $c->stash( 'schema' ) || $c->stash( 'collection' );
    my $schema = $c->yancy->schema( $schema_name )  ;
    my $props  = $schema->{properties};
    for my $key ( keys %$args ) {
        my $value = $args->{ $key };
        my $type = $props->{$key}{type} || 'string';
        if ( _is_type( $type, 'string' ) ) {
            if ( ( $value =~ tr/*/%/ ) <= 0 ) {
                 $value = "\%$value\%";
            }
            $filter{ $key } = { -like => $value };
        }
        elsif ( grep _is_type( $type, $_ ), qw(number integer) ) {
            $filter{ $key } = $value ;
        }
        elsif ( _is_type( $type, 'boolean' ) ) {
            $filter{ $value ? '-bool' : '-not_bool' } = $key;
        }
        else {
            die "Sorry type '" .
                to_json( $type ) .
                "' is not handled yet, only string|number|integer|boolean is supported."
        }
    }

    my $res = $c->yancy->backend->list( $schema_name, \%filter, \%opt );
    _delete_null_values( @{ $res->{items} } );
    $res->{items} = [
        map _apply_op_filters( $schema_name, $_, $c->stash( 'filters_out' ), $c->yancy->filters ), @{ $res->{items} }
    ] if $c->stash( 'filters_out' );

    return $c->render(
        status => 200,
        openapi => $res,
    );
}

sub _is_type {
    my ( $type, $is_type ) = @_;
    return unless $type;
    return ref $type eq 'ARRAY'
        ? !!grep { $_ eq $is_type } @$type
        : $type eq $is_type;
}

=method get

Get a single item from a schema. The schema should be in the stash key
C<schema>.

The item's ID field-name is in the stash key C<id_field>. The ID itself
is extracted from the OpenAPI input, under a parameter of that name.

The return value is filtered like each result is in L</list_items>.

=cut

sub get {
    my ( $c ) = @_;
    return unless $c->openapi->valid_input;
    my $args = $c->validation->output;
    my $id = $args->{ $c->stash( 'id_field' ) };
    if ( $c->stash( 'collection' ) ) {
        derp '"collection" stash key is now "schema" in controller configuration';
    }
    my $schema_name = $c->stash( 'schema' ) || $c->stash( 'collection' );
    my $res = _delete_null_values( $c->yancy->backend->get( $schema_name, $id ) );
    $res = _apply_op_filters( $schema_name, $res, $c->stash( 'filters_out' ), $c->yancy->filters )
        if $c->stash( 'filters_out' );
    return $c->render(
        status => 200,
        openapi => $res,
    );
}

=method set

Create or update an item in a schema. The schema should be in the stash
key C<schema>.

The item to be updated is determined as with L</get>, if any.
The new item is extracted from the OpenAPI input, under parameter name
C<newItem>, and must be a hash/JSON "object". It will be filtered by
filters conforming with L<Mojolicious::Plugin::Yancy/yancy.filter.add>
that are passed in the array-ref in stash key C<filters>, after the
schema and property filters have been applied.

The return value is filtered like each result is in L</list>.

=cut

sub set {
    my ( $c ) = @_;
    return unless $c->openapi->valid_input;
    my $args = $c->validation->output;
    my $id = $args->{ $c->stash( 'id_field' ) };
    if ( $c->stash( 'collection' ) ) {
        derp '"collection" stash key is now "schema" in controller configuration';
    }
    my $schema_name = $c->stash( 'schema' ) || $c->stash( 'collection' );
    my $item = $c->yancy->filter->apply( $schema_name, $args->{ newItem } );
    $item = _apply_op_filters( $schema_name, $item, $c->stash( 'filters' ), $c->yancy->filters )
        if $c->stash( 'filters' );

    if ( $id ) {
        $c->yancy->backend->set( $schema_name, $id, $item );
        # ID field may have changed
        $id = $item->{ $c->stash( 'id_field' ) } || $id;
    }
    else {
        $id = $c->yancy->backend->create( $schema_name, $item );
    }

    my $res = _delete_null_values( $c->yancy->backend->get( $schema_name, $id ) );
    $res = _apply_op_filters( $schema_name, $res, $c->stash( 'filters_out' ), $c->yancy->filters )
        if $c->stash( 'filters_out' );
    return $c->render(
        status => 200,
        openapi => $res,
    );
}

=method delete

Delete an item from a schema. The schema name should be in the
stash key C<schema>.

The item to be deleted is determined as with L</get>.

=cut

sub delete {
    my ( $c ) = @_;
    return unless $c->openapi->valid_input;
    my $args = $c->validation->output;
    my $id = $args->{ $c->stash( 'id_field' ) };
    if ( $c->stash( 'collection' ) ) {
        derp '"collection" stash key is now "schema" in controller configuration';
    }
    my $schema_name = $c->stash( 'schema' ) || $c->stash( 'collection' );
    $c->yancy->backend->delete( $schema_name, $id );
    return $c->rendered( 204 );
}

#=sub _delete_null_values
#
#   _delete_null_values( @items );
#
# Remove all the keys with a value of C<undef> from the given items.
# This prevents the user from having to explicitly declare fields that
# can be C<null> as C<< [ 'string', 'null' ] >>. Since this validation
# really only happens when a response is generated, it can be very
# confusing to understand what the problem is
sub _delete_null_values {
    for my $item ( @_ ) {
        delete $item->{ $_ } for grep !defined $item->{ $_ }, keys %$item;
    }
    return wantarray ? @_ : $_[0];
}

#=sub _apply_op_filters
#
# Similar to the helper 'yancy.filter.apply' - filters input item,
# returns updated version.
sub _apply_op_filters {
    my ( $schema_name, $item, $filters, $app_filters ) = @_;
    $item = { %$item }; # no mutate input
    for my $filter ( @$filters ) {
        ( $filter, my @params ) = @$filter if ref $filter eq 'ARRAY';
        my $sub = $app_filters->{ $filter };
        die "Unknown filter: $filter" unless $sub;
        $item = $sub->( $schema_name, $item, {}, @params );
    }
    $item;
}

1;
