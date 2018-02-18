package Yancy::Plugin::Test;

=head1 DESCRIPTION

This is a test plugin to ensure Yancy looks up plugins and gives them
their arguments correctly.

=cut

use Mojo::Base 'Mojolicious::Plugin';

sub register {
    my ( $self, $app, @args ) = @_;
    my $route = $args[0]{route} // '/test';
    $app->routes->get( $route )->to( cb => sub {
        my ( $c ) = @_;
        return $c->render( json => \@args );
    } );
}

1;
