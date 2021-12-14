package Yancy::Model::Schema;
our $VERSION = '1.088';
# ABSTRACT: Interface to a single schema

=head1 SYNOPSIS

    my $schema = $app->model->schema( 'foo' );

    my $id = $schema->create( $data );
    my $item = $schema->get( $id );
    my $count = $schema->delete( $id );
    my $count = $schema->delete( $where );
    my $count = $schema->set( $id, $data );
    my $count = $schema->set( $where, $data );

    my $res = $schema->list( $where, $opts );
    for my $item ( @{ $res->{items} } ) { ... }

=head1 DESCRIPTION

B<NOTE>: This module is experimental and its API may change before
Yancy v2!

For information on how to extend this module to add your own schema
and item methods, see L<Yancy::Guides::Model>.

=head1 SEE ALSO

L<Yancy::Guides::Model>, L<Yancy::Model>

=cut

use Mojo::Base -base;
use Mojo::JSON qw( true false );
use Yancy::Util qw( json_validator is_type derp );

=attr model

The L<Yancy::Model> object that created this schema object.

=cut

has model => sub { die 'model is required' };

=attr name

The name of the schema.

=cut

has name => sub { die 'name is required' };

=attr json_schema

The JSON Schema for this schema.

=cut

has json_schema => sub { die 'json_schema is required' };

sub _backend { shift->model->backend };
has _item_class => sub {
    my $self = shift;
    return $self->model->find_class( Item => $self->name );
};
sub _log { shift->model->log };

sub new {
  my ( $class, @args ) = @_;
  my $self = $class->SUPER::new( @args );
  $self->_check_json_schema;
  return $self;
}

=method id_field

The ID field for this schema. Either a single string, or an arrayref of
strings (for composite keys).

=cut

sub id_field {
    my ( $self ) = @_;
    return $self->json_schema->{'x-id-field'} // 'id';
}

=method build_item

Turn a hashref of row data into a L<Yancy::Model::Item> object using
L<Yancy::Model/find_class> to find the correct class.

=cut

sub build_item {
    my ( $self, $data ) = @_;
    return $self->_item_class->new( { data => $data, schema => $self } );
}

=method validate

Validate an item. Returns a list of errors (if any).

=cut

sub validate {
    my ( $self, $item, %opt ) = @_;
    my $schema = $self->json_schema;

    if ( $opt{ properties } ) {
        # Only validate these properties
        $schema = {
            type => 'object',
            required => [
                grep { my $f = $_; grep { $_ eq $f } @{ $schema->{required} || [] } }
                @{ $opt{ properties } }
            ],
            properties => {
                map { $_ => $schema->{properties}{$_} }
                grep { exists $schema->{properties}{$_} }
                @{ $opt{ properties } }
            },
            additionalProperties => 0, # Disallow any other properties
        };
    }

    my $v = json_validator();
    $v->schema( $schema );

    my @errors;
    # This is a shallow copy of the item that we will change to pass
    # Yancy-specific additions to schema validation
    my %check_item = %$item;
    for my $prop_name ( keys %{ $schema->{properties} } ) {
        my $prop = $schema->{properties}{ $prop_name };

        # These blocks fix problems with validation only. If the
        # problem is the database understanding the value, it must be
        # fixed in the backend class.

        # Pre-filter booleans
        if ( is_type( $prop->{type}, 'boolean' ) && defined $check_item{ $prop_name } ) {
            my $value = $check_item{ $prop_name };
            if ( $value eq 'false' or !$value ) {
                $value = false;
            } else {
                $value = true;
            }
            $check_item{ $prop_name } = $value;
        }
        # An empty date-time, date, or time must become undef: The empty
        # string will never pass the format check, but properties that
        # are allowed to be null can be validated.
        if ( is_type( $prop->{type}, 'string' ) && $prop->{format} && $prop->{format} =~ /^(?:date-time|date|time)$/ ) {
            if ( exists $check_item{ $prop_name } && !$check_item{ $prop_name } ) {
                $check_item{ $prop_name } = undef;
            }
            # The "now" special value will not validate yet, but will be
            # replaced by the Backend with something useful
            elsif ( ($check_item{ $prop_name }//$prop->{default}//'') eq 'now' ) {
                $check_item{ $prop_name } = '2021-01-01 00:00:00';
            }
        }
        # Always add dummy passwords to pass required checks
        if ( $prop->{format} && $prop->{format} eq 'password' && !$check_item{ $prop_name } ) {
            $check_item{ $prop_name } = '<PASSWORD>';
        }

        # XXX: JSON::Validator 4 moved support for readOnly/writeOnly to
        # the OpenAPI schema classes, but we use JSON Schema internally,
        # so we need to make support ourselves for now...
        if ( $prop->{readOnly} && exists $check_item{ $prop_name } ) {
            push @errors, JSON::Validator::Error->new(
                "/$prop_name", "Read-only.",
            );
        }
    }

    push @errors, $v->validate( \%check_item );
    return @errors;
}

=method get

Get an item by its ID. Returns a L<Yancy::Model::Item> object.

=cut

sub get {
    my ( $self, $id, %opt ) = @_;
    return $self->build_item( $self->_backend->get( $self->name, $id, %opt ) // return undef );
}

=method list

List items. Returns a hash reference with C<items> and C<total> keys. The C<items> is
an array ref of L<Yancy::Model::Item> objects. C<total> is the total number of items
that would be returned without any C<offset> or C<limit> options.

=cut

sub list {
    my ( $self, $where, $opt ) = @_;
    my $res = $self->_backend->list( $self->name, $where, $opt );
    return { items => [ map { $self->build_item( $_ ) } @{ $res->{items} } ], total => $res->{total} };
}

=method create

Create a new item. Returns the ID of the created item.

=cut

sub create {
    my ( $self, $data ) = @_;
    if ( my @errors = $self->validate( $data ) ) {
        $self->_log->error(
            sprintf 'Error validating new item in schema "%s": %s',
            $self->name,
            join ', ', @errors
        );
        die \@errors; # XXX: Throw an exception instead that can stringify to something useful
    }
    my $retval = eval { $self->_backend->create( $self->name, $data ) };
    if ( my $error = $@ ) {
        $self->_log->error(
            sprintf 'Error creating item in schema "%s": %s',
            $self->name, $error,
        );
        die $error;
    }
    return $retval;
}

=method set

Set the given fields in an item. See also L<Yancy::Model::Item/set>.

=cut

sub set {
    my ( $self, $id, $data ) = @_;
    if ( my @errors = $self->validate( $data, properties => [ keys %$data ] ) ) {
        $self->_log->error(
            sprintf 'Error validating item with ID "%s" in schema "%s": %s',
            $id, $self->name,
            join ', ', @errors
        );
        die \@errors; # XXX: Throw an exception instead that can stringify to something useful
    }
    my $retval = eval { $self->_backend->set( $self->name, $id, $data ) };
    if ( my $error = $@ ) {
        $self->_log->error(
            sprintf 'Error setting item with ID "%s" in schema "%s": %s',
            $id, $self->name, $error,
        );
        die $error;
    }
    return $retval;
}

=method delete

Delete an item. See also L<Yancy::Model::Item/delete>.

=cut

sub delete {
    my ( $self, $id ) = @_;
    # XXX: Use get() to get the item instance first? Then they could
    # override delete() to do things...
    return $self->_backend->delete( $self->name, $id );
}

sub _check_json_schema {
    my ( $self ) = @_;
    my $name = $self->name;
    my $json_schema = $self->json_schema;

    # Deprecate x-view. Yancy::Model is a much better
    # solution to that.
    derp q{x-view is deprecated and will be removed in v2. }
        . q{Use Yancy::Model or your database's CREATE VIEW instead}
        if $json_schema->{'x-view'};

    $json_schema->{ type } //= 'object';
    my $props = $json_schema->{properties};
    if ( $json_schema->{'x-view'} && !$props ) {
        my $real_name = $json_schema->{'x-view'}->{schema};
        my $real_schema = $self->model->schema( $real_name )
          // die qq{Could not find x-view schema "$real_name" for schema "$name"};
        $props = $real_schema->json_schema->{properties};
    }
    die qq{Schema "$name" has no properties. Does it exist?} if !$props;

    my $id_field = $self->id_field;
    my @id_fields = ref $id_field eq 'ARRAY' ? @$id_field : ( $id_field );
    # ; say "$name ID field: @id_fields";
    # ; use Data::Dumper;
    # ; say Dumper $props;

    for my $field ( @id_fields ) {
        if ( !$props->{ $field } ) {
            die sprintf "ID field missing in properties for schema '%s', field '%s'."
                . " Add x-id-field to configure the correct ID field name, or"
                . " add x-ignore to ignore this schema.",
                    $name, $field;
        }
    }
}

1;
