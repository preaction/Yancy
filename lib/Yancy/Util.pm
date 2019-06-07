package Yancy::Util;
our $VERSION = '1.032';
# ABSTRACT: Utilities for Yancy

=head1 SYNOPSIS

    use Yancy::Util qw( load_backend );
    my $be = load_backend( 'test://localhost', $schema );

    use Yancy::Util qw( curry );
    my $helper = curry( \&_helper_sub, @args );

    use Yancy::Util qw( currym );
    my $sub = currym( $object, 'method_name', @args );

    use Yancy::Util qw( match );
    if ( match( $where, $item ) ) {
        say 'Matched!';
    }

=head1 DESCRIPTION

This module contains utility functions for Yancy.

=head1 SEE ALSO

L<Yancy>

=cut

use Mojo::Base '-strict';
use Exporter 'import';
use List::Util qw( any );
use Mojo::Loader qw( load_class );
use Scalar::Util qw( blessed );
use Mojo::JSON::Pointer;
use Mojo::JSON qw( to_json );
use Carp qw( carp );

our @EXPORT_OK = qw( load_backend curry currym copy_inline_refs match derp );

=sub load_backend

    my $backend = load_backend( $backend_url, $schema );
    my $backend = load_backend( { $backend_name => $arg }, $schema );

Get a Yancy backend from the given backend URL, or from a hash reference
with a backend name and optional argument. The C<$schema> hash is
the configured JSON schema for this backend.

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
    my ( $config, $schema ) = @_;
    my ( $type, $arg );
    if ( !ref $config ) {
        ( $type ) = $config =~ m{^([^:]+)};
        $arg = $config;
    }
    else {
        ( $type, $arg ) = %{ $config };
    }
    my $class = 'Yancy::Backend::' . ucfirst $type;
    if ( my $e = load_class( $class ) ) {
        die ref $e ? "Could not load class $class: $e" : "Could not find class $class";
    }
    return $class->new( $arg, $schema );
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

=sub match

    my $bool = match( $where, $item );

Test if the given C<$item> matches the given L<SQL::Abstract> C<$where>
data structure. See L<SQL::Abstract/WHERE CLAUSES> for the full syntax.

Not all of SQL::Abstract's syntax is supported yet, so patches are welcome.

=cut

sub match {
    my ( $match, $item ) = @_;

    my %test;
    for my $key ( keys %$match ) {
        if ( $key =~ /^-(not_)?bool/ ) {
            my $want_false = $1;
            $key = $match->{ $key }; # the actual field
            $test{ $key } = sub {
                my ( $value, $key ) = @_;
                return $want_false ? !$value : !!$value;
            };
        }
        elsif ( !ref $match->{ $key } ) {
            $test{ $key } = $match->{ $key };
        }
        elsif ( ref $match->{ $key } eq 'HASH' ) {
            if ( my $value = $match->{ $key }{ -like } || $match->{ $key }{ like } ) {
                $value = quotemeta $value;
                $value =~ s/(?<!\\)\\%/.*/g;
                $test{ $key } = qr{^$value$};
            }
            else {
                die "Unimplemented query type: " . to_json( $match->{ $key } );
            }
        }
        elsif ( ref $match->{ $key } eq 'ARRAY' ) {
            my @tests = @{ $match->{ $key } };
            # Array is an 'OR' combiner
            $test{ $key } = sub {
                my ( $value, $key ) = @_;
                my $sub_item = { $key => $value };
                return any { match( { $key => $_ }, $sub_item ) } @tests;
            };
        }
        else {
            die "Unimplemented match ref type: " . to_json( $match->{ $key } );
        }
    }

    my $passes
        = grep {
            ref $test{ $_ } eq 'Regexp' ? $item->{ $_ } =~ $test{ $_ }
            : ref $test{ $_ } eq 'CODE' ? $test{ $_ }->( $item->{ $_ }, $_ )
            : $item->{ $_ } eq $test{ $_ }
        }
        keys %test;

    return $passes == keys %test;
}

=sub derp

    derp "This feature is deprecated in file '%s'", $file;

Print out a deprecation message as a warning. A message will only be
printed once for each set of arguments from each caller.

=cut

our @CARP_NOT = qw(
    Yancy::Controller::Yancy Yancy::Controller::Yancy::MultiTenant
    Mojolicious::Plugin::Yancy Mojolicious::Plugins Mojolicious
    Mojo::Server Yancy::Plugin::Editor Yancy::Plugin::Auth
    Mojolicious::Renderer Yancy::Plugin::Auth::Token
    Yancy::Plugin::Auth::Password
);
our %DERPED;
sub derp(@) {
    my @args = @_;
    my $key = to_json [ caller, @args ];
    return if $DERPED{ $key };
    if ( $args[0] !~ /\.$/ ) {
        $args[0] .= '.';
    }
    carp sprintf( $args[0], @args[1..$#args] );
    $DERPED{ $key } = 1;
}

1;
