package Yancy::User;
use Mojo::Base 'Yancy::Model', -signatures;
use Scalar::Util qw( blessed );
use Mojo::JSON qw( true false );
use Mojo::Loader qw( data_section );
use Mojo::Util qw( decamelize );

=head1 DESCRIPTION

This is the user _model_: It provides user accounts, sessions, and groups.
Authentication is handled by a L<Yancy::Auth> plugin, which then use this
model to find users and set up sessions.

=cut

has _auths => sub { [] };

sub new($class, @args) {
  my $self = $class->SUPER::new(@args);
  unshift @{$self->namespaces}, 'Yancy::User';

  # Perform migrations for our backend
  # backend class minus Yancy::Backend::, lower-case.
  my ($ext) = blessed($self->backend) =~ s{Yancy::Backend::(\w+)}{\L$1}r;
  # try to find migrations.<key>
  if (my $migrations = data_section( __PACKAGE__, "migrations.$ext")) {
    # decamelize $class for migration name
    $self->backend->driver->migrations->name(decamelize(__PACKAGE__))->from_string($migrations)->migrate();
  }

  # Now that we have our database tables, we need to re-read the schema...
  $self->read_schema;

  return $self;
}

sub add_auth( $self, $auth ) {
  # XXX: Make sure auth provider_name is unique!

}

1;
__DATA__

@@ migrations.sqlite
-- 1 up
CREATE TABLE users (
  user_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  login STRING NOT NULL,
  UNIQUE KEY (login)
);

CREATE TABLE auth_attributes (
  auth_attribute_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL REFERENCES users (user_id),
  provider_name STRING NOT NULL,
  attribute STRING NOT NULL,
  value STRING,
  UNIQUE KEY (user_id, provider_name, attribute)
);

CREATE TABLE user_permissions (
  user_id INTEGER NOT NULL REFERENCES users (user_id),
  permission STRING,
  PRIMARY KEY (user_id, permission)
);

CREATE TABLE sessions (
  session_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  user_id STRING REFERENCES users (user_id),
  created_datetime STRING,
  last_activity_datetime STRING,
  expired_datetime STRING
);

-- 1 down
DROP TABLE sessions;
DROP TABLE user_permissions;
DROP TABLE auth_attrs;
DROP TABLE users;
