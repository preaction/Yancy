package Yancy::Util;
our $VERSION = '1.007';
# ABSTRACT: Utilities for Yancy

=head1 SYNOPSIS

    use Yancy::Util qw( load_backend );
    my $be = load_backend( 'test://localhost', $collections );

=head1 DESCRIPTION

This module contains utility functions for Yancy.

=head1 SEE ALSO

L<Yancy>

=cut

use Mojo::Base '-strict';
use Exporter 'import';
use Mojo::Loader qw( load_class );
our @EXPORT_OK = qw( load_backend );

=sub load_backend

    my $backend = load_backend( $backend_url, $collections );
    my $backend = load_backend( { $backend_name => $arg }, $collections );

Get a Yancy backend from the given backend URL, or from a hash reference
with a backend name and optional argument. The C<$collections> hash is
the configured collections for this backend.

A backend URL should begin with a name followed by a colon. The first
letter of the name will be capitalized, and used to build a class name
in the C<Yancy::Backend> namespace.

The C<$backend_name> should be the name of a module in the
C<Yancy::Backend> namespace. The C<$arg> is handled by the backend
module. Read your backend module's documentation for details.

See L<Yancy/Database Backend> for information about backend URLs and
L<Yancy::Backend> for more information about backend objects.

=cut

sub load_backend {
    my ( $config, $collections ) = @_;
    my ( $type, $arg );
    if ( !ref $config ) {
        ( $type ) = $config =~ m{^([^:]+)};
        $arg = $config
    }
    else {
        ( $type, $arg ) = %{ $config };
    }
    my $class = 'Yancy::Backend::' . ucfirst $type;
    if ( my $e = load_class( $class ) ) {
        die ref $e ? "Could not load class $class: $e" : "Could not find class $class";
    }
    return $class->new( $arg, $collections );
}

1;
