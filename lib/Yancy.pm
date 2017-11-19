package Yancy;
our $VERSION = '0.001';
# ABSTRACT: Write a sentence about what it does

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SEE ALSO

=cut

use v5.24;
use Mojo::Base 'Mojolicious';
use experimental qw( signatures postderef );

sub startup( $app ) {
    $app->plugin( Config => { default => { } } );
    $app->plugin( 'Yancy', {
        %{ $app->config },
        route => $app->routes->any('/'),
    } );
}

1;
