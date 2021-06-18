package Yancy::Model;
our $VERSION = '1.075';
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

=attr backend

A L<Yancy::Backend> object.

=cut

has backend => sub { die "backend is required" };

=attr namespaces

An array of namespaces to find Schema and Item classes. Defaults to C<[ 'Yancy::Model' ]>.

=cut

has namespaces => sub { [qw( Yancy::Model )] };

has _schema => sub { {} };

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

Read the schema from the L</backend> and prepare schema objects using L</find_class>
to find the correct classes.

=cut

sub read_schema {
    my ( $self ) = @_;
    my $schema = $self->backend->read_schema;
    for my $name ( keys %$schema ) {
        $self->schema( $name, $schema->{ $name } );
    }
    return $self;
}

=method schema

Get or set a schema object.

    $model = $model->schema( user => MyApp::Model::User->new );
    $schema = $model->schema( 'user' );

=cut

# XXX: Preload namespaces' Schema:: and Item:: classes?
sub schema {
    my ( $self, $name, $data ) = @_;
    return $self->_schema->{ $name } if !$data;

    if ( !blessed $data ) {
        my $class = $self->find_class( Schema => $name );
        $data = $class->new( { %$data, model => $self, name => $name } );
    }

    $self->_schema->{$name} = $data;
    return $self;
}

1;
