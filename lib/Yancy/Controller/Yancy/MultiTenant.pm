package Yancy::Controller::Yancy::MultiTenant;
our $VERSION = '0.007';
# ABSTRACT: A controller to show a user only their content

=head1 DESCRIPTION

This module contains routes to manage content owned by users. Each user
is allowed to see and manage only their own content.

=head1 CONFIGURATION

To use this controller, you must add some additional configuration to
your collections. This configuration will map collection fields to
Mojolicious stash values. You must then set these stash values on every
request so that users are restricted to their own content.

    use Mojolicious::Lite;
    plugin Yancy => {
        controller_class => 'Yancy::MultiTenant',
        collections => {
            blog => {
                # Map collection fields to stash values
                'x-stash-fields' => {
                    # collection field => stash field
                    user_id => 'current_user_id',
                },
                properties => {
                    id => { type => 'integer', readOnly => 1 },
                    user_id => { type => 'integer', readOnly => 1 },
                    title => { type => 'string' },
                    content => { type => 'string' },
                },
            },
        },
    };

    under '/' => sub {
        my ( $c ) = @_;
        # Pull out the current user's username from the session.
        # See Yancy::Plugin::Auth::Basic for a way to set the username
        $c->stash( current_user_id => $c->session( 'username' ) );
    };

=head1 SEE ALSO

L<Yancy::Controller::Yancy>, L<Mojolicious::Controller>

=cut

use Mojo::Base 'Mojolicious::Controller';
use v5.24;
use experimental qw( signatures postderef );

sub _build_tenant_filter( $c, $coll ) {
    my $filter = $c->yancy->config->{collections}{$coll}{'x-stash-filter'} || {};
    #; use Data::Dumper; say "Filter: " . Dumper $filter;
    my %query = (
        map {; $_ => $c->stash( $filter->{ $_ } ) }
        keys %$filter
    );
    #; use Data::Dumper; say "Query: " . Dumper \%query;
    return %query;
}

sub _fetch_authorized_item( $c, $coll, $id ) {
    my $item = $c->yancy->backend->get( $coll, $id );
    my %filter = $c->_build_tenant_filter( $coll );
    if ( grep { $item->{ $_ } ne $filter{ $_ } } keys %filter ) {
        return;
    }
    return $item;
}

=method list_items

List the items in a collection. A user only can see items owned by
themselves.

=cut

sub list_items( $c ) {
    return unless $c->openapi->valid_input;
    my %query = $c->_build_tenant_filter( $c->stash( 'collection' ) );
    my $args = $c->validation->output;
    my %opt = (
        limit => $args->{limit},
        offset => $args->{offset},
    );
    if ( $args->{order_by} ) {
        $opt{order_by} = [
            map +{ "-$_->[0]" => $_->[1] },
            map +[ split /:/ ],
            split /,/, $args->{order_by}
        ];
    }
    return $c->render(
        status => 200,
        openapi => $c->yancy->backend->list( $c->stash( 'collection' ), \%query, \%opt ),
    );
}

=method add_item

Add a new item to the collection. This new item will be owned by the
current user.

=cut

sub add_item( $c ) {
    return unless $c->openapi->valid_input;
    my $coll = $c->stash( 'collection' );
    my $item = {
        $c->yancy->filter->apply( $coll, $c->validation->param( 'newItem' ) )->%*,
        $c->_build_tenant_filter( $coll ),
    };
    return $c->render(
        status => 201,
        openapi => $c->yancy->backend->create( $coll, $item ),
    );
}

=method get_item

Get a single item from a collection. Users can only view items owned
by them.

=cut

sub get_item( $c ) {
    return unless $c->openapi->valid_input;
    my $args = $c->validation->output;
    my $id = $args->{ $c->stash( 'id_field' ) };
    my $item = $c->_fetch_authorized_item( $c->stash( 'collection' ), $id );
    if ( !$item ) {
        return $c->render(
            status => 401,
            openapi => {
                message => 'Unauthorized',
            },
        );
    }
    return $c->render(
        status => 200,
        openapi => $item,
    );
}

=method set_item

Update an item in a collection. Users can only update items that they
own.

=cut

sub set_item( $c ) {
    return unless $c->openapi->valid_input;
    my $args = $c->validation->output;
    my $id = $args->{ $c->stash( 'id_field' ) };
    my $coll = $c->stash( 'collection' );
    if ( $c->_fetch_authorized_item( $coll, $id ) ) {
        my $new_item = {
            $c->yancy->filter->apply( $coll, $args->{ newItem } )->%*,
            $c->_build_tenant_filter( $coll ),
        };
        $c->yancy->backend->set( $coll, $id, $new_item );
        return $c->render(
            status => 200,
            openapi => $c->yancy->backend->get( $coll, $id ),
        );
    }
    return $c->render(
        status => 401,
        openapi => {
            message => 'Unauthorized',
        },
    );
}

=method delete_item

Delete an item from a collection. Users can only delete items they own.

=cut

sub delete_item( $c ) {
    return unless $c->openapi->valid_input;
    my $args = $c->validation->output;
    my $id = $args->{ $c->stash( 'id_field' ) };
    if ( $c->_fetch_authorized_item( $c->stash( 'collection' ), $id ) ) {
        $c->yancy->backend->delete( $c->stash( 'collection' ), $id );
        return $c->rendered( 204 );
    }
    return $c->render(
        status => 401,
        openapi => {
            message => 'Unauthorized',
        },
    );
}

1;
