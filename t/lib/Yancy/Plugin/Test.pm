package Yancy::Plugin::Test;

=head1 DESCRIPTION

This is a test plugin to ensure Yancy looks up plugins and gives them
their arguments correctly.

=cut

use v5.24;
use Mojo::Base 'Mojolicious::Plugin';
use experimental qw( signatures postderef );

sub register( $self, $app, @args ) {
    $app->routes->get( '/test' )->to( cb => sub( $c ) {
        return $c->render( json => \@args );
    } );
}

1;
