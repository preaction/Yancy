package Yancy::Controller::Yancy;
our $VERSION = '0.004';
# ABSTRACT: A simple REST controller for Mojolicious

=head1 DESCRIPTION

This module contains the routes that L<Yancy> uses to work with the
backend data.

=head1 SEE ALSO

L<Yancy>, L<Mojolicious::Controller>

=cut

use Mojo::Base 'Mojolicious::Controller';
use v5.24;
use experimental qw( signatures postderef );

=method list_items

List the items in a collection. The collection name should be in the
stash key C<collection>. C<limit> and C<offset> may be provided as query
parameters.

=cut

sub list_items( $c ) {
    return unless $c->openapi->valid_input;
    my $args = $c->validation->output;
    my %opt = (
        limit => $args->{limit},
        offset => $args->{offset},
    );
    return $c->render(
        status => 200,
        openapi => $c->yancy->backend->list( $c->stash( 'collection' ), {}, \%opt ),
    );
}

=method add_item

Add a new item to the collection. The new item should be in the request
body as JSON.

=cut

sub add_item( $c ) {
    return unless $c->openapi->valid_input;
    return $c->render(
        status => 201,
        openapi => $c->yancy->backend->create( $c->stash( 'collection' ), $c->req->json ),
    );
}

=method get_item

Get a single item from a collection. The collection should be in the
stash key C<collection>, and the item's ID in the stash key C<id>.

=cut

sub get_item( $c ) {
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

sub set_item( $c ) {
    return unless $c->openapi->valid_input;
    my $args = $c->validation->output;
    my $id = $args->{ $c->stash( 'id_field' ) };
    $c->yancy->backend->set( $c->stash( 'collection' ), $id, $c->req->json );
    return $c->render(
        status => 200,
        openapi => $c->yancy->backend->get( $c->stash( 'collection' ), $id ),
    );
}

=method delete_item

Delete an item from a collection. The collection name should be in the
stash key C<collection>. The ID of the item should be in the stash key
C<id>.

=cut

sub delete_item( $c ) {
    return unless $c->openapi->valid_input;
    my $args = $c->validation->output;
    my $id = $args->{ $c->stash( 'id_field' ) };
    $c->yancy->backend->delete( $c->stash( 'collection' ), $id );
    return $c->rendered( 204 );
}

1;
