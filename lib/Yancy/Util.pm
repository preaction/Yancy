package Yancy::Util;
our $VERSION = '1.066';
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

    use Yancy::Util qw( fill_brackets );
    my $value = fill_brackets( $template, $item );

=head1 DESCRIPTION

This module contains utility functions for Yancy.

=head1 SEE ALSO

L<Yancy>

=cut

use Mojo::Base '-strict';
use Exporter 'import';
use List::Util qw( all any none first );
use Mojo::Loader qw( load_class );
use Scalar::Util qw( blessed );
use Mojo::JSON::Pointer;
use Mojo::JSON qw( to_json );
use Mojo::Util qw( xml_escape );
use Carp qw( carp );

our @EXPORT_OK = qw( load_backend curry currym copy_inline_refs match derp fill_brackets
    is_type order_by is_format );

=sub load_backend

    my $backend = load_backend( $backend_url, $schema );
    my $backend = load_backend( { $backend_name => $arg }, $schema );
    my $backend = load_backend( $db_object, $schema );

Get a Yancy backend from the given backend URL, or from a hash reference
with a backend name and optional argument. The C<$schema> hash is
the configured JSON schema for this backend.

A backend URL should begin with a name followed by a colon. The first
letter of the name will be capitalized, and used to build a class name
in the C<Yancy::Backend> namespace.

The C<$backend_name> should be the name of a module in the
C<Yancy::Backend> namespace. The C<$arg> is handled by the backend
module. Read your backend module's documentation for details.

The C<$db_object> can be one of: L<Mojo::Pg>, L<Mojo::mysql>,
L<Mojo::SQLite>, or a subclass of L<DBIx::Class::Schema>. The
appropriate backend object will be created.

See L<Yancy::Help::Config/Database Backend> for information about
backend URLs and L<Yancy::Backend> for more information about backend
objects.

=cut

# This allows users to pass in the database object directly
our %BACKEND_CLASSES = (
    'Mojo::Pg' => 'pg',
    'Mojo::mysql' => 'mysql',
    'Mojo::SQLite' => 'sqlite',
    'DBIx::Class::Schema' => 'dbic',
);

# Aliases allow the user to specify the same string as they pass to
# their database object
our %TYPE_ALIAS = (
    postgresql => 'pg',
);

sub load_backend {
    my ( $config, $schema ) = @_;
    my ( $type, $arg );
    if ( !ref $config ) {
        ( $type ) = $config =~ m{^([^:]+)};
        $type = $TYPE_ALIAS{ $type } // $type;
        $arg = $config;
    }
    elsif ( blessed $config ) {
        for my $class ( keys %BACKEND_CLASSES ) {
            if ( $config->isa( $class ) ) {
                ( $type, $arg ) = ( $BACKEND_CLASSES{ $class }, $config );
                last;
            }
        }
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
    return undef if !defined $item;

    if ( ref $match eq 'ARRAY' ) {
        return any { match( $_, $item ) } @$match;
    }

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
            elsif ( $value = $match->{ $key }{ -has } ) {
                my $expect = $value;
                $test{ $key } = sub {
                    my ( $value, $key ) = @_;
                    return 0 if !defined $value;
                    if ( ref $value eq 'ARRAY' ) {
                        if ( ref $expect eq 'ARRAY' ) {
                            return all { my $e = $_; any { $_ eq $e } @$value } @$expect;
                        }
                        elsif ( !ref $expect ) {
                            return any { $_ eq $expect } @$value;
                        }
                    }
                    elsif ( ref $value eq 'HASH' ) {
                        if ( ref $expect eq 'HASH' ) {
                            return match( $expect, $value );
                        }
                        else {
                            die 'Bad query in -has on hash value: ' . ref $expect;
                        }
                    }
                    else {
                        die '-has query does not work on non-ref fields';
                    }
                };
            }
            elsif ( $value = $match->{ $key }{ -not_has } ) {
                $test{ $key } = sub {
                    my $expect = $value;
                    my ( $value, $key ) = @_;
                    return 1 if !defined $value;
                    if ( ref $value eq 'ARRAY' ) {
                        if ( ref $expect eq 'ARRAY' ) {
                            return all { my $e = $_; none { $_ eq $e } @$value } @$expect;
                        }
                        elsif ( !ref $expect ) {
                            return none { $_ eq $expect } @$value;
                        }
                        else {
                            die 'Bad query in -has on array value: ' . ref $expect;
                        }
                    }
                    elsif ( ref $value eq 'HASH' ) {
                        if ( ref $expect eq 'HASH' ) {
                            return !match( $expect, $value );
                        }
                        else {
                            die 'Bad query in -has on hash value: ' . ref $expect;
                        }
                    }
                    else {
                        die '-has query does not work on non-ref fields';
                    }
                };
            }
            elsif ( exists $match->{ $key }{ '!=' } ) {
                my $expect = $match->{ $key }{ '!=' };
                $test{ $key } = sub {
                    my ( $got, $key ) = @_;
                    if ( !defined $expect || !defined $got) {
                        return defined $got != defined $expect;
                    }
                    return $got ne $expect;
                };
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
            !defined $test{ $_ } ? !defined $item->{ $_ }
            : ref $test{ $_ } eq 'Regexp' ? $item->{ $_ } =~ $test{ $_ }
            : ref $test{ $_ } eq 'CODE' ? $test{ $_ }->( $item->{ $_ }, $_ )
            : $item->{ $_ } eq $test{ $_ }
        }
        keys %test;

    return $passes == keys %test;
}

=sub order_by

    my $ordered_array = order_by( $order_by, $unordered_array );

Order the given arrayref by the given L<SQL::Abstract> order-by clause.

=cut

sub order_by {
    my ( $order_by, $unordered ) = @_;
    # Array of [ (-asc/-desc), (field) ]
    my @sort_items;

    if ( ref $order_by eq 'ARRAY' ) {
        @sort_items = map { [ ref $_ ? %$_ : ( -asc => $_ ) ] } @$order_by;
    }
    elsif ( ref $order_by eq 'HASH' ) {
        @sort_items = [ %$order_by ];
    }
    else {
        @sort_items = [ -asc => $order_by ];
    }

    my @ordered = sort {
            for my $item ( @sort_items ) {
                my $cmp = $item->[0] eq '-asc'
                    ? ($a->{ $item->[1] }//'') cmp ($b->{ $item->[1] }//'')
                    : ($b->{ $item->[1] }//'') cmp ($a->{ $item->[1] }//'')
                    ;
                return $cmp || next;
            }
        }
        @$unordered;

    return \@ordered;
}

=sub fill_brackets

    my $string = fill_brackets( $template, $item );

This routine will fill in the given template string with the values from
the given C<$item> hashref. The template contains field names within curly braces.
Values in the C<$item> hashref will be escaped with L<Mojo::Util/xml_escape>.

    my $item = {
        name => 'Doug Bell',
        email => 'doug@example.com',
        quote => 'I <3 Perl',
    };

    # Doug Bell <doug@example.com>
    fill_brackets( '{name} <{email}>', $item );

    # I &lt;3 Perl
    fill_brackets( '{quote}', $item );

=cut

sub fill_brackets {
    my ( $template, $item ) = @_;
    return scalar $template =~ s/(?<!\\)\{\s*([^\s\}]+)\s*\}/xml_escape $item->{$1}/reg;
}

=sub is_type

    my $bool = is_type( $schema->{properties}{myprop}{type}, 'boolean' );

Returns true if the given JSON schema type value (which can be a string or
an array of strings) contains the given value, allowing the given type for
the property.

    # true
    is_type( 'boolean', 'boolean' );
    is_type( [qw( boolean null )], 'boolean' );
    # false
    is_type( 'string', 'boolean' );
    is_type( [qw( string null )], 'boolean' );

=cut

sub is_type {
    my ( $type, $is_type ) = @_;
    return unless $type;
    return ref $type eq 'ARRAY'
        ? !!grep { $_ eq $is_type } @$type
        : $type eq $is_type;
}

=sub is_format

    my $bool = is_format( $schema->{properties}{myprop}{format}, 'date-time' );

Returns true if the given JSON schema format value (a string) is the given value.

    # true
    is_format( 'date-time', 'date-time' );
    # false
    is_format( 'email', 'date-time' );

=cut

sub is_format {
    my ( $format, $is_format ) = @_;
    return unless $format;
    return $format eq $is_format;
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
