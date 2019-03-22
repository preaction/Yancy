package Yancy::Util;
our $VERSION = '1.024';
# ABSTRACT: Utilities for Yancy

=head1 SYNOPSIS

    use Yancy::Util qw( load_backend );
    my $be = load_backend( 'test://localhost', $collections );

    use Yancy::Util qw( curry );
    my $helper = curry( \&_helper_sub, @args );

    use Yancy::Util qw( currym );
    my $sub = currym( $object, 'method_name', @args );

=head1 DESCRIPTION

This module contains utility functions for Yancy.

=head1 SEE ALSO

L<Yancy>

=cut

use Mojo::Base '-strict';
use Exporter 'import';
use Mojo::Loader qw( load_class );
use Scalar::Util qw( blessed );
use Mojo::JSON::Pointer;
our @EXPORT_OK = qw( load_backend curry currym copy_inline_refs );

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

See L<Yancy::Help::Config/Database Backend> for information about
backend URLs and L<Yancy::Backend> for more information about backend
objects.

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

=sub curry

    my $curried_sub = curry( $sub, @args );

Return a new subref that, when called, will call the passed-in subref with
the passed-in C<@args> first.

For example:

    my $add = sub {
        my ( $lop, $rop ) = @_;
        return $lop + $rop;
    };
    my $add_four = curry( $add, 4 );
    say $add_four->( 1 ); # 5
    say $add_four->( 2 ); # 6
    say $add_four->( 3 ); # 7

This is more-accurately called L<partial
application|https://en.wikipedia.org/wiki/Partial_application>, but
C<curry> is shorter.

=cut

sub curry {
    my ( $sub, @args ) = @_;
    return sub { $sub->( @args, @_ ) };
}

=sub currym

    my $curried_sub = currym( $obj, $method, @args );

Return a subref that, when called, will call given C<$method> on the
given C<$obj> with any passed-in C<@args> first.

See L</curry> for an example.

=cut

sub currym {
    my ( $obj, $meth, @args ) = @_;
    my $sub = $obj->can( $meth )
        || die sprintf q{Can't curry method "%s" on object of type "%s": Method is not implemented},
            $meth, blessed( $obj );
    return curry( $sub, $obj, @args );
}

=sub copy_inline_refs

    my $subschema = copy_inline_refs( $schema, '/user' );

Given:

=over

=item a "source" JSON schema (will not be mutated)

=item a JSON Pointer into the source schema, from which to be copied

=back

will return another, copied standalone JSON schema, with any C<$ref>
either copied in, or if previously encountered, with a C<$ref> to the
new location.

=cut

sub copy_inline_refs {
    my ( $schema, $pointer, $usschema, $uspointer, $refmap ) = @_;
    $usschema //= Mojo::JSON::Pointer->new( $schema )->get( $pointer );
    $uspointer //= '';
    $refmap ||= {};
    return { '$ref' => $refmap->{ $uspointer } } if $refmap->{ $uspointer };
    $refmap->{ $pointer } = "#$uspointer"
        unless ref $usschema eq 'HASH' and $usschema->{'$ref'};
    return $usschema
        unless ref $usschema eq 'ARRAY' or ref $usschema eq 'HASH';
    my $counter = 0;
    return [ map copy_inline_refs(
        $schema,
        $pointer.'/'.$counter++,
        $_,
        $uspointer.'/'.$counter++,
        $refmap,
    ), @$usschema ] if ref $usschema eq 'ARRAY';
    # HASH
    my $ref = $usschema->{'$ref'};
    return { map { $_ => copy_inline_refs(
        $schema,
        $pointer.'/'.$_,
        $usschema->{ $_ },
        $uspointer.'/'.$_,
        $refmap,
    ) } sort keys %$usschema } if !$ref;
    $ref =~ s:^#::;
    return { '$ref' => $refmap->{ $ref } } if $refmap->{ $ref };
    copy_inline_refs(
        $schema,
        $ref,
        Mojo::JSON::Pointer->new( $schema )->get( $ref ),
        $uspointer,
        $refmap,
    );
}

1;
