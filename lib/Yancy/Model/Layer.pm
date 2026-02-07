package Yancy::Model::Layer;
our $VERSION = '1.089';
# ABSTRACT: Layered model layer

=head1 SYNOPSIS

    my $model = Yancy::Model::Layer->new($model_one, $model_two)

=head1 DESCRIPTION

This L<Yancy::Model> allows layering one model on top of another.
Models are not merged, so an earlier model will override a later one.

=head1 SEE ALSO

L<Yancy::Model>

=cut

use Mojo::Base -base, -signatures;
use List::Util qw( uniq );

=attr models

An array reference of L<Yancy::Model> objects.

=cut

has models => sub { [] };

=method new

Create a new model combining the given models.

=cut

sub new {
  my ( $class, @models ) = @_;
  my $self = $class->SUPER::new();
  push @{$self->models}, @models;
  return $self;
}

=method schema

Get a schema object.

    $schema = $model->schema( 'user' );

=cut

sub schema {
  my ( $self, $name ) = @_;
  for my $model ( $self->models->@* ) {
    return $model->schema($name) || next;
  }
}

=method json_schema

Get the JSON Schema for every attached schema from each model.

=cut

sub json_schema {
  my ( $self ) = @_;
  my %json_schema;
  for my $model ( $self->models->@* ) {
    %json_schema = (
      $model->json_schema->%*,
      %json_schema,
    );
  }
  return \%json_schema;
}

=method schema_names

Get a list of all the schema names.

=cut

sub schema_names {
  my ( $self ) = @_;
  return uniq map { $_->schema_names } $self->models->@*;
}

1;
