package Yancy::Controller::Yancy;
our $VERSION = '0.013';
# ABSTRACT: A simple REST controller for Mojolicious

=head1 DESCRIPTION

This module contains the routes that L<Yancy> uses to work with the
backend data. This API is used by the web application.

=head1 SUBCLASSING

To change how the API provides access to the data in your database, you
can create a custom controller. To do so, you should extend this class
and override the desired methods to provide the desired functionality.

    package MyApp::Controller::CustomYancy;
    use Mojo::Base 'Yancy::Controller::Yancy';
    sub list_items {
        my ( $c ) = @_;
        return unless $c->openapi->valid_input;
        my $items = $c->yancy->backend->list( $c->stash( 'collection' ) );
        return $c->render(
            status => 200,
            openapi => $items,
        );
    }

    package main;
    use Mojolicious::Lite;
    push @{ app->routes->namespaces }, 'MyApp::Controller';
    plugin Yancy => {
        controller_class => 'CustomYancy',
    };

For an example, you could extend this class to add authorization based
on your own requirements.

=head1 SEE ALSO

L<Yancy>, L<Mojolicious::Controller>

=cut

use Mojo::Base 'Mojolicious::Controller';

=method list_items

List the items in a collection. The collection name should be in the
stash key C<collection>. C<limit>, C<offset>, and C<order_by> may be
provided as query parameters.

=cut

sub list_items {
    my ( $c ) = @_;
    return unless $c->openapi->valid_input;
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
        openapi => $c->yancy->backend->list( $c->stash( 'collection' ), {}, \%opt ),
    );
}

=method add_item

Add a new item to the collection. The new item should be in the request
body as JSON. The collection name should be in the stash key C<collection>.

=cut

sub add_item {
    my ( $c ) = @_;
    return unless $c->openapi->valid_input;
    my $coll = $c->stash( 'collection' );
    my $item = $c->yancy->filter->apply( $coll, $c->validation->param( 'newItem' ) );
    return $c->render(
        status => 201,
        openapi => $c->yancy->backend->create( $coll, $item ),
    );
}

=method get_item

Get a single item from a collection. The collection should be in the
stash key C<collection>, and the item's ID in the stash key C<id>.

=cut

sub get_item {
    my ( $c ) = @_;
    return unless $c->openapi->valid_input;
    my $args = $c->validation->output;
    my $id = $args->{ $c->stash( 'id_field' ) };
    return $c->render(
        status => 200,
        openapi => $c->yancy->backend->get( $c->stash( 'collection' ), $id ),
    );
}

=method set_item

Update an item in a collection. The collection should be in the stash
key C<collection>, and the item's ID in the stash key C<id>. The updated
item should be in the request body as JSON.

=cut

sub set_item {
    my ( $c ) = @_;
    return unless $c->openapi->valid_input;
    my $args = $c->validation->output;
    my $id = $args->{ $c->stash( 'id_field' ) };
    my $coll = $c->stash( 'collection' );
    my $item = $c->yancy->filter->apply( $coll, $args->{ newItem } );
    $c->yancy->backend->set( $coll, $id, $item );
    return $c->render(
        status => 200,
        openapi => $c->yancy->backend->get( $coll, $id ),
    );
}

=method delete_item

Delete an item from a collection. The collection name should be in the
stash key C<collection>. The ID of the item should be in the stash key
C<id>.

=cut

sub delete_item {
    my ( $c ) = @_;
    return unless $c->openapi->valid_input;
    my $args = $c->validation->output;
    my $id = $args->{ $c->stash( 'id_field' ) };
    $c->yancy->backend->delete( $c->stash( 'collection' ), $id );
    return $c->rendered( 204 );
}

1;
