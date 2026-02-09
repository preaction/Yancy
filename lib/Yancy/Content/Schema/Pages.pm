package Yancy::Content::Schema::Pages;
use Mojo::Base 'Yancy::Model::Schema', -signatures;
use Mojo::JSON qw( true false );

sub set( $self, $id, $data ) {
  # If we are setting this in the database, it cannot possibly be an
  # in-app route. In-app routes are created by Yancy::Content->new and
  # bypass this model class.
  $data->{in_app} = false;
  # XXX: overrides cannot change method, name, or pattern
  return $self->SUPER::set( $id, $data )
}

sub delete( $self, $id ) {
  # XXX: in_app routes cannot be deleted, only overridden
}

sub json_schema( $self ) {
  my $schema = $self->SUPER::json_schema;
  $schema->{'x-list-columns'} = [qw( name pattern title )];
  return $schema;
}
1;
