package Yancy::Model;
our $VERSION = '1.089';
# ABSTRACT: Model layer for Yancy apps

=head1 SYNOPSIS

    # XXX: Allow using backend strings
    my $model = Yancy::Model->new( backend => $backend );

    my $schema = $model->schema( 'foo' );

    my $id = $schema->create( $data );
    my $count = $schema->delete( $id );
    my $count = $schema->delete( $where );
    my $count = $schema->set( $id, $data );
    my $count = $schema->set( $where, $data );

    my $item = $schema->get( $id );
    my ( $items, $total ) = $schema->list( $where, $opts );
    for my $item ( @$items ) {
    }

    my $success = $row->set( $data );
    my $success = $row->delete();
    my $data = $row->to_hash;

=head1 DESCRIPTION

B<NOTE>: This module is experimental and its API may change before
Yancy v2!

L<Yancy::Model> is a framework for your business logic. L<Yancy::Model>
contains a number of schemas, L<Yancy::Model::Schema> objects. Each
schema contains a number of items, L<Yancy::Model::Item> objects.

For information on how to extend this module to add your own schema
and item methods, see L<Yancy::Guides::Model>.

=head1 SEE ALSO

L<Yancy::Guides::Model>

=cut

use Mojo::Base -base;
use Scalar::Util qw( blessed );
use Mojo::Util qw( camelize );
use Mojo::Loader qw( load_class );
use Mojo::Log;
use Yancy::Util qw( load_backend );
use Storable qw( dclone );

=attr backend

A L<Yancy::Backend> object.

=cut

has backend => sub { die "backend is required" };

=attr namespaces

An array of namespaces to find Schema and Item classes. Defaults to C<[ 'Yancy::Model' ]>.

=cut

has namespaces => sub { [qw( Yancy::Model )] };

=attr log

A L<Mojo::Log> object to log messages to.

=cut

has log => sub { Mojo::Log->new };

has _schema => sub { {} };
has _config_schema => sub { {} };
has _auto_read => 1;

=method new

Create a new model with the given backend. In addition to any L</ATTRIBUTES>, these
options may be given:

=over

=item schema

A JSON schema configuration. By default, the information from
L</read_schema> will be merged with this information. See
L<Yancy::Guides::Schema/Documenting Your Schema> for more information.

=back

=cut

sub new {
    my ( $class, @args ) = @_;
    my %args = @args == 1 ? %{ $args[0] } : @args;
    die "backend is required" unless $args{backend};
    $args{backend} = load_backend($args{backend});
    my $conf = $args{_config_schema} = delete $args{schema} if $args{schema};
    my $self = $class->SUPER::new(\%args);
    $self->read_schema;
    return $self;
}

=method find_class

Find a class of the given type for an object of the given name. The name is run
through L<Mojo::Util/camelize> before lookups.

    unshift @{ $model->namespaces }, 'MyApp';
    # MyApp::Schema::User
    $class = $model->find_class( Schema => 'user' );
    # MyApp::Item::UserProfile
    $class = $model->find_class( Item => 'user_profile' );

If a specific class cannot be found, a generic class for the type is found instead.

    # MyApp::Schema
    $class = $model->find_class( Schema => 'not_found' );
    # MyApp::Item
    $class = $model->find_class( Item => 'not_found' );

=cut

sub find_class {
    my ( $self, $type, $name ) = @_;
    # First, a specific class for this named type.
    for my $namespace ( @{ $self->namespaces } ) {
        my $class = "${namespace}::${type}::" . camelize( $name );
        if ( my $e = load_class $class ) {
            if ( ref $e ) {
                die "Could not load $class: $e";
            }
            # Not found, try the next one
            next;
        }
        # No error, so this is the class we want
        return $class;
    }

    # Finally, try to find a generic type class
    for my $namespace ( @{ $self->namespaces } ) {
        my $class = "${namespace}::${type}";
        if ( my $e = load_class $class ) {
            if ( ref $e ) {
                die "Could not load $class: $e";
            }
            # Not found, try the next one
            next;
        }
        # No error, so this is the class we want
        return $class;
    }

    die "Could not find class for type $type or name $name";
}

=method read_schema

Read the schema from the L</backend>.

=cut

sub read_schema {
    my ( $self ) = @_;
    my $conf_schema = $self->_config_schema;
    my $read_schema = $self->backend->read_schema;

    for my $name ( keys %$read_schema ) {
        # ; use Data::Dumper;
        # ; say "Creating schema $name";
        # ; say Dumper $read_schema->{$name};
        my $full_schema = _merge_schema( $conf_schema->{ $name } // {}, $read_schema->{ $name } // {} );
        $conf_schema->{ $name } = $full_schema;
    }
    return $self;
}

=method schema

Get a schema object.

    $schema = $model->schema( 'user' );

=cut

sub schema {
  my ( $self, $name ) = @_;

  # If we have this schema object already, return it
  if ( my $schema = $self->_schema->{ $name } ) {
    return $schema;
  }
  # If we have this schema in our json schema, make a schema object and return
  # it.
  my $conf = $self->_config_schema->{ $name };
  if ( $conf && !$conf->{'x-ignore'} ) {
    # ; use Data::Dumper;
    # ; print STDERR 'Getting schema ' . $name . ': ' . Dumper($conf) . "\n";
    my $class = $self->find_class( Schema => $name );
    return $self->_schema->{$name} = $class->new( model => $self, name => $name, json_schema => $conf );
  }
}

=method json_schema

Get the JSON Schema for every attached schema.

=cut

sub json_schema {
  my ( $self, @names ) = @_;
  if ( !@names ) {
    @names = $self->schema_names;
  }
  return {
    map { $_ => $self->schema( $_ )->json_schema } @names
  };
}

=method schema_names

Get a list of all the schema names.

=cut

sub schema_names {
    my ( $self ) = @_;
    my $conf = $self->_config_schema;
    my %all_schemas = map { $_ => 1 } grep !$conf->{$_}{'x-ignore'}, keys %$conf, keys %{ $self->_schema };
    return keys %all_schemas;
}

# _merge_schema( $keep, $merge );
#
# Merge the two schemas, returning the result.
sub _merge_schema {
    my ( $left, $right ) = @_;
    # ; use Data::Dumper;
    # ; say "Split schema " . Dumper( $left ) . Dumper( $right );
    my $keep = dclone $left;
    if ( my $right_props = $right->{properties} ) {
        my $keep_props = $keep->{properties} ||= {};
        for my $p ( keys %{ $right_props } ) {
            my $keep_prop = $keep_props->{ $p } ||= {};
            my $right_prop = $right_props->{ $p };
            for my $k ( keys %$right_prop ) {
                $keep_prop->{ $k } ||= $right_prop->{ $k };
            }
        }
    }
    for my $k ( keys %$right ) {
        next if $k eq 'properties';
        $keep->{ $k } ||= $right->{ $k };
    }
    # ; use Data::Dumper;
    # ; say "Merged schema " . Dumper $keep;
    return $keep;
}

1;
